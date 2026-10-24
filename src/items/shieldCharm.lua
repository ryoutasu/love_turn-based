local animation = require 'src.animation'

local boost = 2
local duration = 3

local ShieldCharm = Class{
    name = 'Shield Charm',
    description = 'Boost armor by ' .. boost .. ' for ' .. duration .. ' turns.',

    usableOnMap = false,
    usableInFight = true,

    type = 'unit',
    range = 100,
    filter = function(target)
        if target.actor and target.actor.is_player then
            return true
        end
        return false
    end,
    color = { 0.3, 0.6, 0.9, 1 },
}

function ShieldCharm:init(caster, target)
    if Gamestate.current() == Levelmap then
        return
    end

    target = target.actor

    self.caster = caster
    self.target = target

    self.x = target.x
    self.y = target.y

    local effect = animation('resources/simplefx-alpha.png', true)
    local x = 32
    local y = 32
    for i = 1, 3 do
        effect:add_frame(x, y, 16, 16)
        x = x + 16
    end
    x = 32
    y = y + 16
    for i = 1, 3 do
        effect:add_frame(x, y, 16, 16)
        x = x + 16
    end
    x = 32
    y = y + 16
    for i = 1, 3 do
        effect:add_frame(x, y, 16, 16)
        x = x + 16
    end
    effect.frameTime = 0.1
    effect.play = true
    self.effect = effect
end

function ShieldCharm:update(dt)
    self.effect:update(dt)
    local _, _, w, h = self.effect:get_frame():getViewport()
    self.ox = w / 2
    self.oy = h / 2
    if self.effect.play then
        return false
    end

    self.target:add_bonus_stat('armor', boost)
    self.target:add_status_effect({
        name = 'Shield Charm',
        duration = duration,
        target = self.target,
        caster = self.caster,
        on_tick = function() end,
        on_expire = function(self) self.target:add_bonus_stat('armor', -boost) end
    })
    
    Tagtext:add('Bonus armor!', self.target.x + 5, self.target.y - 40, 1, 30, self.color, 1)
    
    return true
end

function ShieldCharm:draw()
    love.graphics.setColor(1, 1, 1, 1)
    self.effect:draw(self.x, self.y, 0, 3, 3, self.ox, self.oy)
end

return ShieldCharm