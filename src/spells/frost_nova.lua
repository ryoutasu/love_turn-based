-- local animation = require 'src.animation'

-- local Cast = Class{}

-- function Cast:init(caster, target)
--     target = target.actor

--     self.caster = caster
--     self.target = target
--     self.x = target.x
--     self.y = target.y

--     local effect = animation('resources/simplefx-alpha.png', true)
--     local x = 0
--     local y = 144  -- Ice effect row
--     for i = 1, 7 do
--         effect:add_frame(x, y, 32, 48)
--         x = x + 32
--     end
--     effect.frameTime = 0.25
--     self.effect = effect

--     -- Apply AOE damage and slow
--     for _, tile in pairs(BattleState.map.tiles._props) do
--         if tile.aoe_target and tile.actor and not tile.actor.is_player then
--             tile.actor:take_damage(self.caster, 10)
--             tile.actor:add_status_effect({
--                 name = 'Frost Slow',
--                 duration = 3,
--                 target = tile.actor,
--                 caster = self.caster,
--                 on_tick = function() end,
--                 on_expire = function(self) 
--                     self.target:add_bonus_stat('initiative', 3)
--                 end
--             })
--             tile.actor:add_bonus_stat('initiative', -3)
--         end
--     end
-- end

-- function Cast:update(dt)
--     self.effect:update(dt)
--     local _, _, w, h = self.effect:get_frame():getViewport()
--     self.ox = w / 2
--     self.oy = h / 2
--     return not self.effect.play
-- end

-- function Cast:draw()
--     love.graphics.setColor(1, 1, 1, 1)
--     self.effect:draw(self.x, self.y, 0, 2, 2, self.ox, self.oy)
-- end

-- local FrostNova = Class{}

-- function FrostNova:init()
--     self.name = 'Frost Nova'
--     self.type = 'AOE'
--     self.range = 2
--     self.radius = 1
--     self.element = 'ice'
--     self.cost = 4
--     self.filter = function() return true end
--     self.cast = Cast
-- end

-- return FrostNova

local VisualEffect = require 'src.spellcast.visualEffect'
local SimpleSwoosh = require 'src.spellcast.effects.simpleSwoosh'

return {
    name = 'Frost Nova',
    type = 'AOE',
    range = 2,
    radius = 1,
    filter = TargetFactory.any,
    element = 'water',
    cost = 4,
    damage = 10,
    onCast = function (spellcast, caster, target)
        local x = caster.x + (target.x - caster.x)/2
        local y = caster.y + (target.y - caster.y)/2
        local dx, dy = target.x - caster.x, target.y - caster.y
        local effect = VisualEffect(SimpleSwoosh(), { x = x, y = y, r = math.atan2(dy, dx), sx = 1, sy = 2 } )
        effect:setOnComplete(function ()
            for _, tile in pairs(BattleState.map.tiles._props) do
                if tile.aoe_target and tile.actor and not tile.actor.is_player then
                    tile.actor:take_damage(caster, 10)
                    -- tile.actor:add_status_effect({
                    --     name = 'Frost Slow',
                    --     duration = 3,
                    --     target = tile.actor,
                    --     caster = caster,
                    --     on_tick = function() end,
                    --     on_expire = function(self)
                    --         self.target:add_bonus_stat('initiative', 3)
                    --     end
                    -- })
                    -- tile.actor:add_bonus_stat('initiative', -3)
                    
                    target:addModifier(Modifier.battleAdd('initiative', -3, {
                        id = 'speed_debuff',
                        duration = { type = 'turn', value = 3 },
                    }))
                end
            end
            spellcast:complete()
        end)
        spellcast:addEffect(effect)
    end
}