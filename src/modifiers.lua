local UpgradeList = require 'data.upgrades'

local Modifier = {}

local function make(scope, stat, op, value, opts)
    return {
        id     = opts.id,
        scope  = scope,
        stat   = stat,
        op     = op,
        value  = value,
        filter = opts.filter,
        source = opts.source,
        duration = opts.duration,   -- для battle-модификаторов с временем
        tag    = opts.tag,
    }
end

-- Permanent
function Modifier.permAdd(stat, value, opts)  return make('permanent', stat, 'add', value, opts or {}) end
function Modifier.permMul(stat, value, opts)  return make('permanent', stat, 'mul', value, opts or {}) end

-- Run
function Modifier.runAdd(stat, value, opts)   return make('run', stat, 'add', value, opts or {}) end
function Modifier.runMul(stat, value, opts)   return make('run', stat, 'mul', value, opts or {}) end

-- Battle
function Modifier.battleAdd(stat, value, opts) return make('battle', stat, 'add', value, opts or {}) end
function Modifier.battleMul(stat, value, opts) return make('battle', stat, 'mul', value, opts or {}) end

function Modifier.pack(scope, defaults, entries)
    local out = {}
    for i, e in ipairs(entries) do
        out[i] = {
            id     = e.id or (defaults.id_prefix and defaults.id_prefix .. i) or nil,
            scope  = scope,
            stat   = e.stat,
            op     = e.op or 'add',
            value  = e.value,
            filter = e.filter or defaults.filter,
            source = defaults.source,
            duration = e.duration or defaults.duration,
            tag    = e.tag or defaults.tag,
        }
    end
    return out
end

function Modifier.fromUpgrade(key)
    local def = UpgradeList[key]
    assert(def, 'Unknown upgrade: '..tostring(key))

    local out = {}
    for i, m in ipairs(def.mods) do
        out[i] = {
            id     = (def.id or key) .. (m.id and ('_'..m.id) or ('_'..i)),
            scope  = def.scope,
            stat   = m.stat,
            op     = m.op or 'add',
            value  = m.value,
            filter = def.filter,
            source = def.source,
            duration = m.duration or def.duration,
            tag    = def.tag or def.scope,
        }
    end
    return out
end

return Modifier