local map = require 'src.map'
local pathfinder = require 'src.pathfinder'
local queue = require 'src.actorQueue'
local panel = require 'src.commandPanel'
local Unit = require 'src.objects.unit'
local inventory = require 'src.inventory'
local Sprite = require 'src.sprite'
local Tween = require 'lib.tween'

local move = require 'src.actions.move'
local attack = require 'src.actions.attack'
local ai_wait = require 'src.actions.ai_wait'
local Actions = require 'src.actions'

local characterList = require 'src.characters'

local fontSize = 14
local font = love.graphics.newFont(fontSize)

local resultFontSize = 24
local resultFont = love.graphics.newFont(resultFontSize)

local rewardsFontSize = 18
local rewardsFont = love.graphics.newFont(rewardsFontSize)

local BattleState = {}

function BattleState:init()
    self.u = Urutora:new()
    self.panel = panel(self.u, 15, love.graphics.getHeight() - 210)
    self.result = nil
    self.paused = false

    local w, h = 140, 55
    local x = love.graphics.getWidth()/2 - w/2
    local y = love.graphics.getHeight()/2 - h/2 - 120
    local resultLabel = Urutora.label({
        x = x, y = y,
        w = w, h = h,
        text = '',
        align = 'center'
    }):deactivate():setStyle({ font = resultFont })

    self.rewards_w = resultLabel.w + 20
    self.rewards_h = 0
    self.rewards_x = love.graphics.getWidth()/2 - self.rewards_w/2
    self.rewards_y = resultLabel.y + resultLabel.h + 10
    
    w, h = 100, 30
    x = love.graphics.getWidth()/2 - w/2
    y = self.rewards_y + 10
    local resultButton = Urutora.button({
        x = x, y = y,
        w = w, h = h,
        text = 'Continue',
        align = 'center',
    }):deactivate():action(function (e)
        if self.state == 'result' then
            if self.result == 'lose' then
                Gamestate.pop({ result = self.result })
            else
                self.state = 'rewards'
                resultLabel.text = 'Rewards:'

                self.rewards_h = 0
                self.rewards_tween = Tween.new(1, self, { rewards_h = 150 }, 'inOutCubic')
                self.show_rewards_items = false
                self.rewards_print_progress = 0

                if self.type == 'wild' then
                    table.insert(self.rewards, { currency = 'tokens', value = 10 })
                elseif self.type == 'trainer' then
                    table.insert(self.rewards, { currency = 'gold', value = 10 })
                end

                for index, reward in ipairs(self.rewards) do
                    self.player:addCurrency(reward.currency, reward.value)
                end
            end
        elseif self.state == 'rewards' then
            Gamestate.pop({ result = self.result })
        end
    end):setStyle({ font = rewardsFont })

    self.u:add(resultLabel)
    self.u:add(resultButton)

    self.resultLabel = resultLabel
    self.resultButton = resultButton
    self.background = Sprite('resources/background.jpg')

    self.rewards_print_progress = 0
    self.rewards_tween = nil
    self.rewards = {}
end

function BattleState:enter(from, args)
    self.result = nil
    self.paused = false

    self.map = map(8, 6)
    self.pathfinder = pathfinder(self.map)
    self.queue = queue(230, love.graphics.getHeight() - 210)
    self.type = args.type

    self.units = {}
    self.actions = {}

    self.state = 'none'
    self.current_spell = nil
    self.action_complete = false

    self.player = args.player
    self.inventory = inventory(100, 10, self.player.inventory)

    local ranged_i = 1
    local melee_i = 1
    for _, character in ipairs(self.player.party) do
        local isMelee = character.attack_range == 1
        if isMelee then
            self:add_unit(2, melee_i, character, true, true)
            melee_i = melee_i + 1
        else
            self:add_unit(1, ranged_i, character, true, true)
            ranged_i = ranged_i + 1
        end
    end

    -- self:add_unit(4, 3, 'Bat', false)
    local x = math.random(self.map.width - 2, self.map.width)
    local y = math.random(1, self.map.height)
    if math.random(10) > 5 then
        self:add_unit(x, y, 'Quillpaw', false)
    else
        self:add_unit(x, y, 'Dewscale', false)
    end

    self:start_turn()
end

function BattleState:add_unit(x, y, table_or_name, is_player, do_change_character)
    local character_table = table_or_name
    if type(table_or_name) == "string" then
        character_table = characterList[table_or_name]
    end

    local node = self.map:get_node(x, y)
    if not node or node.is_blocked then return false end
    
    local u = Unit(node, is_player):setup(character_table, do_change_character)

    table.insert(self.units, u)
    self.queue:add_actor(u)

    return u
end

function BattleState:remove_unit(unit)
    for index, other in ipairs(self.units) do
        if other == unit then
            table.remove(self.units, index)
        end
    end

    self.queue:remove_actor(unit)
    unit:remove()
    
    self:check_result()
end

