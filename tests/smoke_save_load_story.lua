-- tests/smoke_save_load_story.lua
--
-- Regression test: Levelmap:serialize / deserialize must preserve story node
-- identity. Before the fix, serialize kept only isOpen/isCompleted/isDiscovered
-- and deserialize never re-ran _place_story, so every story node came back as
-- a generic event node — the master boss battle never triggered and the run
-- soft-locked. Saves happen after every node completion, so that was the
-- common path, not an edge case.
--
-- Headless, no LÖVE runtime. Run: lua tests/smoke_save_load_story.lua

local here = (arg and arg[0] or ''):match('^(.*)[/\\]') or '.'
local root = here .. '/..'
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path

-- ---------------------------------------------------------------------------
-- LÖVE stubs
-- ---------------------------------------------------------------------------

local function stubImage()
    return { getWidth = function() return 1 end, getHeight = function() return 1 end }
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
    return { getWidth = function() return 1 end, getHeight = function() return 14 end }
end

CHARACTERS_SCALE = 0.75
HEX_RADIUS = 40
HEX_HEIGHT = 1
DEBUG = false

love = {
    image = { newImageData = stubImageData, newImage = stubImage },
    graphics = {
        newImage = stubImage,
        newFont  = stubFont,
        newQuad  = function() return { getViewport = function() return 0, 0, 1, 1 end } end,
        newText  = function() return { setf = function() end } end,
        getWidth  = function() return 1920 end,
        getHeight = function() return 1080 end,
    },
    filesystem = {
        getInfo           = function() return nil end,
        getDirectoryItems = function() return {} end,
    },
    math = {
        colorFromBytes = function(r, g, b, a)
            return { (r or 0) / 255, (g or 0) / 255, (b or 0) / 255, (a or 255) / 255 }
        end,
        random = function(a, b)
            if a and b then return a end
            return 0
        end,
        -- RunState:reset builds its RNG from this. Seeded so the same call
        -- sequence yields the same placement on every run.
        newRandomGenerator = function(seed)
            local state = math.floor(math.abs(seed or 1)) % 2147483647
            if state == 0 then state = 1 end
            return {
                random = function(_, a, b)
                    state = (state * 16807) % 2147483647
                    local v = (state - 1) / 2147483646
                    if a and b then return math.floor(a + v * (b - a + 1)) end
                    if a then return math.floor(v * a) + 1 end
                    return v
                end,
            }
        end,
    },
}

Class = dofile(root .. '/lib/class.lua')
require 'src.spellcast.targetFactory'
dofile(root .. '/utils.lua')

-- ---------------------------------------------------------------------------
-- Globals that Levelmap / Node / MapRenderer touch at load time.
-- The state modules are read from _G by levelmap2, so they are set as bare
-- globals exactly like main.lua:31-42 does.
-- ---------------------------------------------------------------------------

FadeInState         = { __name = 'FadeInState' }
FadeOutState        = { __name = 'FadeOutState' }
TownState           = { __name = 'TownState' }
BattleState         = { __name = 'BattleState' }
RestState           = { __name = 'RestState' }
ShopState           = { __name = 'ShopState' }
EventState          = { __name = 'EventState' }

Gamestate = {
    push    = function() end,
    pop     = function() end,
    switch  = function() end,
    current = function() return nil end,
}
Tagtext = { add = function() end }

-- Real RunState: levelmap2 requires it directly, and _place_story needs it.
local RunState = require 'src.states.run_state'
_G.RunState = RunState
RunState.story           = { thread_id = 'master_trial', flags = {} }
RunState.active          = true
RunState.unlocks         = {}
RunState.modifiers       = {}
RunState.tickBattleModifiers = function() end

-- No real save/load: Levelmap:_saveGame must not hit disk.
local saveCalls = 0
package.loaded['src.save_manager'] = {
    save   = function() saveCalls = saveCalls + 1 return true end,
    load   = function() return nil end,
    exists = function() return false end,
}

-- ---------------------------------------------------------------------------
-- Modules
-- ---------------------------------------------------------------------------

local Levelmap        = require 'src.states.levelmap2'
local StoryPlacement  = require 'src.story.story_placement'
local PlayerMetaStory = require 'src.player_meta_story'
local MasterGenerator = require 'data.story.generators.master_generator'

local SEED = 4242

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function make_player()
    local camp = PlayerMetaStory.create(SEED)
    MasterGenerator.ensure_campaign(camp)
    return {
        meta_story       = camp,
        lives            = 3,
        charactersActive = {},
        charactersSpare  = {},
        shards           = {},
        inventory        = {},
        drawLives        = function() end,
    }
end

