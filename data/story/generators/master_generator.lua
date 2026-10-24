-- Deterministic master generator. No Love2D / global math.random dependencies.
-- Self-contained Park-Miller PRNG for reproducibility.

local MasterGenerator = {}

-- ===========================================================================
-- PRNG (Park-Miller minimal standard)
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

-- ===========================================================================
-- Data banks
-- ===========================================================================

local ARCHETYPES = {
    stern = {
        weight = 3,
        greetings = {
            "Silence and listen. Here, the beasts speak — not the men.",
            "Another one. Show me what you know, or leave.",
            "You came for mastery. Mastery comes through pain.",
        },
        taunts = {
            "Too slow.",
            "Your beast fears you. I can feel it.",
            "You think, but you do not feel.",
        },
        defeat = {
            "Hmph. You are not as empty as you seemed.",
            "Remember this feeling. It will not last.",
        },
        victory = {
            "Go. Come back when you have learned.",
            "Do not return until you understand why you are here.",
        },
        rematch = {
            "You are here again. I was waiting.",
            "Last time you left with nothing. Today — differently?",
            "Your eyes have changed. Show me what changed inside.",
        },
    },
    warm = {
        weight = 2,
        greetings = {
            "Ah, a guest! Come in. Tea? And a blade, too.",
            "Glad to see a new face. Tired from the road?",
        },
        taunts = { "Easy, easy. Do not rush.", "Good, good. Again?" },
        defeat = { "Beautiful. Simply beautiful.", "You found your rhythm." },
        victory = { "Come back whenever you wish.", "Rest. The world can wait." },
        rematch = { "You have changed, I see.", "You again! Wonderful, wonderful." },
    },
    trickster = {
        weight = 2,
        greetings = {
            "Bets are placed. What are we playing for?",
            "Ooh, fresh blood. Or fresh coin?",
        },
        taunts = { "Already lost. Not noticed yet?", "Ooh, shiny key!" },
        defeat = { "Clever. Clever.", "You played by your own rules. I like that." },
        victory = { "Amusing. Come again.", "You owe me. Joking. Or not." },
        rematch = { "You owe me.", "Well then. Will you win it back?" },
    },
    stoic = {
        weight = 2,
        greetings = { "...", "You came. Enter." },
        taunts = { "...", "Hm." },
        defeat = { "...", "Worthy." },
        victory = { "...", "Go." },
        rematch = { "You have returned.", "..." },
    },
    wild = {
        weight = 1,
        greetings = {
            "HA! Beast! A beast with you!",
            "I smell the road on you. Good!",
        },
        taunts = { "Weak!", "AGAIN!" },
        defeat = { "Good! VERY good!", "You are a beast!" },
        victory = { "AGAIN! Come back!", "Run! Grow! Return!" },
        rematch = { "You returned! AGAIN!", "The beast has grown!" },
    },
}

local ARCHETYPE_KEYS = { 'stern', 'warm', 'trickster', 'stoic', 'wild' }

local SYLLABLES = {
    'ka','ri','to','ma','shi','nu','ho','ze','ra','vo',
    'ae','mi','su','ke','ru','ta','no','se','ya','fu',
}
local SURNAMES = {
    'Inoue','Tanaka','Sato','Yamada','Kuroda','Ozawa','Mori',
    'Kimura','Hoshi','Kondo','Abe','Ito','Nakamura','Kobayashi','Kato',
}
local DOJO_WORDS = {
    'Winds','Ash','Mist','Moon','Steel','Tide','Thunder',
    'Moss','Glass','Shadow','Fire','Stone','Frost','Dawn','Silence',
}
local TITLES     = {'Master','Sensei','Keeper','Mentor','Lord','Lady'}
local ELEMENTS   = {'ember','water','earth','storm','light','dark','plant'}
local ATTRIBUTES = {'wild','mystic','mechanic'}

local SPECIES_POOL = {
    wild     = {'wild_wolf','wild_bear','wild_boar','wild_hawk'},
    mystic   = {'mystic_wisp','mystic_seer','mystic_wraith','mystic_owl'},
    mechanic = {'mech_drone','mech_golem','mech_spider','mech_sentry'},
}

-- ===========================================================================
-- Helpers
-- ===========================================================================

