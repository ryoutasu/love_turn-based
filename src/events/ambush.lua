local RunState = require 'src.states.run_state'

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
            title = "Ambush!",
            steps = {
                [1] = {
                    text = "Shadows move in the trees. You are alone — nothing to defend.",
                    buttons = { { text = "Continue", action = function() return 0 end } },
                }
            }
        }
    end

    -- Заранее роллим исход
    local roll = RunState:random()
    -- 60%: успешная оборона + трофей
    -- 30%: оборона, но урон
    -- 10%: засада удалась, золото украдено
    local outcome = (roll < 0.6 and 'win')
                 or (roll < 0.9 and 'costly')
                 or 'loss'

    local gold = RunState:randomInt(10, 30)

    return {
        title = "Ambush!",
        steps = {
            [1] = {
                text = "Shapes move between the trees. Something is stalking you.",
                buttons = {
                    { text = "Stand and fight", action = function() return 2 end },
                    { text = "Flee",            action = function() return 3 end },
                }
            },
            [2] = {
                text = function()
                    if outcome == 'win' then
                        return "You fight off the attackers!\n\nAmong the fallen you find "
                            .. gold .. " gold."
                    elseif outcome == 'costly' then
                        return "You drive them off — but not without cost.\n\n"
                            .. "Blood stains the road, and the air tastes of copper."
                    else
                        return "They were faster than you.\n\n"
                            .. "By the time the dust settles, " .. gold .. " gold is gone."
                    end
                end,
                buttons = { { text = "Continue", action = function() return 0 end } },
                on_enter = function()
                    if outcome == 'win' then
                        player:addCurrency('gold', gold)
                        PlaySound(CoinsSound)
                    elseif outcome == 'costly' then
                        local c = active[RunState:randomInt(1, #active)]
                        c.health = math.max(1, c.health - RunState:randomInt(8, 15))
                    else
                        local current = player.currencies.gold or 0
                        player:addCurrency('gold', -math.min(gold, current))
                    end
                end,
            },
            [3] = {
                text = "You run. Branches whip your face. After an hour, the footsteps stop.",
                buttons = {
                    { text = "Continue", action = function()
                        local c = active[RunState:randomInt(1, #active)]
                        c.health = math.max(1, c.health - 5)
                        return 0
                    end }
                },
            },
        }
    }
end