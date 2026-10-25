local TypeChart = require 'data.type_chart'

local DamageCalculator = {}

local ARMOR_K    = 20
local ARMOR_CAP  = 0.75
local RESIST_CAP = 0.75
local MIN_DAMAGE = 1

--- @param source  table|nil  Unit, spell, effect — источник. Может быть nil.
--- @param target  Unit       Получатель.
--- @param base    number     Базовый урон.
--- @param element string|nil Элемент (если nil — берётся source.element).
--- @param opts    table|nil  { is_attack = bool }
function DamageCalculator.calculate(source, target, base, element, opts)
    opts = opts or {}
    if not target then return math.max(MIN_DAMAGE, base) end
    
    -- 1. Атрибут
    local attr_mul = 1
    if source and source.attribute and target.attribute then
        attr_mul = TypeChart.getAttributeMultiplier(source.attribute, target.attribute)
    end
    
    -- 2. Элемент
    local elem = element or (source and source.element) or nil
    local elem_mul = 1
    if elem and target.element then
        elem_mul = TypeChart.getElementMultiplier(elem, target.element)
    end

    local damage = base * attr_mul * elem_mul

    -- 3. Resist элемента (Adaptation и другие resist_<element> модификаторы)
    if elem then
        local resist = target:get_stat('resist_' .. elem) or 0
        resist = math.min(math.max(resist, 0), RESIST_CAP)
        damage = damage * (1 - resist)
    end
    
    -- 4. Броня (только физические атаки)
    if opts.is_attack then
        local armor = target:get_stat('armor') or 0
        local pierce = (source and source:get_stat('armor_pierce')) or 0

        local eff_armor = armor * (1 - pierce)
        eff_armor = math.max(0, eff_armor)

        local reduction = eff_armor / (eff_armor + ARMOR_K)
        reduction = math.min(reduction, ARMOR_CAP)

        damage = damage * (1 - reduction)
    end
    
    -- 5. Exhaustion: % от max_hp, без снижения (bypass armor + resist)
    local pct = (source and source:get_stat('percent_hp_damage')) or 0
    if pct > 0 then
        local max_hp = target:get_stat('max_health') or 0
        damage = damage + math.floor(max_hp * pct)
    end

    return math.max(MIN_DAMAGE, math.floor(damage))
end

return DamageCalculator