-- A Levelmap that can run _generateMap / _place_story / serialize for real,
-- without the constructor's MapRenderer.
local function make_levelmap(player)
    local lm = setmetatable({}, { __index = Levelmap })
    lm.player   = player
    lm.nodes    = {}
    lm.pathes   = {}
    lm.active   = true
    lm.seed     = SEED
    return lm
end

-- Build a map the way Levelmap:enter does: deterministic seed, legacy map,
-- then stamp the active story thread onto it.
local function build_story_map(player)
    local camp = player.meta_story

    RunState:reset(player, SEED)
    RunState.story   = { thread_id = 'master_trial', flags = {} }
    RunState.unlocks = {}

    -- Pin master_trial. Without this, ThreadGenerator picks a fresh thread at
    -- random and for this seed chooses bond_arc — one scene, no boss — so the
    -- round-trip would not be exercising the boss node at all.
    camp.active_thread = { id = 'master_trial', params = {}, started_run = 1 }

    local lm = make_levelmap(player)
    math.randomseed(SEED)
    lm:_generateMap()

    local placed = 0
    local real_place = StoryPlacement.place
    StoryPlacement.place = function(...)
        placed = placed + 1
        return real_place(...)
    end
    local ok, err = pcall(lm._place_story, lm)
    StoryPlacement.place = real_place
    if not ok then error('_place_story failed: ' .. tostring(err), 0) end

    assert(placed == 1, 'fixture must run _place_story exactly once')
    return lm
end

local function snapshot(lm)
    local out = {}
    for i, node in ipairs(lm.nodes) do
        out[i] = {
            story_scene     = node.story_scene,
            story_id        = node.story_id,
            is_master_boss  = node.is_master_boss,
            requires        = node.requires,
            alt_when_locked = node.alt_when_locked,
            is_boss         = node.is_boss,
            grants          = node.grants,
            locked_hint     = node.locked_hint,
        }
    end
    return out
end

local function count_story_nodes(lm)
    local n = 0
    for _, node in ipairs(lm.nodes) do
        if node.story_scene then n = n + 1 end
    end
    return n
end

local function count_master_boss(lm)
    local n = 0
    for _, node in ipairs(lm.nodes) do
        if node.is_master_boss then n = n + 1 end
    end
    return n
end

-- Structural comparison for the nested requires/grants tables.
local function same_table(a, b)
    if a == nil and b == nil then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return a == b end
    for k, v in pairs(a) do
        if type(v) == 'table' then
            if not same_table(v, b[k]) then return false end
        elseif b[k] ~= v then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

local failures = 0
local function test(label, fn)
    local ok, err = pcall(fn)
    if ok then
        print('  ok   ' .. label)
    else
        failures = failures + 1
        print('  FAIL ' .. label .. '\n         ' .. tostring(err))
    end
end

-- ===========================================================================
-- T1 — round trip preserves story identity
-- ===========================================================================

