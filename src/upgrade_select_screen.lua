-- Экран выбора улучшения после боя.
-- Открывается через UpgradeSelectScreen:open(player, choices?, onClose?)
-- Если choices не переданы — роллит 3 случайных улучшения взвешенно по редкости.

local Upgrades = require 'data.upgrades'
local RunState = require 'src.states.run_state'

local UpgradeSelectScreen = {
    isOpen   = false,
    player   = nil,
    choices  = {},     -- { { id = 'vitality', data = <upgrade table> }, ... }
    onClose  = nil,
}

-- ------------------------------------------------------------------
-- Константы
-- ------------------------------------------------------------------

local CARD_W   = 260
local CARD_H   = 380
local CARD_GAP = 100

local TITLE_FONT  = love.graphics.newFont(28)
local NAME_FONT   = love.graphics.newFont(18)
local LABEL_FONT  = love.graphics.newFont(12)
local DESC_FONT   = love.graphics.newFont(13)
local HINT_FONT   = love.graphics.newFont(13)

local RARITY_COLORS = {
    common    = { 0.80, 0.80, 0.80, 1 },
    uncommon  = { 0.35, 0.85, 0.35, 1 },
    rare      = { 0.40, 0.60, 1.00, 1 },
    legendary = { 1.00, 0.75, 0.25, 1 },
}

local RARITY_BG = {
    common    = { 0.28, 0.28, 0.32, 0.96 },
    uncommon  = { 0.20, 0.40, 0.24, 0.96 },
    rare      = { 0.20, 0.28, 0.52, 0.96 },
    legendary = { 0.52, 0.38, 0.14, 0.96 },
}

local RARITY_LABEL = {
    common    = 'COMMON',
    uncommon  = 'UNCOMMON',
    rare      = 'RARE',
    legendary = 'LEGENDARY',
}

-- Заглушка иконки — 1x1 белый пиксель, растягиваем через ui.image с размером.
local placeholder_data = love.image.newImageData(1, 1)
placeholder_data:setPixel(0, 0, 1, 1, 1, 1)
local PLACEHOLDER = love.graphics.newImage(placeholder_data)

-- ------------------------------------------------------------------
-- Хелперы
-- ------------------------------------------------------------------

local function rng_random()
    if RunState.rng then return RunState:random() end
    return math.random()
end

local function wrap_text(text, font, max_width)
    local lines = {}
    for paragraph in text:gmatch("[^\n]+") do
        local current = ""
        for word in paragraph:gmatch("%S+") do
            local test = current == "" and word or (current .. " " .. word)
            if font:getWidth(test) <= max_width then
                current = test
            else
                if current ~= "" then table.insert(lines, current) end
                current = word
            end
        end
        if current ~= "" then table.insert(lines, current) end
    end
    return lines
end

-- ------------------------------------------------------------------
-- Ролл вариантов
-- ------------------------------------------------------------------

