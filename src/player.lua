local RunState = require 'src.states.run_state'
local Character = require 'src.character'
local Characters = require 'src.characters'
local ItemList = require 'src.items'
local SpellList = require 'src.spells'
local Stats = require 'src.stats'
local PlayerMetaStory = require 'src.player_meta_story'

local currenciesFont = love.graphics.newFont(14)
local goldColor = { 1, 0.85, 0, 1 }

-- ------------------------------------------------------------------
-- Shards (by attribute) & Essence (universal)
-- ------------------------------------------------------------------

local SHARD_TYPES = { 'wild', 'mystic', 'mechanic', 'ancient', 'chaos' }

local SHARD_TYPE_SET = {}
for _, t in ipairs(SHARD_TYPES) do SHARD_TYPE_SET[t] = true end

local SHARD_COLORS = {
    wild     = { 0.55, 0.80, 0.30, 1 },
    mystic   = { 0.65, 0.40, 0.90, 1 },
    mechanic = { 0.75, 0.75, 0.85, 1 },
    ancient  = { 0.90, 0.75, 0.35, 1 },
    chaos    = { 0.90, 0.35, 0.35, 1 },
}

local SHARD_LABELS = {
    wild     = 'Wild',
    mystic   = 'Myst',
    mechanic = 'Mech',
    ancient  = 'Anc',
    chaos    = 'Chaos',
}

local shardFont  = love.graphics.newFont(14)
local shardChipW = 80
local shardChipH = 25
local shardGap   = 6

-- ------------------------------------------------------------------

---@class Player
local Player = Class{}

function Player:init()
    self.charactersStables = {}
    self.charactersActive = {}
    self.charactersSpare = {}
    self.inventory = {}
    self.store = {}
    self.currencies = {}
    self.meta_unlocks = {}

    -- Shards by attribute + universal essence
    self.shards = {}
    for _, t in ipairs(SHARD_TYPES) do
        self.shards[t] = 0
    end
    self.essence = 0

    self.level = 1
    self.currentExp = 0
    self.maxExp = 100

    self.charactersActiveSize = 2
    self.charactersSpareSize = 1
    self.charactersStablesSize = 20
    self.charactersActiveMax = 4
    self.charactersSpareMax = 3
    self.inventorySize = 4

    self.showCharacter = nil

    self.lives = 3
    self.livesMax = 3

    self.meta_story = PlayerMetaStory.create()
end

-- ================================================================
-- SHARDS
-- ================================================================

-- Проверка валидности типа осколка.
function Player:isValidShardType(shard_type)
    return SHARD_TYPE_SET[shard_type] == true
end

-- Список типов осколков (для UI).
function Player.getShardTypes()
    return SHARD_TYPES
end

-- Начислить осколки. type ∈ SHARD_TYPES.
function Player:addShard(shard_type, amount)
    amount = amount or 1
    assert(SHARD_TYPE_SET[shard_type],
        "Unknown shard type: " .. tostring(shard_type))
    if amount == 0 then return end

    self.shards[shard_type] = math.max(0, (self.shards[shard_type] or 0) + amount)
end

-- Начислить осколки разных типов: { wild = 3, mystic = 1 }
function Player:addShardsMulti(map)
    for shard_type, amount in pairs(map) do
        self:addShard(shard_type, amount)
    end
end

-- Получить количество осколков одного типа.
function Player:getShard(shard_type)
    return self.shards[shard_type] or 0
end

-- Вся таблица осколков (ссылка).
function Player:getAllShards()
    return self.shards
end

-- Общее количество осколков всех типов.
function Player:getShardTotal()
    local total = 0
    for _, t in ipairs(SHARD_TYPES) do
        total = total + (self.shards[t] or 0)
    end
    return total
end

function Player:hasShards(shard_type, amount)
    return (self.shards[shard_type] or 0) >= amount
end

-- Списать осколки одного типа. true, если успех.
function Player:spendShards(shard_type, amount)
    amount = amount or 1
    if not self:hasShards(shard_type, amount) then return false end
    self.shards[shard_type] = self.shards[shard_type] - amount
    return true
