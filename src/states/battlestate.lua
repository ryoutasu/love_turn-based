local map = require 'src.map'
local pathfinder = require 'src.pathfinder'
local queue = require 'src.actorQueue'
local ui = require 'src.ui'

local move = require 'src.actions.move'
local attack = require 'src.actions.attack'
local ai_wait = require 'src.actions.ai_wait'
local spell = require 'src.actions.spell'

local unit_def = require 'resources.unit_definition'

local BattleState = {}

function BattleState:init()
    self.map = map(20, 9)
    self.pathfinder = pathfinder(self.map)
    self.u = Urutora:new()
    self.UI = ui(self.u, 15, self.map:get_height_px())
    self.queue = queue(self.u, 230, self.map:get_height_px())

    self.units = {}
    self.state = 'none'
    
    self:add_unit(4, 3, 'Alice', true)
    self:add_unit(2, 2, 'Cat', true)
    self:add_unit(18, 7, 'Bat', false)

    self:start_turn()
end

function BattleState:current_actor()
    return self.queue.current
end

function BattleState:add_unit(x, y, name, is_player)
    if not unit_def[name] then return false end

    local node = self.map:get_node(x, y)
    if not node or node.is_blocked then return false end

    local u = unit_def[name](node, is_player)
    table.insert(self.units, u)
    self.queue:add_actor(u)
    return true
end

function BattleState:set_target_mode(current_spell)
    self.current_spell = current_spell
    local actor = self:current_actor()

    self.map:reset_nodes()
    self.pathfinder:calculate_range(actor.node, actor.attack_range)

    for _, t in pairs(self.map.tiles._props) do
        t.can_be_selected = current_spell.filter(t) and t.range <= current_spell.range
        t:change_color()
    end

    self.state = 'spell'
    self.UI:show_cancel_button(true)
end

function BattleState:cancel_target_mode()
    self.map:reset_nodes()

    local actor = self:current_actor()
    local node = actor.node
    BattleState:open_attack_move(actor, node)
end

function BattleState:open_attack_move(actor, node)
    self.state = 'waiting'
    self.pathfinder:calculate(node, actor.movement_range, false, actor.attack_range == 1)
    self.pathfinder:calculate_range(node, actor.attack_range)
end

-- for later
-- function BattleState:recalculate_path(tile, range)
--     local actor = self:current_actor()
--     self.map:reset_nodes()

--     for i, t in ipairs(self.map.drawing_path) do
--         t.parent = i == 1 and actor.node or self.map.drawing_path[i-1]
--     end

--     self.pathfinder:calculate(tile, range, false, actor.attack_range == 1, true)
--     self.pathfinder:calculate_range(tile, 1)
-- end

function BattleState:start_turn()
    self.queue:start_turn()
    
    local actor = self:current_actor()
    local node = actor.node
    if actor.is_player == true then
        BattleState:open_attack_move(actor, node)
        self.UI:start_turn(actor)
    else
        self.state = 'ai'
        self.pathfinder:calculate(node, nil, true)

        local path_to_target
        local target
        local cost = 1/0
        for _, u in ipairs(self.units) do
            if u.is_player then
                local p = u.node:get_path()
                if cost > #p then
                    cost = #p
                    path_to_target = p
                    target = u.node
                end
            end
        end

        if target then
            self.pathfinder:calculate_range(target, actor.attack_range)
    
            if node.range <= actor.attack_range then
                target:set_animation('select', nil , { 1, 0, 0, 1 })
                actor:set_current_action(attack, target.actor)
            else
                
                local path_to_closest = path_to_target
                local closest_node = target
                cost = 1/0
                -- find closest node that enemy can attack from
                for _, n in pairs(self.map.tiles._props) do
                    if n.range == actor.attack_range then
                        local p = n:get_path()
                        if cost > #p or n == target.parent then
                            cost = #p
                            path_to_closest = p
                            closest_node = n
                        end
                    end
                end

                if path_to_closest and cost > 0 then
                    local n = math.min(#path_to_closest, actor.movement_range)
                    closest_node = path_to_closest[n]
                end

                local do_attack = closest_node.range == 1 and actor.attack_range == 1
        
                if closest_node then
                    if do_attack then
                        target:show_path()
                        target:set_animation('select', nil , { 1, 0, 0, 1 })
                    else
                        closest_node:show_path()
                    end
                    actor:set_current_action(move, closest_node:get_path(), self.pathfinder, do_attack and target.actor or false)
                else
                    actor:set_current_action(ai_wait)
                end
            end
        else
            actor:set_current_action(ai_wait)
        end
        self.map:reset_nodes()
    end
end

function BattleState:handle_action()
    if self:current_actor().action_new then
        self.map:reset_nodes()
        self.UI:disable()
    end
    if not self:current_actor().action_completed then return end

    -- self.queue:end_turn()
    
    self:start_turn()
end

function BattleState:update(dt)
    self.queue:update(dt)
    self:handle_action()

    self.map:update(dt)
    -- self:update_drawing_path()
    for i, unit in ipairs(self.units) do
        unit:update(dt)
    end
    self.u:update(dt)
end

function BattleState:draw()
    self.map:draw()
    for i, u in ipairs(self.units) do
        u:draw()
    end
    self.u:draw()
end

function BattleState:mousepressed(x, y, button)
    local actor = self:current_actor()
    if button == 1 then
        if self.state == 'waiting' then
            local tile = self.map.highlighted
            if tile and (tile.actor == actor or tile.is_open) then
                self.map:start_drawing_path(tile)
            end
        end

        if self.state == 'spell' then
            local t = self.map.highlighted
            if t and t.can_be_selected then
                self.state = 'acting'
                actor:set_current_action(spell, self.current_spell, t)
                self.UI:show_cancel_button(false)
            end
        end
    end
    if button == 2 then
        if --[[ actor.is_player and ]] self.state == 'waiting' then
            local tile = self.map.highlighted
            if tile then
                if tile.is_open then
                    self.state = 'acting'
                    actor:set_current_action(move, tile:get_path(), self.pathfinder)
                elseif tile.can_be_selected then
                    self.state = 'acting'
                    if actor.attack_range == 1 and tile.range > 1 then
                        actor:set_current_action(move, tile.parent:get_path(), self.pathfinder, tile.actor)
                    else
                        actor:set_current_action(attack, tile.actor)
                    end
                end
            end
        end
        if self.state == 'drawing_path' then
            self.map:stop_drawing_path()
        end
    end
    self.u:pressed(x, y, button)
end

function BattleState:mousereleased(x, y, button)
    if self.state == 'drawing_path' then
        local path = self.map.drawing_path
        if next(path) then
            self.state = 'acting'
            local actor = self:current_actor()
            actor:set_current_action(move, path, self.pathfinder, self.map.last_tile.actor)
        else
            self.map:stop_drawing_path()
        end
    end
    self.u:released(x, y)
end

function BattleState:mousemoved(x, y, dx, dy)
    self.u:moved(x, y, dx, dy)
end

function BattleState:keypressed(key, scancode, isrepeat)
    self.u:keypressed(key, scancode, isrepeat)
    if key == 'escape' then
        if self.state == 'spell' then
            self:cancel_target_mode()
        end
        if self.state == 'drawing_path' then
            self.map:stop_drawing_path()
        end
    end
end
function BattleState:textinput(text) self.u:textinput(text) end
function BattleState:wheelmoved(x, y) self.u:wheelmoved(x, y) end

return BattleState