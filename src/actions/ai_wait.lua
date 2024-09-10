local action = require 'src.actions.action'
local move = require 'src.actions.move'

local AI_Wait = Class{}
AI_Wait:include(action)
AI_Wait.name = 'AI Wait'

local decide_time = 3
local move_distance = 3
function AI_Wait:init(actor)
    action.init(self, actor)
end

function AI_Wait:start()
    self.actor.node:set_animation('border_fill', decide_time, { 1, 0, 0, 1 })
    self.time = 0
end

function AI_Wait:update(dt)
    self.time = self.time + dt
    if self.time > decide_time then
        self.actor.node:set_animation(nil)
        return true
    end
    return false
end

function AI_Wait:draw()
end

return AI_Wait