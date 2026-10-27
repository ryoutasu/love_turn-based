local RunState = require 'src.states.run_state'
local Stats    = require 'src.stats'

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
    return Stats(char, RunState:getModifiers(), {}):get('max_health')
end

return function(player)
    local gold      = RunState:randomInt(30, 50)
    local damage    = RunState:randomInt(10, 20)
    local buff      = RunState:randomInt(5, 10)
    local hp_loss   = 10

    local active = get_active(player)
    if #active == 0 then
        return {
            title = "Dark Shrine",
            steps = {
                [1] = {
                    text = "A dark shrine radiates ominous energy. You have no one to offer.",
                    buttons = { { text = "Leave", action = function() return 0 end } },
                }
            }
        }
    end

    -- Выбираем жертву заранее (детерминированно — для текста)
    local victim   = active[RunState:randomInt(1, #active)]
    local victim2  = active[RunState:randomInt(1, #active)]

    return {
        title = "Dark Shrine",
        steps = {
            [1] = {
                text = "A dark shrine radiates ominous energy. Ancient runes promise power at a cost.",
                buttons = {
                    { text = "Approach shrine", action = function() return 2 end },
                    { text = "Leave",           action = function() return 5 end },
                }
            },
            [2] = {
                text = "Three sigils glow on the shrine. Each demands a price.",
                buttons = {
                    { text = "Power (+" .. buff .. " dmg, -" .. hp_loss .. " max HP)",
                      action = function()
                        victim.damage     = victim.damage + buff
                        victim.max_health = math.max(1, victim.max_health - hp_loss)
                        victim.health     = math.min(victim.health, victim.max_health)
                        return 3
                    end },
                    { text = "Wealth (+" .. gold .. "g, " .. victim2.name .. " -" .. damage .. " HP)",
                      action = function()
                        player:addCurrency('gold', gold)
                        victim2.health = math.max(1, victim2.health - damage)
                        PlaySound(CoinsSound)
                        return 4
                    end },
                    { text = "Step back", action = function() return 5 end },
                }
            },
            [3] = {
                text = function()
                    return string.format(
                        "Dark energy floods through %s.\n\nDamage +%d, max HP -%d.",
                        victim.name, buff, hp_loss)
                end,
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
            [4] = {
                text = function()
                    return string.format(
                        "You receive %d gold.\n%s staggers as the shrine drains %d HP.",
                        gold, victim2.name, damage)
                end,
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
            [5] = {
                text = "You step away from the shrine. The runes dim and fade.",
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
        }
    }
end