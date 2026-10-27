local Stats    = require 'src.stats'
local RunState = require 'src.states.run_state'

local Effects = {}

function Effects.apply(effect, item, subject, context)
    local handler = Effects[effect.type]
    if not handler then
        print('[Items.Effects] Unknown effect type: ' .. tostring(effect.type))
        return
    end
    handler(effect, item, subject, context)
end

local function tag(subject, text, color)
    if subject.x and subject.y then
        Tagtext:add(text, subject.x + 5, subject.y - 40, 1, 30,
            color or { 1, 1, 1 })
    end
end

-- restore_hp { amount = N }
function Effects.restore_hp(effect, item, subject, context)
    local amount = effect.amount or 0
    if context == 'unit' then
        subject:change_health(amount)
    elseif context == 'character' then
        local stats  = Stats(subject, RunState:getModifiers(), {})
        local max_hp = stats:get('max_health')
        subject.health = math.min(subject.health + amount, max_hp)
    end
    tag(subject, '+' .. amount, item.color)
end

-- restore_energy { amount = N }
function Effects.restore_energy(effect, item, subject, context)
    local amount = effect.amount or 0
    if context == 'unit' then
        subject:change_energy(amount)
    elseif context == 'character' then
        local stats  = Stats(subject, RunState:getModifiers(), {})
        local max_en = stats:get('max_energy')
        subject.energy = math.min(subject.energy + amount, max_en)
    end
    tag(subject, '+' .. amount, item.color)
end

-- add_modifier { modifier = { ... } }
-- Применяется только к Unit. На карте — игнорируется (модификаторы живут в бою).
function Effects.add_modifier(effect, item, subject, context)
    if context ~= 'unit' then return end

    -- Копируем, чтобы не мутировать шаблон из data
    local m = {}
    for k, v in pairs(effect.modifier) do m[k] = v end
    subject:addModifier(m)
    tag(subject, effect.label or 'Buff!', item.color)
end

-- damage { amount = N }
function Effects.damage(effect, item, subject, context)
    local amount = effect.amount or 0
    if context == 'unit' then
        subject:take_damage(item.caster, amount, false)
    end
end

return Effects