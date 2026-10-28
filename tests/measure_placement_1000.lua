-- tests/measure_placement_1000.lua
--
-- MEASUREMENT SCRIPT, not a test. Always exits 0.
--
--   lua tests/measure_placement_1000.lua [from] [to]
--
-- Pinned master_trial sweep over a wide seed range (default 1..1000), same
-- fixture as measure_placement_T1. Reports the residual placement failure rate
-- and which scene fails, so rare topologies are quantified rather than guessed.
--
-- Also probes the specific playtest seed 1793198478 and prints the topology of
-- its crossroads node when the run fails.

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

local FROM = tonumber(arg and arg[1]) or 1
local TO   = tonumber(arg and arg[2]) or 1000

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

-- ---------------------------------------------------------------------------
-- Fixture (identical to measure_placement_T1)
-- ---------------------------------------------------------------------------

local function make_player(seed)
    local camp = PlayerMetaStory.create(seed)
    MasterGenerator.ensure_campaign(camp)
    camp.active_thread = { id = 'master_trial', params = {}, started_run = 0 }
    return {
        meta_story       = camp,
        lives            = 3,
        charactersActive = {
            { name = 'Emberpuff', health = 20, max_health = 28, level = 1, exp = 0 },
            { name = 'Terrow',    health = 5,  max_health = 30, level = 1, exp = 0 },
        },
        charactersSpare  = {},
        shards           = {},
        inventory        = {},
        drawLives        = function() end,
    }
end

local function run_seed(seed)
    local player = make_player(seed)

    RunState:reset(player, seed)
    RunState.story   = { thread_id = 'master_trial', flags = {} }
    RunState.unlocks = {}

    local lm = setmetatable({}, { __index = Levelmap })
    lm.player = player
    lm.nodes  = {}
    lm.pathes = {}
    lm.active = true
    lm.seed   = seed

    math.randomseed(seed)
    lm:_generateMap()

    captured = {}
    capturing = true
    lm:_place_story()
    capturing = false

    local fail_scene, fail_parents
    for _, line in ipairs(captured) do
        local s, p = line:match('placement failed: scene (%a+) from parent%(s%) (.*)')
        if s then fail_scene, fail_parents = s, p end
        if not fail_scene then
            local b = line:match('placement failed: boss scene (%a+)')
            if b then fail_scene, fail_parents = b, '(boss)' end
        end
    end

    return {
        seed    = seed,
        success = lm.story ~= nil,
        scene   = fail_scene,
        parents = fail_parents,
        lm      = lm,
        diag    = captured,
    }
end

-- ---------------------------------------------------------------------------
-- Sweep
-- ---------------------------------------------------------------------------

local rows, ok_n = {}, 0
local scene_hist = {}
local fail_seeds = {}

for seed = FROM, TO do
    local r = run_seed(seed)
    rows[#rows + 1] = r
    if r.success then
        ok_n = ok_n + 1
    else
        local key = r.scene or 'unknown'
        scene_hist[key] = (scene_hist[key] or 0) + 1
        fail_seeds[#fail_seeds + 1] = seed
    end
end

local total = #rows
local fail_n = total - ok_n
local function pct(n) return total > 0 and ('%.2f%%'):format(100 * n / total) or 'n/a' end

real_print('════════════════════════════════════════════════')
real_print(('PLACEMENT SWEEP — pinned master_trial, seeds %d..%d'):format(FROM, TO))
real_print('════════════════════════════════════════════════')
real_print(('Successful placements: %d  (%s)'):format(ok_n, pct(ok_n)))
real_print(('Failed placements:     %d  (%s)'):format(fail_n, pct(fail_n)))

local keys = {}
for k in pairs(scene_hist) do keys[#keys + 1] = k end
table.sort(keys)
if #keys > 0 then
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = ('%s: %d'):format(k, scene_hist[k]) end
    real_print('Failure scenes:        ' .. table.concat(parts, ', '))
    -- First 20 failing seeds, for reproducibility.
    local shown = {}
    for i = 1, math.min(20, #fail_seeds) do shown[#shown + 1] = tostring(fail_seeds[i]) end
    real_print(('Failing seeds:         %s%s'):format(
        table.concat(shown, ', '), #fail_seeds > 20 and ' …' or ''))
else
    real_print('Failure scenes:        none')
end
real_print('')

-- ---------------------------------------------------------------------------
-- The playtest seed
-- ---------------------------------------------------------------------------

local PLAYTEST_SEED = 1793198478
real_print('════════════════════════════════════════════════')
real_print(('PLAYTEST SEED %d'):format(PLAYTEST_SEED))
real_print('════════════════════════════════════════════════')

do
    local r = run_seed(PLAYTEST_SEED)
    real_print(('placement: %s'):format(r.success and 'SUCCESS' or 'FAILED'))
    if not r.success then
        real_print(('failing scene: %s   parents: %s')
            :format(tostring(r.scene), tostring(r.parents)))
        for _, line in ipairs(r.diag) do real_print('  said: ' .. line) end

        -- Topology of the placed crossroads node.
        local cross
        for _, n in ipairs(r.lm.nodes) do
            if n.story_id == 'crossroads' then cross = n end
        end
        if cross then
            real_print(('crossroads node: idx=%s at (%.0f,%.0f)')
                :format(tostring(cross.id), cross.x or -1, cross.y or -1))
            real_print('crossroads neighbours:')
            local by_point = {}
            for _, n in ipairs(r.lm.nodes) do by_point[n.point] = n end
            for _, np in ipairs(cross.point.neighbors or {}) do
                local n = by_point[np]
                local usable = n and (n.type == 'event' or n.type == 'wild'
                    or n.type == 'trainer') and not n.story_id
                real_print(('    idx=%-3s type=%-8s story=%-10s usable_free=%s')
                    :format(tostring(n and n.id), tostring(n and n.type),
                            tostring(n and n.story_id), tostring(usable)))
            end
        else
            real_print('crossroads node: not placed')
        end
    end
end

real_print('')
os.exit(0)
