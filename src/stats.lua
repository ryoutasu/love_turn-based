local Stats = Class{}

Stats.STATS = {
    'max_health', 'max_energy', 'damage', 'attack_range',
    'move_range', 'initiative', 'armor',
}

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
    local base = self.character[stat] or 0
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