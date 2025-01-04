local shader = require 'shader'
local Sprite = require 'src.sprite'
local spellList = require 'src.spells'
local moonshine = require 'lib.moonshine'

-- local statistics = require 'src.unit_statistics'

local fontSize = 12
local healthFont = love.graphics.newFont(fontSize)

local text_effect = moonshine(moonshine.effects.boxblur)
text_effect.boxblur.radius = 1

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
    -- self.text_effect = moonshine(moonshine.effects.boxblur)
    -- self.text_effect.boxblur.radius = 1
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
    self.outline = nil
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
    self.max_energy = character.max_energy
    self.energy = character.energy or character.max_energy

    self.movement_range = character.movement_range or 4

    self.health_text = love.graphics.newText(healthFont)
    self.energy_text = love.graphics.newText(healthFont)

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
    if name == 'energy' then
        value = math.min(value, self.max_energy)
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
        energy = self.energy,
        max_energy = self.max_energy,
        spells = self.spells,
    }
end

function Unit:update(dt)
    
end

-- mathemagic
local p1 = Vector(0, HEX_RADIUS * HEX_HEIGHT) -- bottom point of hex
local p2 = Vector(HEX_RADIUS * math.sqrt(3) / 2, HEX_RADIUS / 2 * HEX_HEIGHT) -- bottom right point of hex
local p3 = Vector(-p2.x, p2.y)

local kx = 0
local offset = 5

local rotation = p1:angleTo(p2) -- - math.pi/2
local rotation2 = p3:angleTo(p1)

local distance = p1:dist(p2)

local health_w = distance
local health_h = 16

local health_x = p1.x
local health_y = p1.y - health_h

local energy_x = p3.x
local energy_y = p3.y - health_h

function Unit:draw_name()
    if not self.show_name then return end

    local x, y = self.x, self.y

    local w = health_w
    local h = health_h
    local rx = x -- - w / 2
    local ry = y + health_y - health_h - 1

    -- love.graphics.setColor(0.75, 0.75, 0.75, 0.75)
    -- love.graphics.rectangle('fill', rx, ry, w, h)

    local tx = rx + 2
    local ty = ry + ((h - fontSize) / 2) - 1

    love.graphics.setFont(healthFont)
    love.graphics.setColor(0, 0, 0, 1)
    PrintText(self.name, tx, ty, rotation)
end

local d = 1
local sides = {
    { -d, 0 },
    { d, 0 },
    { 0, -d },
    { 0, d },

    { d, d },
    { -d, -d },
    { -d, d },
    { d, -d }
}
function Unit:draw_health(x, y)
    if self.is_dead or self.is_moving then return end

    love.graphics.setFont(healthFont)

    -- local w = health_w
    -- local h = health_h
    -- local rx1 = x + health_x
    -- local ry1 = y + health_y
    -- local rx2 = x + energy_x
    -- local ry2 = y + energy_y

    -- text_effect(function ()
    --     love.graphics.setColor(1, 0.35, 0.35, 1)
    --     love.graphics.polygon('fill',
    --         p1.x + x, p1.y + y,
    --         p1.x + x, p1.y + y - h,
    --         p2.x + x, p2.y + y - h,
    --         p2.x + x, p2.y + y
    --     )
    
    --     love.graphics.setColor(0.25, 0.35, 1, 1)
    --     love.graphics.polygon('fill',
    --         p1.x + x, p1.y + y,
    --         p1.x + x, p1.y + y - h,
    --         p3.x + x, p3.y + y - h,
    --         p3.x + x, p3.y + y
    --     )
    -- end)

    -- local healthString = self.health .. '/' .. self.max_health
    -- local energy_string = self.energy .. '/' .. self.max_energy
    
    -- self.health_text:setf(healthString, w, 'center')
    -- self.energy_text:setf(energy_string, w, 'center')

    -- love.graphics.setColor(1, 1, 1, 1)
    -- for index, value in ipairs(sides) do
    --     love.graphics.draw(self.health_text, math.floor(rx1) + value[1], math.floor(ry1) + value[2], rotation, 1, 1, 0, 0, -kx, 0)
    --     love.graphics.draw(self.energy_text, math.floor(rx2) + value[1], math.floor(ry2) + value[2], rotation2, 1, 1, 0, 0, kx, 0)
    -- end

    -- love.graphics.setColor(0, 0, 0, 1)
    -- love.graphics.draw(self.health_text, math.floor(rx1), math.floor(ry1), rotation, 1, 1, 0, 0, -kx, 0)
    -- love.graphics.draw(self.energy_text, math.floor(rx2), math.floor(ry2), rotation2, 1, 1, 0, 0, kx, 0)

    local healthString = self.health .. '/' .. self.max_health
    local w = healthFont:getWidth(healthString)
    local h = healthFont:getHeight() - 1
    local rx, ry = math.floor(x - w/2), math.floor(y) + 10

    -- local padding = 1
    -- love.graphics.setColor(0.15, 0.45, 0.25, 0.5)
    -- love.graphics.rectangle('fill', rx - padding, ry - padding, w + padding + padding, h + padding + padding)
    -- love.graphics.setColor(0, 0, 0, 0.5)
    -- love.graphics.rectangle('line', rx - padding, ry - padding, w + padding + padding, h + padding + padding)

    self.health_text:setf(healthString, w, 'center')
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.draw(self.health_text, rx + 1, ry + 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.health_text, rx, ry)
end

function Unit:draw_outline(r, g, b, size)
    local x = self.x
    local y = self.y
    if not self.is_dead then y = y - HEX_RADIUS * 0.45 end
    if self.is_dead then y = y + HEX_RADIUS * 0.3 end

    self.shader:outline(r, g, b)
    self.shader:draw(size, self.sprite.image, self.quad, x, y, 0, self.sprite_sx or 1, self.sprite_sy or 1, self.w*0.5, self.h*0.5)
end

function Unit:draw()
    if self.is_dead and self.node.actor then return end

    local x = self.x
    local y = self.y
    if not self.is_dead then y = y - HEX_RADIUS * 0.45 end
    if self.is_dead then y = y + HEX_RADIUS * 0.3 end

    if self.show_name then
        self:draw_outline(1, 1, 1, 2)
    end

    if self.acting then
        -- self.shader:draw(1, self.sprite.image, self.quad, x, y, 0, self.sprite_sx or 1, self.sprite_sy or 1, self.w*0.5, self.h*0.5)
        self:draw_outline(0, 1, 0, 1)
    end

    love.graphics.setColor(1, 1, 1, 1)
    self.sprite:draw(self.quad, x, y, 0, self.sprite_sx or 1, self.sprite_sy or 1, self.w*0.5, self.h*0.5)
end

function Unit:remove()
    self.node.actor = nil
    self.node.is_blocked = false
end

return Unit