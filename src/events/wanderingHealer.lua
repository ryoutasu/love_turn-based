local RunState = require 'src.states.run_state'
local Stats    = require 'src.stats'

local HEAL_AMOUNT = 40
local BASE_COST   = 30

local function get_active(player)
    local list = {}
    local size = player.charactersActiveSize or #player.charactersActive
    for i = 1, size do
        if player.charactersActive[i] then
            table.insert(list, player.charactersActive[i])
        end
    end
    return list
end

local function max_hp(c)
    return Stats.new(c, RunState:getModifiers(), {}):get('max_health')
end

return function(player)
    local active  = get_active(player)
    local wounded = {}
    for _, c in ipairs(active) do
        if c.health < max_hp(c) then
            table.insert(wounded, c)
        end
    end

    if #wounded == 0 then
        return {
            title = "Wandering Healer",
            steps = {
                [1] = {
                    text = "A wandering healer offers aid — but your party is unharmed.\n\nShe bows and moves on.",
                    buttons = { { text = "Continue", action = function() return 0 end } },
                }
            }
        }
    end

    -- Цена варьируется ±40%
    local cost = math.floor(BASE_COST * (0.6 + RunState:random() * 0.8))

    local buttons = {}
    for _, c in ipairs(wounded) do
        table.insert(buttons, {
            text = string.format("Heal %s (%dg)", c.name, cost),
            action = function()
                local gold = player.currencies.gold or 0
                if gold < cost then return 3 end
                player:addCurrency('gold', -cost)
                c.health = math.min(max_hp(c), c.health + HEAL_AMOUNT)
                PlaySound(CoinsSound)
                return 2
            end
        })
    end
    table.insert(buttons, { text = "Decline", action = function() return 4 end })

    return {
        title = "Wandering Healer",
        steps = {
            [1] = {
                text = "A wandering healer kneels by the road, offering her craft for coin.\n\n"
                     .. "She can restore " .. HEAL_AMOUNT .. " HP to one creature.",
                buttons = buttons,
            },
            [2] = {
                text = "The healer's hands glow. Wounds close, breath steadies.\n\nShe nods and walks on.",
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
            [3] = {
                text = function()
                    return string.format(
                        "You fumble for coin — only %d gold. The healer needs %d.\n\nShe moves on.",
                        player.currencies.gold or 0, cost)
                end,
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
            [4] = {
                text = "You thank the healer but decline. She disappears down the road.",
                buttons = { { text = "Continue", action = function() return 0 end } },
            },
        }
    }
end