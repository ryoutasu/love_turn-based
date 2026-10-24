local Character = require 'src.character'
local Upgrades = require 'data.upgrades'

local RunState = {
    active = false,
    seed = nil,
    rng = nil,             -- love.math.newRandomGenerator
    player = nil,

    modifiers = {},        -- run-scope модификаторы (Stats получает их как runModifiers)
    unlocks = {},          -- { [key] = true } — флаги для UI и логики
    hooks = {},            -- { [upgrade_id] = { on_battle_start = fn, ... } }
    conditionals = {},     -- { [upgrade_id] = upgrade } — synergy-апгрейды
    active_conditions = {},-- { [upgrade_id] = true } — какие сейчас активны
    applied_upgrades = {}, -- { [upgrade_id] = count }
}

-- ------------------------------------------------------------------
-- Жизненный цикл
-- ------------------------------------------------------------------

function RunState:reset(player, seed)
    self.active  = true
    self.player  = player
    self.seed    = seed or love.math.random(1, 2^31 - 1)
    self.rng     = love.math.newRandomGenerator(self.seed)

    self.modifiers         = {}
    self.unlocks           = {}
    self.hooks             = {}
    self.conditionals      = {}
    self.active_conditions = {}
    self.applied_upgrades  = {}
end

function RunState:endRun()
    self.active = false
end

function RunState:isActive() return self.active end
function RunState:getSeed()  return self.seed   end
function RunState:getPlayer() return self.player end

-- ------------------------------------------------------------------
-- RNG (воспроизводимый)
-- ------------------------------------------------------------------

function RunState:random()
    return self.rng:random()
end

function RunState:randomInt(min, max)
    return self.rng:random(min, max)
end

