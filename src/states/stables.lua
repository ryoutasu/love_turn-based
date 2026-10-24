-- src/stables.lua
local PenCreature   = require 'src.stables.pen_creature'
local CharacterList = require 'src.characters'
local Sprite        = require 'src.sprite'

-- ================================================================
-- Layout / цвета
-- ================================================================

local FRAME_SIZE = 84
local FRAME_GAP  = 12
local PARTY_Y    = 100
local MARGIN     = 40

local COLOR_FRAME_BG        = { 0.75, 0.75, 0.75, 0.85 }
local COLOR_FRAME_BG_LOCKED = { 0.40, 0.40, 0.40, 0.70 }
local COLOR_FRAME_BORDER    = { 0.85, 0.85, 0.85, 1    }
local COLOR_FRAME_HOVER     = { 1,    1,    1,    1    }
local COLOR_PEN_BG          = { 0.32, 0.40, 0.32, 0.40 }
local COLOR_PEN_BORDER      = { 0.55, 0.65, 0.55, 1    }

local COLOR_ATTR = {
    wild     = { 0.55, 0.80, 0.30 },
    mystic   = { 0.65, 0.40, 0.90 },
    mechanic = { 0.75, 0.75, 0.85 },
    ancient  = { 0.90, 0.75, 0.35 },
    chaos    = { 0.90, 0.35, 0.35 },
}

local ATTR_ORDER = { 'wild', 'mystic', 'mechanic', 'ancient', 'chaos' }

local font      = love.graphics.newFont(24)
local fontSmall = love.graphics.newFont(14)
local fontTiny  = love.graphics.newFont(11)

-- ================================================================
-- Кеширование спрайтов и квадов (для Pokedex)
-- ================================================================

local spriteCache = {}
local quadCache   = {}

local function getSprite(path, color)
    local key = path or 'nil'
    if not spriteCache[key] then
        spriteCache[key] = Sprite(path, color)
    end
    return spriteCache[key]
end

local function getQuad(sprite)
    local key = sprite.w .. 'x' .. sprite.h
    if not quadCache[key] then
        quadCache[key] = love.graphics.newQuad(0, 0, sprite.w, sprite.h,
            sprite.w, sprite.h)
    end
    return quadCache[key]
end

-- ================================================================
-- Sparse / compact (party arrays)
-- ================================================================

local function to_sparse(list, size)
    local out = {}
    for i = 1, size do out[i] = list[i] end
    return out
end

local function to_compact(list, size)
    local out = {}
    for i = 1, size do
        if list[i] ~= nil then table.insert(out, list[i]) end
    end
    return out
end

-- ================================================================
-- Stables
-- ================================================================

local Stables = {}

function Stables:init()
    self.penCreatures    = {}
    self.partySlots      = {}
    self.drag            = nil
    self.view            = 'pen'
    self.pokedexFilter   = nil
    self.buy_slot_button = nil
    self.pen             = nil
end

-- ================================================================
-- Enter / leave
-- ================================================================

function Stables:enter(state, args)
    self.player = args.player
    self.view   = 'pen'
    self.pokedexFilter = nil
    self.drag   = nil

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    self.pen = {
        x = MARGIN,
        y = PARTY_Y + FRAME_SIZE + 50,
        w = sw - MARGIN * 2,
        h = sh - (PARTY_Y + FRAME_SIZE + 50) - 130,
    }

    -- Party-массивы временно становятся sparse, чтобы слоты были стабильными
    self.player.charactersActive = to_sparse(self.player.charactersActive,
        self.player.charactersActiveMax)
    self.player.charactersSpare  = to_sparse(self.player.charactersSpare,
        self.player.charactersSpareMax)

    -- Слоты отряда
    self.partySlots = {}
    local x = MARGIN
    for i = 1, self.player.charactersActiveMax do
        table.insert(self.partySlots, {
            list_type = 'active',
            index     = i,
            x         = x,
            y         = PARTY_Y,
            locked    = i > self.player.charactersActiveSize,
            hovered   = false,
        })
        x = x + FRAME_SIZE + FRAME_GAP
    end
    x = x + 20
    for i = 1, self.player.charactersSpareMax do
        table.insert(self.partySlots, {
            list_type = 'spare',
            index     = i,
            x         = x,
            y         = PARTY_Y,
            locked    = i > self.player.charactersSpareSize,
            hovered   = false,
        })
        x = x + FRAME_SIZE + FRAME_GAP
    end

    -- Pen creatures для каждого существа из стойл
    self.penCreatures = {}
    for _, character in ipairs(self.player.charactersStables) do
        self:_spawn_pen_creature(character)
    end

    self.buy_slot_button = {
        x = sw - MARGIN - 180,
        y = PARTY_Y,
        w = 180,
        h = FRAME_SIZE,
        cost = 200,
    }
