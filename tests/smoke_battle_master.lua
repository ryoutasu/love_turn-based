-- tests/smoke_battle_master.lua
--
-- Smoke test for master-party support in BattleState (Task A).
--
--   * BattleState:enter({ master = m }) builds one enemy Unit per
--     m.battle_party descriptor, in order, with matching attribute/element.
--   * BattleState:enter({ master = nil }) keeps the legacy random generator.
--   * `enraged` is stored, and does not change party size yet (Task B).
--
-- Headless: no LÖVE runtime needed.
-- Run: lua tests/smoke_battle_master.lua

local here = (arg and arg[0] or ''):match('^(.*)[/\\]') or '.'
local root = here .. '/..'
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path

-- ---------------------------------------------------------------------------
-- LÖVE stubs
-- ---------------------------------------------------------------------------

-- src/characters/init.lua enumerates the real files via
-- love.filesystem.getDirectoryItems, exactly like LÖVE does. Listing through
-- the shell keeps this test honest about the real bestiary. Only used when the
-- directory exists; otherwise the test says so instead of silently passing.
local function list_dir(path)
    local items = {}
    local is_windows = package.config:sub(1, 1) == '\\'
    local cmd = is_windows
        and ('dir /b "' .. path:gsub('/', '\\') .. '" 2>NUL')
        or ('ls "' .. path .. '" 2>/dev/null')
    local pipe = io.popen(cmd)
    if not pipe then return items end
    for line in pipe:lines() do
        if line ~= '' then items[#items + 1] = line end
    end
    pipe:close()
    return items
end

local function stubImage()
    return {
        getWidth  = function() return 1 end,
        getHeight = function() return 1 end,
    }
end

local function stubImageData(w, h)
    local d = { w = w or 1, h = h or 1 }
    function d:setPixel() end
    function d:mapPixel() end
    function d:getWidth() return self.w end
    function d:getHeight() return self.h end
    return d
end

local function stubFont()
    return {
        getWidth  = function(_, s) return #tostring(s or '') * 7 end,
        getHeight = function() return 14 end,
    }
end

local function stubRandomGenerator()
    -- Deterministic, and compatible with both random() and random(a, b).
    return { random = function(_, a, b)
        if a and b then return a end
        return 0
    end }
end

CHARACTERS_SCALE = 0.75
HEX_RADIUS = 40
HEX_HEIGHT = 1
DEBUG = false

love = {
    image = { newImageData = stubImageData, newImage = stubImage },
    graphics = {
        newImage  = stubImage,
        newFont   = stubFont,
        newQuad   = function() return { getViewport = function() return 0, 0, 1, 1 end } end,
        newText   = function() return { setf = function() end } end,
        newCanvas = stubImage,
        newShader = function() return { send = function() end } end,
        getCanvas = function() return nil end,
        setCanvas = function() end,
        getShader = function() return nil end,
        setShader = function() end,
        getColor  = function() return 1, 1, 1, 1 end,
        clear     = function() end,
        getWidth  = function() return 1280 end,
        getHeight = function() return 720 end,
    },
    filesystem = {
        getInfo = function() return nil end,
        getDirectoryItems = function(dir)
            if dir == 'src/characters' or dir == 'src/characters/' then
                return list_dir(root .. '/src/characters')
            end
            return {}
        end,
    },
    window = {
        getMode = function() return 1280, 720, {} end,
        isOpen  = function() return true end,
        setMode = function() end,
    },
    timer = {
        getDelta = function() return 0.016 end,
        getTime  = function() return 0 end,
    },
    mouse = { getPosition = function() return 0, 0 end },
    math = {
        colorFromBytes = function(r, g, b, a)
            return { (r or 0) / 255, (g or 0) / 255, (b or 0) / 255, (a or 255) / 255 }
        end,
        random = function(a, b)
            if a and b then return a end
            return 0
        end,
        newRandomGenerator = stubRandomGenerator,
    },
}

Class  = dofile(root .. '/lib/class.lua')
Vector = require 'lib.vector'
dofile(root .. '/utils.lua')
dofile(root .. '/colors.lua')
require 'src.spellcast.targetFactory'

-- Globals the battle code expects from main.lua.
Tagtext     = { add = function() end }
FieldMusic  = { stop = function() end }
BattleMusic = { play = function() end, stop = function() end }
PlaySound   = function() end

local RunState = require 'src.states.run_state'
RunState.fireHook     = function() end
RunState.getModifiers = function() return {} end
RunState.hasUnlock    = function() return false end

-- ---------------------------------------------------------------------------
-- Modules under test
-- ---------------------------------------------------------------------------

BattleState     = require 'src.states.battlestate'
local Character       = require 'src.character'
local Characters      = require 'src.characters'
local PlayerMetaStory = require 'src.player_meta_story'
local MasterGenerator = require 'data.story.generators.master_generator'

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function make_player()
    local p = {
        charactersActiveSize = 0,
        charactersActive     = {},
        charactersSpareSize  = 0,
        charactersSpare      = {},
        inventory            = {},
    }
    p.addCurrency   = function() end
    p.addShard      = function() end
    p.addEssence    = function() end
    p.addExperience = function() end
    return p
end

local function build_battle(args)
    local battle = setmetatable({}, { __index = BattleState })
    BattleState.init(battle)
    BattleState.enter(battle, nil, args)
    return battle
end

local function enemy_units(battle)
    local list = {}
    for _, unit in ipairs(battle.units) do
        if not unit.is_player then
            list[#list + 1] = unit
        end
    end
    return list
end

local function player_units(battle)
    local list = {}
    for _, unit in ipairs(battle.units) do
        if unit.is_player then
            list[#list + 1] = unit
        end
    end
    return list
end

local FLOAT_TOLERANCE = 1e-6

local function near(a, b, tolerance)
    return math.abs(a - b) <= (tolerance or FLOAT_TOLERANCE)
end

-- Asserts that `enraged` equals `normal` with `factor` applied, reporting the
-- effective Stats values on failure. When `normal` is 0 — a fallback creature
-- built without base stats — the check stays a real assertion: Stats:_compute
-- evaluates `(0 + 0) * mul`, which is 0 in Lua. That case is printed so the
-- content gap stays visible instead of being silently skipped.
local function assert_scaled(label, normal, enraged, factor)
    local expected = normal * factor
    if normal ~= 0 then
        assert(near(enraged, expected),
            ('%s: expected %f (%f x %g), got %f')
                :format(label, expected, normal, factor, enraged))
        return
    end
    assert(enraged == 0,
        ('%s: baseline is 0 but enraged value is %f'):format(label, enraged))
    print(('  note %s: no base stat, enraged value is also 0'):format(label))
end

local function current_master(seed)
    local camp = PlayerMetaStory.create(seed)
    MasterGenerator.ensure_campaign(camp)
    return MasterGenerator.current(camp), camp
end

-- ---------------------------------------------------------------------------
-- Test 1: master party drives the enemy roster
-- ---------------------------------------------------------------------------

local function test_master_party()
    -- Seeds 1, 2, 4 give wild / mystic / mechanic respectively (see
    -- master_generator): one resolving through the bestiary and the attribute
    -- pool, one resolving entirely through the fallback.
    for _, seed in ipairs({ 1, 2, 4 }) do
        local m = current_master(seed)
        assert(type(m) == 'table', 'master missing for seed ' .. seed)
        assert(type(m.battle_party) == 'table' and #m.battle_party > 0,
            'master has no battle party (seed ' .. seed .. ')')

        local battle = build_battle({
            player  = make_player(),
            node    = { enemies_count = 2, level = 1, type = 'trainer' },
            master  = m,
            enraged = false,
        })

        local enemies = enemy_units(battle)
        assert(#enemies == #m.battle_party,
            ('expected %d enemies for %s master, got %d')
                :format(#m.battle_party, m.attribute, #enemies))

        for i, desc in ipairs(m.battle_party) do
            local unit = enemies[i]
            assert(unit, 'missing unit at index ' .. i)
            assert(unit.character.attribute == desc.attribute,
                ('unit %d attribute: expected %q, got %q')
                    :format(i, tostring(desc.attribute), tostring(unit.character.attribute)))
            assert(unit.character.element == desc.element,
                ('unit %d element: expected %q, got %q')
                    :format(i, tostring(desc.element), tostring(unit.character.element)))
            -- The unit caches these at setup time; they must agree too.
            assert(unit.attribute == desc.attribute, 'unit.attribute mismatch at ' .. i)
            assert(unit.element == desc.element, 'unit.element mismatch at ' .. i)
            assert(unit.character.level == desc.level,
                ('unit %d level: expected %d, got %s')
                    :format(i, desc.level, tostring(unit.character.level)))
            assert(unit.is_player == false, 'enemy unit flagged as player at ' .. i)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Test 2: legacy path untouched when master is nil
-- ---------------------------------------------------------------------------

local function test_legacy_path()
    local bestiary_count = 0
    for _ in pairs(Characters) do bestiary_count = bestiary_count + 1 end
    assert(bestiary_count > 0,
        'bestiary is empty — love.filesystem stub did not see src/characters/')

    local battle = build_battle({
        player = make_player(),
        node   = { enemies_count = 2, level = 1, type = 'wild' },
        master = nil,
    })

    local enemies = enemy_units(battle)
    assert(#enemies > 0, 'legacy path produced no enemies')
    assert(#enemies == 2,
        'legacy path should honour node.enemies_count = 2, got ' .. #enemies)
    assert(battle.master == nil, 'master should stay nil on the legacy path')
    assert(battle.enraged == false, 'enraged should default to false')

    for i, unit in ipairs(enemies) do
        assert(Characters[unit.character.name],
            ('legacy enemy %d (%q) is not a bestiary creature')
                :format(i, tostring(unit.character.name)))
    end
end

-- ---------------------------------------------------------------------------
-- Test 3: enraged is stored, party size unchanged
-- ---------------------------------------------------------------------------

local function test_enraged()
    local m = current_master(1)

    local calm = build_battle({
        player  = make_player(),
        node    = { enemies_count = 2 },
        master  = m,
        enraged = false,
    })
    local angry = build_battle({
        player  = make_player(),
        node    = { enemies_count = 2 },
        master  = m,
        enraged = true,
    })

    assert(angry.enraged == true, 'enraged flag was not stored')
    assert(calm.enraged == false, 'enraged should be false when omitted')
    assert(#enemy_units(angry) == #m.battle_party,
        'enraged changed the party size')
    assert(#enemy_units(angry) == #enemy_units(calm),
        'enraged changed the enemy count versus the calm battle')
end

-- ---------------------------------------------------------------------------
-- Test 4: enraged multiplies enemy damage and max_health through Stats
-- ---------------------------------------------------------------------------

local function test_enraged_enemy_stats()
    -- Seeds 1 (wild) and 4 (mechanic) resolve to the same templates in the calm
    -- and the enraged battle, so any stat difference comes from the modifiers.
    for _, seed in ipairs({ 1, 4 }) do
        local m = current_master(seed)
        local node = { enemies_count = 2, level = 1 }

        local calm  = build_battle({ player = make_player(), node = node,
                                     master = m, enraged = false })
        local angry = build_battle({ player = make_player(), node = node,
                                     master = m, enraged = true })

        local calm_enemies  = enemy_units(calm)
        local angry_enemies = enemy_units(angry)
        assert(#angry_enemies == #calm_enemies, 'enraged changed the enemy count')

        for i = 1, #calm_enemies do
            local normal  = calm_enemies[i]
            local enraged = angry_enemies[i]

            -- Effective values come from Stats, not from the modifier table:
            -- that is what proves the modifiers went through aggregation.
            local dmg_normal  = normal.stats:get('damage')
            local hp_normal   = normal.stats:get('max_health')
            local dmg_enraged = enraged.stats:get('damage')
            local hp_enraged  = enraged.stats:get('max_health')

            assert_scaled(('seed %d unit %d damage'):format(seed, i),
                dmg_normal, dmg_enraged, 1.15)
            assert_scaled(('seed %d unit %d max_health'):format(seed, i),
                hp_normal, hp_enraged, 1.10)

            -- Current health was restored to the new max for enraged units.
            assert(near(enraged.health, enraged.stats:get('max_health')),
                ('seed %d unit %d health: expected %f (current max), got %f')
                    :format(seed, i, enraged.stats:get('max_health'), enraged.health))

            -- Both modifiers are battle-scope, from master_enraged.
            local battle_mods = 0
            for _, mod in ipairs(enraged.modifiers) do
                if mod.source == 'master_enraged' then
                    assert(mod.scope == 'battle',
                        ('seed %d unit %d: modifier %q has scope %q, expected battle')
                            :format(seed, i, tostring(mod.id), tostring(mod.scope)))
                    battle_mods = battle_mods + 1
                end
            end
            assert(battle_mods == 2,
                ('seed %d unit %d: expected 2 master_enraged modifiers, got %d')
                    :format(seed, i, battle_mods))
        end

        -- Calm battle: no master_enraged modifier anywhere.
        for i, unit in ipairs(calm_enemies) do
            for _, mod in ipairs(unit.modifiers) do
                assert(mod.source ~= 'master_enraged',
                    ('seed %d calm unit %d: unexpected enraged modifier'):format(seed, i))
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Test 5: enraged does not leak into the player's units
-- ---------------------------------------------------------------------------

local function test_enraged_player_untouched()
    local m = current_master(1)
    local node = { enemies_count = 2, level = 1 }

    -- Give the player a real unit on both sides, so there is something to
    -- leak into and the comparison is not vacuous.
    local function seeded_player()
        local p = make_player()
        p.charactersActive[1] = Character.new(Characters.Emberpuff)
        p.charactersActiveSize = 1
        return p
    end

    local calm  = build_battle({ player = seeded_player(), node = node,
                                 master = m, enraged = false })
    local angry = build_battle({ player = seeded_player(), node = node,
                                 master = m, enraged = true })

    local calm_players  = player_units(calm)
    local angry_players = player_units(angry)

    assert(#calm_players > 0, 'player has no units — leakage test is vacuous')
    assert(#calm_players == #angry_players, 'player unit count changed')

    for i = 1, #calm_players do
        local normal  = calm_players[i]
        local enraged = angry_players[i]

        assert(near(enraged.stats:get('damage'), normal.stats:get('damage')),
            ('player unit %d damage changed: %f -> %f')
                :format(i, normal.stats:get('damage'), enraged.stats:get('damage')))
        assert(near(enraged.stats:get('max_health'), normal.stats:get('max_health')),
            ('player unit %d max_health changed: %f -> %f')
                :format(i, normal.stats:get('max_health'), enraged.stats:get('max_health')))
        assert(near(enraged.health, normal.health),
            ('player unit %d current health changed: %f -> %f')
                :format(i, normal.health, enraged.health))

        for _, mod in ipairs(enraged.modifiers) do
            assert(mod.source ~= 'master_enraged',
                ('player unit %d received an enraged modifier'):format(i))
        end
    end

    -- Sanity: enemies in that same battle did get the modifiers, so the
    -- player comparison above is not trivially passing.
    local angry_enemies = enemy_units(angry)
    local calm_enemies  = enemy_units(calm)
    assert(near(angry_enemies[1].stats:get('damage'),
                calm_enemies[1].stats:get('damage') * 1.15),
        'enemies in the leakage battle were not enraged — test is vacuous')
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------

local tests = {
    { 'master party from descriptors', test_master_party },
    { 'legacy path with master = nil',  test_legacy_path },
    { 'enraged stored, party unchanged', test_enraged },
    { 'enraged scales enemy stats via Stats', test_enraged_enemy_stats },
    { 'enraged leaves player units alone',    test_enraged_player_untouched },
}

local failed = 0
for _, t in ipairs(tests) do
    local name, fn = t[1], t[2]
    local ok, err = pcall(fn)
    if ok then
        print('  ok   ' .. name)
    else
        failed = failed + 1
        print('  FAIL ' .. name .. '\n       ' .. tostring(err))
    end
end

if failed > 0 then
    print(('%d smoke case(s) FAILED'):format(failed))
    os.exit(1)
end

print('smoke_battle_master OK')
os.exit(0)
