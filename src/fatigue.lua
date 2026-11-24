-- src/fatigue.lua
--
-- Fatigue system rules and arithmetic. The value itself lives on Character
-- (`character.fatigue`, 0..FATIGUE_MAX) and is persisted through
-- Character.serialize — this module only owns the constants and the policy.
--
-- No LÖVE dependencies: the whole module is pure so that it can be exercised
-- headlessly by tests/smoke_fatigue.lua.

local Fatigue = {}

-- The only threshold. Every check (spawn filter, run-end rule, UI) compares
-- against this constant; no literal 100 anywhere else.
Fatigue.MAX = 100

-- Fatigue gained when a node closes. `boss` is the master-boss battle, which
-- is heavier than a regular fight.
Fatigue.GAIN = {
    win   = 10,
    lose  = 15,
    event = 5,
    rest  = 0,
    shop  = 0,
    boss  = 20,
}

-- Fatigue relieved by the rest node's healing choice.
Fatigue.REST_RELIEF = 30

-- Spare creatures gain a share of the party's fatigue, rounded up
-- (ceil(value * 0.5)).
Fatigue.SPARE_FACTOR = 0.5

-- ------------------------------------------------------------------
-- Value helpers
-- ------------------------------------------------------------------

function Fatigue.clamp(value)
    value = math.floor(tonumber(value) or 0)
    if value < 0 then return 0 end
    if value > Fatigue.MAX then return Fatigue.MAX end
    return value
end

function Fatigue.get(character)
    if not character then return 0 end
    return Fatigue.clamp(character.fatigue or 0)
end

--- Adds fatigue, clamped to [0, MAX]. Returns the new value.
function Fatigue.gain(character, amount)
    if not character then return 0 end
    local value = Fatigue.clamp((character.fatigue or 0) + (amount or 0))
    character.fatigue = value
    return value
end

--- Removes fatigue, clamped to [0, MAX]. Returns the new value.
function Fatigue.relieve(character, amount)
    return Fatigue.gain(character, -(amount or 0))
end

function Fatigue.isExhausted(character)
    return Fatigue.get(character) >= Fatigue.MAX
end

-- ------------------------------------------------------------------
-- Party rules
-- ------------------------------------------------------------------

--- Everyone who can step into battle: active slots plus spare slots.
--- Stables are excluded on purpose — they never fight, so counting them
--- would make the "everyone exhausted" rule unreachable.
function Fatigue.party(player)
    local list = {}
    if not player then return list end

    for i = 1, player.charactersActiveSize or 0 do
        local c = player.charactersActive and player.charactersActive[i]
        if c then table.insert(list, c) end
    end
    for i = 1, player.charactersSpareSize or 0 do
        local c = player.charactersSpare and player.charactersSpare[i]
        if c then table.insert(list, c) end
    end

    return list
end

--- True when the party has at least one creature and all of them are spent.
--- An empty party is not "exhausted" — that is a different failure.
function Fatigue.isPartyExhausted(player)
    local list = Fatigue.party(player)
    if #list == 0 then return false end

    for _, c in ipairs(list) do
        if not Fatigue.isExhausted(c) then return false end
    end
    return true
end

--- True when at least one creature can be deployed into a battle.
function Fatigue.hasFighter(player)
    for _, c in ipairs(Fatigue.party(player)) do
        if not Fatigue.isExhausted(c) then return true end
    end
    return false
end

-- ------------------------------------------------------------------
-- Awarding
-- ------------------------------------------------------------------

--- Applies `amount` to one creature: full weight when it is in the active
--- party, ceil(amount * SPARE_FACTOR) when it is a spare.
function Fatigue.gainFor(player, character, amount)
    if not character or not amount or amount == 0 then return 0 end

    local is_active = false
    for i = 1, player and player.charactersActiveSize or 0 do
        if player.charactersActive and player.charactersActive[i] == character then
            is_active = true
            break
        end
    end

    local share = amount
    if not is_active then
        share = math.ceil(amount * Fatigue.SPARE_FACTOR)
    end
    return Fatigue.gain(character, share)
end

local NODE_KEY = {
    win   = 'win',
    lose  = 'lose',
    event = 'event',
    rest  = 'rest',
    shop  = 'shop',
    boss  = 'boss',
}

--- Amount active creatures take for a node key. Unknown keys fall back to
--- 'event' instead of being dropped: a silent 0 for a mistyped key is
--- invisible in play and in tests.
function Fatigue.amountFor(key)
    local base = Fatigue.GAIN[NODE_KEY[key] or NODE_KEY.event]
    return base or 0
end

--- Awards fatigue for one closed node to everyone in the party.
--- `key` is one of 'win' | 'lose' | 'event' | 'rest' | 'shop' | 'boss'.
--- Returns the amount granted to active creatures (0 if nothing was granted).
function Fatigue.applyNode(player, key)
    local base = Fatigue.amountFor(key)
    if base == 0 then return 0 end

    for _, c in ipairs(Fatigue.party(player)) do
        Fatigue.gainFor(player, c, base)
    end
    return base
end

--- Relieves fatigue for the whole party (rest node).
function Fatigue.relieveParty(player, amount)
    if not amount or amount == 0 then return end
    for _, c in ipairs(Fatigue.party(player)) do
        Fatigue.relieve(c, amount)
    end
end

return Fatigue
