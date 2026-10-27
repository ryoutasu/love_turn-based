-- tests/smoke_master_boss.lua
--
-- Integration smoke test for the master-boss pipeline:
--   EventState close -> Levelmap:_handle_story_node_complete -> BattleState
--   BattleState win  -> Levelmap:resume(_, { result = 'win' })  -> on_victory
--   BattleState lose -> Levelmap:resume(_, { result = 'lose' }) -> on_defeat
--
-- Levelmap:resume dispatches on _G.BattleState / _G.EventState /
-- _G.RestState / _G.ShopState / _G.FadeInState / _G.FadeOutState.
-- main.lua establishes these via bare global assignments at
-- lines 31,32,37,39,40,41,42. This test mirrors that exactly
-- with bare assignments below. Do not replace these with
-- package.loaded stubs: those only affect `require`, which
-- levelmap2 does not call for these modules.
--
-- Headless, no LÖVE runtime. Run: lua tests/smoke_master_boss.lua

local here = (arg and arg[0] or ''):match('^(.*)[/\\]') or '.'
local root = here .. '/..'
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path

-- ---------------------------------------------------------------------------
-- LÖVE stubs (module load only — nothing here opens a window)
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
    },
}

Class = dofile(root .. '/lib/class.lua')
require 'src.spellcast.targetFactory'
dofile(root .. '/utils.lua')

-- ---------------------------------------------------------------------------
-- Fake states, installed BEFORE Levelmap loads.
--
-- Two different binding mechanisms, mirroring production:
--
--   1. State modules are GLOBALS. levelmap2.lua never requires them; it reads
--      BattleState / EventState / ... out of _ENV, exactly as main.lua:31-42
--      populates them. Only bare assignments reach that lookup path.
--   2. UpgradeSelectScreen is an upvalue: levelmap2.lua binds it at its own
--      load time via `require 'src.upgrade_select_screen'`, so it is stubbed
--      through package.loaded (below), not through a global.
-- ---------------------------------------------------------------------------

local Fakes = {}
Fakes.FadeInState         = { __name = 'FadeInState' }
Fakes.FadeOutState        = { __name = 'FadeOutState' }
Fakes.TownState           = { __name = 'TownState' }
Fakes.BattleState         = { __name = 'BattleState' }
Fakes.RestState           = { __name = 'RestState' }
Fakes.ShopState           = { __name = 'ShopState' }
Fakes.EventState          = { __name = 'EventState' }
Fakes.UpgradeSelectScreen = {
    __name   = 'UpgradeSelectScreen',
    isActive = function() return false end,
    open     = function() end,
    draw     = function() end,
}

-- Bare assignments, same shape as main.lua:31,32,37,39,40,41,42.
FadeInState  = Fakes.FadeInState
FadeOutState = Fakes.FadeOutState
TownState    = Fakes.TownState
BattleState  = Fakes.BattleState
RestState    = Fakes.RestState
ShopState    = Fakes.ShopState
EventState   = Fakes.EventState

-- The one state module levelmap2 captures as an upvalue.
package.loaded['src.upgrade_select_screen'] = Fakes.UpgradeSelectScreen

-- ---------------------------------------------------------------------------
-- Globals Levelmap / Node touch. Recorded so tests can inspect calls.
-- ---------------------------------------------------------------------------

local gamestateCalls = {}
local tagtextCalls   = {}

