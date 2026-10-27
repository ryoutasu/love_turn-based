-- Deterministic rival generator.
--
-- In monster-taming games the rival is the single most reliable narrative
-- device (Blue/Gary Oak, Silver, Hop, Shauna). It works because it is the
-- SAME person across the whole campaign: they take the creature you did not
-- take, they grow with you, and they remember how you beat them.
--
-- Rules that keep the drama intact:
--   * generated ONCE per campaign from campaign_seed (never re-rolled per run);
--   * strength tiers up with `meetings` (they progress too);
--   * element/attribute are the OPPOSITE-ish of the player's starters so
--     fights feel personal, not random.
--
-- No Love2D / global math.random dependencies: Park-Miller PRNG, like
-- master_generator.lua, so the rival is reproducible from the save alone.

local RivalGenerator = {}

-- ===========================================================================
-- PRNG (same algorithm as master_generator, kept local for independence)
-- ===========================================================================

local function make_rng(seed)
    local state = math.floor(math.abs(seed or 1)) % 2147483647
    if state == 0 then state = 1 end
    local rng = {}
    function rng:next()
        state = (state * 16807) % 2147483647
        return (state - 1) / 2147483646
    end
    function rng:random(a, b)
        if a and b then return math.floor(a + self:next() * (b - a + 1))
        elseif a     then return math.floor(self:next() * a) + 1
        else              return self:next() end
    end
    return rng
end

RivalGenerator.make_rng = make_rng

-- ===========================================================================
-- Archetypes
-- ===========================================================================
-- `attitude` drives how they speak to us at each meeting stage.
-- Each archetype is a different *relationship*, not just a tone:
--   eager   вЂ” wants to be your friend, competes to be seen
--   proud   вЂ” sees you as a stepping stone, softens only after losing
--   gentle  вЂ” kind, hides a competitive streak
--   feral   вЂ” raised by beasts, barely speaks, respects strength only

local ARCHETYPES = {
    eager = {
        weight = 3,
        names = { 'Kae', 'Toma', 'Nila', 'Rui', 'Sen' },
        first_meet = {
            "Wait вЂ” you're starting too? Then we're the same. That means we're rivals. That's how it works, right?",
            "I already picked mine. Don't lag behind, okay? I don't want to win against nobody.",
        },
        second_meet = {
            "You again! I've been training. Look, look вЂ” it grew!",
            "I was hoping I'd run into you. No, really. It's boring when you're not there.",
        },
        taunt = {
            "I'm not scared of you. I'm a little scared of you.",
            "This is the part where I win, right?",
        },
        won = {
            "Yes! Yes! ...Sorry. I was loud.",
            "I did it! Don't be mad. Be mad a little.",
        },
        lost = {
            "Okay. Okay. You're stronger. That's fine. That's FINE.",
            "I lost. I'm not crying. My beast is crying.",
        },
        final_won = {
            "So that's it. ...I'll see you at the top of this. I mean it.",
        },
        final_lost = {
            "You go on ahead. I'll catch up. I always do.",
        },
    },

    proud = {
        weight = 3,
        names = { 'Vex', 'Auren', 'Sabine', 'Kell', 'Maren' },
        first_meet = {
            "You took that one? Hm. I took the better one. Remember that when you lose.",
            "Another hopeful. Try not to disappoint me early вЂ” it's tedious.",
        },
        second_meet = {
            "You're still alive. I suppose that counts for something.",
            "I've heard your name twice now. Twice is a pattern.",
        },
        taunt = {
            "You fight like someone who reads the manual.",
            "Show me the thing that beat the last one.",
        },
        won = {
            "As predicted. Go home and think about it.",
            "I expected more. That is the kindest thing I can say.",
        },
        lost = {
            "...Again. And again until I beat you properly.",
            "That was not luck. I am aware. Do not look so pleased.",
        },
        final_won = {
            "Stay there, in front of me. Where I can see you.",
        },
        final_lost = {
            "Then I was wrong about one thing. Only one.",
        },
    },

    gentle = {
        weight = 2,
        names = { 'Hina', 'Ody', 'Lis', 'Wren', 'Iva' },
        first_meet = {
            "Oh вЂ” you have one too! Do they get along? Mine's shy.",
            "Hello. I'm not very good at this yet. But I'm trying.",
        },
        second_meet = {
            "I've been thinking about you. Is that strange? It's strange.",
            "You look tired. You should rest more. Then fight me.",
        },
        taunt = {
            "I don't want to hurt yours. But I will, a little.",
            "Please take this seriously. Please.",
        },
        won = {
            "Oh! I... won? That's new.",
            "Sorry. Truly. Your beast was wonderful.",
        },
        lost = {
            "Thank you for not going easy on me.",
            "...That hurt more than I expected.",
        },
        final_won = {
            "I'll keep going. Because you did.",
        },
        final_lost = {
            "Be careful out there. I mean it more than you know.",
        },
    },

    feral = {
        weight = 1,
        names = { 'Ash', 'Grit', 'Rook', 'Fen' },
        first_meet = {
            "You smell of beasts. Good. So do I.",
            "The road is thin here. Speak with claws.",
        },
        second_meet = {
            "You again. I remember your wolf.",
            "Strong now. Still hungry?",
        },
        taunt = {
            "Less words.",
            "Bite.",
        },
        won = {
            "Good. Painful. Good.",
            "Now you learn. That is how it works.",
        },
        lost = {
            "You bit hard. I respect that.",
            "...I will remember your face.",
        },
        final_won = {
            "Now you are worth following.",
        },
        final_lost = {
            "Run. Or stay. Both are fine.",
        },
    },
}

