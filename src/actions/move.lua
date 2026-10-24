local action = require 'src.actions.action'
local tween = require 'lib.tween'
local attack = require 'src.actions.attack'

local first_last_time = 0.8
local move_time = 0.3
local step_time = 0.4
local step_distance = 80

local Move = Class{}
Move:include(action)
Move.name = 'Move'

function Move:init(actor, path, pathfinder, attack_target)
    action.init(self, actor)

    self.path = path
    self.pathfinder = pathfinder
    self.attack_target = attack_target
end

function Move:start()
    local tile = table.remove(self.path, 1)
    if next(self.path) then
        self.tween = tween.new(first_last_time, self.actor, { x = tile.x, y = tile.y + UNIT_ALIVE_OFFSET }, 'inCubic')
    else
        self.tween = tween.new(first_last_time, self.actor, { x = tile.x, y = tile.y + UNIT_ALIVE_OFFSET }, 'inOutCubic')
    end
    self.tile = tile

    self.actor.is_moving = true

    -- self.last_point = Vector(self.actor.x, self.actor.y)
end

function Move:update(dt)
    -- local distance = Vector(self.actor.x, self.actor.y):dist(self.last_point)
    -- if distance >= step_distance then
    --     PlaySound(StepSound)
    --     self.last_point = Vector(self.actor.x, self.actor.y)
    -- end

    local complete = self.tween:update(dt)
    if not complete then return false end

    for index, effect in ipairs(self.tile.effects) do
        local triggered = effect.trigger(self.actor)
        if triggered then
            effect.triggered = true

            for _, tile in ipairs(self.path) do
                tile:hide_path()
            end

            self.path = {}
            self.attack_target = false
        end
    end

    if next(self.path) then
        self.tile:hide_path()
        local tile = table.remove(self.path, 1)
        if next(self.path) then
            self.tween = tween.new(move_time, self.actor, { x = tile.x, y = tile.y + UNIT_ALIVE_OFFSET }, 'linear')
        else
            self.tween = tween.new(first_last_time, self.actor, { x = tile.x, y = tile.y + UNIT_ALIVE_OFFSET }, 'outCubic')
        end
        self.tile = tile
    else
        self.tile:hide_path()
        self.actor:set_tile(self.tile)
        self.actor.is_moving = false
        
        if self.attack_target then
            BattleState:add_action(attack(self.actor, self.attack_target))
        end

        return true
    end

    return false
end

function Move:draw()
    
end

return Move