local shader = require 'shader'
local Sprite = require 'src.sprite'
local spellList = require 'src.spells'
local moonshine = require 'lib.moonshine'
local Stats = require 'src.stats'
local RunState = require 'src.states.run_state'
local damageCalculator = require 'src.damage_calculator'

local fontSize = 12
local healthFont = love.graphics.newFont(fontSize)

local text_effect = moonshine(moonshine.effects.boxblur)
text_effect.boxblur.radius = 1

UNIT_ALIVE_OFFSET = -HEX_RADIUS * 0.45
UNIT_DEAD_OFFSET = HEX_RADIUS * 0.3

--- @class Unit
local Unit = Class{}

-- ------------------------------------------------------------------
-- Инициализация
-- ------------------------------------------------------------------

function Unit:init(tile, is_player)
    local x = tile.x
    local y = tile.y + UNIT_ALIVE_OFFSET

    self.x = x
    self.y = y
    self.z = 0
    self:set_tile(tile)

    self.is_player = is_player or false

    self.spells = {}
    self.current_action = nil
    self.action_completed = false
    self.action_new = false

    self.acting = false
    self.shader = shader(true)

    self.died = false
    self.is_dead = false
    self.show_name = false
    self.is_moving = false
    self.outline = nil

    self.health_text = love.graphics.newText(healthFont)
    self.energy_text = love.graphics.newText(healthFont)

    self.status_effects = {}
    self.modifiers = {}    -- battle-модификаторы, ссылка передаётся в Stats

    self.miss_chance = 0
end

