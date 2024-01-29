local Sprite = Class{}

local images = {}

function Sprite:init(path)
    local image = images[path]
    if image == nil then
        image = love.graphics.newImage(path)
        images[path] = image
    end
    self.image = image

    self.w = image:getWidth()
    self.h = image:getHeight()
end

function Sprite:draw(quad, x, y, r, sx, sy, ox, oy, ...)
    r,sx,sy,ox,oy = r or 0, sx or 1, sy or 1, ox or 0, oy or 0
    
    if quad then
        local _, _, w, h = quad:getViewport()
    
        if self.flippedH then
            sx = sx * -1
            ox = w - ox
        end
        if self.flippedV then
            sy = sy * -1
            oy = h - oy
        end

        love.graphics.draw(self.image, quad, x, y, r, sx, sy, ox, oy, ...)
    else
        if self.flippedH then
            sx = sx * -1
            ox = self.w - ox
        end
        if self.flippedV then
            sy = sy * -1
            oy = self.h - oy
        end

        love.graphics.draw(self.image, x, y, r, sx, sy, ox, oy, ...)
    end
end

return Sprite