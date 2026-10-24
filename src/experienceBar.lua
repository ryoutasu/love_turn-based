local font = love.graphics.newFont(16)

local ExperienceBar = Class{}

function ExperienceBar:init(x, y, width, height)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.currentExp = 0
    self.maxExp = 100
    self.level = 0
end

function ExperienceBar:update(currentExp, maxExp, level)
    self.currentExp = currentExp
    self.maxExp = maxExp
    self.level = level or 0
end

function ExperienceBar:draw()
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle('fill', self.x, self.y, self.width, self.height)
    
    -- Experience fill
    local fillWidth = (self.currentExp / self.maxExp) * self.width
    love.graphics.setColor(0.6, 0.8, 0.2, 1)
    love.graphics.rectangle('fill', self.x, self.y, fillWidth, self.height)
    
    -- Border
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle('line', self.x, self.y, self.width, self.height)
    
    -- Text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(font)

    PrintfText('Level ' .. self.level, self.x + 3, self.y + 2, self.width - 8, 'left')
    PrintfText(self.currentExp .. ' / ' .. self.maxExp, self.x + 3, self.y + 2, self.width - 8, 'right')
end

return ExperienceBar