local Timer = Class{}

function Timer:init()
end

function Timer:after(time, func)
    self.afterTime = time
    self.afterFunc = func
    self.afterElapsed = 0
end

function Timer:every(time, func)
    self.everyTime = time
    self.everyFunc = func
    self.everyElapsed = 0
end

function Timer:update(dt)
    self.afterElapsed = self.afterElapsed + dt
    if self.afterElapsed >= self.afterTime then
        self.afterElapsed = self.afterElapsed - self.afterTime
        self:afterFunc(dt)
    end
    
    self.everyElapsed = self.everyElapsed + dt
    if self.everyElapsed >= self.everyTime then
        self.everyElapsed = self.everyElapsed - self.everyTime
        self:everyFunc(dt)
    end
end

function Timer:draw()
    
end

return Timer