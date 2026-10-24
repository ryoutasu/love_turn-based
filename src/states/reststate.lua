local Stats     = require 'src.stats'
local RunState  = require 'src.states.run_state'

local titleFont = love.graphics.newFont(40)
local nameFont  = love.graphics.newFont(16)
local smallFont = love.graphics.newFont(12)

local RestState = {}

-- ================================================================
-- Жизненный цикл
-- ================================================================

function RestState:init()
    self.rested   = false
    self.complete = false
end

function RestState:enter(from, args)
    self.player   = args.player
    self.rested   = false
    self.complete = false
end

function RestState:leave() end

-- ================================================================
-- Логика
-- ================================================================

function RestState:_healAll(kind, ratio)
    local function heal_list(list)
        for _, c in ipairs(list) do
            if c then
                local stats  = Stats(c, RunState:getModifiers(), {})
                local max_hp = stats:get('max_health')
                local max_en = stats:get('max_energy')

                if kind == 'hp' or kind == 'both' then
                    c.health = math.min(c.health + max_hp * ratio, max_hp)
                end
                if kind == 'energy' or kind == 'both' then
                    c.energy = math.min(c.energy + max_en * ratio, max_en)
                end
            end
        end
    end

    heal_list(self.player.charactersActive)
    heal_list(self.player.charactersSpare)

    self.rested   = true
    self.complete = true
    PlaySound(ButtonClickSound)
end

function RestState:_getAll()
    local all = {}
    for _, c in ipairs(self.player.charactersActive) do
        if c then table.insert(all, { c = c, is_active = true  }) end
    end
    for _, c in ipairs(self.player.charactersSpare) do
        if c then table.insert(all, { c = c, is_active = false }) end
    end
    return all
end

-- ================================================================
-- Update: кнопки через UI
-- ================================================================

function RestState:update(dt)
end

-- ================================================================
-- Draw: карточки персонажей
-- ================================================================

function RestState:draw()
    -- Заголовок
    UI.setStyle({})
    UI.setFont(titleFont)
    UI.nextPosition("TOP", "root")
    UI.text(3, 33, "Rest", "TOP", { 0, 0, 0, 1 })
    UI.text(0, 30, "Rest", "TOP", { 1, 1, 1, 1 })

    local all = self:_getAll()
    if #all == 0 then return end

    local card_w, card_h = 150, 210
    local gap    = 20
    local total  = #all * card_w + (#all - 1) * gap
    local sw     = love.graphics.getWidth()
    local sh     = love.graphics.getHeight()
    local x      = (sw - total) / 2
    local y      = 110

    for _, entry in ipairs(all) do
        self:_drawCard(entry, x, y, card_w, card_h)
        x = x + card_w + gap
    end

    if not self.rested then
        -- Три варианта лечения
        local bw, bh = 320, 140
        local gap    = 20
        local total  = bw * 3 + gap * 2
        local x      = (sw - total) / 2
        local y      = sh - 240

        UI.setStyle({
            draw_border      = true,
            border_color     = { 0, 0, 0, 1 },
            background_color = { 0.55, 0.75, 0.55, 1 },
        })
        UI.nextPosition("TOPLEFT", "root")
        if UI.button("rest_hp", x, y, bw, bh, "", "TOPLEFT") then
            self:_healAll('hp', 0.5)
        end
        UI.nextPosition("CENTER")
        UI.text(0, -2, "Restore HP", "BOTTOM", { 1, 1, 1, 1 })
        UI.text(0, 2, "(+50%)", "TOP", { 1, 1, 1, 1 })

        x = x + bw + gap
        UI.nextPosition("TOPLEFT", "root")
        if UI.button("rest_en", x, y, bw, bh, "", "TOPLEFT") then
            self:_healAll('energy', 0.5)
        end
        UI.nextPosition("CENTER")
        UI.text(0, -2, "Meditate", "BOTTOM", { 1, 1, 1, 1 })
        UI.text(0, 2, "(+50% Energy)", "TOP", { 1, 1, 1, 1 })

        x = x + bw + gap
        UI.nextPosition("TOPLEFT", "root")
        if UI.button("rest_both", x, y, bw, bh, "", "TOPLEFT") then
            self:_healAll('both', 0.25)
        end
        UI.nextPosition("CENTER")
        UI.text(0, -2, "Both", "BOTTOM", { 1, 1, 1, 1 })
        UI.text(0, 2, "(+25% each)", "TOP", { 1, 1, 1, 1 })
    else
        -- Возврат
        UI.setStyle({
            draw_border      = true,
            border_color     = { 0, 0, 0, 1 },
            background_color = { 0.6, 0.6, 0.8, 1 },
        })
        UI.nextPosition("BOTTOM", "root")
        if UI.button("rest_return", 0, -50, 300, 80, "Return", "BOTTOM") then
            Gamestate.push(FadeInState, {
                color = { 1, 1, 1, 1 },
                time = 1,
                onFadeComplete = function()
                    Levelmap.active = true
                    Gamestate.pop({ complete = self.complete })
                    Gamestate.push(FadeOutState, { color = { 1, 1, 1, 1 }, time = 1 })
                end
            })
        end
    end
