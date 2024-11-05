local map = require 'src.map'
local pathfinder = require 'src.pathfinder'
local queue = require 'src.actorQueue'
local panel = require 'src.commandPanel'
local unit = require 'src.objects.unit'
local sprite = require 'src.sprite'

local move = require 'src.actions.move'
local attack = require 'src.actions.attack'
local ai_wait = require 'src.actions.ai_wait'
local spell = require 'src.actions.spell'

local characterList = require 'src.characters'
local spellList = require 'src.spells'

local BattleState = {}

function BattleState:init()
    self.u = Urutora:new()
    self.panel = panel(self.u, 15, love.graphics.getHeight() - 210)
    self.result = nil
    self.paused = false

    local w, h = 200, 50
    local x = love.graphics.getWidth()/2 - w/2
    local y = love.graphics.getHeight()/2 - h/2
    local resultLabel = Urutora.label({
        x = x, y = y,
        w = w, h = h,
        text = '',
        align = 'center'
    }):deactivate()
    
    w, h = 100, 30
    x = love.graphics.getWidth()/2 - w/2
    y = love.graphics.getHeight()/2 - h/2 + resultLabel.h + 10
    local resultButton = Urutora.button({
        x = x, y = y,
        w = w, h = h,
        text = 'Continue',
        align = 'center'
    }):deactivate():action(function (e)
        Gamestate.pop(self.result)
    end)

    self.u:add(resultLabel)
    self.u:add(resultButton)

    self.resultLabel = resultLabel
    self.resultButton = resultButton
end

function BattleState:enter(from, args)
    self.result = nil
    self.paused = false

    self.map = map(9, 5)
    self.pathfinder = pathfinder(self.map)
    self.queue = queue(230, love.graphics.getHeight() - 210)

    self.units = {}
    self.actions = {}

    self.state = 'none'
    self.current_spell = nil
    self.action_complete = false

    self.player = args.player

    local i = 1
    for name, character in pairs(self.player.party) do
        self:add_unit(1, i, character, true, true)
        i = i + 1
    end

    self:add_unit(4, 3, 'Bat', false)

    self:start_turn()
end

function BattleState:leave()
    self.resultLabel:deactivate()
    self.resultButton:deactivate()

    self.map = nil
    self.pathfinder = nil
    self.queue = nil
    
    self.state = 'none'
    self.current_spell = nil
    self.action_complete = false
    
    self.result = nil
end

function BattleState:current_actor()
    return self.queue.current
end

function BattleState:current_action()
    return self.actions[1]
end

function BattleState:add_unit(x, y, table_or_name, is_player, change_character)
    local character_table = table_or_name
    if type(table_or_name) == "string" then
        character_table = characterList[table_or_name]
    end

    local node = self.map:get_node(x, y)
    if not node or node.is_blocked then return false end
    
    local rect = character_table.rect
    local u = unit(node, sprite('resources/'.. character_table.sprite_path ..'.png'), rect[1], rect[2], rect[3], rect[4], is_player)

    u.name = character_table.name
    
    u.sprite_sx = character_table.sprite_sx or 1
    u.sprite_sy = character_table.sprite_sy or 1
    
    u:set_statistics(
        character_table.health,
        character_table.damage,
        character_table.attack_range,
        character_table.move_range,
        character_table.initiative
    )

    if character_table.current_health then
        u.health = character_table.current_health
    end

    for _, spellname in ipairs(character_table.spells) do
        u:add_spell(spellList[spellname])
    end

    if change_character then
        u.character_reference = table_or_name
    end

    table.insert(self.units, u)
    self.queue:add_actor(u)

    return u
end

-- function BattleState:add_unit(x, y, name, is_player)
--     if not unit_def[name] then return false end

--     local node = self.map:get_node(x, y)
--     if not node or node.is_blocked then return false end

--     local u = unit_def[name](node, is_player)
--     table.insert(self.units, u)
--     self.queue:add_actor(u)
--     return true
-- end

function BattleState:add_action(action, pos)
    pos = pos or #self.actions + 1
    table.insert(self.actions, pos, action)
end

-- function BattleState:remove_unit(unit)
--     self.queue:remove_actor(unit)
-- end

function BattleState:unit_death(unit)
    self.queue:remove_actor(unit)

    local is_win = true
    local is_lose = true
    for _, checking_unit in ipairs(self.units) do
        if not checking_unit.is_dead then
            if checking_unit.is_player then
                is_lose = false
            else
                is_win = false
            end
        end
    end

    if is_win then
        self.result = 'win'
    end
    if is_lose then
        self.result = 'lose'
    end
end

function BattleState:showResult()
	assert(self.result ~= 'win' or self.result ~= 'lose', "Wrong result!")
    self.paused = true

    if self.result == 'win' then
        self.resultLabel.text = 'You won!'
    end
    if self.result == 'lose' then
        self.resultLabel.text = 'You lost...'
    end

    self.resultLabel:activate()
    self.resultButton:activate()
end

function BattleState:set_target_mode(current_spell)
    self.current_spell = current_spell
    local actor = self:current_actor()

    self.map:reset_nodes()
    -- self.pathfinder:calculate_range(actor.node, current_spell.range)
    self.pathfinder:calculate_range2(actor.node, current_spell.range)

    for _, t in pairs(self.map.tiles._props) do
        t.can_be_selected = current_spell.filter(t) and t.range <= current_spell.range
        t:change_color()
    end

    self.state = 'spell'
    self.panel:show_cancel_button(true)
