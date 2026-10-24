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
-- Returns list of { id, thread, weight } sorted by id (determinism).

function ThreadGenerator.pool(player, runState, threads_registry)
    local camp = player.meta_story
    local pool = {}

    for id, thread in pairs(threads_registry) do
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
                local w = 1
                if thread.weight then
                    w = thread.weight(camp) or 1
                end
                if camp.threads[id] then w = w * 3 end
                pool[#pool + 1] = { id = id, thread = thread, weight = w }
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
-- Returns (thread, ctx) or (nil, ctx) if no story thread.
-- Always sets RunState.story and Player.meta_story.active_thread on success.

function ThreadGenerator.select(player, runState, threads_registry)
    local camp = player.meta_story
    local ctx  = build_context(player, runState)

    -- 1) Forced continuation of an active thread (survives defeats)
    if camp.active_thread then
        local forced = threads_registry[camp.active_thread.id]
        if forced and (not forced.requires or forced.requires(camp)) then
            runState.story = {
                thread_id    = forced.id,
                flags        = {},
                scene_log    = {},
                thread_state = {},
            }
            return forced, ctx
        end
        -- Thread no longer valid (e.g. master already defeated elsewhere):
        PlayerMetaStory.clear_active_thread(camp)
    end

    -- 2) Fresh pick from eligible pool
    local pool = ThreadGenerator.pool(player, runState, threads_registry)
    if #pool == 0 then
        runState.story = nil
        return nil, ctx
    end

    local chosen = weighted_pick(pool, runState)
    if not chosen then
        runState.story = nil
        return nil, ctx
    end

    -- 3) Pin thread for this and subsequent runs until completion
    PlayerMetaStory.set_active_thread(camp, chosen.id, {})

    runState.story = {
        thread_id    = chosen.id,
        flags        = {},
        scene_log    = {},
        thread_state = {},
    }

    return chosen.thread, ctx
end

return ThreadGenerator