-- src/story/story_placement.lua
--
-- Places the active story thread onto a generated map.
--
-- Responsibilities (deliberately narrow):
--   1. ask ThreadGenerator which thread runs this run;
--   2. find free nodes and stamp them with the thread's graph nodes
--      (story_scene / story_id / requires / is_boss ...);
--   3. never touch the map if no thread is selected — a "filler run"
--      stays a pure roguelite run.
--
-- Determinism: uses RunState:random only. Placement order is derived from
-- node index, so the same seed yields the same scene placement.

local ThreadGenerator = require 'src.story.thread_generator'
local SceneRunner     = require 'src.story.scene_runner'
local Threads         = require 'data.story.threads'

local StoryPlacement = {}

-- Nodes that may host a story scene: generic event nodes that are neither
-- the start nor the boss, and that are far enough from the start.
local function is_usable(node, start_node)
    if node == start_node then return false end
    if node.type ~= 'event' and node.type ~= 'wild' then return false end
    return true
end

--- Choose placement slots for `count` scenes spread across depths.
--- Returns an array of nodes ordered shallow -> deep.
local function choose_slots(nodes, start_node, count)
    local candidates = {}
    for i, node in ipairs(nodes) do
        if is_usable(node, start_node) then
            candidates[#candidates + 1] = { node = node, depth = node.level or 1, index = i }
        end
    end

    -- Deterministic: sort by depth then index.
    table.sort(candidates, function(a, b)
        if a.depth ~= b.depth then return a.depth < b.depth end
        return a.index < b.index
    end)

    local slots = {}
    if #candidates == 0 then return slots end

    -- Spread picks evenly along the sorted list so scenes are not all
    -- clustered at the entrance.
    for i = 1, count do
        local pos = math.floor((i - 0.5) * #candidates / count) + 1
        pos = math.min(math.max(pos, 1), #candidates)
        local pick = candidates[pos]
        -- Skip duplicates caused by rounding on small maps.
        if pick and not slots[pick.index] then
            slots[pick.index] = pick.node
        end
    end

    local ordered = {}
    for _, node in pairs(slots) do ordered[#ordered + 1] = node end
    table.sort(ordered, function(a, b)
        if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
        return a.id < b.id
    end)
    return ordered
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

--- Main entry: attach the active thread to the map.
--- @param levelmap  Levelmap state (needs .nodes, .player)
--- @param player    Player
--- @param runState  RunState
--- @return table|nil { thread, graph, placed = { node } }
function StoryPlacement.place(levelmap, player, runState)
    local ok, thread = pcall(ThreadGenerator.select, player, runState, Threads)
    if not ok or not thread then return nil end

    local ctx  = ThreadGenerator.build_context(player, runState)
    local start = SceneRunner._begin(thread, ctx, runState)
    if not start then return nil end

    local graph = start.graph
    local nodes = levelmap.nodes
    if not nodes or #nodes == 0 then return nil end

    local start_node
    for _, n in ipairs(nodes) do
        if n.type == 'wild' and (n.level or 0) <= 1 then start_node = n break end
    end
    start_node = start_node or nodes[1]

    -- Order graph nodes by depth so the deepest is placed furthest away.
    local SceneGraph = require 'src.story.scene_graph'
    local depths = SceneGraph.depths(graph)
    local ids = {}
    for id in pairs(graph) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b)
        local da, db = depths[a] or 0, depths[b] or 0
        if da ~= db then return da < db end
        return a < b
    end)

    local slots = choose_slots(nodes, start_node, #ids)
    if #slots == 0 then return nil end

    local placed = {}
    for i, node_id in ipairs(ids) do
        local map_node = slots[i]
        if map_node then
            local graph_node = graph[node_id]
            stamp(map_node, node_id, graph, graph_node.scene)
            map_node.type = 'event'          -- renders with the event icon
            map_node.event = nil             -- story scenes are not random events
            map_node.is_master_boss = graph_node.is_boss or false
            placed[#placed + 1] = map_node
        end
    end

    return { thread = thread, graph = graph, placed = placed, ctx = ctx }
end

return StoryPlacement
