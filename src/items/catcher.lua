local fillTime = 2

local Catcher = Class{
    name = 'Catcher',
    description = 'Catches target wild \'mon and add to yuor party.',

    usableOnMap = false,
    usableInFight = true,

    type = 'unit',
    range = 100,
    filter = function(target)
        if target.actor and not target.actor.is_player then
            return true
        end
        return false
    end,
    color = { 0.8, 0.1, 0.1, 1 },
}

function Catcher:init(caster, target)
    target = target.actor

    self.caster = caster
    self.target = target

    self.w = 45
    self.h = 15

    self.x = self.target.x - self.w / 2
    self.y = self.target.y - 65
    self.time = 0
    self.progress = 0
end

function Catcher:update(dt)
    self.time = self.time + dt
    self.progress = self.time / fillTime

    if self.progress > 0.2 then
        if self.target.health > self.target.maxHealth * 0.3 then
            local rnd = math.random()
            if rnd < self.progress then
                Tagtext:add('\'mon freed!', self.x, self.y, 2, 30, { 1, 1, 1 })

                return true
            end
        end
    end

    if self.progress < 1 then
        return false
    end

    BattleState.player:addCharacter(self.target:convertToParty())
    BattleState:remove_unit(self.target)

    Tagtext:add('\'mon catched!', self.x, self.y, 2, 30, { 1, 1, 1 })

    return true
end

function Catcher:draw()
    local x, y = self.x, self.y
    local w, h = self.w, self.h

    love.graphics.setColor(0.75, 0.75, 0.75, 0.75)
    love.graphics.rectangle('fill', x, y, w, h)

    local fill = w * self.progress
    love.graphics.setColor(0.25, 0.75, 0.25, 0.75)
    love.graphics.rectangle('fill', x, y, fill, h)

    love.graphics.setColor(0.15, 0.15, 0.15, 1)
    love.graphics.rectangle('line', x, y, w, h)
end

return Catcher