function UpgradeSelectScreen.rollChoices(count)
    count = count or 3
    local pool = {}
    for id, up in pairs(Upgrades) do
        -- Пока исключаем апгрейды, требующие конкретного существа.
        if type(up) == 'table'
           and up.name
           and up.rarity
           and not up.target then
            pool[#pool + 1] = { id = id, up = up }
        end
    end

    local chosen = {}
    local used = {}

    for _ = 1, count do
        local total = 0
        local available = {}
        for _, entry in ipairs(pool) do
            if not used[entry.id] then
                local w = Upgrades.RARITY_WEIGHTS[entry.up.rarity] or 1
                total = total + w
                available[#available + 1] = { entry = entry, weight = w }
            end
        end
        if total == 0 then break end

        local r = rng_random() * total
        local acc = 0
        for _, item in ipairs(available) do
            acc = acc + item.weight
            if r <= acc then
                chosen[#chosen + 1] = { id = item.entry.id, data = item.entry.up }
                used[item.entry.id] = true
                break
            end
        end
    end

    return chosen
end

-- ------------------------------------------------------------------
-- Жизненный цикл
-- ------------------------------------------------------------------

function UpgradeSelectScreen:open(player, choices, onClose)
    self.isOpen  = true
    self.player  = player
    self.choices = (choices and #choices > 0) and choices or self.rollChoices(3)
    self.onClose = onClose
end

function UpgradeSelectScreen:close()
    self.isOpen  = false
    self.player  = nil
    self.choices = {}
    local cb = self.onClose
    self.onClose = nil
    if cb then cb() end
end

function UpgradeSelectScreen:isActive()
    return self.isOpen
end

-- ------------------------------------------------------------------
-- Выбор
-- ------------------------------------------------------------------

function UpgradeSelectScreen:_pick(index)
    local choice = self.choices[index]
    if not choice then return end

    RunState:applyUpgrade(choice.id)

    -- Если апгрейд персональный (target = 'single') — можно
    -- передать конкретное существо вторым аргументом applyUpgrade.
    -- Пока такие апгрейды исключены из пула.

    self:close()
end

-- ------------------------------------------------------------------
-- Отрисовка
-- ------------------------------------------------------------------

function UpgradeSelectScreen:_drawCard(index, choice, card_x)
    local up     = choice.data
    local rarity = up.rarity or 'common'
    local rcol   = RARITY_COLORS[rarity] or RARITY_COLORS.common
    local rbg    = RARITY_BG[rarity]     or RARITY_BG.common
    local card_id = "upg_card_" .. index

    -- Карта — это кнопка с фоном по редкости
    UI.setStyle({
        draw_border      = true,
        border_color     = rcol,
        border_width     = 2,
        background_color = rbg,
        corner_radius    = 14,
    })
    UI.backdrop(card_id, card_x, 0, CARD_W, CARD_H, "LEFT")

    -- Имя (сверху)
    UI.setStyle({})
    UI.nextPosition("TOP", card_id)
    UI.text(0, 18, up.name or choice.id, "TOP", rcol, NAME_FONT)

    -- Метка редкости
    UI.nextPosition("TOP", card_id)
    local dim = { rcol[1] * 0.65, rcol[2] * 0.65, rcol[3] * 0.65, 0.9 }
    UI.text(0, 44, RARITY_LABEL[rarity] or rarity, "TOP", dim, LABEL_FONT)

    -- Иконка-заглушка (центр)
    UI.nextPosition("CENTER", card_id)
    UI.image(0, 0, PLACEHOLDER, "CENTER", 100, rcol)
    -- Тонкая рамка вокруг иконки
    UI.nextPosition("CENTER", card_id)
    UI.setStyle({
        draw_border      = true,
        border_color     = rcol,
        border_width     = 1,
        background_color = { 0, 0, 0, 0 },
        corner_radius    = 4,
    })
    UI.backdrop("upg_icon_" .. index, 0, 0, 100, 100, "CENTER")

    -- Описание (снизу, перенос по словам)
    UI.setStyle({})
    local lines = wrap_text(up.description or "", DESC_FONT, CARD_W - 30)
    UI.nextPosition("BOTTOMLEFT", card_id)
    UI.text(15, -22, lines[#lines], "BOTTOMLEFT",
        { 0.95, 0.95, 0.95, 1 }, DESC_FONT)
    for j = #lines-1, 1, -1 do
        UI.nextPosition("TOPLEFT")
        UI.text(0, -2, lines[j], "BOTTOMLEFT",
            { 0.95, 0.95, 0.95, 1 }, DESC_FONT)
    end
    
    UI.setStyle({
        draw_border      = false,
        background_color = { 0.65, 0.65, 0.65, 0.3 },
        corner_radius    = 14,
    })
    UI.nextPosition("CENTER", card_id)
    local clicked = UI.button(card_id .. "_button", 0, 0, CARD_W, CARD_H, "", "CENTER")

    return clicked
end

function UpgradeSelectScreen:draw()
    if not self.isOpen then return end

    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    -- Затемняющий фон
    UI.setStyle({
        draw_border      = false,
        background_color = { 0.06, 0.06, 0.09, 0.88 },
        corner_radius    = 0,
    })
    UI.nextPosition("CENTER", "root")
    UI.backdrop("upg_blocker", 0, 0, sw, sh, "CENTER")

    -- Заголовок
    UI.setStyle({})
    UI.nextPosition("TOP", "root")
    UI.text(0, 65, "Choose an Upgrade", "TOP", { 1, 1, 1, 1 }, TITLE_FONT)

    -- Подсказка
    UI.nextPosition("BOTTOM")
    UI.text(0, 10, "Choose one — it will last until the end of the run.",
        "TOP", { 0.7, 0.7, 0.7, 1 }, HINT_FONT)

    -- Карты
    local n        = #self.choices
    local total_w  = n * CARD_W + math.max(n - 1, 0) * CARD_GAP
    local start_x  = -total_w / 2

    for i, choice in ipairs(self.choices) do
        local card_x = start_x + (i - 1) * (CARD_W + CARD_GAP)

        -- current_pos должен быть в центре экрана перед каждой картой
        UI.nextPosition("CENTER", "root")

        local clicked = self:_drawCard(i, choice, card_x)

        if clicked then
            self:_pick(i)
            return  -- после выбора выходим, чтобы не рисовать/обрабатывать остальные
        end
    end
end

return UpgradeSelectScreen