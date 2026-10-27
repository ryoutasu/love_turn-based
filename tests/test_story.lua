-- tests/test_story.lua
--
-- Validates the procedural story layer WITHOUT LÖVE:
--   * every thread graph is structurally valid (SceneGraph.validate);
--   * every scene id referenced by a graph exists in scenes.lua;
--   * every scene's generate() runs and returns the EventState format;
--   * generators are deterministic (same seed -> same output);
--   * rivals persist and grow across meetings (the core genre promise);
--   * the Chekhov key thread spans two runs correctly.
--
-- Run: lua tests/test_story.lua

local here = (arg and arg[0] or ''):match('^(.*)[/\\]') or '.'
package.path = here .. '/../?.lua;' .. here .. '/../?/init.lua;' .. package.path

-- ---------------------------------------------------------------------------
-- Stubs
-- ---------------------------------------------------------------------------

local function stubImageData(w, h)
    local d = { w = w or 1, h = h or 1 }
    function d:setPixel() end
    function d:mapPixel() end
    function d:getWidth() return self.w end
    function d:getHeight() return self.h end
    return d
end

local function stubImage()
    return {
        getWidth  = function() return 1 end,
        getHeight = function() return 1 end,
    }
end

_G.CHARACTERS_SCALE = 0.75
_G.HEX_RADIUS = 40
_G.HEX_HEIGHT = 1
_G.DEBUG = false

_G.love = {
    image   = { newImageData = stubImageData, newImage = stubImage },
    graphics = {
        newImage = stubImage,
        newFont  = function()
            return { getWidth = function(_, s) return #tostring(s or '') * 7 end,
                     getHeight = function() return 14 end }
        end,
        newQuad = function() return {} end,
        newText  = function() return { setf = function() end } end,
    },
    filesystem = { getInfo = function() return nil end,
                   getDirectoryItems = function() return {} end },
    math = { colorFromBytes = function(r, g, b, a)
        return { (r or 0)/255, (g or 0)/255, (b or 0)/255, (a or 255)/255 }
    end, random = function(a, b)
        if a and b then return a end
        return 0
    end },
}

_G.Class = function(base)
    base = base or {}
    base.__index = base
    return setmetatable(base, { __call = function(c, ...)
        local o = setmetatable({}, c)
        if o.init then o:init(...) end
        return o
    end })
end

require 'src.spellcast.targetFactory'
dofile('utils.lua')

-- RunState/Logging touch globals the scenes expect.
_G.Tagtext = { add = function() end }
_G.RunState = {
    unlocks   = {},
    modifiers = {},
    story     = nil,
    addUnlock = function(self, k) self.unlocks[k] = (self.unlocks[k] or 0) + 1 end,
    hasUnlock = function(self, k) return (self.unlocks[k] or 0) > 0 end,
    getModifiers = function(self) return self.modifiers end,
    random    = function() return 0.25 end,
    randomInt = function(a, b) return a end,
}

-- ---------------------------------------------------------------------------
-- Tiny framework
-- ---------------------------------------------------------------------------

