local animation = require 'src.animation'

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
    element = 'life',
    cost = 2,
}

function Healing:init(caster, target)
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

function Healing:update(dt)
    self.effect:update(dt)
    local _, _, w, h = self.effect:get_frame():getViewport()
    self.ox = w / 2
    self.oy = h / 2
    if self.effect.play then
        return false
    end

    Tagtext:add('+15', self.target.x + 5, self.target.y - 40, 2, 30, { 1, 1, 1 })
    self.target.health = self.target.health + 15
    
    return true
end

function Healing:draw()
    love.graphics.setColor(1, 1, 1, 1)
    self.effect:draw(self.x, self.y, 0, 1, 1, self.ox, self.oy)
end

return Healing