-- Payoff half, part 2: the door opens (or does not).
-- Consumes the persistent key and marks the payoff as spent, closing
-- the Chekhov thread cleanly.

local PlayerMetaStory = require 'src.player_meta_story'
local RunState        = require 'src.states.run_state'

local KEY = 'moon_key'

return {
    id = 'moon_door',
    slots = {},

    terminal = true,

    generate = function(ctx)
        local camp = ctx.campaign
        local player = ctx.player
        local has_key = PlayerMetaStory.has_story_key(camp, KEY)

        -- No key: the door is simply locked. Hard block, no consolation,
        -- because the player had a run to carry the key here.
        if not has_key then
            return {
                title = "A door in the open",
                steps = {
                    {
                        text = "The lock is a crescent and the crescent is empty. "
                            .. "The door does not care how far you have come.",
                        buttons = {
                            { text = "Turn back.", action = function() return 0 end },
                        },
                    },
                },
            }
        end

        return {
            title = "The door",
            steps = {
                {
                    text = "The key fits. Of course it does — it was made for this "
                        .. "and you carried it here across a road you no longer "
                        .. "remember choosing.\n\n"
                        .. "The door opens onto a small room, and the room holds "
                        .. "one thing: a hollow the shape of a beast, and in it, "
                        .. "still breathing, something asleep.",
                    buttons = {
                        {
                            text = "Reach in.",
                            action = function(player)
                                -- Consume the key: this thread is spent.
                                PlayerMetaStory.consume_story_key(camp, KEY)

                                -- Reward: a real creature, not a stat buff.
                                -- The genre's promise is "you get a monster",
                                -- so the payoff must be a monster.
                                local name = 'Emberpuff'
                                local ok, Character = pcall(require, 'src.character')
                                local Characters = require 'src.characters'
                                if ok and Characters then
                                    -- Pick something the player does not own yet,
                                    -- deterministically.
                                    local owned = {}
                                    for _, list in ipairs({
                                        player.charactersActive,
                                        player.charactersSpare,
                                        player.charactersStables,
                                    }) do
                                        for _, c in ipairs(list or {}) do
                                            owned[c.name] = true
                                        end
                                    end
                                    local keys = {}
                                    for k in pairs(Characters) do
                                        if not owned[k] then keys[#keys + 1] = k end
                                    end
                                    table.sort(keys)
                                    if #keys > 0 then
                                        name = keys[1 + (ctx.rngInt and ctx.rngInt(0, #keys - 1) or 0)]
                                    end
                                end

                                player:addCharacter(name)
                                RunState:addUnlock('moon_reward')
                                Tagtext:add("Something wakes.",
                                    love.mouse.getX(), love.mouse.getY(),
                                    1, 30, { 1, 1, 1 })
                                return 0
                            end,
                        },
                        {
                            text = "Close the door. It slept this long.",
                            action = function(player)
                                -- Leaving it unopened still spends the key:
                                -- the choice is moral, not mechanical.
                                PlayerMetaStory.consume_story_key(camp, KEY)
                                RunState:addUnlock('moon_left_closed')
                                return 0
                            end,
                        },
                    },
                },
            },
        }
    end,
}