function BattleState:leave()
    self.resultLabel:deactivate()
    self.resultButton:deactivate()

    self.map = nil
    self.pathfinder = nil
    self.queue = nil
    
    self.state = 'none'
    self.current_spell = nil
    self.action_type = nil
    self.action_complete = false
    
    self.result = nil

    self.rewards_h = 0
    self.show_rewards_items = false
    
    self.resultButton.y = self.rewards_y + 5
    self.rewards_tween = nil
    self.rewards_print_progress = 0
    self.rewards = {}
end

function BattleState:current_actor()
    return self.queue.current
end

function BattleState:current_action()
    return self.actions[1]
end

function BattleState:add_action(action, pos)
    pos = pos or #self.actions + 1
    table.insert(self.actions, pos, action)
end

function BattleState:unit_death(unit)
    self.queue:remove_actor(unit)

    self:check_result()
end

function BattleState:check_result()
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

    self.state = 'result'
end

function BattleState:showResult()
	assert(self.result ~= 'win' or self.result ~= 'lose', "Wrong result!")
    self.paused = true

    if self.result == 'win' then
        self.resultLabel.text = 'Victory!'
    end
    if self.result == 'lose' then
        self.resultLabel.text = 'Defeat...'
    end

    self.resultLabel:activate()
    self.resultButton:activate()
end

function BattleState:set_target_mode(current_spell, actionType)
    self.current_spell = current_spell
    self.action_type = actionType or 'spell'
    local actor = self:current_actor()

    self.map:reset_nodes()
    -- self.pathfinder:calculate_range(actor.node, current_spell.range)
    self.pathfinder:calculate_range2(actor.node, current_spell.range)

    for _, t in pairs(self.map.tiles._props) do
        t.can_be_selected = current_spell.filter(t) and t.range <= current_spell.range
        t:change_color()
    end

    self.state = 'target'
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
        self.inventory:enable()
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
            self.inventory:disable()

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
        
        if self.state == 'result' then
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
    
    local actor = self.map.highlighted and self.map.highlighted.actor or nil
    table.sort(self.units, function (a, b)
        if a == actor then return false end
        if b == actor then return true end
        return a.y < b.y
    end)
    for i, unit in ipairs(self.units) do
        unit:update(dt)
    end
    self.u:update(dt)
    self.inventory:update(dt)

    if self.state == 'rewards' then
        local complete = false
        if self.rewards_tween then
            complete = self.rewards_tween:update(dt)
            self.resultButton.y = self.rewards_y + self.rewards_h + 10
        end

        if complete then
            self.show_rewards_items = true
            self.rewards_print_progress = self.rewards_print_progress + dt * 2
        end
    end
end

function BattleState:draw()
    local size = 1.3
    local window_width = love.graphics.getWidth()
    local sprite_width = self.background.w * size
    self.background:draw(_, window_width / 2 - sprite_width / 2, -260, 0, size, 1)

    self.map:draw()

    for _, unit in ipairs(self.units) do
        if unit.is_dead then
            unit:draw()
        end
    end

    love.graphics.setLineWidth(1)
    for _, unit in ipairs(self.units) do
        if not unit.is_dead then
            unit:draw()
            unit:draw_health(unit.node.x, unit.node.y)
        end
    end

    local current_action = self:current_action()
    if current_action then
        current_action:draw()
    end
    
    -- love.graphics.setLineWidth(1)
    -- for _, unit in ipairs(self.units) do
    --     unit:draw_health(unit.node.x, unit.node.y)
    --     unit:draw_name()
    -- end
    self.u:draw()
    self.queue:draw()
    self.inventory:draw()

    if self.current_spell then
        local w, h = self.inventory.w, self.inventory.h
        local x, y = self.inventory.x + w + 10, self.inventory.y

        local text = 'Casting: ' .. self.current_spell.name
        local textW = font:getWidth(text)
        local textH = font:getHeight(text)

        local padding = 4

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle('fill', x, y, textW + padding + padding, textH + padding + padding)
        
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle('line', x, y, textW + padding + padding, textH + padding + padding)

        love.graphics.setFont(font)
        PrintText(text, x + padding, y + padding)
    end

    if self.state == 'rewards' then
        love.graphics.setColor(0.3, 0.34, 0.5, 1)
        love.graphics.rectangle('fill', self.rewards_x, self.rewards_y, self.rewards_w, self.rewards_h)

        if self.show_rewards_items then
            love.graphics.setFont(rewardsFont)
            love.graphics.setColor(1, 1, 1, 1)
            for index, reward in ipairs(self.rewards) do
                local str = tostring(reward.value) .. ' ' .. reward.currency
                PrintText(Badprint(str, self.rewards_print_progress), self.rewards_x + 8, self.rewards_y + 8)
            end
        end
    end
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

        if self.state == 'target' then
            if tile and tile.can_be_selected then
                self.state = 'acting'
                local action = Actions[self.action_type]
                local a = self.action_type == 'item' and self.player or actor
                self:add_action(action(a, self.current_spell, tile))
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
    self.inventory:mousepressed(x, y)
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
        if self.state == 'target' then
            self:cancel_target_mode()
            self.panel:show_cancel_button(false)
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