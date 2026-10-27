-- tests/measure_placement_T1.lua
--
-- MEASUREMENT SCRIPT, not a test. Always exits 0.
--
--   lua tests/measure_placement_T1.lua
--
-- Re-runs BOTH sweeps (pinned master_trial and unpinned natural selection) with
-- the current is_usable (T1: event/wild/trainer) and prints the comparison
-- against the recorded T0 baseline:
--
--   pinned   T0 baseline: 78 / 22  (78.0% / 22.0%)
--   unpinned T0 subset:   master_trial 34 / 52 (65.4%)
--
-- This is a real re-run, not an eligibility count: placement consumes RNG
-- differently under T1, so previously-successful seeds can move too.

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

local Levelmap        = require 'src.states.levelmap2'
local PlayerMetaStory = require 'src.player_meta_story'
local MasterGenerator = require 'data.story.generators.master_generator'

local SEED_FROM, SEED_TO = 1, 100

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local real_print = print
local captured, capturing = {}, false
print = function(...)
    if capturing then
        local parts = {}
        for i = 1, select('#', ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        captured[#captured + 1] = table.concat(parts, ' ')
        return
    end
    real_print(...)
end

-- Party styles. lost_beast.build guards on party >= 2 AND at least one creature
-- below 60% HP, so an empty party can never select it — that was why the old
-- fixture reported lost_beast 0/13. 'hurt' exercises the guard's passing side.
local PARTY_STYLES = {
    empty = function() return {} end,
    hurt = function()
        return {
            { name = 'Emberpuff', health = 20, max_health = 28, level = 1, exp = 0 },
            { name = 'Terrow',    health = 5,  max_health = 30, level = 1, exp = 0 },
        }
    end,
}

local function make_player(seed, party_style)
    local camp = PlayerMetaStory.create(seed)
    MasterGenerator.ensure_campaign(camp)
    return {
        meta_story       = camp,
        lives            = 3,
        charactersActive = PARTY_STYLES[party_style or 'empty'](),
        charactersSpare  = {},
        shards           = {},
        inventory        = {},
        drawLives        = function() end,
    }
end

local function make_levelmap(player, seed)
    local lm = setmetatable({}, { __index = Levelmap })
    lm.player = player
    lm.nodes  = {}
    lm.pathes = {}
    lm.active = true
    lm.seed   = seed
    return lm
end

local function run_seed(seed, pin, party_style)
    local player = make_player(seed, party_style)
    if pin then
        player.meta_story.active_thread = { id = 'master_trial', params = {}, started_run = 0 }
    end

    RunState:reset(player, seed)
    RunState.story   = { thread_id = 'master_trial', flags = {} }
    RunState.unlocks = {}

    local lm = make_levelmap(player, seed)
    math.randomseed(seed)
    lm:_generateMap()

    captured = {}
    capturing = true
    lm:_place_story()
    capturing = false

    -- Attribute from the placed result (AGENTS.md "Determinism").
    local thread_id = (lm.story and lm.story.thread and lm.story.thread.id)
        or (RunState.story and RunState.story.thread_id)

    local placed, overwritten = {}, {}
    for _, n in ipairs(lm.nodes) do
        if n.story_scene then
            placed[#placed + 1] = n
        end
    end

    return {
        seed    = seed,
        success = lm.story ~= nil,
        thread  = thread_id,
        placed  = placed,
        diag    = captured,
    }
end

local function pct(n, total)
    if total == 0 then return 'n/a' end
    return ('%.1f%%'):format(100 * n / total)
end

-- ===========================================================================
-- Sweep A — pinned master_trial
-- ===========================================================================

local pinned = {}
for seed = SEED_FROM, SEED_TO do pinned[#pinned + 1] = run_seed(seed, true, 'hurt') end

local okA, failA = 0, 0
local failSeeds, failScenes = {}, {}
for _, r in ipairs(pinned) do
    if r.success then okA = okA + 1 else
        failA = failA + 1
        failSeeds[#failSeeds + 1] = tostring(r.seed)
        for _, line in ipairs(r.diag) do
            local scene = line:match('placement failed: scene (%a+)')
            if scene then failScenes[scene] = (failScenes[scene] or 0) + 1 end
        end
    end
end

local sceneCounts = {}
for _, r in ipairs(pinned) do
    if r.success then
        sceneCounts[#r.placed] = (sceneCounts[#r.placed] or 0) + 1
    end
end

real_print('════════════════════════════════════════════════')
real_print('PINNED master_trial — T1 is_usable (event/wild/trainer)')
real_print('════════════════════════════════════════════════')
real_print(('Total seeds:            %d'):format(#pinned))
real_print(('Successful placements:  %d  (%s)'):format(okA, pct(okA, #pinned)))
real_print(('Failed placements:      %d  (%s)'):format(failA, pct(failA, #pinned)))
real_print('  -- baseline (T0):      78 / 22   (78.0% / 22.0%)')
real_print('')
local sc = {}
for k in pairs(sceneCounts) do sc[#sc + 1] = k end
table.sort(sc)
real_print('Scene count distribution (successful):')
for _, k in ipairs(sc) do real_print(('  %d scenes: %d'):format(k, sceneCounts[k])) end
real_print('')
if failA > 0 then
    real_print(('Failing seeds (%d): %s'):format(failA, table.concat(failSeeds, ', ')))
    local parts = {}
    for id, c in pairs(failScenes) do parts[#parts + 1] = ('%s=%d'):format(id, c) end
    real_print(('Failing scene breakdown: %s'):format(table.concat(parts, ', ')))
    real_print('')
    for _, r in ipairs(pinned) do
        if not r.success then
            real_print(('─── seed %d ───'):format(r.seed))
            for _, line in ipairs(r.diag) do real_print('  ' .. line) end
        end
    end
else
    real_print('No placement failures.')
end
real_print('')

-- ===========================================================================
-- Sweep B — unpinned natural selection, for both party styles
-- ===========================================================================

local function unpinned_sweep(party_style)
    local rows = {}
    for seed = SEED_FROM, SEED_TO do
        rows[#rows + 1] = run_seed(seed, false, party_style)
    end

    local per_thread = {}
    for _, r in ipairs(rows) do
        local id = r.thread or '(none)'
        per_thread[id] = per_thread[id] or { total = 0, ok = 0 }
        per_thread[id].total = per_thread[id].total + 1
        if r.success then per_thread[id].ok = per_thread[id].ok + 1 end
    end

    local ok = 0
    for _, r in ipairs(rows) do if r.success then ok = ok + 1 end end

    return { rows = rows, per_thread = per_thread, ok = ok, fail = #rows - ok }
end

for _, style in ipairs({ 'empty', 'hurt' }) do
    local s   = unpinned_sweep(style)
    local ids = {}
    for id in pairs(s.per_thread) do ids[#ids + 1] = id end
    table.sort(ids)

    real_print('════════════════════════════════════════════════')
    real_print(('UNPINNED sweep — T1 is_usable, party = %s'):format(style))
    real_print('════════════════════════════════════════════════')
    real_print(('Successful placements:  %d  (%s)'):format(s.ok, pct(s.ok, #s.rows)))
    real_print(('Failed placements:      %d  (%s)'):format(s.fail, pct(s.fail, #s.rows)))
    real_print('')
    real_print('Per-thread:')
    for _, id in ipairs(ids) do
        local e = s.per_thread[id]
        real_print(('  %-16s %2d selected, %2d ok  (%s)')
            :format(id, e.total, e.ok, pct(e.ok, e.total)))
    end
    real_print('')

    local mt = s.per_thread['master_trial']
    if mt then
        real_print(('Unpinned master_trial (%s party): %d selected, %d/%d ok (%s)')
            :format(style, mt.total, mt.ok, mt.total, pct(mt.ok, mt.total)))
    else
        real_print(('Unpinned master_trial (%s party): never selected'):format(style))
    end

    local lb = s.per_thread['lost_beast']
    if lb then
        real_print(('Unpinned lost_beast (%s party): %d selected, %d ok (%s)')
            :format(style, lb.total, lb.ok, pct(lb.ok, lb.total)))
    else
        real_print(('Unpinned lost_beast (%s party): never entered the pool — '
            .. 'build guard excluded it'):format(style))
    end
    real_print('')
end

os.exit(0)
