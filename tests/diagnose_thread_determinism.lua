-- tests/diagnose_thread_determinism.lua
--
-- DIAGNOSTIC SCRIPT, not a test. Always exits 0.
--
--   lua tests/diagnose_thread_determinism.lua
--
-- Isolates why the unpinned sweep reported bond_arc 100/100 while an isolated
-- select() on seed 1 picks lore_moon_key. Runs the same seed through three
-- variants (direct select, +generateMap, +placeStory) and diffs the outcome.

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
local ThreadGenerator = require 'src.story.thread_generator'
local Threads         = require 'data.story.threads'
local PlayerMetaStory = require 'src.player_meta_story'
local MasterGenerator = require 'data.story.generators.master_generator'

-- ---------------------------------------------------------------------------
-- Fixtures
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

local function make_levelmap(player, seed)
    local lm = setmetatable({}, { __index = Levelmap })
    lm.player = player
    lm.nodes  = {}
    lm.pathes = {}
    lm.active = true
    lm.seed   = seed
    return lm
end

-- Snapshot of the pool exactly as ThreadGenerator builds it.
local function pool_snapshot(player, runState)
    local pool = ThreadGenerator.pool(player, runState, Threads)
    local snap = {}
    for _, e in ipairs(pool) do
        snap[#snap + 1] = { id = e.id, weight = e.weight }
    end
    return snap
end

local function pool_string(snap)
    local parts = {}
    for _, e in ipairs(snap) do
        parts[#parts + 1] = ('%s:%s'):format(e.id, tostring(e.weight))
    end
    return table.concat(parts, ' ')
end

-- One variant: fresh player, reset(seed), optional steps, then select().
local function run_variant(seed, steps)
    local player = make_player(seed)
    local camp   = player.meta_story

    RunState:reset(player, seed)

    if steps >= 1 then
        local lm = make_levelmap(player, seed)
        math.randomseed(seed)
        lm:_generateMap()
        if steps >= 2 then lm:_place_story() end
        -- NOTE: _place_story runs ThreadGenerator.select internally and pins
        -- active_thread, so the later select() is a forced continuation.
    end

    local snap = pool_snapshot(player, RunState)
    local _, ctx = ThreadGenerator.select(player, RunState, Threads)

    return {
        selected   = (RunState.story and RunState.story.thread_id) or '(none)',
        active     = camp.active_thread and camp.active_thread.id or nil,
        pool       = snap,
        master     = ctx and ctx.master and ctx.master.id or nil,
    }
end

local real_print = print
local function p(...) real_print(...) end

-- ===========================================================================
-- R1 — the three-variant table, seeds 1..20
-- ===========================================================================

p('════════════════════════════════════════════════════════════════════')
p('R1 — SELECTION BY STAGE (seeds 1..20)')
p('════════════════════════════════════════════════════════════════════')
p(('%-5s | %-16s | %-16s | %-16s'):format('seed', 'direct', '+generateMap', '+placeStory'))

local divergences = {}
for seed = 1, 20 do
    local a = run_variant(seed, 0)
    local b = run_variant(seed, 1)
    local c = run_variant(seed, 2)

    p(('%-5d | %-16s | %-16s | %-16s')
        :format(seed, a.selected, b.selected, c.selected))

    if not (a.selected == b.selected and b.selected == c.selected) then
        divergences[#divergences + 1] = { seed = seed, a = a, b = b, c = c }
    end
end

p('')
p(('Diverging seeds: %d / 20'):format(#divergences))
for _, d in ipairs(divergences) do
    p(('  seed %-3d direct=%s  +generateMap=%s  +placeStory=%s')
        :format(d.seed, d.a.selected, d.b.selected, d.c.selected))
end
p('')

-- ===========================================================================
-- R2 — hypothesis test on the first divergence
-- ===========================================================================

p('════════════════════════════════════════════════════════════════════')
p('R2 — HYPOTHESIS TEST')
p('════════════════════════════════════════════════════════════════════')

if #divergences == 0 then
    p('No divergence in seeds 1..20 — nothing to diff.')
else
    local d = divergences[1]
    p(('First diverging seed: %d'):format(d.seed))
    p('')
    p(('  direct         : selected=%s  active_thread_after=%s  pool=[%s]')
        :format(d.a.selected, tostring(d.a.active), pool_string(d.a.pool)))
    p(('  +generateMap   : selected=%s  active_thread_after=%s  pool=[%s]')
        :format(d.b.selected, tostring(d.b.active), pool_string(d.b.pool)))
    p(('  +placeStory    : selected=%s  active_thread_after=%s  pool=[%s]')
        :format(d.c.selected, tostring(d.c.active), pool_string(d.c.pool)))
    p('')

    -- Is the pool identical between direct and +generateMap?
    local same_pool = pool_string(d.a.pool) == pool_string(d.b.pool)
    p(('  pool identical (direct vs +generateMap): %s'):format(tostring(same_pool)))

    -- Was active_thread already set before the final select()?
    -- That is what _place_story does: it calls select() which pins the thread.
    local pinned_b = d.b.active ~= nil
    local pinned_c = d.c.active ~= nil
    p(('  active_thread already set before select: +generateMap=%s  +placeStory=%s')
        :format(tostring(pinned_b), tostring(pinned_c)))
    p('')
    p('  Interpretation:')
    if pinned_c and not pinned_b then
        p('    +placeStory calls select() internally (which pins active_thread),')
        p('    so the follow-up select() is a FORCED continuation, not a fresh')
        p('    weighted pick. The divergence is a measurement artefact of asking')
        p('    "what does select pick" after placement already picked once.')
    elseif same_pool then
        p('    Pools are identical but outcomes differ => weighted_pick / RNG.')
    else
        p('    Pool differs => something mutated camp state between variants.')
    end
end
p('')

-- ===========================================================================
-- R3 — the "bond_arc 100/100" claim, same code path as the D3-measure sweep
-- ===========================================================================

p('════════════════════════════════════════════════════════════════════')
p('R3 — UNPINNED SWEEP REPRODUCTION (seeds 1..100)')
p('════════════════════════════════════════════════════════════════════')

local counts, bond0_selected, bond0_total = {}, 0, 0
local master_selected = 0
local rows = {}

for seed = 1, 100 do
    local player = make_player(seed)
    RunState:reset(player, seed)
    RunState.story   = { thread_id = 'master_trial', flags = {} }
    RunState.unlocks = {}

    local lm = make_levelmap(player, seed)
    math.randomseed(seed)
    lm:_generateMap()
    lm:_place_story()

    -- Read AFTER placement, exactly as the sweep did.
    local selected = (RunState.story and RunState.story.thread_id) or '(none)'

    -- Independently: what would a FRESH select pick, and what is bond_arc's
    -- weight at that moment? Use a fresh player, same seed.
    local p2 = make_player(seed)
    RunState:reset(p2, seed)
    local snap = pool_snapshot(p2, RunState)
    local bond_w = nil
    for _, e in ipairs(snap) do if e.id == 'bond_arc' then bond_w = e.weight end end
    local _, _ = ThreadGenerator.select(p2, RunState, Threads)
    local fresh_pick = (RunState.story and RunState.story.thread_id) or '(none)'

    counts[selected] = (counts[selected] or 0) + 1
    if selected == 'master_trial' then master_selected = master_selected + 1 end
    if selected == 'bond_arc' and bond_w == 0 then
        bond0_selected = bond0_selected + 1
    end
    if bond_w == 0 then bond0_total = bond0_total + 1 end

    rows[#rows + 1] = { seed = seed, after = selected, fresh = fresh_pick,
                        bond_w = bond_w }
end

p(('%-5s | %-18s | %-18s | %s'):format('seed', 'after _place_story', 'fresh select', 'bond_arc weight'))
for _, r in ipairs(rows) do
    p(('%-5d | %-18s | %-18s | %s')
        :format(r.seed, r.after, r.fresh, tostring(r.bond_w)))
end
p('')

local ids = {}
for id in pairs(counts) do ids[#ids + 1] = id end
table.sort(ids)
p('Selection distribution as measured by the sweep (after _place_story):')
for _, id in ipairs(ids) do p(('  %-18s %d'):format(id, counts[id])) end
p('')
p(('bond_arc with weight 0: %d / 100 seeds'):format(bond0_total))
p(('bond_arc selected while weight 0: %d / 100'):format(bond0_selected))
p(('master_trial selected (sweep path): %d / 100'):format(master_selected))
p('')

-- ===========================================================================
-- R4 — verdict
-- ===========================================================================

local divergence_point = 'none'
if #divergences > 0 then
    local d = divergences[1]
    if d.a.selected == d.b.selected then
        divergence_point = '+placeStory'
    elseif d.a.selected == d.c.selected then
        divergence_point = '+generateMap'
    else
        divergence_point = '+generateMap'
    end
end

p('════════════════════════════════════════════════')
p('DETERMINISM DIAGNOSIS')
p('════════════════════════════════════════════════')
p('Divergence point:  ' .. divergence_point)
if divergence_point == '+placeStory' then
    p('Divergence cause:  measure_placement reporting bug — _place_story runs')
    p('                   select() internally and pins active_thread, so a')
    p('                   second select() is a forced continuation')
elseif divergence_point == 'none' then
    p('Divergence cause:  none observed in seeds 1..20')
else
    p('Divergence cause:  selected but undetermined — see R2')
end
p(('bond_arc weight-0 selected: %d/%d'):format(bond0_selected, 100))
p(('master_trial selected in sweep: %d/100'):format(master_selected))
p('')

os.exit(0)
