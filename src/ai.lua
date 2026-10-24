local move = require 'src.actions.move'
local attack = require 'src.actions.attack'
local ai_wait = require 'src.actions.ai_wait'
local Actions = require 'src.actions'

local AI = {}

function AI.think(battlestate, actor)
    local tile = actor.tile
    local is_player = actor.is_player

    battlestate.phase = 'action'
    battlestate.end_turn = true
    local gscore, parents = battlestate.pathfinder:calculate(tile)
    battlestate:process_tiles(gscore, parents, actor)

    local path_to_target
    local target
    local cost = math.huge
    for _, unit in ipairs(battlestate.units) do
        if unit.is_player ~= is_player and not unit.is_dead and not unit.spare then
            local p = unit.tile:get_path()
            if cost > #p then
                cost = #p
                path_to_target = p
                target = unit.tile
            end
        end
    end

    if target then
        battlestate.pathfinder:calculate_range(target, actor.attack_range)

        -- Попытка использовать способность, если таковая доступна
        for _, spell in ipairs(actor.spells) do
            if actor.energy < spell.cost then goto continue end
            if spell.current_cooldown > 0 then goto continue end
            if tile.range > spell.range then goto continue end
            
            battlestate:add_action(Actions.spell(actor, spell, target))
            goto reset_tiles
            ::continue::
        end

        if tile.range <= actor.attack_range then
            target:set_animation('select', nil , { 1, 0, 0, 1 })
            -- actor:set_current_action(attack, target.actor)
            battlestate:add_action(attack(actor, target.actor))
        else
            local path_to_closest = path_to_target
            local closest_tile = target
            cost = math.huge
            -- find closest tile that enemy can attack from
            for _, n in pairs(battlestate.map.tiles._props) do
                if n.range == actor.attack_range and not n.is_blocked then
                    local p = n:get_path()
                    if cost > #p or n == target.parent then
                        cost = #p
                        path_to_closest = p
                        closest_tile = n
                    end
                end
            end

            if path_to_closest and cost > 0 then
                local n = math.min(#path_to_closest, actor.move_range)
                closest_tile = path_to_closest[n]
            end

            local do_attack = closest_tile.range == 1 and actor.attack_range == 1
    
            if closest_tile then
                if do_attack then
                    target:show_path()
                    target:set_animation('select', nil , { 1, 0, 0, 1 })
                else
                    closest_tile:show_path()
                end
                -- actor:set_current_action(move, closest_node:get_path(), self.pathfinder, do_attack and target.actor or false)
                battlestate:add_action(move(actor, closest_tile:get_path(), battlestate.pathfinder, do_attack and target.actor or false))
            else
                -- actor:set_current_action(ai_wait)
                battlestate:add_action(ai_wait(actor))
            end
        end
    else
        -- actor:set_current_action(ai_wait)
        battlestate:add_action(ai_wait(actor))
    end
    ::reset_tiles::
    battlestate.map:reset_tiles()
end

return AI