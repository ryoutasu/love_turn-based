local RunState = require 'src.states.run_state'

return function(player)
    -- Стоимость фиксирована, но выбор — что взять
    local gold_cost = 50
    local shard_amt = 3
    local essence_amt = 2

    -- Случайный тип осколка
    local shard_types = { 'wild', 'mystic', 'mechanic', 'ancient', 'chaos' }
    local shard_type = shard_types[RunState:randomInt(1, #shard_types)]

    local SHARD_LABELS = {
        wild = 'Wild', mystic = 'Mystic', mechanic = 'Mechanic',
        ancient = 'Ancient', chaos = 'Chaos',
    }

    return {
        title = "Traveling Scholar",
        steps = {
            [1] = {
                text = "A robed scholar perches on a fallen log, sorting strange stones.\n\n"
                     .. "\"Knowledge has a price,\" she says. \"So do these.\"",
                buttons = {
                    { text = "Buy " .. shard_amt .. " " .. SHARD_LABELS[shard_type] .. " shards (" .. gold_cost .. "g)",
                      action = function()
                        if (player.currencies.gold or 0) < gold_cost then return 4 end
                        player:addCurrency('gold', -gold_cost)
                        player:addShard(shard_type, shard_amt)
                        PlaySound(CoinsSound)
                        return 2
                    end },
                    { text = "Buy " .. essence_amt .. " essence (" .. gold_cost .. "g)",
                      action = function()
                        if (player.currencies.gold or 0) < gold_cost then return 4 end
                        player:addCurrency('gold', -gold_cost)
                        player:addEssence(essence_amt)
                        PlaySound(CoinsSound)
                        return 3
                    end },
                    { text = "Walk away", action = function() return 5 end },
                }
            },
            [2] = {
                text = function()
                    return string.format(
                        "She hands you %d %s shards.\n\n\"Spend them wisely.\"",
                        shard_amt, SHARD_LABELS[shard_type])
                end,
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
            [3] = {
                text = function()
                    return string.format(
                        "She pours %d drops of glowing liquid into a small vial.",
                        essence_amt)
                end,
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
            [4] = {
                text = function()
                    return string.format(
                        "\"Come back when you have %d gold,\" she says without looking up.",
                        gold_cost)
                end,
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
            [5] = {
                text = "You leave the scholar to her stones.",
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
        }
    }
end