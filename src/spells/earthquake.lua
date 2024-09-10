local animation = require 'src.animation'

local Earthquake = Class{
    name = 'Earthquake',
    type = 'AOE',
    range = 3,
    radius = 1,
    filter = function(target)
        -- if target.actor and not target.actor.is_player then
        --     return true
        -- end
        -- return false
        return true
    end,
}

function Earthquake:init(caster, target)
    target = target.actor

    self.caster = caster
    -- self.target = target

    -- self.x = caster.x + (target.x - caster.x)/2
    -- self.y = caster.y + (target.y - caster.y)/2
    local targets = {}
    for _, node in pairs(BattleState.map.tiles._props) do
        if node.aoe_target and node.actor then
            targets[#targets+1] = node
            node.actor:take_damage(self.caster, 100)
        end
    end
end

function Earthquake:update(dt)

    return true
end

function Earthquake:draw()

end

return Earthquake