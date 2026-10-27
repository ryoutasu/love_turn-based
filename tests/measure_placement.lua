-- tests/measure_placement.lua
--
-- MEASUREMENT SCRIPT, NOT A TEST. Always exits 0. No assertions: every check
-- here is data collection.
--
--   lua tests/measure_placement.lua
--
-- Sweeps seeds 1..100 twice:
--   sweep A — master_trial pinned via camp.active_thread (same graph every seed)
--   sweep B — no pin (ThreadGenerator picks naturally; real play experience)
--
-- Failure detail is recovered by temporarily intercepting `print`: placement
-- reports the failing scene through print('[story] placement failed: ...').
-- The intercepted lines are captured per seed and re-emitted only for the
-- first few failures, so the aggregate output stays readable.

local here = (arg and arg[0] or ''):match('^(.*)[/\\]') or '.'
local root = here .. '/..'
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path

-- ---------------------------------------------------------------------------
-- LÖVE stubs (same shape as tests/smoke_story_placement.lua)
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
        newImage  = stubImage,
        newFont   = stubFont,
        newQuad   = function() return { getViewport = function() return 0, 0, 1, 1 end } end,
        newText   = function() return { setf = function() end } end,
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
        random = function(a, b) if a and b then return a end return 0 end,
        -- Park-Miller with warm-up. The raw first draw is ~seed*7.8e-6, a heavy
        -- bias toward zero that breaks any single-draw weighted pick (it made
        -- every seed appear to select the first non-zero thread). Real LÖVE
        -- RNGs scramble the seed; the warm-up models that.
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

FadeInState  = { __name = 'FadeInState' }
FadeOutState = { __name = 'FadeOutState' }
TownState    = { __name = 'TownState' }
BattleState  = { __name = 'BattleState' }
RestState    = { __name = 'RestState' }
ShopState    = { __name = 'ShopState' }
EventState   = { __name = 'EventState' }

Gamestate = {
    push    = function() end,
    pop     = function() end,
    switch  = function() end,
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
    save   = function() return true end,
    load   = function() return nil end,
    exists = function() return false end,
}

local Levelmap        = require 'src.states.levelmap2'
local PlayerMetaStory = require 'src.player_meta_story'
local MasterGenerator = require 'data.story.generators.master_generator'

local SEED_FROM, SEED_TO = 1, 100

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

local function make_levelmap(player, seed)
    local lm = setmetatable({}, { __index = Levelmap })
    lm.player = player
    lm.nodes  = {}
    lm.pathes = {}
    lm.active = true
    lm.seed   = seed
    return lm
end

-- ADJ per AGENTS.md: generator:isNeighbors is the authoritative adjacency.
local function ADJ(lm, a, b)
    if not a or not b or a == b or not a.point or not b.point then return false end
    return lm.generator:isNeighbors(a.point, b.point) and true or false
end

