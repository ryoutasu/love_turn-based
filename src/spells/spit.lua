-- local tween = require 'lib.tween'

-- local imageData = love.image.newImageData(1, 1)
-- imageData:setPixel(0,0, 1,1,1,1)
-- local image = love.graphics.newImage(imageData)

-- local multiplier = 0.8

-- local Cast = Class{}

-- local speed = 350
-- function Cast:init(caster, target)
--     target = target.actor

--     self.caster = caster
--     self.target = target

--     self.x = caster.x
--     self.y = caster.y

--     local dx, dy = self.caster.x - self.target.x, self.caster.y - self.target.y
--     local len = math.sqrt(dx * dx + dy * dy)
--     self.tween = tween.new(len / speed, self, { x = target.x, y = target.y }, 'inCubic')

--     local emissionRate = 5000
--     local particle = Particles:add(love.graphics.newParticleSystem(image, emissionRate))
-- 	particle.system:setPosition(self.x, self.y)
-- 	particle.system:setEmissionRate(emissionRate)
--     particle.system:setEmissionArea('ellipse', 7, 7)
-- 	particle.system:setParticleLifetime(0.03, 0.08)
-- 	particle.system:setSizes(2)
-- 	particle.system:setColors(1,1,1,1, 0.5,0.5,0.5,1, 1,1,1,0)

--     self.particle = particle
-- end

-- function Cast:update(dt)
--     local complete = self.tween:update(dt)
    
-- 	self.particle.system:moveTo(self.x, self.y)

--     if not complete then return false end

-- 	self.particle.system:pause()

--     self.particle.toRemove = true

--     local particle = Particles:add(love.graphics.newParticleSystem(image, 2000))
-- 	particle.system:setPosition(self.x, self.y)
--     particle.system:setEmissionArea('borderellipse', 7, 7)
-- 	particle.system:setParticleLifetime(0.15, 0.35)
-- 	particle.system:setSizes(2)
-- 	particle.system:setColors(1,1,0,1, 0.5,0.5,0.5,1, 1,1,1,0)
--     particle.system:setRadialAcceleration(75, 100)
--     particle.system:emit(200)
    
--     particle.toRemove = true

--     local damage = self.caster.damage * multiplier
--     self.target:take_damage(self.caster, damage)
    
--     return true
-- end

-- function Cast:draw()

-- end

-- local Spit = Class{}

-- function Spit:init()
--     self.name = 'Spit'
--     self.type = 'unit'
--     self.range = 5
--     self.filter = function(target)
--         if target.actor and not target.actor.is_player then
--             return true
--         end
--         return false
--     end
--     self.element = 'water'
--     self.cost = 2
--     self.cast = Cast
-- end

-- return Spit


local Mover = require 'src.spellcast.mover'
local ParticleEffect = require 'src.spellcast.particleEffect'

local speed = 75
return {
    name = 'Spit',
    type = 'unit',
    range = 5,
    filter = TargetFactory.enemy,
    element = 'water',
    cost = 2,
    cooldown = 2,
    damage = 10,
    onCast = function (spellcast, caster, target)
        local dx, dy = caster.x - target.x, caster.y - target.y
        local len = math.sqrt(dx * dx + dy * dy)

        local particle = ParticleEffect(caster.x, caster.y, {
            emissionRate = 5000, distribution = 'ellipse', dx = 7, dy = 7,
            min = 0.03, max = 0.08, size = 2, colors = { 1,1,1,1, 0.5,0.5,0.5,1, 1,1,1,0 }
        })
        local mover = Mover(particle, target, len / speed, 'inCubic')

        mover:setOnComplete(function ()
            particle:remove()

            local particle2 = ParticleEffect(caster.x, caster.y, {
                emissionRate = 3500, distribution = 'ellipse', dx = 7, dy = 7,
                min = 0.15, max = 0.35, size = 2, colors = { 1,1,0,1, 0.5,0.5,0.5,1, 1,1,1,0 }
            })
            particle2.system:setRadialAcceleration(75, 100)
            particle2.system:emit(200)
            particle2:remove()

            target:take_damage(caster, spellcast.spell.damage)

            spellcast:complete()
        end)

        spellcast:addEffect(mover)
        spellcast:addEffect(particle)
    end
}