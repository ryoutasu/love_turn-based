local shader = require 'shader'
local Sprite = require 'src.sprite'
local spellList = require 'src.spells'

-- local statistics = require 'src.unit_statistics'

local fontSize = 12
local healthFont = love.graphics.newFont(fontSize)

local Unit = Class{}
-- Unit.include(statistics)

function Unit:init(node, is_player)
    local x = node.x
    local y = node.y

    self.x = x
    self.y = y
    self:set_node(node)

    self.is_player = is_player

    self.spells = {}
    self.current_action = nil
    self.action_completed = false
    self.action_new = false

    self.acting = false
    self.shader = shader(true)
    -- if is_player then
    --     self.shader:outline(0, 1, 0)
    -- else
    --     self.shader:outline(1, 0, 0)
    -- end
    -- self.whiteOutline = shader(true)

    self.died = false
    self.is_dead = false
    self.show_name = false
    self.is_moving = false
end

function Unit:setup(character, do_change_character)
    local rect = character.rect
    self.sprite = Sprite(character.sprite_path)
    self.w = rect[1] or 64
    self.h = rect[2] or 64
    self.sw = rect[3] or 64
    self.sh = rect[4] or 64
    self.quad = love.graphics.newQuad(0, 0, self.w, self.h, self.sw, self.sh)

    self.name = character.name
    
    self.sprite_sx = character.sprite_sx or 1
    self.sprite_sy = character.sprite_sy or 1

    for _, spellname in ipairs(character.spells) do
        self:add_spell(spellList[spellname])
    end

    if do_change_character then
        self.character = character
    end

    -- statistics
    self.max_health = character.max_health
    self.health = character.health or character.max_health

    self.damage = character.damage
    self.attack_range = character.attack_range
    self.attack_type = character.damage and (character.attack_range == 1 and 'melee' or character.attack_range > 1 and 'ranged') or 'none'
    self.initiative = character.initiative or 1
    self.armor = character.armor or 0

    self.movement_range = character.movement_range or 4

    return self
end

function Unit:add_stat(name, value)
    if self[name] then
        self:set_stat(name, self[name] + value)
    end
end

function Unit:set_stat(name, value)
    if name == 'health' then
        value = math.min(value, self.max_health)
    end

    self[name] = value
    
    if self.character then
        self.character[name] = value
    end
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
    local final_damage = damage - self.armor

    Tagtext:add('-'..final_damage, self.x + 5, self.y - 40, 2, 30, { 1, 0, 0 })
    self:add_stat('health', -final_damage)

    if self.health <= 0 then
        self.health = 0
        self.is_dead = true

        -- play death animation
        self.sprite_sx = 1.35
        self.sprite_sy = -0.55

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
    
        health = self.health,
        max_health = self.max_health,
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

-- mathemagic
local p1 = Vector(0, HEX_RADIUS * HEX_HEIGHT)
local p2 = Vector(HEX_RADIUS * math.sqrt(3) / 2, HEX_RADIUS / 2 * HEX_HEIGHT)
local p3 = (p1 + p2)/2

local rotation = p1:angleTo(p2) - math.pi/2
local rotation2 = p1:angleTo(p2)

local distance = p1:dist(p2)

local healthW = distance
local healthH = 24
local healthX = p3.x - math.cos(rotation2) * healthH - math.cos(rotation) * healthW / 2
local healthY = p3.y - math.sin(rotation2) * healthH - math.sin(rotation) * healthW / 2 -- - healthH - 5

local p4 = Vector(p1.x - math.cos(rotation) * healthH, p1.y - math.sin(rotation) * healthH)
local p5 = Vector(p1.x - math.cos(rotation) * healthH, p1.y - math.sin(rotation) * healthH)
local rect_points = {
    p1, p2,
    Vector(p2.x - math.cos(rotation2) * healthH, p2.y - math.sin(rotation2) * healthH),
    Vector(p1.x - math.cos(rotation2) * healthH, p1.y - math.sin(rotation2) * healthH),
    p1,
}

function Unit:draw_name()
    if not self.show_name then return end

    local x, y = self.x, self.y

    local w = healthW
    local h = healthH
    local rx = x -- - w / 2
    local ry = y + healthY - healthH - 1

    -- love.graphics.setColor(0.75, 0.75, 0.75, 0.75)
    -- love.graphics.rectangle('fill', rx, ry, w, h)

    local tx = rx + 2
    local ty = ry + ((h - fontSize) / 2) - 1

    love.graphics.setFont(healthFont)
    love.graphics.setColor(0, 0, 0, 1)
    PrintText(self.name, tx, ty, rotation)
end

function Unit:draw_health(x, y)
    if self.is_dead or self.is_moving then return end

    local w = healthW
    local h = healthH
    local rx = x + healthX -- - w / 2
    local ry = y + healthY

    -- if self.is_player then
    --     love.graphics.setColor(0.33, 1, 0.33, 1)
    -- else
    --     love.graphics.setColor(1, 0.33, 0.33, 1)
    -- end
    -- love.graphics.rectangle('fill', rx, ry, w, h)

    -- if self.is_player then
    --     love.graphics.setColor(0.25, .66, 0.25, 1)
    -- else
    --     love.graphics.setColor(.66, 0.25, 0.25, 1)
    -- end
    -- -- line width is in BattleState
    -- love.graphics.rectangle('line', rx, ry, w, h)
    -- love.graphics.setColor(0.33, 1, 0.33, 1)
    -- love.graphics.polygon('fill',
    --     rect_points[1].x + x, rect_points[1].y + y,
    --     rect_points[2].x + x, rect_points[2].y + y,
    --     rect_points[3].x + x, rect_points[3].y + y,
    --     rect_points[4].x + x, rect_points[4].y + y
    -- )
    

    local healthString = self.health .. '/' .. self.max_health
    local textW = healthFont:getWidth(healthString)
    
    local tx = rx + 2
    local ty = ry + ((h - fontSize) / 2) - 1

    tx = tx + math.cos(rotation) * (distance - textW)/2
    ty = ty + math.sin(rotation) * (distance - textW)/2

    -- love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setFont(healthFont)
    PrintText(healthString, tx, ty, rotation)
end

function Unit:draw_outline(r, g, b)
    local x = self.x
    local y = self.y
    if not self.is_dead then y = y - HEX_RADIUS * 0.45 end
    if self.is_dead then y = y + HEX_RADIUS * 0.3 end

    self.shader:outline(r, g, b)
    self.shader:draw(1, self.sprite.image, self.quad, x, y, 0, self.sprite_sx or 1, self.sprite_sy or 1, self.w*0.5, self.h*0.5)
end

function Unit:draw()
    if self.is_dead and self.node.actor then return end

    local x = self.x
    local y = self.y
    if not self.is_dead then y = y - HEX_RADIUS * 0.45 end
    if self.is_dead then y = y + HEX_RADIUS * 0.3 end

    if self.acting then
        -- self.shader:draw(1, self.sprite.image, self.quad, x, y, 0, self.sprite_sx or 1, self.sprite_sy or 1, self.w*0.5, self.h*0.5)
        self:draw_outline(0, 1, 0)
    end

    love.graphics.setColor(1, 1, 1, 1)
    self.sprite:draw(self.quad, x, y, 0, self.sprite_sx or 1, self.sprite_sy or 1, self.w*0.5, self.h*0.5)
end

function Unit:remove()
    self.node.actor = nil
    self.node.is_blocked = false
end

return Unit