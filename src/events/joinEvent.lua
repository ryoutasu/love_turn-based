-- local JoinEvent = Class{}

-- function JoinEvent:init(player, character)
--     self.steps = {
--         [1] = {
--             text = character.name .. ' wishes to join your party. Will you accept him?',
--             buttons = {
--                 { text = 'Yes', action = function ()
--                     table.insert(player.party, character)
--                     return 2
--                 end },
--                 { text = 'No', action = function () return 3 end }
--             }
--         },
--         [2] = {
--             text = 'You accepting ' .. character.name .. ' into your party!',
--             buttons = {
--                 { text = 'Exit', action = function () return 0 end }
--             }
--         },
--         [3] = {
--             text = 'You refuse to accept ' .. character.name .. ' to your party.',
--             buttons = {
--                 { text = 'Exit', action = function () return 0 end }
--             }
--         }
--     }
-- end

-- return JoinEvent
local characters = require 'src.characters'

return function (player)
    local character = 'Gato'

    return {
        [1] = {
            text = character .. ' wishes to join your party. Will you accept him?',
            buttons = {
                { text = 'Yes', action = function ()
                    player:addCharacter(character)
                    return 2
                end },
                { text = 'No', action = function () return 3 end }
            }
        },
        [2] = {
            text = 'You accepting ' .. character .. ' into your party!',
            buttons = {
                { text = 'Exit', action = function () return 0 end }
            }
        },
        [3] = {
            text = 'You refuse to accept ' .. character .. ' to your party.',
            buttons = {
                { text = 'Exit', action = function () return 0 end }
            }
        }
    }
end
