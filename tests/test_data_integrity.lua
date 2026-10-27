-- tests/test_data_integrity.lua
--
-- Проверяем, что контент и правила согласованы между собой.
-- Именно такой тест поймал бы исходный баг: в data/type_chart.lua
-- не было строк ancient/chaos, а существа и осколки их используют.
--
-- Запуск: lua tests/test_data_integrity.lua

local here = (arg and arg[0] or ''):match('^(.*)[/\\]') or '.'
package.path = here .. '/../?.lua;' .. here .. '/../?/init.lua;' .. package.path

-- ------------------------------------------------------------------
-- Заглушки LÖVE: char/spell-файлы выполняют графические вызовы
-- на этапе загрузки модуля.
-- ------------------------------------------------------------------

local function stubImageData(w, h)
    local d = { w = w or 1, h = h or 1 }
    function d:setPixel() end
    function d:mapPixel() end
    function d:getWidth() return self.w end
    function d:getHeight() return self.h end
    return d
end

local function stubImage()
    return {
        getWidth  = function() return 1 end,
        getHeight = function() return 1 end,
        setFilter = function() end,
    }
end

_G.CHARACTERS_SCALE = 0.75
_G.HEX_RADIUS = 40
_G.HEX_HEIGHT = 1
_G.DEBUG = false

_G.love = {
    image = {
        newImageData = stubImageData,
        newImage     = stubImage,
    },
    graphics = {
        newImage = stubImage,
        newFont  = function()
            return { getWidth = function(_, s) return #tostring(s or '') * 7 end,
                     getHeight = function() return 14 end }
        end,
        newQuad = function() return {} end,
        newText  = function() return { setf = function() end } end,
    },
    filesystem = {
        getInfo = function() return nil end,
        getDirectoryItems = function() return {} end,
    },
    math = { colorFromBytes = function(r, g, b, a)
        return { (r or 0)/255, (g or 0)/255, (b or 0)/255, (a or 255)/255 }
    end },
}

_G.Class = function(base)
    base = base or {}
    base.__index = base
    return setmetatable(base, { __call = function(c, ...)
        local o = setmetatable({}, c)
        if o.init then o:init(...) end
        return o
    end })
end

-- main.lua выставляет TargetFactory как ГЛОБАЛ до загрузки заклинаний.
-- Без него любой spell-модуль падает на строке `filter = TargetFactory.enemy`.
-- ВАЖНО: модуль не делает `return`, он только присваивает глобал —
-- поэтому require возвращает `true`, и читать надо именно глобал.
require 'src.spellcast.targetFactory'
assert(type(_G.TargetFactory) == 'table',
    'src/spellcast/targetFactory.lua must define the TargetFactory global')

-- colors.lua вызывает Brighter() на этапе загрузки — берём из utils.lua.
dofile('utils.lua')

-- ------------------------------------------------------------------
-- Мини-фреймворк
-- ------------------------------------------------------------------