end

function BattleState:cancel_target_mode()
    self.current_spell = nil
    self.map:reset_nodes()

    local actor = self:current_actor()
    local node = actor.node
    BattleState:open_attack_move(actor, node)
end

function BattleState:open_attack_move(actor, node)
    self.state = 'waiting'

    self.pathfinder:calculate(node, actor.movement_range, false, actor.attack_range == 1)
    self.pathfinder:calculate_range(node, actor.attack_range)
    
    -- if self.map.highlighted and not self.map.highlighted.actor.is_player then
    --     self.map:cursor_enters_tile(self.map.highlighted)
    -- end
end

function BattleState:recalculate_path(tile, range)
    local actor = self:current_actor()
    self.map:reset_nodes()

    self.pathfinder:calculate(tile, range, false, actor.attack_range == 1)
    self.pathfinder:calculate_range(tile, 1)

    for i, t in ipairs(self.map.drawing_path) do
        t.parent = i == 1 and actor.node or self.map.drawing_path[i-1]
    end
    actor.node.parent = nil
end

function BattleState:start_turn()
    self.queue:start_turn()
    
    local actor = self:current_actor()
    local node = actor.node
    if actor.is_player == true then
        BattleState:open_attack_move(actor, node)
        self.panel:start_turn(actor)
    else
        self.state = 'ai'
        self.pathfinder:calculate(node, nil, true)

        local path_to_target
        local target
        local cost = 1/0
        for _, u in ipairs(self.units) do
            if u.is_player and not u.is_dead then
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
                -- actor:set_current_action(attack, target.actor)
                self:add_action(attack(actor, target.actor))
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
                    -- actor:set_current_action(move, closest_node:get_path(), self.pathfinder, do_attack and target.actor or false)
                    self:add_action(move(actor, closest_node:get_path(), self.pathfinder, do_attack and target.actor or false))
                else
                    -- actor:set_current_action(ai_wait)
                    self:add_action(ai_wait(actor))
                end
            end
        else
            -- actor:set_current_action(ai_wait)
            self:add_action(ai_wait(actor))
        end
        self.map:reset_nodes()
    end
end

function BattleState:handle_action(dt)
    local complete = false
    local currentAction = self:current_action()

    if currentAction then
        if currentAction.is_new then
            self.map:reset_nodes()
            self.panel:disable()

            currentAction:start()
            currentAction.is_new = false
        end

        complete = currentAction:update(dt)
    else
        if self.action_complete then
            self:start_turn()
        end
    end

    if complete then
        table.remove(self.actions, 1)
        
        if self.result then
            self:showResult()
        end
    end
    self.action_complete = complete
end

function BattleState:update(dt)
    self.queue:update(dt)

    if not self.paused then
        self:handle_action(dt)
    end

    self.map:update(dt)
    for i, unit in ipairs(self.units) do
        unit:update(dt)
    end
    self.u:update(dt)
end

function BattleState:draw()
    self.map:draw()

    for _, unit in ipairs(self.units) do
        if unit.is_dead then
            unit:draw()
        end
    end

    for _, unit in ipairs(self.units) do
        if not unit.is_dead then
            unit:draw()
        end
    end

    local current_action = self:current_action()
    if current_action then
        current_action:draw()
    end
    
    for _, unit in ipairs(self.units) do
        unit:draw_health(unit.x, unit.y)
        unit:draw_name()
    end

    self.u:draw()
    self.queue:draw()
end

function BattleState:mousepressed(x, y, button)
    local actor = self:current_actor()
    if button == 1 then
        local tile = self.map.highlighted
        if self.state == 'waiting' then
            if tile and (tile.actor == actor or tile.is_open) then
                self.map:start_drawing_path(tile)
            end
        end

        if self.state == 'spell' then
            if tile and tile.can_be_selected then
                self.state = 'acting'
                self:add_action(spell(actor, self.current_spell, tile))
                self.panel:show_cancel_button(false)
                self.current_spell = nil
            end
        end
    end

    if button == 2 then
        if --[[ actor.is_player and ]] self.state == 'waiting' then
            local tile = self.map.highlighted
            if tile then

                if tile.is_open then
                    self.state = 'acting'
                    self:add_action(move(actor, tile:get_path(), self.pathfinder))
                elseif tile.can_be_selected then
                    self.state = 'acting'
                    if actor.attack_range == 1 and tile.range > 1 then
                        self:add_action(move(actor, tile.parent:get_path(), self.pathfinder, tile.actor))
                    else
                        self:add_action(attack(actor, tile.actor))
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
            self:add_action(move(actor, path, self.pathfinder, self.map.last_tile.actor))
        else
            self.map:stop_drawing_path()
        end
    end
    self.u:released(x, y)
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

function BattleState:mousemoved(x, y, dx, dy) self.u:moved(x, y, dx, dy) end
function BattleState:textinput(text) self.u:textinput(text) end
function BattleState:wheelmoved(x, y) self.u:wheelmoved(x, y) end

return BattleState