local action = require 'src.actions.action'

local Skip = Class{}
Skip:include(action)
Skip.name = 'Skip'

function Skip:init(actor)
    action.init(self, actor)
end

function Skip:start()
    Tagtext:add('Skip', self.actor.x - 25, self.actor.y - 40, 2, 30, { 1, 1, 1 })
    BattleState.end_turn = true
end

function Skip:update(dt)
    return true
end

function Skip:draw()
    
end

return Skip