function Unit:setup(character, runModifiers)
    local rect = character.rect or {}
    if rect[2] == nil then
        for key, value in pairs(character) do
            print(key)
        end
    end
    self.sprite = Sprite(character.sprite_path, character.color)
    self.w, self.h = rect[1], rect[2]
    self.sw, self.sh = rect[3], rect[4]
    self.quad = love.graphics.newQuad(0, 0, self.w, self.h, self.sw, self.sh)

    self.name = character.name
    self.character = character
    self.attribute = character.attribute
    self.element = character.element

    -- self.modifiers уже создан в :init и будет наполняться battle-модификаторами.
    -- Передаём его в Stats по ссылке.
    self.stats = Stats(character, runModifiers or {}, self.modifiers)

    -- Производные поля (для быстрого доступа при отрисовке).
    -- Источник истины — self.stats, здесь только кеш.
    self:_cache_stats()

    -- Текущие значения (из Character, обрезанные по максимуму).
    self.health = math.min(character.health or self.max_health, self.max_health)
    self.energy = math.min(character.energy or self.max_energy, self.max_energy)

    -- Способности.
    for _, entry in ipairs(character.spells or {}) do
        local id, level, cooldown
        if type(entry) == 'string' then
            id = entry
        else
            id = entry.id
            level = entry.level
            cooldown = entry.current_cooldown
        end

        local template = spellList[id]
        if template then
            local spell = Class(template)
            spell.level = level or 1
            spell.current_cooldown = cooldown or 0
            spell.owner = self
            self.spells[#self.spells + 1] = spell
        else
            -- Раньше отсутствующий файл заклинания молча проглатывался:
            -- существо теряло способность без единого сообщения, и это
            -- выглядело как «баланс», а не как ошибка контента.
            print(('[Unit] %s: spell %q has no definition in src/spells/ — skipped')
                :format(tostring(character.name), tostring(id)))
        end
    end

    return self
end

-- ------------------------------------------------------------------
-- Статы
-- ------------------------------------------------------------------

-- Кешируем самые часто используемые статы в поля для отрисовки/логики.
function Unit:_cache_stats()
    self.max_health  = self.stats:get('max_health')
    self.max_energy  = self.stats:get('max_energy')
    self.damage      = self.stats:get('damage')
    self.armor       = self.stats:get('armor')
    self.initiative  = self.stats:get('initiative')
    self.attack_range = self.stats:get('attack_range')
    self.move_range   = self.stats:get('move_range')
    self.attack_type  = self.attack_range == 1 and 'melee' or 'ranged'
end

function Unit:get_stat(name)
    return self.stats:get(name)
end

function Unit:get_stats()
    return self.stats:all()
end

-- ------------------------------------------------------------------
-- Модификаторы
-- ------------------------------------------------------------------

function Unit:addModifier(mod)
    table.insert(self.modifiers, mod)
    self:refreshStats()
end

function Unit:removeModifier(mod)
    for i = #self.modifiers, 1, -1 do
        if self.modifiers[i] == mod then
            table.remove(self.modifiers, i)
            break
        end
    end
    self:refreshStats()
end

function Unit:hasModifier(id)
    for _, m in ipairs(self.modifiers) do
        if m.id == id then return true end
    end
    return false
end

function Unit:refreshStats()
    self.stats:invalidate()
    self:_cache_stats()

    -- Обрезаем текущие значения по новым максимумам (модификатор мог уменьшить max_health).
    if self.health then self.health = math.min(self.health, self.max_health) end
    if self.energy then self.energy = math.min(self.energy, self.max_energy) end

    -- Инициатива могла измениться — очередь нужно пересортировать.
    if BattleState and BattleState.queue then
        BattleState.queue:sort_next()
    end
end

-- ------------------------------------------------------------------
-- Здоровье и энергия
-- ------------------------------------------------------------------

function Unit:change_health(delta)
    self.health = math.max(0, math.min(self.health + delta, self.max_health))
    RunState:fireHook('on_low_health', self)
    return self.health
end

function Unit:change_energy(delta)
    self.energy = math.max(0, math.min(self.energy + delta, self.max_energy))
    return self.energy
end

function Unit:heal(amount)
    return self:change_health(amount)
end

-- ------------------------------------------------------------------
-- Статус-эффекты
-- ------------------------------------------------------------------

function Unit:add_status_effect(status_effect)
    table.insert(self.status_effects, status_effect)
end

function Unit:remove_status_effect(status_effect)
    for index, effect in ipairs(self.status_effects) do
        if effect == status_effect then
            effect:on_expire()
            table.remove(self.status_effects, index)
            return
        end
    end
end

-- ------------------------------------------------------------------
-- Позиционирование
-- ------------------------------------------------------------------

function Unit:set_acting()
    self.acting = true
    self.tile.acting = true
    self.tile:change_color()
end

function Unit:set_tile(tile)
    if self.tile and self.tile.actor == self then
        self.tile.is_blocked = false
        self.tile.actor = nil
    end
    self.tile = tile
    tile.is_blocked = true
    tile.actor = self
end

function Unit:bottom()
    return self.x, self.y + self.h / 2 - 8
end

-- ------------------------------------------------------------------
-- Способности
-- ------------------------------------------------------------------

function Unit:add_spell(spell)
    spell.current_cooldown = 0
    spell.owner = self
    self.spells[#self.spells + 1] = spell
end

function Unit:get_spells()
    return self.spells
end

-- ------------------------------------------------------------------
-- Отношения
-- ------------------------------------------------------------------

function Unit:ally_to(unit)
    if not unit then return nil end
    return self.is_player == unit.is_player
end

function Unit:enemy_to(unit)
    if not unit then return nil end
    return self.is_player ~= unit.is_player
end

-- ------------------------------------------------------------------
-- Урон
-- ------------------------------------------------------------------

--- Наносит урон. Возвращает фактически нанесённое значение.
--- @param source table|nil       Источник (Unit, spell, effect) — может быть nil для чистого урона
--- @param damage number          Базовый урон
--- @param is_attack boolean|nil  Флаг: это атака (для логов и брони)
--- @param element string|nil     Элемент атаки (для множителя). Если nil — берётся element источника
--- @param opts table|nil         { is_spell = bool } — включает STAB и spell_power
function Unit:take_damage(source, damage, is_attack, element, opts)
    if self.is_dead then return 0 end

    opts = opts or {}
    -- Атака ближнего боя и заклинание взаимоисключающи: броня применяется
    -- только к физическим атакам, STAB/spell_power — только к заклинаниям.
    if is_attack then opts.is_attack = true end

    local details = damageCalculator.details(source, self, damage, element, opts)
    local final_damage = details.total

    -- Визуальные эффекты. Цвет подсказывает игроку результат попадания
    -- ещё до того, как он прочитает лог.
    Tagtext:add('-' .. final_damage, self.x + 5, self.y - 40, 2, 30,
        damageCalculator.tierColor(details))
    BattleState.shaking = 4

    -- Применяем урон
    self:change_health(-final_damage)

    -- Хуки. element нужен Adaptation и другим resist-эффектам.
    RunState:fireHook('on_damage_taken', self, details.elem)
    if is_attack and source and source.attack_range == 1 then
        RunState:fireHook('on_melee_hit_taken', self, source)
    end

    -- Лог
    local tag = damageCalculator.describe(details)
    local suffix = tag ~= '' and (' (' .. tag .. ')') or ''
    if source and source.name then
        if is_attack then
            BattleState:addLog(source.name .. ' attack ' .. self.name .. ' for ' .. final_damage .. ' damage' .. suffix)
        else
            BattleState:addLog(self.name .. ' takes ' .. final_damage .. ' damage from ' .. source.name .. suffix)
        end
    end

    -- Смерть
    if self.health <= 0 then
        self:die(source)
    end

    return final_damage
end

function Unit:die(killer)
    if self.is_dead then return end

    self.health = 0
    self.is_dead = true
    self.died = true

    -- Освобождаем гекс
    self.tile.dead_unit = self
    self.tile.actor = nil
    self.tile.is_blocked = false

    RunState:fireHook('on_death', self)

    BattleState:unit_death(self, killer)
end

-- ------------------------------------------------------------------
-- Экспорт данных
-- ------------------------------------------------------------------

--- Синхронизация персистентного состояния обратно в Character.
--- Вызывается после боя для выживших.
function Unit:syncBackToCharacter()
    local c = self.character
    if not c then return end

    c.health = self.health
    c.energy = self.energy
    c.prepare_x = self.tile and self.tile.tx
    c.prepare_y = self.tile and self.tile.ty

    -- Если Character хранит кулдауны — синхронизируем
    if c.spells and type(c.spells[1]) == 'table' then
        for i, entry in ipairs(c.spells) do
            local spell = self.spells[i]
            if spell then
                entry.current_cooldown = spell.current_cooldown
            end
        end
    end
end

--- Создание Character из Unit (для захвата врагов).
function Unit:toCharacter()
    local spells = {}
    for i, spell in ipairs(self.spells) do
        spells[i] = {
            id = spell.id or spell.name,
            level = spell.level or 1,
            current_cooldown = 0,
        }
    end

    return {
        name = self.name,
        sprite_path = self.sprite.path,
        rect = { self.w, self.h, self.sw, self.sh },

        max_health = self.max_health,
        health = self.max_health,     -- захваченный приходит с полным HP
        max_energy = self.max_energy,
        energy = self.max_energy,
        damage = self.damage,
        attack_range = self.attack_range,
        move_range = self.move_range,
        initiative = self.initiative,
        armor = self.armor,

        attribute = self.attribute,
        element = self.element,

        spells = spells,
        modifiers = {},               -- без временных бафов
    }
end

-- Обратная совместимость со старым API.
function Unit:convertToParty()
    return self:toCharacter()
end

-- ------------------------------------------------------------------
-- Отрисовка
-- ------------------------------------------------------------------

function Unit:update(dt)
end

-- mathemagic
local p1 = Vector(0, HEX_RADIUS * HEX_HEIGHT)
local p2 = Vector(HEX_RADIUS * math.sqrt(3) / 2, HEX_RADIUS / 2 * HEX_HEIGHT)
local p3 = Vector(-p2.x, p2.y)

local kx = 0
local offset = 5

local rotation  = p1:angleTo(p2)
local rotation2 = p3:angleTo(p1)

local distance = p1:dist(p2)

local health_w = distance
local health_h = 16

local health_x = p1.x
local health_y = p1.y - health_h

local energy_x = p3.x
local energy_y = p3.y - health_h

function Unit:draw_name()
    if not self.show_name then return end

    local x, y = self.x, self.y

    local w = health_w
    local h = health_h
    local rx = x
    local ry = y + health_y - health_h - 1

    local tx = rx + 2
    local ty = ry + ((h - fontSize) / 2) - 1

    love.graphics.setFont(healthFont)
    love.graphics.setColor(0, 0, 0, 1)
    PrintText(self.name, tx, ty, rotation)
end

local d = 1
local sides = {
    { -d, 0 }, { d, 0 }, { 0, -d }, { 0, d },
    { d, d }, { -d, -d }, { -d, d }, { d, -d }
}

function Unit:draw_health(x, y)
    if self.is_dead then return end

    love.graphics.setFont(healthFont)

    local healthString = self.health .. '/' .. self.max_health
    local w = healthFont:getWidth(healthString)
    local h = healthFont:getHeight() - 1
    local rx, ry = math.floor(x - w / 2), math.floor(y) + 10

    self.health_text:setf(healthString, w, 'center')
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.draw(self.health_text, rx + 1, ry + 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.health_text, rx, ry)
end

function Unit:draw_outline(r, g, b, size)
    local x, y, z = self.x, self.y, self.z

    self.shader:outline(r, g, b)
    self.shader:draw(size, self.sprite.image, self.quad,
        x, y - z, 0,
        self.sprite_sx or 1, self.sprite_sy or 1,
        self.w * 0.5, self.h * 0.5)
end

function Unit:draw()
    if self.is_dead and self.tile.actor then return end

    local x, y, z = self.x, self.y, self.z

    if self.show_name then
        self:draw_outline(1, 1, 1, 2)
    end

    if self.acting then
        self:draw_outline(0, 1, 0, 1)
    end

    love.graphics.setColor(1, 1, 1, 1)
    self.sprite:draw(self.quad, x, y - z, 0,
        self.sprite_sx or 1, self.sprite_sy or 1,
        self.w * 0.5, self.h * 0.5)

    self:draw_health(x, y + 40)
end

function Unit:remove()
    if self.tile then
        self.tile.actor = nil
        self.tile.is_blocked = false
    end
end

return Unit