local CharacterPool = require 'src.character_pool'

local SHARD_TYPES = { 'wild', 'mystic', 'mechanic', 'ancient', 'chaos' }
local SHARD_LABELS = {
    wild = 'Wild', mystic = 'Mystic', mechanic = 'Mechanic',
    ancient = 'Ancient', chaos = 'Chaos',
}
local SHARD_COLORS = {
    wild     = { 0.55, 0.80, 0.30, 1 },
    mystic   = { 0.65, 0.40, 0.90, 1 },
    mechanic = { 0.75, 0.75, 0.85, 1 },
    ancient  = { 0.90, 0.75, 0.35, 1 },
    chaos    = { 0.90, 0.35, 0.35, 1 },
}

local TITLE_FONT  = love.graphics.newFont(28)
local LABEL_FONT  = love.graphics.newFont(14)
local CHIP_W, CHIP_H = 150, 56
local CHIP_GAP = 12

local CRAFT_SHARDS     = 5    -- требуется осколков
local ESSENCE_PER_SHARD = 2   -- цена одного недостающего осколка в эссенции

local CraftScreen = {
    isOpen         = false,
    player         = nil,
    mode           = 'targeted',   -- 'targeted' | 'wild'
    target_attr    = 'wild',
    onClose        = nil,
    message        = "",
    message_color  = { 1, 1, 1, 1 },
    last_crafted   = nil,          -- имя последнего скрафченного (для сообщения)
}

-- ================================================================
-- Жизненный цикл
-- ================================================================

function CraftScreen:open(player, onClose)
    self.isOpen        = true
    self.player        = player
    self.mode          = 'targeted'
    self.target_attr   = 'wild'
    self.onClose       = onClose
    self.message       = ""
    self.last_crafted  = nil
end

function CraftScreen:close()
    self.isOpen   = false
    self.player   = nil
    self.last_crafted = nil
    local cb = self.onClose
    self.onClose = nil
    if cb then cb() end
end

function CraftScreen:isActive()
    return self.isOpen
end

-- ================================================================
-- Стоимость и оплата
-- ================================================================

-- Стоимость targeted: сколько осколков и эссенции уйдёт.
-- Возвращает: (can_afford, shards_used, essence_used)
function CraftScreen:_costTargeted(attr)
    local have = self.player:getShard(attr)
    local use_shards = math.min(have, CRAFT_SHARDS)
    local missing    = CRAFT_SHARDS - use_shards
    local essence    = missing * ESSENCE_PER_SHARD

    if self.player:getEssence() < essence then
        return false, use_shards, essence
    end
    return true, use_shards, essence
end

-- Стоимость wild: сколько осколков и эссенции уйдёт.
-- Использует осколки в порядке убывания количества, чтобы не «съесть» редкий тип.
function CraftScreen:_costWild()
    local total = self.player:getShardTotal()
    local use_shards = math.min(total, CRAFT_SHARDS)
    local missing    = CRAFT_SHARDS - use_shards
    local essence    = missing * ESSENCE_PER_SHARD

    if self.player:getEssence() < essence then
        return false, use_shards, essence
    end
    return true, use_shards, essence
end