end

function Stables:leave()
    -- Обратно в плотные массивы
    self.player.charactersActive = to_compact(self.player.charactersActive,
        self.player.charactersActiveMax)
    self.player.charactersSpare  = to_compact(self.player.charactersSpare,
        self.player.charactersSpareMax)

    self.drag = nil
    self.penCreatures = {}
end

-- ================================================================
-- Внутренние хелперы
-- ================================================================

function Stables:_spawn_pen_creature(character, x, y)
    local px = x or (self.pen.x + 40 + math.random() * (self.pen.w - 80))
    local py = y or (self.pen.y + 40 + math.random() * (self.pen.h - 80))
    local bounds = {
        x = self.pen.x + 20,
        y = self.pen.y + 20,
        w = self.pen.w - 40,
        h = self.pen.h - 40,
    }
    local pc = PenCreature(character, px, py, bounds)
    table.insert(self.penCreatures, pc)
    return pc
end

function Stables:get_slot_char(slot)
    if slot.list_type == 'active' then
        return self.player.charactersActive[slot.index]
    else
        return self.player.charactersSpare[slot.index]
    end
end

function Stables:set_slot_char(slot, character)
    if slot.list_type == 'active' then
        self.player.charactersActive[slot.index] = character
    else
        self.player.charactersSpare[slot.index] = character
    end
end

function Stables:_clear_drag()
    if self.drag and self.drag.pen_creature then
        self.drag.pen_creature.dragged = false
    end
    self.drag = nil
end

function Stables:_find_slot_at(mx, my)
    for _, slot in ipairs(self.partySlots) do
        if mx >= slot.x and mx <= slot.x + FRAME_SIZE
        and my >= slot.y and my <= slot.y + FRAME_SIZE then
            return slot
        end
    end
    return nil
end

function Stables:_find_pen_creature_at(mx, my)
    for i = #self.penCreatures, 1, -1 do
        local pc = self.penCreatures[i]
        if not pc.dragged and pc:contains(mx, my) then
            return pc
        end
    end
    return nil
end

function Stables:_is_inside_pen(mx, my)
    return mx >= self.pen.x and mx <= self.pen.x + self.pen.w
       and my >= self.pen.y and my <= self.pen.y + self.pen.h
end

-- ================================================================
-- Перемещения
-- ================================================================

function Stables:_drop_to_slot(target_slot)
    local d          = self.drag
    local drag_char  = d.character
    local target_char = self:get_slot_char(target_slot)

    if target_char == drag_char then
        self:_clear_drag()
        return
    end

    -- 1. Убрать drag_char из источника
    if d.origin.list_type == 'active' then
        self.player.charactersActive[d.origin.index] = nil
    elseif d.origin.list_type == 'spare' then
        self.player.charactersSpare[d.origin.index] = nil
    else -- stables
        for i, c in ipairs(self.player.charactersStables) do
            if c == drag_char then table.remove(self.player.charactersStables, i); break end
        end
        for i, pc in ipairs(self.penCreatures) do
            if pc == d.pen_creature then table.remove(self.penCreatures, i); break end
        end
    end

    -- 2. Освободить целевой слот от target_char (если был)
    if target_char then
        self:set_slot_char(target_slot, nil)
    end

    -- 3. Поставить drag_char в целевой слот
    self:set_slot_char(target_slot, drag_char)

    -- 4. Если был swap — вернуть target_char в источник
    if target_char then
        if d.origin.list_type == 'active' then
            self.player.charactersActive[d.origin.index] = target_char
        elseif d.origin.list_type == 'spare' then
            self.player.charactersSpare[d.origin.index] = target_char
        else -- stables
            table.insert(self.player.charactersStables, target_char)
            if d.pen_creature then
                d.pen_creature.character = target_char
                d.pen_creature.dragged   = false
                table.insert(self.penCreatures, d.pen_creature)
            end
        end
    end

    self:_clear_drag()
