local Tagtext = Class{}

function Tagtext:init()
    self.array = {}
end

function Tagtext:add(text, x, y, time, speed, color)
    local t = {
        text = text,
        x = x, y = y,
        speed = speed,
        time = time,
        remaining = time,
        color = color
    }
    t.color[4] = 1
    table.insert(self.array, t)
end

function Tagtext:update(dt)
    for i, t in ipairs(self.array) do
        t.remaining = t.remaining - dt

        if t.remaining <= 0 then
            table.remove(self.array, i)
        end

        t.y = t.y - t.speed * dt
        -- t.alpha = 
        t.color[4] = t.remaining / t.time
    end
end

function Tagtext:draw()
    for i, t in ipairs(self.array) do
        love.graphics.setColor(t.color or { 0, 0, 0, t.remaining / t.time })
        love.graphics.print(t.text, t.x, t.y)
    end
end

return Tagtext