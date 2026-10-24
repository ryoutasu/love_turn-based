local Items = require 'src.items'

return function(player)
    local gold = math.random(20, 40)
    local damage = math.random(5, 15)
    
    local lootTable = {
        { name = 'healPotion', chance = 0.6, quantity = 1 },
        { name = 'powerup', chance = 0.4, quantity = 1 }
    }

    local function rollLoot()
        for _, item in ipairs(lootTable) do
            if math.random() <= item.chance then
                return item.name, item.quantity
            end
        end
        return nil
    end

    return {
        title = "Abandoned Camp",
        steps = {
            [1] = {
                text = 'You discover an abandoned camp. The embers are still warm...',
                buttons = {
                    { text = 'Search tent', action = function() return 2 end },
                    { text = 'Check supplies', action = function() return 3 end },
                    { text = 'Leave camp', action = function() return 4 end }
                }
            },
            [2] = {
                text = 'The tent seems safe to search...',
                buttons = {
                    { text = 'Search carefully', action = function()
                        local itemName, quantity = rollLoot()
                        if itemName then
                            player:addItem(itemName, quantity)
                            return 5
                        else
                            return 6
                        end
                    end },
                    { text = 'Back away', action = function() return 4 end }
                }
            },
            [3] = {
                text = 'There\'s a supply cache nearby.',
                buttons = {
                    { text = 'Take supplies', action = function()
                        player:addCurrency('gold', gold)
                        return 7
                    end },
                    { text = 'Leave it', action = function() return 4 end }
                }
            },
            [4] = {
                text = 'You decide to leave the camp undisturbed.',
                buttons = {
                    { text = 'Continue', action = function() return 0 end }
                }
            },
            [5] = {
                text = 'You found useful supplies!',
                buttons = {
                    { text = 'Continue', action = function() return 0 end }
                }
            },
            [6] = {
                text = 'The tent is empty...',
                buttons = {
                    { text = 'Continue', action = function() return 0 end }
                }
            },
            [7] = {
                text = 'You found ' .. gold .. ' gold in the supplies!',
                buttons = {
                    { text = 'Continue', action = function() return 0 end }
                }
            }
        }
    }
end