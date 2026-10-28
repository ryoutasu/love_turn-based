-- tests/smoke_story_routing.lua
--
-- End-to-end routing regression for the three playtest-blocking story bugs.
--
--   Bug 1  the story boss was placed on a regular node, while the map's 'end'
--          node (the one that looks like a boss) opened a legacy battle.
--   Bug 2  alt_when_locked is a SCENE id, but resolve_node used it as a graph
--          node id -> nil graph lookup -> boss intro silently skipped.
--   Bug 3  _advance_story fired thread.on_complete on non-terminal branch
--          nodes (`not moved OR terminal`), marking the master defeated at
--          the crossroads, before the boss fight.
--
-- Headless. Run: lua tests/smoke_story_routing.lua

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
    function d:setPixel() end function d:mapPixel() end
    function d:getWidth() return self.w end function d:getHeight() return self.h end
    return d
end

CHARACTERS_SCALE = 0.75
HEX_RADIUS = 40
HEX_HEIGHT = 1
DEBUG = false

love = {
    image = { newImageData = stubImageData, newImage = stubImage },
    graphics = {
        newImage  = stubImage,
        newFont   = function() return { getWidth = function() return 1 end, getHeight = function() return 14 end } end,
        newQuad   = function() return { getViewport = function() return 0, 0, 1, 1 end } end,
        newText   = function() return { setf = function() end } end,
        getWidth  = function() return 1920 end,
        getHeight = function() return 1080 end,
    },
    filesystem = { getInfo = function() return nil end, getDirectoryItems = function() return {} end },
    math = {
        colorFromBytes = function(r, g, b, a)
            return { (r or 0) / 255, (g or 0) / 255, (b or 0) / 255, (a or 255) / 255 }
        end,
        random = function(a, b) if a and b then return a end return 0 end,
        newRandomGenerator = function(seed)
            local state = math.floor(math.abs(seed or 1)) % 2147483647
            if state == 0 then state = 1 end
            for _ = 1, 12 do state = (state * 16807) % 2147483647 end
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

-- State modules are resolved from _G by levelmap2 (main.lua:31-42 shape).
FadeInState  = { __name = 'FadeInState' }
FadeOutState = { __name = 'FadeOutState' }
TownState    = { __name = 'TownState' }
BattleState  = { __name = 'BattleState' }
RestState    = { __name = 'RestState' }
ShopState    = { __name = 'ShopState' }

local gamestateCalls = {}
Gamestate = {
    push = function(state, args) gamestateCalls[#gamestateCalls + 1] = { state = state, args = args } end,
    pop = function() end,
    switch = function() end,
    current = function() return nil end,
}
Tagtext = { add = function() end }

local RunState = require 'src.states.run_state'
_G.RunState = RunState
RunState.active = true
RunState.unlocks = {}
RunState.modifiers = {}
RunState.tickBattleModifiers = function() end

package.loaded['src.save_manager'] = {
    save = function() return true end,
    load = function() return nil end,
    exists = function() return false end,
}

-- eventstate.lua captures EventState's globals at load; install a fake that
-- keeps the real generate_story (which is what these cases exercise).
local EventState = require 'src/states/eventstate'
_G.EventState = EventState

local Levelmap        = require 'src.states.levelmap2'
local SceneRunner     = require 'src.story.scene_runner'
local Scenes          = require 'data.story.scenes'
local PlayerMetaStory = require 'src.player_meta_story'
local MasterGenerator = require 'data.story.generators.master_generator'

local SEED = 4242

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

local function make_player()
    local camp = PlayerMetaStory.create(SEED)
    MasterGenerator.ensure_campaign(camp)
    local p = {
        meta_story       = camp,
        lives            = 3,
        charactersActive = {},
        charactersSpare  = {},
        shards           = {},
        inventory        = {},
        drawLives        = function() end,
    }
    return p
end

local function build_map(player)
    player.meta_story.active_thread = {
        id = 'master_trial', params = {}, started_run = 0,
    }

    RunState:reset(player, SEED)
    RunState.story   = { thread_id = 'master_trial', flags = {}, scene_log = {} }
    RunState.unlocks = {}

    local lm = setmetatable({}, { __index = Levelmap })
    lm.player = player
    lm.nodes  = {}
    lm.pathes = {}
    lm.active = true
    lm.seed   = SEED
    lm.openNeighborNodes = function() end

    math.randomseed(SEED)
    lm:_generateMap()
    lm:_place_story()
    return lm
end

local function find_story(lm, id)
    for _, n in ipairs(lm.nodes) do
        if n.story_id == id then return n end
    end
    return nil
end

local function find_master_boss(lm)
    for _, n in ipairs(lm.nodes) do
        if n.is_master_boss then return n end
    end
    return nil
end

local function pushes_to(state)
    local out = {}
    for _, c in ipairs(gamestateCalls) do
        if c.state == state then out[#out + 1] = c end
    end
    return out
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
-- Bug 1 — the story boss sits on the map's 'end' node
-- ===========================================================================

test('Bug 1: master boss is placed on the original end node', function()
    local player = make_player()
    local lm = build_map(player)

    local boss = find_master_boss(lm)
    assert(boss, 'no master-boss node was placed')

    assert(boss.original_type == 'end',
        ('boss node original type is %q, expected "end" — the end icon would '
         .. 'otherwise open a legacy battle'):format(tostring(boss.original_type)))

    -- Exactly one 'end' exists on a map, so the boss is the only one stamped.
    local ends = 0
    for _, n in ipairs(lm.nodes) do
        if n.original_type == 'end' and n.story_scene then ends = ends + 1 end
    end
    assert(ends == 1, ('expected exactly 1 stamped end node, got %d'):format(ends))

    -- Retyped for routing (Node:getGamestate maps 'end' -> BattleState).
    assert(boss.type == 'event',
        ('boss node type is %q after stamping, expected "event"'):format(tostring(boss.type)))
    assert(boss.is_master_boss == true, 'boss node lost is_master_boss')
end)

-- ===========================================================================
-- Case A — boss entered WITH the key
-- ===========================================================================

test('Case A: boss with key shows the normal intro and starts a battle', function()
    gamestateCalls = {}
    local player = make_player()
    local lm     = build_map(player)
    local boss   = find_master_boss(lm)
    assert(boss, 'no master-boss node')
    local master_name = player.meta_story.masters[player.meta_story.current_master_id].name

    RunState.unlocks['dojo_key'] = true
    lm.currentNode = boss

    local es = setmetatable({}, { __index = EventState })
    EventState:enter(nil, { player = player, node = boss, locked = false })
    -- NOTE: :enter is a method table operation; call it on the instance.
    es = setmetatable({}, { __index = EventState })
    EventState.enter(es, nil, { player = player, node = boss, locked = false })

    assert(es.steps ~= nil, 'EventState.steps is nil — intro was not generated')
    assert(type(es.steps) == 'table' and #es.steps >= 1,
        'EventState.steps has no steps')
    local first = es.steps[1]
    local text = type(first.text) == 'function' and first.text() or first.text
    assert(type(text) == 'string' and text:find(master_name, 1, true) ~= nil,
        ('first step text does not mention the master %q'):format(tostring(master_name)))

    -- The scene that ran is the plain boss scene.
    local log = RunState.story.scene_log
    assert(log[#log] == 'master_boss',
        ('scene_log last entry is %q, expected "master_boss"'):format(tostring(log[#log])))

    -- Advance the step, then close the node: BattleState must be pushed calm.
    assert(first.buttons and first.buttons[1] and first.buttons[1].action,
        'first step has no action button')
    first.buttons[1].action(player)

    Levelmap._handle_story_node_complete(lm, boss)
    local pushes = pushes_to(BattleState)
    assert(#pushes == 1, ('expected 1 BattleState push, got %d'):format(#pushes))
    assert(pushes[1].args.master ~= nil, 'battle push has no master')
    assert(pushes[1].args.enraged == false,
        ('battle push enraged is %s, expected false'):format(tostring(pushes[1].args.enraged)))
end)

-- ===========================================================================
-- Case B — boss entered WITHOUT the key (Bug 2 regression)
-- ===========================================================================

test('Case B: boss without key plays master_boss_angry and enrages the battle', function()
    gamestateCalls = {}
    local player = make_player()
    local lm     = build_map(player)
    local boss   = find_master_boss(lm)
    assert(boss, 'no master-boss node')

    RunState.unlocks['dojo_key'] = nil
    RunState.story.scene_log = {}
    lm.currentNode = boss

    local es = setmetatable({}, { __index = EventState })
    EventState.enter(es, nil, { player = player, node = boss, locked = true })

    -- Before the Bug 2 fix this was nil: resolve_node rewrote node_id to
    -- 'master_boss_angry', story.graph[...] was nil, current() returned nil.
    assert(es.steps ~= nil,
        'EventState.steps is nil — the angry-boss scene was not generated '
        .. '(Bug 2: alt_when_locked treated as a graph node id)')
    assert(type(es.steps) == 'table' and #es.steps >= 1, 'no steps generated')

    local log = RunState.story.scene_log
    assert(log[#log] == 'master_boss_angry',
        ('scene_log last entry is %q, expected "master_boss_angry"')
            :format(tostring(log[#log])))
    assert(Scenes[log[#log]] ~= nil, 'the logged scene id is not registered', 2)

    local first = es.steps[1]
    assert(first.buttons and first.buttons[1] and first.buttons[1].action,
        'angry step has no action button')
    first.buttons[1].action(player)

    -- The angry scene sets boss_enraged.
    assert(RunState.story.flags.boss_enraged == true,
        'master_boss_angry did not set RunState.story.flags.boss_enraged')

    Levelmap._handle_story_node_complete(lm, boss)
    local pushes = pushes_to(BattleState)
    assert(#pushes == 1, ('expected 1 BattleState push, got %d'):format(#pushes))
    assert(pushes[1].args.enraged == true,
        ('battle push enraged is %s, expected true'):format(tostring(pushes[1].args.enraged)))
end)

test('Case B2: graph still stands on the boss node after the angry scene', function()
    -- The alt scene must not rewrite node_id: only the scene shown changes.
    local player = make_player()
    local lm     = build_map(player)
    local boss   = find_master_boss(lm)
    RunState.unlocks['dojo_key'] = nil
    RunState.story.node_id = 'boss'
    lm.currentNode = boss

    EventState.enter(setmetatable({}, { __index = EventState }), nil,
        { player = player, node = boss, locked = true })

    assert(RunState.story.node_id == 'boss',
        ('story.node_id was rewritten to %q — the scene id leaked into the graph')
            :format(tostring(RunState.story.node_id)))
end)

-- ===========================================================================
-- Case C — crossroads close does NOT fire on_complete (Bug 3)
-- ===========================================================================

test('Case C: closing crossroads does not complete the thread', function()
    gamestateCalls = {}
    local player = make_player()
    local lm     = build_map(player)
    local cross  = find_story(lm, 'crossroads')
    assert(cross, 'crossroads node was not placed')

    local master_id = player.meta_story.current_master_id
    local master    = player.meta_story.masters[master_id]

    local calls = 0
    local real_on_victory = MasterGenerator.on_victory
    MasterGenerator.on_victory = function(...)
        calls = calls + 1
        return real_on_victory(...)
    end

    Levelmap._handle_story_node_complete(lm, cross)
    MasterGenerator.on_victory = real_on_victory

    assert(calls == 0,
        ('MasterGenerator.on_victory fired %d time(s) on a branch node — '
         .. 'the master is marked defeated before the boss fight'):format(calls))
    assert(master.defeated == false,
        'master was marked defeated at the crossroads')
    assert(player.meta_story.current_master_id == master_id,
        'current_master_id advanced at the crossroads')
end)

-- ===========================================================================
-- Case D — boss close DOES fire on_complete exactly once
-- ===========================================================================

test('Case D: boss victory completes the thread once', function()
    gamestateCalls = {}
    local player = make_player()
    local lm     = build_map(player)
    local boss   = find_master_boss(lm)
    lm.currentNode = boss

    local master_id = player.meta_story.current_master_id
    local master    = player.meta_story.masters[master_id]

    local calls = 0
    local real_on_victory = MasterGenerator.on_victory
    MasterGenerator.on_victory = function(...)
        calls = calls + 1
        return real_on_victory(...)
    end

    RunState.story.node_id = 'boss'
    Levelmap.resume(lm, BattleState, { result = 'win' })
    MasterGenerator.on_victory = real_on_victory

    assert(calls == 1, ('MasterGenerator.on_victory fired %d time(s), expected 1'):format(calls))
    assert(master.defeated == true, 'winning did not mark the master defeated')
    assert(player.meta_story.current_master_id ~= master_id,
        ('current_master_id did not advance from %q'):format(tostring(master_id)))
    assert(boss.isCompleted == true, 'the boss node was not completed on victory')
end)

-- ===========================================================================
-- Report
-- ===========================================================================

print(('%d assertion group(s) failed'):format(failures))
if failures > 0 then
    print('smoke_story_routing FAILED')
    os.exit(1)
end

print('smoke_story_routing OK')
os.exit(0)