end

function Stables:_drop_to_pen(x, y)
    local d = self.drag
    local drag_char = d.character

    if d.origin.list_type == 'stables' then
        -- Уже в стойлах — просто переместить по загону
        if d.pen_creature then
            d.pen_creature.x            = x
            d.pen_creature.y            = y
            d.pen_creature.state        = 'idle'
            d.pen_creature.idle_timer   = 1.5
        end
        self:_clear_drag()
        return
    end

    -- Из отряда в стойла
    self:set_slot_char({ list_type = d.origin.list_type, index = d.origin.index }, nil)
    table.insert(self.player.charactersStables, drag_char)
    self:_spawn_pen_creature(drag_char, x, y)
    self:_clear_drag()
end

-- ================================================================
-- Ввод
-- ================================================================

function Stables:mousepressed(mx, my, button)
    if button ~= 1 or self.view ~= 'pen' then return end

    -- Кнопка "открыть слот"
    local b = self.buy_slot_button
    if b and mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then
        if self.player.charactersActiveSize < self.player.charactersActiveMax
        and self.player.currencies.gold >= b.cost then
            self.player:addCurrency('gold', -b.cost)
            self.player.charactersActiveSize = self.player.charactersActiveSize + 1
            for _, slot in ipairs(self.partySlots) do
                if slot.list_type == 'active'
                and slot.index == self.player.charactersActiveSize then
                    slot.locked = false
                end
            end
            PlaySound(ButtonClickSound)
        end
        return
    end

    -- Клик по слоту отряда
    local slot = self:_find_slot_at(mx, my)
    if slot and not slot.locked then
        local char = self:get_slot_char(slot)
        if char then
            self.drag = {
                character    = char,
                origin       = { list_type = slot.list_type, index = slot.index },
                pen_creature = nil,
            }
            return
        end
    end

    -- Клик по существу в загоне
    local pc = self:_find_pen_creature_at(mx, my)
    if pc then
        pc.dragged = true
        self.drag = {
            character    = pc.character,
            origin       = {
                list_type    = 'stables',
                pen_creature = pc,
                x            = pc.x,
                y            = pc.y,
            },
            pen_creature = pc,
        }
        return
    end
end

function Stables:mousereleased(mx, my, button)
    if button ~= 1 or not self.drag then return end

    local d = self.drag

    -- 1. Слот отряда — переместить / swap
    local slot = self:_find_slot_at(mx, my)
    if slot and not slot.locked then
        self:_drop_to_slot(slot)
        return
    end

    -- 2. Внутри пена (или тянем из отряда — всегда дропаем в пен)
    if self:_is_inside_pen(mx, my) or not d.pen_creature then
        local dx = math.max(self.pen.x + 30, math.min(self.pen.x + self.pen.w - 30, mx))
        local dy = math.max(self.pen.y + 30, math.min(self.pen.y + self.pen.h - 30, my))
        self:_drop_to_pen(dx, dy)
        return
    end

    -- 3. Тянули из пена, но отпустили вне пена — вернуть на исходную позицию
    if d.pen_creature and d.origin and d.origin.x then
        d.pen_creature.x           = d.origin.x
        d.pen_creature.y           = d.origin.y
        d.pen_creature.state       = 'idle'
        d.pen_creature.idle_timer  = 1.5
    end
    self:_clear_drag()
