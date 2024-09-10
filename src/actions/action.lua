local Action = Class{}

function Action:init(actor)
    self.actor = actor
    self.is_new = true
    self.is_complete = false
end

function Action:start()
end

function Action:update()
end

function Action:draw()
end

return Action