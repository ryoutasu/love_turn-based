-- Main narrative thread: approach the current dojo master, choose a path,
-- reach the boss. Deterministic per (master, campaign) — the graph is the
-- same across retries so the story is consistent; only the map layout rerolls.

local MasterGenerator  = require 'data.story.generators.master_generator'
local PlayerMetaStory  = require 'src.player_meta_story'

return {
    id   = 'master_trial',
    type = 'story',

    -- Eligible whenever a dojo master is still ahead of us.
    requires = function(camp)
        if camp.phase ~= 'dojo' then return false end
        if not camp.current_master_id then return false end
        local m = camp.masters and camp.masters[camp.current_master_id]
        return m ~= nil and not m.defeated
    end,

    -- High priority: story runs every time a master is pending.
    weight = function(camp) return 20 end,

    -- Deterministic scene graph. Depends only on campaign/master state.
    --
    --   start (arrival) -> crossroads
    --   crossroads -> branches { shortcut, scenic }
    --   shortcut (gate) -> boss
    --   scenic (find_key, grants run_key) -> boss
    --   boss: is_boss, requires run_key, alt_when_locked = boss_angry
    --   boss_angry: is_boss (harsher encounter — see scene)
    --
    -- Narrative intent:
    --   * Shortcut = fewer nodes, but you arrive at the gate with nothing.
    --   * Scenic  = one extra node, but you pick up the key on the way.
    --   * If the player is impatient, the boss is angry (alt_when_locked).
    --   * If the player explores, the boss is normal.
    build = function(ctx)
        local m = ctx.master
        if not m then return nil end

        return {
            start = {
                scene = 'master_arrival',
                next  = 'crossroads',
            },
            crossroads = {
                scene    = 'master_crossroads',
                branches = { 'shortcut', 'scenic' },
            },
            shortcut = {
                scene = 'master_gate',
                next  = 'boss',
            },
            scenic = {
                scene  = 'master_find_key',
                next   = 'boss',
                grants = { run_key = 'dojo_key' },
            },
            boss = {
                scene           = 'master_boss',
                is_boss         = true,
                requires        = { run_key = 'dojo_key' },
                alt_when_locked = 'boss_angry',
            },
            boss_angry = {
                scene   = 'master_boss_angry',
                is_boss = true,
            },
        }
    end,

    -- Victory over the master: advance progression, clear active thread.
    -- Do NOT add to completed_threads — the thread repeats for the next master.
    on_complete = function(camp, thread_state)
        MasterGenerator.on_victory(camp, camp.current_master_id)
        PlayerMetaStory.clear_active_thread(camp)
    end,

    -- Player died to the master (all lives lost). Master keeps memory;
    -- active_thread stays so the next run uses the same master.
    on_fail = function(camp, thread_state)
        MasterGenerator.on_defeat(camp, camp.current_master_id)
    end,
}