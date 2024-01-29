local action = require 'src.actions.action'

local Skip = Class{}
Skip:include(action)
Skip.name = 'Skip'

function Skip:init(actor)
    action.init(self, actor)
end

function Skip:update(dt)
    return true
end

function Skip:draw()
    
end

return Skip