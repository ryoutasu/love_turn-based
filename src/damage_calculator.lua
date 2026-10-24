local typeChart = require 'data.type_chart'

local DamageCalculator = {}

function DamageCalculator.calculate(attacker, defender, baseDamage, element)
    local attrMultiplier = getAttributeMultiplier(attacker.attribute, defender.attribute)
    local elemMultiplier = getElementMultiplier(attacker.element, defender.element)
    local totalMultiplier = attrMultiplier * elemMultiplier
    return math.floor(baseDamage * totalMultiplier)
end

function getAttributeMultiplier(attAttr, defAttr)
    return typeChart.attributes[attAttr][defAttr] or 1
end

function getElementMultiplier(attElem, defElem)
    return typeChart.elements[attElem][defElem] or 1
end

return DamageCalculator