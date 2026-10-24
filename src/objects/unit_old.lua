local shader = require 'shader'
local Sprite = require 'src.sprite'
local spellList = require 'src.spells'
local moonshine = require 'lib.moonshine'
local Stats = require 'src.stats'

local damageCalculator = require 'src.damage_calculator'

local fontSize = 12
local healthFont = love.graphics.newFont(fontSize)

local text_effect = moonshine(moonshine.effects.boxblur)
text_effect.boxblur.radius = 1

UNIT_ALIVE_OFFSET = -HEX_RADIUS * 0.45
UNIT_DEAD_OFFSET = HEX_RADIUS * 0.3

local Unit = Class{}
-- Unit.include(statistics)

function Unit:init(tile, is_player)
    local x = tile.x
    local y = tile.y + UNIT_ALIVE_OFFSET

    self.x = x
    self.y = y
    self.z = 0
    self:set_tile(tile)

    self.is_player = is_player or false

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

    self.health_text = love.graphics.newText(healthFont)
    self.energy_text = love.graphics.newText(healthFont)

    self.status_effects = {}
    self.modifiers = {}

    self.bonus_stats = {}
    self.miss_chance = 0
end

function Unit:setup(character, runModifiers)
    local rect = character.rect
    self.sprite = Sprite(character.sprite_path, character.color)
    self.w, self.h = rect[1], rect[2]
    self.sw, self.sh = rect[3], rect[4]
    self.quad = love.graphics.newQuad(0, 0, self.w, self.h, self.sw, self.sh)

    self.name = character.name
    self.character = character
    self.attribute = character.attribute
    self.element = character.element

    self.stats = Stats(character, runModifiers, self.modifiers)

    self.max_health = self.stats:get('max_health')
    self.max_energy = self.stats:get('max_energy')
    self.damage     = self.stats:get('damage')
    self.armor      = self.stats:get('armor')
    self.initiative = self.stats:get('initiative')
    self.attack_range = self.stats:get('attack_range')
    self.move_range   = self.stats:get('move_range')

    -- self.max_health = computed_stats.max_health
    -- self.max_energy = computed_stats.max_energy
    -- self.damage = computed_stats.damage
    -- self.attack_range = computed_stats.attack_range
    -- self.attack_type = computed_stats.damage and (computed_stats.attack_range == 1 and 'melee' or computed_stats.attack_range > 1 and 'ranged') or 'none'
    -- self.move_range = computed_stats.move_range or 4
    -- self.initiative = computed_stats.initiative or 1
    -- self.armor = computed_stats.armor or 0
    
    self.health = math.min(character.health or self.max_health, self.max_health)
    self.energy = math.min(character.energy or self.max_energy, self.max_energy)

    for _, spell in ipairs(character.spells) do
        if type(spell) == "string" and spellList[spell] then
            spell = Class(spellList[spell])
        end

        if type(spell) == "table" then
            self:add_spell(spell)
        end
    end

    return self
end

function Unit:bottom()
    return self.x, self.y + self.h / 2 - 8
end

function Unit:get_stat(name)
    return self.stats:get(name)
end

function Unit:get_stats()
    self.stats:all()
end

function Unit:addModifier(mod)
    table.insert(self.modifiers, mod)
    self:refreshStats()
end

function Unit:removeModifier(mod)
    for i = #self.modifiers, 1, -1 do
        if self.modifiers[i] == mod then
            table.remove(self.modifiers, i)
        end
    end
    self:refreshStats()
end

function Unit:refreshStats()
    self.stats:invalidate()
    self.max_health = self.stats:get('max_health')
    self.max_energy = self.stats:get('max_energy')
    self.damage     = self.stats:get('damage')
    self.armor      = self.stats:get('armor')
    self.initiative = self.stats:get('initiative')

    self.health = math.min(self.health, self.max_health)
    self.energy = math.min(self.energy, self.max_energy)

    if BattleState and BattleState.queue then
        BattleState.queue:sort_next()
    end
end

function Unit:add_status_effect(status_effect)
    table.insert(self.status_effects, status_effect)