end

-- Списать осколки разных типов одной операцией (атомарно).
-- Возвращает true/false; при неудаче ничего не списывается.
function Player:spendShardsMulti(cost)
    -- 1. Проверка
    for shard_type, amount in pairs(cost) do
        if not SHARD_TYPE_SET[shard_type] then
            error("Unknown shard type: " .. tostring(shard_type))
        end
        if (self.shards[shard_type] or 0) < amount then
            return false
        end
    end
    -- 2. Списание
    for shard_type, amount in pairs(cost) do
        self.shards[shard_type] = self.shards[shard_type] - amount
    end
    return true
end

-- Обмен осколков одного типа на другой (для upgrade 'exchange').
-- rate = 3 → 3 штуки from_type дают 1 to_type.
function Player:exchangeShards(from_type, to_type, rate)
    rate = rate or 3
    assert(SHARD_TYPE_SET[from_type], "Unknown shard type: " .. tostring(from_type))
    assert(SHARD_TYPE_SET[to_type],   "Unknown shard type: " .. tostring(to_type))
    if from_type == to_type then return false end
    if not self:hasShards(from_type, rate) then return false end

    self.shards[from_type] = self.shards[from_type] - rate
    self.shards[to_type]   = (self.shards[to_type] or 0) + 1
    return true
end

-- ================================================================
-- ESSENCE
-- ================================================================

function Player:addEssence(amount)
    amount = amount or 1
    if amount == 0 then return end
    self.essence = math.max(0, self.essence + amount)
end

function Player:getEssence()
    return self.essence
end

function Player:hasEssence(amount)
    return self.essence >= amount
end

function Player:spendEssence(amount)
    amount = amount or 1
    if not self:hasEssence(amount) then return false end
    self.essence = self.essence - amount
    return true
end

-- ================================================================
-- EXPERIENCE / LEVEL
-- ================================================================

function Player:addExperience(amount)
    self.currentExp = self.currentExp + amount
    if self.currentExp >= self.maxExp then
        self:levelUp()
    end
end

function Player:levelUp()
    self.currentExp = self.currentExp - self.maxExp
    self.maxExp = self.maxExp * 1.2

    self.level = self.level + 1

    for _, character in ipairs(self.charactersActive) do
        Character.addModifiers(character, Modifier.fromUpgrade('level_up'))
    end
end

function Player:getCurrentExperience()
    return self.currentExp
end

function Player:getMaxExperience()
    return self.maxExp
end

-- ================================================================
-- META
-- ================================================================

function Player:addMetaUnlock(key)
    self.meta_unlocks[key] = true
end

function Player:hasMetaUnlock(key)
    return self.meta_unlocks[key] == true
end

-- ================================================================
-- CHARACTERS
-- ================================================================

function Player:getFreeCharacterSpace()
    for i = 1, self.charactersActiveSize do
        if not self.charactersActive[i] then
            return i, self.charactersActive
        end
    end

    for i = 1, self.charactersSpareSize do
        if not self.charactersSpare[i] then
            return i, self.charactersSpare
        end
    end

    for i = 1, 20 do
        if not self.charactersStables[i] then
            return i, self.charactersStables
        end
    end

    return nil, {}
end

function Player:addCharacter(name_or_table)
    local c
    if type(name_or_table) == 'string' then
        c = Character.new(Characters[name_or_table])
    else
        c = Character.new(name_or_table)
    end

    local index, target_table = self:getFreeCharacterSpace()
    if index then
        table.insert(target_table, index, c)
    end

    return c
end

function Player:addCharacterTo(character, to)
    if to == 'spare' then
        for i = 1, self.charactersSpareSize do
            if not self.charactersSpare[i] then
                table.insert(self.charactersSpare, i, character)
                return
            end
        end
    end

    if to == 'active' then
        for i = 1, self.charactersActiveSize do
            if not self.charactersActive[i] then
                table.insert(self.charactersActive, i, character)
                return
            end
        end
    end

    if to == 'stables' then
        for i = 1, self.charactersStablesSize do
            if not self.charactersStables[i] then
                table.insert(self.charactersStables, i, character)
                return
            end
        end
    end
