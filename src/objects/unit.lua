-- local sprite = require 'src.sprite'
local shader = require 'shader'
local skip_turn = require 'src.actions.skip_turn'

local statistics = require 'src.unit_statistics'

local Unit = Class{}
Unit.include(statistics)

function Unit:init(node, sprite, w, h, sw, sh, is_player)
    local x = node.x
    local y = node.y

    self.x = x
    self.y = y
    self:set_node(node)
    self.sprite = sprite
    self.w = w or 64
    self.h = h or 64
    self.sw = sw or 64
    self.sh = sh or 64
    self.quad = love.graphics.newQuad(0, 0, self.w, self.h, self.sw, self.sh)

    self.is_player = is_player

    self.spells = {}
    -- self.actions = {
    --     skip_turn,
    -- }
    self.current_action = nil
    self.action_completed = false
    self.action_new = false

    self.acting = false
    self.shader = shader(true)
    if is_player then
        self.shader:outline(0, 1, 0)
    else
        self.shader:outline(1, 0, 0)
    end
end

function Unit:set_statistics(...)
    statistics.init(self, ...)
end

function Unit:set_acting()
    self.acting = true
    self.node.acting = true
    self.node:change_color()
end

function Unit:set_node(node)
    if self.node then
        self.node.is_blocked = false
        self.node.actor = nil
    end
    self.node = node
    node.is_blocked = true
    node.actor = self
end

function Unit:set_current_action(action, ...)
    -- if not self.current_action then
        self.action_new = true
        self.current_action = action(self, ...)
    -- end
end

function Unit:add_spell(spell)
    self.spells[#self.spells+1] = spell
end

function Unit:get_spells()
    return self.spells
end

function Unit:update(dt)
    self.action_new = false
    self.action_completed = false
    if self.current_action then
        local complete = self.current_action:update(dt)
        if complete then
            self.current_action = nil
            self.action_completed = true
        end
    end
end

function Unit:draw_health(x, y)
    local w = 45
    local h = 15
    local rx = x - w / 2
    local ry = y - 34
    
    local fontSize = 9
    local tx = rx + 3
    local ty = ry + ((h - fontSize) / 2) - 1

    if self.is_player then
        love.graphics.setColor(0.33, 1, 0.33, 1)
    else
        love.graphics.setColor(1, 0.33, 0.33, 1)
    end
    love.graphics.rectangle('fill', rx, ry, w, h)

    if self.is_player then
        love.graphics.setColor(0.25, .66, 0.25, 1)
    else
        love.graphics.setColor(.66, 0.25, 0.25, 1)
    end
    love.graphics.rectangle('line', rx, ry, w, h)

    love.graphics.setColor(0.2, 0.2, 0.2, 1)

    local healthString = self.health .. '/' .. self.maxHealth
    love.graphics.setNewFont(fontSize)
    love.graphics.print(healthString, tx, ty)
end

function Unit:draw()
    local x = self.x
    local y = self.y

    if self.acting then
        self.shader:draw(2, self.sprite.image, self.quad, x, y, 0, 1, 1, self.w*0.5, self.h*0.5)
    end

    love.graphics.setColor(1, 1, 1, 1)
    self.sprite:draw(self.quad, x, y, 0, 1, 1, self.w*0.5, self.h*0.5)
    
    if self.current_action then
        self.current_action:draw()
    end

    self:draw_health(x, y)
end

return Unit