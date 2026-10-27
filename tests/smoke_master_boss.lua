-- tests/smoke_master_boss.lua
--
-- Integration smoke test for the master-boss pipeline.
--
-- What this file checks, and what it deliberately reports as missing, is
-- driven by what src/states/levelmap2.lua actually implements today. See the
-- "Groups whose production code does not exist yet" section at the bottom.
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
-- levelmap2.lua binds the real state modules at its own load time
-- (`local UpgradeSelectScreen = require 'src.upgrade_select_screen'`), and
-- src/node.lua resolves BattleState / EventState from package.loaded when its
-- node_gamestates table is evaluated. Both happen during `require`, so these
-- entries must exist first. Fakes carry no game logic.
-- ---------------------------------------------------------------------------

local Fakes = {}
Fakes.BattleState         = { __name = 'BattleState' }
Fakes.EventState          = { __name = 'EventState' }
Fakes.RestState           = { __name = 'RestState' }
Fakes.ShopState           = { __name = 'ShopState' }
Fakes.TownState           = { __name = 'TownState' }
Fakes.UpgradeSelectScreen = {
    __name   = 'UpgradeSelectScreen',
    isActive = function() return false end,
    open     = function() end,
    draw     = function() end,
}

package.loaded['src.states.battlestate']           = Fakes.BattleState
package.loaded['src.states.eventstate']            = Fakes.EventState
package.loaded['src.states.reststate']             = Fakes.RestState
package.loaded['src.states.shopstate']             = Fakes.ShopState
package.loaded['src.states.townstate']             = Fakes.TownState
package.loaded['src.states.upgrade_select_screen'] = Fakes.UpgradeSelectScreen

-- src/node.lua reads these as globals; main.lua normally provides them.
BattleState = Fakes.BattleState
EventState  = Fakes.EventState

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

-- Real RunState: cheap to load, and its API is exactly what Node/Levelmap call.
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

-- src.states.levelmap2 pulls in the REAL src.player, which requires the real
-- state modules again during this require. Those requires load Node, and Node
-- snapshots BattleState/EventState into its node_gamestates table at load time.
-- Re-assert the fakes after Levelmap loads, and again after Node loads, so the
-- routing table is built from the fakes and not from half-loaded reals.
local Levelmap = require 'src.states.levelmap2'

local function assert_fakes_installed()
    for key, fake in pairs({
        ['src.states.battlestate'] = Fakes.BattleState,
        ['src.states.eventstate']  = Fakes.EventState,
    }) do
        package.loaded[key] = fake
    end
    BattleState = Fakes.BattleState
    EventState  = Fakes.EventState
end

assert_fakes_installed()

-- Drop any table a pre-fake load may have produced, then load Node for real.
package.loaded['src.node'] = nil
local Node = require 'src.node'
assert_fakes_installed()

local PlayerMetaStory = require 'src.player_meta_story'
local MasterGenerator = require 'data.story.generators.master_generator'
local SceneGraph      = require 'src.story.scene_graph'
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

local function master_boss_node(extra)
    local fields = {
        is_master_boss = true,
        is_boss        = true,
        story_scene    = 'master_boss',
    }
    for k, v in pairs(extra or {}) do fields[k] = v end
    return make_node(fields)
end

local failures, skips = 0, 0

local function test(label, fn)
    local ok, err = pcall(fn)
    if ok then
        print('  ok   ' .. label)
    else
        failures = failures + 1
        print('  FAIL ' .. label .. '\n         ' .. tostring(err))
    end
end

local function skip(label, reason)
    skips = skips + 1
    print('  SKIP ' .. label .. '\n         ' .. reason)
end

-- ===========================================================================
-- T1 — master-boss node routing
-- ===========================================================================
--
-- Levelmap:_handle_story_node_complete does not exist (see the missing-groups
-- section), so the routing half of that contract is asserted where it does
-- live: src/node.lua maps node types to states.
--
-- Nodes are built with a battle type ('wild'/'trainer'/'end'), because
-- Node:getGamestate only understands node types. story_placement.stamp() sets
-- type = 'event' on every story node, the boss included, while is_boss /
-- is_master_boss are flags of their own. So a story boss node routes to
-- EventState here; whether that is a defect depends on the absent
-- _handle_story_node_complete, and T1c pins the behavior either way.

test('T1a master-boss node routes to BattleState', function()
    reset_calls()
    local node = master_boss_node({ type = 'wild' })
    local gs = node:getGamestate()
    assert(gs == Fakes.BattleState,
        ('a master-boss battle node must route to BattleState, got %s (type=%s)')
            :format(tostring(gs and gs.__name or gs), tostring(node.type)))
end)

test('T1b closing a story node completes it without pushing a battle', function()
    reset_calls()
    local camp = fresh_campaign()
    local lm   = make_levelmap(make_player(camp))
    local node = master_boss_node({ type = 'event' })
    lm.currentNode = node

    Levelmap.resume(lm, Fakes.EventState, { complete = true })

    assert(node.isCompleted == true, 'story node should be completed on close')
    assert(#calls_with_state(Fakes.BattleState) == 0,
        'closing EventState must not push BattleState by itself')
end)

