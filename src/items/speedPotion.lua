local animation = require 'src.animation'

local boost = 2
local duration = 3

local SpeedPotion = Class{
    name = 'Speed Potion',
    description = 'Boost initiative by ' .. boost .. ' for ' .. duration .. ' turns.',

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
    color = { 0.2, 0.8, 0.8, 1 },
}

function SpeedPotion:init(caster, target)
    if Gamestate.current() == Levelmap then return end

    self.caster = caster
    self.target = target.actor
    self.x = self.target.x
    self.y = self.target.y

    local effect = animation('resources/simplefx-alpha.png', true)
    local x, y = 0, 96  -- Seventh row for speed effect
    for i = 1, 5 do
        effect:add_frame(x, y, 16, 16)
        x = x + 16
    end
    effect.frameTime = 0.15
    effect.play = true
    self.effect = effect
end

function SpeedPotion:update(dt)
    self.effect:update(dt)
    local _, _, w, h = self.effect:get_frame():getViewport()
    self.ox = w / 2
    self.oy = h / 2
    if self.effect.play then return false end

    self.target:add_bonus_stat('initiative', boost)
    self.target:add_status_effect({
        name = 'Speed Potion',
        duration = duration,
        target = self.target,
        caster = self.caster,
        on_tick = function() end,
        on_expire = function(self) self.target:add_bonus_stat('initiative', -boost) end
    })
    
    Tagtext:add('Speed up!', self.target.x + 5, self.target.y - 40, 1, 30, self.color, 1)
    
    return true
end

function SpeedPotion:draw()
    love.graphics.setColor(1, 1, 1, 1)
    self.effect:draw(self.x, self.y, 0, 3, 3, self.ox, self.oy)
end

return SpeedPotion