local ARCHETYPE_KEYS = { 'eager', 'proud', 'gentle', 'feral' }

-- Rival's element/attribute pair opposes the player's first starter,
-- so that the first clash feels designed rather than random.
local ELEMENT_OPPOSITE = {
    ember = 'water', water = 'storm', storm = 'earth',
    earth = 'plant', plant = 'ember', light = 'dark', dark = 'light',
}

-- Attributes the rival can champion. Only ones with real creatures in the
-- bestiary: choosing `mechanic` today would leave the party empty
-- (see SPECIES_POOL).
local RIVAL_ATTRIBUTES = { 'wild', 'mystic' }

local SURNAMES = {
    'Adair', 'Bram', 'Corvin', 'Dara', 'Ennis', 'Fenwick',
    'Gallow', 'Hark', 'Ilsa', 'Jorr', 'Mera', 'Nyx',
}

-- Species pool reused from masters so the rival fields creatures that
-- actually exist in the game's bestiary.
local SPECIES_POOL = {
    wild     = { 'Emberpuff', 'Dewscale', 'Leafen', 'Quillpaw', 'Terrow',
                 'Frostling', 'Mystwing', 'Nightshade' },
    mystic   = { 'Aetheris', 'Blazeflare', 'Brambleclaw', 'Flarevine',
                 'Marilix', 'Rockjaw', 'Sylphine', 'Tempira', 'Voltling' },
    mechanic = {},
}

-- Exposed so battle setup can map a generated party descriptor to a creature
-- that actually exists in the bestiary (BattleState:_spawn_enemy_from_descriptor).
RivalGenerator.SPECIES_POOL = SPECIES_POOL