end

function Player:removeCharacter(character)
    for i = 1, self.charactersActiveSize do
        if self.charactersActive[i] == character then
            table.remove(self.charactersActive, i)
            return
        end
    end

    for i = 1, self.charactersSpareSize do
        if self.charactersSpare[i] == character then
            table.remove(self.charactersSpare, i)
            return
        end
    end

    for i = 1, self.charactersStablesSize do
        if self.charactersStables[i] == character then
            table.remove(self.charactersStables, i)
            return
        end
    end
end

function Player:getLen(t)
    local len = 0
    if t == 'spare' then
        for i = 1, self.charactersSpareSize do
            if self.charactersSpare[i] then len = len + 1 end
        end
    end

    if t == 'active' then
        for i = 1, self.charactersActiveSize do
            if self.charactersActive[i] then len = len + 1 end
        end
    end

    if t == 'stables' then
        for i = 1, self.charactersStablesSize do
            if self.charactersStables[i] then len = len + 1 end
        end
    end

    return len
end

-- ================================================================
-- ITEMS
-- ================================================================

local max_stack_count = 5

function Player:findItem(name)
    for i = 1, self.inventorySize do
        if self.inventory[i]
        and self.inventory[i].item.name == name
        and self.inventory[i].quantity < max_stack_count then
            return i, self.inventory
        end
    end

    for i = 1, 20 do
        if self.store[i]
        and self.store[i].item.name == name
        and self.store[i].quantity < max_stack_count then
            return i, self.store
        end
    end

    return nil, {}
end

function Player:getFreeItemSpace()
    for i = 1, self.inventorySize do
        if not self.inventory[i] then
            return i, self.inventory
        end
    end

    for i = 1, 20 do
        if not self.store[i] then
            return i, self.store
        end
    end

    return nil, {}
end

function Player:addItem(itemName, quantity)
    local item = itemName
    if type(item) == 'string' then
        item = ItemList[itemName]
    end
    itemName = item.name

    while quantity > 0 do
        local index, target_table = self:findItem(itemName)

        if index then
            local target_quantity = target_table[index].quantity
            local add = math.min(5 - target_quantity, quantity)
            target_table[index].quantity = target_quantity + add
            quantity = quantity - add

            goto continue
        end

        local index, target_table = self:getFreeItemSpace()

        if index then
            local add = math.min(5, quantity)
            table.insert(target_table, { item = item, quantity = add, isActive = true })
            quantity = quantity - add

            goto continue
        end

        ::continue::
    end
end

function Player:removeItem(item, quantity)
    for index, inventoryItem in ipairs(self.inventory) do
        if inventoryItem.item.name == item.name then
            if quantity == 0 then
                quantity = inventoryItem.quantity
            end
            inventoryItem.quantity = inventoryItem.quantity - quantity

            if inventoryItem.quantity <= 0 then
                table.remove(self.inventory, index)
            end
        end
    end
end

function Player:removeItemByIndex(from, index, quantity)
    if from[index].quantity <= quantity then
        from[index] = nil
        return
    end

    from[index].quantity = from[index].quantity - quantity
end

-- ================================================================
-- CURRENCIES
-- ================================================================

function Player:addCurrency(name, value)
    local currency = self.currencies[name]
    if not currency then self.currencies[name] = 0; currency = 0 end
    self.currencies[name] = math.max(currency + value, 0)
end

function Player:drawCurrency()
    local padding = 4
    local text = tostring(self.currencies.gold or 0)
    -- local textW = currenciesFont:getWidth(text) + padding + padding
    -- local textH = currenciesFont:getHeight(text) + padding + padding
    UI.setStyle({
        draw_border = true,
        border_color = { 0, 0, 0, 1 },
        background_color = { 1, 1, 1, 1 },
        corner_radius = 4,
    })
    UI.nextPosition("TOPRIGHT", "root")
    local goldBackdrop = UI.backdrop("gold", -10, 10, 80, shardChipH, "TOPRIGHT")
    UI.nextPosition("LEFT", "gold")
    UI.text(4, 0, "Gold:", "LEFT", { 0, 0, 0, 1 }, currenciesFont)
    UI.nextPosition("RIGHT", "gold")
    UI.text(-4, 0, text, "RIGHT", { 0, 0, 0, 1 }, currenciesFont)

    if goldBackdrop then
        self:drawShards()
    end
