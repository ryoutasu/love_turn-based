-- src/damage_calculator.lua
--
-- Единая точка расчёта урона.
--
-- Конвейер (порядок важен — он же порядок в логе/подсказке):
--   1. attr_mul  — атрибут атакующего против атрибута цели (wild/mystic/...)
--   2. elem_mul  — элемент заклинания против элемента цели (ember/water/...)
--   3. stab      — бонус за «свой» элемент (только для заклинаний)
--   4. spell_power — множитель силы заклинаний кастера (апгрейды)
--   5. resist    — сопротивление цели конкретному элементу (Adaptation и пр.)
--   6. armor     — процентное снижение для физических атак (с учётом pierce)
--   7. percent_hp_damage — плоская добавка от Exhaustion (после брони)
--
-- ВАЖНО: раньше броня вычиталась как `base - armor`, что при armor=2 и
-- базе 10 давало -80% урона — нелинейно и нечитаемо.
-- Теперь используется кривая `armor / (armor + K)` с мягким насыщением.
--
-- K откалиброван под ФАКТИЧЕСКИЙ диапазон брони в игре (0..2 у существ,
-- максимум 3 с апгрейдами). При K=20 броня 1 давала 5% — игрок этого
-- не замечал, и вся характеристика была декоративной.
--
-- K = 5 даёт при базе 10:
--   armor 0 -> -0%    armor 1 -> -17%   armor 2 -> -29%   armor 3 -> -38%
--   (насыщение: 4 -> -44%, 8 -> -62%, кап 75%)
-- Это заметно, но не «неубиваемость»: броня никогда не режет больше 75%.

local TypeChart = require 'data.type_chart'

local DamageCalculator = {}

local ARMOR_K     = 5      -- точка полунасыщения кривой брони
local ARMOR_CAP   = 0.75   -- броня не может срезать больше 75%
local RESIST_CAP  = 0.75   -- сопротивление тоже ограничено
local MIN_DAMAGE  = 1      -- минимальный ненулевой урон

-- ------------------------------------------------------------------
-- Безопасное чтение статов
-- ------------------------------------------------------------------

-- Цель — почти всегда Unit, но события и предметы могут передать
-- Character, у которого нет get_stat. Тогда читаем поле напрямую.
local function stat_of(entity, name)
    if not entity then return nil end
    if entity.get_stat then
        local ok, value = pcall(entity.get_stat, entity, name)
        if ok and value ~= nil then return value end
    end
    return entity[name]
end

local function num_of(entity, name, default)
    local v = stat_of(entity, name)
    if type(v) ~= 'number' then return default end
    return v
end

-- ------------------------------------------------------------------
-- Основной расчёт
-- ------------------------------------------------------------------

