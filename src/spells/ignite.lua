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
                    -- Горение — это урон огнём, а не «чистый» урон:
                    -- иначе plant-цели не получают штраф, а ember-цели — нет.
                    self.target:take_damage(caster, tick_damage, false, 'ember', { is_spell = true })

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