-- local tween = require 'lib.tween'

-- local imageData = love.image.newImageData(1, 1)
-- imageData:setPixel(0,0, 0,0,1,1)
-- local image = love.graphics.newImage(imageData)

-- local multiplier = 1.5

-- local Cast = Class{}

-- local color1 = { 0, 0, 1 }
-- local color2 = { 0.3, 0.75, 1 }
-- local color3 = { 1, 1, 1 }
-- local color4 = { 1, 1, 1, 0 }

-- local speed = 75
-- function Cast:init(caster, target)
--     target = target.actor

--     self.caster = caster
--     self.target = target

--     self.x = caster.x
--     self.y = caster.y

--     local dx, dy = self.caster.x - self.target.x, self.caster.y - self.target.y
--     local len = math.sqrt(dx * dx + dy * dy)
--     self.tween = tween.new(len / speed, self, { x = target.x, y = target.y }, 'inCubic')

--     local emissionRate = 1000
--     local particle = Particles:add(love.graphics.newParticleSystem(image, emissionRate))
-- 	particle.system:setPosition(self.x, self.y)
-- 	particle.system:setEmissionRate(emissionRate)
--     particle.system:setEmissionArea('ellipse', 7, 7)
-- 	particle.system:setParticleLifetime(0.03, 0.07)
-- 	particle.system:setSizes(2)
-- 	particle.system:setColors(color1, color2, color3, color4)

--     self.particle = particle
    
--     emissionRate = 2500
--     local particle2 = Particles:add(love.graphics.newParticleSystem(image, emissionRate))
-- 	particle2.system:setPosition(self.x, self.y)
-- 	particle2.system:setEmissionRate(emissionRate)
--     particle2.system:setEmissionArea('borderellipse', 4, 4)
-- 	particle2.system:setParticleLifetime(0.06, 0.1)
-- 	particle2.system:setSizes(2)
-- 	particle2.system:setColors(color2, color3, color4)
    
--     self.particle2 = particle2
-- end

-- function Cast:update(dt)
--     local complete = self.tween:update(dt)
    
-- 	self.particle.system:moveTo(self.x, self.y)
-- 	self.particle2.system:moveTo(self.x, self.y)

--     if not complete then return false end

-- 	self.particle.system:pause()
-- 	self.particle2.system:pause()

--     self.particle.toRemove = true
--     self.particle2.toRemove = true

--     local particle = Particles:add(love.graphics.newParticleSystem(image, 3500))
-- 	particle.system:setPosition(self.x, self.y)
--     particle.system:setEmissionArea('borderellipse', 7, 7)
-- 	particle.system:setParticleLifetime(0.4, 0.6)
-- 	particle.system:setSizes(2)
-- 	particle.system:setColors(color1, color2, color3, color4)
--     particle.system:setRadialAcceleration(150, 200)
--     particle.system:emit(300)
    
--     particle.toRemove = true

--     local damage = self.caster.damage * multiplier
--     self.target:take_damage(self.caster, damage)
    
--     return true
-- end

-- function Cast:draw()

-- end

-- local Splash = Class{}

-- function Splash:init()
--     self.name = 'Splash'
--     self.type = 'unit'
--     self.range = 5
--     self.filter = function(target)
--         if target.actor and not target.actor.is_player then
--             return true
--         end
--         return false
--     end
--     self.element = 'water'
--     self.cost = 3
--     self.cast = Cast
-- end

-- return Splash

local Mover = require 'src.spellcast.mover'
local ParticleEffect = require 'src.spellcast.particleEffect'

local color1 = { 0, 0, 1 }
local color2 = { 0.3, 0.75, 1 }
local color3 = { 1, 1, 1 }
local color4 = { 1, 1, 1, 0 }

local speed = 75
return {
    name = 'Splash',
    type = 'unit',
    range = 5,
    filter = TargetFactory.enemy,
    element = 'water',
    cost = 3,
    cooldown = 2,
    damage = 10,
    onCast = function (spellcast, caster, target)
        local dx, dy = caster.x - target.x, caster.y - target.y
        local len = math.sqrt(dx * dx + dy * dy)

        local particle = ParticleEffect(caster.x, caster.y, {
            emissionRate = 1000, distribution = 'ellipse', dx = 7, dy = 7,
            min = 0.03, max = 0.07, size = 2, colors = { color1, color2, color3, color4 }
        })
        local mover = Mover(particle, target, len / speed, 'inCubic')
        
        local particle2 = ParticleEffect(caster.x, caster.y, {
            emissionRate = 2500, distribution = 'borderellipse', dx = 4, dy = 4,
            min = 0.06, max = 0.1, size = 2, colors = { color2, color3, color4 }
        })
        local mover2 = Mover(particle2, target, len / speed, 'inCubic')

        mover:setOnComplete(function ()
            particle:remove()
            particle2:remove()

            local particle3 = ParticleEffect(caster.x, caster.y, {
                emissionRate = 3500, distribution = 'borderellipse', dx = 7, dy = 7,
                min = 0.4, max = 0.6, size = 2, colors = { color1, color2, color3, color4 }
            })
            particle3.system:setRadialAcceleration(150, 200)
            particle3.system:emit(300)
            particle3:remove()

            spellcast:dealDamage(target)

            spellcast:complete()
        end)

        spellcast:addEffect(mover)
        spellcast:addEffect(mover2)
        spellcast:addEffect(particle)
        spellcast:addEffect(particle2)
    end
}