end

-- ================================================================
-- SHARDS DRAW
-- ================================================================

-- Компактный ряд чипов с осколками (5 штук) и эссенцией.
-- Вызывать из HUD, когда активны города/карта.
function Player:drawShards()
    local x = -10

    UI.nextPosition("BOTTOMRIGHT", "gold")
    -- Осколки — 5 штук справа налево
    for i = 1, #SHARD_TYPES, 1 do
        local shard_type = SHARD_TYPES[i]
        local color = SHARD_COLORS[shard_type] or { 1, 1, 1, 1 }
        local id    = "shard_chip_" .. shard_type
        local count = self.shards[shard_type] or 0

        UI.setStyle({
            draw_border = true,
            border_color = { 0, 0, 0, 1 },
            background_color = color,
            corner_radius = 4,
        })

        UI.backdrop(id, 0, 4, shardChipW, shardChipH, "TOPRIGHT")

        UI.nextPosition("RIGHT", id)
        UI.text(-4, 0, tostring(count), "RIGHT", { 1, 1, 1, 1 }, shardFont)

        UI.nextPosition("LEFT", id)
        UI.text(4, 0, SHARD_LABELS[shard_type] or shard_type, "LEFT", { 1, 1, 1, 1 }, shardFont)

        UI.nextPosition("BOTTOMRIGHT", id)
    end
    
    -- Эссенция — крайняя правая
    UI.setStyle({
        draw_border = true,
        border_color = { 0, 0, 0, 1 },
        background_color = { 0.20, 0.55, 0.85, 1 },
        corner_radius = 4,
    })
    UI.backdrop("essence_chip", 0, 4, shardChipW, shardChipH, "TOPRIGHT")
    UI.nextPosition("RIGHT")
    UI.text(-4, 0, tostring(self.essence or 0), "RIGHT", { 1, 1, 1, 1 }, shardFont)
    UI.nextPosition("LEFT", "essence_chip")
    UI.text(4, 0, "Ess", "LEFT", { 1, 1, 1, 1 }, shardFont)
end

-- ================================================================
-- CHARACTER LIST (tooltip)
-- ================================================================

local spriteScale = 0.6
local buttonSize = 80
local buttonOffset = 16
local statWindowFont = love.graphics.newFont(18)
local padding = 10
local textOffset = 4
local statWindowWidth  = 300
local statWindowHeight = 300

function Player:getTooltipStats(character)
    if self._tooltipStats and self._tooltipStats.character == character then
        return self._tooltipStats.stats
    end
    local stats = Stats(character, RunState:getModifiers(), {})
    self._tooltipStats = { character = character, stats = stats }
    return stats
end