local function pick(rng, list)
    return list[rng:random(1, #list)]
end

local function pick_weighted(rng, dict, keys)
    local total = 0
    for _, k in ipairs(keys) do total = total + (dict[k].weight or 1) end
    local r = rng:next() * total
    for _, k in ipairs(keys) do
        r = r - (dict[k].weight or 1)
        if r <= 0 then return k, dict[k] end
    end
    local last = keys[#keys]
    return last, dict[last]
end

local function species_for(attribute)
    local pool = SPECIES_POOL[attribute]
    if pool and #pool > 0 then return pool end
    -- Fall back to every known species, sorted for determinism.
    local all = {}
    for _, list in pairs(SPECIES_POOL) do
        for _, s in ipairs(list) do all[#all + 1] = s end
    end
    table.sort(all)
    if #all == 0 then return { 'Dewscale' } end
    return all
end

-- ===========================================================================
-- Generation
-- ===========================================================================

--- Build a rival for a campaign.
--- @param seed      number   campaign_seed (or derived)
--- @param player_element string|nil player's first starter element, for opposition
function RivalGenerator.generate(seed, player_element)
    local rng = make_rng(seed)

    local arch_id, arch = pick_weighted(rng, ARCHETYPES, ARCHETYPE_KEYS)

    local given  = pick(rng, arch.names)
    local family = pick(rng, SURNAMES)

    -- Travel gear colour: pure flavour, but gives the UI something to show.
    local element = player_element and ELEMENT_OPPOSITE[player_element]
    if not element then
        local all = { 'ember', 'water', 'earth', 'storm', 'light', 'dark', 'plant' }
        element = pick(rng, all)
    end

    -- Attribute: only pick ones that have real species in the bestiary.
    -- (mechanic has no creatures yet вЂ” choosing it would force the fallback
    -- pool and make every rival look identical.)
    local attribute = pick(rng, RIVAL_ATTRIBUTES)

    local species = pick(rng, species_for(attribute))

    return {
        id        = 'rival',
        seed      = seed,
        name      = given .. ' ' .. family,
        archetype = arch_id,
        element   = element,
        attribute = attribute,
        ace_species = species,

        -- Progress: how many times we have met, who won each time.
        meetings  = 0,          -- number of encounters played
        wins      = 0,          -- rival's wins against the player
        losses    = 0,          -- player's wins
        history   = {},         -- [i] = 'won' | 'lost'  (rival's perspective)

        -- The creature they took at the start (shown in the first scene).
        starter   = species,

        met_in_run = nil,
    }
end

--- Lazily create the rival for a campaign, reusing campaign_seed.
function RivalGenerator.ensure(camp, player)
    if type(camp) ~= 'table' then return nil end
    if camp.rival then return camp.rival end

    -- Derive a distinct seed so the rival is not correlated with masters.
    local base = (camp.campaign_seed or 1) * 7919 % 2147483647

    local element
    if player and player.charactersActive then
        local first = player.charactersActive[1]
        element = first and first.element or nil
    end

    camp.rival = RivalGenerator.generate(base, element)
    return camp.rival
end

--- Difficulty tier for the next encounter: they grow with meetings.
function RivalGenerator.tier(rival)
    if not rival then return 1 end
    local t = 1 + (rival.meetings or 0) * 2
    if t > 8 then t = 8 end
    return t
end

--- Which stage the next meeting is at.
--- 1 = first meeting (no battle yet), 2 = second, 3 = final.
function RivalGenerator.stage(rival)
    local m = (rival and rival.meetings) or 0
    if m <= 0 then return 1 end
    if m == 1 then return 2 end
    return 3
end

--- Party descriptors for a rival battle at the current tier.
function RivalGenerator.build_party(rival)
    if not rival then return {} end
    local tier = RivalGenerator.tier(rival)
    local rng  = make_rng((rival.seed or 1) + (rival.meetings or 0) * 104729)

    local party = {}
    local size  = math.min(1 + rival.meetings, 3)
    local pool  = species_for(rival.attribute)

    for i = 1, size do
        local is_ace = (i == size)
        party[i] = {
            species   = is_ace and rival.ace_species or pick(rng, pool),
            attribute = rival.attribute,
            element   = is_ace and rival.element or pick(rng, { 'ember','water','earth','storm','light','dark','plant' }),
            level     = tier,
        }
    end
    return party
end

-- ===========================================================================
-- Memory
-- ===========================================================================

--- Record the outcome of an encounter. `player_won` = true if the player won.
function RivalGenerator.record(camp, player_won)
    local r = camp and camp.rival
    if not r then return end

    r.meetings = (r.meetings or 0) + 1
    if player_won then
        r.losses = (r.losses or 0) + 1
        r.history[#r.history + 1] = 'lost'
    else
        r.wins = (r.wins or 0) + 1
        r.history[#r.history + 1] = 'won'
    end
end

--- Pick a line for the current stage, honouring who has been winning.
--- field: 'first_meet' | 'second_meet' | 'taunt' | 'won' | 'lost' |
---        'final_won' | 'final_lost'
function RivalGenerator.line_for(rival, field)
    if not rival then return '...' end
    local arch = ARCHETYPES[rival.archetype] or ARCHETYPES.eager
    local lines = arch[field] or arch.taunt or { '...' }

    -- Deterministic pick, salted by how many meetings happened so the
    -- same NPC does not repeat the same line every run.
    local n = #lines
    if n == 0 then return '...' end
    local idx = ((rival.meetings or 0) + string.len(field)) % n + 1
    return lines[idx]
end

--- Human-readable summary of the rivalry, for a journal/debug screen.
function RivalGenerator.summary(rival)
    if not rival then return 'No rival yet.' end
    return ('%s (%s) вЂ” met %d, beat you %d, lost to you %d | ace: %s')
        :format(rival.name, rival.archetype, rival.meetings or 0,
                rival.wins or 0, rival.losses or 0, tostring(rival.ace_species))
end

RivalGenerator.ARCHETYPES = ARCHETYPES
RivalGenerator.ELEMENT_OPPOSITE = ELEMENT_OPPOSITE

return RivalGenerator