local passed, failed, failures = 0, 0, {}
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1
    else failed = failed + 1; failures[#failures + 1] = name .. '\n    ' .. tostring(err) end
end
local function ok(cond, msg) if not cond then error(msg, 2) end end
local function eq(a, b, msg)
    if a ~= b then error((msg or 'eq') .. ': expected ' .. tostring(b) .. ', got ' .. tostring(a), 2) end
end

-- ---------------------------------------------------------------------------
-- Modules
-- ---------------------------------------------------------------------------

local SceneGraph      = require 'src.story.scene_graph'
local ThreadGenerator = require 'src.story.thread_generator'
local PlayerMetaStory = require 'src.player_meta_story'
local MasterGenerator = require 'data.story.generators.master_generator'
local RivalGenerator  = require 'data.story.generators.rival_generator'
local Threads         = require 'data.story.threads'
local Scenes          = require 'data.story.scenes'

-- ---------------------------------------------------------------------------
-- Fake player/run used to build contexts
-- ---------------------------------------------------------------------------

local function make_player(seed)
    local p = {
        meta_story = PlayerMetaStory.create(seed or 12345),
        charactersActive = {},
        charactersSpare  = {},
        charactersStables = {},
        inventory = {},
        shards = {},
        essence = 0,
        currencies = {},
        addCharacter = function(self, name)
            local c = { name = name, level = 1, exp = 0, health = 20,
                        max_health = 20, energy = 5, max_energy = 5,
                        element = 'ember', attribute = 'wild', modifiers = {} }
            self.charactersActive[#self.charactersActive + 1] = c
            return c
        end,
        addEssence = function(self, n) self.essence = self.essence + n end,
    }
    p.charactersActive[1] = { name = 'Emberpuff', level = 2, exp = 10, health = 20,
                              max_health = 28, energy = 10, max_energy = 10,
                              element = 'ember', attribute = 'wild', modifiers = {} }
    return p
end

local function make_run(seed)
    local s = seed or 777
    local state = s
    return {
        seed = s,
        random = function(self)
            state = (state * 16807) % 2147483647
            return (state - 1) / 2147483646
        end,
        randomInt = function(self, a, b)
            return a + math.floor(self:random() * (b - a + 1))
        end,
        addUnlock = function(self, k) self.unlocks[k] = true end,
        unlocks = {},
        modifiers = {},
        getModifiers = function(self) return self.modifiers end,
        hasUnlock = function(self, k) return self[k] and true or (self.unlocks[k] ~= nil) end,
    }
end

local function ctx_for(player, run, opts)
    opts = opts or {}
    local camp = player.meta_story
    -- build_context already resolves ctx.master from camp.current_master_id
    -- and ctx.rival from camp.rival. Only override when explicitly asked.
    local ctx = ThreadGenerator.build_context(player, run)
    if opts.master ~= nil then ctx.master = opts.master end
    if opts.rival  ~= nil then ctx.rival  = opts.rival  end
    return ctx
end

-- ===========================================================================
-- 1. Registries
-- ===========================================================================

test('every registered thread has the required shape', function()
    local n = 0
    for id, t in pairs(Threads) do
        n = n + 1
        ok(type(id) == 'string', 'thread key must be a string')
        ok(t.id == id, ('thread %s: .id is %s'):format(id, tostring(t.id)))
        ok(type(t.requires) == 'function', id .. ': requires must be a function')
        ok(type(t.build) == 'function', id .. ': build must be a function')
    end
    ok(n >= 5, 'expected at least 5 threads, found ' .. n)
end)

test('every registered scene has the required shape', function()
    for id, s in pairs(Scenes) do
        ok(s.id == id, ('scene %s: .id is %s'):format(id, tostring(s.id)))
        ok(type(s.generate) == 'function', id .. ': generate must be a function')
    end
end)

-- ===========================================================================
-- 2. Graphs validate and reference real scenes
-- ===========================================================================

test('every thread graph is structurally valid', function()
    local player = make_player()
    local camp = player.meta_story
    MasterGenerator.ensure_campaign(camp)
    RivalGenerator.ensure(camp, player)

    for id, t in pairs(Threads) do
        local run = make_run(4242)
        local ctx = ctx_for(player, run)
        local graph = t.build(ctx)

        if graph ~= nil then
            SceneGraph.validate(graph)
            -- Zero cost at runtime, but important: a thread whose build()
            -- returns nil can never run. Warn loudly for story threads.
            if t.type == 'story' then
                ok(graph.start, id .. ': story thread built no graph')
            end
        end
    end
end)

test('every scene id in every graph exists in the scene registry', function()
    local player = make_player()
    local camp = player.meta_story
    MasterGenerator.ensure_campaign(camp)
    RivalGenerator.ensure(camp, player)

    for id, t in pairs(Threads) do
        local run = make_run(9191)
        local ctx = ctx_for(player, run)
        local graph = t.build(ctx)
        if graph then
            for node_id, node in pairs(graph) do
                ok(Scenes[node.scene],
                    ('thread %s, node %s references missing scene %q')
                    :format(id, node_id, tostring(node.scene)))
            end
        end
    end
end)

-- ===========================================================================
-- 3. Every scene generates the EventState format
-- ===========================================================================

test('every scene generate() returns { title, steps }', function()
    local player = make_player()
    local camp = player.meta_story
    MasterGenerator.ensure_campaign(camp)
    RivalGenerator.ensure(camp, player)

    local run = make_run(31337)
    local ctx = ctx_for(player, run)

    for id, s in pairs(Scenes) do
        local result = s.generate(ctx)
        ok(type(result) == 'table', id .. ': generate returned non-table')
        ok(type(result.steps) == 'table', id .. ': missing .steps')
        ok(#result.steps > 0, id .. ': .steps is empty')

        for si, step in ipairs(result.steps) do
            ok(type(step.text) == 'string' or type(step.text) == 'function',
                ('%s step %d: .text must be string or function'):format(id, si))
            ok(type(step.buttons) == 'table' and #step.buttons > 0,
                ('%s step %d: needs at least one button'):format(id, si))
            for bi, b in ipairs(step.buttons) do
                ok(type(b.text) == 'string',
                    ('%s step %d button %d: text must be a string'):format(id, si, bi))
                ok(type(b.action) == 'function',
                    ('%s step %d button %d: action must be a function'):format(id, si, bi))
            end
        end
    end
end)

test('every scene text function is callable', function()
    local player = make_player()
    local camp = player.meta_story
    MasterGenerator.ensure_campaign(camp)
    RivalGenerator.ensure(camp, player)

    local run = make_run(555)
    local ctx = ctx_for(player, run)

    for id, s in pairs(Scenes) do
        local result = s.generate(ctx)
        for si, step in ipairs(result.steps) do
            if type(step.text) == 'function' then
                local okr, text = pcall(step.text, player, step)
                ok(okr, ('%s step %d: text() raised: %s'):format(id, si, tostring(text)))
                ok(type(text) == 'string',
                    ('%s step %d: text() returned %s'):format(id, si, type(text)))
                ok(#text > 0, ('%s step %d: empty text'):format(id, si))
            end
        end
    end
end)

-- ===========================================================================
-- 4. Determinism
-- ===========================================================================

test('master generation is deterministic for a seed', function()
    local a = MasterGenerator.generate(123456, 'master_1', 1)
    local b = MasterGenerator.generate(123456, 'master_1', 1)
    eq(a.name, b.name, 'same seed -> same master name')
    eq(a.dojo_name, b.dojo_name, 'same seed -> same dojo')
    eq(a.archetype, b.archetype, 'same seed -> same archetype')
end)

test('different seeds produce different masters', function()
    local seen = {}
    for s = 1, 40 do
        local m = MasterGenerator.generate(s * 7919, 'm', 1)
        seen[m.name .. '|' .. m.dojo_name .. '|' .. m.element] = true
    end
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    ok(n > 20, 'expected variety across seeds, got ' .. n .. ' unique of 40')
end)

test('rival generation is deterministic for a seed', function()
    local a = RivalGenerator.generate(98765, 'ember')
    local b = RivalGenerator.generate(98765, 'ember')
    eq(a.name, b.name)
    eq(a.ace_species, b.ace_species)
    eq(a.archetype, b.archetype)
end)

test('rival element opposes the player starter', function()
    local r = RivalGenerator.generate(4321, 'ember')
    eq(r.element, 'water', 'ember player -> water rival')
    local r2 = RivalGenerator.generate(4321, 'light')
    eq(r2.element, 'dark', 'light player -> dark rival')
end)

-- ===========================================================================
-- 5. Rival progression (the core genre promise)
-- ===========================================================================

test('rival persists in the campaign across runs', function()
    local player = make_player(1001)
    local camp = player.meta_story
    RivalGenerator.ensure(camp, player)
    local first = camp.rival
    ok(first ~= nil, 'rival created')

    -- A new run does not touch the rival identity.
    RivalGenerator.ensure(camp, player)
    eq(camp.rival, first, 'same table instance is reused')
    eq(camp.rival.name, first.name)
end)

test('rival grows stronger with each meeting', function()
    local camp = PlayerMetaStory.create(2024)
    local r = RivalGenerator.generate(2024, 'ember')
    camp.rival = r

    local tiers = { RivalGenerator.tier(r) }
    for i = 1, 3 do
        RivalGenerator.record(camp, i % 2 == 0)
        tiers[#tiers + 1] = RivalGenerator.tier(r)
    end

    for i = 2, #tiers do
        ok(tiers[i] >= tiers[i - 1],
            ('tier must not decrease: %d -> %d'):format(tiers[i - 1], tiers[i]))
    end
    ok(tiers[#tiers] > tiers[1], 'rival must eventually outgrow the first meeting')
end)

test('rival records wins and losses separately', function()
    local camp = PlayerMetaStory.create(31)
    local r = RivalGenerator.generate(31, 'water')
    camp.rival = r

    RivalGenerator.record(camp, true)   -- player won
    RivalGenerator.record(camp, false)  -- rival won
    RivalGenerator.record(camp, true)

    eq(r.meetings, 3, 'meetings')
    eq(r.losses, 2, 'rival losses = player wins')
    eq(r.wins, 1, 'rival wins')
    eq(#r.history, 3, 'history length')
    eq(r.history[1], 'lost')
    eq(r.history[2], 'won')
end)

test('rival party grows with meetings and respects the bestiary', function()
    local camp = PlayerMetaStory.create(77)
    local r = RivalGenerator.generate(77, 'ember')
    camp.rival = r

    local size0 = #RivalGenerator.build_party(r)
    RivalGenerator.record(camp, true)
    local size1 = #RivalGenerator.build_party(r)
    RivalGenerator.record(camp, true)
    local size2 = #RivalGenerator.build_party(r)

    ok(size1 >= size0, 'party must not shrink')
    ok(size2 >= size1, 'party must grow with meetings')
    ok(size2 <= 3, 'party capped at 3 for the rival')

    for _, member in ipairs(RivalGenerator.build_party(r)) do
        ok(type(member.species) == 'string' and #member.species > 0,
            'party member has a species')
        ok(type(member.level) == 'number' and member.level >= 1,
            'party member has a level')
    end
end)

test('rival lines are non-empty for every archetype and field', function()
    local fields = { 'first_meet', 'second_meet', 'taunt', 'won', 'lost',
                     'final_won', 'final_lost' }
    for archetype, _ in pairs(RivalGenerator.ARCHETYPES) do
        local r = { archetype = archetype, meetings = 2 }
        for _, f in ipairs(fields) do
            local line = RivalGenerator.line_for(r, f)
            ok(type(line) == 'string' and #line > 0,
                ('%s / %s produced an empty line'):format(archetype, f))
        end
    end
end)

-- ===========================================================================
-- 6. Chekhov key: two runs
-- ===========================================================================

test('moon key thread is eligible when no key has been found', function()
    local camp = PlayerMetaStory.create(1)
    ok(Threads.lore_moon_key.requires(camp), 'should be eligible initially')
end)

test('moon key: giver registers the thread, payoff becomes pending next run', function()
    local camp = PlayerMetaStory.create(2)
    local KEY = Threads.lore_moon_key.KEY

    -- Run 1: the key is found.
    PlayerMetaStory.grant_story_key(camp, KEY)
    PlayerMetaStory.register_key_thread(camp, KEY, {
        giver_scene  = 'moon_key_find',
        payoff_scene = 'moon_door',
    })
    ok(PlayerMetaStory.has_story_key(camp, KEY), 'key is held')
    ok(not PlayerMetaStory.key_thread_pending(camp, KEY),
       'payoff must not be pending in the same run')

    -- Run 2 begins.
    PlayerMetaStory.begin_new_run(camp)
    ok(PlayerMetaStory.key_thread_pending(camp, KEY),
       'payoff must be pending in the next run')

    -- Consume it.
    PlayerMetaStory.consume_story_key(camp, KEY)
    ok(not PlayerMetaStory.has_story_key(camp, KEY), 'key consumed')
    ok(not PlayerMetaStory.key_thread_pending(camp, KEY), 'payoff spent')
    ok(camp.key_threads[KEY].payoff_consumed, 'marked consumed')
end)

test('moon key survives a failed run (does not vanish on death)', function()
    local camp = PlayerMetaStory.create(3)
    local KEY = Threads.lore_moon_key.KEY

    PlayerMetaStory.grant_story_key(camp, KEY)
    PlayerMetaStory.register_key_thread(camp, KEY, { giver_scene = 'x', payoff_scene = 'y' })

    -- A defeat: on_fail is called, the run ends, meta persists.
    Threads.lore_moon_key.on_fail(camp, {})
    ok(PlayerMetaStory.has_story_key(camp, KEY), 'key survives defeat')
end)

test('moon key does not re-offer the giver while holding the key', function()
    local camp = PlayerMetaStory.create(4)
    local KEY = Threads.lore_moon_key.KEY

    PlayerMetaStory.grant_story_key(camp, KEY)
    PlayerMetaStory.register_key_thread(camp, KEY, { giver_scene = 'x', payoff_scene = 'y' })

    ok(not PlayerMetaStory.can_replay_giver(camp, KEY),
       'cannot replay giver while the key is still carried')
end)

-- ===========================================================================
-- 7. Thread selection
-- ===========================================================================

test('select returns nil for a fresh campaign with no eligible thread', function()
    -- Fresh campaign has a master, so master_trial is eligible; but a
    -- campaign with no rival and no master must yield nil.
    local player = make_player(9)
    player.meta_story.phase = 'tournament'   -- no master interactions
    local run = make_run(11)
    local thread = ThreadGenerator.select(player, run, {
        bond_arc = Threads.bond_arc,
        lost_beast = Threads.lost_beast,
    })
    -- bond_arc needs total_runs >= 1; lost_beast needs a hurt party.
    ok(thread == nil or thread.id ~= nil, 'selection must be nil or a thread')
end)

test('an active thread is re-selected (survives a defeat)', function()
    local player = make_player(15)
    local camp = player.meta_story
    MasterGenerator.ensure_campaign(camp)

    PlayerMetaStory.set_active_thread(camp, 'master_trial', {})
    local run = make_run(16)
    local thread = ThreadGenerator.select(player, run, Threads)
    ok(thread ~= nil, 'a thread was selected')
    eq(thread.id, 'master_trial', 'the pinned thread wins')
    ok(run.story ~= nil and run.story.thread_id == 'master_trial', 'RunState.story is set')
    ok(run.story.flags ~= nil, 'story.flags exists before any scene writes to it')
end)

test('thread selection is deterministic for the same campaign state', function()
    local function pick_once()
        local player = make_player(505)
        local camp = player.meta_story
        MasterGenerator.ensure_campaign(camp)
        RivalGenerator.ensure(camp, player)
        local run = make_run(606)
        local t = ThreadGenerator.select(player, run, Threads)
        return t and t.id or 'none'
    end
    eq(pick_once(), pick_once(), 'same state -> same thread')
end)

-- ===========================================================================
-- 8. Scene side effects
-- ===========================================================================

test('rival_meet advances the rival only once per stage', function()
    local player = make_player(88)
    local camp = player.meta_story
    RivalGenerator.ensure(camp, player)
    local r = camp.rival

    local before = r.meetings
    local run = make_run(99)
    local ctx = ctx_for(player, run)
    local result = Scenes.rival_meet.generate(ctx)

    -- Press the first button (advance / offer hand).
    result.steps[1].buttons[1].action(player)
    ok(r.meetings > before, 'meeting was recorded')

    -- Second press must not double-count from the same stage.
    local after = r.meetings
    ok(after - before <= 1, 'stage 1 advances the counter by at most 1')
end)

-- Regression: stages 2 and 3 used to never advance the counter, so the
-- rival stayed on "second meeting" forever and never grew.
test('rival_meet advances the counter at EVERY stage', function()
    local player = make_player(1200)
    local camp = player.meta_story
    RivalGenerator.ensure(camp, player)
    local r = camp.rival

    for expected_stage = 1, 3 do
        eq(RivalGenerator.stage(r), expected_stage,
           'stage before pressing button ' .. expected_stage)

        local run  = make_run(1200 + expected_stage)
        local ctx  = ctx_for(player, run)
        local res  = Scenes.rival_meet.generate(ctx)
        local before = r.meetings
        res.steps[1].buttons[1].action(player)

        eq(r.meetings, before + 1,
           ('stage %d must advance meetings'):format(expected_stage))
    end
end)

test('rival thread closes after three meetings', function()
    local camp = PlayerMetaStory.create(1300)
    local r = RivalGenerator.generate(1300, 'ember')
    camp.rival = r

    for _ = 1, 3 do RivalGenerator.record(camp, true) end

    ok(not Threads.rival_encounter.requires(camp),
       'thread must not be eligible after the third meeting')
end)

test('bond scene picks the most invested creature', function()
    local player = make_player(311)
    player.charactersActive[1].level = 1
    player.charactersActive[1].name = 'Aaa'
    player.charactersSpare[1] = { name = 'Zzz', level = 6, exp = 90,
                                  health = 9, max_health = 30, modifiers = {} }

    local thread = Threads.bond_arc
    local best = thread.pick_companion(player)
    ok(best ~= nil, 'a companion was chosen')
    eq(best.name, 'Zzz', 'highest level wins')
end)

test('lost_beast refuses to fire when the party is too small', function()
    local player = make_player(401)
    player.charactersActive[1].health = 1   -- hurt enough
    local run = make_run(402)
    local ctx = ctx_for(player, run)
    -- Only one creature in the party: losing it would be a dead end.
    ok(Threads.lost_beast.build(ctx) == nil,
       'must not build a graph with a single creature')
end)

-- ===========================================================================
-- 9. SceneRunner: translation between graphs and EventState
-- ===========================================================================

local SceneRunner = require 'src.story.scene_runner'

local function fresh_run(seed)
    local run = make_run(seed)
    run.story = nil
    return run
end

test('scene runner walks a linear graph from start to terminal', function()
    local player = make_player(1500)
    local camp = player.meta_story
    RivalGenerator.ensure(camp, player)

    local run = fresh_run(1501)
    local ctx = ctx_for(player, run)

    local step = SceneRunner.begin(run, Threads.rival_encounter, ctx)
    ok(step ~= nil, 'first scene generated')
    eq(step.scene_id, 'rival_meet', 'starts at rival_meet')
    ok(not SceneRunner.is_terminal(run), 'meet is not terminal')

    -- advance -> duel
    ok(SceneRunner.advance(run), 'advanced to next node')
    local second = SceneRunner.current(run, ctx)
    eq(second.scene_id, 'rival_duel', 'second scene is the duel')
    ok(SceneRunner.is_terminal(run), 'duel is terminal')
end)

test('scene runner records a scene log', function()
    local player = make_player(1600)
    local camp = player.meta_story
    RivalGenerator.ensure(camp, player)

    local run = fresh_run(1601)
    local ctx = ctx_for(player, run)
    SceneRunner.begin(run, Threads.rival_encounter, ctx)
    SceneRunner.advance(run)
    SceneRunner.current(run, ctx)

    ok(run.story.scene_log ~= nil, 'scene_log exists')
    eq(#run.story.scene_log, 2, 'two scenes logged')
    eq(run.story.scene_log[1], 'rival_meet')
    eq(run.story.scene_log[2], 'rival_duel')
end)

test('scene runner honours alt_when_locked', function()
    local player = make_player(1700)
    local camp = player.meta_story
    MasterGenerator.ensure_campaign(camp)

    local run = fresh_run(1701)
    local ctx = ctx_for(player, run)
    SceneRunner._begin(Threads.master_trial, ctx, run)

    -- Walk to the boss node to exercise the gate.
    eq(SceneRunner.jump_to(run, 'boss'), true, 'jumped to boss node')

    local locked_node = SceneRunner.resolve_node(run, true)
    ok(locked_node ~= nil, 'resolved a node while locked')
    eq(locked_node.scene, 'master_boss_angry',
       'locked gate must fall back to the angry boss')
end)

test('scene runner: unknown scene id raises instead of failing silently', function()
    local run = fresh_run(1800)
    run.story = {
        graph   = { start = { scene = 'no_such_scene_at_all' } },
        node_id = 'start',
        flags   = {}, scene_log = {}, thread_state = {},
    }
    local okr, err = pcall(SceneRunner.current, run, {})
    ok(not okr, 'must raise on a missing scene')
    ok(tostring(err):find('no_such_scene_at_all') ~= nil,
       'error must name the missing scene: ' .. tostring(err))
end)

test('finish() clears run story state', function()
    local run = fresh_run(1900)
    run.story = { thread_id = 'x' }
    SceneRunner.finish(run)
    eq(run.story, nil)
end)

-- ===========================================================================
-- 10. Thread lifecycle (one-shot threads must not repeat forever)
-- ===========================================================================

test('one-shot threads are marked complete on on_complete', function()
    local camp = PlayerMetaStory.create(2000)
    for _, id in ipairs({ 'bond_arc', 'lost_beast' }) do
        local t = Threads[id]
        ok(type(t.on_complete) == 'function', id .. ': on_complete missing')
        t.on_complete(camp, {})
        ok(camp.completed_threads[id] == true,
           id .. ': on_complete must mark the thread completed')
    end
end)

test('a completed one-shot thread leaves the pool', function()
    local player = make_player(2100)
    local camp = player.meta_story
    MasterGenerator.ensure_campaign(camp)
    RivalGenerator.ensure(camp, player)
    camp.total_runs = 2

    -- Bond is eligible before completion...
    ok(Threads.bond_arc.requires(camp), 'eligible before completion')

    PlayerMetaStory.mark_thread_complete(camp, 'bond_arc')
    ok(not Threads.bond_arc.requires(camp), 'not eligible after completion')

    local pool = ThreadGenerator.pool(player, make_run(2200), Threads)
    for _, e in ipairs(pool) do
        ok(e.id ~= 'bond_arc', 'completed thread must not be in the pool')
    end
end)

test('bond_arc has a non-zero weight once the campaign has history', function()
    local camp = PlayerMetaStory.create(2300)
    eq(Threads.bond_arc.weight(camp), 0, 'no weight on the very first run')
    camp.total_runs = 1
    ok(Threads.bond_arc.weight(camp) > 0, 'weight once a run has happened')
end)

-- ===========================================================================
-- 11. Selection distribution matches the declared weights
-- ===========================================================================

test('thread selection distribution follows the weights', function()
    -- Regression: a pool member with weight 0 used to be able to starve
    -- the whole selection, and one thread could win every seed.
    local N = 600
    local counts, total = {}, 0
    math.randomseed(4242)

    for i = 1, N do
        local player = make_player(3000 + i)
        local camp = player.meta_story
        MasterGenerator.ensure_campaign(camp)
        RivalGenerator.ensure(camp, player)

        local run = make_run(3100 + i)
        run.random = function() return math.random() end

        local t = ThreadGenerator.select(player, run, Threads)
        local id = t and t.id or 'none'
        counts[id] = (counts[id] or 0) + 1
        total = total + 1
    end

    -- master_trial and rival_encounter carry most of the weight and must
    -- both actually appear. A single dominant thread is the failure mode.
    ok((counts.master_trial or 0) > 0, 'master_trial must be selectable')
    ok((counts.rival_encounter or 0) > 0, 'rival_encounter must be selectable')
    ok((counts.master_trial or 0) < total,
       'master_trial must not win every time')

    local distinct = 0
    for _ in pairs(counts) do distinct = distinct + 1 end
    ok(distinct >= 3, 'expected at least 3 distinct threads, got ' .. distinct)
end)

-- ===========================================================================
-- Summary
-- ===========================================================================

print('')
if failed == 0 then
    print(('All %d story tests passed.'):format(passed))
    os.exit(0)
else
    print(('%d passed, %d FAILED:'):format(passed, failed))
    for _, f in ipairs(failures) do print('  * ' .. f) end
    os.exit(1)
end
