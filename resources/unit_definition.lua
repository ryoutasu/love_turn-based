local unit = require 'src.objects.unit'
local sprite = require 'src.sprite'
local animation = require 'src.animation'

local fireball = require 'src.spells.fireball'
local healing = require 'src.spells.healing'
local slash = require 'src.spells.slash'
local earthquake = require 'src.spells.earthquake'

return {
    ['Alice'] = function (node, is_player, ...)
        local u = unit(node, sprite('resources/alice.png'), 32, 48, 96, 192, is_player)
        u:set_statistics(
            100, -- health
            10,  -- damage
            1,   -- attack_range
            4,   -- move_range
            5    -- initiative
        )
        u:add_spell(slash)
        u.name = 'Alice'
        return u
    end,
    
    ['Wizard'] = function (node, is_player, ...)
        local u = unit(node, sprite('resources/wizard.png'), 32, 48, 96, 192, is_player)
        u:set_statistics(
            90, -- health
            8,  -- damage
            4,  -- attack_range
            3,  -- move_range
            3   -- initiative
        )
        u:add_spell(fireball)
        u:add_spell(earthquake)
        u.name = 'Wizard'
        return u
    end,

    ['Cat'] = function (node, is_player, ...)
        local u = unit(node, sprite('resources/cat.png'), 64, 64, 64, 64, is_player)
        u:set_statistics(
            80, -- health
            5,  -- damage
            3,  -- attack_range
            2,  -- move_range
            2   -- initiative
        )
        u:add_spell(healing)
        u.name = 'Cat'
        u.sprite_sx = 0.75
        u.sprite_sy = 0.75
        return u
    end,

    ['Witch'] = function (node, is_player, ...)
        -- local sprite = animation('resources/Blue_witch/B_witch_idle.png', false, 0.5)
        -- sprite:add_frame(0, 0, 32, 48)
        -- sprite:add_frame(0, 48, 32, 48)
        -- sprite:add_frame(0, 96, 32, 48)
        -- sprite:add_frame(0, 96+48, 32, 48)
        -- sprite.play = true

        local u = unit(node, sprite('resources/Blue_witch/B_witch_idle.png'), 32, 48, 32, 288, is_player)
        u:set_statistics(
            90, -- health
            8,  -- damage
            4,  -- attack_range
            3,  -- move_range
            3   -- initiative
        )
        u:add_spell(fireball)
        u:add_spell(earthquake)
        u.name = 'Witch'
        u.sprite_sx = 1.3
        u.sprite_sy = 1.3
        return u
    end,

    ['Bat'] = function (node, is_player, ...)
        local u = unit(node, sprite('resources/bat.png'), 81, 57, 81, 57, is_player)
        u:set_statistics(
            120, -- health
            10,  -- damage
            1,   -- attack_range
            3,   -- move_range
            4    -- initiative
        )
        u.name = 'Bat'
        return u
    end
}