local ItemList = require 'src.items'
local RunState = require 'src.states.run_state'

-- ================================================================
-- Шрифты и layout
-- ================================================================

local titleFont = love.graphics.newFont(36)
local nameFont  = love.graphics.newFont(16)
local descFont  = love.graphics.newFont(12)
local priceFont = love.graphics.newFont(16)
local smallFont = love.graphics.newFont(11)

local CARD_W, CARD_H = 280, 110
local GAP            = 16
local COLS, ROWS     = 2, 3
local SELL_RATIO     = 0.4

-- Цвета
local COLOR_CARD_BG          = { 0.22, 0.26, 0.34, 0.95 }
local COLOR_CARD_BG_HOVER    = { 0.30, 0.36, 0.46, 0.95 }
local COLOR_CARD_BG_DISABLED = { 0.15, 0.15, 0.18, 0.85 }
local COLOR_BORDER           = { 0.45, 0.55, 0.70, 1 }
local COLOR_BORDER_HOVER     = { 1, 1, 1, 1 }
local COLOR_PRICE            = { 1, 0.85, 0, 1 }
local COLOR_SOLD_OUT         = { 0.5, 0.5, 0.5, 1 }
local COLOR_TAB_ACTIVE       = { 0.55, 0.75, 0.55, 1 }
local COLOR_TAB_INACTIVE     = { 0.30, 0.30, 0.35, 1 }
local COLOR_TEXT             = { 1, 1, 1, 1 }
local COLOR_TEXT_DIM         = { 0.7, 0.7, 0.7, 1 }

-- ================================================================
-- ShopState
-- ================================================================

local ShopState = {}

function ShopState:init()
    self.stock     = {}
    self.mode      = 'buy'
    self.hovered   = nil
    self.layout    = {}
end

-- ================================================================
-- Lifecycle
-- ================================================================

function ShopState:enter(from, args)
    self.player  = args.player
    self.mode    = 'buy'
    self.hovered = nil

    self:_generateStock()
    self:_buildLayout()
end

function ShopState:leave() end

-- ================================================================
-- Генерация ассортимента
-- ================================================================

