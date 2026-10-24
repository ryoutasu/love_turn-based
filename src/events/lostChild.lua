local RunState = require 'src.states.run_state'

return function(player)
    -- Случайное вознаграждение за доброту
    local reward_gold    = RunState:randomInt(20, 50)
    local reward_shard_q = RunState:randomInt(1, 2)

    local shard_types = { 'wild', 'mystic', 'mechanic', 'ancient', 'chaos' }
    local reward_shard = shard_types[RunState:randomInt(1, #shard_types)]

    return {
        title = "Lost Child",
        steps = {
            [1] = {
                text = "A child sits by the road, crying.\n\n"
                     .. "\"I can't find my village,\" she whispers.\n\n"
                     .. "The sun is setting.",
                buttons = {
                    { text = "Help her find home (delays you)",
                      action = function()
                        -- Теряете ресурсы (время), но получаете благодарность
                        player:addCurrency('gold', reward_gold)
                        player:addShard(reward_shard, reward_shard_q)
                        PlaySound(CoinsSound)
                        return 2
                    end },
                    { text = "Give her a healing potion and move on",
                      action = function()
                        -- Тратите предмет, но получаете меньше
                        local has_potion = false
                        for _, slot in ipairs(player.inventory) do
                            if slot.item.id == 'healPotion' and slot.quantity > 0 then
                                has_potion = true
                                break
                            end
                        end
                        if not has_potion then return 3 end
                        -- Списываем 1 зелье
                        for i, slot in ipairs(player.inventory) do
                            if slot.item.id == 'healPotion' then
                                slot.quantity = slot.quantity - 1
                                if slot.quantity <= 0 then
                                    table.remove(player.inventory, i)
                                end
                                break
                            end
                        end
                        player:addCurrency('gold', math.floor(reward_gold * 0.5))
                        return 4
                    end },
                    { text = "Ignore her and keep walking",
                      action = function() return 5 end },
                }
            },
            [2] = {
                text = function()
                    return string.format(
                        "You walk with her for an hour. Her village appears at dusk.\n\n"
                        .. "Her mother presses %d gold and a strange shard into your hands.",
                        reward_gold)
                end,
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
            [3] = {
                text = "You reach for a potion — your pack is empty. You have nothing to give her.",
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
            [4] = {
                text = function()
                    return string.format(
                        "You give her a potion and point toward the village lights.\n\n"
                        .. "She runs off. A few minutes later, a coin purse lands at your feet: %d gold.",
                        math.floor(reward_gold * 0.5))
                end,
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
            [5] = {
                text = "You walk past. The crying fades behind you.\n\nThe road is long, and the night is cold.",
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
        }
    }
end