end

function Stables:mousemoved(mx, my)
    if self.view ~= 'pen' then return end

    for _, slot in ipairs(self.partySlots) do
        slot.hovered = (not slot.locked)
                   and mx >= slot.x and mx <= slot.x + FRAME_SIZE
                   and my >= slot.y and my <= slot.y + FRAME_SIZE
    end

    for _, pc in ipairs(self.penCreatures) do
        pc.hover = not pc.dragged and pc:contains(mx, my)
    end
end

function Stables:keypressed(key)
    if key == 'escape' then
        if self.drag then
            self:_clear_drag()
        elseif self.view == 'pokedex' then
            self.view = 'pen'
        else
            Gamestate.pop()
        end
    end
end

-- ================================================================
-- Update
-- ================================================================

function Stables:update(dt)
    for _, pc in ipairs(self.penCreatures) do
        pc:update(dt)
    end

    -- Dragged creature следует за мышью
    if self.drag and self.drag.pen_creature then
        local mx, my = love.mouse.getPosition()
        self.drag.pen_creature.x = mx
        self.drag.pen_creature.y = my
    end
end

-- ================================================================
-- Draw: pen view
-- ================================================================

function Stables:_draw_party_slots()
    for _, slot in ipairs(self.partySlots) do
        local x, y, s = slot.x, slot.y, FRAME_SIZE
        local char        = self:get_slot_char(slot)
        local is_dragging = self.drag and self.drag.character == char

        if slot.locked then
            love.graphics.setColor(COLOR_FRAME_BG_LOCKED)
        elseif slot.hovered then
            love.graphics.setColor(0.95, 0.95, 0.95, 1)
        else
            love.graphics.setColor(COLOR_FRAME_BG)
        end
        love.graphics.rectangle('fill', x, y, s, s, 6, 6)

        if char and not is_dragging then
            local sprite = char.sprite
            local scale  = PenCreature.SCALE
            local dx = x + s/2 - sprite.w * scale / 2
            local dy = y + s/2 - sprite.h * scale / 2
            love.graphics.setColor(1, 1, 1, 1)
            sprite:draw(char.quad, dx, dy, 0, scale, scale)
        end

        love.graphics.setLineWidth(slot.hovered and 3 or 1)
        love.graphics.setColor(slot.hovered and COLOR_FRAME_HOVER or COLOR_FRAME_BORDER)
        love.graphics.rectangle('line', x, y, s, s, 6, 6)
    end
end

function Stables:_draw_buy_slot_button()
    local b = self.buy_slot_button
    if not b then return end

    local can_buy = self.player.charactersActiveSize < self.player.charactersActiveMax
                and self.player.currencies.gold >= b.cost

    love.graphics.setColor(can_buy and { 0.55, 0.75, 0.55, 1 }
                                or  { 0.45, 0.40, 0.40, 1 })
    love.graphics.rectangle('fill', b.x, b.y, b.w, b.h, 6, 6)
    love.graphics.setColor(COLOR_FRAME_BORDER)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle('line', b.x, b.y, b.w, b.h, 6, 6)

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Open active slot", b.x + 10, b.y + 10)

    love.graphics.setColor(1, 0.85, 0, 1)
    love.graphics.print(b.cost .. " gold", b.x + 10, b.y + 32)

    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print(
        "(" .. self.player.charactersActiveSize
        .. "/" .. self.player.charactersActiveMax .. ")",
        b.x + 10, b.y + 54)
end

