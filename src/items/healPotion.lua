local animation = require 'src.animation'

local healing_power = 20

local HealPotion = Class{
    name = 'HealPotion',
    description = 'Restore ' .. healing_power .. ' health to a \'mon.',

    usableOnMap = true,
    usableInFight = true,

    type = 'unit',
    range = 100,
    filter = function(target)
        if target.actor and target.actor.is_player then
            return true
        end
        return false
    end,
    color = { 0.1, 0.8, 0.1, 1 },
}

function HealPotion:init(caster, target)
    target = target.actor

    self.caster = caster
    self.target = target

    self.x = target.x
    self.y = target.y

    local effect = animation('resources/simplefx-alpha.png', true)
    local x = 0
    local y = 0
    for i = 1, 4 do
        effect:add_frame(x, y, 16, 16)
        x = x + 16
    end
    effect.frameTime = 0.25
    effect.play = true
    self.effect = effect
end

function HealPotion:update(dt)
    self.effect:update(dt)
    local _, _, w, h = self.effect:get_frame():getViewport()
    self.ox = w / 2
    self.oy = h / 2
    if self.effect.play then
        return false
    end

    Tagtext:add('+'..healing_power, self.target.x + 5, self.target.y - 40, 2, 30, { 1, 1, 1 })
    self.target.health = self.target.health + healing_power
    
    return true
end

function HealPotion:draw()
    love.graphics.setColor(1, 1, 1, 1)
    self.effect:draw(self.x, self.y, 0, 1, 1, self.ox, self.oy)
end

return HealPotion