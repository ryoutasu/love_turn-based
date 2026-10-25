local att_less = 0.7
local att_more = 1.5

local ele_less = 0.85
local ele_more = 1.3

local Chart = {}

Chart.attributes = {
    wild = {
        mystic = att_more,
        mechanic = att_less
    },
    mystic = {
        mechanic = att_more,
        wild = att_less
    },
    mechanic = {
        wild = att_more,
        mystic = att_less
    }
}

Chart.elements = {
    ember = {
        earth = ele_more,
        water = ele_less,
        plant = ele_more
    },
    earth = {
        storm = ele_more,
        ember = ele_less,
        plant = ele_less
    },
    storm = {
        water = ele_more,
        earth = ele_less,
        plant = ele_more
    },
    water = {
        ember = ele_more,
        storm = ele_less,
        plant = ele_less
    },
    light = {
        light = ele_less,
        dark = ele_more,
    },
    dark = {
        light = ele_more,
        dark = ele_less,
    },
    plant = {
        ember = ele_less,
        storm = ele_less,
        water = ele_more,
        earth = ele_more
    }
}

function Chart.getAttributeMultiplier(attAttr, defAttr)
    return Chart.attributes[attAttr][defAttr] or 1
end

function Chart.getElementMultiplier(attElem, defElem)
    return Chart.elements[attElem][defElem] or 1
end

return Chart