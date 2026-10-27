-- local animation = require 'src.animation'

-- local Cast = Class{}

-- function Cast:init(caster, target, spell)
--     self:include(spell)
--     -- target = target.actor

--     self.caster = caster
--     -- self.target = target

--     -- self.x = caster.x + (target.x - caster.x)/2
--     -- self.y = caster.y + (target.y - caster.y)/2

--     -- local targets = {}
--     -- for _, tile in pairs(BattleState.map.tiles._props) do
--     --     if tile.aoe_target and tile.actor then
--     --         targets[#targets+1] = tile
--     --         tile.actor:take_damage(self.caster, 10)
--     --     end
--     -- end

--     local tiles = BattleState.pathfinder:getTilesInRange(target, self.radius)
--     for index, tile in ipairs(tiles) do
--         if tile.actor then
--             tile.actor:take_damage(self.caster, 10)
--         end
--     end
-- end

-- function Cast:update(dt)

--     return true
-- end

-- function Cast:draw()

-- end

-- local Earthquake = Class{}

-- function Earthquake:init()
--     self.name = 'Earthquake'
--     self.type = 'AOE'
--     self.range = 3
--     self.radius = 1
--     self.filter = function(target)
--         -- if target.actor and not target.actor.is_player then
--         --     return true
--         -- end
--         -- return false
--         return true
--     end
--     self.element = 'stone'
--     self.cost = 6
--     self.cast = Cast
-- end

-- return Earthquake

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