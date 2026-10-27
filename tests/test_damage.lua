-- tests/test_damage.lua
--
-- Запуск (без LÖVE, нужен только Lua 5.1+/LuaJIT):
--   lua tests/test_damage.lua
--
-- Проверяем чистую математику: чарт типов, конвейер урона, дефолты Stats.
-- Всё остальное (визуал, состояния) требует LÖVE и здесь не тестируется.

local here = (arg and arg[0] or ''):match('^(.*)[/\\]') or '.'
package.path = here .. '/../?.lua;' .. here .. '/../?/init.lua;' .. package.path

-- ------------------------------------------------------------------
-- Минимальные заглушки
-- ------------------------------------------------------------------

_G.Class = function(base)
    base = base or {}
    base.__index = base
    return setmetatable(base, { __call = function(c, ...)
        local o = setmetatable({}, c)
        if o.init then o:init(...) end
        return o
    end })
end

-- ------------------------------------------------------------------
-- Мини-фреймворк
-- ------------------------------------------------------------------

local passed, failed = 0, 0
local failures = {}

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        failures[#failures + 1] = name .. '\n    ' .. tostring(err)
    end
end

local function eq(actual, expected, label)
    if actual ~= expected then
        error(('%s: expected %s, got %s'):format(label or 'eq', tostring(expected), tostring(actual)), 2)
    end
end

local function near(actual, expected, eps, label)
    eps = eps or 0.0001
    if math.abs(actual - expected) > eps then
        error(('%s: expected ~%.4f, got %.4f'):format(label or 'near', expected, actual), 2)
    end
end

-- ------------------------------------------------------------------
-- Загрузка модулей
-- ------------------------------------------------------------------

local Chart    = require 'data.type_chart'
local Dmg      = require 'src.damage_calculator'

-- Фейковый юнит: только то, что читает калькулятор.
local function unit(t)
    t = t or {}
    return {
        attribute         = t.attribute or 'wild',
        element           = t.element   or 'neutral',
        armor             = t.armor     or 0,
        max_health        = t.max_health or 30,
        attack_range      = t.attack_range or 1,
        spell_power       = t.spell_power or 1,
        armor_pierce      = t.armor_pierce or 0,
        percent_hp_damage = t.percent_hp_damage or 0,
    }
end

-- ==================================================================
-- 1. Целостность чарта
-- ==================================================================

test('chart validates: every cell filled', function()
    eq(Chart.validate(), true)
end)

test('chart: no nil rows for any attribute (was the ancient/chaos crash)', function()
    for _, a in ipairs({ 'wild', 'mystic', 'mechanic', 'ancient', 'chaos' }) do
        for _, d in ipairs({ 'wild', 'mystic', 'mechanic', 'ancient', 'chaos' }) do
            near(Chart.getAttributeMultiplier(a, d), Chart.getAttributeMultiplier(a, d))
        end
    end
end)

test('chart: unknown type is neutral, not a crash', function()
    eq(Chart.getAttributeMultiplier('nonsense', 'wild'), 1)
    eq(Chart.getAttributeMultiplier('wild', 'nonsense'), 1)
    eq(Chart.getAttributeMultiplier(nil, 'wild'), 1)
    eq(Chart.getElementMultiplier('nonsense', 'ember'), 1)
    eq(Chart.getElementMultiplier(nil, nil), 1)
end)

test('chart: attribute triangle is reciprocal', function()
    eq(Chart.getAttributeMultiplier('wild', 'mystic'), 1.5, 'wild>mystic')
    eq(Chart.getAttributeMultiplier('mystic', 'wild'), 0.5, 'mystic<wild')
    eq(Chart.getAttributeMultiplier('mystic', 'mechanic'), 1.5, 'mystic>mechanic')
    eq(Chart.getAttributeMultiplier('mechanic', 'mystic'), 0.5, 'mechanic<mystic')
    eq(Chart.getAttributeMultiplier('mechanic', 'wild'), 1.5, 'mechanic>wild')
    eq(Chart.getAttributeMultiplier('wild', 'mechanic'), 0.5, 'wild<mechanic')
end)

test('chart: ancient/chaos are not free upgrades', function()
    -- ancient бьёт chaos, но уязвим к обычным типам
    eq(Chart.getAttributeMultiplier('ancient', 'chaos'), 1.5, 'ancient>chaos')
    eq(Chart.getAttributeMultiplier('ancient', 'wild'), 0.75, 'ancient weak vs wild')
    eq(Chart.getAttributeMultiplier('chaos', 'ancient'), 0.5, 'chaos resists ancient')
    eq(Chart.getAttributeMultiplier('wild', 'chaos'), 1.0, 'chaos neutral vs wild')
end)

test('chart: element cycle ember>earth>storm>water>ember', function()
    eq(Chart.getElementMultiplier('ember', 'earth'), 1.5)
    eq(Chart.getElementMultiplier('earth', 'storm'), 1.5)
    eq(Chart.getElementMultiplier('storm', 'water'), 1.5)
    eq(Chart.getElementMultiplier('water', 'ember'), 1.5)
    -- и обратное направление — сопротивление
    eq(Chart.getElementMultiplier('earth', 'ember'), 0.5)
end)

test('chart: light <-> dark is mutual x2', function()
    eq(Chart.getElementMultiplier('light', 'dark'), 2.0)
    eq(Chart.getElementMultiplier('dark', 'light'), 2.0)
    eq(Chart.getElementMultiplier('light', 'light'), 0.5)
end)

test('chart: neutral element is neutral against everything', function()
    for _, e in ipairs({ 'ember', 'water', 'earth', 'storm', 'light', 'dark', 'plant', 'neutral' }) do
        eq(Chart.getElementMultiplier('neutral', e), 1.0, 'neutral vs ' .. e)
        eq(Chart.getElementMultiplier(e, 'neutral'), 1.0, e .. ' vs neutral')
    end
end)

test('chart: classify maps multipliers to tiers', function()
    eq(Chart.classify(0), 'immune')
    eq(Chart.classify(0.5), 'weak')
    eq(Chart.classify(1), 'neutral')
    eq(Chart.classify(1.5), 'strong')
    eq(Chart.classify(2), 'crush')
end)

-- ==================================================================
-- 2. Конвейер урона
-- ==================================================================

test('damage: plain hit ignores armor (attack not flagged)', function()
    local a, d = unit{ damage = 10 }, unit{ armor = 20, element = 'neutral' }
    eq(Dmg.calculate(a, d, 10, nil, {}), 10)
end)

test('damage: armor reduces physical attacks via saturation curve', function()
    local a = unit{ attack_range = 1 }
    local no_armor = unit{ armor = 0 }
    local some     = unit{ armor = 2 }
    local lots     = unit{ armor = 20 }

    local d0  = Dmg.calculate(a, no_armor, 20, nil, { is_attack = true })
    local d2  = Dmg.calculate(a, some,     20, nil, { is_attack = true })
    local d20 = Dmg.calculate(a, lots,     20, nil, { is_attack = true })

    -- K = 5 (откалиброван под реальную броню 0..3 в игре):
    --   armor 2  -> 2/(2+5)  = 28.6%  -> 20 * 0.714 = 14
    --   armor 20 -> 20/25    = 80% -> кап 75% -> 20 * 0.25 = 5
    eq(d0, 20)
    eq(d2, 14)
    eq(d20, 5)
    if not (d0 > d2 and d2 > d20) then
        error('armor must be monotonic: ' .. d0 .. ' > ' .. d2 .. ' > ' .. d20)
    end
end)

test('damage: even armor 1 is noticeable (>10%)', function()
    -- Защита от регрессии: при K=20 броня 1 давала всего 5%, и
    -- характеристика была декоративной.
    local a = unit{ attack_range = 1 }
    local det = Dmg.details(a, unit{ armor = 1 }, 10, nil, { is_attack = true })
    if det.armor_reduction < 0.10 then
        error('armor 1 reduction too small: ' .. det.armor_reduction)
    end
    eq(det.total, 8)   -- 10 * (1 - 1/6) = 8.33 -> 8
end)

test('damage: armor never reaches zero damage', function()
    local a = unit{ attack_range = 1 }
    local tank = unit{ armor = 100000 }
    -- reduction капнута на ARMOR_CAP = 0.75, поэтому остаётся 25% урона.
    -- 10 * 0.25 = 2.5 -> 2. Главное — не 0.
    eq(Dmg.calculate(a, tank, 10, nil, { is_attack = true }), 2, 'min damage clamp')
end)

test('damage: armor pierce reduces effective armor', function()
    local plain   = unit{ attack_range = 1 }
    local pierced = unit{ attack_range = 1, armor_pierce = 0.5 }
    local target  = unit{ armor = 20 }

    local d_plain  = Dmg.calculate(plain,   target, 20, nil, { is_attack = true })
    local d_pierce = Dmg.calculate(pierced, target, 20, nil, { is_attack = true })

    -- plain:  20/25 = 80% -> кап 75% -> 20 * 0.25 = 5
    -- pierced: armor 20*0.5 = 10 -> 10/15 = 66.7% -> 20 * 0.333 = 6
    eq(d_plain, 5)
    eq(d_pierce, 6)
    if not (d_pierce > d_plain) then
        error('pierce should increase damage: ' .. d_pierce .. ' vs ' .. d_plain)
    end
end)

test('damage: attribute advantage compounds with element advantage', function()
    local a = unit{ attribute = 'wild',   element = 'ember' }
    local d = unit{ attribute = 'mystic', element = 'earth' }
    -- wild>mystic (1.5) * ember>earth (1.5) = 2.25
    eq(Dmg.calculate(a, d, 10, 'ember'), 22)
end)

test('damage: attribute disadvantage reduces damage', function()
    local a = unit{ attribute = 'wild', element = 'neutral' }
    local d = unit{ attribute = 'mechanic' }
    eq(Dmg.calculate(a, d, 10, 'neutral'), 5)   -- 10 * 0.5
end)

test('damage: element falls back to source.element when not passed', function()
    local a = unit{ element = 'water' }
    local d = unit{ element = 'ember' }
    -- water > ember = 1.5
    eq(Dmg.calculate(a, d, 10), 15)
end)

test('damage: STAB only applies to spells', function()
    local a = unit{ element = 'ember' }
    local d = unit{ element = 'water' }   -- ember vs water = 0.5, so isolate STAB

    local as_spell = unit{ element = 'ember' }
    local no_stab  = Dmg.calculate(a, d, 10, 'ember', {})
    local with_stab = Dmg.calculate(as_spell, d, 10, 'ember', { is_spell = true })

    -- 10 * 0.5 = 5 без STAB; 10 * 0.5 * 1.5 = 7.5 -> 7 со STAB
    eq(no_stab, 5)
    eq(with_stab, 7)
end)

test('damage: no STAB when spell element differs from caster element', function()
    local a = unit{ element = 'ember' }
    local d = unit{ element = 'neutral' }
    local with = Dmg.calculate(a, d, 10, 'water', { is_spell = true })
    eq(with, 10, 'water spell from ember caster gets no STAB')
end)

test('damage: spell_power multiplies spell damage', function()
    -- Кастер ember, спелл ember -> есть и STAB, и spell_power.
    local a = unit{ element = 'ember', spell_power = 1.2 }
    local d = unit{ element = 'neutral' }
    -- 10 * 1.0 (attr) * 1.0 (elem) * 1.5 (STAB) * 1.2 = 18
    eq(Dmg.calculate(a, d, 10, 'ember', { is_spell = true }), 18)

    -- Без STAB (нейтральный элемент) остаётся только spell_power.
    eq(Dmg.calculate(a, d, 10, 'neutral', { is_spell = true }), 12)
end)

test('damage: per-element spell_power stacks with global', function()
    -- Нейтральный спелл: STAB не применяется, поэтому чистая арифметика.
    local a = unit{ element = 'neutral', spell_power = 1.2 }
    a.spell_power_ember = 1.5
    local d = unit{ element = 'neutral' }
    -- 10 * 1.2 * 1.5 = 18
    eq(Dmg.calculate(a, d, 10, 'ember', { is_spell = true }), 18)
end)

test('damage: resist_<element> reduces damage and is capped', function()
    local a = unit{ element = 'neutral' }   -- без STAB
    local d = unit{}
    d.resist_ember = 0.2
    eq(Dmg.calculate(a, d, 10, 'ember', { is_spell = true }), 8)

    d.resist_ember = 5   -- cap RESIST_CAP = 0.75 -> остаётся 25%
    -- 10 * 0.25 = 2.5 -> 2
    eq(Dmg.calculate(a, d, 10, 'ember', { is_spell = true }), 2)
end)

test('damage: percent_hp_damage adds flat bonus after armor', function()
    local a = unit{ percent_hp_damage = 0.1 }
    local d = unit{ max_health = 40, armor = 0 }
    -- 10 * 1.0 + floor(40*0.1)=4  => 14
    eq(Dmg.calculate(a, d, 10, 'neutral', {}), 14)
end)

test('damage: nil source never crashes (blood_deal regression)', function()
    local d = unit{ armor = 5 }
    local ok, result = pcall(Dmg.calculate, nil, d, 10, nil, { is_attack = true })
    if not ok then error('calculate with nil source crashed: ' .. tostring(result)) end
    -- 10 * (1 - 5/(5+5)) = 10 * 0.5 = 5
    near(result, 5, 0.001, 'nil source damage')
end)

test('damage: nil target returns base, never crashes', function()
    eq(Dmg.calculate(unit{}, nil, 10, 'ember', {}), 10)
end)

test('damage: Character-like table without get_stat works', function()
    -- События и предметы могут передать Character (нет get_stat)
    local attacker = { attribute = 'wild', element = 'ember' }
    local defender = { attribute = 'mystic', element = 'earth', armor = 0 }
    nearby = Dmg.calculate(attacker, defender, 10, 'ember', {})
    eq(nearby, 22)
end)

-- ==================================================================
-- 3. Объект разбивки (для UI)
-- ==================================================================

test('details: exposes every stage', function()
    local a = unit{ attribute = 'wild',   element = 'ember', spell_power = 1.1 }
    local d = unit{ attribute = 'mystic', element = 'earth' }
    local r = Dmg.details(a, d, 10, 'ember', { is_spell = true })

    near(r.attr_mul, 1.5)
    near(r.elem_mul, 1.5)
    near(r.stab, 1.5)
    near(r.spell_power, 1.1)
    eq(r.elem, 'ember')
    eq(r.attr_tier, 'strong')
    eq(r.elem_tier, 'strong')
    -- 10 * 1.5 * 1.5 * 1.5 * 1.1 = 37.125
    eq(r.total, 37)
end)

test('describe: neutral hit produces empty string', function()
    local a = unit{ attribute = 'wild', element = 'neutral' }
    local d = unit{ attribute = 'wild', element = 'neutral' }
    local r = Dmg.details(a, d, 10, 'neutral', {})
    -- wild vs wild = neutral, neutral vs neutral = neutral
    eq(Dmg.describe(r), '')
end)

test('describe: super effective is reported', function()
    local a = unit{ attribute = 'wild', element = 'light' }
    local d = unit{ attribute = 'wild', element = 'dark' }
    local r = Dmg.details(a, d, 10, 'light', {})
    local s = Dmg.describe(r)
    if s == '' then error('expected a non-empty description, got ""') end
    if not s:find('effective') then error('expected "effective" in "' .. s .. '"') end
end)

test('tierColor: returns a colour table for every case', function()
    local function check(r)
        local c = Dmg.tierColor(r)
        if type(c) ~= 'table' or #c < 3 then error('bad colour') end
    end
    check(Dmg.details(unit{ element = 'light', attribute = 'wild' },
                      unit{ element = 'dark',  attribute = 'wild' }, 10, 'light', {}))
    check(Dmg.details(unit{ element = 'ember', attribute = 'wild' },
                      unit{ element = 'water', attribute = 'wild' }, 10, 'ember', {}))
    check(Dmg.details(unit{}, unit{}, 10, 'neutral', {}))
end)

-- ==================================================================
-- 4. Stats: дефолты множителей
-- ==================================================================

test('stats: missing spell_power defaults to 1, not 0', function()
    local Stats = require 'src.stats'
    local character = { max_health = 20 }
    local s = Stats(character, {}, {})
    eq(s:get('spell_power'), 1, 'spell_power default')
end)

test('stats: spell_power mul keeps meaning when no base', function()
    local Stats = require 'src.stats'
    local character = { max_health = 20 }
    local mods = { { stat = 'spell_power', op = 'mul', value = 1.25 } }
    local s = Stats(character, mods, {})
    near(s:get('spell_power'), 1.25, 0.0001, '1 * 1.25')
end)

test('stats: spell_power_<elem> defaults to 1', function()
    local Stats = require 'src.stats'
    local s = Stats({ max_health = 20 }, {}, {})
    eq(s:get('spell_power_ember'), 1)
end)

test('stats: resist_<elem> defaults to 0', function()
    local Stats = require 'src.stats'
    local s = Stats({ max_health = 20 }, {}, {})
    eq(s:get('resist_ember'), 0)
end)

test('stats: absolute stats still default to 0', function()
    local Stats = require 'src.stats'
    local s = Stats({ max_health = 20 }, {}, {})
    eq(s:get('armor'), 0)
    eq(s:get('armor_pierce'), 0)
end)

-- ==================================================================
-- Итоги
-- ==================================================================

print('')
if failed == 0 then
    print(('All %d tests passed.'):format(passed))
    os.exit(0)
else
    print(('%d passed, %d FAILED:'):format(passed, failed))
    for _, f in ipairs(failures) do print('  * ' .. f) end
    os.exit(1)
end
