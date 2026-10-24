local Characters = require 'src.characters'

local CharacterPool = {
    byAttribute = {},
}

-- Индексируем все шаблоны, кроме стартовых
for name, ch in pairs(Characters) do
    if type(ch) == 'table'
       and ch.name
       and not ch.starter_character then
        local attr = ch.attribute or 'wild'
        CharacterPool.byAttribute[attr] = CharacterPool.byAttribute[attr] or {}
        table.insert(CharacterPool.byAttribute[attr], name)
    end
end

-- Случайное существо заданного атрибута
function CharacterPool.random(attr)
    local pool = CharacterPool.byAttribute[attr]
    if not pool or #pool == 0 then return nil end
    return pool[math.random(#pool)]
end

-- Случайное существо из набора атрибутов (для wildcraft)
function CharacterPool.randomFromAttributes(attrs)
    local all = {}
    for _, a in ipairs(attrs) do
        local list = CharacterPool.byAttribute[a]
        if list then
            for _, n in ipairs(list) do table.insert(all, n) end
        end
    end
    if #all == 0 then return nil end
    return all[math.random(#all)]
end

return CharacterPool