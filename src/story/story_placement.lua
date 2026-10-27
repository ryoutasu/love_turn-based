-- src/story/story_placement.lua
--
-- Places the active story thread onto a generated map.
--
-- Responsibilities (deliberately narrow):
--   1. ask ThreadGenerator which thread runs this run;
--   2. lay the thread's scene graph onto the MAP GRAPH: the graph's `start`
--      node goes on the map start, and every other scene goes on a map node
--      adjacent to its graph parent(s);
--   3. never touch the map if no thread is selected — a "filler run"
--      stays a pure roguelite run.
--
-- Why graph-aware instead of spacing scenes over a flat list: a branch is
-- only a real choice if its arms are siblings on the map. Spacing by node
-- level put `shortcut` and `scenic` four and two steps from the start, so
-- the "shortcut" was the longer route.
--
-- Determinism: the map is rebuilt from the same seed, scene order comes from a
-- BFS with sorted children, and ties break on RunState:random (seeded).

local ThreadGenerator = require 'src.story.thread_generator'
local SceneRunner     = require 'src.story.scene_runner'
local SceneGraph      = require 'src.story.scene_graph'
local Threads         = require 'data.story.threads'

local StoryPlacement = {}

-- How far a merge scene may be from its parents when no point touches all of
-- them at once (hex lattices rarely offer a perfect diamond).
local MERGE_REACH = 4

-- Nodes that may host a story scene.
-- T1: trainer nodes are acceptable story slots (disposable filler; see
-- AGENTS.md placement notes). shop/rest remain excluded.
local function is_usable(node, start_node)
    if node == start_node then return false end
    return node.type == 'event' or node.type == 'wild' or node.type == 'trainer'
end

--- Map-node index: point -> node, index -> node, plus adjacency by point.
local function index_map(nodes)
    local by_point = {}
    local by_index = {}
    for i, node in ipairs(nodes) do
        by_index[node] = i
        if node.point then by_point[node.point] = node end
    end
    return by_point, by_index
end

