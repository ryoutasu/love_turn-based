local Healing = Class{
    name = 'Healing',
    type = 'unit',
    range = 10,
    filter = function(target)
        if target.actor and target.actor.is_player then
            return true
        end
        return false
    end,
}

function Healing:init(caster, target)
    target = target.actor

    self.caster = caster
    self.target = target

    self.x = caster.x
    self.y = caster.y
end

function Healing:update(dt)
    Tagtext:add('+15', self.target.x + 5, self.target.y - 40, 2, 30, { 1, 1, 1 })
    
    self.target.health = self.target.health + 15
    return true
end

function Healing:draw()

end

return Healing