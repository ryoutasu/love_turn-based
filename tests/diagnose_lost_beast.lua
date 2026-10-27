-- tests/diagnose_lost_beast.lua
--
-- DIAGNOSTIC SCRIPT, not a test. Always exits 0.
--
--   lua tests/diagnose_lost_beast.lua
--
-- Tests H1..H4 for lost_beast's 0/13 placement success.

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
local StoryPlacement  = require 'src.story.story_placement'
local ThreadGenerator = require 'src.story.thread_generator'
local SceneGraph      = require 'src.story.scene_graph'
local Scenes          = require 'data.story.scenes'
local Threads         = require 'data.story.threads'
local PlayerMetaStory = require 'src.player_meta_story'
local MasterGenerator = require 'data.story.generators.master_generator'

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
-- Fixtures: an EMPTY party (as measure_placement_T1 uses) and a realistic one
-- ---------------------------------------------------------------------------

local function make_player(seed, with_party)
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
    if with_party then
        -- Two creatures, one badly hurt: exactly what lost_beast.build asks for.
        p.charactersActive = {
            { name = 'Emberpuff', health = 20, max_health = 28, level = 1, exp = 0, modifiers = {}, spells = {} },
            { name = 'Terrow',    health = 5,  max_health = 30, level = 1, exp = 0, modifiers = {}, spells = {} },
        }
    end
    return p
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

-- ---------------------------------------------------------------------------
-- R1 — direct build() inspection
-- ---------------------------------------------------------------------------

local thread = Threads.lost_beast

real_print('════════════════════════════════════════════════')
real_print('R1 — lost_beast.build() inspection')
real_print('════════════════════════════════════════════════')

for _, case in ipairs({
    { label = 'empty party (measure_placement fixture)', party = false },
    { label = '2 creatures, one at 17% HP (realistic)', party = true },
}) do
    local player = make_player(1, case.party)
    RunState:reset(player, 1)
    local ctx = ThreadGenerator.build_context(player, RunState)

    real_print(('--- case: %s'):format(case.label))
    real_print(('    party size = %d'):format(#player.charactersActive + #player.charactersSpare))

    local ok, graph = pcall(thread.build, ctx)
    if not ok then
        real_print(('    build() THREW: %s'):format(tostring(graph)))
    elseif graph == nil then
        real_print('    build() returned NIL  <-- no graph to place')
    else
        real_print('    build() returned a table')
        local ids = {}
        for id in pairs(graph) do ids[#ids + 1] = id end
        table.sort(ids)
        for _, id in ipairs(ids) do
            local n = graph[id]
            local out = SceneGraph.outgoing(n)
            real_print(('      node %-10s scene=%-18s outgoing=[%s] terminal=%s')
                :format(id, tostring(n.scene), table.concat(out, ','), tostring(n.terminal)))
        end

        local okV, errV = pcall(SceneGraph.validate, graph)
        real_print(('      SceneGraph.validate: %s%s')
            :format(tostring(okV), okV and '' or (' — ' .. tostring(errV))))

        for _, id in ipairs(ids) do
            local scene = graph[id].scene
            real_print(('      scene %-18s registered=%s')
                :format(tostring(scene), tostring(Scenes[scene] ~= nil)))
        end
    end
    real_print('')
end

-- ---------------------------------------------------------------------------
-- R1d — full StoryPlacement.place, both fixtures
-- ---------------------------------------------------------------------------

real_print('════════════════════════════════════════════════')
real_print('R1d — StoryPlacement.place with lost_beast pinned')
real_print('════════════════════════════════════════════════')

for _, case in ipairs({
    { label = 'empty party', party = false },
    { label = 'realistic party', party = true },
}) do
    local player = make_player(1, case.party)
    player.meta_story.active_thread = { id = 'lost_beast', params = {}, started_run = 0 }
    RunState:reset(player, 1)
    RunState.story   = { thread_id = 'lost_beast', flags = {} }
    RunState.unlocks = {}

    local lm = make_levelmap(player, 1)
    math.randomseed(1)
    lm:_generateMap()

    captured = {}
    capturing = true
    lm:_place_story()
    capturing = false

    real_print(('--- case: %s'):format(case.label))
    real_print(('    placement result: %s'):format(lm.story and 'table' or 'NIL'))
    if lm.story then
        local ids = {}
        for _, n in ipairs(lm.story.placed) do ids[#ids + 1] = tostring(n.story_id) end
        real_print(('    placed: %s'):format(table.concat(ids, ', ')))
    end
    for _, line in ipairs(captured) do real_print('    said: ' .. line) end
    real_print('')
end

os.exit(0)
