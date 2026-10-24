local imageData = love.image.newImageData(1, 1)
imageData:setPixel(0,0, 1,1,1,1)
local image = love.graphics.newImage(imageData)

local ParticleEffect = Class{}

function ParticleEffect:init(x, y, params)
    self.x = x
    self.y = y

    local emissionRate = params.emissionRate or 1000
    local particle = Particles:add(love.graphics.newParticleSystem(image, emissionRate))
    self.particle = particle
    self.system = particle.system

	self.system:setPosition(x, y)
	self.system:setEmissionRate(emissionRate)
    self.system:setEmissionArea(params.distribution or 'ellipse', params.dx or 5, params.dy or 5, params.angle or 0)
	self.system:setParticleLifetime(params.min or 0.03, params.max or 0.08)
	self.system:setSizes(params.size or 2)
	self.system:setColors(params.colors)
end

function ParticleEffect:remove()
    self.particle.toRemove = true
end

function ParticleEffect:update(dt)
	self.system:moveTo(self.x, self.y)
end

function ParticleEffect:draw()
    
end

return ParticleEffect