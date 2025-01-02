
local Items = require 'src.items'
local itemTable = {
    { name = 'healPotion', chance = 0.5, minQuantity = 1, maxQuantity = 3, costPerItem = '20' },
    { name = 'powerup', chance = 0.5, minQuantity = 1, maxQuantity = 2, costPerItem = '30' },
}

return function (player)
    local t = itemTable[math.random(#itemTable)]
    local item = Items[t.name]
    local quantity = math.random(t.minQuantity, t.maxQuantity)
    local cost = quantity * t.costPerItem
    
    return {
        [1] = {
            text = 'You meet a person, who offers you ' .. quantity .. ' of ' .. item.name .. ' for ' .. cost .. ' gold.\nWill you accept an offer?',
            buttons = {
                { text = 'Yes', action = function ()
                    if player.currencies.gold < cost then
                        return 4
                    end

                    player:addItem(t.name, quantity)
                    player:addCurrency('gold', -cost)
                    PlaySound(CoinsSound)
                    return 2
                end },
                { text = 'No', action = function () return 3 end }
            }
        },
        [2] = {
            text = 'You bought ' .. quantity .. ' of ' .. item.name .. ' for ' .. cost .. ' gold.',
            buttons = {
                { text = 'Exit', action = function () return 0 end }
            }
        },
        [3] = {
            text = 'You leave without taking items.',
            buttons = {
                { text = 'Exit', action = function () return 0 end }
            }
        },
        [4] = {
            text = 'You don\'t have enough gold to afford it.',
            buttons = {
                { text = 'Exit', action = function () return 0 end }
            }
        }
    }
end
