local tween = require 'lib.tween'

local imageData = love.image.newImageData(1, 1)
imageData:setPixel(0,0, 0,0,1,1)
local image = love.graphics.newImage(imageData)

local multiplier = 1.5

local Cast = Class{}

local color1 = { 0, 0, 1 }
local color2 = { 0.3, 0.75, 1 }
local color3 = { 1, 1, 1 }
local color4 = { 1, 1, 1, 0 }

local speed = 250
function Cast:init(caster, target)
    target = target.actor

    self.caster = caster
    self.target = target

    self.x = caster.x
    self.y = caster.y

    local dx, dy = self.caster.x - self.target.x, self.caster.y - self.target.y
    local len = math.sqrt(dx * dx + dy * dy)
    self.tween = tween.new(len / speed, self, { x = target.x, y = target.y }, 'inCubic')

    local emissionRate = 1000
    local particle = Particles:add(love.graphics.newParticleSystem(image, emissionRate))
	particle.system:setPosition(self.x, self.y)
	particle.system:setEmissionRate(emissionRate)
    particle.system:setEmissionArea('ellipse', 7, 7)
	particle.system:setParticleLifetime(0.03, 0.07)
	particle.system:setSizes(2)
	particle.system:setColors(color1, color2, color3, color4)

    self.particle = particle
    
    emissionRate = 2500
    local particle2 = Particles:add(love.graphics.newParticleSystem(image, emissionRate))
	particle2.system:setPosition(self.x, self.y)
	particle2.system:setEmissionRate(emissionRate)
    particle2.system:setEmissionArea('borderellipse', 4, 4)
	particle2.system:setParticleLifetime(0.06, 0.1)
	particle2.system:setSizes(2)
	particle2.system:setColors(color2, color3, color4)
    
    self.particle2 = particle2
end

function Cast:update(dt)
    local complete = self.tween:update(dt)
    
	self.particle.system:moveTo(self.x, self.y)
	self.particle2.system:moveTo(self.x, self.y)

    if not complete then return false end

	self.particle.system:pause()
	self.particle2.system:pause()

    self.particle.toRemove = true
    self.particle2.toRemove = true

    local particle = Particles:add(love.graphics.newParticleSystem(image, 3500))
	particle.system:setPosition(self.x, self.y)
    particle.system:setEmissionArea('borderellipse', 7, 7)
	particle.system:setParticleLifetime(0.4, 0.6)
	particle.system:setSizes(2)
	particle.system:setColors(color1, color2, color3, color4)
    particle.system:setRadialAcceleration(150, 200)
    particle.system:emit(300)
    
    particle.toRemove = true

    local damage = self.caster.damage * multiplier
    self.target:take_damage(self.caster, damage)
    
    return true
end

function Cast:draw()

end

local Splash = Class{}

function Splash:init()
    self.name = 'Splash'
    self.type = 'unit'
    self.range = 5
    self.filter = function(target)
        if target.actor and not target.actor.is_player then
            return true
        end
        return false
    end
    self.element = 'water'
    self.cost = 3
    self.cast = Cast
end

return Splash