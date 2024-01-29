local tween = require 'lib.tween'

local Queue = Class{}

function Queue:init(urutora, x, y)
    self.u = urutora

    self.x = x
    self.y = y

    self.index = 0 -- starting from 1
    self.current = nil
    self.awaiting = {}
    self.finished = {}
    self.all_units = {}
    self.text = {}
    self.round = 0

    self.tweens = {}
end

function Queue:add_actor(actor)
    table.insert(self.all_units, actor)
    table.insert(self.finished, actor)

    table.sort(self.all_units, function (a, b)
        return a.initiative > b.initiative
    end)
end

function Queue:new_round()
    for i = 1, #self.finished, 1 do
        local a = self.finished[i]
        table.insert(self.awaiting, a)
    end

    table.sort(self.awaiting, function (a, b)
        return a.initiative > b.initiative
    end)

    local x = self.x
    local y = self.y
    for i, unit in ipairs(self.awaiting) do
        if self.text[unit] then
            self.tweens[unit] = nil
            self.u:remove(self.text[unit])
        end
        local text = Urutora.label({
            text = unit.name,
            align = 'left',
            x = x, y = y,
            w = 50, h = 20
        })

        local style = {
            outline = true,
            bgColor = { love.math.colorFromBytes(87, 183, 225, 255) }
        }

        text:setStyle(style)

        self.u:add(text)
        self.text[unit] = text

        y = y + 25
    end

    self.finished = {}
    self.round = self.round + 1
    self.index = 0
end

function Queue:start_turn()
    if self.current then
        self.current.acting = false
        table.insert(self.finished, self.current)
    end

    if not next(self.awaiting) then
        self:new_round()
    end
    
    self.index = self.index + 1
    local unit = table.remove(self.awaiting, 1)
    self.text[unit].style.outline = false
    self.current = unit
    self.current:set_acting()
end

function Queue:end_turn()
    local unit = self.current
    local text = self.text[unit]

    local x, y = text.x, text.y
    local toY = y - 25

    self.tweens[unit] = {
        position = tween.new(2, text, { y = toY }),
        opacity = tween.new(2, text.style, { bgColor = { love.math.colorFromBytes(87, 183, 225, 0) } })
    }

    self.index = self.index + 1
end

function Queue:update(dt)
    for unit, tw in pairs(self.tweens) do
        local position = tw.position
        local opacity = tw.opacity

        local completePosition = position:update(dt)
        local completeOpasity = opacity:update(dt)
        if completePosition or completeOpasity then
            tw = {}
            self.u:remove(self.text[unit])
        end
    end
end

return Queue