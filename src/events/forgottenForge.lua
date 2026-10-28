local RunState  = require 'src.states.run_state'
local Character = require 'src.character'

local function get_active(player)
    local list = {}
    local size = player.charactersActiveSize or #player.charactersActive
    for i = 1, size do
        if player.charactersActive[i] then
            table.insert(list, player.charactersActive[i])
        end
    end
    return list
end

return function(player)
    local active = get_active(player)
    if #active == 0 then
        return {
            title = "Forgotten Forge",
            steps = {
                [1] = {
                    text = "An ancient forge smolders. But no creature walks with you.",
                    buttons = { { text = "Leave", action = function() return 0 end } },
                }
            }
        }
    end

    -- Роллим, какой апгрейд выпадет
    local upgrade_roll = RunState:random()
    local upgrade_kind = (upgrade_roll < 0.4 and 'damage')
                      or (upgrade_roll < 0.7 and 'health')
                      or (upgrade_roll < 0.9 and 'armor')
                      or 'all'

    local upgrade_values = {
        damage = { stat = 'damage',     value = 2, label = "+2 damage" },
        health = { stat = 'max_health', value = 8, label = "+8 max HP" },
        armor  = { stat = 'armor',      value = 2, label = "+2 armor" },
        all    = { stat = 'all',        value = 1, label = "+1 damage, +1 armor, +4 max HP" },
    }

    local chosen_upgrade = upgrade_values[upgrade_kind]

    local buttons = {}
    for _, c in ipairs(active) do
        table.insert(buttons, {
            text = "Forge " .. c.name,
            action = function()
                if upgrade_kind == 'all' then
                    Character.applyModifier(c, {
                        id       = 'forge_all_' .. RunState:randomInt(1000, 9999),
                        scope    = 'permanent',
                        stat     = 'damage',
                        op       = 'add',
                        value    = 1,
                        source   = 'event_forgotten_forge',
                    })
                    Character.applyModifier(c, {
                        id       = 'forge_all_armor_' .. RunState:randomInt(1000, 9999),
                        scope    = 'permanent',
                        stat     = 'armor',
                        op       = 'add',
                        value    = 1,
                        source   = 'event_forgotten_forge',
                    })
                    Character.applyModifier(c, {
                        id       = 'forge_all_hp_' .. RunState:randomInt(1000, 9999),
                        scope    = 'permanent',
                        stat     = 'max_health',
                        op       = 'add',
                        value    = 4,
                        source   = 'event_forgotten_forge',
                    })
                else
                    Character.applyModifier(c, {
                        id       = 'forge_' .. upgrade_kind .. '_' .. RunState:randomInt(1000, 9999),
                        scope    = 'permanent',
                        stat     = chosen_upgrade.stat,
                        op       = 'add',
                        value    = chosen_upgrade.value,
                        source   = 'event_forgotten_forge',
                    })
                end
                return 2
            end
        })
    end
    table.insert(buttons, { text = "Leave the forge", action = function() return 3 end })

    return {
        title = "Forgotten Forge",
        steps = {
            [1] = {
                text = "An ancient forge still glows with embers.\n\n"
                     .. "The anvil hums — it could strengthen one of your creatures (" ..
                     chosen_upgrade.label .. ").",
                buttons = buttons,
            },
            [2] = {
                text = function()
                    return "The forge's fire surges.\n\nPermanent: " .. chosen_upgrade.label
                        .. " (until the run ends)."
                end,
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
            [3] = {
                text = "You leave the forge to its slow burn.",
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
        }
    }
end