local VisualEffect = require 'src.spellcast.visualEffect'
local SimpleSwoosh = require 'src.spellcast.effects.simpleSwoosh'

return {
    name = 'Earthquake',
    type = 'AOE',
    range = 3,
    radius = 1,
    filter = TargetFactory.any,
    element = 'earth',
    cost = 6,
    damage = 10,
    onCast = function (spellcast, caster, target)
        local tiles = BattleState.pathfinder:getTilesInRange(target, spellcast.spell.radius)
        for index, tile in ipairs(tiles) do
            if tile.actor then
                spellcast:dealDamage(tile.actor)
            end
        end
        spellcast:complete()
    end
}