--- Полный расчёт с разбивкой по шагам.
--- @return table { total, base, attr_mul, elem_mul, stab, spell_power, resist,
---                 armor_reduction, percent_bonus, attr_tier, elem_tier, elem }
function DamageCalculator.details(source, target, base, element, opts)
    opts = opts or {}
    base = tonumber(base) or 0

    local result = {
        base            = base,
        attr_mul        = TypeChart.MULT.neutral,
        elem_mul        = TypeChart.MULT.neutral,
        stab            = 1,
        spell_power     = 1,
        resist          = 0,
        armor_reduction = 0,
        percent_bonus   = 0,
        total           = math.max(MIN_DAMAGE, math.floor(base)),
        attr_tier       = 'neutral',
        elem_tier       = 'neutral',
        elem            = element,
    }

    if not target then
        return result
    end

    -- 1. Атрибут ----------------------------------------------------
    if source and source.attribute and target.attribute then
        result.attr_mul  = TypeChart.getAttributeMultiplier(source.attribute, target.attribute)
        result.attr_tier = TypeChart.classify(result.attr_mul)
    end

    -- 2. Элемент ----------------------------------------------------
    -- Если элемент не передан явно — берём собственный элемент источника.
    local elem = element or (source and source.element) or nil
    result.elem = elem

    if elem and target.element then
        result.elem_mul  = TypeChart.getElementMultiplier(elem, target.element)
        result.elem_tier = TypeChart.classify(result.elem_mul)
    end

    -- 3. STAB -------------------------------------------------------
    -- Только для заклинаний: «своим» элементом бить выгоднее.
    -- Базовые атаки не получают бонус, иначе он есть у всех всегда
    -- и перестаёт быть решением игрока.
    -- 'neutral' — не элемент, а физический урон: STAB на нём не выдаётся,
    -- иначе любой нейтральный спелл получал бы +50% просто так.
    if opts.is_spell and elem and elem ~= 'neutral'
       and source and source.element == elem then
        result.stab = TypeChart.STAB
    end

    -- 4. Сила заклинаний --------------------------------------------
    if opts.is_spell then
        result.spell_power = num_of(source, 'spell_power', 1)
        -- Точечные мастерии: «+25% к огню» и т.п.
        if elem then
            result.spell_power = result.spell_power * num_of(source, 'spell_power_' .. elem, 1)
        end
    end

    local damage = base
        * result.attr_mul
        * result.elem_mul
        * result.stab
        * result.spell_power

    -- 5. Сопротивление элементу -------------------------------------
    if elem then
        local resist = num_of(target, 'resist_' .. elem, 0)
        resist = math.min(math.max(resist, 0), RESIST_CAP)
        result.resist = resist
        damage = damage * (1 - resist)
    end

    -- 6. Броня (только физические атаки) ----------------------------
    if opts.is_attack then
        local armor  = math.max(0, num_of(target, 'armor', 0))
        local pierce = math.min(math.max(num_of(source, 'armor_pierce', 0), 0), 0.9)

        local eff_armor = armor * (1 - pierce)
        local reduction = eff_armor / (eff_armor + ARMOR_K)
        reduction = math.min(reduction, ARMOR_CAP)

        result.armor_reduction = reduction
        damage = damage * (1 - reduction)
    end

    -- 7. Exhaustion: % от max_hp, после брони и сопротивлений --------
    local pct = num_of(source, 'percent_hp_damage', 0)
    if pct > 0 then
        local max_hp = num_of(target, 'max_health', 0)
        result.percent_bonus = math.floor(max_hp * pct)
        damage = damage + result.percent_bonus
    end

    -- Иммунитет — единственный случай, когда урон действительно 0.
    if result.attr_mul <= 0 or result.elem_mul <= 0 then
        result.total = 0
        return result
    end

    result.total = math.max(MIN_DAMAGE, math.floor(damage))
    return result
end

--- Обратная совместимость: возвращает только итоговое число.
function DamageCalculator.calculate(source, target, base, element, opts)
    return DamageCalculator.details(source, target, base, element, opts).total
end

-- ------------------------------------------------------------------
-- Подсказки для UI
-- ------------------------------------------------------------------

--- Короткая строка вида «effective, super effective» для боевого лога.
--- Возвращает '' для нейтрального удара, чтобы не засорять лог.
function DamageCalculator.describe(details)
    if not details then return '' end
    local parts = {}

    local attr_label = TypeChart.LABELS[details.attr_tier]
    local elem_label = TypeChart.LABELS[details.elem_tier]

    if attr_label and attr_label ~= '' then parts[#parts + 1] = attr_label end
    if elem_label and elem_label ~= '' then parts[#parts + 1] = elem_label end

    return table.concat(parts, ', ')
end

--- Цвет всплывающего текста урона — игрок должен видеть результат
--- без чтения лога.
function DamageCalculator.tierColor(details)
    if not details then return { 1, 0.3, 0.3 } end

    local worst = math.min(details.attr_mul, details.elem_mul)
    local best  = math.max(details.attr_mul, details.elem_mul)

    if worst <= 0            then return { 0.55, 0.55, 0.55 } end -- immune
    if best  >= 1.99         then return { 1.00, 0.85, 0.15 } end -- super effective
    if best  >= 1.49         then return { 1.00, 0.55, 0.20 } end -- effective
    if worst <  0.99         then return { 0.60, 0.80, 1.00 } end -- resisted
    return { 1, 0.3, 0.3 }                                        -- neutral
end

return DamageCalculator
