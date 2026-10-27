-- src/story/scene_runner.lua
--
-- Runs a thread's scene graph: picks the starting node, generates the
-- EventState payload for it, and remembers where to go next.
--
-- Why this exists: data/story/threads/* describe GRAPHS (nodes + edges),
-- while EventState expects a FLAT { title, steps } table. Something has to
-- translate between them, and it must be the single place that does so вЂ”
-- otherwise every scene grows its own ad-hoc navigation and the graph
-- validation stops meaning anything.
--
-- State lives in RunState.story (saved), never in the module.

local Scenes     = require 'data.story.scenes'
local SceneGraph = require 'src.story.scene_graph'

local SceneRunner = {}

local function ensure_story(runState, thread)
    runState.story = runState.story or {
        thread_id    = thread and thread.id,
        flags        = {},
        scene_log    = {},
        thread_state = {},
    }
    runState.story.flags        = runState.story.flags        or {}
    runState.story.scene_log    = runState.story.scene_log    or {}
    runState.story.thread_state = runState.story.thread_state or {}
    return runState.story
end

--- Build everything needed to play the first scene of a thread.
--- @return table|nil { scene_id, node_id, scene, payload, graph }
function SceneRunner.begin(runState, thread, ctx)
    local started = SceneRunner._begin(thread, ctx, runState)
    if not started then return nil end
    return SceneRunner.current(runState, ctx)
end

--- Build the graph for a thread WITHOUT playing a scene yet.
--- Placement only needs the graph; keeping this separate means placement
--- does not accidentally log a scene the player never saw.
--- @return table|nil { graph, thread }
function SceneRunner._begin(thread, ctx, runState)
    if not thread then return nil end

    local graph = thread.build(ctx)
    if not graph then return nil end
    SceneGraph.validate(graph)

    local story = ensure_story(runState, thread)
    story.graph   = graph
    story.node_id = 'start'

    return { graph = graph, thread = thread }
end

--- Generate the payload for the node we are currently standing on.
function SceneRunner.current(runState, ctx)
    local story = runState.story
    if not story or not story.graph or not story.node_id then return nil end

    local node     = story.graph[story.node_id]
    if not node then return nil end

    local scene_id = node.scene
    local scene    = Scenes[scene_id]
    if not scene then
        error(('story: node %q references unknown scene %q')
            :format(tostring(story.node_id), tostring(scene_id)))
    end

    -- Log every scene actually entered: this is what makes a run auditable
    -- and lets tests assert "the player saw exactly these scenes".
    story.scene_log[#story.scene_log + 1] = scene_id
    story.flags = story.flags or {}

    local payload = scene.generate(ctx)
    if not payload then
        error(('story: scene %q generated nothing'):format(scene_id))
    end

    return {
        scene_id = scene_id,
        node_id  = story.node_id,
        scene    = scene,
        node     = node,
        payload  = payload,
        graph    = story.graph,
    }
end

--- Advance to the next node, if this one has a linear successor.
--- Returns true if the graph moved.
function SceneRunner.advance(runState)
    local story = runState.story
    if not story or not story.graph or not story.node_id then return false end

    local node = story.graph[story.node_id]
    if node and node.next then
        story.node_id = node.next
        return true
    end
    return false
end

--- Jump to a specific node (used by `branches` when the player chooses).
function SceneRunner.jump_to(runState, node_id)
    local story = runState.story
    if not story or not story.graph then return false end
    if not story.graph[node_id] then return false end
    story.node_id = node_id
    return true
end

--- Is the current node the end of the thread?
function SceneRunner.is_terminal(runState)
    local story = runState.story
    if not story or not story.graph or not story.node_id then return true end
    local node = story.graph[story.node_id]
    if not node then return true end
    if node.terminal then return true end
    return #SceneGraph.outgoing(node) == 0
end

--- Resolve which node to use given the node's `requires` gate, honouring
--- `alt_when_locked`. Mirrors Node:resolve_scene_id semantics.
function SceneRunner.resolve_node(runState, is_locked)
    local story = runState.story
    if not story or not story.graph or not story.node_id then return nil end

    local node = story.graph[story.node_id]
    if not node then return nil end

    if is_locked and node.alt_when_locked then
        story.node_id = node.alt_when_locked
        return story.graph[story.node_id]
    end
    return node
end

--- Clear story state at the end of a run.
function SceneRunner.finish(runState)
    if runState then runState.story = nil end
end

return SceneRunner
