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
                    spellcast:dealDamage(tile.actor, 10)
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