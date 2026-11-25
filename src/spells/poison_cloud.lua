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