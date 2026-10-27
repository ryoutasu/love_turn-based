-- Chekhov's gun, across runs.
--
-- Pattern taken from the genre: a key found in zone A opens zone B
-- (Pokémon Silph Scope -> Ghost Tower; Monster Sanctuary keys -> zones).
-- What makes it matter here is that it spans TWO RUNS: the giver is placed
-- in this run, the payoff appears in the next one. That is the cheapest way
-- to make a roguelite feel like a continuous story rather than a loop.
--
-- Uses the machinery already present in src/player_meta_story.lua:
--   register_key_thread / key_thread_pending / can_replay_giver.
--
-- The thread is not "pinned" in the usual sense: getAuthorities still picks
-- it through `requires`, but its two halves live in different runs, so it
-- must be eligible whenever either half is due.

local PlayerMetaStory = require 'src.player_meta_story'

local KEY          = 'moon_key'
local PAYOFF_SCENE = 'moon_door'

return {
    id   = 'lore_moon_key',
    type = 'lore',

    requires = function(camp)
        -- Giver half: no key yet, and we have not placed it in this run.
        if PlayerMetaStory.can_replay_giver(camp, KEY) then
            return true
        end
        -- Payoff half: key was found in a previous run and is still unspent.
        if PlayerMetaStory.key_thread_pending(camp, KEY) then
            return true
        end
        return false
    end,

    weight = function(camp)
        -- The payoff is a bigger deal than finding the key, so push it
        -- forward once it is due.
        if PlayerMetaStory.key_thread_pending(camp, KEY) then return 14 end
        return 6
    end,

    build = function(ctx)
        local camp = ctx.campaign

        -- Payoff run: the door is available.
        if PlayerMetaStory.key_thread_pending(camp, KEY) then
            return {
                start = {
                    scene = 'moon_door_prelude',
                    next  = PAYOFF_SCENE,
                },
                moon_door = {
                    scene    = PAYOFF_SCENE,
                    terminal = true,
                },
            }
        end

        -- Giver run: find the key.
        return {
            start = {
                scene    = 'moon_key_find',
                terminal = true,
            },
        }
    end,

    on_complete = function(camp, thread_state)
        -- Behaviour is decided by the scenes themselves:
        --   moon_key_find grants the story key and registers the key thread;
        --   moon_door   consumes it.
        -- Here we only clean up the pin so the thread can run again later
        -- for the next key (there may be more than one moon key in future).
        local has_key    = PlayerMetaStory.has_story_key(camp, KEY)
        local registered = camp.key_threads and camp.key_threads[KEY]
        local consumed   = registered and registered.payoff_consumed

        if consumed then
            PlayerMetaStory.mark_thread_complete(camp, 'lore_moon_key')
        else
            PlayerMetaStory.clear_active_thread(camp)
        end
    end,

    on_fail = function(camp, thread_state)
        -- A failed run does not lose the carried key: that is the point.
        PlayerMetaStory.clear_active_thread(camp)
    end,

    KEY          = KEY,
    PAYOFF_SCENE = PAYOFF_SCENE,
}