test('T1 story node identity survives serialize -> deserialize', function()
    local player = make_player()
    local lm     = build_story_map(player)

    local story_count = count_story_nodes(lm)
    assert(story_count > 0,
        'fixture placed no story nodes — _place_story did not stamp anything')
    assert(count_master_boss(lm) == 1,
        ('fixture must place exactly 1 master-boss node before saving, got %d '
         .. '(boss_angry is an alt_when_locked scene variant, not a node)')
            :format(count_master_boss(lm)))

    local before    = snapshot(lm)
    local saved     = lm:serialize()

    -- Fresh levelmap, same seed, legacy map only — then deserialize.
    local restored = make_levelmap(make_player())
    restored:deserialize(saved)

    assert(#restored.nodes == #lm.nodes,
        ('node count changed: %d -> %d'):format(#lm.nodes, #restored.nodes))

    for i = 1, #lm.nodes do
        local a, node = before[i], restored.nodes[i]
        assert(node.story_scene == a.story_scene,
            ('node %d story_scene: %q -> %q')
                :format(i, tostring(a.story_scene), tostring(node.story_scene)))
        assert(node.story_id == a.story_id,
            ('node %d story_id: %q -> %q')
                :format(i, tostring(a.story_id), tostring(node.story_id)))
        assert(node.is_master_boss == a.is_master_boss,
            ('node %d is_master_boss: %s -> %s')
                :format(i, tostring(a.is_master_boss), tostring(node.is_master_boss)))
        assert(node.alt_when_locked == a.alt_when_locked,
            ('node %d alt_when_locked: %q -> %q')
                :format(i, tostring(a.alt_when_locked), tostring(node.alt_when_locked)))
        assert(same_table(node.requires, a.requires),
            ('node %d requires differ after reload'):format(i))
    end
end)

-- ===========================================================================
-- T2 — the soft-lock regression assertion
-- ===========================================================================

test('T2 the master-boss node survives restore', function()
    local lm = build_story_map(make_player())
    assert(count_master_boss(lm) == 1, 'fixture precondition failed')

    local saved    = lm:serialize()
    local restored = make_levelmap(make_player())
    restored:deserialize(saved)

    -- The assertion that would have caught the original soft-lock: with story
    -- fields lost, the boss came back as a generic event node and no master
    -- battle was ever triggered. A count alone is not enough — the surviving
    -- node must still carry the boss scene id and the run-key gate.
    local bosses = {}
    for _, node in ipairs(restored.nodes) do
        if node.is_master_boss then bosses[#bosses + 1] = node end
    end

    assert(#bosses == 1,
        ('exactly 1 node must have is_master_boss == true after restore, got %d '
         .. '(0 = the original soft-lock: story identity was lost)'):format(#bosses))

    -- boss_angry is a scene variant reached through alt_when_locked, not a
    -- second map node, so only master_boss may carry a boss flag.
    local gated = bosses[1]
    assert(gated.story_scene == 'master_boss',
        ('restored boss node must point at scene master_boss, got %q')
            :format(tostring(gated.story_scene)))
    assert(same_table(gated.requires, { run_key = 'dojo_key' }),
        'restored boss node must keep its run_key gate')
    assert(gated.alt_when_locked == 'master_boss_angry',
        ('restored boss node must keep alt_when_locked, got %q')
            :format(tostring(gated.alt_when_locked)))
end)

-- ===========================================================================
-- T3 — restored story nodes keep the StoryPlacement shape
-- ===========================================================================

test('T3 restored story nodes are event nodes with no random event', function()
    local lm = build_story_map(make_player())
    local restored = make_levelmap(make_player())
    restored:deserialize(lm:serialize())

    local checked = 0
    for i, node in ipairs(restored.nodes) do
        if node.story_scene then
            checked = checked + 1
            assert(node.type == 'event',
                ('node %d (story %q): type must be "event", got %q')
                    :format(i, tostring(node.story_scene), tostring(node.type)))
            assert(node.event == nil,
                ('node %d (story %q): event must be nil, got %s')
                    :format(i, tostring(node.story_scene), tostring(node.event)))
        end
    end

    assert(checked > 0, 'no story nodes were restored — nothing verified')
end)

-- ===========================================================================
-- T4 — deserialize must not re-run placement
-- ===========================================================================

test('T4 _place_story is NOT called during deserialize', function()
    local lm = build_story_map(make_player())
    local saved = lm:serialize()

    local calls = 0
    local real_place = StoryPlacement.place
    local real_place_story = Levelmap._place_story
    StoryPlacement.place = function(...)
        calls = calls + 1
        return real_place(...)
    end
    Levelmap._place_story = function(self, ...)
        calls = calls + 1
        return real_place_story(self, ...)
    end

    local ok, err = pcall(function()
        local restored = make_levelmap(make_player())
        restored:deserialize(saved)
    end)

    StoryPlacement.place = real_place
    Levelmap._place_story = real_place_story
    if not ok then error(err, 0) end

    -- Re-running placement would advance the RNG and can move scenes.
    assert(calls == 0,
        ('deserialize must not re-place the story, placement ran %d time(s)')
            :format(calls))
end)

-- ===========================================================================
-- T5 — old saves without story fields still load
-- ===========================================================================

test('T5 legacy save without story fields loads and leaves nodes untouched', function()
    local lm = make_player() and build_story_map(make_player())

    -- An old-format save: only seed + the three flags.
    local legacy = { seed = lm.seed, nodeStates = {}, pathStates = {} }
    for i, node in ipairs(lm.nodes) do
        legacy.nodeStates[i] = {
            isOpen       = node.isOpen or false,
            isCompleted  = node.isCompleted or false,
            isDiscovered = node.isDiscovered or false,
        }
    end

    local restored = make_levelmap(make_player())
    restored:deserialize(legacy)

    assert(#restored.nodes == #lm.nodes,
        'legacy load changed the node count')

    -- Nothing story-related may be invented for a save that has none.
    assert(count_story_nodes(restored) == 0,
        ('legacy save must not fabricate story nodes, got %d')
            :format(count_story_nodes(restored)))
    assert(count_master_boss(restored) == 0,
        'legacy save must not fabricate a master-boss node')

    -- Nodes keep the legacy generator's shape.
    for i, node in ipairs(restored.nodes) do
        assert(node.story_scene == nil,
            ('node %d gained a story_scene from a legacy save'):format(i))
    end
end)

-- ===========================================================================
-- Report
-- ===========================================================================

print(('%d assertion group(s) failed'):format(failures))
if failures > 0 then
    print('smoke_save_load_story FAILED')
    os.exit(1)
end

print('smoke_save_load_story OK')
os.exit(0)
