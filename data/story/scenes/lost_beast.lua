-- Lost-beast scene. The creature is hurt and wanders off. Three honest
-- options; the point is that none is mechanically "best".

local RunState = require 'src.states.run_state'
local PlayerMetaStory = require 'src.player_meta_story'

local FLAG = 'lost_beast_done'

local function weakest(player)
    local best, best_ratio
    for _, list in ipairs({ player.charactersActive, player.charactersSpare }) do
        for _, c in ipairs(list or {}) do
            if c and c.health and c.max_health and c.max_health > 0 then
                local ratio = c.health / c.max_health
                if not best_ratio or ratio < best_ratio
                   or (ratio == best_ratio and tostring(c.name) < tostring(best.name)) then
                    best, best_ratio = c, ratio
                end
            end
        end
    end
    return best
end

local function remove_from_party(player, character)
    local function strip(list)
        if not list then return end
        for i = #list, 1, -1 do
            if list[i] == character then table.remove(list, i) end
        end
    end
    strip(player.charactersActive)
    strip(player.charactersSpare)
end

return {
    id = 'lost_beast',
    slots = {},

    terminal = true,

    generate = function(ctx)
        local player = ctx.player
        local camp   = ctx.campaign
        local c      = weakest(player)

        if not c then
            return {
                title = "Quiet",
                steps = { { text = "Nothing here.",
                            buttons = { { text = "Move on.", action = function() return 0 end } } } },
            }
        end

        local name = c.name

        return {
            title = "The one that drifts",
            steps = {
                {
                    text = ("You notice at dusk, the way you notice small "
                         .. "absences: %s is not with the others.\n\n"
                         .. "You find it some way back, sitting in the grass, "
                         .. "watching nothing. It has been hurt for a while. "
                         .. "It may have been thinking about leaving for longer "
                         .. "than that."):format(name),
                    buttons = {
                        {
                            text = "Call it back. Carry it if you must.",
                            action = function(player)
                                -- It comes back, but the whole party pays
                                -- in rest: a full round of recovery is lost.
                                local Character = require 'src.character'
                                local Stats = require 'src.stats'
                                for _, list in ipairs({ player.charactersActive, player.charactersSpare }) do
                                    for _, other in ipairs(list or {}) do
                                        local stats = Stats(other, RunState:getModifiers(), {})
                                        local max_hp = stats:get('max_health')
                                        other.health = math.max(1, other.health - math.floor(max_hp * 0.1))
                                    end
                                end
                                RunState:addUnlock('beast_reclaimed')
                                PlayerMetaStory.mark_thread_complete(camp, 'lost_beast')
                                Tagtext:add(name .. " comes back.",
                                    love.mouse.getX(), love.mouse.getY(),
                                    1, 30, { 1, 1, 1 })
                                return 0
                            end,
                        },
                        {
                            text = "Let it go.",
                            action = function(player)
                                -- Real loss, real compensation: the creature
                                -- leaves, and you are not left empty-handed
                                -- for the effort of having raised it.
                                remove_from_party(player, c)
                                player:addEssence(3)
                                RunState:addUnlock('beast_released')
                                PlayerMetaStory.mark_thread_complete(camp, 'lost_beast')
                                Tagtext:add(name .. " is gone.",
                                    love.mouse.getX(), love.mouse.getY(),
                                    1, 30, { 1, 1, 1 })
                                return 0
                            end,
                        },
                        {
                            text = "Sit with it. Say nothing.",
                            action = function(player)
                                -- The third way: no gain, no loss, but the
                                -- creature is healed enough to stay.
                                local Stats = require 'src.stats'
                                local stats = Stats(c, RunState:getModifiers(), {})
                                local max_hp = stats:get('max_health')
                                c.health = math.min(max_hp, c.health + math.floor(max_hp * 0.5))
                                RunState:addUnlock('beast_stayed')
                                PlayerMetaStory.mark_thread_complete(camp, 'lost_beast')
                                Tagtext:add(name .. " stays.",
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