local function record(kind)
    return function(a, b)
        gamestateCalls[#gamestateCalls + 1] = { kind = kind, state = a, args = b }
    end
end

Gamestate = {
    push    = record('push'),
    pop     = record('pop'),
    switch  = record('switch'),
    current = function() return nil end,
}

Tagtext = { add = function(...) tagtextCalls[#tagtextCalls + 1] = { ... } end }

-- Real RunState: it is required (not read as a global) by levelmap2, and its
-- API is exactly what Node/Levelmap call.
local RunState = require 'src.states.run_state'
_G.RunState = RunState
RunState.story  = { thread_id = 'master_trial', flags = {} }
RunState.active = true
RunState.unlocks = {}
RunState.tickBattleModifiers = function() end

-- No real save/load: Levelmap:_saveGame calls SaveManager.save on every
-- resume(). Swapped before Levelmap loads it.
local saveCalls = 0
package.loaded['src.save_manager'] = {
    save   = function() saveCalls = saveCalls + 1 return true end,
    load   = function() return nil end,
    exists = function() return false end,
}

-- ---------------------------------------------------------------------------
-- Modules under test
-- ---------------------------------------------------------------------------

-- src.states.levelmap2 pulls in the REAL src.player, which re-enters
-- battlestate/eventstate through src/actions and src/ai. Under a 5.1-style
-- runtime those nested chunks resolve the bare state names in their OWN
-- environment, never in _G, so the globals above stay pinned to the fakes.
-- Re-assert them after every load boundary anyway: cheap, and it keeps the
-- mirror honest if the module graph ever changes.
local function assert_fakes_installed()
    FadeInState  = Fakes.FadeInState
    FadeOutState = Fakes.FadeOutState
    TownState    = Fakes.TownState
    BattleState  = Fakes.BattleState
    RestState    = Fakes.RestState
    ShopState    = Fakes.ShopState
    EventState   = Fakes.EventState
end

local Levelmap = require 'src.states.levelmap2'
assert_fakes_installed()

-- Node snapshots BattleState/EventState into node_gamestates at load time, so
-- it must be loaded AFTER the globals exist.
package.loaded['src.node'] = nil
local Node = require 'src.node'
assert_fakes_installed()

local PlayerMetaStory = require 'src.player_meta_story'
local MasterGenerator = require 'data.story.generators.master_generator'
local Threads         = require 'data.story.threads'

local SEED = 4242

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function fresh_campaign()
    local camp = PlayerMetaStory.create(SEED)
    MasterGenerator.ensure_campaign(camp)
    return camp
end

local function make_player(camp)
    return {
        meta_story       = camp or fresh_campaign(),
        lives            = 3,
        charactersActive = {},
        charactersSpare  = {},
        shards           = {},
        inventory        = {},
        drawLives        = function() end,
    }
end

-- Raw Levelmap table. `init` builds a MapRenderer and touches love.graphics,
-- which this suite does not provide; only the fields resume() reads are set.
-- resume() -> openNeighborNodes() is stubbed because it needs a generated map
-- graph, and the sibling nodes it would reveal are not part of this contract.
local function make_levelmap(player)
    local lm = setmetatable({}, { __index = Levelmap })
    lm.player   = player
    lm.nodes    = {}
    lm.pathes   = {}
    lm.active   = true
    lm.seed     = SEED
    lm.openNeighborNodes = function() end
    return lm
end

local function reset_calls()
    gamestateCalls = {}
    tagtextCalls   = {}
end

local function calls(kind)
    local out = {}
    for _, call in ipairs(gamestateCalls) do
        if call.kind == kind then out[#out + 1] = call end
    end
    return out
end

local function calls_with_state(state)
    local out = {}
    for _, call in ipairs(gamestateCalls) do
        if call.state == state then out[#out + 1] = call end
    end
    return out
end

-- A real Node (Class instance) so isLocked / resolve_scene_id / getGamestate are
-- the production methods. `enemies_count` is only rolled for wild/trainer, so
-- 'event' avoids math.random entirely.
local function make_node(extra)
    local node = Node(1, 0, 0, true, 'event')
    node.x = 0
    node.y = 0
    node.event = {}
    for k, v in pairs(extra or {}) do node[k] = v end
    return node
end

-- Mirrors what story_placement.stamp() produces for the boss node:
-- story_id, story_scene, requires, alt_when_locked, is_boss, is_master_boss.
local function master_boss_node(extra)
    local fields = {
        is_master_boss  = true,
        is_boss         = true,
        story_scene     = 'master_boss',
        story_id        = 'boss',
        requires        = { run_key = 'dojo_key' },
        alt_when_locked = 'boss_angry',
    }
    for k, v in pairs(extra or {}) do fields[k] = v end
    return make_node(fields)
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

-- Every handler this suite depends on must exist. No silent skips: a missing
-- handler is a hard failure that names it.
local function require_handlers()
    for _, name in ipairs({
        '_handle_story_node_complete',
        '_handle_master_victory',
        '_handle_master_defeat',
        '_handle_run_failed',
    }) do
        assert(type(Levelmap[name]) == 'function',
            ('Levelmap:%s is missing from src/states/levelmap2.lua'):format(name))
    end
end

-- Shared fixture: fresh campaign, player, levelmap and a master-boss node that
-- is being closed out of EventState. Run key held, not enraged.
local function boss_setup()
    RunState.story   = { thread_id = 'master_trial', flags = {} }
    RunState.unlocks = { dojo_key = true }

    local camp   = fresh_campaign()
    local player = make_player(camp)
    player.lives = 3
    local lm     = make_levelmap(player)
    local node   = master_boss_node()
    lm.currentNode = node

    return lm, node, player, camp
end

-- ===========================================================================
-- T1 — master-boss node: EventState close -> BattleState, then resolution
-- ===========================================================================

test('T1a closing a master-boss story node pushes BattleState', function()
    require_handlers()
    reset_calls()
    local lm, node, player, camp = boss_setup()
    local master_id = camp.current_master_id

    Levelmap._handle_story_node_complete(lm, node)

    local pushes = calls('push')
    assert(#pushes == 1,
        ('expected exactly 1 Gamestate.push, got %d'):format(#pushes))

    local push = pushes[1]
    assert(push.state == Fakes.BattleState,
        'push target must be BattleState')

    local args = push.args
    assert(type(args) == 'table', 'push args must be a table')
    assert(args.master ~= nil, 'args.master must not be nil')
    assert(args.master.id == master_id,
        ('args.master.id: expected %q, got %q')
            :format(tostring(master_id), tostring(args.master.id)))
    assert(args.node == node, 'args.node must be the same node')
    assert(args.player == player, 'args.player must be the same player')
    assert(args.enraged == false, 'args.enraged must be false without boss_enraged')

    assert(not node.isCompleted,
        'boss node must stay open until the battle resolves')
    assert(lm.active == false, 'levelmap must be inactive while the battle runs')
end)

test('T1d master victory advances progression', function()
    require_handlers()
    reset_calls()
    local lm, node, player, camp = boss_setup()
    local master_id = camp.current_master_id
    local master    = camp.masters[master_id]

    Levelmap._handle_story_node_complete(lm, node)

    -- Spy _advance_story: closing the scene must not advance the thread yet.
    local advanceCalls = 0
    local advanceNodes = {}
    local realAdvance  = Levelmap._advance_story
    Levelmap._advance_story = function(self, n)
        advanceCalls = advanceCalls + 1
        advanceNodes[#advanceNodes + 1] = n
        return realAdvance(self, n)
    end

    local ok, err = pcall(function()
        assert(advanceCalls == 0,
            ('_advance_story ran %d time(s) before the battle resolved'):format(advanceCalls))

        Levelmap.resume(lm, Fakes.BattleState, { result = 'win' })

        assert(advanceCalls == 1,
            ('_advance_story: expected exactly 1 call, got %d'):format(advanceCalls))
        assert(advanceNodes[1] == node, '_advance_story must receive the boss node')
    end)
    Levelmap._advance_story = realAdvance
    if not ok then error(err, 0) end

    assert(master.defeated == true,
        'winning must mark the master defeated')
    assert(camp.current_master_id ~= master_id,
        ('master must advance: still %q'):format(tostring(camp.current_master_id)))
    assert(node.isCompleted == true, 'winning must close the boss node')
    assert(lm.currentNode == nil, 'currentNode must be cleared after victory')
end)

test('T1e master defeat spends lives, keeps the master and the thread', function()
    require_handlers()
    reset_calls()
    local lm, node, player, camp = boss_setup()
    camp.active_thread = { id = 'master_trial', params = {}, started_run = 1 }
    local master_id = camp.current_master_id
    local master    = camp.masters[master_id]

    Levelmap._handle_story_node_complete(lm, node)
    Levelmap.resume(lm, Fakes.BattleState, { result = 'lose' })

    assert(player.lives == 0,
        ('lives: expected 0, got %s'):format(tostring(player.lives)))
    assert(master.defeats == 1,
        ('defeats: expected 1, got %s'):format(tostring(master.defeats)))
    assert(master.defeated == false, 'a loss must not mark the master defeated')
    assert(camp.current_master_id == master_id, 'a loss must not advance the master')
    assert(camp.active_thread and camp.active_thread.id == 'master_trial',
        'a loss must keep the active thread')
    assert(#calls('pop') == 1,
        ('expected 1 Gamestate.pop, got %d'):format(#calls('pop')))
    assert(lm.currentNode == nil, 'currentNode must be cleared after defeat')
end)

-- ===========================================================================
-- T4b — canary: a non-master battle win must reach the legacy dispatch
-- ===========================================================================

test('T4b non-master battle win routes through UpgradeSelectScreen', function()
    require_handlers()
    reset_calls()
    RunState.story = { thread_id = 'master_trial', flags = {} }
    local camp   = fresh_campaign()
    local lm     = make_levelmap(make_player(camp))
    local node   = make_node({})          -- no is_master_boss, no story_scene
    lm.currentNode = node

    -- Canary for the silent-fallthrough class of bug: if resume() misses the
    -- BattleState branch (e.g. the global is no longer the fake), it lands in
    -- `else`, clears currentNode and never touches this stub — and the
    -- assertion below fails loudly instead of passing on the epilogue alone.
    local opened = 0
    local realOpen = Fakes.UpgradeSelectScreen.open
    Fakes.UpgradeSelectScreen.open = function() opened = opened + 1 end

    local advanceCalls = 0
    local realAdvance  = Levelmap._advance_story
    Levelmap._advance_story = function(self, n)
        advanceCalls = advanceCalls + 1
        return realAdvance(self, n)
    end

    local ok, err = pcall(function()
        Levelmap.resume(lm, Fakes.BattleState, { result = 'win' })
    end)

    Fakes.UpgradeSelectScreen.open = realOpen
    Levelmap._advance_story = realAdvance
    if not ok then error(err, 0) end

    assert(opened == 1,
        ('UpgradeSelectScreen:open expected once, got %d — resume did not '
         .. 'take the BattleState branch'):format(opened))
    assert(advanceCalls == 0,
        ('_advance_story must not run for a non-story battle, ran %d time(s)')
            :format(advanceCalls))
    assert(node.isCompleted == true, 'a normal battle win closes the node')
    assert(lm.currentNode == nil, 'currentNode cleared by the shared epilogue')
end)

-- ===========================================================================
-- Story-node routing and gates
-- ===========================================================================

test('T1b non-master story node completes without a battle', function()
    require_handlers()
    reset_calls()
    local camp = fresh_campaign()
    local lm   = make_levelmap(make_player(camp))
    local node = make_node({ story_scene = 'master_crossroads', story_id = 'crossroads' })
    lm.currentNode = node

    Levelmap.resume(lm, Fakes.EventState, { complete = true })

    assert(node.isCompleted == true, 'story node should be completed on close')
    assert(#calls_with_state(Fakes.BattleState) == 0,
        'closing a non-boss story node must not push BattleState')
    assert(lm.currentNode == nil, 'currentNode cleared by the shared epilogue')
end)

test('T1c story boss node routes to EventState, then dispatches the battle', function()
    require_handlers()
    reset_calls()
    -- Mirrors what story_placement.stamp() produces: type stays 'event', so the
    -- scene plays first; is_master_boss is what triggers the battle afterwards.
    local node = master_boss_node()
    local gs = node:getGamestate()
    assert(gs == Fakes.EventState,
        ('story boss node must play its scene first, got %s')
            :format(tostring(gs and gs.__name or gs)))
    assert(node.is_master_boss == true, 'is_master_boss must survive on the node')

    local lm, _, _, camp = boss_setup()
    lm.currentNode = node
    Levelmap.resume(lm, Fakes.EventState, { complete = true })

    local pushes = calls('push')
    assert(#pushes == 1 and pushes[1].state == Fakes.BattleState,
        'closing a master-boss story node must hand off to BattleState')
    assert(not node.isCompleted, 'boss node stays open across the battle')
end)

test('T2 master defeat via thread keeps memory and thread', function()
    require_handlers()
    reset_calls()
    local camp = fresh_campaign()
    camp.active_thread = { id = 'master_trial', params = {}, started_run = 1 }
    local master_id = camp.current_master_id
    local master    = camp.masters[master_id]

    local thread = Threads.master_trial
    assert(thread and thread.on_fail, 'master_trial must expose on_fail')
    thread.on_fail(camp, nil)

    assert(master.defeats == 1, 'on_fail must record the defeat')
    assert(master.defeated == false, 'on_fail must not mark the master defeated')
    assert(camp.current_master_id == master_id, 'on_fail must not advance the master')
    assert(camp.active_thread.id == 'master_trial', 'on_fail must keep the thread')
end)

test('T3b resolve_scene_id follows alt_when_locked', function()
    reset_calls()
    RunState.unlocks = {}
    local player = make_player()
    local node = master_boss_node()

    assert(node:isLocked(player) == true, 'node should be locked without the run key')
    assert(node:resolve_scene_id(player) == 'boss_angry',
        'locked node must fall back to alt_when_locked')

    RunState.unlocks = { dojo_key = 1 }
    assert(node:isLocked(player) == false, 'node unlocks once the run key is held')
    assert(node:resolve_scene_id(player) == 'master_boss',
        'unlocked node plays its own scene')

    RunState.unlocks = {}
end)

test('T3c story_key gate is consumed when the node closes', function()
    require_handlers()
    reset_calls()
    local camp = fresh_campaign()
    camp.persistent_keys.moon_key = true
    camp.key_threads.moon_key = { payoff_consumed = false }
    local player = make_player(camp)
    local lm   = make_levelmap(player)
    local node = make_node({
        story_scene = 'moon_door',
        story_id    = 'moon_door',
        requires    = { story_key = 'moon_key' },
    })
    lm.currentNode = node

    Levelmap.resume(lm, Fakes.EventState, { complete = true })

    assert(camp.persistent_keys.moon_key == nil,
        'closing a story_key-gated node must consume the key')
end)

-- ===========================================================================
-- Report
-- ===========================================================================

print(('%d assertion group(s) failed'):format(failures))
if failures > 0 then
    print('smoke_master_boss FAILED')
    os.exit(1)
end

print('smoke_master_boss OK')
os.exit(0)
