-- --[[Сделай способность, которая поджигает врага, накладывая на него эффект горения.
--     За основу возьми способность sandThrow.
--     Добавь эффект визуальный горения.
-- ]]

-- local tween = require 'lib.tween'
-- local SeparateParticles = require 'src.particles2'

-- local imageData = love.image.newImageData(1, 1)
-- imageData:setPixel(0,0, 1,1,1,1)
-- local image = love.graphics.newImage(imageData)

-- local Cast = Class{}

-- local color1 = { 1, 0, 0 }
-- local color2 = { 1, 0.5, 0 }
-- local color3 = { 1, 1, 0 }
-- local color4 = { 1, 1, 1, 0 }

-- local castTime = 2

-- function Cast:init(caster, target)
--     target = target.actor

--     self.caster = caster
--     self.target = target

--     self.x = target.x
--     self.y = target.y

--     self.timer = 0
    
--     emissionRate = 250

--     local particles = SeparateParticles(image, 10000)
-- 	particles:setPosition(caster.x, caster.y)
-- 	particles:setEmissionRate(emissionRate)
--     particles:setEmissionArea('borderellipse', 50, 20)
-- 	particles:setParticleLifetime(0.4, 0.8)
-- 	particles:setSizes(4)
-- 	particles:setColors(1,1,1,1, 1,1,0,1, 1,0,0,1, 1,0,0,0)
--     particles:setLinearAccelerationZ(80, 120)

--     self.particles = particles

--     local particles2 = SeparateParticles(image, 10000)
-- 	particles2:setPosition(target.x, target.y)
-- 	particles2:setEmissionRate(emissionRate)
--     particles2:setEmissionArea('borderellipse', 50, 20)
-- 	particles2:setParticleLifetime(0.4, 0.8)
-- 	particles2:setSizes(4)
-- 	particles2:setColors(1,1,1,1, 1,1,0,1, 1,0,0,1, 1,0,0,0)
--     particles2:setLinearAccelerationZ(80, 120)

--     self.particles2 = particles2

--     self.target:add_status_effect({
--         name = 'Ignite',
--         duration = 4,
--         target = self.target,
--         caster = self.caster,
--         on_tick = function(self)
--             -- local tick_damage = self.caster.damage * 0.2
--             local tick_damage = 3
--             self.target:take_damage(self, tick_damage)

--             local burn_particle = SeparateParticles(image, 1000)
--             burn_particle:setPosition(self.target.x, self.target.y)
--             burn_particle:setEmissionArea('ellipse', 50, 20)
--             burn_particle:setParticleLifetime(0.5, 1)
--             burn_particle:setSizes(4)
--             burn_particle:setColors(color1, color2, color3, color4)
--             burn_particle:setLinearAccelerationZ(75, 150)
--             burn_particle:emit(200)  -- Ensure particles are emitted
--             for index, value in ipairs(burn_particle.newItems) do
--                 BattleState:add_object(value)
--             end
--             burn_particle.toRemove = true
--         end,
--         on_expire = function() end
--     })
-- end

-- function Cast:update(dt)
--     self.particles:update(dt)
--     for index, value in ipairs(self.particles.newItems) do
--         BattleState:add_object(value)
--     end

--     self.particles2:update(dt)
--     for index, value in ipairs(self.particles2.newItems) do
--         BattleState:add_object(value)
--     end

--     self.timer = self.timer + dt
--     if self.timer < castTime then
--         return false
--     end

--     self.particles.paused = true
--     self.particles2.paused = true

--     return true
-- end

-- function Cast:draw()

-- end

-- local Ignite = Class{}

-- function Ignite:init()
--     self.name = 'Ignite'
--     self.type = 'unit'
--     self.range = 5
--     self.filter = function(target)
--         if target.actor and not target.actor.is_player then
--             return true
--         end
--         return false
--     end
--     self.element = 'fire'
--     self.cost = 3
--     self.cooldown = 2
--     self.cast = Cast
-- end

-- return Ignite

local SeparateParticles = require 'src.particles2'
local Timer = require 'src.spellcast.timer'

local imageData = love.image.newImageData(1, 1)
imageData:setPixel(0,0, 1,1,1,1)
local image = love.graphics.newImage(imageData)

local color1 = { 1, 0, 0 }
local color2 = { 1, 0.5, 0 }
local color3 = { 1, 1, 0 }
local color4 = { 1, 1, 1, 0 }

return {
    name = 'Ignite',
    type = 'unit',
    range = 5,
    filter = TargetFactory.enemy,
    element = 'ember',
    cost = 3,
    cooldown = 2,
    onCast = function (spellcast, caster, target)
        emissionRate = 250

        local particles = SeparateParticles(image, 10000)
        particles:setPosition(caster:bottom())
        particles:setEmissionRate(emissionRate)
        particles:setEmissionArea('borderellipse', 50, 20)
        particles:setParticleLifetime(0.4, 0.8)
        particles:setSizes(4)
        particles:setColors(1,1,1,1, 1,1,0,1, 1,0,0,1, 1,0,0,0)
        particles:setLinearAccelerationZ(80, 120)

        local particles2 = SeparateParticles(image, 10000)
        particles2:setPosition(target:bottom())
        particles2:setEmissionRate(emissionRate)
        particles2:setEmissionArea('borderellipse', 50, 20)
        particles2:setParticleLifetime(0.4, 0.8)
        particles2:setSizes(4)
        particles2:setColors(1,1,1,1, 1,1,0,1, 1,0,0,1, 1,0,0,0)
        particles2:setLinearAccelerationZ(80, 120)

        local timer = Timer()
        timer:every(0, function (t, dt)
            particles:update(dt)
            particles2:update(dt)
        end)

        timer:after(2, function ()
            particles.paused = true
            particles2.paused = true

            target:add_status_effect({
                name = 'Ignite',
                duration = 4,
                target = target,
                caster = caster,
                on_tick = function(self)
                    local tick_damage = 3
                    self.target:take_damage(caster, tick_damage)

                    local burn_particle = SeparateParticles(image, 1000)
                    burn_particle:setPosition(self.target:bottom())
                    burn_particle:setEmissionArea('ellipse', 50, 20)
                    burn_particle:setParticleLifetime(0.5, 1)
                    burn_particle:setSizes(4)
                    burn_particle:setColors(color1, color2, color3, color4)
                    burn_particle:setLinearAccelerationZ(75, 150)
                    burn_particle:emit(300)
                    burn_particle.toRemove = true
                end,
                on_expire = function() end
            })
            spellcast:complete()
        end)
        spellcast:addEffect(timer)
    end
}