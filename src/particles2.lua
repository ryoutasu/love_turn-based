local function lerp(v0, v1, t)
    return (1 - t) * v0 + t * v1;
end

local distribution_functions = {
    ['uniform'] = function (dx, dy)
        return math.random(-dx, dx), math.random(-dy, dy)
    end,
    ['ellipse'] = function (dx, dy)
        local p = math.random()
        local angle = math.random() * math.pi * 2
        local x = math.sqrt(p) * math.cos(angle)
        local y = math.sqrt(p) * math.sin(angle)
        return x * dx, y * dy
    end,
    ['borderellipse'] = function (dx, dy)
        local angle = math.random() * math.pi * 2
        local px = dx * math.cos(angle)
        local py = dy * math.sin(angle)
        return px, py
    end,
}

local Particle = Class{}

function Particle:init(drawable, x, y, z, lifetime, colors, linearAcceleration, size)
    self.drawable = drawable
    self.x = x
    self.y = y
    self.z = z
    self.lifetime = lifetime
    self.color = {}
    self.colors = {}
    self.currentColor = 1
    self.timePerColor = lifetime / (#colors - 1)
    self.colorTimer = 0
    self.linearAcceleration = linearAcceleration
    self.speed = { x = 0, y = 0, z = 0 }
    self.size = size
    self.toRemove = false

    for index, color in ipairs(colors) do
        self.colors[index] = { color[1], color[2], color[3], color[4] or 1 }
    end
    self.color = { self.colors[1][1], self.colors[1][2], self.colors[1][3], self.colors[1][4] }
end

function Particle:update(dt)
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        self.toRemove = true
        return
    end

    self.x = self.x + self.speed.x * dt
    self.y = self.y + self.speed.y * dt
    self.z = self.z + self.speed.z * dt

    self.speed.x = self.speed.x + self.linearAcceleration.x * dt
    self.speed.y = self.speed.y + self.linearAcceleration.y * dt
    self.speed.z = self.speed.z + self.linearAcceleration.z * dt

    if #self.colors > 1 then
        self.colorTimer = self.colorTimer + dt
        if self.colorTimer >= self.timePerColor then
            self.colorTimer = self.colorTimer - self.timePerColor
            self.currentColor = self.currentColor + 1
        end

        local color1 = self.colors[self.currentColor]
        local color2 = self.colors[self.currentColor + 1] or color1

        local r = lerp(color1[1], color2[1], self.colorTimer / self.timePerColor)
        local g = lerp(color1[2], color2[2], self.colorTimer / self.timePerColor)
        local b = lerp(color1[3], color2[3], self.colorTimer / self.timePerColor)
        local a = lerp(color1[4], color2[4], self.colorTimer / self.timePerColor)

        self.color = { r, g, b, a }
    end
end

function Particle:draw()
    love.graphics.setColor(self.color)
    love.graphics.draw(self.drawable, self.x, self.y - self.z, 0, self.size, self.size)
end

local Particles = Class{}

function Particles:init(drawable, buffer)
    self.drawable = drawable
    self.buffer = buffer
    self.x = 0
    self.y = 0
    self.z = 0

    self.paused = false

    self.items = {}
    self.newItems = {}

    self.colors = { { 1, 1, 1, 1 } }

    self.minLifetime = 0
    self.maxLifetime = 0

    self.distribution = 0
    self.minEmissionArea = 0
    self.maxEmissionArea = 0

    self.emissionRate = 0
    self.particleCreateTime = 0
    self.timer = 0
    
    self.minLinearAcceleration = { x = 0, y = 0, z = 0 }
    self.maxLinearAcceleration = { x = 0, y = 0, z = 0 }

    self.minSize = 1
    self.maxSize = 1

    self.distribution = 'uniform'
    self.emissionArea = { dx = 0, dy = 0 }
end

function Particles:setPosition(x, y)
    self.x = x
    self.y = y
end

function Particles:setHeight(height)
    self.z = height
end

function Particles:setParticleLifetime(min, max)
    self.minLifetime = min
    self.maxLifetime = max
end

function Particles:setEmissionRate(emissionRate)
    self.emissionRate = emissionRate
    self.particleCreateTime = 1 / emissionRate
    self.timer = 0
end

function Particles:setLinearAcceleration(minx, miny, maxx, maxy)
    -- self.minLinearAcceleration = { x = minx, y = miny }
    -- self.maxLinearAcceleration = { x = maxx or minx, y = maxy or miny }

    self.minLinearAcceleration.x = minx
    self.minLinearAcceleration.y = miny

    self.maxLinearAcceleration.x = maxx or minx
    self.maxLinearAcceleration.y = maxy or miny
end

function Particles:setColors(...)
    local args = {...}
    local colors = {}

    if type(args[1]) == "number" then
        local n = 1
        for i = 1, #args, 4 do
            colors[n] = { args[i], args[i+1], args[i+2], args[i+3] }
            assert(#colors[n] == 4, "Expected red, green, blue, and alpha. Only got " .. #colors[n] .. " of 4 components.")
            n = n + 1
        end
    else
        colors = args
    end

    self.colors = {}
    
    for index, color in ipairs(colors) do
        self.colors[index] = { color[1], color[2], color[3], color[4] or 1 }
    end
end

function Particles:setSizes(min, max)
    self.minSize = min
    self.maxSize = max or min
end

function Particles:setEmissionArea(distribution, dx, dy)
    self.distribution = distribution
    self.emissionArea = { dx = dx, dy = dy }
end

function Particles:setLinearAccelerationZ(min, max)
    self.minLinearAcceleration.z = min
    self.maxLinearAcceleration.z = max or min
end

function Particles:emit(count)
    for i = 1, count do
        if #self.items < self.buffer then
            local x, y = distribution_functions[self.distribution](self.emissionArea.dx, self.emissionArea.dy)
            local lifetime = math.random(self.minLifetime, self.maxLifetime)
            local linearAcceleration = {
                x = math.random(self.minLinearAcceleration.x, self.maxLinearAcceleration.x),
                y = math.random(self.minLinearAcceleration.y, self.maxLinearAcceleration.y),
                z = math.random(self.minLinearAcceleration.z, self.maxLinearAcceleration.z),
            }
            local size = math.random(self.minSize, self.maxSize)
            local particle = Particle(self.drawable, self.x + x, self.y + y, self.z, lifetime, self.colors, linearAcceleration, size)

            if Gamestate.current() == BattleState then
                BattleState:add_object(particle)
            end
            -- table.insert(self.items, particle)
            -- table.insert(self.newItems, particle)
        end
    end
end

function Particles:update(dt)
    self.newItems = {}
    if self.paused then return end

    if self.particleCreateTime > 0 then
        self.timer = self.timer + dt

        while self.timer >= self.particleCreateTime do
            self.timer = self.timer - self.particleCreateTime

            if #self.items < self.buffer then
                local x, y = distribution_functions[self.distribution](self.emissionArea.dx, self.emissionArea.dy)
                local lifetime = math.random(self.minLifetime, self.maxLifetime)
                local linearAcceleration = {
                    x = math.random(self.minLinearAcceleration.x, self.maxLinearAcceleration.x),
                    y = math.random(self.minLinearAcceleration.y, self.maxLinearAcceleration.y),
                    z = math.random(self.minLinearAcceleration.z, self.maxLinearAcceleration.z),
                }
                local size = math.random(self.minSize, self.maxSize)
                local particle = Particle(self.drawable, self.x + x, self.y + y, self.z, lifetime, self.colors, linearAcceleration, size)
                
                if Gamestate.current() == BattleState then
                    BattleState:add_object(particle)
                end
                -- table.insert(self.items, particle)
                -- table.insert(self.newItems, particle)
            end
        end
    end

    -- for i = #self.items, 1, -1 do
    --     local item = self.items[i]
    --     item:update(dt)
    --     if item.toRemove then
    --         table.remove(self.items, i)
    --     end
    -- end

    -- for index, item in ipairs(self.items) do
    --     item:update(dt)
    --     if item.toRemove then
    --         table.remove(self.items, index)
    --     end
    -- end
end

function Particles:draw()
    for index, item in ipairs(self.items) do
        item:draw()
    end
end

return Particles