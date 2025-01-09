local animation = require 'src.animation'

local Cast = Class{}

function Cast:init(caster, target, spell)
    self:include(spell)
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

function Cast:update(dt)

    return true
end

function Cast:draw()

end

local Earthquake = Class{}

function Earthquake:init()
    self.name = 'Earthquake'
    self.type = 'AOE'
    self.range = 3
    self.radius = 1
    self.filter = function(target)
        -- if target.actor and not target.actor.is_player then
        --     return true
        -- end
        -- return false
        return true
    end
    self.element = 'stone'
    self.cost = 6
    self.cast = Cast
end

return Earthquake