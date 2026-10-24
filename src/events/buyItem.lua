local Items    = require 'src.items'
local RunState = require 'src.states.run_state'

local OFFERS = {
    { name = 'healPotion',   costPer = 20 },
    { name = 'energyPotion', costPer = 15 },
    { name = 'powerup',      costPer = 40 },
}

local function filtered()
    local out = {}
    for _, entry in ipairs(OFFERS) do
        if Items[entry.name] then
            table.insert(out, entry)
        end
    end
    return out
end

return function(player)
    local offers = filtered()
    if #offers == 0 then
        return {
            title = "Traveling Merchant",
            steps = {
                [1] = {
                    text = "A merchant passes by, but has nothing you need.",
                    buttons = { { text = "Continue", action = function() return 0 end } },
                }
            }
        }
    end

    local offer    = offers[RunState:randomInt(1, #offers)]
    local item     = Items[offer.name]
    local quantity = RunState:randomInt(1, 2)
    local cost     = quantity * offer.costPer

    return {
        title = "Traveling Merchant",
        steps = {
            [1] = {
                text = string.format(
                    "A traveler offers %d × %s for %d gold.\n\nWill you accept?",
                    quantity, item.name, cost),
                buttons = {
                    { text = "Accept offer", action = function()
                        local gold = player.currencies.gold or 0
                        if gold < cost then
                            return 4
                        end
                        player:addItem(offer.name, quantity)
                        player:addCurrency('gold', -cost)
                        PlaySound(CoinsSound)
                        return 2
                    end },
                    { text = "Decline", action = function() return 3 end },
                }
            },
            [2] = {
                text = function()
                    return string.format(
                        "You bought %d × %s for %d gold.",
                        quantity, item.name, cost)
                end,
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
            [3] = {
                text = "You decline the offer and walk away.",
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
            [4] = {
                text = function()
                    return string.format(
                        "You reach for your coin purse but find only %d gold — not enough for %d.",
                        player.currencies.gold or 0, cost)
                end,
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
        }
    }
end