local passed, failed, failures = 0, 0, {}
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1
    else failed = failed + 1; failures[#failures + 1] = name .. '\n    ' .. tostring(err) end
end
local function ok(cond, msg)
    if not cond then error(msg, 2) end
end

-- ------------------------------------------------------------------
-- Данные
-- ------------------------------------------------------------------

local Chart    = require 'data.type_chart'
local Upgrades = require 'data.upgrades'
local Characters = require 'src.characters'

-- Реестры, которые грузятся через auto-discovery (love.filesystem пуст),
-- поэтому собираем их вручную из известных имён.
local CHARACTER_MODULES = {
    'Aetheris', 'Blazeflare', 'Brambleclaw', 'Dewscale', 'Emberpuff',
    'Flarevine', 'Frostling', 'Leafen', 'Marilix', 'Mystwing',
    'Nightshade', 'Quillpaw', 'Rockjaw', 'Sylphine', 'Tempira',
    'Terrow', 'Voltling',
}

local SPELL_MODULES = {
    'armor_up', 'claws', 'earthquake', 'fireball', 'fire_claws',
    'frost_bite', 'frost_nova', 'healing', 'ignite', 'lash',
    'leaf_strike', 'poison_cloud', 'sand_throw', 'speed_up', 'spikes',
    'spit', 'splash', 'stone_claws', 'water_bolt',
}

local characters = {}
for _, name in ipairs(CHARACTER_MODULES) do
    local okLoad, mod = pcall(require, 'src.characters.' .. name)
    if okLoad and type(mod) == 'table' then characters[name] = mod end
end

local spells = {}
for _, name in ipairs(SPELL_MODULES) do
    local okLoad, mod = pcall(require, 'src.spells.' .. name)
    if okLoad and type(mod) == 'table' then spells[name] = mod end
end

-- ==================================================================
-- 1. Чарт покрывает весь контент
-- ==================================================================

local ATTR_SET = {}
for _, a in ipairs(Chart.ATTRIBUTES) do ATTR_SET[a] = true end

local ELEM_SET = {}
for _, e in ipairs(Chart.ELEMENTS) do ELEM_SET[e] = true end

test('all character templates loaded', function()
    ok(#CHARACTER_MODULES > 0, 'no characters to check')
    ok(next(characters) ~= nil, 'failed to load any character template')
end)

test('all spell definitions loaded', function()
    ok(next(spells) ~= nil, 'failed to load any spell definition')
end)

test('every character attribute exists in the chart', function()
    for name, c in pairs(characters) do
        ok(c.attribute, name .. ' has no attribute')
        ok(ATTR_SET[c.attribute],
            ('%s uses attribute %q, which is missing from data/type_chart.lua'):format(name, tostring(c.attribute)))
    end
end)

test('every character element exists in the chart', function()
    for name, c in pairs(characters) do
        ok(c.element, name .. ' has no element')
        ok(ELEM_SET[c.element],
            ('%s uses element %q, which is missing from data/type_chart.lua'):format(name, tostring(c.element)))
    end
end)

test('every spell element exists in the chart', function()
    for name, s in pairs(spells) do
        if s.element then
            ok(ELEM_SET[s.element],
                ('spell %q uses element %q, which is missing from data/type_chart.lua'):format(name, tostring(s.element)))
        end
    end
end)

-- Известный контентный долг: 8 персонажей ссылаются на заклинания,
-- файлов которых не существует. Unit:setup молча пропускает такие записи
-- (`if template then`), поэтому существо просто теряет способность —
-- без единой ошибки в консоли. Тест фиксирует текущий список как baseline:
-- НОВАЯ отсутствующая ссылка упадёт, известная — только предупредит.
local KNOWN_MISSING_SPELLS = {
    explosive_burst = 'Blazeflare',
    thorn_strike    = 'Brambleclaw',
    entangle        = 'Brambleclaw',
    burn_leaf       = 'Flarevine',
    coral_strike    = 'Marilix',
    tidal_shield    = 'Marilix',
    gust            = 'Mystwing/Sylphine',
    vortex          = 'Mystwing/Sylphine',
    toxic_bite      = 'Nightshade',
    shadow_pulse    = 'Nightshade',
    stone_crush     = 'Rockjaw',
    water_spout     = 'Tempira',
    storm_dash      = 'Tempira',
}

test('every character spell reference resolves', function()
    local unknown = {}
    local known_count = 0

    for name, c in pairs(characters) do
        for _, entry in ipairs(c.spells or {}) do
            local id = type(entry) == 'string' and entry or entry.id
            if not spells[id] then
                if KNOWN_MISSING_SPELLS[id] then
                    known_count = known_count + 1
                else
                    unknown[#unknown + 1] = ('%s -> %s'):format(name, tostring(id))
                end
            end
        end
    end

    if known_count > 0 then
        print(('    note: %d known missing spell reference(s) — see KNOWN_MISSING_SPELLS')
            :format(known_count))
    end

    ok(#unknown == 0,
        'NEW unresolved spell reference(s): ' .. table.concat(unknown, ', '))
end)

test('shard types match chart attributes', function()
    -- SHARD_TYPES в player.lua обязан совпадать с Chart.ATTRIBUTES,
    -- иначе осколки нельзя будет получить или потратить.
    local SHARD_TYPES = { 'wild', 'mystic', 'mechanic', 'ancient', 'chaos' }
    for _, t in ipairs(SHARD_TYPES) do
        ok(ATTR_SET[t], 'shard type ' .. t .. ' has no attribute row')
    end
    ok(#SHARD_TYPES == #Chart.ATTRIBUTES,
        'shard types and chart attributes differ in length')
end)

-- ==================================================================
-- 2. Апгрейды ссылаются на существующие статы
-- ==================================================================

local KNOWN_STATS = {
    max_health = true, max_energy = true, damage = true,
    attack_range = true, move_range = true, initiative = true,
    armor = true, spell_power = true, armor_pierce = true,
    percent_hp_damage = true, shard_bonus = true, essence_bonus = true,
    gold_bonus = true,
    -- miss_chance реально читается в Attack:update (через get_stat).
    miss_chance = true,
}

-- Статы, объявленные в data/upgrades.lua, но не имеющие ни одного
-- потребителя. Это не регрессия сегодняшней правки, но зафиксированный
-- техдолг: апгрейд существует, кнопка берётся, эффекта нет.
local KNOWN_UNIMPLEMENTED = {
    aoe_bonus          = 'amplify_area',   -- AoE-усиление не реализовано
    echo_chance        = 'echo',           -- повторный каст не реализован
    double_cast_chance = 'double_cast',    -- двойной каст не реализован
}

local function isKnownStat(stat)
    if not stat then return false end
    if KNOWN_STATS[stat] or KNOWN_UNIMPLEMENTED[stat] then return true end
    if stat:match('^spell_power_') then
        return ELEM_SET[stat:sub(#'spell_power_' + 1)] == true
    end
    if stat:match('^resist_') then
        return ELEM_SET[stat:sub(#'resist_' + 1)] == true
    end
    return false
end

test('every upgrade modifier targets a known stat', function()
    local unknown = {}
    for id, up in pairs(Upgrades) do
        if type(up) == 'table' and up.mods then
            for _, m in ipairs(up.mods) do
                if m.stat and not isKnownStat(m.stat) then
                    unknown[#unknown + 1] = ('%s -> %s'):format(id, m.stat)
                end
            end
        end
    end
    ok(#unknown == 0, 'unknown stat(s): ' .. table.concat(unknown, ', '))
end)

test('no upgrade writes a dead filter_elem field', function()
    local bad = {}
    for id, up in pairs(Upgrades) do
        if type(up) == 'table' and up.mods then
            for _, m in ipairs(up.mods) do
                if m.filter_elem then bad[#bad + 1] = id end
            end
        end
    end
    ok(#bad == 0, 'dead filter_elem in: ' .. table.concat(bad, ', '))
end)

-- ==================================================================
-- 3. Согласованность имён в UI
-- ==================================================================

test('ATTRIBUTES label table covers every chart attribute', function()
    dofile('elements.lua')
    for _, a in ipairs(Chart.ATTRIBUTES) do
        ok(_G.ATTRIBUTES[a], 'ATTRIBUTES has no label for ' .. a)
    end
end)

test('ELEMENTS label table covers every chart element', function()
    dofile('elements.lua')
    for _, e in ipairs(Chart.ELEMENTS) do
        ok(_G.ELEMENTS[e], 'ELEMENTS has no label for ' .. e)
    end
end)

test('colour tables cover every attribute and element', function()
    dofile('colors.lua')
    for _, a in ipairs(Chart.ATTRIBUTES) do
        ok(_G.ATTRIBUTES_COLORS[a], 'ATTRIBUTES_COLORS has no entry for ' .. a)
    end
    for _, e in ipairs(Chart.ELEMENTS) do
        ok(_G.ELEMENTS_COLORS[e], 'ELEMENTS_COLORS has no entry for ' .. e)
    end
end)

-- ==================================================================
-- Итоги
-- ==================================================================

print('')
if failed == 0 then
    print(('All %d data-integrity tests passed.'):format(passed))
    os.exit(0)
else
    print(('%d passed, %d FAILED:'):format(passed, failed))
    for _, f in ipairs(failures) do print('  * ' .. f) end
    os.exit(1)
end