function Player:drawCharacterList()
    local active = self.charactersActive
    local spare = self.charactersSpare

    local character_pressed = nil
    local character_from = nil

    local x = buttonOffset
    UI.nextPosition("TOPLEFT", "root")
    for i = 1, self.charactersActiveSize do
        local character = active[i]
        if character then
            UI.setStyle({})
            UI.backdrop("player_active_backdrop_"..i, x, buttonOffset, buttonSize, buttonSize, "TOPLEFT")
            UI.nextPosition("CENTER")
            UI.image(0, 0, character.sprite.image, "CENTER", spriteScale)

            UI.setStyle({ draw_border = true, border_color = { 0, 0, 0, 1 }, background_color = { 0.8, 0.8, 0.8, 0.15 } })
            if UI.button("player_active_btn_"..i, 0, 0, buttonSize, buttonSize, "", "CENTER") then
                character_pressed = i
                character_from = { table = active, name = "active" }
            end

            UI.setStyle({ draw_border = true, border_color = { 0.25, .66, 0.25, 1 }, background_color = { 0.5, 0.5, 0.5, 0.85 } })
            UI.nextPosition("BOTTOMLEFT", "player_active_backdrop_"..i)
            x = 0
        end
    end

    if #spare > 0 then
        UI.setStyle({ draw_border = false })
        UI.backdrop("line", 0, buttonOffset, buttonSize, 2, "TOPLEFT", { 0, 0, 0, 1 })
        UI.nextPosition("BOTTOMLEFT")

        for i = 1, self.charactersSpareSize do
            local character = spare[i]
            if character then
                UI.setStyle({})
                UI.backdrop("player_spare_backdrop_"..i, x, buttonOffset, buttonSize, buttonSize, "TOPLEFT")
                UI.nextPosition("CENTER")
                UI.image(0, 0, character.sprite.image, "CENTER", spriteScale)

                UI.setStyle({ draw_border = true, border_color = { 0, 0, 0, 1 }, background_color = { 0.8, 0.8, 0.8, 0.15 } })
                if UI.button("player_spare_btn_"..i, 0, 0, buttonSize, buttonSize, "", "CENTER") then
                    character_pressed = i
                    character_from = { table = spare, name = "spare" }
                end

                UI.setStyle({ draw_border = true, border_color = { 0.25, .66, 0.25, 1 }, background_color = { 0.5, 0.5, 0.5, 0.85 } })
                UI.nextPosition("BOTTOMLEFT", "player_spare_backdrop_"..i)
                x = 0
            end
        end
    end

    if character_pressed == self.showCharacter then
        self.showCharacter = nil
        self.showCharacterFrom = nil
        self._tooltipStats = nil
    elseif character_pressed then
        self.showCharacter = character_pressed
        self.showCharacterFrom = character_from
        self._tooltipStats = nil
    end

    if self.showCharacter and self.showCharacterFrom.table[self.showCharacter] then
        local character = self.showCharacterFrom.table[self.showCharacter]
        local stats = self:getTooltipStats(character)

        local max_hp = math.floor(stats:get('max_health'))
        local max_en = math.floor(stats:get('max_energy'))
        local cur_hp = math.min(character.health or max_hp, max_hp)
        local cur_en = math.min(character.energy or max_en, max_en)

        UI.setStyle({ draw_border = true, border_color = { 0, 0, 0, 1 } })
        UI.setFont(statWindowFont)

        UI.nextPosition("TOPRIGHT", "player_"..self.showCharacterFrom.name.."_backdrop_"..self.showCharacter)
        UI.backdrop("showed_character_backdrop", 15, 0, statWindowWidth, statWindowHeight, "TOPLEFT")
        UI.nextPosition("TOPLEFT")
        UI.text(padding, padding - 2, character.name, "TOPLEFT")

        UI.nextPosition("BOTTOMLEFT")
        UI.text(0, textOffset, {
            { 1, 1, 1, 1 }, "Attribute: ",
            ATTRIBUTES_COLORS[character.attribute], ATTRIBUTES[character.attribute]
        }, "TOPLEFT")

        UI.nextPosition("BOTTOMLEFT")
        UI.text(0, textOffset, {
            { 1, 1, 1, 1 }, "Element: ",
            ELEMENTS_COLORS[character.element], ELEMENTS[character.element]
        }, "TOPLEFT")

        UI.nextPosition("BOTTOMLEFT")
        UI.text(0, textOffset, "Health: " .. cur_hp .. "/" .. max_hp, "TOPLEFT")

        UI.nextPosition("BOTTOMLEFT")
        UI.text(0, textOffset, "Energy: " .. cur_en .. "/" .. max_en, "TOPLEFT")

        UI.nextPosition("BOTTOMLEFT")
        UI.text(0, textOffset, "Damage: " .. math.floor(stats:get('damage')), "TOPLEFT")

        UI.nextPosition("BOTTOMLEFT")
        UI.text(0, textOffset, "Armor: " .. math.floor(stats:get('armor')), "TOPLEFT")

        UI.nextPosition("BOTTOMLEFT")
        UI.text(0, textOffset, "Initiative: " .. math.floor(stats:get('initiative')), "TOPLEFT")

        UI.nextPosition("BOTTOMLEFT")
        UI.text(0, textOffset, "Move range: " .. math.floor(stats:get('move_range')), "TOPLEFT")

        UI.nextPosition("BOTTOMLEFT")
        UI.text(0, textOffset, "Attack range: " .. math.floor(stats:get('attack_range')), "TOPLEFT")

        UI.nextPosition("BOTTOMLEFT")
        UI.text(0, textOffset, "Spells: ", "TOPLEFT")
        for _, entry in ipairs(character.spells or {}) do
            local id = type(entry) == 'string' and entry or entry.id
            local spell = SpellList[id]
            local name = spell and spell.name or id
            UI.nextPosition("BOTTOMLEFT")
            UI.text(0, textOffset, "> " .. name .. " <", "TOPLEFT")
        end
    end
