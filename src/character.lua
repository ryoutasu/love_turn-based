local Sprite     = require 'src.sprite'
local Characters = require 'src.characters'
local Upgrades   = require 'data.upgrades'

local Character = {}

function Character.new(template)
    local c = {}
    for k, v in pairs(template) do c[k] = v end
    
    c.spells = {}
    for i, spell in ipairs(template.spells or {}) do
        c.spells[i] = spell
    end

    c.modifiers = c.modifiers or {}
    c.health = c.health or c.max_health
    c.energy = c.energy or c.max_energy
    c.level = c.level or 1
    c.exp = c.exp or 0

    c.sprite = Sprite(c.sprite_path, c.color)
    local w, h = c.sprite.w, c.sprite.h
    c.quad = love.graphics.newQuad(0, 0, w, h, w, h)

    return c
end

function Character.applyModifier(c, mod)
    table.insert(c.modifiers, mod)
end

function Character.addModifiers(c, pack)
    for _, mod in ipairs(pack) do
        Character.applyModifier(c, mod)
    end
end

function Character.removeModifier(c, id)
    for i = #c.modifiers, 1, -1 do
        if c.modifiers[i].id == id then
            table.remove(c.modifiers, i)
        end
    end
end

function Character.levelUp(c)
    
end

-- ------------------------------------------------------------------
-- Serialization
-- ------------------------------------------------------------------

--- Сохраняем только мутабельные поля. Всё, что задаётся шаблоном
--- (sprite, rect, базовые статы, attack_range и т.д.), восстанавливается
--- через Character.new(template) при загрузке.
function Character.serialize(c)
    if not c then return nil end

    local data = {
        name       = c.name,
        health     = c.health,
        energy     = c.energy,
        prepare_x  = c.prepare_x,
        prepare_y  = c.prepare_y,
        attribute  = c.attribute,
        element    = c.element,
        level      = c.level,
        exp        = c.exp,
        _second_chance_available = c._second_chance_available,
        modifiers  = {},
        spells     = {},
    }

    for i, m in ipairs(c.modifiers or {}) do
        data.modifiers[i] = {
            id       = m.id,
            scope    = m.scope,
            stat     = m.stat,
            op       = m.op,
            value    = m.value,
            source   = m.source,
            stack    = m.stack,
            duration = m.duration and {
                type    = m.duration.type,
                value   = m.duration.value,
                tick_on = m.duration.tick_on,
            } or nil,
        }
    end

    for i, entry in ipairs(c.spells or {}) do
        if type(entry) == 'string' then
            data.spells[i] = entry
        else
            data.spells[i] = {
                id               = entry.id,
                level            = entry.level,
                current_cooldown = entry.current_cooldown,
            }
        end
    end

    return data
end

--- Восстанавливаем Character: берём свежий шаблон (для sprite, quad, базы),
--- затем накатываем сохранённое состояние.
function Character.deserialize(data)
    if not data then return nil end

    local template = Characters[data.name] or data
    local c = Character.new(template)

    c.health     = data.health
    c.energy     = data.energy
    c.prepare_x  = data.prepare_x
    c.prepare_y  = data.prepare_y
    c.attribute  = data.attribute or c.attribute
    c.element    = data.element   or c.element
    c.level      = data.level     or 1
    c.exp        = data.exp       or 0
    c._second_chance_available = data._second_chance_available

    -- Модификаторы: восстанавливаем filter/on_expire из Upgrades по source
    c.modifiers = {}
    for _, m in ipairs(data.modifiers or {}) do
        local up = Upgrades[m.source]
        if up then
            if up.filter     then m.filter     = up.filter     end
            if up.on_expire  then m.on_expire  = up.on_expire  end
        end
        table.insert(c.modifiers, m)
    end

    -- Способности — как есть (строки или таблицы)
    c.spells = {}
    for _, entry in ipairs(data.spells or {}) do
        table.insert(c.spells, entry)
    end

    return c
end

-- function Character.getStats(c, runModifiers) ... end
-- function Character.levelUp(c) ... end
-- function Character.syncFromUnit(c, unit) ... end
-- function Character.addSpell(c, spell) ... end

return Character