function Stables:_draw_pen()
    local p = self.pen

    love.graphics.setColor(COLOR_PEN_BG)
    love.graphics.rectangle('fill', p.x, p.y, p.w, p.h, 12, 12)
    love.graphics.setColor(COLOR_PEN_BORDER)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', p.x, p.y, p.w, p.h, 12, 12)

    -- Все существа, кроме dragged
    local dragged_pc = nil
    table.sort(self.penCreatures, function(a, b) return a.y < b.y end)
    for _, pc in ipairs(self.penCreatures) do
        if pc.dragged then
            dragged_pc = pc
        else
            pc:draw()
        end
    end

    -- Preview для переноса из отряда
    if self.drag and not self.drag.pen_creature then
        local char = self.drag.character
        if char and char.sprite then
            local mx, my = love.mouse.getPosition()
            local sprite = char.sprite
            local scale  = PenCreature.SCALE
            local dx = mx - sprite.w * scale / 2
            local dy = my - sprite.h * scale / 2
            love.graphics.setColor(1, 1, 1, 0.85)
            sprite:draw(char.quad, dx, dy, 0, scale, scale)
        end
    end

    -- Dragged существо из загона — рисуем последним, поверх
    if dragged_pc then
        dragged_pc:draw()
    end
end

function Stables:draw_pen_view()
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.print("Party", MARGIN, PARTY_Y - 22)

    self:_draw_party_slots()
    self:_draw_buy_slot_button()
    self:_draw_pen()

    UI.setStyle()
    UI.setFont(font)

    UI.nextPosition("BOTTOMLEFT", "root")
    if UI.button("stables_pokedex", 40, -60, 200, 50, "Pokedex", "BOTTOMLEFT") then
        self.view = 'pokedex'
        PlaySound(ButtonClickSound)
    end

    UI.nextPosition("BOTTOMRIGHT", "root")
    if UI.button("stables_back", -40, -60, 200, 50, "BACK", "BOTTOMRIGHT") then
        Gamestate.pop()
    end
end

-- ================================================================
-- Draw: Pokedex
-- ================================================================

function Stables:_collect_owned()
    local owned = {}
    local function mark(list)
        for _, c in pairs(list) do
            if c then owned[c.name] = true end
        end
    end
    mark(self.player.charactersActive)
    mark(self.player.charactersSpare)
    mark(self.player.charactersStables)
    return owned
end

function Stables:_collect_pokedex_entries()
    local all = {}
    for key, ch in pairs(CharacterList) do
        if type(ch) == 'table' and ch.name then
            if not self.pokedexFilter or ch.attribute == self.pokedexFilter then
                table.insert(all, { key = key, ch = ch })
            end
        end
    end
    table.sort(all, function(a, b) return a.ch.name < b.ch.name end)
    return all
end

