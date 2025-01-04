local tween = require 'lib.tween'

local imageData = love.image.newImageData(1, 1)
imageData:setPixel(0,0, 1,1,1,1)
local image = love.graphics.newImage(imageData)

local multiplier = 1.5

local Fireball = Class{
    name = 'Fireball',
    type = 'unit',
    range = 20,
    filter = function(target)
        if target.actor and not target.actor.is_player then
            return true
        end
        return false
    end,
    element = 'fire',
    cost = 0,
}

local speed = 500
function Fireball:init(caster, target)
    target = target.actor

    self.caster = caster
    self.target = target

    self.x = caster.x
    self.y = caster.y

    local dx, dy = self.caster.x - self.target.x, self.caster.y - self.target.y
    local len = math.sqrt(dx * dx + dy * dy)
    self.tween = tween.new(len / speed, self, { x = target.x, y = target.y }, 'inCubic')

    local emissionRate = 5000
    local particle = Particles:add(love.graphics.newParticleSystem(image, emissionRate))
	particle.system:setPosition(self.x, self.y)
	particle.system:setEmissionRate(emissionRate)
    particle.system:setEmissionArea('ellipse', 7, 7)
	particle.system:setParticleLifetime(0.03, 0.08)
	particle.system:setSizes(2)
	particle.system:setColors(1,1,1,1, 1,1,0,1, 1,0,0,1, 1,0,0,0)

    self.particle = particle
    
    emissionRate = 3500
    local particle2 = Particles:add(love.graphics.newParticleSystem(image, emissionRate))
	particle2.system:setPosition(self.x, self.y)
	particle2.system:setEmissionRate(emissionRate)
    particle2.system:setEmissionArea('borderellipse', 4, 4)
	particle2.system:setParticleLifetime(0.1, 0.15)
	particle2.system:setSizes(2)
	particle2.system:setColors(1,1,0,1, 1,0,0,1, 1,0,0,0)
    
    self.particle2 = particle2
end

function Fireball:update(dt)
    local complete = self.tween:update(dt)
    
	self.particle.system:moveTo(self.x, self.y)
	self.particle2.system:moveTo(self.x, self.y)

    if not complete then return false end

    -- if not self.delay then
    --     self.delay = 1

        self.particle.system:pause()
        self.particle2.system:pause()
    
        self.particle.toRemove = true
        self.particle2.toRemove = true
    
        local particle = Particles:add(love.graphics.newParticleSystem(image, 3500))
        particle.system:setPosition(self.x, self.y)
        particle.system:setEmissionArea('borderellipse', 7, 7)
        particle.system:setParticleLifetime(0.4, 0.6)
        particle.system:setSizes(2)
        particle.system:setColors(1,1,1,1, 1,1,0,1, 1,0,0,1, 1,0,0,0)
        particle.system:setRadialAcceleration(150, 200)
        particle.system:emit(800)
        
        particle.toRemove = true
    
        local damage = self.caster.damage * multiplier
        self.target:take_damage(self.caster, 200)
    -- end

    -- self.delay = self.delay - dt
    -- if self.delay > 0 then return false end
    
    return true
end

function Fireball:draw()

end

return Fireball