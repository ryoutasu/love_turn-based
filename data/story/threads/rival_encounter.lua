-- Rival thread: the same NPC, met three times across the campaign.
--
-- This is the genre's strongest narrative device (Gary Oak, Silver, Hop).
-- The graph is intentionally identical on every visit; what changes is
-- `rival.meetings`, which drives:
--   * stage  (1 = first meeting, 2 = middle, 3 = final)
--   * tier   (their party grows every meeting — see RivalGenerator.tier)
--   * tone   (a proud rival only softens after losing twice)
--
-- The thread stays pinned until it is completed, so a defeat does not
-- reset the relationship — it is remembered.

local RivalGenerator = require 'data.story.generators.rival_generator'
local PlayerMetaStory = require 'src.player_meta_story'

return {
    id   = 'rival_encounter',
    type = 'story',

    -- Available from the very first run and until the final meeting is done.
    requires = function(camp)
        if not camp.rival then return false end
        -- Three meetings total: stage 3 is the last one.
        return RivalGenerator.stage(camp.rival) <= 3
            and (camp.rival.meetings or 0) < 3
    end,

    -- Slightly below the master trial: the master is the main axis,
    -- the rival is the recurring counterpoint.
    weight = function(camp)
        local rival = camp.rival
        if not rival then return 0 end
        -- First meeting is urgent: it introduces the character.
        if (rival.meetings or 0) == 0 then return 16 end
        return 10
    end,

    -- Two scenes per stage: the encounter, then the duel.
    -- Both stages share the graph; scenes branch on stage internally.
    build = function(ctx)
        local rival = ctx.rival
        if not rival then return nil end

        return {
            start = {
                scene = 'rival_meet',
                next  = 'duel',
            },
            duel = {
                scene    = 'rival_duel',
                is_boss  = true,      -- real battle, not just dialogue
                terminal = true,
            },
        }
    end,

    on_complete = function(camp, thread_state)
        -- The duel's outcome is recorded by record_battle_outcome; here we
        -- only decide whether the rivalry is over.
        local rival = camp.rival
        if rival and (rival.meetings or 0) >= 3 then
            PlayerMetaStory.mark_thread_complete(camp, 'rival_encounter')
        else
            -- Keep the thread pinned: the next meeting is a new run.
            PlayerMetaStory.set_active_thread(camp, 'rival_encounter', {})
        end
    end,

    on_fail = function(camp, thread_state)
        -- Losing to the rival counts as a meeting too, but the thread
        -- survives: they will bring it up next time.
        if camp.rival then
            RivalGenerator.record(camp, false)
            PlayerMetaStory.set_active_thread(camp, 'rival_encounter', {})
        end
    end,
}
