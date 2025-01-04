local animation = require 'src.animation'

local restore = 10

local EnergyPotion = Class{
    name = 'Energy Potion',
    description = 'Restore ' .. restore .. ' energy to a \'mon.',

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

function EnergyPotion:init(caster, target)
    if Gamestate.current() == Levelmap then
        local _, _, w, h = target.quad:getViewport()
        Tagtext:add('+'..restore, target.x + w / 2, target.y + h / 2, 1, 30, { 0.25, 0.35, 1 }, 1)
        target.character.energy = math.min(target.character.max_energy, target.character.energy + restore)
        
        return
    end

    target = target.actor

    self.caster = caster
    self.target = target

    self.x = target.x
    self.y = target.y

    local effect = animation('resources/simplefx-alpha.png', true)
    local x = 0
    local y = 0
    for i = 1, 5 do
        effect:add_frame(x, y, 16, 16)
        x = x + 16
    end
    effect.frameTime = 0.15
    effect.play = true
    self.effect = effect
end

function EnergyPotion:update(dt)
    self.effect:update(dt)
    local _, _, w, h = self.effect:get_frame():getViewport()
    self.ox = w / 2
    self.oy = h / 2
    if self.effect.play then
        return false
    end

    Tagtext:add('+'..restore, self.target.x + 5, self.target.y - 40, 1, 30, { 0.25, 0.35, 1 }, 1)
    -- self.target.energy = self.target.energy + restore
    self.target:add_stat('energy', restore)
    
    return true
end

function EnergyPotion:draw()
    love.graphics.setColor(0, 0, 1, 1)
    self.effect:draw(self.x, self.y, 0, 3, 3, self.ox, self.oy)
end

return EnergyPotion