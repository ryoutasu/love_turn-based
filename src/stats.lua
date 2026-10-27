local Stats = Class{}

-- Статы «абсолютного» типа: база 0, модификаторы складываются.
Stats.STATS = {
    'max_health', 'max_energy', 'damage', 'attack_range',
    'move_range', 'initiative', 'armor',
}

-- Статы-МНОЖИТЕЛИ: база 1, модификаторы перемножаются.
-- Если для них использовать базу 0 (как раньше), то любой `mul`
-- превращался в 0 — именно поэтому `spell_power` был мёртвым статом:
-- spell_power = (0 + 0) * 1.15 = 0, и урон от заклинаний обнулялся.
Stats.MULTIPLIER_STATS = {
    'spell_power',
    'armor_pierce',   -- это доля, база 0 — но задаётся через DEFAULTS ниже
    'percent_hp_damage',
}

-- Значения по умолчанию для статов, которых нет в шаблоне персонажа.
-- Ключевое: всё, что дальше умножается, должно стартовать с 1.
Stats.DEFAULTS = {
    spell_power       = 1,
    armor             = 0,
    armor_pierce      = 0,
    percent_hp_damage = 0,
    -- resist_<element> читается калькулятором как `or 0`; здесь не нужны.
}

-- Динамические статы вида `resist_ember` / `spell_power_ember`.
-- База 0 для resist_* (это доля снижения) и 1 для spell_power_*.
local DYNAMIC_DEFAULTS = {
    { prefix = 'resist_',      base = 0 },
    { prefix = 'spell_power_', base = 1 },
}

local function defaultFor(stat)
    local d = Stats.DEFAULTS[stat]
    if d ~= nil then return d end
    for _, entry in ipairs(DYNAMIC_DEFAULTS) do
        if stat:sub(1, #entry.prefix) == entry.prefix then
            return entry.base
        end
    end
    return 0
end

function Stats:init(character, runModifiers, battleModifiers)
    self.character = character
    self.runModifiers = runModifiers or {}
    self.battleModifiers = battleModifiers or {}
    self.cache = {}
    self.byStat = {}
    self:rebuildIndex()
end

function Stats:rebuildIndex()
    self.byStat = {}
    local function index(m)
        local list = self.byStat[m.stat]
        if not list then list = {}; self.byStat[m.stat] = list end
        list[#list+1] = m
    end
    for _, m in ipairs(self.character.modifiers or {}) do index(m) end
    for _, m in ipairs(self.runModifiers) do index(m) end
    for _, m in ipairs(self.battleModifiers) do index(m) end
end

function Stats:get(stat)
    local v = self.cache[stat]
    if v ~= nil then return v end
    v = self:_compute(stat)
    self.cache[stat] = v
    return v
end

function Stats:all()
    local out = {}
    for _, stat in ipairs(Stats.STATS) do
        out[stat] = self:get(stat)
    end
    return out
end

function Stats:invalidate()
    self.cache = {}
    self:rebuildIndex()
end

function Stats:invalidateStat(stat)
    self.cache[stat] = nil
end

function Stats:_compute(stat)
    -- База: поле персонажа, иначе разумный дефолт (1 для множителей).
    -- Раньше отсутствующий стат давал 0, и `mul`-модификатор обнулял его:
    -- spell_power = (0 + 0) * 1.15 = 0, то есть заклинания не наносили урон.
    local base = self.character[stat]
    if base == nil then base = defaultFor(stat) end
    local add, mul, set = 0, 1, nil

    for _, m in ipairs(self.byStat[stat] or {}) do
        if m.filter and not m.filter(self.character) then goto continue end
        if m.op == 'add' then add = add + m.value
        elseif m.op == 'mul' then mul = mul * m.value
        elseif m.op == 'set' then set = m.value end
        ::continue::
    end

    if set then return set end
    return (base + add) * mul
end

return Stats