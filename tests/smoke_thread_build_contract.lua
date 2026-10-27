-- tests/smoke_thread_build_contract.lua
--
-- Regression guard for the pin-after-build contract:
--
--   A thread is pinned in camp.active_thread only AFTER its build(ctx) has
--   returned a non-nil graph. A pinned thread whose build now refuses (runtime
--   guard unmet) has its pin released and selection proceeds normally.
--
-- Background: select() used to pin before build, so a thread with a build-time
-- guard (lost_beast: party < 2 or every creature above 60% HP) could be pinned,
-- fail placement, and force every later run back into itself — a silent loop of
-- legacy runs.
--
-- Headless. Run: lua tests/smoke_thread_build_contract.lua

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
        -- Warm-up required (AGENTS.md "Determinism").
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
local SceneGraph      = require 'src.story.scene_graph'
local Threads         = require 'data.story.threads'
local PlayerMetaStory = require 'src.player_meta_story'
local MasterGenerator = require 'data.story.generators.master_generator'
local Levelmap        = require 'src.states.levelmap2'

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

-- two_creatures_hurt: satisfies lost_beast's guard
--   party >= 2 and at least one creature below 60% HP
local function healthy(c) c.health = c.max_health; return c end

local function make_player(seed, party_kind)
    local camp = PlayerMetaStory.create(seed)
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

    if party_kind == 'hurt' then
        p.charactersActive = {
            { name = 'Emberpuff', health = 20, max_health = 28, level = 1, exp = 0 },
            { name = 'Terrow',    health = 5,  max_health = 30, level = 1, exp = 0 },
        }
    elseif party_kind == 'healthy' then
        p.charactersActive = {
            { name = 'Emberpuff', health = 28, max_health = 28, level = 1, exp = 0 },
            { name = 'Terrow',    health = 30, max_health = 30, level = 1, exp = 0 },
        }
    end
    -- 'empty' leaves charactersActive == {}
    return p
end

local function select_fresh(player, seed)
    RunState:reset(player, seed)
    return ThreadGenerator.select(player, RunState, Threads)
end