function Stables:draw_pokedex_view()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Pokedex", 0, 30, sw, "center")

    -- Фильтры по атрибуту
    UI.setStyle()
    UI.setFont(fontSmall)

    UI.nextPosition("TOPLEFT", "root")
    if UI.button("pokedex_all", MARGIN, 80, 100, 36, "All", "TOPLEFT") then
        self.pokedexFilter = nil
    end

    for i, attr in ipairs(ATTR_ORDER) do
        local c = COLOR_ATTR[attr]
        UI.setStyle({ background_color = { c[1] * 0.5, c[2] * 0.5, c[3] * 0.5, 1 } })
        UI.nextPosition("TOPLEFT", "root")
        local label = attr:sub(1,1):upper() .. attr:sub(2)
        if UI.button("pokedex_" .. attr, MARGIN + 108 * i, 80, 100, 36, label, "TOPLEFT") then
            self.pokedexFilter = attr
        end
    end

    -- Данные
    local entries = self:_collect_pokedex_entries()
    local owned   = self:_collect_owned()

    -- Сетка
    local cell_w, cell_h = 100, 100
    local gap = 8
    local cols = math.floor((sw - 80) / (cell_w + gap))
    local start_x = (sw - (cols * (cell_w + gap) - gap)) / 2
    local start_y = 140

    local mx, my = love.mouse.getPosition()
    local hovered_entry = nil

    for i, entry in ipairs(entries) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cx = start_x + col * (cell_w + gap)
        local cy = start_y + row * (cell_h + gap)
        if cy + cell_h > sh - 100 then break end

        local ch       = entry.ch
        local is_owned = owned[ch.name] == true
        local ac       = COLOR_ATTR[ch.attribute] or { 0.5, 0.5, 0.5 }

        -- Фон
        love.graphics.setColor(ac[1] * 0.25, ac[2] * 0.25, ac[3] * 0.25, 1)
        love.graphics.rectangle('fill', cx, cy, cell_w, cell_h, 6, 6)

        -- Рамка
        love.graphics.setLineWidth(is_owned and 2 or 1)
        love.graphics.setColor(ac[1], ac[2], ac[3], is_owned and 1 or 0.4)
        love.graphics.rectangle('line', cx, cy, cell_w, cell_h, 6, 6)

        -- Спрайт
        if ch.sprite_path then
            local sprite = getSprite(ch.sprite_path, ch.color)
            local scale  = 0.5
            local dx = cx + cell_w / 2 - sprite.w * scale / 2
            local dy = cy + cell_h / 2 - sprite.h * scale / 2 - 8
            love.graphics.setColor(
                is_owned and 1 or 0.15,
                is_owned and 1 or 0.15,
                is_owned and 1 or 0.15,
                1)
            sprite:draw(getQuad(sprite), dx, dy, 0, scale, scale)
        end

        -- Имя
        love.graphics.setFont(fontTiny)
        love.graphics.setColor(1, 1, 1, is_owned and 1 or 0.5)
        love.graphics.printf(is_owned and ch.name or "???",
            cx, cy + cell_h - 22, cell_w, "center")

        -- Hover
        if mx >= cx and mx <= cx + cell_w
        and my >= cy and my <= cy + cell_h then
            hovered_entry = { entry = entry, is_owned = is_owned }
        end
    end

    if hovered_entry then
        self:_draw_pokedex_info(hovered_entry.entry, hovered_entry.is_owned)
    end

    -- Кнопка назад
    UI.setStyle()
    UI.setFont(font)
    UI.nextPosition("BOTTOMRIGHT", "root")
    if UI.button("pokedex_back", -40, -60, 200, 50, "BACK", "BOTTOMRIGHT") then
        self.view = 'pen'
    end
end

function Stables:_draw_pokedex_info(entry, is_owned)
    local ch = entry.ch
    local mx, my = love.mouse.getPosition()

    local w, h = 240, 190
    local x = math.min(mx + 16, love.graphics.getWidth()  - w - 10)
    local y = math.min(my + 16, love.graphics.getHeight() - h - 10)

    love.graphics.setColor(0.10, 0.10, 0.15, 0.95)
    love.graphics.rectangle('fill', x, y, w, h, 8, 8)
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle('line', x, y, w, h, 8, 8)

    local tx, ty = x + 12, y + 12

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(is_owned and ch.name or "???", tx, ty)
    ty = ty + 24

    local ac = COLOR_ATTR[ch.attribute] or { 0.5, 0.5, 0.5 }
    love.graphics.setColor(ac[1], ac[2], ac[3], 1)
    love.graphics.print("Attribute: " .. (ch.attribute or "?"), tx, ty)
    ty = ty + 20

    love.graphics.setColor(0.7, 0.7, 0.85, 1)
    love.graphics.print("Element: " .. (ch.element or "?"), tx, ty)
    ty = ty + 20

    if is_owned then
        love.graphics.setColor(0.85, 0.85, 0.85, 1)
        love.graphics.print("HP: "      .. (ch.max_health or "?"), tx, ty); ty = ty + 18
        love.graphics.print("Damage: "  .. (ch.damage     or "?"), tx, ty); ty = ty + 18
        love.graphics.print("Armor: "   .. (ch.armor      or 0),   tx, ty); ty = ty + 18

        if ch.spells then
            love.graphics.print("Spells: " .. #ch.spells, tx, ty)
        end
    else
        love.graphics.setColor(0.6, 0.6, 0.6, 1)
        love.graphics.print("Not yet captured.", tx, ty); ty = ty + 18
        love.graphics.print("Encounter one to unlock its data.", tx, ty)
    end
end

function Stables:draw()
    if self.view == 'pen' then
        self:draw_pen_view()
    else
        self:draw_pokedex_view()
    end
end

return Stables