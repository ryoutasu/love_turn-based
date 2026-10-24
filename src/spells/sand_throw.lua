-- local tween = require 'lib.tween'

-- local imageData = love.image.newImageData(1, 1)
-- imageData:setPixel(0,0, 1,1,1,1)
-- local image = love.graphics.newImage(imageData)

-- local multiplier = 1.5

-- local Cast = Class{}

-- local color1 = { 0.8, 0.7, 0.5 }
-- local color2 = { 0.9, 0.8, 0.6 }
-- local color3 = { 1, 1, 1 }
-- local color4 = { 1, 1, 1, 0 }

-- local speed = 750  -- Increase speed for a faster effect
-- function Cast:init(caster, target)
--     target = target.actor

--     self.caster = caster
--     self.target = target

--     self.x = caster.x
--     self.y = caster.y

--     local dx, dy = self.caster.x - self.target.x, self.caster.y - self.target.y
--     local len = math.sqrt(dx * dx + dy * dy)
--     self.tween = tween.new(len / speed, self, { x = target.x, y = target.y }, 'linear')

--     local angle = Vector(dx, dy):angleTo()
--     local particle = Particles:add(love.graphics.newParticleSystem(image, 4000))
--     particle.system:setPosition(self.x, self.y)
--     particle.system:setEmissionRate(4000)
--     particle.system:setEmissionArea('ellipse', 7, 7, angle)
--     particle.system:setParticleLifetime(0.1, 0.3)  -- Shorten particle lifetime for a sharper effect
--     particle.system:setSizes(2)
--     particle.system:setColors(color1, color2, color3, color4)
--     particle.system:setLinearAcceleration(0, 200, 0, 400)  -- Add gravity effect
--     particle.system:setSpeed(100, 200)

--     self.particle = particle
--     self.elapsedTime = 0
-- end

-- function Cast:update(dt)
--     local complete = self.tween:update(dt)
    
--     self.elapsedTime = self.elapsedTime + dt
--     local newRadius = 7 + self.elapsedTime * 20  -- Increase radius more quickly over time
--     self.particle.system:setEmissionArea('ellipse', newRadius, newRadius)
    
--     -- Apply a slight arc effect
--     local arcHeight = 50  -- Adjust this value to change the arc height
--     local progress = self.elapsedTime / (self.tween.duration or 1)
--     self.y = self.y - arcHeight * (1 - (2 * progress - 1) ^ 2)

--     self.particle.system:moveTo(self.x, self.y)

--     if not complete then return false end

--     self.particle.system:pause()
--     self.particle.toRemove = true

--     self.target.miss_chance = self.target.miss_chance + 0.25
--     self.target:add_status_effect({
--         name = 'Sand Throw',
--         duration = 5,
--         target = self.target,
--         caster = self.caster,
--         on_tick = function() end,
--         on_expire = function(self) self.target.miss_chance = self.target.miss_chance - 0.25 end
--     })
    
--     return true
-- end

-- function Cast:draw()

-- end

-- local SandThrow = Class{}

-- function SandThrow:init()
--     self.name = 'Sand Throw'
--     self.type = 'unit'
--     self.range = 10
--     self.filter = function(target)
--         if target.actor and not target.actor.is_player then
--             return true
--         end
--         return false
--     end
--     self.element = 'earth'
--     self.cost = 3
--     self.cast = Cast
-- end

-- return SandThrow

local Mover = require 'src.spellcast.mover'
local ParticleEffect = require 'src.spellcast.particleEffect'

local color1 = { 0.8, 0.7, 0.5 }
local color2 = { 0.9, 0.8, 0.6 }
local color3 = { 1, 1, 1 }
local color4 = { 1, 1, 1, 0 }

local speed = 750
return {
    name = 'Sand Throw',
    type = 'unit',
    range = 1,
    filter = TargetFactory.enemy,
    element = 'neutral',
    cost = 2,
    damage = 10,
    onCast = function (spellcast, caster, target)
        local dx, dy = caster.x - target.x, caster.y - target.y
        local len = math.sqrt(dx * dx + dy * dy)
        local angle = Vector(dx, dy):angleTo()

        local particle = ParticleEffect(caster.x, caster.y, {
            emissionRate = 4000, distribution = 'ellipse', dx = 7, dy = 7,
            min = 0.03, max = 0.08, size = 2, colors = { color1, color2, color3, color4 },
            angle = angle
        })
        particle.system:setLinearAcceleration(0, 200, 0, 400)
        particle.system:setSpeed(100, 200)

        local mover = Mover(particle, target, len / speed, 'linear')

        mover:setOnComplete(function ()
            particle.system:pause()
            particle:remove()
            
            target.miss_chance = target.miss_chance + 0.25
            target:add_status_effect({
                name = 'Sand Throw',
                duration = 5,
                target = target,
                caster = caster,
                on_tick = function() end,
                on_expire = function(self) self.target.miss_chance = self.target.miss_chance - 0.25 end
            })

            spellcast:complete()
        end)

        spellcast:addEffect(mover)
        spellcast:addEffect(particle)
    end
}