local function serialize_graph(g)
    if not g then return 'nil' end
    local ids = {}
    for id in pairs(g) do ids[#ids + 1] = id end
    table.sort(ids)
    local parts = {}
    for _, id in ipairs(ids) do
        parts[#parts + 1] = id .. ':' .. tostring(g[id].scene)
            .. '|' .. table.concat(SceneGraph.outgoing(g[id]), ',')
    end
    return table.concat(parts, ';')
end

-- The id of the thread the last select() chose.
local function run_thread_id(runState)
    return runState.story and runState.story.thread_id or nil
end

-- select() must hand back a usable graph: non-nil with a start node.
local function run_graph_ok(graph)
    return type(graph) == 'table' and graph.start ~= nil
end

-- Select again after a fresh reset, leaving the party and campaign as they are
-- (used to prove a released pin does not come back on the following run).
local function run_thread_id_after_second_select(player, seed)
    RunState:reset(player, seed)
    ThreadGenerator.select(player, RunState, Threads)
    return run_thread_id(RunState)
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
-- A — empty party: lost_beast cannot build, so it must not be picked or pinned
-- ===========================================================================

test('A empty party: lost_beast is not selected and not pinned', function()
    for _, seed in ipairs({ 1, 2, 3, 4, 5 }) do
        local player = make_player(seed, 'empty')
        local thread, _, graph = select_fresh(player, seed)
        local id = run_thread_id(RunState)

        assert(id ~= 'lost_beast',
            ('seed %d: lost_beast selected with an empty party'):format(seed))
        assert(run_graph_ok(graph),
            ('seed %d: select returned no graph for %s')
                :format(seed, tostring(thread and thread.id)))
        assert(not (player.meta_story.active_thread
            and player.meta_story.active_thread.id == 'lost_beast'),
            ('seed %d: lost_beast was pinned despite an empty party'):format(seed))
    end
end)

test('A2 empty party: selection is deterministic across resets', function()
    local results = {}
    for i = 1, 2 do
        local player = make_player(7, 'empty')
        local _, _, graph = select_fresh(player, 7)
        results[i] = serialize_graph(graph) .. '@' .. tostring(run_thread_id(RunState))
    end
    assert(results[1] == results[2],
        ('empty-party selection diverged:\n         %s\n         %s')
            :format(results[1], results[2]))
end)

-- ===========================================================================
-- B — realistic party, lost_beast forced: builds, pins, returns a graph
-- ===========================================================================

test('B realistic party + pin: lost_beast selected with a graph', function()
    local player = make_player(1, 'hurt')
    player.meta_story.active_thread = { id = 'lost_beast', params = {}, started_run = 0 }

    RunState:reset(player, 1)
    local thread, _, graph = ThreadGenerator.select(player, RunState, Threads)

    assert(thread and thread.id == 'lost_beast',
        ('forced lost_beast returned %q'):format(tostring(thread and thread.id)))
    assert(graph ~= nil, 'select() returned no graph for lost_beast')
    assert(type(graph) == 'table' and graph.start ~= nil,
        'returned graph has no start node')
    assert(player.meta_story.active_thread
        and player.meta_story.active_thread.id == 'lost_beast',
        'lost_beast should remain pinned while its guard holds')
    assert(RunState.story and RunState.story.thread_id == 'lost_beast',
        ('RunState.story.thread_id is %q')
            :format(tostring(RunState.story and RunState.story.thread_id)))
end)

-- ===========================================================================
-- C — pinned lost_beast, party heals: pin released, another thread chosen
-- ===========================================================================

test('C pin released when lost_beast guard becomes unmet', function()
    local player = make_player(1, 'hurt')
    player.meta_story.active_thread = { id = 'lost_beast', params = {}, started_run = 0 }

    -- Heal everyone: ratio > 0.6 for all, so build() now returns nil.
    for _, c in ipairs(player.charactersActive) do healthy(c) end

    RunState:reset(player, 1)
    local thread, _, graph = ThreadGenerator.select(player, RunState, Threads)

    assert(not (player.meta_story.active_thread
        and player.meta_story.active_thread.id == 'lost_beast'),
        'lost_beast is still pinned although its build now returns nil')

    local id = run_thread_id(RunState)
    assert(id ~= 'lost_beast',
        ('lost_beast selected despite an unmet guard (id=%q)'):format(tostring(id)))

    if thread then
        assert(id == thread.id,
            ('RunState.story.thread_id %q disagrees with select() thread %q')
                :format(tostring(id), tostring(thread.id)))
        assert(run_graph_ok(graph),
            'the replacement thread must also come with a graph')
    end
end)

test('C2 released pin does not resurrect on the next run', function()
    local player = make_player(1, 'hurt')
    player.meta_story.active_thread = { id = 'lost_beast', params = {}, started_run = 0 }
    for _, c in ipairs(player.charactersActive) do healthy(c) end

    RunState:reset(player, 1)
    ThreadGenerator.select(player, RunState, Threads)

    -- Second run, still healed: must not be forced back into lost_beast.
    local id2 = run_thread_id_after_second_select(player, 2)
    assert(id2 ~= 'lost_beast',
        ('run 2 forced lost_beast again (id=%q)'):format(tostring(id2)))
end)

-- ===========================================================================
-- D — determinism: same seed + same party => identical thread and graph
-- ===========================================================================

test('D same seed and party give an identical thread and graph', function()
    for _, kind in ipairs({ 'empty', 'hurt', 'healthy' }) do
        local a = make_player(11, kind)
        local ta, _, ga = select_fresh(a, 11)
        local ida = run_thread_id(RunState)

        local b = make_player(11, kind)
        local tb, _, gb = select_fresh(b, 11)
        local idb = run_thread_id(RunState)

        assert(ida == idb,
            ('party=%s: thread diverged %q vs %q')
                :format(kind, tostring(ida), tostring(idb)))
        assert(serialize_graph(ga) == serialize_graph(gb),
            ('party=%s: graph diverged\n         %s\n         %s')
                :format(kind, serialize_graph(ga), serialize_graph(gb)))
        assert((ta and ta.id) == (tb and tb.id),
            ('party=%s: returned thread objects disagree'):format(kind))
    end
end)

-- ===========================================================================
-- E — full path through Levelmap:_place_story
-- ===========================================================================

test('E _place_story succeeds for a realistic-party run', function()
    local player = make_player(1, 'hurt')

    RunState:reset(player, 1)
    RunState.story   = { thread_id = 'master_trial', flags = {} }
    RunState.unlocks = {}

    local lm = setmetatable({}, { __index = Levelmap })
    lm.player = player
    lm.nodes  = {}
    lm.pathes = {}
    lm.active = true
    lm.seed   = 1

    math.randomseed(1)
    lm:_generateMap()
    lm:_place_story()

    assert(lm.story ~= nil, '_place_story produced no story for a realistic party')
    assert(lm.story.thread.id == RunState.story.thread_id,
        ('placed thread %q != RunState.story.thread_id %q')
            :format(tostring(lm.story.thread.id), tostring(RunState.story.thread_id)))

    local placed = 0
    for _, n in ipairs(lm.nodes) do
        if n.story_scene then placed = placed + 1 end
    end
    assert(placed > 0, 'story placed but no node was stamped')
end)

-- ===========================================================================
-- F — regression: master_trial pinned still selects with a graph
-- ===========================================================================

test('F master_trial pin still selects with a graph', function()
    local player = make_player(1, 'empty')
    player.meta_story.active_thread = { id = 'master_trial', params = {}, started_run = 0 }

    RunState:reset(player, 1)
    local thread, _, graph = ThreadGenerator.select(player, RunState, Threads)

    assert(thread and thread.id == 'master_trial',
        ('expected master_trial, got %q'):format(tostring(thread and thread.id)))
    assert(graph ~= nil, 'master_trial select returned no graph')
    assert(graph.start and graph.start.scene == 'master_arrival',
        'master_trial graph does not start at master_arrival')
    assert(player.meta_story.active_thread.id == 'master_trial',
        'master_trial should stay pinned')
end)

-- ===========================================================================
-- Report
-- ===========================================================================

print(('%d assertion group(s) failed'):format(failures))
if failures > 0 then
    print('smoke_thread_build_contract FAILED')
    os.exit(1)
end

print('smoke_thread_build_contract OK')
os.exit(0)
