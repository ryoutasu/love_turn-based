-- Giver half of the Chekhov's-gun thread: the key is found here.
-- Grants the persistent story key and registers the payoff scene.

local RunState = require 'src.states.run_state'
local PlayerMetaStory = require 'src.player_meta_story'

local KEY          = 'moon_key'
local PAYOFF_SCENE = 'moon_door'

return {
    id = 'moon_key_find',
    slots = {},

    generate = function(ctx)
        local camp = ctx.campaign

        -- Three variants so the giver does not look identical every campaign.
        local variants = {
            {
                title = "Under the bridge",
                text  = "The bridge has been broken longer than anyone remembers. "
                     .. "In the mud under it, half-buried, something catches what "
                     .. "light there is: a key of pale, cold metal, shaped like a "
                     .. "crescent that has been bent straight.",
                take  = "Take the key.",
                leave = "Leave it in the mud.",
            },
            {
                title = "The drowned temple",
                text  = "The water is shallow here, and beneath it: steps, a lintel, "
                     .. "the edge of a door long gone. Wedged in the lintel, a key "
                     .. "of pale metal, cold enough to sting.",
                take  = "Pry the key loose.",
                leave = "Leave the temple alone.",
            },
            {
                title = "A hand in the roots",
                text  = "An old tree has swallowed something. Among the roots, still "
                     .. "gripped by a hand that is no longer a hand: a key of pale "
                     .. "metal, warm, as if it had been held a moment ago.",
                take  = "Take the key.",
                leave = "Let the tree keep it.",
            },
        }

        local v = variants[1]
        -- Deterministic pick from the run's RNG stream, so the same seed
        -- always shows the same place.
        if ctx.rngInt then
            local ok, n = pcall(ctx.rngInt, 1, #variants)
            if ok and type(n) == 'number' then
                v = variants[n] or variants[1]
            end
        end

        return {
            title = v.title,
            steps = {
                {
                    text = v.text,
                    buttons = {
                        {
                            text = v.take,
                            action = function(player)
                                -- Persistent: survives the run, unlike RunState.
                                PlayerMetaStory.grant_story_key(camp, KEY)
                                PlayerMetaStory.register_key_thread(camp, KEY, {
                                    giver_scene  = 'moon_key_find',
                                    payoff_scene = PAYOFF_SCENE,
                                    locked_hint  = "A door of pale wood. Its lock is a "
                                                .. "crescent, and empty.",
                                })
                                -- Also unlock within this run, in case the
                                -- payoff node is generated in the same run.
                                RunState:addUnlock(KEY)
                                Tagtext:add("A pale key.",
                                    love.mouse.getX(), love.mouse.getY(),
                                    1, 30, { 1, 1, 1 })
                                return 0
                            end,
                        },
                        {
                            text = v.leave,
                            action = function() return 0 end,
                        },
                    },
                },
            },
        }
    end,
}
