local unit = require 'src.objects.unit'
local sprite = require 'src.sprite'

local fireball = require 'src.spells.fireball'
local healing = require 'src.spells.healing'

---Unit
---@param node table
---@param path string
---@param w number sprite width
---@param h number sprite height
---@param sw number sheet width
---@param sh number sheet height
---@param is_player boolean
---@param health number
---@param damage number
---@param attack_range number
---@param move_range number
---@param initiative number
---@return table
local function create_unit(node, path, w, h, sw, sh, is_player, health, damage, attack_range, move_range, initiative)
    local u = unit(node, sprite(path), w, h, sw, sh, is_player)
    u:set_statistics(health, damage, attack_range, move_range, initiative)
    return u
end

return {
    ['Alice'] = function (node, is_player, ...)
        local u = create_unit(node, 'resources/alice.png', 32, 48, 96, 192, is_player, 100, 10, 1, 5, 6)
        u.name = 'Alice'
        return u
    end,
    ['Cat'] = function (node, is_player, ...)
        local u = create_unit(node, 'resources/cat.png', 64, 64, 64, 64, is_player, 80, 5, 5, 3, 3)
        u.name = 'Cat'
        u:add_spell(fireball)
        u:add_spell(healing)
        u:add_spell(healing)
        return u
    end,
    ['Bat'] = function (node, is_player, ...)
        local u = create_unit(node, 'resources/bat.png', 81, 57, 81, 57, is_player, 100, 10, 1, 4, 4)
        u.name = 'Bat'
        return u
    end
}