-- local sprite = require 'src.sprite'
local shader = require 'shader'
local skip_turn = require 'src.actions.skip_turn'

local statistics = require 'src.unit_statistics'

local fontSize = 9
local healthFont = love.graphics.newFont(fontSize)

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

    self.died = false
    self.is_dead = false
    self.show_name = false
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

-- function Unit:set_current_action(action, ...)
--     -- if not self.current_action then
--         self.action_new = true
--         self.current_action = action(self, ...)
--     -- end
-- end

function Unit:add_spell(spell)
    self.spells[#self.spells+1] = spell
end

function Unit:get_spells()
    return self.spells
end

function Unit:ally_to(unit)
    if not unit then return nil end
    return self.is_player == unit.is_player
end

function Unit:enemy_to(unit)
    if not unit then return nil end
    return not self.is_player == unit.is_player
end

function Unit:take_damage(source, damage, type)
    if self.is_dead then return end

    Tagtext:add('-'..damage, self.x + 5, self.y - 40, 2, 30, { 1, 0, 0 })
    self.health = self.health - damage

    if self.character_reference then
        self.character_reference.current_health =  self.health
    end

    if self.health <= 0 then
        self.health = 0
        self.is_dead = true

        -- play death animation
        self.sprite_sx = 1.35
        self.sprite_sy = 0.4

        self.node.dead_unit = self
        self.node.actor = nil
        self.node.is_blocked = false
        
        if self.character_reference then
            self.character_reference.is_dead = true
        end

        BattleState:unit_death(self)
    end
end

function Unit:convertToParty()
    return {
        name = self.name,
        sprite_path = self.sprite.path,
        rect = { self.w, self.h, self.sw, self.sh },
        -- scale = scale,
    
        health = self.maxHealth,
        current_health = self.health,
        damage = self.damage,
        attack_range = self.attack_range,
        move_range = self.move_range,
        initiative = self.initative,
        spells = self.spells,
    }
end

function Unit:update(dt)
    -- self.action_new = false
    -- self.action_completed = false
    -- if self.current_action then
    --     local complete = self.current_action:update(dt)
    --     if complete then
    --         self.current_action = nil
    --         self.action_completed = true
    --     end
    -- end
end

function Unit:draw_name()
    if not self.show_name then return end

    local x, y = self.x, self.y

    local w = 45
    local h = 15
    local rx = x - w / 2
    local ry = y - 50
    
    local tx = rx + 3
    local ty = ry + ((h - fontSize) / 2) - 1

    love.graphics.setColor(0.75, 0.75, 0.75, 0.75)
    love.graphics.rectangle('fill', rx, ry, w, h)
    

    love.graphics.setFont(healthFont)
    love.graphics.setColor(0, 0, 0, 1)
    PrintText(self.name, tx, ty)
end

function Unit:draw_health(x, y)
    if self.is_dead then
        return
    end

    local w = 45
    local h = 15
    local rx = x - w / 2
    local ry = y - 34
    
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
    love.graphics.setFont(healthFont)
    PrintText(healthString, tx, ty)
end

function Unit:draw()
    if self.is_dead and self.node.actor then return end

    local x = self.x
    local y = self.y

    -- if self.acting then
    --     self.shader:draw(2, self.sprite.image, self.quad, x, y, 0, self.sprite_sx or 1, self.sprite_sy or 1, self.w*0.5, self.h*0.5)
    -- end

    love.graphics.setColor(1, 1, 1, 1)
    self.sprite:draw(self.quad, x, y, 0, self.sprite_sx or 1, self.sprite_sy or 1, self.w*0.5, self.h*0.5)
end

function Unit:remove()
    self.node.actor = nil
    self.node.is_blocked = false
end

return Unit