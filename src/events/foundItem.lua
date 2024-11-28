local Items = require 'src.items'

return function (player)
    local itemName = 'healPotion'
    local item = Items[itemName]
    local quantity = math.random(1, 2)
    
    return {
        [1] = {
            text = 'You found ' .. quantity .. ' of ' .. item.name .. '. Will you take it?',
            buttons = {
                { text = 'Yes', action = function ()
                    -- player:addCharacter(character)
                    player:addItem(itemName, quantity)
                    return 2
                end },
                { text = 'No', action = function () return 3 end }
            }
        },
        [2] = {
            text = 'You take ' .. quantity .. ' of ' .. item.name .. '.',
            buttons = {
                { text = 'Exit', action = function () return 0 end }
            }
        },
        [3] = {
            text = 'You leave without taking items.',
            buttons = {
                { text = 'Exit', action = function () return 0 end }
            }
        }
    }
end
