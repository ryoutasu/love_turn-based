local Items    = require 'src.items'
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

-- Урон не убивает: клампим до 1 HP.
local function hurt_random(player, amount)
    local list = get_active(player)
    if #list == 0 then return nil end
    local c = list[RunState:randomInt(1, #list)]
    c.health = math.max(1, c.health - amount)
    return c
end

return function(player)
    -- Предроллим всё заранее, чтобы текст был детерминирован.
    local gold_small = RunState:randomInt(10, 20)
    local gold_large = RunState:randomInt(40, 60)
    local damage     = RunState:randomInt(10, 25)

    -- Три исхода «рискнуть»:
    --   50% — сокровище + золото, без урона
    --   30% — сокровище + золото + урон
    --   20% — урон, без награды
    local risk_roll  = RunState:random()
    local risk_kind  = (risk_roll < 0.5 and 'lucky')
                    or (risk_roll < 0.8 and 'costly')
                    or 'unlucky'

    local function do_risk()
        local lines = {}

        if risk_kind ~= 'unlucky' then
            player:addCurrency('gold', gold_large)
            table.insert(lines, string.format("Found %d gold.", gold_large))

            -- 60% шанс, что вместе с золотом выпадет предмет
            if RunState:random() < 0.6 and Items['healPotion'] then
                local qty = RunState:randomInt(1, 2)
                player:addItem('healPotion', qty)
                table.insert(lines, string.format("Found %s ×%d.", Items['healPotion'].name, qty))
            end
        end

        if risk_kind ~= 'lucky' then
            local victim = hurt_random(player, damage)
            if victim then
                table.insert(lines, string.format("%s took %d damage from cave guardians.",
                    victim.name, damage))
            end
        end

        if #lines == 0 then
            table.insert(lines, "The chamber is empty — but the echoes wake something in the dark.")
        end

        return table.concat(lines, "\n")
    end

    local risk_text = do_risk()

    return {
        title = "Mystery Cave",
        steps = {
            [1] = {
                text = "A dark cave mouth looms before you. Strange echoes emanate from within...",
                buttons = {
                    { text = "Enter deeply",       action = function() return 2 end },
                    { text = "Explore entrance",   action = function() return 3 end },
                    { text = "Leave it alone",     action = function() return 6 end },
                }
            },
            [2] = {
                text = "Deep in the cave, you find ancient treasures, but danger lurks...",
                buttons = {
                    { text = "Risk taking treasure", action = function()
                        -- Эффект уже применён при формировании risk_text
                        return 4
                    end },
                    { text = "Retreat", action = function() return 6 end },
                }
            },
            [3] = {
                text = "The cave entrance contains abandoned supplies left by earlier travelers.",
                buttons = {
                    { text = "Search carefully", action = function() return 5 end },
                    { text = "Leave", action = function() return 6 end },
                }
            },
            [4] = {
                text = risk_text,
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
            [5] = {
                text = function()
                    -- Применяем золото только когда игрок реально нажал кнопку.
                    -- Но чтобы текст был корректен, мы «применяем» заранее — здесь
                    -- только показ. Эффект выдан в action выше.
                    return string.format("You find %d gold near the entrance.", gold_small)
                end,
                buttons = {
                    { text = "Continue", action = function()
                        return 0
                    end }
                },
                on_enter = function()
                    player:addCurrency('gold', gold_small)
                    PlaySound(CoinsSound)
                end,
            },
            [6] = {
                text = "You leave the cave behind.",
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
        }
    }
end