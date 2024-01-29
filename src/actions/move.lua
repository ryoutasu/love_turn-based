local action = require 'src.actions.action'
local tween = require 'lib.tween'
local attack = require 'src.actions.attack'

local first_last_time = 0.8
local move_time = 0.3

local Move = Class{}
Move:include(action)

function Move:init(actor, path, pathfinder, attack_target)
    action.init(self, actor)

    self.path = path
    self.pathfinder = pathfinder
    self.attack_target = attack_target

    local node = table.remove(self.path, 1)
    if next(self.path) then
        self.tween = tween.new(first_last_time, actor, { x = node.x, y = node.y }, 'inCubic')
    else
        self.tween = tween.new(first_last_time, self.actor, { x = node.x, y = node.y }, 'inOutCubic')
    end
    self.node = node
end

function Move:update(dt)
    local complete = self.tween:update(dt)
    if not complete then return false end

    if next(self.path) then
        self.node:hide_path()
        local node = table.remove(self.path, 1)
        if next(self.path) then
            self.tween = tween.new(move_time, self.actor, { x = node.x, y = node.y }, 'linear')
        else
            self.tween = tween.new(first_last_time, self.actor, { x = node.x, y = node.y }, 'outCubic')
        end
        self.node = node
    else
        self.node:hide_path()
        self.actor:set_node(self.node)
        
        if self.attack_target then
            -- self.actor:set_current_action(attack, self.attack_target)
            self.actor.current_action = attack(self.actor, self.attack_target)
            return false
        end

        return true
    end

    return false
end

function Move:draw()
    
end

return Move