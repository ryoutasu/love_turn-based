-- tests/measure_placement_tiers.lua
--
-- MEASUREMENT SCRIPT, not a test. Always exits 0.
--
--   lua tests/measure_placement_tiers.lua
--
-- Decision support for `is_usable` in src/story/story_placement.lua.
--
-- Baseline fixture is the D3-measure pinned sweep (active_thread=master_trial,
-- seeds 1..100). For every failure we capture the failing scene's parent nodes
-- and their FULL map neighbourhood, then ask: at each candidate eligibility
-- tier, would a free slot have existed?
--
-- Tier semantics (which node TYPES a story scene may occupy):
--   T0 (current)  event, wild
--   T1            + trainer
--   T2            + shop
--   T3            + rest
--   T4            anything except 'end' and the map start
--
-- NOTE: this measures ELIGIBILITY COUNTS, not a re-run of placement under a
-- changed is_usable. A tier can only save a seed if the failing step had at
-- least one free, in-reach neighbour of an allowed type; the true placement
-- result under a looser tier could differ further down the graph. The counts
-- are a lower bound on what each tier buys.
--
-- Failure attribution: StoryPlacement prints
--   '[story] placement failed: scene %s from parent(s) %s'
-- which is captured by intercepting print() during _place_story.

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
        -- Warm-up required: an unscrambled Park-Miller seed yields a ~1e-5 first
        -- draw (see AGENTS.md "Determinism").
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
local MERGE_REACH = 4   -- mirrors story_placement.MERGE_REACH

-- ---------------------------------------------------------------------------
-- Tiers
-- ---------------------------------------------------------------------------

local TIERS = {
    { id = 'T0', allow = { event = true, wild = true }, label = 'event, wild (current)' },
    { id = 'T1', allow = { event = true, wild = true, trainer = true }, label = '+ trainer' },
    { id = 'T2', allow = { event = true, wild = true, trainer = true, shop = true }, label = '+ shop' },
    { id = 'T3', allow = { event = true, wild = true, trainer = true, shop = true, rest = true }, label = '+ rest' },
    { id = 'T4', allow = 'all', label = 'anything except end/start' },
}

local function allowed(node, tier)
    if node.type == 'end' then return false end
    if tier.allow == 'all' then return true end
    return tier.allow[node.type] == true
end

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

local function find_by_id(lm, id)
    for _, n in ipairs(lm.nodes) do if n.story_id == id then return n end end
    return nil
end

local function node_types(lm)
    local counts = {}
    for _, n in ipairs(lm.nodes) do counts[n.type] = (counts[n.type] or 0) + 1 end
    return counts
end