end

function RestState:_drawCard(entry, x, y, w, h)
    local c         = entry.c
    local is_active = entry.is_active

    -- Фон
    love.graphics.setColor(0.25, 0.28, 0.35, 0.95)
    love.graphics.rectangle('fill', x, y, w, h, 8, 8)

    -- Рамка: зелёная для active, серая для spare
    if is_active then
        love.graphics.setColor(0.5, 0.8, 0.5, 1)
    else
        love.graphics.setColor(0.35, 0.35, 0.35, 1)
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', x, y, w, h, 8, 8)

    -- Метка ACTIVE / SPARE
    love.graphics.setFont(smallFont)
    if is_active then
        love.graphics.setColor(0.7, 1, 0.7, 1)
    else
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
    end
    love.graphics.printf(is_active and "ACTIVE" or "SPARE", x, y + 6, w, 'center')

    -- Спрайт
    if c.sprite then
        local scale = 0.5
        local sx    = x + w / 2 - c.sprite.w * scale / 2
        local sy    = y + 24
        love.graphics.setColor(1, 1, 1, 1)
        c.sprite:draw(c.quad, sx, sy, 0, scale, scale)
    end

    -- Статы (с учётом модификаторов)
    local stats    = Stats(c, RunState:getModifiers(), {})
    local max_hp   = stats:get('max_health')
    local max_en   = stats:get('max_energy')
    local hp_ratio = max_hp > 0 and math.min(c.health / max_hp, 1) or 0
    local en_ratio = max_en > 0 and math.min(c.energy / max_en, 1) or 0

    -- Имя
    love.graphics.setFont(nameFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(c.name or '?', x, y + 112, w, 'center')

    -- HP
    local bar_x = x + 12
    local bar_w = w - 24
    local bar_h = 12
    local bar_y = y + 145

    love.graphics.setFont(smallFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(
        "HP " .. math.floor(c.health) .. "/" .. math.floor(max_hp),
        x, bar_y - 16, w, 'center')

    love.graphics.setColor(0.15, 0.15, 0.15, 1)
    love.graphics.rectangle('fill', bar_x, bar_y, bar_w, bar_h)
    love.graphics.setColor(0.85, 0.3, 0.3, 1)
    love.graphics.rectangle('fill', bar_x, bar_y, bar_w * hp_ratio, bar_h)

    -- Energy
    bar_y = bar_y + 34
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(
        "EN " .. math.floor(c.energy) .. "/" .. math.floor(max_en),
        x, bar_y - 16, w, 'center')

    love.graphics.setColor(0.15, 0.15, 0.15, 1)
    love.graphics.rectangle('fill', bar_x, bar_y, bar_w, bar_h)
    love.graphics.setColor(0.3, 0.5, 0.9, 1)
    love.graphics.rectangle('fill', bar_x, bar_y, bar_w * en_ratio, bar_h)
end

return RestState