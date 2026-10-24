local RunState = require 'src.states.run_state'

return function(player)
    local buff_battles = 3
    local buff_pct     = 20

    return {
        title = "Cursed Idol",
        steps = {
            [1] = {
                text = "A jade idol sits on a stone plinth. It hums with a hunger you can feel in your teeth.",
                buttons = {
                    { text = "Touch the idol", action = function() return 2 end },
                    { text = "Walk away",      action = function() return 5 end },
                }
            },
            [2] = {
                text = "The idol whispers in a language older than words. Two pacts are offered.",
                buttons = {
                    { text = "+" .. buff_pct .. "% damage for " .. buff_battles .. " battles\n(-1 max HP, permanent)",
                      action = function()
                        -- Временный бафф (3 боя)
                        RunState:addModifier({
                            id       = 'idol_power',
                            scope    = 'run',
                            stat     = 'damage',
                            op       = 'mul',
                            value    = 1 + buff_pct / 100,
                            source   = 'event_cursed_idol',
                            duration = { type = 'battle', value = buff_battles },
                            stack    = 'refresh',
                        })
                        -- Постоянная жертва: HP отнимается у одного случайного
                        local c = player.charactersActive[1]
                        if c then
                            c.max_health = math.max(1, c.max_health - 1)
                            c.health     = math.min(c.health, c.max_health)
                        end
                        return 3
                    end },
                    { text = "Refuse the whispers", action = function() return 4 end },
                }
            },
            [3] = {
                text = "Power floods your veins. The idol shatters — its hunger sated.",
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
            [4] = {
                text = "You pull your hand back. The whispers grow angry, then fade.",
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
            [5] = {
                text = "You leave the idol behind. Its hum fades with distance.",
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
        }
    }
end