end

-- ================================================================
-- LIVES / EXPERIENCE
-- ================================================================

local heartImagePath = "resources/heart.png"
local heartBrokenImagePath = "resources/heart_broken.png"
local heartImage = love.graphics.newImage(heartImagePath)
local heartBrokenImage = love.graphics.newImage(heartBrokenImagePath)
local heartSize = 0.8
local heartWidth = heartImage:getWidth() * heartSize

local offset = -20

function Player:drawLives()
    local width = self.livesMax * heartWidth + offset * (self.livesMax - 1)
    local remained = self.lives

    UI.nextPosition("TOP", "root")
    local x = -width/2
    local y = -10
    for i = 1, self.livesMax do
        local image = remained > 0 and heartImage or heartBrokenImage
        local color = remained > 0 and { 1, 1, 1, 1 } or { 0.5, 0.5, 0.5, 1 }
        UI.image(x, y, image, "TOPLEFT", heartSize, color)
        UI.nextPosition("TOPRIGHT")

        remained = remained - 1
        x, y = offset, 0
    end
end

local experienceBarFont = love.graphics.newFont(16)

function Player:drawExperienceBar()
    UI.setStyle({
        draw_border = true,
        border_color = { 0, 0, 0, 1 },
        background_color = { 0.8, 0.8, 0.8 },
        corner_radius = 2,
    })
    UI.nextPosition("BOTTOMLEFT", "root")
    UI.bar("exp_bar", 18, -20, 220, 28, (self.currentExp / self.maxExp), { 0.6, 0.8, 0.2, 1 }, "BOTTOMLEFT")
    UI.nextPosition("LEFT", "exp_bar")
    UI.text(7, 1, "Level " .. self.level, "LEFT", { 0, 0, 0, 1 }, experienceBarFont)
    UI.text(6, 0, "Level " .. self.level, "LEFT", { 1, 1, 1, 1 }, experienceBarFont)
    UI.nextPosition("RIGHT", "exp_bar")
    UI.text(-5, 1, self.currentExp .. ' / ' .. self.maxExp, "RIGHT", { 0, 0, 0, 1 }, experienceBarFont)
    UI.text(-6, 0, self.currentExp .. ' / ' .. self.maxExp, "RIGHT", { 1, 1, 1, 1 }, experienceBarFont)
end

-- ------------------------------------------------------------------
-- Serialization
-- ------------------------------------------------------------------

