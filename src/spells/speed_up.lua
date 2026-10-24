-- local tween = require 'lib.tween'

-- local imageData = love.image.newImageData(1, 1)
-- imageData:setPixel(0,0, 1,1,1,1)
-- local image = love.graphics.newImage(imageData)

-- local Cast = Class{}

-- function Cast:init(caster, target)
--     target = target.actor

--     self.caster = caster
--     self.target = target

--     self.x = target.x
--     self.y = target.y

--     local effect = Particles:add(love.graphics.newParticleSystem(image, 1000))
--     effect.system:setPosition(self.x, self.y)
--     effect.system:setEmissionRate(1000)
--     effect.system:setEmissionArea('ellipse', 7, 7)
--     effect.system:setParticleLifetime(0.2, 0.5)
--     effect.system:setSizes(2)
--     effect.system:setColors(0, 1, 0, 1, 0, 1, 0, 0)
--     effect.system:setLinearAcceleration(0, -100, 0, -200)

--     self.effect = effect
-- end

-- function Cast:update(dt)
--     self.effect.system:moveTo(self.x, self.y)

--     self.effect.system:emit(1000)
--     self.effect.system:pause()
--     self.effect.toRemove = true

--     self.target:add_bonus_stat('initiative', 4)
--     BattleState.queue:sort_next()
--     self.target:add_status_effect({
--         name = 'Speed Up',
--         duration = 5,
--         target = self.target,
--         caster = self.caster,
--         on_tick = function() end,
--         on_expire = function(self) self.target:add_bonus_stat('initiative', -4); BattleState.queue:sort_next() end
--     })
    
--     return true
-- end

-- function Cast:draw()

-- end

-- local SpeedUp = Class{}

-- function SpeedUp:init()
--     self.name = 'Speed Up'
--     self.type = 'unit'
--     self.range = 5
--     self.filter = function(target)
--         if target.actor and target.actor.is_player then
--             return true
--         end
--         return false
--     end
--     self.element = 'wind'
--     self.cost = 2
--     self.cast = Cast
-- end

-- return SpeedUp

return {
    name = 'Speed Up',
    type = 'unit',
    range = 5,
    filter = TargetFactory.ally,
    element = 'storm',
    cost = 2,
    cooldown = 2,
    onCast = function (spellcast, caster, target)
        -- target:add_bonus_stat('initiative', 4)
        -- target:add_status_effect({
        --     name = 'Speed Up',
        --     duration = 5,
        --     target = target,
        --     caster = caster,
        --     on_tick = function() end,
        --     on_expire = function(self) self.target:add_bonus_stat('initiative', -4) end
        -- })

        target:addModifier(Modifier.battleAdd('initiative', 3, {
            id = 'speed_buff',
            duration = { type = 'turn', value = 3 },
        }))

        spellcast:complete()
    end
}