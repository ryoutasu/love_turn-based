local Items    = require 'src.items'
local RunState = require 'src.states.run_state'

-- Предметы, которые можно найти. Только map-usable.
local LOOT_POOL = {
    { name = 'healPotion',   minQty = 1, maxQty = 3 },
    { name = 'energyPotion', minQty = 1, maxQty = 3 },
    { name = 'powerup',      minQty = 1, maxQty = 1 },
}

-- Отфильтровать то, чего нет в ItemList
local function filtered_pool()
    local out = {}
    for _, entry in ipairs(LOOT_POOL) do
        if Items[entry.name] then
            table.insert(out, entry)
        end
    end
    return out
end

return function(player)
    local pool = filtered_pool()
    if #pool == 0 then
        return {
            title = "Found Supplies",
            steps = {
                [1] = {
                    text = "You find a stash of supplies, but nothing useful remains.",
                    buttons = { { text = "Leave", action = function() return 0 end } },
                }
            }
        }
    end

    local pick     = pool[RunState:randomInt(1, #pool)]
    local item     = Items[pick.name]
    local quantity = RunState:randomInt(pick.minQty, pick.maxQty)

    return {
        title = "Found Supplies",
        steps = {
            [1] = {
                text = string.format(
                    "You stumble upon a small cache.\n\nInside: %s ×%d.\n\nDo you take it?",
                    item.name, quantity),
                buttons = {
                    { text = "Take it", action = function()
                        player:addItem(pick.name, quantity)
                        PlaySound(CoinsSound)
                        return 2
                    end },
                    { text = "Leave it", action = function() return 3 end },
                }
            },
            [2] = {
                text = string.format("You pack the %s into your bag.", item.name),
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
            [3] = {
                text = "You decide not to disturb the cache and move on.",
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
        }
    }
end