test('T1c story boss node (type=event, is_master_boss) routes to EventState', function()
    reset_calls()
    -- Mirrors what story_placement.stamp() produces for the boss node.
    local node = master_boss_node({ type = 'event' })
    local gs = node:getGamestate()

    assert(gs == Fakes.EventState,
        ('PINNED GAP: story boss node now routes to %s — if Levelmap gained a '
         .. 'post-EventState battle dispatch, update Test 1 to follow it')
            :format(tostring(gs and gs.__name or gs)))
    assert(node.is_master_boss == true,
        'is_master_boss must survive on the node for later dispatch')
    assert(node.is_boss == true, 'is_boss must survive on the node')
end)

-- ===========================================================================
-- T2 — master defeat: memory kept, thread kept
-- ===========================================================================

test('T2 master defeat keeps the master and the thread', function()
    reset_calls()
    local camp = fresh_campaign()
    camp.active_thread = { id = 'master_trial', params = {}, started_run = 1 }
    local player = make_player(camp)
    player.lives = 3
    local lm   = make_levelmap(player)
    local node = master_boss_node()
    lm.currentNode = node

    local master_id = camp.current_master_id
    local master    = camp.masters[master_id]

    -- Defeat contract (stub): the thread's on_fail records the loss.
    local thread = Threads[camp.active_thread.id]
    assert(thread and thread.on_fail, 'master_trial must expose on_fail')
    thread.on_fail(camp, nil)

    assert(master.defeats == 1,
        ('defeat count: expected 1, got %s'):format(tostring(master.defeats)))
    assert(master.defeated == false, 'a defeat must not mark the master defeated')
    assert(camp.current_master_id == master_id, 'defeat must not advance the master')
    assert(camp.active_thread and camp.active_thread.id == 'master_trial',
        'defeat must keep the active thread')

    -- Real resume(BattleState) path as it exists today.
    Levelmap.resume(lm, Fakes.BattleState, { won = false })
    assert(node.isCompleted == true, 'resume marks the boss node completed')
    assert(camp.current_master_id == master_id, 'resume must not advance the master')

    -- The loss contract (lives -> 0) is only reachable if Levelmap consumes the
    -- battle result. It does not: resume() branches on args.result, not args.won.
    assert(player.lives == 3,
        ('PINNED GAP: lives changed to %s — Levelmap now handles defeat; '
         .. 'fold Test 3/R6 into this group'):format(tostring(player.lives)))
end)

-- ===========================================================================
-- T3 — routing and gates
-- ===========================================================================

test('T3a non-master story node completes without a battle', function()
    reset_calls()
    local camp = fresh_campaign()
    local lm   = make_levelmap(make_player(camp))
    local node = make_node({ story_scene = 'master_crossroads' })
    lm.currentNode = node

    Levelmap.resume(lm, Fakes.EventState, { complete = true })

    assert(node.isCompleted == true, 'non-master story node should complete')
    assert(#calls_with_state(Fakes.BattleState) == 0,
        'no BattleState push for a non-master story node')
end)

test('T3b resolve_scene_id follows alt_when_locked', function()
    reset_calls()
    RunState.unlocks = {}
    local player = make_player()
    local node = master_boss_node({
        requires        = { run_key = 'dojo_key' },
        alt_when_locked = 'boss_angry',
    })

    assert(node:isLocked(player) == true, 'node should be locked without the run key')
    assert(node:resolve_scene_id(player) == 'boss_angry',
        'locked node must fall back to alt_when_locked')

    RunState.unlocks = { dojo_key = 1 }
    assert(node:isLocked(player) == false, 'node unlocks once the run key is held')
    assert(node:resolve_scene_id(player) == 'master_boss',
        'unlocked node plays its own scene')

    RunState.unlocks = {}
end)

test('T3c story_key gate is not consumed by resume', function()
    reset_calls()
    local camp = fresh_campaign()
    camp.persistent_keys.moon_key = true
    camp.key_threads.moon_key = { payoff_consumed = false }
    local player = make_player(camp)
    local lm   = make_levelmap(player)
    local node = make_node({
        story_scene = 'moon_door',
        requires    = { story_key = 'moon_key' },
    })
    lm.currentNode = node

    Levelmap.resume(lm, Fakes.EventState, { complete = true })

    -- Consumption belongs to the scene / key machinery, not to resume().
    assert(camp.persistent_keys.moon_key == true,
        'PINNED GAP: resume consumed the story key — update this test if intended')
end)

-- ===========================================================================
-- Missing production code — reported, never faked.
-- ===========================================================================

local MISSING = {
    { '_handle_story_node_complete', 'node close -> BattleState push' },
    { '_handle_master_victory',      'win  -> MasterGenerator.on_victory' },
    { '_handle_master_defeat',       'lose -> MasterGenerator.on_defeat' },
    { '_handle_run_failed',          'lose -> lives -> TownState' },
}

for _, entry in ipairs(MISSING) do
    local name, meaning = entry[1], entry[2]
    if Levelmap[name] then
        test('T-gap Levelmap:' .. name, function()
            assert(false, ('PINNED: Levelmap:%s now exists (%s) — '
                .. 'fold this group back into the suite'):format(name, meaning))
        end)
    else
        skip('Levelmap:' .. name,
            'not implemented in src/states/levelmap2.lua (' .. meaning .. ')')
    end
end

-- ===========================================================================
-- Report
-- ===========================================================================

print(('%d assertion group(s) failed, %d skipped'):format(failures, skips))
if failures > 0 then
    print('smoke_master_boss FAILED')
    os.exit(1)
end

print('smoke_master_boss OK')
os.exit(0)
