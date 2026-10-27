local Spellcast = Class{}

function Spellcast:init(caster, target, spell)
    if spell.type == 'unit' then
        target = target.actor
    end
    self.caster = caster
    self.target = target

    self.spell = spell

    self.effects = {}

    self.isStarted = false
    self.isCompleted = false
end

function Spellcast:startCast()
    self.isStarted = true
    self.spell.onCast(self, self.caster, self.target)
    
    -- if not self.target or self.target.actor == self.actor then
    --     BattleState:addLog(self.actor.name .. ' casts ' .. self.spellcast.spell.name .. '!')
    -- end
end

function Spellcast:addEffect(effect)
    table.insert(self.effects, effect)
end

function Spellcast:complete()
    self.isCompleted = true
end

--- Единая точка нанесения урона для заклинаний.
---
--- Зачем метод, а не прямой вызов target:take_damage(...):
--- элемент заклинания и флаг is_spell должны попадать в калькулятор
--- ВСЕГДА. Раньше каждый spell-файл звал take_damage(caster, dmg) без
--- элемента, поэтому стихийные множители, STAB, resist и апгрейды вида
--- element_mastery_* не работали вообще.
---
--- @param target Unit|nil  Цель (по умолчанию self.target)
--- @param amount number|nil Базовый урон (по умолчанию self.spell.damage)
--- @param element string|nil Переопределить элемент (по умолчанию элемент заклинания)
function Spellcast:dealDamage(target, amount, element)
    target = target or self.target
    if not target or not target.take_damage then return 0 end

    local spell = self.spell or {}
    amount  = amount  or spell.damage or 0
    element = element or spell.element

    return target:take_damage(self.caster, amount, false, element, { is_spell = true })
end

--- Урон по всем юнитам на клетке (AoE-заклинания).
function Spellcast:dealAreaDamage(tiles, amount, element)
    local total = 0
    for _, tile in ipairs(tiles or {}) do
        if tile.actor and not tile.actor.is_dead then
            total = total + self:dealDamage(tile.actor, amount, element)
        end
    end
    return total
end

function Spellcast:update(dt)
    for index, effect in ipairs(self.effects) do
        effect:update(dt)
    end
end

function Spellcast:draw()
    for index, effect in ipairs(self.effects) do
        effect:draw()
    end
end

return Spellcast