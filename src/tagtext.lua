local Tagtext = Class{}

function Tagtext:init()
    self.array = {}
end

function Tagtext:add(text, x, y, time, speed, color, fadeTime)
    local t = {
        text = text,
        x = x, y = y,
        speed = speed,
        time = time,
        remaining = time,
        color = color,
        fadeTime = fadeTime or 1,
        remainingFadeTime = fadeTime or 1
    }
    t.color[4] = 1
    table.insert(self.array, t)
end

function Tagtext:update(dt)
    for i, t in ipairs(self.array) do
        if t.remaining > 0 then
            t.remaining = t.remaining - dt
        else
            t.remainingFadeTime = t.remainingFadeTime - dt
            t.color[4] = t.remainingFadeTime / t.fadeTime
        end

        if t.remaining + t.remainingFadeTime <= 0 then
            table.remove(self.array, i)
        end

        t.y = t.y - t.speed * dt
        -- t.alpha = 
    end
end

function Tagtext:draw()
    for i, t in ipairs(self.array) do
        love.graphics.setColor(t.color or { 0, 0, 0, t.remainingFadeTime / t.fadeTime })
        love.graphics.print(t.text, t.x, t.y)
    end
end

return Tagtext