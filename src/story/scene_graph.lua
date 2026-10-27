-- Pure graph operations for story scene graphs. Engine-agnostic.
-- No Love2D dependencies, no globals. Safe to unit-test standalone.

local SceneGraph = {}

-- Outgoing scene ids from a scene node definition.
-- Recognised fields:
--   .next            (string)          linear next scene
--   .branches        (array)           player choice
--   .alt_when_locked (string)          SCENE id played when the node's
--                                      `requires` gate is closed
--
-- `alt_when_locked` is deliberately NOT an edge: it names a scene, not another
-- graph node (see Node:resolve_scene_id, which returns it verbatim for lookup
-- in Scenes[]). Treating it as an edge made validate() demand a graph node
-- named after a scene, so the boss could not be collapsed into a single node.
function SceneGraph.outgoing(node)
    local out = {}
    if node.next then out[#out + 1] = node.next end
    if node.branches then
        for i = 1, #node.branches do
            out[#out + 1] = node.branches[i]
        end
    end
    return out
end

-- Structural + reachability validation. Throws on error.
function SceneGraph.validate(graph)
    if type(graph) ~= 'table' then
        error("scene graph is nil or not a table")
    end
    if not graph.start then
        error("scene graph has no 'start' node")
    end

    for id, node in pairs(graph) do
        if type(node) ~= 'table' then
            error("scene node '" .. tostring(id) .. "' is not a table")
        end
        if type(node.scene) ~= 'string' then
            error("scene node '" .. tostring(id) .. "' has no .scene string")
        end
        for _, nid in ipairs(SceneGraph.outgoing(node)) do
            if not graph[nid] then
                error(string.format(
                    "scene '%s' points to missing node '%s'", id, nid))
            end
        end
    end

    -- Reachability from start via BFS
    local reached = {}
    local q = { 'start' }
    while #q > 0 do
        local id = table.remove(q, 1)
        if not reached[id] then
            reached[id] = true
            for _, nid in ipairs(SceneGraph.outgoing(graph[id])) do
                q[#q + 1] = nid
            end
        end
    end
    for id in pairs(graph) do
        if not reached[id] then
            error("unreachable scene node: " .. tostring(id))
        end
    end
end

-- BFS depth from 'start'. Returns { [scene_id] = depth }.
function SceneGraph.depths(graph)
    local depth = { start = 0 }
    local q = { 'start' }
    while #q > 0 do
        local id = table.remove(q, 1)
        for _, nid in ipairs(SceneGraph.outgoing(graph[id])) do
            if not depth[nid] then
                depth[nid] = depth[id] + 1
                q[#q + 1] = nid
            end
        end
    end
    return depth
end

-- Groups scene ids by depth. Returns { [depth] = sorted_array }.
-- Sorted for determinism (pairs order is not guaranteed).
function SceneGraph.group_by_depth(graph, depths)
    local groups = {}
    for id, d in pairs(depths) do
        groups[d] = groups[d] or {}
        groups[d][#groups[d] + 1] = id
    end
    for _, row in pairs(groups) do
        table.sort(row)
    end
    return groups
end

function SceneGraph.max_depth(graph)
    local depths = SceneGraph.depths(graph)
    local m = 0
    for _, d in pairs(depths) do
        if d > m then m = d end
    end
    return m
end

-- Count edges (each entry in .next and each .branches entry counts once).
function SceneGraph.edge_count(graph)
    local n = 0
    for _, node in pairs(graph) do
        n = n + #SceneGraph.outgoing(node)
    end
    return n
end

-- Sorted list of scene ids, for deterministic iteration in layout.
function SceneGraph.sorted_ids(graph)
    local ids = {}
    for id in pairs(graph) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

return SceneGraph