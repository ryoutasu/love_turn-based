local action = require 'src.actions.action'

local Skip = Class{}
Skip:include(action)
Skip.name = 'Skip'

function Skip:init(actor)
    action.init(self, actor)
    
    Tagtext:add('Skip', self.actor.x - 25, self.actor.y - 40, 2, 30, { 1, 1, 1 })
end

function Skip:update(dt)
    return true
end

function Skip:draw()
    
end

return Skip