end

function Unit:remove_status_effect(status_effect)
    for index, effect in ipairs(self.status_effects) do
        if effect == status_effect then
            effect:on_expire()
            table.remove(self.status_effects, index)
        end
    end
end

function Unit:set_acting()
    self.acting = true
    self.tile.acting = true
    self.tile:change_color()
end

function Unit:set_tile(tile)
    if self.tile and self.tile.actor == self then
        self.tile.is_blocked = false
        self.tile.actor = nil
    end
    self.tile = tile
    tile.is_blocked = true
    tile.actor = self
end

function Unit:add_spell(spell)
    spell.current_cooldown = 0
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

function Unit:take_damage(source, damage, is_attack)
    if self.is_dead then return end
    -- local armor = self:get_stat('armor')
    -- local final_damage = math.max(math.ceil(damage - armor), 0)
    local final_damage = damageCalculator.calculate(source, self, damage)

    BattleState:add_action('damage', self)

    Tagtext:add('-'..final_damage, self.x + 5, self.y - 40, 2, 30, { 1, 0, 0 })
    self:add_stat('health', -final_damage)

    if self.health <= 0 then
        self.health = 0
        self.is_dead = true

        -- play death animation
        -- self.sprite_sx = 1.35
        -- self.sprite_sy = -0.55

        self.tile.dead_unit = self
        self.tile.actor = nil
        self.tile.is_blocked = false
        
        -- if self.character then
        --     self.character.is_dead = true
        -- end

        BattleState:unit_death(self)
    end

    if is_attack then
        BattleState:addLog(source.name .. ' atatck ' .. self.name .. ' for ' .. final_damage .. ' damage')
    else
        BattleState:addLog(self.name .. ' takes ' .. final_damage .. ' damage from ' .. source.name)
    end

    BattleState.shaking = 4

    return final_damage
end

function Unit:convertToParty()
    return {
        name = self.name,
        sprite_path = self.sprite.path,
        sprite = self.sprite,
        rect = { self.w, self.h, self.sw, self.sh },
        -- scale = scale,
    
        -- health = self.health,
        health = self.max_health,
        max_health = self.max_health,
        -- energy = self.energy,
        energy = self.max_energy,
        max_energy = self.max_energy,
        damage = self.damage,
        attack_range = self.attack_range,
        move_range = self.move_range,
        initiative = self.initiative,
        spells = self.spells,
        armor = self.armor,
        -- prepare_x = self.prepare_x,
        -- prepare_y = self.prepare_y,
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
    if self.is_dead --[[ or self.is_moving ]] then return end

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
    local z = self.z
    -- if not self.is_dead then y = y - HEX_RADIUS * 0.45 end
    -- if self.is_dead then y = y + HEX_RADIUS * 0.3 end

    self.shader:outline(r, g, b)
    self.shader:draw(size, self.sprite.image, self.quad, x, y - z, 0, self.sprite_sx or 1, self.sprite_sy or 1, self.w*0.5, self.h*0.5)
end

function Unit:draw()
    if self.is_dead and self.tile.actor then return end

    local x = self.x
    local y = self.y
    local z = self.z
    -- if not self.is_dead then y = y - HEX_RADIUS * 0.45 end
    -- if self.is_dead then y = y + HEX_RADIUS * 0.3 end

    if self.show_name then
        self:draw_outline(1, 1, 1, 2)
    end

    if self.acting then
        -- self.shader:draw(1, self.sprite.image, self.quad, x, y, 0, self.sprite_sx or 1, self.sprite_sy or 1, self.w*0.5, self.h*0.5)
        self:draw_outline(0, 1, 0, 1)
    end

    love.graphics.setColor(1, 1, 1, 1)
    self.sprite:draw(self.quad, x, y - z, 0, self.sprite_sx or 1, self.sprite_sy or 1, self.w*0.5, self.h*0.5)

    self:draw_health(x, y + 40)
end

function Unit:remove()
    self.tile.actor = nil
    self.tile.is_blocked = false
end

return Unit