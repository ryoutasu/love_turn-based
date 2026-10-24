local RunState = require 'src.states.run_state'
local Stats    = require 'src.stats'

local HEAL_AMOUNT = 30

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

local function max_hp(char)
    return Stats.new(char, RunState:getModifiers(), {}):get('max_health')
end

local function hp_text(char)
    return string.format("%s (%d/%d)",
        char.name, math.floor(char.health), math.floor(max_hp(char)))
end

local function party_status(player)
    local list = get_active(player)
    local lines = {}
    for _, c in ipairs(list) do
        table.insert(lines, hp_text(c))
    end
    return table.concat(lines, "\n")
end

return function(player)
    local active   = get_active(player)
    local wounded  = {}
    for _, c in ipairs(active) do
        if c.health < max_hp(c) then
            table.insert(wounded, c)
        end
    end

    -- Никто не ранен — короткий исход
    if #wounded == 0 then
        return {
            title = "Healing Spring",
            steps = {
                [1] = {
                    text = "You discover a glowing spring.\n\nYour party is unharmed — nothing to heal here.",
                    buttons = { { text = "Continue", action = function() return 0 end } },
                }
            }
        }
    end

    -- Кнопка на каждого раненого
    local buttons = {}
    for _, c in ipairs(wounded) do
        table.insert(buttons, {
            text = "Heal " .. c.name,
            action = function()
                local m = max_hp(c)
                c.health = math.min(m, c.health + HEAL_AMOUNT)
                return 2
            end
        })
    end
    table.insert(buttons, { text = "Leave spring untouched", action = function() return 3 end })

    return {
        title = "Healing Spring",
        steps = {
            [1] = {
                text = "You discover a healing spring. The water glows with mysterious energy.\n\n"
                     .. "Party status:\n" .. party_status(player),
                buttons = buttons,
            },
            [2] = {
                text = function()
                    return "The spring's energy restores " .. HEAL_AMOUNT
                        .. " HP!\n\nCurrent status:\n" .. party_status(player)
                end,
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
            [3] = {
                text = "You leave the spring untouched — the glow fades behind you.",
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
        }
    }
end