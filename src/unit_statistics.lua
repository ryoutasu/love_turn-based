local Statistics = Class{}

function Statistics:init(health, damage, attack_range, movement_range, initiative)
    self.maxHealth = health
    self.health = health

    self.damage = damage
    self.attack_range = attack_range
    self.attack_type = damage and (attack_range == 1 and 'melee' or attack_range > 1 and 'ranged') or 'none'
    self.initiative = initiative or 1

    self.movement_range = movement_range or 5
end

return Statistics