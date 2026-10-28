-- Bond scene: the creature that has been with you longest says something.
-- Which creature is chosen, and how they feel, comes from real run history
-- (level, exp, health) — not from a generator.

local RunState = require 'src.states.run_state'
local PlayerMetaStory = require 'src.player_meta_story'

local function companions(player)
    local out = {}
    for _, list in ipairs({
        player.charactersActive, player.charactersSpare, player.charactersStables,
    }) do
        for _, c in ipairs(list or {}) do
            if c and c.name then out[#out + 1] = c end
        end
    end
    -- Deterministic ordering before picking.
    table.sort(out, function(a, b)
        local la, lb = a.level or 1, b.level or 1
        if la ~= lb then return la > lb end
        local ea, eb = a.exp or 0, b.exp or 0
        if ea ~= eb then return ea > eb end
        return tostring(a.name) < tostring(b.name)
    end)
    return out
end

return {
    id = 'bond_creature',
    slots = {},

    terminal = true,

    generate = function(ctx)
        local player = ctx.player
        local camp   = ctx.campaign
        local list   = companions(player)
        local c      = list[1]

        if not c then
            return {
                title = "Quiet",
                steps = { { text = "There is no one to listen to.",
                            buttons = { { text = "Move on.", action = function() return 0 end } } } },
            }
        end

        local name  = c.name
        local level = c.level or 1

        -- Three registers of bond, chosen by how invested the player is.
        local flavour
        if level >= 4 then
            flavour = ("It does not wait to be called. It wakes before you do, "
                    .. "and is already facing the road.")
        elseif level >= 2 then
            flavour = ("It has learned your habits. When you stop to rest, it "
                    .. "stops a half-step early.")
        else
            flavour = ("It is still deciding what you are. It watches you more "
                    .. "than it watches the road.")
        end

        return {
            title = name,
            steps = {
                {
                    text = ("On the third night of the road, %s stops walking. "
                         .. "It does not look at you — it looks at the distance.\n\n%s\n\n"
                         .. "It is asking something, or it is only tired. With "
                         .. "beasts, those are close."):format(name, flavour),
                    buttons = {
                        {
                            text = "Trust it. Let it lead.",
                            action = function(player)
                                -- Buff the creature for the rest of the run.
                                c.modifiers = c.modifiers or {}
                                c.modifiers[#c.modifiers + 1] = {
                                    id     = 'bond_trust',
                                    name   = 'Bonded',
                                    scope  = 'run',
                                    stat   = 'damage',
                                    op     = 'mul',
                                    value  = 1.15,
                                    source = 'bond_arc',
                                }
                                RunState:addUnlock('bond_trusted')
                                PlayerMetaStory.mark_thread_complete(camp, 'bond_arc')
                                Tagtext:add(name .. " trusts you.",
                                    love.mouse.getX(), love.mouse.getY(),
                                    1, 30, { 1, 1, 1 })
                                return 0
                            end,
                        },
                        {
                            text = "Test it. Make it keep walking.",
                            action = function(player)
                                -- Risk: a strong buff, or a curse.
                                local roll = ctx.rng and ctx.rng() or 0.5
                                c.modifiers = c.modifiers or {}
                                if roll < 0.5 then
                                    c.modifiers[#c.modifiers + 1] = {
                                        id     = 'bond_tested_hard',
                                        name   = 'Forged',
                                        scope  = 'run',
                                        stat   = 'damage',
                                        op     = 'mul',
                                        value  = 1.3,
                                        source = 'bond_arc',
                                    }
                                    RunState:addUnlock('bond_forged')
                                    Tagtext:add(name .. " is harder now.",
                                        love.mouse.getX(), love.mouse.getY(),
                                        1, 30, { 1, 1, 1 })
                                else
                                    c.modifiers[#c.modifiers + 1] = {
                                        id     = 'bond_tested_broken',
                                        name   = 'Wary',
                                        scope  = 'run',
                                        stat   = 'initiative',
                                        op     = 'add',
                                        value  = -2,
                                        source = 'bond_arc',
                                    }
                                    RunState:addUnlock('bond_broken')
                                    Tagtext:add(name .. " is wary.",
                                        love.mouse.getX(), love.mouse.getY(),
                                        1, 30, { 1, 1, 1 })
                                end
                                PlayerMetaStory.mark_thread_complete(camp, 'bond_arc')
                                return 0
                            end,
                        },
                        {
                            text = "Let it rest. It has earned it.",
                            action = function(player)
                                -- The kind option: it heals fully instead of
                                -- getting a stat buff. Still a real benefit.
                                local Character = require 'src.character'
                                local Stats = require 'src.stats'
                                local stats = Stats(c, RunState:getModifiers(), {})
                                c.health = stats:get('max_health')
                                c.energy = stats:get('max_energy')
                                RunState:addUnlock('bond_rested')
                                PlayerMetaStory.mark_thread_complete(camp, 'bond_arc')
                                Tagtext:add(name .. " is rested.",
                                    love.mouse.getX(), love.mouse.getY(),
                                    1, 30, { 1, 1, 1 })
                                return 0
                            end,
                        },
                    },
                },
            },
        }
    end,
}