local function build_adjacency(lm)
    local adj = {}
    for _, a in ipairs(lm.nodes) do
        adj[a] = {}
        for _, b in ipairs(lm.nodes) do
            if a ~= b and ADJ(lm, a, b) then adj[a][#adj[a] + 1] = b end
        end
    end
    return adj
end

local function bfs_distances(from, adj)
    if not from then return {} end
    local dist = { [from] = 0 }
    local q, head = { from }, 1
    while head <= #q do
        local cur = q[head]; head = head + 1
        for _, nxt in ipairs(adj[cur] or {}) do
            if dist[nxt] == nil then
                dist[nxt] = dist[cur] + 1
                q[#q + 1] = nxt
            end
        end
    end
    return dist
end

local function find_by_id(lm, id)
    for _, n in ipairs(lm.nodes) do
        if n.story_id == id then return n end
    end
    return nil
end

-- Temporarily capture print() output so per-seed failure diagnostics can be
-- attributed without polluting the sweep output.
local captured = {}
local real_print = print
local capturing = false

print = function(...)
    if capturing then
        local parts = {}
        for i = 1, select('#', ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        captured[#captured + 1] = table.concat(parts, ' ')
        return
    end
    real_print(...)
end

local function capture_begin()
    captured = {}
    capturing = true
end

local function capture_end()
    capturing = false
    return captured
end

-- ---------------------------------------------------------------------------
-- One seed
-- ---------------------------------------------------------------------------

local function run_seed(seed, pin)
    local player = make_player(seed)
    local camp   = player.meta_story

    if pin then
        camp.active_thread = { id = 'master_trial', params = {}, started_run = 0 }
    end

    RunState:reset(player, seed)
    RunState.story   = { thread_id = 'master_trial', flags = {} }
    RunState.unlocks = {}

    local lm = make_levelmap(player, seed)
    math.randomseed(seed)
    lm:_generateMap()

    capture_begin()
    lm:_place_story()
    local diagnostics = capture_end()

    -- Attribute the thread from the PLACED result, not from RunState.story.
    -- RunState.story is shared state: _place_story calls ThreadGenerator.select()
    -- internally, which pins camp.active_thread and bumps camp.total_runs — so
    -- reading RunState.story afterwards reports the thread that placement chose,
    -- while a naive "what would select pick now" second call reports a forced
    -- continuation. lm.story.thread is the authoritative record of what ran.
    local thread_id = (lm.story and lm.story.thread and lm.story.thread.id)
        or (RunState.story and RunState.story.thread_id)

    local result = {
        seed        = seed,
        pin         = pin,
        thread_id   = thread_id,
        success     = lm.story ~= nil,
        diagnostic  = diagnostics,
        lm          = lm,
        placed_ids  = {},
    }

    -- Everything below is measurement, never an assertion.
    local adj  = build_adjacency(lm)
    local start = find_by_id(lm, 'start')
    local dist = bfs_distances(start, adj)
    local placed = {}

    for _, node in ipairs(lm.nodes) do
        if node.story_scene then
            placed[#placed + 1] = node
            result.placed_ids[#result.placed_ids + 1] = tostring(node.story_id)
        end
    end
    result.placed_count = #placed

    local shortcut = find_by_id(lm, 'shortcut')
    local scenic   = find_by_id(lm, 'scenic')
    local cross    = find_by_id(lm, 'crossroads')

    result.d_shortcut = shortcut and dist[shortcut] or nil
    result.d_scenic   = scenic   and dist[scenic]   or nil
    result.d_cross    = cross    and dist[cross]    or nil

    result.bypass = (shortcut and start) and ADJ(lm, start, shortcut) or false
    result.siblings = (cross and shortcut and scenic)
        and (ADJ(lm, cross, shortcut) and ADJ(lm, cross, scenic)) or false
    result.direction_ok = (result.d_shortcut and result.d_scenic)
        and (result.d_shortcut <= result.d_scenic) or nil

    result.adj_of = adj
    result.dist   = dist
    return result
end

-- ---------------------------------------------------------------------------
-- Aggregation helpers
-- ---------------------------------------------------------------------------

local function median(list)
    if #list == 0 then return nil end
    local s = {}
    for i, v in ipairs(list) do s[i] = v end
    table.sort(s)
    local n = #s
    if n % 2 == 1 then return s[(n + 1) / 2] end
    return (s[n // 2] + s[n // 2 + 1]) / 2
end

local function stat3(list)
    if #list == 0 then return 'n/a' end
    local s = {}
    for i, v in ipairs(list) do s[i] = v end
    table.sort(s)
    return string.format('%d / %s / %d', s[1], tostring(median(s)), s[#s])
end

local function tally(result)
    local ok = 0
    for _, r in ipairs(result) do if r.success then ok = ok + 1 end end
    return ok, #result - ok
end

local function pct(n, total)
    if total == 0 then return 'n/a' end
    return string.format('%.1f%%', 100 * n / total)
end

local function count_if(list, pred)
    local n = 0
    for _, r in ipairs(list) do if pred(r) then n = n + 1 end end
    return n
end

local function scene_count_distribution(successful)
    local dist = {}
    for _, r in ipairs(successful) do
        dist[r.placed_count] = (dist[r.placed_count] or 0) + 1
    end
    local keys = {}
    for k in pairs(dist) do keys[#keys + 1] = k end
    table.sort(keys)
    return dist, keys
end

-- ---------------------------------------------------------------------------
-- Sweep A: pinned master_trial
-- ---------------------------------------------------------------------------

local pinned = {}
for seed = SEED_FROM, SEED_TO do pinned[#pinned + 1] = run_seed(seed, true) end

local okA, failA = tally(pinned)
local goodA = {}
for _, r in ipairs(pinned) do if r.success then goodA[#goodA + 1] = r end end

local d_s, d_c = {}, {}
for _, r in ipairs(goodA) do
    if r.d_shortcut then d_s[#d_s + 1] = r.d_shortcut end
    if r.d_scenic   then d_c[#d_c + 1] = r.d_scenic   end
end

local sc_dist, sc_keys = scene_count_distribution(goodA)

real_print('════════════════════════════════════════════════')
real_print('SEED SWEEP — master_trial, seeds ' .. SEED_FROM .. '..' .. SEED_TO)
real_print('════════════════════════════════════════════════')
real_print('Total seeds:            ' .. #pinned)
real_print(('Successful placements:  %d  (%s)'):format(okA, pct(okA, #pinned)))
real_print(('Failed placements:      %d  (%s)'):format(failA, pct(failA, #pinned)))
real_print('')
real_print(('When successful (%d seeds):'):format(okA))
real_print('  Scene count distribution:')
for _, k in ipairs(sc_keys) do
    real_print(('    %d scenes placed: %d'):format(k, sc_dist[k]))
end
real_print('  Shortcut distance from start:')
real_print('    min / median / max: ' .. stat3(d_s))
real_print('  Scenic distance from start:')
real_print('    min / median / max: ' .. stat3(d_c))
real_print(('  Shortcut bypass (adjacent to start): %d / %d (%s)')
    :format(count_if(goodA, function(r) return r.bypass end), okA,
            pct(count_if(goodA, function(r) return r.bypass end), okA)))
real_print(('  Shortcut & scenic siblings:          %d / %d (%s)')
    :format(count_if(goodA, function(r) return r.siblings end), okA,
            pct(count_if(goodA, function(r) return r.siblings end), okA)))
real_print(('  Shortcut <= scenic (narrative holds): %d / %d (%s)')
    :format(count_if(goodA, function(r) return r.direction_ok == true end), okA,
            pct(count_if(goodA, function(r) return r.direction_ok == true end), okA)))
real_print(('  Shortcut > scenic (INVERTED):         %d / %d (%s)')
    :format(count_if(goodA, function(r) return r.direction_ok == false end), okA,
            pct(count_if(goodA, function(r) return r.direction_ok == false end), okA)))
real_print('')

-- ---------------------------------------------------------------------------
-- Failure detail (first 5)
-- ---------------------------------------------------------------------------

local shown = 0
for _, r in ipairs(pinned) do
    if not r.success and shown < 5 then
        shown = shown + 1
        real_print('─── FAILURE — seed ' .. r.seed .. ' ───')
        real_print('scenes placed before failure: '
            .. (#r.placed_ids > 0 and table.concat(r.placed_ids, ', ') or '(none)'))

        local last_id = r.placed_ids[#r.placed_ids]
        local last_node = last_id and find_by_id(r.lm, last_id) or nil
        if last_node then
            real_print(('last placed scene: %s at (%.0f,%.0f)')
                :format(last_id, last_node.x or -1, last_node.y or -1))
            local nbrs = {}
            for _, n in ipairs(r.adj_of[last_node] or {}) do
                nbrs[#nbrs + 1] = tostring(n.story_id or ('(' .. tostring(n.type) .. ')'))
            end
            real_print('last placed node adjacency: '
                .. (#nbrs > 0 and table.concat(nbrs, ', ') or '(isolated)'))
        else
            real_print('last placed scene: (none)')
            real_print('last placed node adjacency: (n/a)')
        end

        if #r.diagnostic > 0 then
            for _, line in ipairs(r.diagnostic) do
                real_print('placement said: ' .. line)
            end
        else
            real_print('graph scene that failed: NOT INFERABLE — '
                .. 'StoryPlacement returned nil without a diagnostic line')
        end
        real_print('')
    end
end

local total_failures = failA
real_print(('(%d failure(s) total; first %d shown above)'):format(total_failures, shown))

-- Classify every pinned failure: a Lua error (caught by pcall and reported with
-- a source line) is a different defect class from a graceful nil return.
local cause_hist, n_crash, n_graceful = {}, 0, 0
for _, r in ipairs(pinned) do
    if not r.success then
        local key    = 'unknown'
        local is_err = false
        for _, line in ipairs(r.diagnostic) do
            if line:find('bad argument') or line:find('attempt to') then
                is_err = true
            end
            local scene = line:match('placement failed: scene (%a+)')
            if scene then key = scene end
        end
        if is_err then
            key      = 'LUA ERROR (not graceful)'
            n_crash  = n_crash + 1
        else
            n_graceful = n_graceful + 1
        end
        cause_hist[key] = (cause_hist[key] or 0) + 1
    end
end
local cause_keys = {}
for k in pairs(cause_hist) do cause_keys[#cause_keys + 1] = k end
table.sort(cause_keys)
real_print('')
real_print('FAILURE BREAKDOWN by cause:')
for _, k in ipairs(cause_keys) do
    real_print(('  %-32s %d'):format(k, cause_hist[k]))
end
real_print(('  -> Lua error: %d   graceful nil: %d'):format(n_crash, n_graceful))
real_print('')

-- ---------------------------------------------------------------------------
-- Sweep B: no pin — natural thread selection
-- ---------------------------------------------------------------------------

local unpinned = {}
for seed = SEED_FROM, SEED_TO do unpinned[#unpinned + 1] = run_seed(seed, false) end

local by_thread = {}
for _, r in ipairs(unpinned) do
    local id = r.thread_id or '(none)'
    by_thread[id] = by_thread[id] or { total = 0, ok = 0, ok_seeds = {} }
    by_thread[id].total = by_thread[id].total + 1
    if r.success then
        by_thread[id].ok = by_thread[id].ok + 1
        by_thread[id].ok_seeds[#by_thread[id].ok_seeds + 1] = r
    end
end

local thread_ids = {}
for id in pairs(by_thread) do thread_ids[#thread_ids + 1] = id end
table.sort(thread_ids)

local _, failB = tally(unpinned)

real_print('════════════════════════════════════════════════')
real_print('UNPINNED SWEEP — natural thread selection, seeds '
    .. SEED_FROM .. '..' .. SEED_TO)
real_print('════════════════════════════════════════════════')
real_print('Total seeds:            ' .. #unpinned)
real_print(('Successful placements:  %d  (%s)'):format(#unpinned - failB, pct(#unpinned - failB, #unpinned)))
real_print(('Failed placements:      %d  (%s)'):format(failB, pct(failB, #unpinned)))
real_print('')
real_print('Thread selection distribution:')
for _, id in ipairs(thread_ids) do
    real_print(('  %-16s %d  (%s)'):format(id, by_thread[id].total,
        pct(by_thread[id].total, #unpinned)))
end
real_print('')
real_print('Success rate per thread:')
for _, id in ipairs(thread_ids) do
    local e = by_thread[id]
    real_print(('  %-16s %d / %d  (%s)'):format(id, e.ok, e.total, pct(e.ok, e.total)))
end
real_print('')

local mt = by_thread['master_trial']
if mt and #mt.ok_seeds > 0 then
    local ds, dc = {}, {}
    for _, r in ipairs(mt.ok_seeds) do
        if r.d_shortcut then ds[#ds + 1] = r.d_shortcut end
        if r.d_scenic   then dc[#dc + 1] = r.d_scenic   end
    end
    local sd, sk = scene_count_distribution(mt.ok_seeds)
    real_print(('master_trial detail (unpinned, %d successful):'):format(#mt.ok_seeds))
    real_print('  Scene count distribution:')
    for _, k in ipairs(sk) do
        real_print(('    %d scenes placed: %d'):format(k, sd[k]))
    end
    real_print('  Shortcut distance from start: min / median / max: ' .. stat3(ds))
    real_print('  Scenic distance from start:   min / median / max: ' .. stat3(dc))
    real_print(('  Shortcut bypass: %d / %d'):format(
        count_if(mt.ok_seeds, function(r) return r.bypass end), #mt.ok_seeds))
    real_print(('  Siblings:        %d / %d'):format(
        count_if(mt.ok_seeds, function(r) return r.siblings end), #mt.ok_seeds))
    real_print(('  Shortcut <= scenic: %d / %d'):format(
        count_if(mt.ok_seeds, function(r) return r.direction_ok == true end), #mt.ok_seeds))
else
    real_print('master_trial detail: no successful unpinned master_trial run in this range')
end

real_print('')
real_print('(measurement complete)')

-- ---------------------------------------------------------------------------
-- Thread-selection diagnostic (seed 1, unpinned). Observation only.
--
-- master_trial was selected 0/100 in the unpinned sweep. This dumps the inputs
-- ThreadGenerator.select actually sees, plus each thread's pool membership and
-- weight, so the reason can be read off directly. No fix is applied here.
-- ---------------------------------------------------------------------------

local ThreadGenerator = require 'src.story.thread_generator'
local Threads         = require 'data.story.threads'

real_print('')
real_print('════════════════════════════════════════════════')
real_print('THREAD SELECTION DIAGNOSTIC — seed 1, unpinned')
real_print('════════════════════════════════════════════════')

do
    local seed   = 1
    local player = make_player(seed)
    local camp   = player.meta_story

    RunState:reset(player, seed)
    RunState.story   = { thread_id = 'master_trial', flags = {} }
    RunState.unlocks = {}

    real_print(('camp.phase               = %s'):format(tostring(camp.phase)))
    real_print(('camp.current_master_id   = %s'):format(tostring(camp.current_master_id)))

    local master_keys = {}
    for id in pairs(camp.masters or {}) do master_keys[#master_keys + 1] = id end
    table.sort(master_keys)
    real_print(('camp.masters count       = %d'):format(#master_keys))

    local cur = camp.current_master_id
    if cur then
        local m = camp.masters and camp.masters[cur]
        real_print(('masters[%s] exists       = %s'):format(cur, tostring(m ~= nil)))
        real_print(('masters[%s].defeated     = %s'):format(cur, tostring(m and m.defeated)))
    else
        real_print('masters[current] exists  = n/a (current_master_id is nil)')
    end
    real_print(('camp.active_thread       = %s'):format(
        camp.active_thread and camp.active_thread.id or 'nil'))

    local registered = {}
    for id in pairs(Threads) do registered[#registered + 1] = id end
    table.sort(registered)
    real_print(('registered threads       = %s'):format(table.concat(registered, ', ')))
    real_print('')

    -- Pool membership + weight, exactly as ThreadGenerator computes them.
    local pool = ThreadGenerator.pool(player, RunState, Threads)
    local in_pool = {}
    for _, e in ipairs(pool) do in_pool[e.id] = e.weight end

    real_print('Per-thread pool membership and weight:')
    for _, id in ipairs(registered) do
        local t = Threads[id]
        local req_ok = 'no requires()'
        if t.requires then
            local ok, res = pcall(t.requires, camp)
            req_ok = ok and tostring(res) or ('ERROR: ' .. tostring(res))
        end
        local inP = in_pool[id] ~= nil
        local w = 'n/a'
        if inP then
            w = tostring(in_pool[id])
        elseif t.weight then
            local ok, res = pcall(t.weight, camp)
            w = ok and ('excluded (weight would be ' .. tostring(res) .. ')')
                or ('ERROR: ' .. tostring(res))
        end
        real_print(('  %-16s requires=%-6s inPool=%-5s weight=%s')
            :format(id, req_ok, tostring(inP), w))
    end

    real_print('')
    local pool_ids = {}
    for _, e in ipairs(pool) do pool_ids[#pool_ids + 1] = e.id end
    real_print(('pool = %s'):format(#pool_ids > 0 and table.concat(pool_ids, ', ') or '(empty)'))

    local _, ctx = ThreadGenerator.select(player, RunState, Threads)
    real_print(('select() picked          = %s'):format(
        RunState.story and RunState.story.thread_id or '(none)'))
    if ctx and ctx.master then
        real_print(('ctx.master               = %s'):format(tostring(ctx.master.id)))
    else
        real_print('ctx.master               = nil  <-- scene graphs that require ctx.master build nothing')
    end
end

real_print('')
os.exit(0)