--- Map neighbours of a node, from the generator's point neighbours.
local function neighbours(node)
    local out = {}
    local point = node and node.point
    if not point or not point.neighbors then return out end
    for _, npoint in ipairs(point.neighbors) do out[#out + 1] = npoint end
    return out
end

--- Authoritative map adjacency: two map nodes are adjacent when the generator
--- says their points are neighbours. Placement and smoke_story_placement both
--- use this rule; point.neighbors agrees with it on every pair.
local function ADJACENT(levelmap, a, b)
    if not a or not b or a == b or not a.point or not b.point then return false end
    local gen = levelmap and levelmap.generator
    if not gen then return false end
    return gen:isNeighbors(a.point, b.point) and true or false
end

--- BFS over the map graph from `from`, returning { [node] = distance }.
local function map_distances(from, by_point)
    if not from or not from.point then return {} end
    local dist = { [from] = 0 }
    local q = { from }
    local head = 1
    while head <= #q do
        local cur = q[head]
        head = head + 1
        for _, npoint in ipairs(neighbours(cur)) do
            local node = by_point[npoint]
            if node and dist[node] == nil then
                dist[node] = dist[cur] + 1
                q[#q + 1] = node
            end
        end
    end
    return dist
end

--- Stamp one graph node onto a map node.
local function stamp(map_node, graph_node_id, graph, scene_id)
    map_node.story_id        = graph_node_id
    map_node.story_scene     = scene_id
    map_node.requires        = graph_node_id and graph[graph_node_id] and graph[graph_node_id].requires or nil
    map_node.alt_when_locked = graph_node_id and graph[graph_node_id] and graph[graph_node_id].alt_when_locked or nil
    map_node.is_boss         = (graph_node_id and graph[graph_node_id] and graph[graph_node_id].is_boss) or false
    map_node.grants          = (graph_node_id and graph[graph_node_id] and graph[graph_node_id].grants) or nil
end

--- BFS over the scene graph from 'start'. Children are visited in sorted
--- order so the result never depends on table hash order.
--- Returns an ordered list of { id, parents = { ids } }.
local function graph_order(graph)
    -- Parents of every node, from SceneGraph.outgoing.
    local parents = {}
    for id, node in pairs(graph) do
        for _, child in ipairs(SceneGraph.outgoing(node)) do
            parents[child] = parents[child] or {}
            table.insert(parents[child], id)
        end
    end

    local order = {}
    local seen = { start = true }
    local queue = { 'start' }

    while #queue > 0 do
        local id = table.remove(queue, 1)
        local kids = SceneGraph.outgoing(graph[id])
        table.sort(kids)
        for _, child in ipairs(kids) do
            if not seen[child] then
                seen[child] = true
                local ps = {}
                for _, p in ipairs(parents[child] or {}) do ps[#ps + 1] = p end
                table.sort(ps)
                order[#order + 1] = { id = child, parents = ps }
                queue[#queue + 1] = child
            end
        end
    end

    return order
end

--- Candidate map nodes for one scene, ranked deterministically.
---   single parent: map neighbours of the parent, unused
---   merge:         unused nodes touching ALL parents, else unused nodes within
---                  MERGE_REACH of ALL parents
--- Ranking: closest to the parents first, then furthest from the map start.
--- Siblings are picked in the same breath, so keeping both arms next to their
--- shared parent matters more than pushing scenes forward: ranking on "forward"
--- first made S1 grab the deepest neighbour and S2 fall back one step, which
--- broke the branch. Returns the ranked list, or {} when nothing fits.
---
--- @param avoid map node -> true. Placed scenes that this one must NOT touch:
---        the map start and every scene placed before this one's parent set.
---        A hex lattice often offers a neighbour shared with an earlier scene,
---        and landing there shortcuts the story (it made `shortcut` adjacent
---        to the arrival node, so the branch read as depth 1 instead of 2).
local function candidates_for(parent_nodes, used, start_node, by_point, from_start, rng, avoid, levelmap)
    local maps = {}
    for _, node in pairs(by_point) do maps[#maps + 1] = node end
    table.sort(maps, function(a, b)
        return (a.id or 0) < (b.id or 0)
    end)

    -- Reachability from each parent, computed once.
    local reach = {}
    for i, parent in ipairs(parent_nodes) do reach[i] = map_distances(parent, by_point) end

    local out = {}
    for _, node in ipairs(maps) do
        if not used[node] and node ~= start_node and is_usable(node, start_node) then
            local best = 0
            local fits = true
            for i = 1, #reach do
                local d = reach[i][node]
                if d == nil then
                    fits = false
                    break
                end
                if d > best then best = d end
            end
            local limit = #reach == 1 and 1 or MERGE_REACH
            if fits and best <= limit then
                local touches_earlier = false
                for other in pairs(avoid or {}) do
                    if ADJACENT(levelmap, node, other) then touches_earlier = true end
                end
                if not touches_earlier then
                    out[#out + 1] = { node = node, near = best }
                end
            end
        end
    end

    -- Closest to the parents first: that is what keeps sibling scenes
    -- adjacent to the same parent. Direction from the map start is the next
    -- criterion (prefer forward when several slots are equally near), then
    -- index.
    --
    -- A seeded draw is used ONLY to break a tie on both criteria, so the RNG
    -- is consumed in a well-defined order and never for scenes that had a
    -- single sensible slot.
    for _, entry in ipairs(out) do
        entry.forward = from_start[entry.node] or 0
        entry.jitter  = 0
    end
    table.sort(out, function(a, b)
        if a.near ~= b.near then return a.near < b.near end
        return a.forward > b.forward
    end)
    local i = 1
    while i <= #out do
        local j = i
        while j < #out
            and out[j + 1].near == out[i].near
            and out[j + 1].forward == out[i].forward do
            j = j + 1
        end
        if j > i and rng then
            for k = i, j do out[k].jitter = rng() end
            local slice = {}
            for k = i, j do slice[#slice + 1] = out[k] end
            table.sort(slice, function(a, b)
                if a.jitter ~= b.jitter then return a.jitter < b.jitter end
                return (a.node.id or 0) < (b.node.id or 0)
            end)
            for k = i, j do out[k] = slice[k - i + 1] end
        end
        i = j + 1
    end

    local nodes = {}
    for _, entry in ipairs(out) do
        nodes[#nodes + 1] = entry.node
    end
    return nodes
end

--- Main entry: attach the active thread to the map.
--- @param levelmap  Levelmap state (needs .nodes, .currentNode, .generator)
--- @param player    Player
--- @param runState  RunState
--- @return table|nil { thread, graph, placed = { node }, ctx }
function StoryPlacement.place(levelmap, player, runState)
    local ok, thread = pcall(ThreadGenerator.select, player, runState, Threads)
    if not ok or not thread then return nil end

    local ctx   = ThreadGenerator.build_context(player, runState)
    local start = SceneRunner._begin(thread, ctx, runState)
    if not start then return nil end

    local graph = start.graph
    local nodes = levelmap.nodes
    if not nodes or #nodes == 0 then return nil end

    -- (a) Map start node.
    local by_point = index_map(nodes)
    local start_node = levelmap.currentNode
    if not start_node then
        local gen = levelmap.generator
        if gen and gen.startPoint then start_node = by_point[gen.startPoint] end
    end
    if not start_node or not start_node.point then
        print('[story] placement failed: no map start node')
        return nil
    end

    local from_start = map_distances(start_node, by_point)
    local rng = runState and runState.random and function() return runState:random() end or nil

    -- (b) The graph's start scene goes on the map start.
    local used = { [start_node] = true }
    stamp(start_node, 'start', graph, graph.start.scene)
    start_node.type  = 'event'   -- renders with the event icon
    start_node.event = nil       -- story scenes are not random events
    start_node.is_master_boss = graph.start.is_boss or false
    local placed = { start_node }

    -- (c)/(d) Walk the graph breadth-first, giving each scene a map node
    -- adjacent to the nodes its parents were placed on.
    local node_of   = { start = start_node }
    local parent_of = {}          -- scene id -> { parent ids }, from the BFS

    for _, entry in ipairs(graph_order(graph)) do
        parent_of[entry.id] = entry.parents

        local parent_nodes = {}
        for _, pid in ipairs(entry.parents) do
            local pnode = node_of[pid]
            if pnode then parent_nodes[#parent_nodes + 1] = pnode end
        end

        if #parent_nodes == 0 then
            print(('[story] placement failed: scene %s has unplaced parents')
                :format(entry.id))
            return nil
        end

        -- A scene must not sit next to the map start unless its parent IS the
        -- start scene. In this hex lattice one of crossroads' neighbours is
        -- also adjacent to the arrival node, so shortcut read as depth 1 and
        -- the branch looked shorter than it is.
        --
        -- Only the start is excluded. Excluding every earlier scene starved
        -- the branch instead: scenic was left with a single candidate, so
        -- shortcut had nothing left to pair with and took the start-adjacent
        -- slot anyway.
        local avoid
        if node_of[entry.parents[1]] ~= start_node then
            avoid = { [start_node] = true }
        end

        local ranked = candidates_for(parent_nodes, used, start_node, by_point,
            from_start, rng, avoid, levelmap)

        -- The avoid filter softens: every neighbour of the parent is already
        -- adjacent to the parent, so in a cramped lattice the only free slots
        -- may also touch the start. Prefer a slot that touches nothing
        -- earlier, but fall back rather than failing the whole run.
        --
        -- `avoid` is nil when this scene's parent is the map start (nothing to
        -- avoid), so guard the emptiness check — next(nil) throws.
        if #ranked == 0 and avoid and next(avoid) ~= nil then
            ranked = candidates_for(parent_nodes, used, start_node, by_point,
                from_start, rng, nil, levelmap)
        end

        -- Sibling placement is structural: every candidate is a map neighbour
        -- of the shared parent, so whichever arm is chosen here is adjacent to
        -- the parent. Whether two arms are adjacent to EACH OTHER is left to
        -- the lattice — on a hex map siblings often share an edge, and
        -- requiring the opposite starved placement on ~14% of seeds.
        if #ranked == 0 then
            local names = {}
            for _, pid in ipairs(entry.parents) do names[#names + 1] = pid end
            print(('[story] placement failed: scene %s from parent(s) %s')
                :format(entry.id, table.concat(names, ',')))
            return nil
        end

        local map_node = ranked[1]
        stamp(map_node, entry.id, graph, graph[entry.id].scene)
        map_node.type  = 'event'
        map_node.event = nil
        map_node.is_master_boss = graph[entry.id].is_boss or false

        used[map_node] = true
        node_of[entry.id] = map_node
        placed[#placed + 1] = map_node
    end

    -- (e) Keep the mapped start node first so callers can rely on placed[1].
    return { thread = thread, graph = graph, placed = placed, ctx = ctx, start = start_node }
end

return StoryPlacement