function ShopState:_generateStock()
    self.stock = {}

    -- Собираем все покупаемые предметы
    local pool = {}
    for id, item in pairs(ItemList) do
        if type(item) == 'table' and item.cost and item.cost > 0 then
            table.insert(pool, { id = id, item = item })
        end
    end
    table.sort(pool, function(a, b) return a.id < b.id end)

    -- Уникальные позиции (или меньше, если пул маленький)
    local count = math.min(COLS * ROWS, #pool)
    for _ = 1, count do
        local idx  = RunState:randomInt(1, #pool)
        local pick = pool[idx]
        table.remove(pool, idx)

        local base  = pick.item.cost
        local price = math.floor(base * (0.8 + RunState:random() * 0.4))
        local qty   = RunState:randomInt(1, 3)

        table.insert(self.stock, {
            id       = pick.id,
            item     = pick.item,
            price    = price,
            quantity = qty,
        })
    end
end

function ShopState:_buildLayout()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local total_w = COLS * CARD_W + (COLS - 1) * GAP
    local total_h = ROWS * CARD_H + (ROWS - 1) * GAP
    local start_x = (sw - total_w) / 2
    local start_y = math.max(140, (sh - total_h) / 2 - 20)

    self.layout = {}
    for i = 1, COLS * ROWS do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        self.layout[i] = {
            x = start_x + col * (CARD_W + GAP),
            y = start_y + row * (CARD_H + GAP),
        }
    end
end

-- ================================================================
-- Хелперы
-- ================================================================

function ShopState:_getEntries()
    if self.mode == 'buy' then
        return self.stock
    end

    -- Sell mode: список предметов игрока
    local entries = {}
    for _, slot in ipairs(self.player.inventory) do
        if slot and slot.item then
            local base_cost  = slot.item.cost or 10
            local sell_price = math.max(1, math.floor(base_cost * SELL_RATIO))
            table.insert(entries, {
                item     = slot.item,
                quantity = slot.quantity,
                price    = sell_price,
                sell     = true,
            })
        end
    end
    return entries
end

function ShopState:_hoveredIndex(mx, my)
    for i, pos in ipairs(self.layout) do
        if mx >= pos.x and mx <= pos.x + CARD_W
        and my >= pos.y and my <= pos.y + CARD_H then
            return i
        end
    end
    return nil
end

-- ================================================================
-- Update — только UI (кнопки, табы, возврат)
-- ================================================================

function ShopState:update(dt)
    local mx, my = love.mouse.getPosition()
    self.hovered = self:_hoveredIndex(mx, my)

    -- Кнопки табов
    local sw      = love.graphics.getWidth()
    local tab_w   = 160
    local tab_h   = 40
    local tab_gap = 10
    local tab_y   = 80
    local tabs_x  = sw / 2 - (tab_w * 2 + tab_gap) / 2

    UI.setStyle({
        draw_border      = true,
        border_color     = { 0, 0, 0, 1 },
        background_color = (self.mode == 'buy') and COLOR_TAB_ACTIVE or COLOR_TAB_INACTIVE,
        corner_radius    = 6,
    })
    UI.setFont(nameFont)
    UI.nextPosition("TOPLEFT", "root")
    if UI.button("shop_tab_buy", tabs_x, tab_y, tab_w, tab_h, "Buy", "TOPLEFT") then
        self.mode = 'buy'
        PlaySound(ButtonClickSound)
    end

    UI.setStyle({
        draw_border      = true,
        border_color     = { 0, 0, 0, 1 },
        background_color = (self.mode == 'sell') and COLOR_TAB_ACTIVE or COLOR_TAB_INACTIVE,
        corner_radius    = 6,
    })
    UI.nextPosition("TOPLEFT", "root")
    if UI.button("shop_tab_sell", tabs_x + tab_w + tab_gap, tab_y, tab_w, tab_h,
        "Sell", "TOPLEFT") then
        self.mode = 'sell'
        PlaySound(ButtonClickSound)
    end

    -- Return
    UI.setStyle({
        draw_border      = true,
        border_color     = { 0, 0, 0, 1 },
        background_color = { 0.6, 0.6, 0.8, 1 },
        corner_radius    = 6,
    })
    UI.setFont(titleFont)
    UI.nextPosition("BOTTOM", "root")
    if UI.button("shop_return", 0, -40, 240, 60, "Return", "BOTTOM") then
        Gamestate.push(FadeInState, {
            color = { 1, 1, 1, 1 },
            time = 1,
            onFadeComplete = function()
                Levelmap.active = true
                Gamestate.pop()
                Gamestate.push(FadeOutState, { color = { 1, 1, 1, 1 }, time = 1 })
            end
        })
    end
end

-- ================================================================
-- Ввод
-- ================================================================

function ShopState:mousepressed(x, y, button)
    if button ~= 1 then return end
    local idx = self:_hoveredIndex(x, y)
    if idx then
        self:_clickCard(idx)
    end
end

function ShopState:_clickCard(index)
    local entries = self:_getEntries()
    local entry   = entries[index]
    if not entry then return end

    if self.mode == 'buy' then
        self:_buy(entry)
    else
        self:_sell(entry)
    end
end

function ShopState:_buy(entry)
    local gold = self.player.currencies.gold or 0

    if entry.quantity <= 0 then
        Tagtext:add('Sold out',
            love.mouse.getX(), love.mouse.getY(),
            1, 30, { 1, 0.5, 0.5 })
        PlaySound(ErrorSound, 0.4)
        return
    end
    if gold < entry.price then
        Tagtext:add('Not enough gold',
            love.mouse.getX(), love.mouse.getY(),
            1, 30, { 1, 0.5, 0.5 })
        PlaySound(ErrorSound, 0.4)
        return
    end

    entry.quantity = entry.quantity - 1
    self.player:addItem(entry.id, 1)
    self.player:addCurrency('gold', -entry.price)
    PlaySound(CoinsSound)
end

function ShopState:_sell(entry)
    -- Ищем слот в инвентаре игрока с этим item.id
    local found = nil
    for i, slot in ipairs(self.player.inventory) do
        if slot and slot.item and slot.item.id == entry.item.id then
            found = i
            break
        end
    end
    if not found then return end

    local slot = self.player.inventory[found]
    slot.quantity = slot.quantity - 1
    if slot.quantity <= 0 then
        table.remove(self.player.inventory, found)
    end

    self.player:addCurrency('gold', entry.price)
    PlaySound(CoinsSound)
end

-- ================================================================
-- Draw
-- ================================================================

function ShopState:draw()
    local sw = love.graphics.getWidth()

    -- Заголовок
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.printf("Shop", 3, 33, sw, 'center')
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Shop", 0, 30, sw, 'center')

    -- Золото (верхний правый угол)
    love.graphics.setFont(priceFont)
    love.graphics.setColor(COLOR_PRICE)
    love.graphics.printf(
        "Gold: " .. (self.player.currencies.gold or 0),
        sw - 220, 40, 200, 'right')

    -- Сетка карточек
    local entries = self:_getEntries()
    if #entries == 0 then
        love.graphics.setFont(nameFont)
        love.graphics.setColor(COLOR_TEXT_DIM)
        love.graphics.printf(
            (self.mode == 'buy') and "Shop is empty." or "Your inventory is empty.",
            0, love.graphics.getHeight() / 2, sw, 'center')
        return
    end

    for i, entry in ipairs(entries) do
        local pos = self.layout[i]
        if pos then
            self:_drawCard(entry, pos, self.hovered == i)
        end
    end
end

function ShopState:_drawCard(entry, pos, is_hovered)
    local x, y   = pos.x, pos.y
    local item   = entry.item
    local out_of_stock = entry.quantity <= 0
    local can_afford   = (self.player.currencies.gold or 0) >= entry.price

    -- Фон
    local bg = COLOR_CARD_BG
    if out_of_stock then
        bg = COLOR_CARD_BG_DISABLED
    elseif is_hovered then
        bg = COLOR_CARD_BG_HOVER
    end
    love.graphics.setColor(bg)
    love.graphics.rectangle('fill', x, y, CARD_W, CARD_H, 8, 8)

    -- Рамка
    love.graphics.setLineWidth(is_hovered and 3 or 2)
    love.graphics.setColor(is_hovered and COLOR_BORDER_HOVER or COLOR_BORDER)
    love.graphics.rectangle('line', x, y, CARD_W, CARD_H, 8, 8)

    -- Цветная полоска (item.color)
    if item.color then
        love.graphics.setColor(item.color)
        love.graphics.rectangle('fill', x + 4, y + 8, 5, CARD_H - 16, 3, 3)
    end

    -- Имя
    love.graphics.setFont(nameFont)
    love.graphics.setColor(COLOR_TEXT)
    love.graphics.print(item.name or entry.id or "?", x + 18, y + 12)

    -- Описание
    love.graphics.setFont(descFont)
    love.graphics.setColor(COLOR_TEXT_DIM)
    love.graphics.printf(item.description or "",
        x + 18, y + 40, CARD_W - 100, 'left')

    -- Цена (снизу слева)
    love.graphics.setFont(priceFont)
    if out_of_stock then
        love.graphics.setColor(COLOR_SOLD_OUT)
        love.graphics.print("SOLD OUT", x + 18, y + CARD_H - 28)
    elseif self.mode == 'buy' and not can_afford then
        love.graphics.setColor(1, 0.5, 0.5, 1)
        love.graphics.print(entry.price .. "g", x + 18, y + CARD_H - 28)
    else
        love.graphics.setColor(COLOR_PRICE)
        love.graphics.print(entry.price .. "g", x + 18, y + CARD_H - 28)
    end

    -- Количество (снизу справа)
    love.graphics.setFont(smallFont)
    love.graphics.setColor(COLOR_TEXT_DIM)
    love.graphics.printf("x" .. entry.quantity,
        x, y + CARD_H - 24, CARD_W - 12, 'right')
end

return ShopState