local function pick(rng, list)
    return list[rng:random(1, #list)]
end

local function capitalize(s)
    return s:sub(1,1):upper() .. s:sub(2)
end

local function pick_weighted(rng, dict, ordered_keys)
    local total = 0
    for _, k in ipairs(ordered_keys) do
        total = total + (dict[k].weight or 1)
    end
    local r = rng:next() * total
    for _, k in ipairs(ordered_keys) do
        r = r - (dict[k].weight or 1)
        if r <= 0 then return k, dict[k] end
    end
    local last = ordered_keys[#ordered_keys]
    return last, dict[last]
end

-- ===========================================================================
-- Party builder (descriptors; convert to Units at battle setup)
-- ===========================================================================

function MasterGenerator.build_party(rng, attribute, element, tier)
    tier = tier or 1
    local size = 4 + rng:random(0, 2)
    local party = {}

    for i = 1, size do
        local is_ace = (i == size)
        local pool = SPECIES_POOL[attribute]
        if not pool then
            pool = {}
            for _, list in pairs(SPECIES_POOL) do
                for _, s in ipairs(list) do pool[#pool + 1] = s end
            end
            table.sort(pool)
        end

        party[i] = {
            species   = pool[rng:random(1, #pool)],
            attribute = attribute,
            element   = is_ace and element or pick(rng, ELEMENTS),
            level     = tier,
        }
    end

    return party
end

-- ===========================================================================
-- Single master
-- ===========================================================================

function MasterGenerator.generate(seed, id, tier)
    tier = tier or 1
    local rng = make_rng(seed)
    local arch_id, arch = pick_weighted(rng, ARCHETYPES, ARCHETYPE_KEYS)

    local given = SYLLABLES[rng:random(1, #SYLLABLES)]
               .. SYLLABLES[rng:random(1, #SYLLABLES)]
    given = capitalize(given)

    local element   = pick(rng, ELEMENTS)
    local attribute = pick(rng, ATTRIBUTES)

    return {
        id    = id,
        seed  = seed,
        tier  = tier,

        name      = given .. ' ' .. pick(rng, SURNAMES),
        title     = pick(rng, TITLES),
        dojo_name = 'Dojo of ' .. pick(rng, DOJO_WORDS),

        archetype = arch_id,
        element   = element,
        attribute = attribute,

        battle_party = MasterGenerator.build_party(rng, attribute, element, tier),

        lines = {
            greeting = pick(rng, arch.greetings),
            taunt    = pick(rng, arch.taunts),
            defeat   = pick(rng, arch.defeat),
            victory  = pick(rng, arch.victory),
            rematch  = pick(rng, arch.rematch or arch.greetings),
        },

        attempts = 0,
        defeats  = 0,
        defeated = false,
        first_met_run = nil,
    }
end

-- ===========================================================================
-- Campaign-level
-- ===========================================================================

local function next_seed(rng)
    return rng:random(1, 2147483646)
end

function MasterGenerator.ensure_campaign(camp)
    if type(camp) ~= 'table' then return camp end
    camp.masters = camp.masters or {}
    camp.masters_required = camp.masters_required or 8

    local rng = make_rng(camp.campaign_seed)

    for i = 1, camp.masters_required do
        local id = 'master_' .. i
        if not camp.masters[id] then
            local seed = next_seed(rng)
            camp.masters[id] = MasterGenerator.generate(seed, id, i)
        end
    end

    if not camp.current_master_id then
        for i = 1, camp.masters_required do
            local id = 'master_' .. i
            if not camp.masters[id].defeated then
                camp.current_master_id = id
                break
            end
        end
    end

    return camp
end

function MasterGenerator.current(camp)
    if not camp or not camp.current_master_id then return nil end
    return camp.masters[camp.current_master_id]
end

function MasterGenerator.on_defeat(camp, master_id)
    master_id = master_id or camp.current_master_id
    local m = camp.masters[master_id]
    if not m then return end
    m.attempts = m.attempts + 1
    m.defeats  = m.defeats + 1
end

function MasterGenerator.on_victory(camp, master_id)
    master_id = master_id or camp.current_master_id
    local m = camp.masters[master_id]
    if not m then return end

    m.attempts = m.attempts + 1
    m.defeated = true
    camp.masters_defeated = (camp.masters_defeated or 0) + 1

    if camp.masters_defeated >= camp.masters_required then
        camp.current_master_id = nil
        camp.phase = 'tournament'
    else
        for i = 1, camp.masters_required do
            local id = 'master_' .. i
            if not camp.masters[id].defeated then
                camp.current_master_id = id
                break
            end
        end
    end
end

-- Memory-aware line accessor. Scenes call this instead of master.lines.greeting
-- when they want the "you've been here before" flavour.
-- field: 'greeting' | 'taunt' | 'defeat' | 'victory'
function MasterGenerator.line_for(master, camp, field)
    local memory = (camp and camp.masters and camp.masters[master.id]) or master

    if field == 'greeting' and memory and memory.defeats and memory.defeats > 0 then
        return master.lines.rematch
    end

    return master.lines[field] or '...'
end

return MasterGenerator