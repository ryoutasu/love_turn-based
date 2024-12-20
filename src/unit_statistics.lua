local Statistics = Class{}

function Statistics:init(max_health, damage, attack_range, movement_range, initiative)
    self.max_health = max_health
    self.health = max_health

    self.damage = damage
    self.attack_range = attack_range
    self.attack_type = damage and (attack_range == 1 and 'melee' or attack_range > 1 and 'ranged') or 'none'
    self.initiative = initiative or 1

    self.movement_range = movement_range or 5
end

function Statistics:add_stat(name, value)
    if self[name] then
        self:set(name, self[name] + value)
    end
end

function Statistics:set(name, value)
    if name == 'health' then
        value = math.min(value, self.max_health)
    end

    self[name] = value
    
    if self.character_reference then
        self.character_reference[name] = value
    end
end

return Statistics