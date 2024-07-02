local sprite = require 'src.sprite'

local Animation = Class{}

function Animation:init(path, once, frameTime)
    self.sprite = sprite(path)
    self.frames = {}
    self.frameTime = frameTime or 0.1
    self.time = 0
    self.currentFrame = 1
    self.once = once or false
    self.play = true
end

function Animation:add_frame(x, y, w, h)
    local quad = love.graphics.newQuad(x, y, w, h, self.sprite.w, self.sprite.h)
    self.frames[#self.frames+1] = quad
end

function Animation:get_frame()
    return self.frames[self.currentFrame]
end

function Animation:update(dt)
    if self.play and #self.frames > 0 then
        if #self.frames == 1 then
            self.currentFrame = 1
            return
        end
        
        self.time = self.time + dt
        if self.time >= self.frameTime then
            self.time = self.time - self.frameTime
            if self.currentFrame == #self.frames and self.once then
                self.play = false
            else
                self.currentFrame = self.currentFrame % #self.frames + 1
            end
        end
    end
end

function Animation:draw(x, y, r, sx, sy, ox, oy, ...)
    if not self.play then return end
    
    local quad = self:get_frame()

    if self.flippedH then
        sx = sx * -1
        ox = self.w - ox
    end
    if self.flippedV then
        sy = sy * -1
        oy = self.h - oy
    end

    self.sprite:draw(quad, x, y, r, sx, sy, ox, oy, ...)
end

return Animation