-- local animation = require 'src.animation'

-- local Cast = Class{}

-- function Cast:init(caster, target)
--     target = target.actor

--     self.caster = caster
--     self.target = target
--     self.x = target.x
--     self.y = target.y

--     -- Apply poison to all targets in area
--     for _, tile in pairs(BattleState.map.tiles._props) do
--         if tile.aoe_target and tile.actor and not tile.actor.is_player then
--             tile.actor:add_status_effect({
--                 name = 'Poison',
--                 duration = 3,
--                 target = tile.actor,
--                 caster = self.caster,
--                 on_tick = function(self)
--                     self.target:take_damage(self.caster, 3, false, self.spell and self.spell.element, { is_spell = true })
--                 end,
--                 on_expire = function() end
--             })
--         end
--     end

--     -- Visual effect
--     local effect = animation('resources/simplefx-alpha.png', true)
--     local x, y = 0, 192  -- Purple effect row
--     for i = 1, 7 do
--         effect:add_frame(x, y, 32, 48)
--         x = x + 32
--     end
--     effect.frameTime = 0.05
--     self.effect = effect
-- end

-- function Cast:update(dt)
--     self.effect:update(dt)
--     return not self.effect.play
-- end

-- function Cast:draw()
--     love.graphics.setColor(1, 1, 1, 0.8)
--     self.effect:draw(self.x, self.y, 0, 3, 3)
-- end

-- local PoisonCloud = Class{}

-- function PoisonCloud:init()
--     self.name = 'Poison Cloud'
--     self.type = 'AOE'
--     self.range = 3
--     self.radius = 2
--     self.element = 'poison'
--     self.cost = 4
--     self.filter = function() return true end
--     self.cast = Cast
-- end

-- return PoisonCloud

local VisualEffect = require 'src.spellcast.visualEffect'
local SimpleSwoosh = require 'src.spellcast.effects.simpleSwoosh'

return {
    name = 'Poison Cloud',
    type = 'AOE',
    range = 3,
    radius = 2,
    filter = TargetFactory.any,
    element = 'plant',
    cost = 4,
    onCast = function (spellcast, caster, target)
        local x = caster.x + (target.x - caster.x)/2
        local y = caster.y + (target.y - caster.y)/2
        local dx, dy = target.x - caster.x, target.y - caster.y
        local effect = VisualEffect(SimpleSwoosh(), { x = x, y = y, r = math.atan2(dy, dx), sx = 1, sy = 2, { 1, 1, 1, 0.8 } } )
        effect:setOnComplete(function ()
            for _, tile in pairs(BattleState.map.tiles._props) do
                if tile.aoe_target and tile.actor and not tile.actor.is_player then
                    tile.actor:add_status_effect({
                        name = 'Poison',
                        duration = 3,
                        target = tile.actor,
                        caster = caster,
                        on_tick = function(self)
                            self.target:take_damage(self.caster, 3, false, 'plant', { is_spell = true })
                        end,
                        on_expire = function() end
                    })
                end
            end
            spellcast:complete()
        end)
        spellcast:addEffect(effect)
    end
}