function RunState:pick(list)
    if #list == 0 then return nil end
    return list[self.rng:random(#list)]
end

function RunState:weightedPick(entries)
    -- entries = { { value, weight }, ... }
    local total = 0
    for _, e in ipairs(entries) do total = total + e[2] end
    if total <= 0 then return nil end

    local r = self.rng:random() * total
    local acc = 0
    for _, e in ipairs(entries) do
        acc = acc + e[2]
        if r <= acc then return e[1] end
    end
    return entries[#entries][1]
end

-- ------------------------------------------------------------------
-- Stats
-- ------------------------------------------------------------------

function RunState:getStat(name)
    if not self.active then return 0, 1 end
    local add_sum, mul_prod = 0, 1
    for _, m in ipairs(self.modifiers) do
        if m.stat == name and not m.filter then
            if m.op == 'add' then
                add_sum = add_sum + m.value
            elseif m.op == 'mul' then
                mul_prod = mul_prod * m.value
            end
        end
    end
    return add_sum, mul_prod
end

-- ------------------------------------------------------------------
-- Модификаторы
-- ------------------------------------------------------------------

function RunState:addModifier(mod)
    table.insert(self.modifiers, mod)
end

function RunState:addModifiers(list)
    for _, m in ipairs(list) do
        table.insert(self.modifiers, m)
    end
end

function RunState:removeModifierById(id)
    for i = #self.modifiers, 1, -1 do
        local m = self.modifiers[i]
        if m.id == id then
            table.remove(self.modifiers, i)
            if m.on_expire then m.on_expire(self.player, m) end
        end
    end
end

function RunState:getModifiers()
    return self.modifiers
end

-- Вызывать при выходе из боя (в Levelmap:resume или BattleState:showResult)
function RunState:tickBattleModifiers()
    for i = #self.modifiers, 1, -1 do
        local m = self.modifiers[i]
        local d = m.duration
        if d and d.type == 'battle' then
            d.value = d.value - 1
            if d.value <= 0 then
                table.remove(self.modifiers, i)
                if m.on_expire then m.on_expire(self.player, m) end
            end
        end
    end
end

-- ------------------------------------------------------------------
-- Unlocks
-- ------------------------------------------------------------------

function RunState:addUnlock(key, count)
    self.unlocks[key] = (self.unlocks[key] or 0) + (count or 1)
end

function RunState:hasUnlock(key)
    return (self.unlocks[key] or 0) > 0
end

function RunState:getUnlockCount(key)
    return self.unlocks[key] or 0
end

function RunState:consumeUnlock(key, count)
    count = count or 1
    if (self.unlocks[key] or 0) < count then return false end
    self.unlocks[key] = self.unlocks[key] - count
    return true
end

-- ------------------------------------------------------------------
-- Hooks
-- ------------------------------------------------------------------

-- Регистрируем набор хуков одного апгрейда
function RunState:registerHooks(upgradeId, hooks)
    self.hooks[upgradeId] = hooks
end

-- Вызываем все хуки с заданным именем. Пример:
--   RunState:fireHook('on_battle_start', battle)
--   RunState:fireHook('on_damage_taken', target, element)
function RunState:fireHook(name, ...)
    for _, hooks in pairs(self.hooks) do
        local fn = hooks[name]
        if fn then fn(...) end
    end
end

-- ------------------------------------------------------------------
-- Применение апгрейдов
-- ------------------------------------------------------------------

function RunState:hasUpgrade(id)
    return (self.applied_upgrades[id] or 0) > 0
end

-- target — обязателен только для апгрейдов с up.target == 'single'
function RunState:applyUpgrade(id, target)
    local up = Upgrades[id]
    if not up then
        error('Unknown upgrade: ' .. tostring(id))
    end

    self.applied_upgrades[id] = (self.applied_upgrades[id] or 0) + 1

    -- 1. Модификаторы
    if up.mods and #up.mods > 0 then
        if up.target == 'single' then
            if not target then
                error('Upgrade "'..id..'" requires a target character')
            end
            for i, raw in ipairs(up.mods) do
                local m = self:_buildMod(up, raw, i)
                if Character and Character.addModifier then
                    Character.addModifier(target, m)
                else
                    target.modifiers = target.modifiers or {}
                    table.insert(target.modifiers, m)
                end
            end
        else
            for i, raw in ipairs(up.mods) do
                local m = self:_buildMod(up, raw, i)
                self:addModifier(m)
            end
        end
    end

    -- 2. Хуки
    if up.hooks then
        self:registerHooks(id, up.hooks)
    end

    -- 3. Unlocks
    if up.unlocks then
        for _, key in ipairs(up.unlocks) do
            self:addUnlock(key)
        end
    end

    -- 4. Условные (synergy) — модификаторы активируются при выполнении condition
    if up.condition then
        self.conditionals[id] = up
    end

    -- 5. Спец-эффект (эволюция, новое заклинание, второй шанс)
    if up.on_apply and target then
        up.on_apply(target)
    end
end

function RunState:_buildMod(up, raw, index)
    local id = up.id .. '_' .. (raw.stat or ('mod' .. index))
    return {
        id        = id,
        scope     = up.scope or 'run',
        stat      = raw.stat,
        op        = raw.op or 'add',
        value     = raw.value,
        filter    = up.filter,
        source    = up.id,
        duration  = raw.duration or up.duration,
        stack     = raw.stack or up.stack or 'add',
        on_expire = up.on_expire,
    }
end

-- ------------------------------------------------------------------
-- Условные (synergy) апгрейды
-- Вызывать после изменения состава отряда (add/remove character).
-- ------------------------------------------------------------------

function RunState:reevaluateConditionals(party)
    for id, up in pairs(self.conditionals) do
        local active = up.condition and up.condition(party)
        local wasActive = self.active_conditions[id]

        if active and not wasActive then
            self.active_conditions[id] = true
            if up.mods then
                for i, raw in ipairs(up.mods) do
                    local m = self:_buildMod(up, raw, i)
                    m.id = id .. '_cond_' .. (raw.stat or i)
                    self:addModifier(m)
                end
            end
        elseif not active and wasActive then
            self.active_conditions[id] = nil
            if up.mods then
                for i, raw in ipairs(up.mods) do
                    self:removeModifierById(id .. '_cond_' .. (raw.stat or i))
                end
            end
        end
    end
end

-- ------------------------------------------------------------------
-- Сериализация (для сейвов)
-- Фильтры/хуки/условия восстанавливаются из data/upgrades.lua
-- ------------------------------------------------------------------

function RunState:serialize()
    local mods = {}
    for _, m in ipairs(self.modifiers) do
        mods[#mods+1] = {
            id       = m.id,
            scope    = m.scope,
            stat     = m.stat,
            op       = m.op,
            value    = m.value,
            source   = m.source,
            duration = m.duration,
            stack    = m.stack,
        }
    end

    local applied = {}
    for id, count in pairs(self.applied_upgrades) do
        applied[#applied+1] = { id = id, count = count }
    end

    local unlocks = {}
    for k, v in pairs(self.unlocks) do unlocks[k] = v end

    return {
        seed              = self.seed,
        modifiers         = mods,
        applied_upgrades  = applied,
        unlocks           = unlocks,
        active_conditions = self.active_conditions,
    }
end

function RunState:deserialize(data)
    self.active = true
    self.seed   = data.seed or love.math.random(1, 2^31 - 1)
    self.rng    = love.math.newRandomGenerator(self.seed)

    self.modifiers = {}
    for _, m in ipairs(data.modifiers or {}) do
        local up = Upgrades[m.source]
        if up then m.filter = up.filter end  -- восстанавливаем несериализуемое
        table.insert(self.modifiers, m)
    end

    self.unlocks = {}
    for k, v in pairs(data.unlocks or {}) do
        if type(v) == 'number' then
            self.unlocks[k] = v
        elseif v == true then
            self.unlocks[k] = 1
        end
    end

    self.applied_upgrades = {}
    for _, e in ipairs(data.applied_upgrades or {}) do
        self.applied_upgrades[e.id] = e.count
    end

    -- Восстанавливаем hooks и conditionals из data/upgrades
    self.hooks = {}
    self.conditionals = {}
    for id in pairs(self.applied_upgrades) do
        local up = Upgrades[id]
        if up then
            if up.hooks     then self.hooks[id] = up.hooks end
            if up.condition then self.conditionals[id] = up end
        end
    end

    self.active_conditions = data.active_conditions or {}
end

return RunState