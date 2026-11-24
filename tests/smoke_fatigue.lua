-- tests/smoke_fatigue.lua
--
-- Fatigue system: persistence, accumulation rules (active x1, spare ceil x0.5),
-- clamping, the spawn filter, the "party exhausted" run-end rule and the
-- single-award-per-node guarantee.
--
-- Headless, no LÖVE runtime. Run: lua tests/smoke_fatigue.lua

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

local function list_dir(dir)
    local list = {}
    local pipe = io.popen('dir /b "' .. dir:gsub('/', '\\') .. '" 2>nul')
    if pipe then
        for line in pipe:lines() do
            if line ~= '' then list[#list + 1] = line end
        end
        pipe:close()
    end
    return list
end

love = {
    image = { newImageData = stubImageData, newImage = stubImage },
    graphics = {
        newImage  = stubImage,
        newFont   = stubFont,
        newQuad   = function() return { getViewport = function() return 0, 0, 1, 1 end } end,
        newText   = function() return { setf = function() end } end,
        newCanvas = stubImage,
        newShader = function() return { send = function() end } end,
        getCanvas = function() return nil end,
        setCanvas = function() end,
        setShader = function() end,
        getColor  = function() return 1, 1, 1, 1 end,
        clear     = function() end,
        getWidth  = function() return 1280 end,
        getHeight = function() return 720 end,
    },
    filesystem = {
        getInfo = function() return nil end,
        getDirectoryItems = function(dir)
            if dir == 'src/characters' or dir == 'src/characters/' then
                return list_dir(root .. '/src/characters')
            end
            return {}
        end,
    },
    window = {
        getMode = function() return 1280, 720, {} end,
        isOpen  = function() return true end,
        setMode = function() end,
    },
    timer = {
        getDelta = function() return 0.016 end,
        getTime  = function() return 0 end,
    },
    mouse = { getPosition = function() return 0, 0 end },
    math = {
        colorFromBytes = function(r, g, b, a)
            return { (r or 0) / 255, (g or 0) / 255, (b or 0) / 255, (a or 255) / 255 }
        end,
        random = function(a, b)
            if a and b then return a end
            return 0
        end,
        newRandomGenerator = function(seed)
            local state = math.floor(math.abs(seed or 1)) % 2147483647
            if state == 0 then state = 1 end
            return { random = function(_, a, b)
                state = (state * 16807) % 2147483647
                local v = (state - 1) / 2147483646
                if a and b then return math.floor(a + v * (b - a + 1)) end
                return v
            end }
        end,
    },
}

Class  = dofile(root .. '/lib/class.lua')
Vector = require 'lib.vector'
dofile(root .. '/utils.lua')
dofile(root .. '/colors.lua')
require 'src.spellcast.targetFactory'

-- ---------------------------------------------------------------------------
-- Globals main.lua provides. State modules are bare globals read by
-- levelmap2 / node, exactly like main.lua does.
-- ---------------------------------------------------------------------------

Tagtext     = { add = function() end }
FieldMusic  = { stop = function() end, play = function() end }
BattleMusic = { play = function() end, stop = function() end }
PlaySound   = function() end

FadeInState     = { __name = 'FadeInState' }
FadeOutState    = { __name = 'FadeOutState' }
TownState       = { __name = 'TownState' }
RestState       = { __name = 'RestState' }
ShopState       = { __name = 'ShopState' }
EventState      = { __name = 'EventState' }
ExhaustionState = { __name = 'ExhaustionState' }
BattleState     = { __name = 'BattleState' }

-- Records transitions instead of running them.
local stack = { pushed = {}, switched = {}, popped = 0 }
Gamestate = {
    push    = function(state, args) stack.pushed[#stack.pushed + 1] = { state, args } end,
    pop     = function() stack.popped = stack.popped + 1 end,
    switch  = function(state, args) stack.switched[#stack.switched + 1] = { state, args } end,
    current = function() return nil end,
}

local savedRuns = 0
package.loaded['src.save_manager'] = {
    save   = function() savedRuns = savedRuns + 1 return true end,
    load   = function() return nil end,
    exists = function() return false end,
}

local RunState = require 'src.states.run_state'
_G.RunState = RunState
RunState.tickBattleModifiers = function() end
RunState.fireHook           = function() end
RunState.getModifiers       = function() return {} end
RunState.hasUnlock          = function() return false end
RunState.consumeUnlock      = function() return false end

local Levelmap   = require 'src.states.levelmap2'
local Fatigue    = require 'src.fatigue'
local Character  = require 'src.character'
local Characters = require 'src.characters'

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function ok(cond, message)
    assert(cond, message)
    print('  ok  ' .. message)
end

local STARTER = Characters['dumbbat'] and 'dumbbat' or next(Characters)

local function creature(name)
    local template = Characters[name or STARTER]
    assert(template, 'no creature template available')
    return Character.new(template)
end

local function make_player(actives, spares)
    local p = {
        charactersActive     = {},
        charactersActiveSize = #actives,
        charactersSpare      = {},
        charactersSpareSize  = #spares,
        lives                = 3,
        inventory            = {},
    }
    for i, c in ipairs(actives) do p.charactersActive[i] = c end
    for i, c in ipairs(spares)  do p.charactersSpare[i]  = c end
    return p
end

-- A bare instance. Methods are resolved through a *function* __index, never a
-- table: a table __index makes every assigned field leak into the module
-- table (Lua 5.4 writes plain fields upward), which silently replaced
-- Levelmap.resume mid-test.
local function make_levelmap(player)
    return setmetatable({
        player      = player,
        nodes       = {},
        pathes      = {},
        active      = true,
        seed        = 4242,
        currentNode = nil,
    }, { __index = function(_, key) return Levelmap[key] end })
end

-- Levelmap functions live on the module table; the instance only carries data.
local function call_resume(lm, from, args)
    return Levelmap.resume(lm, from, args)
end

local function call_story_complete(lm, node)
    return Levelmap._handle_story_node_complete(lm, node)
end

local function call_party_exhausted(lm, node)
    return Levelmap._handle_party_exhausted(lm, node)
end

local function call_has_fighters(lm)
    return Levelmap.hasFighters(lm)
end

local function node(type_, extra)
    local n = { type = type_, isCompleted = false }
    for k, v in pairs(extra or {}) do n[k] = v end
    return n
end

local function reset_transitions()
    stack.pushed, stack.switched, stack.popped = {}, {}, 0
end

print('smoke_fatigue: model')

-- ---------------------------------------------------------------------------
-- 1. Defaults and persistence (handoff §3)
-- ---------------------------------------------------------------------------

local c = creature()
ok(c.fatigue == 0, 'Character.new defaults fatigue to 0')

c.fatigue = 60
local data = Character.serialize(c)
ok(data.fatigue == 60, 'Character.serialize writes fatigue')

local restored = Character.deserialize(data)
ok(restored.fatigue == 60, 'fatigue 60 survives serialize -> deserialize')

-- Legacy save without the field must not yield nil.
local legacy = Character.deserialize({ name = c.name, health = 10, fatigue = nil })
ok(legacy.fatigue == 0, 'legacy save without fatigue loads as 0')

-- Out-of-range values are pulled back into [0, MAX] on load.
local dirty = Character.deserialize({ name = c.name, health = 10, fatigue = 130 })
ok(dirty.fatigue == Fatigue.MAX, 'loaded fatigue above MAX is clamped to 100')

-- ---------------------------------------------------------------------------
-- 2. Single threshold constant and clamping
-- ---------------------------------------------------------------------------

ok(Fatigue.MAX == 100, 'one threshold constant, value 100')

local probe = creature()
Fatigue.gain(probe, 95)
Fatigue.gain(probe, 15)
ok(probe.fatigue == 100, 'gain clamps at MAX (95 + 15 -> 100)')

Fatigue.relieve(probe, 250)
ok(probe.fatigue == 0, 'relieve clamps at 0')

Fatigue.relieve(probe, 10)
ok(probe.fatigue == 0, 'relieve below zero stays 0')

probe.fatigue = 40
ok(Fatigue.isExhausted(probe) == false, '40 is not exhausted')
probe.fatigue = 100
ok(Fatigue.isExhausted(probe) == true, '100 is exhausted')

-- ---------------------------------------------------------------------------
-- 3. Shares: active x1, spare ceil(x0.5)
-- ---------------------------------------------------------------------------

print('smoke_fatigue: shares')

local a1, a2 = creature(), creature()
local s1 = creature()
local p = make_player({ a1, a2 }, { s1 })

Fatigue.applyNode(p, 'win')  -- 10
ok(a1.fatigue == 10 and a2.fatigue == 10, 'active creatures take full 10 for a win')
ok(s1.fatigue == 5, 'spare takes ceil(10 * 0.5) = 5 for a win')

local s2 = creature()
local p2 = make_player({ creature() }, { s2 })
Fatigue.gain(s2, 0)
-- 7 is the player-facing example of a rounding case: ceil(7 * 0.5) = 4.
local odd = creature()
local p3 = make_player({}, { odd })
local granted = Fatigue.gainFor(p3, odd, 7)
ok(granted == 4, 'spare rounding is up: ceil(7 * 0.5) = 4')

local p4 = make_player({ creature() }, {})
Fatigue.applyNode(p4, 'lose')  -- 15
ok(p4.charactersActive[1].fatigue == 15, 'loss costs 15')

local p5 = make_player({ creature() }, {})
Fatigue.applyNode(p5, 'boss')  -- 20
ok(p5.charactersActive[1].fatigue == 20, 'master boss costs 20')

local p6 = make_player({ creature() }, { creature() })
Fatigue.applyNode(p6, 'event')  -- 5
ok(p6.charactersActive[1].fatigue == 5, 'event costs 5 to active')
ok(p6.charactersSpare[1].fatigue == 3, 'event costs ceil(5 * 0.5) = 3 to spare')

local p7 = make_player({ creature() }, { creature() })
Fatigue.applyNode(p7, 'rest')
Fatigue.applyNode(p7, 'shop')
ok(p7.charactersActive[1].fatigue == 0, 'rest and shop cost no fatigue')

-- ---------------------------------------------------------------------------
-- 4. Party rule: active + spare, stables excluded
-- ---------------------------------------------------------------------------

print('smoke_fatigue: party rule')

local exhausted_pair = make_player({ creature(), creature() }, { creature() })
for _, ch in ipairs(Fatigue.party(exhausted_pair)) do ch.fatigue = Fatigue.MAX end
ok(Fatigue.isPartyExhausted(exhausted_pair), 'all active + spare at 100 -> party exhausted')
ok(Fatigue.hasFighter(exhausted_pair) == false, 'no fighter left')

exhausted_pair.charactersSpare[1].fatigue = 50
ok(Fatigue.isPartyExhausted(exhausted_pair) == false, 'a surviving spare keeps the party alive')
ok(Fatigue.hasFighter(exhausted_pair), 'surviving spare counts as a fighter')

local with_stables = make_player({ creature() }, {})
with_stables.charactersActive[1].fatigue = Fatigue.MAX
with_stables.charactersStables = { creature() }
with_stables.charactersStablesSize = 1
ok(Fatigue.isPartyExhausted(with_stables), 'stables are not counted toward "everyone"')

local empty = make_player({}, {})
ok(Fatigue.isPartyExhausted(empty) == false, 'empty party is not "exhausted"')

-- ---------------------------------------------------------------------------
-- 5. Spawn filter (BattleState.enter loops)
-- ---------------------------------------------------------------------------

print('smoke_fatigue: spawn filter')

local filt = make_player({ creature(), creature() }, { creature() })
filt.charactersActive[1].fatigue = Fatigue.MAX     -- must not spawn
filt.charactersActive[2].fatigue = 40              -- must spawn
filt.charactersSpare[1].fatigue  = Fatigue.MAX     -- must not spawn

local spawned_active, spawned_spare = 0, 0
for i = 1, filt.charactersActiveSize do
    local ch = filt.charactersActive[i]
    if ch and not Fatigue.isExhausted(ch) then spawned_active = spawned_active + 1 end
end
for i = 1, filt.charactersSpareSize do
    local ch = filt.charactersSpare[i]
    if ch and not Fatigue.isExhausted(ch) then spawned_spare = spawned_spare + 1 end
end
ok(spawned_active == 1, 'exhausted active creature is not deployed')
ok(spawned_spare == 0, 'exhausted spare creature is not deployed')

-- ---------------------------------------------------------------------------
-- 6. Rest relieves fatigue
-- ---------------------------------------------------------------------------

print('smoke_fatigue: rest')

local rest_party = make_player({ creature() }, { creature() })
rest_party.charactersActive[1].fatigue = 60
rest_party.charactersSpare[1].fatigue  = 20
Fatigue.relieveParty(rest_party, Fatigue.REST_RELIEF)
ok(rest_party.charactersActive[1].fatigue == 30, 'rest removes 30 from active (60 -> 30)')
ok(rest_party.charactersSpare[1].fatigue == 0, 'rest clamps spare at 0 (20 -> 0)')

-- ---------------------------------------------------------------------------
-- 7. Levelmap: award once per closed node, and the run-end rule
-- ---------------------------------------------------------------------------

print('smoke_fatigue: levelmap integration')

-- 7a. A won battle awards exactly once, even if resume is re-entered.
RunState.active = true
local lmA = make_levelmap(make_player({ creature(), creature() }, { creature() }))
local battleNode = node('wild')
lmA.currentNode = battleNode
reset_transitions()

call_resume(lmA, BattleState, { result = 'win' })
local after_first = lmA.player.charactersActive[1].fatigue
ok(after_first == 10, 'won battle awards 10 to active creatures')
ok(lmA.player.charactersSpare[1].fatigue == 5, 'won battle awards 5 to spare')
ok(lmA.currentNode == nil, 'node is released after closing')

-- The node is closed now; a repeated resume must not award again.
local again = make_levelmap(lmA.player)
again.currentNode = battleNode
call_resume(again, BattleState, { result = 'win' })
ok(lmA.player.charactersActive[1].fatigue == 10, 'repeat resume on a closed node awards nothing')

-- 7b. Event node awards its own key.
local lmB = make_levelmap(make_player({ creature() }, {}))
lmB.currentNode = node('event')
call_resume(lmB, EventState, {})
ok(lmB.player.charactersActive[1].fatigue == 5, 'event node awards 5 after completion')

-- 7c. Shop and rest nodes cost nothing. They still go through the award path
--     (the node is closed), the gain table is simply 0 for both. Each case
--     uses a fresh map: a rest node is followed by the real RestState, which
--     relieves fatigue, so reusing one party would mask the value under test.
local lmC = make_levelmap(make_player({ creature() }, { creature() }))
lmC.currentNode = node('shop')
call_resume(lmC, ShopState, {})
ok(lmC.currentNode == nil, 'a closed shop node is released')
ok(lmC.player.charactersActive[1].fatigue == 0, 'shop node adds no fatigue')

local lmC2 = make_levelmap(make_player({ creature() }, { creature() }))
lmC2.currentNode = node('rest')
call_resume(lmC2, RestState, {})
ok(lmC2.currentNode == nil, 'a closed rest node is released')
ok(lmC2.player.charactersActive[1].fatigue == 0, 'rest node adds no fatigue')
ok(lmC2.player.charactersSpare[1].fatigue == 0, 'rest node adds nothing to spares either')

-- 7d. The party hitting 100 closes the run without spending a life.
local dead_tired = make_player({ creature(), creature() }, { creature() })
dead_tired.charactersActive[1].fatigue = 90
dead_tired.charactersActive[2].fatigue = 90
dead_tired.charactersSpare[1].fatigue  = 95   -- spare gains ceil(10 * 0.5) = 5
local lives_before = dead_tired.lives

local lmD = make_levelmap(dead_tired)
lmD.currentNode = node('wild')
reset_transitions()

call_resume(lmD, BattleState, { result = 'win' })

ok(dead_tired.charactersActive[1].fatigue == 100, 'last battle pushes active to 100')
ok(Fatigue.isPartyExhausted(dead_tired), 'party is exhausted after the award')
ok(dead_tired.lives == lives_before, 'exhaustion does not spend lives')
ok(lmD.active == false, 'levelmap is no longer active')
ok(RunState.active == false, 'run state is ended')
ok(#stack.pushed == 1, 'a transition was queued to the exhaustion screen')

local fired = stack.pushed[1]
ok(fired[1] == FadeInState, 'transition is a fade')

-- Drive the fade callback: it must switch to ExhaustionState, not push it.
reset_transitions()
fired[2].onFadeComplete()
ok(#stack.switched == 1 and stack.switched[1][1] == ExhaustionState,
    'fade completes into ExhaustionState via switch (Levelmap is gone)')
ok(#stack.pushed == 0, 'ExhaustionState is switched in, not pushed over Levelmap')
ok(stack.switched[1][2].player == dead_tired, 'ExhaustionState receives the player')

-- 7e. Losing the last life still awards the loss fatigue (15).
RunState.active = true
local lmE = make_levelmap(make_player({ creature() }, {}))
lmE.player.lives = 1
lmE.currentNode = node('trainer')
reset_transitions()
call_resume(lmE, BattleState, { result = 'lose' })
ok(lmE.player.charactersActive[1].fatigue == 15, 'lost battle awards 15')
ok(lmE.player.lives == 0, 'lost battle still spends the last life')

-- 7f. A run-ending loss must not double-pop for exhaustion.
ok(#stack.pushed == 0, 'run-ending loss does not trigger the exhaustion screen')

-- 7g. The master boss awards its own key and does not fall through the
--     generic branch (which returns early in resume).
RunState.active = true
local lmF = make_levelmap(make_player({ creature() }, {}))
lmF.currentNode = node('event', { story_scene = 'master_boss', is_master_boss = true })
rawset(lmF, "_handle_master_victory", function() end)
rawset(lmF, "_handle_master_defeat",  function() end)
call_resume(lmF, BattleState, { result = 'win' })
ok(lmF.player.charactersActive[1].fatigue == 20, 'master boss awards 20')

-- 7h. The start node is never awarded, even if resume sees it as current.
local lmG = make_levelmap(make_player({ creature() }, {}))
local startNode = node('wild', { isStartingNode = true })
lmG.currentNode = startNode
call_resume(lmG, BattleState, { result = 'win' })
ok(lmG.player.charactersActive[1].fatigue == 0, 'start node is skipped, no fatigue')

-- 7i. Boss battle is gated: no fighters means no battle.
--
-- `_handle_story_node_complete` consults `self.player.meta_story` to find the
-- master, so the fixture carries one. The gate must fire before the
-- no-master fallback (which would silently close the node instead).
RunState.active = true
local lmH = make_levelmap(make_player({ creature() }, {}))
lmH.player.meta_story = { persistent_keys = {} }
lmH.player.charactersActive[1].fatigue = Fatigue.MAX
local bossNode = node('event', { story_scene = 'master_boss', is_master_boss = true })
reset_transitions()
-- Stub the two helpers the handler reaches for: the point of this case is
-- the fatigue gate, not master generation.
rawset(lmH, '_advance_story', function() end)
rawset(lmH, '_saveGame',     function() end)
local ok_boss, err_boss = pcall(call_story_complete, lmH, bossNode)
ok(ok_boss, 'boss scene handler runs headless (' .. tostring(err_boss) .. ')')
ok(#stack.pushed == 1 and stack.pushed[1][1] == FadeInState,
    'boss battle does not start when the party has no fighters (pushed='
    .. #stack.pushed .. ', nodeCompleted=' .. tostring(bossNode.isCompleted) .. ')')
ok(RunState.active == false, 'the exhausted run is ended instead of fought')

ok(call_has_fighters(lmH) == false, 'Levelmap:hasFighters reports the exhausted party')

-- ---------------------------------------------------------------------------
-- 8. RestState actually relieves fatigue
-- ---------------------------------------------------------------------------

print('smoke_fatigue: reststate')

local RestModule = dofile(root .. '/src/states/reststate.lua')
local restState = { player = make_player({ creature() }, { creature() }) }
restState.player.charactersActive[1].fatigue = 70
restState.rested, restState.complete = false, false

-- _healAll needs no real sprites here: it only touches health/energy.
local heal_ok, heal_err = pcall(RestModule._healAll, restState, 'hp', 0.0)
ok(heal_ok, 'RestState:_healAll runs headless (' .. tostring(heal_err) .. ')')
ok(restState.player.charactersActive[1].fatigue == 40, 'rest node removes 30 fatigue')

print('smoke_fatigue OK')