function Player:serialize()
    local data = {
        level                 = self.level,
        currentExp            = self.currentExp,
        maxExp                = self.maxExp,
        lives                 = self.lives,
        livesMax              = self.livesMax,
        charactersActiveSize  = self.charactersActiveSize,
        charactersSpareSize   = self.charactersSpareSize,
        charactersActiveMax   = self.charactersActiveMax,
        charactersSpareMax    = self.charactersSpareMax,
        charactersStablesSize = self.charactersStablesSize,
        inventorySize         = self.inventorySize,
        essence               = self.essence,
        currencies            = {},
        shards                = {},
        meta_unlocks          = {},
        charactersActive      = {},
        charactersSpare       = {},
        charactersStables     = {},
        inventory             = {},
        store                 = {},
    }

    for k, v in pairs(self.currencies or {}) do data.currencies[k] = v end
    for k, v in pairs(self.shards or {}) do data.shards[k] = v end
    for k, v in pairs(self.meta_unlocks or {}) do data.meta_unlocks[k] = v end

    -- Массивы персонажей — плотные (без nil), чтобы ipairs при загрузке работал
    for _, c in ipairs(self.charactersActive) do
        if c then data.charactersActive[#data.charactersActive + 1] = Character.serialize(c) end
    end
    for _, c in ipairs(self.charactersSpare) do
        if c then data.charactersSpare[#data.charactersSpare + 1] = Character.serialize(c) end
    end
    for _, c in ipairs(self.charactersStables) do
        if c then data.charactersStables[#data.charactersStables + 1] = Character.serialize(c) end
    end

    -- Предметы — ссылки по name (предполагается, что имена уникальны).
    -- Если у вас в ItemList ключ != name, замените на сохранение id.
    for _, slot in ipairs(self.inventory) do
        data.inventory[#data.inventory + 1] = {
            item_name = slot.item.name,
            quantity  = slot.quantity,
            isActive  = slot.isActive,
        }
    end
    for _, slot in ipairs(self.store) do
        data.store[#data.store + 1] = {
            item_name = slot.item.name,
            quantity  = slot.quantity,
            isActive  = slot.isActive,
        }
    end

    data.meta_story = PlayerMetaStory.serialize(self.meta_story)

    return data
end

function Player:deserialize(data)
    if not data then return end

    -- Обнуляем
    self.charactersActive  = {}
    self.charactersSpare   = {}
    self.charactersStables = {}
    self.inventory         = {}
    self.store             = {}
    self.currencies        = {}
    self.shards            = {}
    self.meta_unlocks      = {}

    self.level                 = data.level                 or 1
    self.currentExp            = data.currentExp            or 0
    self.maxExp                = data.maxExp                or 100
    self.lives                 = data.lives                 or 3
    self.livesMax              = data.livesMax              or 3
    self.charactersActiveSize  = data.charactersActiveSize  or 2
    self.charactersSpareSize   = data.charactersSpareSize   or 1
    self.charactersActiveMax   = data.charactersActiveMax   or 4
    self.charactersSpareMax    = data.charactersSpareMax    or 3
    self.charactersStablesSize = data.charactersStablesSize or 20
    self.inventorySize         = data.inventorySize         or 4
    self.essence               = data.essence               or 0

    -- Shards — гарантируем все 5 ключей
    for _, t in ipairs(SHARD_TYPES) do self.shards[t] = 0 end
    for k, v in pairs(data.shards or {}) do
        if SHARD_TYPE_SET[k] then self.shards[k] = v end
    end

    for k, v in pairs(data.currencies   or {}) do self.currencies[k]   = v end
    for k, v in pairs(data.meta_unlocks or {}) do self.meta_unlocks[k] = v end

    for _, cdata in ipairs(data.charactersActive or {}) do
        local c = Character.deserialize(cdata)
        if c then table.insert(self.charactersActive, c) end
    end
    for _, cdata in ipairs(data.charactersSpare or {}) do
        local c = Character.deserialize(cdata)
        if c then table.insert(self.charactersSpare, c) end
    end
    for _, cdata in ipairs(data.charactersStables or {}) do
        local c = Character.deserialize(cdata)
        if c then table.insert(self.charactersStables, c) end
    end

    -- Восстанавливаем предметы по имени
    local function find_item(name)
        for _, it in pairs(ItemList) do
            if it.name == name then return it end
        end
        return nil
    end

    for _, slot in ipairs(data.inventory or {}) do
        local item = find_item(slot.item_name)
        if item then
            table.insert(self.inventory, {
                item = item, quantity = slot.quantity, isActive = slot.isActive,
            })
        end
    end
    for _, slot in ipairs(data.store or {}) do
        local item = find_item(slot.item_name)
        if item then
            table.insert(self.store, {
                item = item, quantity = slot.quantity, isActive = slot.isActive,
            })
        end
    end

    self.meta_story = PlayerMetaStory.deserialize(data.meta_story)
end

return Player