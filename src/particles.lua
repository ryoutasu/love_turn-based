local Particles = Class{}

function Particles:init()
    self.particles = {}
end

function Particles:add(system)
    local t = {
        system = system,
        toRemove = false
    }
    self.particles[#self.particles+1] = t
    return t
end

function Particles:update(dt)
    for i, p in ipairs(self.particles) do
        p.system:update(dt)
        if p.toRemove and p.system:getCount() == 0 then
            table.remove(self.particles, i)
        end
    end
end

function Particles:draw()
    love.graphics.setColor(1, 1, 1, 1)
    for i, p in ipairs(self.particles) do
        love.graphics.draw(p.system)
    end
end

return Particles