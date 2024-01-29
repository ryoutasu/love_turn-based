local mt = {}
local function coord2index(x, y)
    return x..';'..y
end

mt.__index = function(s, k)
    if type(k) == 'table' then
        if s._props[coord2index(k[1], k[2])] ~= nil then
            return s._props[coord2index(k[1], k[2])]
        end
    elseif type(k) == "number" then
        if s._iprops[k] ~= nil then
            return s._iprops[k]
        end
    else
        if s._props[k] ~= nil then
            return s._props[k]
        end
    end
end

mt.__newindex = function(s, k, v)
    if type(k) == 'table' then
        s._props[coord2index(k[1], k[2])] = v
    elseif type(k) == "number" then
        s._iprops[k] = v
    else
        s._props[k] = v
    end
end

return function()
    return setmetatable({
        _props = {},
        _iprops = {}
    }, mt)
end