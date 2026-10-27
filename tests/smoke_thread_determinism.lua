-- tests/smoke_thread_determinism.lua
--
-- Regression guard for thread selection. See AGENTS.md "Determinism".
--
-- Background: a D3-measure sweep reported "bond_arc 100/100, master_trial
-- unreachable". That was a measurement artefact. _place_story calls
-- ThreadGenerator.select() once (story_placement.lua:236) and pins the result
-- in camp.active_thread; it also calls PlayerMetaStory.begin_new_run(), which
-- bumps camp.total_runs and therefore flips bond_arc.weight from 0 to 8.
-- A harness that calls select() a SECOND time after _place_story is asking
-- about a forced continuation, not about a fresh weighted pick.
--
-- What this test pins:
--   * select() is a pure function of (RunState:reset(seed), camp state);
--   * bond_arc (weight 0 on a fresh campaign) is never chosen;
--   * master_trial is actually reachable through the weighted pick;
--   * the production path selects exactly once per run.
--
-- Headless. Run: lua tests/smoke_thread_determinism.lua

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
        -- Park-Miller. Warm-up draws are REQUIRED: the raw first output is
        -- (16807*seed mod M - 1)/(M-1), which for ordinary seeds is ~1e-5 — a
        -- heavy bias toward zero that makes a single-draw weighted pick choose
        -- the first non-zero bucket every time. Real LÖVE RNGs scramble the
        -- seed, so the warm-up models them. Without it, seeded distribution
        -- checks in this suite would lie.
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

FadeInState = {} FadeOutState = {} TownState = {}
BattleState = {} RestState = {} ShopState = {} EventState = {}

Gamestate = { push = function() end, pop = function() end, switch = function() end,
              current = function() return nil end }
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

local ThreadGenerator = require 'src.story.thread_generator'
local Threads         = require 'data.story.threads'
local PlayerMetaStory = require 'src.player_meta_story'
local MasterGenerator = require 'data.story.generators.master_generator'

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function make_player(seed)
    local camp = PlayerMetaStory.create(seed)
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

-- Fresh campaign + fresh RNG, then a single select(). This is the unit whose
-- determinism is under test.
local function select_once(seed)
    local player = make_player(seed)
    RunState:reset(player, seed)
    local thread = ThreadGenerator.select(player, RunState, Threads)
    return {
        player = player,
        picked = RunState.story and RunState.story.thread_id or nil,
        thread = thread,
    }
end

local function pool_weights(player)
    local pool = ThreadGenerator.pool(player, RunState, Threads)
    local w = {}
    for _, e in ipairs(pool) do w[e.id] = e.weight end
    return w
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
-- Determinism: same seed => same pick
-- ===========================================================================

test('D1 same seed selects the same thread 20 times', function()
    local expected = select_once(1).picked
    assert(expected, 'seed 1 selected no thread — nothing to compare')
    for i = 1, 20 do
        local got = select_once(1).picked
        assert(got == expected,
            ('run %d: expected %q, got %q'):format(i, tostring(expected), tostring(got)))
    end
end)

test('D2 distinct seeds stay stable across repeated selection', function()
    -- Guards against hidden global state: each seed must reproduce its own pick
    -- regardless of the order seeds are evaluated in.
    local first = {}
    for seed = 1, 20 do first[seed] = select_once(seed).picked end
    for seed = 20, 1, -1 do
        local again = select_once(seed).picked
        assert(again == first[seed],
            ('seed %d: %q on first pass, %q on reverse pass')
                :format(seed, tostring(first[seed]), tostring(again)))
    end
end)

test('D3 selecting twice from the same reset state is idempotent', function()
    local player = make_player(7)
    RunState:reset(player, 7)
    ThreadGenerator.select(player, RunState, Threads)
    local first = RunState.story.thread_id

    -- Re-select without resetting: active_thread is now pinned, so this is a
    -- forced continuation and must agree with the first pick.
    ThreadGenerator.select(player, RunState, Threads)
    assert(RunState.story.thread_id == first,
        ('forced continuation changed the thread: %q -> %q')
            :format(tostring(first), tostring(RunState.story.thread_id)))
end)

-- ===========================================================================
-- Weight semantics: weight 0 is never selected
-- ===========================================================================

test('D4 a weight-0 thread is never selected', function()
    -- On a fresh campaign total_runs == 0, so bond_arc.weight() returns 0.
    local zero_weight_ids = {}
    local picked_seed, picked_id

    for seed = 1, 100 do
        local player = make_player(seed)
        RunState:reset(player, seed)
        local weights = pool_weights(player)
        local picked  = ThreadGenerator.select(player, RunState, Threads)
        local id      = RunState.story and RunState.story.thread_id

        local w = weights[id]
        assert(w ~= 0,
            ('seed %d: selected %q which has weight 0'):format(seed, tostring(id)))
        if w == 0 then zero_weight_ids[#zero_weight_ids + 1] = tostring(id) end
        if not picked_seed then picked_seed, picked_id = seed, id end
    end

    assert(#zero_weight_ids == 0,
        ('weight-0 threads selected: %s'):format(table.concat(zero_weight_ids, ',')))
end)

test('D5 bond_arc has weight 0 on a fresh campaign', function()
    local player = make_player(1)
    RunState:reset(player, 1)
    local weights = pool_weights(player)
    assert(weights.bond_arc ~= nil, 'bond_arc should be eligible on a fresh campaign')
    assert(weights.bond_arc == 0,
        ('bond_arc weight on a fresh campaign: expected 0, got %s')
            :format(tostring(weights.bond_arc)))
end)

-- ===========================================================================
-- Reachability: master_trial must actually be selectable
-- ===========================================================================

test('D6 master_trial is selected by at least 20% of seeds 1..100', function()
    local n = 0
    for seed = 1, 100 do
        if select_once(seed).picked == 'master_trial' then n = n + 1 end
    end
    print(('         master_trial selected: %d / 100'):format(n))
    assert(n >= 20,
        ('master_trial selected only %d/100 — it carries the highest weight '
         .. 'and must not be starved'):format(n))
end)

test('D7 master_trial appears in the pool for every seed', function()
    for seed = 1, 100 do
        local player = make_player(seed)
        RunState:reset(player, seed)
        local weights = pool_weights(player)
        assert(weights.master_trial ~= nil,
            ('seed %d: master_trial missing from the thread pool'):format(seed))
        assert(weights.master_trial > 0,
            ('seed %d: master_trial has weight %s'):format(seed, tostring(weights.master_trial)))
    end
end)

-- ===========================================================================
-- The measurement artefact itself
-- ===========================================================================

test('D8 total_runs changes bond_arc weight — the sweep artefact', function()
    -- Documents WHY a post-placement select() differs from a pre-placement one.
    local player = make_player(1)
    RunState:reset(player, 1)

    local before = pool_weights(player).bond_arc
    PlayerMetaStory.begin_new_run(player.meta_story)
    local after = pool_weights(player).bond_arc

    assert(before == 0,
        ('bond_arc weight before begin_new_run: expected 0, got %s'):format(tostring(before)))
    assert(after ~= 0,
        'begin_new_run should raise bond_arc weight off zero')
    print(('         bond_arc weight: %s -> %s after begin_new_run')
        :format(tostring(before), tostring(after)))
end)

-- ===========================================================================
-- Report
-- ===========================================================================

print(('%d assertion group(s) failed'):format(failures))
if failures > 0 then
    print('smoke_thread_determinism FAILED')
    os.exit(1)
end

print('smoke_thread_determinism OK')
os.exit(0)
