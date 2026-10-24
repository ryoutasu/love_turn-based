local Sprite = Class{}

local images = {}

function Sprite:init(path, color)
    local image = images[path]
    if image == nil then
        if path and love.filesystem.getInfo(path) then
            image = love.graphics.newImage(path)
            images[path] = image
        else
            local radius = 140 * CHARACTERS_SCALE/2 -8
            local imageData = love.image.newImageData(140 * CHARACTERS_SCALE, 140 * CHARACTERS_SCALE)
            imageData:mapPixel(function (x,y, r,g,b,a)
                local ax, ay = x - radius - 8, y - radius - 8
                if (ax * ax + ay * ay) <= radius*radius then
                    if color then
                        return love.math.colorFromBytes(color)
                    else
                        return 1, 0, 1, 1
                    end
                end
                
                return 0, 0, 0, 0
            end)

            image = love.graphics.newImage(imageData)
        end
    end
    self.image = image
    self.path = path

    self.w = image:getWidth()
    self.h = image:getHeight()
end

function Sprite:update(dt)
    
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