-- Потратить осколки wild-режимом. Возвращает таблицу { [attr] = потрачено }.
function CraftScreen:_spendWildShards(amount)
    local needed = amount
    local spent  = {}

    local order = {}
    for _, t in ipairs(SHARD_TYPES) do
        order[#order + 1] = { type = t, count = self.player:getShard(t) }
    end
    table.sort(order, function(a, b) return a.count > b.count end)

    for _, entry in ipairs(order) do
        if needed <= 0 then break end
        local take = math.min(needed, entry.count)
        if take > 0 then
            self.player:spendShards(entry.type, take)
            spent[entry.type] = take
            needed = needed - take
        end
    end
    return spent
end

-- ================================================================
-- Крафт
-- ================================================================

function CraftScreen:_doCraft()
    local name

    if self.mode == 'targeted' then
        local can, shard_use, essence_use = self:_costTargeted(self.target_attr)
        if not can then
            self.message = "Not enough shards or essence."
            self.message_color = { 1, 0.4, 0.4, 1 }
            return
        end

        if shard_use > 0 then
            self.player:spendShards(self.target_attr, shard_use)
        end
        if essence_use > 0 then
            self.player:spendEssence(essence_use)
        end

        name = CharacterPool.random(self.target_attr)

    else -- wild
        local can, shard_use, essence_use = self:_costWild()
        if not can then
            self.message = "Not enough shards or essence."
            self.message_color = { 1, 0.4, 0.4, 1 }
            return
        end

        local spent = {}
        if shard_use > 0 then
            spent = self:_spendWildShards(shard_use)
        end
        if essence_use > 0 then
            self.player:spendEssence(essence_use)
        end

        -- Пул атрибутов = те, что игрок реально потратил.
        -- Если потратил только эссенцию — все 5.
        local attrs = {}
        for t, n in pairs(spent) do
            if n > 0 then table.insert(attrs, t) end
        end
        if #attrs == 0 then
            attrs = SHARD_TYPES
        end
        name = CharacterPool.randomFromAttributes(attrs)
    end

    if not name then
        self.message = "No creature available for this attribute."
        self.message_color = { 1, 0.4, 0.4, 1 }
        return
    end

    -- Проверка свободного слота
    local index, _ = self.player:getFreeCharacterSpace()
    if not index then
        self.message = "All slots are full!"
        self.message_color = { 1, 0.4, 0.4, 1 }
        return
    end

    local character = self.player:addCharacter(name)
    self.last_crafted = character.name

    self.message = "Crafted: " .. character.name
    self.message_color = { 0.4, 1, 0.4, 1 }
    PlaySound(ButtonClickSound)
end

-- ================================================================
-- Отрисовка
-- ================================================================

function CraftScreen:draw()
    if not self.isOpen then return end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    -- Фон
    UI.setStyle({
        draw_border      = false,
        background_color = { 0.06, 0.06, 0.09, 0.88 },
        corner_radius    = 0,
    })
    UI.nextPosition("CENTER", "root")
    UI.backdrop("craft_blocker", 0, 0, sw, sh, "CENTER")

    -- Заголовок
    UI.setStyle({})
    UI.nextPosition("TOP", "root")
    UI.text(0, 50, "Craft a Creature", "TOP", { 1, 1, 1, 1 }, TITLE_FONT)

    -- Подзаголовок с ресурсами
    UI.nextPosition("BOTTOM")
    UI.text(0, 8,
        "Cost: " .. CRAFT_SHARDS .. " shards, or " .. ESSENCE_PER_SHARD .. " essence per missing shard.",
        "TOP", { 0.7, 0.7, 0.7, 1 }, LABEL_FONT)

    UI.nextPosition("BOTTOM")
    UI.text(0, 6,
        "You have: " .. self.player:getShardTotal() .. " shards, "
        .. self.player:getEssence() .. " essence",
        "TOP", { 0.9, 0.9, 0.5, 1 }, LABEL_FONT)

    -- Переключатель режима
    UI.nextPosition("BOTTOM", _, 0, 38)
    if UI.button("craft_mode_targeted", -8, 0, 300, 60,
        "Targeted (specific type)", "TOPRIGHT") then
        self.mode = 'targeted'
    end
    if UI.button("craft_mode_wild", 8, 0, 300, 60,
        "Wild (any types)", "TOPLEFT") then
        self.mode = 'wild'
    end

    UI.nextPosition("CENTER", "root", 0, 0)
    if self.mode == 'targeted' then
        self:_drawTargetedPanel()
    else
        self:_drawWildPanel()
    end

    -- Сообщение
    if self.message ~= "" then
        UI.nextPosition("CENTER", "root")
        UI.text(0, 260, self.message, "CENTER", self.message_color, LABEL_FONT)
    end

    -- Кнопка Craft
    local can_craft
    if self.mode == 'targeted' then
        can_craft = self:_costTargeted(self.target_attr)
    else
        can_craft = self:_costWild()
    end

    -- Close
    UI.nextPosition("BOTTOM", "root")
    if UI.button("craft_close", 0, -40, 180, 44, "Close", "BOTTOM") then
        self:close()
    end

    UI.nextPosition("TOP")
    if UI.button("craft_do", 0, -50, 220, 52, "Craft", "BOTTOM", can_craft) then
        self:_doCraft()
    end
end

function CraftScreen:_drawTargetedPanel()
    local n = #SHARD_TYPES
    local total_w = n * CHIP_W + (n - 1) * CHIP_GAP

    UI.backdrop("craft_t_backdrop", 0, 0, total_w, CHIP_H, "CENTER", { 0, 0, 0, 0 })
    UI.nextPosition("LEFT")
    for i, shard_type in ipairs(SHARD_TYPES) do
        local color  = SHARD_COLORS[shard_type]
        local is_sel = (shard_type == self.target_attr)
        local count  = self.player:getShard(shard_type)
        local can    = self:_costTargeted(shard_type)

        UI.setStyle({
            draw_border      = true,
            border_color     = is_sel and { 1, 1, 1, 1 } or { 0.2, 0.2, 0.2, 1 },
            border_width     = is_sel and 3 or 1,
            background_color = can and color or { color[1] * 0.4, color[2] * 0.4, color[3] * 0.4, 1 },
            corner_radius    = 8,
        })
        if UI.button("craft_t_" .. shard_type, 0, 0, CHIP_W, CHIP_H, "", "LEFT") then
            self.target_attr = shard_type
        end

        UI.setStyle({})
        UI.nextPosition("CENTER", "craft_t_" .. shard_type)
        UI.text(0, -10, SHARD_LABELS[shard_type], "CENTER", { 1, 1, 1, 1 }, LABEL_FONT)

        UI.nextPosition("CENTER", "craft_t_" .. shard_type)
        UI.text(0, 10, count .. " / " .. CRAFT_SHARDS, "CENTER",
            can and { 1, 1, 1, 1 } or { 1, 0.5, 0.5, 1 }, TITLE_FONT)

        UI.nextPosition("RIGHT", "craft_t_" .. shard_type, CHIP_GAP)
    end

    -- Итоговая цена выбранного
    local can, shard_use, essence_use = self:_costTargeted(self.target_attr)
    UI.nextPosition("CENTER", "root")
    UI.text(0, 110,
        "Cost: " .. shard_use .. " " .. SHARD_LABELS[self.target_attr] .. " shards"
        .. (essence_use > 0 and (" + " .. essence_use .. " essence") or ""),
        "CENTER", { 0.9, 0.9, 0.9, 1 }, LABEL_FONT)
end

function CraftScreen:_drawWildPanel()
    local n = #SHARD_TYPES
    local total_w = n * CHIP_W + (n - 1) * CHIP_GAP

    UI.backdrop("craft_w_backdrop", 0, 0, total_w, CHIP_H, "CENTER", { 0, 0, 0, 0 })
    UI.nextPosition("LEFT")
    -- Показываем текущий баланс каждого типа (информативно)
    for i, shard_type in ipairs(SHARD_TYPES) do
        local color = SHARD_COLORS[shard_type]
        local count = self.player:getShard(shard_type)
        local active = count > 0

        UI.setStyle({
            draw_border      = false,
            background_color = active and color or { color[1] * 0.3, color[2] * 0.3, color[3] * 0.3, 0.8 },
            corner_radius    = 8,
        })
        UI.backdrop("craft_w_" .. shard_type, 0, 0, CHIP_W, CHIP_H, "LEFT")

        UI.setStyle({})
        UI.nextPosition("CENTER", "craft_w_" .. shard_type)
        UI.text(0, -10, SHARD_LABELS[shard_type], "CENTER", { 1, 1, 1, 1 }, LABEL_FONT)

        UI.nextPosition("CENTER", "craft_w_" .. shard_type)
        UI.text(0, 10, tostring(count), "CENTER", { 1, 1, 1, 1 }, TITLE_FONT)
        
        UI.nextPosition("RIGHT", "craft_w_" .. shard_type, CHIP_GAP)
    end

    -- Итоговая цена
    local can, shard_use, essence_use = self:_costWild()
    UI.nextPosition("CENTER", "root")
    UI.text(0, 110,
        "Cost: " .. shard_use .. " any shards"
        .. (essence_use > 0 and (" + " .. essence_use .. " essence") or "")
        .. "  (creature attribute: random from spent types)",
        "CENTER", { 0.9, 0.9, 0.9, 1 }, LABEL_FONT)
end

return CraftScreen