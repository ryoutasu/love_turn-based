-- Selects the active story thread for a run, or returns nil for a filler run.
-- Honors Player.meta_story.active_thread (persists through defeats).
-- Deterministic: all randomness via RunState:random().

local PlayerMetaStory = require 'src.player_meta_story'

local ThreadGenerator = {}

-- ===========================================================================
-- Context
-- ===========================================================================
-- The context passed to thread.build(ctx) and scene.generate(ctx).

local function build_context(player, runState)
    local camp = player.meta_story
    local master = nil
    if camp.current_master_id and camp.masters then
        master = camp.masters[camp.current_master_id]
    end

    return {
        player   = player,
        campaign = camp,
        run      = runState,
        master   = master,
        rival    = camp.rival,
        rng      = function() return runState:random() end,
        rngInt   = function(a, b) return runState:randomInt(a, b) end,
    }
end

ThreadGenerator.build_context = build_context

-- ===========================================================================
-- Pool
-- ===========================================================================
-- Returns list of { id, thread, graph, weight } sorted by id (determinism).
--
-- A thread enters the pool only if its build(ctx) succeeds and returns a
-- non-nil graph. Several threads carry runtime guards in build (lost_beast:
-- party < 2 or every creature above 60% HP; rival_encounter: no rival yet),
-- and a thread whose guard refuses cannot be placed — so it must not be
-- selectable either. build must be side-effect free; every registered thread
-- is verified by tests/smoke_thread_build_contract.lua.
--
-- `threads_seen`, when passed, collects { [id] = true } for every thread that
-- was considered but excluded, so select() can release a stale pin.

function ThreadGenerator.pool(player, runState, threads_registry, threads_seen)
    local camp = player.meta_story
    local ctx  = build_context(player, runState)
    local pool = {}

    for id, thread in pairs(threads_registry) do
        if threads_seen then threads_seen[id] = true end
        if not camp.completed_threads[id] then
            local ok = false

            -- Persistent thread: currently in progress (survived a defeat)
            if camp.threads[id] then
                ok = true
            end

            -- Fresh eligibility
            if not ok and thread.requires then
                ok = thread.requires(camp) and true or false
            end

            if ok then
                -- Eligibility is not enough: the graph must actually build.
                local built, graph = pcall(thread.build, ctx)
                if built and graph then
                    local w = 1
                    if thread.weight then
                        w = thread.weight(camp) or 1
                    end
                    if camp.threads[id] then w = w * 3 end
                    pool[#pool + 1] = { id = id, thread = thread, graph = graph, weight = w }
                end
            end
        end
    end

    table.sort(pool, function(a, b) return a.id < b.id end)
    return pool
end

-- ===========================================================================
-- Weighted pick (uses RunState:random for determinism)
-- ===========================================================================

local function weighted_pick(pool, runState)
    local total = 0
    for _, entry in ipairs(pool) do total = total + entry.weight end
    if total <= 0 then return nil end

    local r = runState:random() * total
    for _, entry in ipairs(pool) do
        r = r - entry.weight
        if r <= 0 then return entry end
    end
    return pool[#pool]
end

-- ===========================================================================
-- Select
-- ===========================================================================
-- Returns (thread, ctx, graph) or (nil, ctx, nil) if no story thread.
-- Always sets RunState.story and Player.meta_story.active_thread on success.
-- The third return value is the pre-built scene graph: callers using only
-- (thread, ctx) keep working, and callers that place the story reuse it
-- instead of building a second, possibly divergent graph.

function ThreadGenerator.select(player, runState, threads_registry)
    local camp = player.meta_story
    local ctx  = build_context(player, runState)

    -- 1) Forced continuation of an active thread (survives defeats).
    -- build() runs BEFORE the pin is honoured: a thread whose runtime guard no
    -- longer holds (lost_beast after the party heals, rival once the arc ends)
    -- cannot be placed, so keeping the pin would force every following run into
    -- the same unplaceable thread.
    if camp.active_thread then
        local forced = threads_registry[camp.active_thread.id]
        if forced then
            local built, graph = pcall(forced.build, ctx)
            if built and graph then
                runState.story = {
                    thread_id    = forced.id,
                    flags        = {},
                    scene_log    = {},
                    thread_state = {},
                }
                return forced, ctx, graph
            end
        end
        -- Pin no longer viable: release it and fall through to a fresh pick.
        PlayerMetaStory.clear_active_thread(camp)
    end

    -- 2) Fresh pick. Pool membership already implies the graph built cleanly.
    local pool = ThreadGenerator.pool(player, runState, threads_registry)
    if #pool == 0 then
        runState.story = nil
        return nil, ctx, nil
    end

    local chosen = weighted_pick(pool, runState)
    if not chosen then
        runState.story = nil
        return nil, ctx, nil
    end

    -- 3) Pin only now that the graph exists.
    PlayerMetaStory.set_active_thread(camp, chosen.id, {})

    runState.story = {
        thread_id    = chosen.id,
        flags        = {},
        scene_log    = {},
        thread_state = {},
    }

    return chosen.thread, ctx, chosen.graph
end

return ThreadGenerator