-- Full map neighbourhood of a node: the 1-step neighbours of its point.
local function neighbourhood(lm, node)
    local out = {}
    if not node or not node.point or not node.point.neighbors then return out end
    for _, np in ipairs(node.point.neighbors) do
        for _, n in ipairs(lm.nodes) do
            if n.point == np then out[#out + 1] = n end
        end
    end
    return out
end

-- BFS distance from a node over the map graph.
local function distances_from(lm, from)
    local dist, q, head = { [from] = 0 }, { from }, 1
    while head <= #q do
        local cur = q[head]; head = head + 1
        for _, nb in ipairs(neighbourhood(lm, cur)) do
            if dist[nb] == nil then dist[nb] = dist[cur] + 1; q[#q + 1] = nb end
        end
    end
    return dist
end

-- ---------------------------------------------------------------------------
-- Sweep: pinned master_trial, same fixture as D3-measure
-- ---------------------------------------------------------------------------

local results = {}

for seed = SEED_FROM, SEED_TO do
    local player = make_player(seed)
    local camp   = player.meta_story
    camp.active_thread = { id = 'master_trial', params = {}, started_run = 0 }

    RunState:reset(player, seed)
    RunState.story   = { thread_id = 'master_trial', flags = {} }
    RunState.unlocks = {}

    local lm = make_levelmap(player, seed)
    math.randomseed(seed)
    lm:_generateMap()

    local types = node_types(lm)          -- baseline type distribution

    captured = {}
    capturing = true
    lm:_place_story()
    capturing = false
    local diagnostics = captured

    local placed = {}
    for _, n in ipairs(lm.nodes) do
        if n.story_scene then placed[#placed + 1] = n end
    end

    local r = {
        seed        = seed,
        success     = lm.story ~= nil,
        placed      = placed,
        types       = types,
        lm          = lm,
    }

    if not r.success then
        -- Parse the failing scene + parents from the diagnostic line.
        for _, line in ipairs(diagnostics) do
            local scene, parents = line:match('placement failed: scene (%a+) from parent%s?%s*(.*)')
            if scene then r.fail_scene = scene; r.fail_parents = parents end
        end

        -- Parent nodes are the placed scenes the graph says are parents.
        -- We cannot read the graph's parent map from placement, so infer:
        -- the failing scene's parents are the placed nodes that are adjacent
        -- to where the failing scene would have gone. Simpler and exact for
        -- master_trial: parse the parent list from the diagnostic string.
        r.parent_nodes = {}
        if r.fail_parents then
            for pid in r.fail_parents:gmatch('([%w_]+)') do
                local pn = find_by_id(lm, pid)
                if pn then r.parent_nodes[#r.parent_nodes + 1] = { id = pid, node = pn } end
            end
        end

        -- For each tier: would a free in-reach neighbour of an allowed type exist?
        r.tier_free = {}
        r.tier_candidates = {}
        for _, tier in ipairs(TIERS) do
            local free = 0
            local seen = {}
            for _, p in ipairs(r.parent_nodes) do
                local dist = distances_from(lm, p.node)
                local limit = #r.parent_nodes == 1 and 1 or MERGE_REACH
                for _, n in ipairs(lm.nodes) do
                    local d = dist[n]
                    if d and d >= 1 and d <= limit
                        and n ~= lm.currentNode
                        and not n.story_scene
                        and not seen[n]
                        and allowed(n, tier) then
                        seen[n] = true
                        free = free + 1
                    end
                end
            end
            r.tier_free[tier.id] = free
        end

        -- Per-tier detail for the first few failures.
        r.neighbour_detail = {}
        for _, p in ipairs(r.parent_nodes) do
            local rows = {}
            for _, n in ipairs(neighbourhood(lm, p.node)) do
                rows[#rows + 1] = {
                    index  = n.id,
                    type   = n.type,
                    story  = n.story_id,
                    x      = n.x,
                    y      = n.y,
                }
            end
            r.neighbour_detail[#r.neighbour_detail + 1] = { parent = p.id, rows = rows }
        end
    end

    results[#results + 1] = r
end

local total      = #results
local failures   = {}
for _, r in ipairs(results) do if not r.success then failures[#failures + 1] = r end end
local n_fail     = #failures

-- ===========================================================================
-- R2 — tier aggregate
-- ===========================================================================

real_print('════════════════════════════════════════════════')
real_print('TIER BREAKDOWN — pinned master_trial, seeds 1..100')
real_print('════════════════════════════════════════════════')

-- A seed is "saved" at tier T if the failing step had a free allowed slot.
local function saved_by(r, tier_id)
    return (r.tier_free and (r.tier_free[tier_id] or 0) > 0) or false
end

real_print(('%-5s  %-9s  %-13s  %s'):format('Tier', 'Failures', 'Saved vs T0', 'Seeds that would still fail'))
for _, tier in ipairs(TIERS) do
    local still, saved = {}, {}
    for _, r in ipairs(failures) do
        if saved_by(r, tier.id) then
            saved[#saved + 1] = r.seed
        else
            still[#still + 1] = r.seed
        end
    end
    local saved_vs_t0 = '—'
    if tier.id ~= 'T0' then
        local base_saved = 0
        for _, r in ipairs(failures) do if saved_by(r, 'T0') then base_saved = base_saved + 1 end end
        saved_vs_t0 = ('+%d'):format(#saved - base_saved)
    end
    real_print(('%-5s  %-9d  %-13s  %d seeds: %s')
        :format(tier.id, #still, saved_vs_t0, #still,
            #still > 0 and table.concat(still, ',') or '—'))
end
real_print('')

-- ===========================================================================
-- R3 — overwrite cost per transition
-- ===========================================================================

real_print('════════════════════════════════════════════════')
real_print('OVERWRITE COST PER TRANSITION')
real_print('════════════════════════════════════════════════')

-- For each transition, count the nodes that would become overwritable on the
-- FAILING seeds' maps: nodes of the newly-allowed type(s) that are free and
-- in-reach for the failing step. That is the overwrite cost of saving the seed.
for i = 1, #TIERS - 1 do
    local from_t, to_t = TIERS[i], TIERS[i + 1]
    local added = {}
    for _, t in ipairs({ 'event', 'wild', 'trainer', 'shop', 'rest' }) do
        if allowed({ type = t }, to_t) and not allowed({ type = t }, from_t) then
            added[#added + 1] = t
        end
    end

    local newly_saved, overwrites, per_type = 0, 0, {}
    for _, r in ipairs(failures) do
        if saved_by(r, to_t.id) and not saved_by(r, from_t.id) then
            newly_saved = newly_saved + 1
            -- Count the newly-eligible free in-reach nodes for this step.
            local count = 0
            for _, p in ipairs(r.parent_nodes) do
                local dist = distances_from(r.lm, p.node)
                local limit = #r.parent_nodes == 1 and 1 or MERGE_REACH
                for _, n in ipairs(r.lm.nodes) do
                    local d = dist[n]
                    if d and d >= 1 and d <= limit
                        and n ~= r.lm.currentNode
                        and not n.story_scene
                        and allowed(n, to_t) and not allowed(n, from_t) then
                        count = count + 1
                        per_type[n.type] = (per_type[n.type] or 0) + 1
                    end
                end
            end
            overwrites = overwrites + count
        end
    end

    local parts = {}
    for _, t in ipairs(added) do parts[#parts + 1] = ('%s=%d'):format(t, per_type[t] or 0) end
    local ratio = newly_saved > 0
        and ('%.2f overwrites per seed saved'):format(overwrites / newly_saved)
        or 'n/a (saves no seeds)'

    real_print(('%s -> %s  (adds: %s)'):format(from_t.id, to_t.id, table.concat(added, ', ')))
    real_print(('  Seeds newly saved:     %d'):format(newly_saved))
    real_print(('  Total new overwrites:  %d'):format(overwrites))
    real_print(('  Breakdown by type:     %s'):format(table.concat(parts, ', ')))
    real_print(('  Ratio:                 %s'):format(ratio))
    real_print('')
end

-- ===========================================================================
-- R4 — per-tier narrative impact
-- ===========================================================================

real_print('════════════════════════════════════════════════')
real_print('PER-TIER NARRATIVE IMPACT')
real_print('════════════════════════════════════════════════')

for i = 1, #TIERS - 1 do
    local from_t, to_t = TIERS[i], TIERS[i + 1]
    local added, avg = {}, {}
    for _, t in ipairs({ 'trainer', 'shop', 'rest' }) do
        if allowed({ type = t }, to_t) and not allowed({ type = t }, from_t) then
            added[#added + 1] = t
            local sum, max = 0, 0
            for _, r in ipairs(results) do
                local c = r.types[t] or 0
                sum = sum + c
                if c > max then max = c end
            end
            avg[t] = { mean = sum / total, max = max }
        end
    end
    real_print(('%s -> %s introduces story placement on: %s')
        :format(from_t.id, to_t.id, table.concat(added, ', ')))
    for _, t in ipairs(added) do
        real_print(('  %-8s avg/map = %.2f   max/map = %d'):format(t, avg[t].mean, avg[t].max))
    end
    real_print('')
end

real_print('Tradeoffs:')
real_print('  shop    — overwritten: player loses an upgrade opportunity that run.')
real_print('  rest    — overwritten: player loses a heal. Rest is the only mid-run')
real_print('            recovery besides camp_once, so this is the most load-bearing.')
real_print('  trainer — overwritten: player loses XP + gold from a trainer fight.')
real_print('')

-- ===========================================================================
-- Failure detail (first 3)
-- ===========================================================================

real_print('════════════════════════════════════════════════')
real_print('FAILURE DETAIL (first 3)')
real_print('════════════════════════════════════════════════')

for i = 1, math.min(3, #failures) do
    local r = failures[i]
    real_print(('─── seed %d ───'):format(r.seed))
    real_print(('  failing scene: %s   parents: %s')
        :format(tostring(r.fail_scene), tostring(r.fail_parents)))
    for _, det in ipairs(r.neighbour_detail) do
        real_print(('  parent %s neighbourhood:'):format(det.parent))
        for _, row in ipairs(det.rows) do
            real_print(('    idx=%-3s type=%-8s story=%-10s at (%.0f,%.0f)')
                :format(tostring(row.index), row.type, tostring(row.story), row.x, row.y))
        end
    end
    local parts = {}
    for _, tier in ipairs(TIERS) do
        parts[#parts + 1] = ('%s=%d'):format(tier.id, r.tier_free[tier.id] or 0)
    end
    real_print(('  free in-reach slots by tier: %s'):format(table.concat(parts, '  ')))
    real_print('')
end

-- ===========================================================================
-- R5 — recommendation
-- ===========================================================================

local function fail_rate(tier_id)
    local still = 0
    for _, r in ipairs(failures) do
        if not saved_by(r, tier_id) then still = still + 1 end
    end
    return still, 100 * still / total
end

local function cheapest_under(threshold)
    for _, tier in ipairs(TIERS) do
        local n, pct = fail_rate(tier.id)
        if pct < threshold then return tier.id, n, pct end
    end
    return 'none', 0, 0
end

real_print('════════════════════════════════════════════════')
real_print('TIER RECOMMENDATION')
real_print('════════════════════════════════════════════════')

local t15, n15, p15 = cheapest_under(15)
local t5,  n5,  p5  = cheapest_under(5)
local t2,  n2,  p2  = cheapest_under(2)
real_print(('Cheapest tier achieving <15%% failure rate:  %s  (%d fail, %.1f%%)'):format(t15, n15, p15))
real_print(('Cheapest tier achieving <5%% failure rate:   %s  (%d fail, %.1f%%)'):format(t5, n5, p5))
real_print(('Cheapest tier achieving <2%% failure rate:   %s  (%d fail, %.1f%%)'):format(t2, n2, p2))
real_print('')
real_print('Marginal summary per tier (one line each):')

for _, tier in ipairs(TIERS) do
    if tier.id ~= 'T0' then
        local n, pct = fail_rate(tier.id)
        local bits = {}
        local prev = TIERS[1]
        local csum = {}
        for _, t in ipairs({ 'trainer', 'shop', 'rest' }) do
            if allowed({ type = t }, tier) then
                local sum = 0
                for _, r in ipairs(results) do sum = sum + (r.types[t] or 0) end
                csum[#csum + 1] = ('%.2f %s'):format(sum / total, t)
            end
        end
        real_print(('  %s: fail=%.1f%% (was 22.0%%), map avg: %s')
            :format(tier.id, pct, table.concat(csum, ' + ')))
    end
end

real_print('')
real_print('Data note: counts are ELIGIBILITY (free, in-reach slots of an allowed')
real_print('type at the failing step), not a re-run of placement under a looser')
real_print('is_usable. They are a lower bound on what each tier buys.')
real_print('')
os.exit(0)
