-- data/upgrades.lua
-- Definitions of upgrades for a roguelike run.
-- scope: 'run' (default) — lasts until the end of the run.
--        'battle' — only for one battle (used by curses).
-- rarity: 'common' | 'uncommon' | 'rare' | 'legendary'
-- Special effects (not covered by modifiers) use on_apply/on_expire.
--
-- IMPORTANT: filter functions are not serialized. For saves, store only ids.

local Upgrades = {}

-- ------------------------------------------------------------------
-- Filter helpers (reused across the data)
-- ------------------------------------------------------------------
local function byAttribute(attr)
    return function(c) return c.attribute == attr end
end

local function byElement(elem)
    return function(c) return c.element == elem end
end

local function byRole(role)
    return function(c) return c.role == role end
end

Upgrades['level_up'] = {
    id = 'level_up',
    scope = 'permanent',
    source = 'level_up',
    mods = {
        { stat = 'max_health', op = 'add', value = 4, },
        { stat = 'max_energy', op = 'add', value = 2, },
        { stat = 'damage',     op = 'add', value = 2, },
        { stat = 'initiative', op = 'add', value = 1, },
        { stat = 'armor',      op = 'add', value = 1, },
    },
}

-- ------------------------------------------------------------------
-- 1. STAT UPGRADES
-- ------------------------------------------------------------------

Upgrades['vitality'] = {
    id = 'vitality',
    name = 'Vitality',
    description = '+15% max HP to all creatures.',
    icon = 'icons/vitality.png',
    rarity = 'common',
    tags = { 'stat', 'health' },
    mods = {
        { stat = 'max_health', op = 'mul', value = 1.15 },
    },
}

Upgrades['ferocity'] = {
    id = 'ferocity',
    name = 'Ferocity',
    description = '+15% physical damage.',
    icon = 'icons/ferocity.png',
    rarity = 'common',
    tags = { 'stat', 'damage' },
    mods = {
        { stat = 'damage', op = 'mul', value = 1.15 },
    },
}

Upgrades['concentration'] = {
    id = 'concentration',
    name = 'Concentration',
    description = '+15% spell damage.',
    icon = 'icons/concentration.png',
    rarity = 'common',
    tags = { 'stat', 'spell' },
    mods = {
        { stat = 'spell_power', op = 'mul', value = 1.15 },
    },
}

Upgrades['fortitude'] = {
    id = 'fortitude',
    name = 'Fortitude',
    description = '+2 armor to all creatures.',
    icon = 'icons/fortitude.png',
    rarity = 'common',
    tags = { 'stat', 'armor' },
    mods = {
        { stat = 'armor', op = 'add', value = 2 },
    },
}

Upgrades['initiative'] = {
    id = 'initiative',
    name = 'Initiative',
    description = '+2 initiative to all creatures.',
    icon = 'icons/initiative.png',
    rarity = 'uncommon',
    tags = { 'stat', 'speed' },
    mods = {
        { stat = 'initiative', op = 'add', value = 2 },
    },
}

Upgrades['endurance'] = {
    id = 'endurance',
    name = 'Endurance',
    description = '+25% max HP, but -10% damage.',
    icon = 'icons/endurance.png',
    rarity = 'uncommon',
    tags = { 'stat', 'health', 'trade-off' },
    mods = {
        { stat = 'max_health', op = 'mul', value = 1.25 },
        { stat = 'damage',     op = 'mul', value = 0.9  },
    },
}

Upgrades['berserk'] = {
    id = 'berserk',
    name = 'Berserk',
    description = '+30% damage, but -15% max HP.',
    icon = 'icons/berserk.png',
    rarity = 'uncommon',
    tags = { 'stat', 'damage', 'trade-off' },
    mods = {
        { stat = 'damage',     op = 'mul', value = 1.3 },
        { stat = 'max_health', op = 'mul', value = 0.85 },
    },
}

-- ------------------------------------------------------------------
-- 2. ATTRIBUTE & ELEMENT UPGRADES
-- ------------------------------------------------------------------

Upgrades['master_wild'] = {
    id = 'master_wild',
    name = 'Mastery: Wild',
    description = 'Wild-attribute creatures gain +20% damage.',
    icon = 'icons/master_wild.png',
    rarity = 'rare',
    tags = { 'attribute', 'wild' },
    filter = byAttribute('wild'),
    mods = {
        { stat = 'damage', op = 'mul', value = 1.2 },
    },
}

Upgrades['master_mystic'] = {
    id = 'master_mystic',
    name = 'Mastery: Mystic',
    description = 'Mystic-attribute creatures gain +20% damage.',
    icon = 'icons/master_mystic.png',
    rarity = 'rare',
    tags = { 'attribute', 'mystic' },
    filter = byAttribute('mystic'),
    mods = {
        { stat = 'damage', op = 'mul', value = 1.2 },
    },
}

Upgrades['master_mechanic'] = {
    id = 'master_mechanic',
    name = 'Mastery: Mechanic',
    description = 'Mechanic-attribute creatures gain +20% damage.',
    icon = 'icons/master_mechanic.png',
    rarity = 'rare',
    tags = { 'attribute', 'mechanic' },
    filter = byAttribute('mechanic'),
    mods = {
        { stat = 'damage', op = 'mul', value = 1.2 },
    },
}

Upgrades['element_mastery_fire'] = {
    id = 'element_mastery_fire',
    name = 'Fire Mastery',
    description = 'Fire-element spells deal +25% damage.',
    icon = 'icons/element_fire.png',
    rarity = 'uncommon',
    tags = { 'element', 'fire' },
    mods = {
        -- spell_power is used by the damage calculator for spells
        { stat = 'spell_power', op = 'mul', value = 1.25, filter_elem = 'fire' },
    },
}

Upgrades['element_mastery_water'] = {
    id = 'element_mastery_water',
    name = 'Water Mastery',
    description = 'Water-element spells deal +25% damage.',
    icon = 'icons/element_water.png',
    rarity = 'uncommon',
    tags = { 'element', 'water' },
    mods = {
        { stat = 'spell_power', op = 'mul', value = 1.25, filter_elem = 'water' },
    },
}

Upgrades['element_mastery_ice'] = {
    id = 'element_mastery_ice',
    name = 'Ice Mastery',
    description = 'Ice-element spells apply Slow for 2 turns.',
    icon = 'icons/element_ice.png',
    rarity = 'uncommon',
    tags = { 'element', 'ice' },
    mods = {},  -- implemented via on_spell_hit hook
    hooks = {
        on_spell_hit = function(target, spell)
            if spell.element == 'ice' then
                target:addModifier({
                    id = 'slow_'..target.name,
                    scope = 'battle',
                    stat = 'initiative',
                    op = 'add',
                    value = -2,
                    duration = { type = 'turn', value = 2 },
                    stack = 'refresh',
                })
            end
        end,
    },
}

Upgrades['unity_of_elements'] = {
    id = 'unity_of_elements',
    name = 'Unity of Elements',
    description = 'If all creatures share the same element: +15% to all stats.',
    icon = 'icons/unity.png',
    rarity = 'rare',
    tags = { 'synergy', 'element' },
    condition = function(party)
        local e = party[1] and party[1].element
        if not e then return false end
        for _, c in ipairs(party) do
            if c.element ~= e then return false end
        end
        return true
    end,
    mods = {
        { stat = 'max_health', op = 'mul', value = 1.15 },
        { stat = 'damage',     op = 'mul', value = 1.15 },
        { stat = 'armor',      op = 'add', value = 2    },
    },
}

Upgrades['diversity'] = {
    id = 'diversity',
    name = 'Diversity',
    description = 'If the party has 4 different elements: +10% damage.',
    icon = 'icons/diversity.png',
    rarity = 'rare',
    tags = { 'synergy', 'element' },
    condition = function(party)
        local seen, count = {}, 0
        for _, c in ipairs(party) do
            if c.element and not seen[c.element] then
                seen[c.element] = true
                count = count + 1
            end
        end
        return count >= 4
    end,
    mods = {
        { stat = 'damage', op = 'mul', value = 1.1 },
    },
}

Upgrades['piercing'] = {
    id = 'piercing',
    name = 'Piercing',
    description = 'Attacks ignore 25% of the target\'s armor.',
    icon = 'icons/piercing.png',
    rarity = 'uncommon',
    tags = { 'combat', 'armor' },
    mods = {
        { stat = 'armor_pierce', op = 'add', value = 0.25 },
    },
}

Upgrades['adaptation'] = {
    id = 'adaptation',
    name = 'Adaptation',
    description = 'After taking damage from an element: +20% resistance to it for the rest of the battle.',
    icon = 'icons/adaptation.png',
    rarity = 'rare',
    tags = { 'combat', 'element' },
    mods = {},
    hooks = {
        on_damage_taken = function(target, element)
            if not element then return end
            target:addModifier({
                id = 'resist_'..element,
                scope = 'battle',
                stat = 'resist_'..element,
                op = 'add',
                value = 0.2,
                duration = { type = 'battle', value = 1 },
                stack = 'refresh',
            })
        end,
    },
}

-- ------------------------------------------------------------------
-- 3. SHARDS & ECONOMY
-- ------------------------------------------------------------------

Upgrades['generosity'] = {
    id = 'generosity',
    name = 'Generosity',
    description = '+1 shard per defeated enemy.',
    icon = 'icons/generosity.png',
    rarity = 'common',
    tags = { 'economy', 'shards' },
    mods = {
        { stat = 'shard_bonus', op = 'add', value = 1 },
    },
}

-- Upgrades['exchange'] = {
--     id = 'exchange',
--     name = 'Exchange',
--     description = 'Allows trading 3 shards of one type for 1 of another (in camp).',
--     icon = 'icons/exchange.png',
--     rarity = 'uncommon',
--     tags = { 'economy', 'shards' },
--     mods = {},
--     -- unlocks = { 'shard_exchange' },  -- flag for the camp UI
--     meta_unlock = 'shard_exchange',
-- }

Upgrades['synthesis'] = {
    id = 'synthesis',
    name = 'Synthesis',
    description = '10% chance to gain an extra random shard on victory.',
    icon = 'icons/synthesis.png',
    rarity = 'uncommon',
    tags = { 'economy', 'shards' },
    mods = {},
    hooks = {
        on_battle_win = function(player)
            if math.random() < 0.1 then
                local t = { 'wild','mystic','mechanic','ancient','chaos' }
                player:addShard(t[math.random(#t)], 1)
            end
        end,
    },
}

Upgrades['essence_flow'] = {
    id = 'essence_flow',
    name = 'Essence Flow',
    description = '+1 universal essence on victory.',
    icon = 'icons/essence_flow.png',
    rarity = 'rare',
    tags = { 'economy', 'essence' },
    mods = {
        { stat = 'essence_bonus', op = 'add', value = 1 },
    },
}

-- Upgrades['collector'] = {
--     id = 'collector',
--     name = 'Collector',
--     description = 'All shards collected during the run are kept after the run ends.',
--     icon = 'icons/collector.png',
--     rarity = 'legendary',
--     tags = { 'economy', 'shards', 'meta' },
--     mods = {},
--     unlocks = { 'keep_shards_after_run' },
-- }

-- Upgrades['alchemist'] = {
--     id = 'alchemist',
--     name = 'Alchemist',
--     description = 'Once per run: create a random creature from 5 shards of any type.',
--     icon = 'icons/alchemist.png',
--     rarity = 'rare',
--     tags = { 'economy', 'craft' },
--     mods = {},
--     -- unlocks = { 'random_creature_craft' },
--     meta_unlock = 'random_creature_craft',
-- }

-- ------------------------------------------------------------------
-- 4. COMBAT MECHANICS
-- ------------------------------------------------------------------

Upgrades['extra_action'] = {
    id = 'extra_action',
    name = 'Extra Action',
    description = 'Once per battle: one creature gains +1 action.',
    icon = 'icons/extra_action.png',
    rarity = 'legendary',
    tags = { 'combat', 'action' },
    mods = {},
    unlocks = { 'extra_action_once_per_battle' },
}

Upgrades['swift_movement'] = {
    id = 'swift_movement',
    name = 'Swift Movement',
    description = '+1 movement range to all creatures.',
    icon = 'icons/swift.png',
    rarity = 'common',
    tags = { 'combat', 'movement' },
    mods = {
        { stat = 'move_range', op = 'add', value = 1 },
    },
}

Upgrades['long_shot'] = {
    id = 'long_shot',
    name = 'Long Shot',
    description = '+1 attack range.',
    icon = 'icons/long_shot.png',
    rarity = 'uncommon',
    tags = { 'combat', 'range' },
    mods = {
        { stat = 'attack_range', op = 'add', value = 1 },
    },
}

Upgrades['counter_attack'] = {
    id = 'counter_attack',
    name = 'Counter Attack',
    description = '20% chance to retaliate against a melee attack.',
    icon = 'icons/counter.png',
    rarity = 'uncommon',
    tags = { 'combat', 'defense' },
    mods = {},
    hooks = {
        on_melee_hit_taken = function(target, attacker)
            if math.random() < 0.2 then
                attacker:take_damage(target, target:get_stat('damage'), true)
            end
        end,
    },
}

Upgrades['first_strike'] = {
    id = 'first_strike',
    name = 'First Strike',
    description = 'The first attack in a battle deals +50% damage.',
    icon = 'icons/first_strike.png',
    rarity = 'uncommon',
    tags = { 'combat', 'damage' },
    mods = {},
    hooks = {
        on_battle_start = function(battle)
            for _, unit in ipairs(battle.units) do
                if unit.is_player then
                    unit:addModifier({
                        id = 'first_strike',
                        scope = 'battle',
                        stat = 'damage',
                        op = 'mul',
                        value = 1.5,
                        duration = { type = 'turn', value = 1 },
                        stack = 'refresh',
                    })
                end
            end
        end,
    },
}

Upgrades['second_wind'] = {
    id = 'second_wind',
    name = 'Second Wind',
    description = 'Once per battle: a creature below 20% HP restores 30% HP.',
    icon = 'icons/second_wind.png',
    rarity = 'rare',
    tags = { 'combat', 'heal' },
    mods = {},
    hooks = {
        on_damage_taken = function(unit)
            if unit._second_wind_used then return end
            if unit.health / unit.max_health < 0.2 then
                unit:heal(math.floor(unit.max_health * 0.3))
                unit._second_wind_used = true
                Tagtext:add('+Heal', unit.x, unit.y - 50, 1.5, 30, {0.3, 1, 0.3})
            end
        end,
    },
}

Upgrades['inspiration'] = {
    id = 'inspiration',
    name = 'Inspiration',
    description = 'When an enemy is killed, all allies gain +10% to their next attack.',
    icon = 'icons/inspiration.png',
    rarity = 'rare',
    tags = { 'combat', 'buff' },
    mods = {},
    hooks = {
        on_enemy_killed = function(victim, killer, battle)
            for _, ally in ipairs(battle.units) do
                if ally.is_player and not ally.is_dead then
                    ally:addModifier({
                        id = 'inspired',
                        scope = 'battle',
                        stat = 'damage',
                        op = 'mul',
                        value = 1.1,
                        duration = { type = 'turn', value = 1 },
                        stack = 'refresh',
                    })
                end
            end
        end,
    },
}

Upgrades['trap_master'] = {
    id = 'trap_master',
    name = 'Trap Master',
    description = 'At the start of battle, a trap spawns on a random tile (damages enemies).',
    icon = 'icons/trap.png',
    rarity = 'rare',
    tags = { 'combat', 'utility' },
    mods = {},
    hooks = {
        on_battle_start = function(battle)
            -- Trap spawning is implemented at the BattleState level
            battle:spawn_random_trap()
        end,
    },
}

-- ------------------------------------------------------------------
-- 5. PERSONAL UPGRADES (targeting a specific creature)
-- ------------------------------------------------------------------

Upgrades['loyalty'] = {
    id = 'loyalty',
    name = 'Loyalty',
    description = 'The chosen creature gains +20% to all stats until the end of the run.',
    icon = 'icons/loyalty.png',
    rarity = 'rare',
    tags = { 'personal', 'buff' },
    target = 'single',           -- UI should prompt for a creature
    mods = {
        { stat = 'max_health', op = 'mul', value = 1.2 },
        { stat = 'damage',     op = 'mul', value = 1.2 },
        { stat = 'armor',      op = 'add', value = 2   },
    },
}

Upgrades['new_ability'] = {
    id = 'new_ability',
    name = 'New Ability',
    description = 'The chosen creature learns a random spell of its element.',
    icon = 'icons/new_ability.png',
    rarity = 'rare',
    tags = { 'personal', 'spell' },
    target = 'single',
    mods = {},
    on_apply = function(character)
        local pool = SPELLS_BY_ELEMENT[character.element] or {}
        if #pool == 0 then return end
        local id = pool[math.random(#pool)]
        if not character:hasSpell(id) then
            Character.addSpell(character, id)
        end
    end,
}

Upgrades['evolution'] = {
    id = 'evolution',
    name = 'Evolution',
    description = 'The chosen creature changes its attribute to a random one.',
    icon = 'icons/evolution.png',
    rarity = 'legendary',
    tags = { 'personal', 'attribute' },
    target = 'single',
    mods = {},
    on_apply = function(character)
        local all = { 'wild', 'mystic', 'mechanic', 'ancient', 'chaos' }
        local new
        repeat new = all[math.random(#all)] until new ~= character.attribute
        character.attribute = new
    end,
}

Upgrades['second_chance'] = {
    id = 'second_chance',
    name = 'Second Chance',
    description = 'Once per run: if the creature dies, it revives with 30% HP.',
    icon = 'icons/second_chance.png',
    rarity = 'legendary',
    tags = { 'personal', 'revive' },
    target = 'single',
    mods = {},
    on_apply = function(character)
        character._second_chance_available = true
    end,
    hooks = {
        on_death = function(unit)
            local c = unit.character
            if c and c._second_chance_available then
                c._second_chance_available = false
                unit.is_dead = false
                unit.health = math.floor(unit.max_health * 0.3)
                -- return to field and queue — depends on implementation
                BattleState:revive_unit(unit)
            end
        end,
    },
}

-- ------------------------------------------------------------------
-- 6. MAP & EXPEDITION
-- ------------------------------------------------------------------

Upgrades['scouting'] = {
    id = 'scouting',
    name = 'Scouting',
    description = 'Reveals enemy types in adjacent locations.',
    icon = 'icons/scouting.png',
    rarity = 'common',
    tags = { 'map', 'utility' },
    mods = {},
    unlocks = { 'show_enemy_types' },
}

Upgrades['guide'] = {
    id = 'guide',
    name = 'Guide',
    description = 'Once per run: skip one location without a fight.',
    icon = 'icons/guide.png',
    rarity = 'uncommon',
    tags = { 'map', 'utility' },
    mods = {},
    unlocks = { 'skip_location_once' },
}

Upgrades['camp'] = {
    id = 'camp',
    name = 'Camp',
    description = 'Once per run: restore 30% HP to all creatures.',
    icon = 'icons/camp.png',
    rarity = 'rare',
    tags = { 'map', 'heal' },
    mods = {},
    unlocks = { 'camp_once' },
}

Upgrades['treasury'] = {
    id = 'treasury',
    name = 'Treasury',
    description = '+50% gold on victory.',
    icon = 'icons/treasury.png',
    rarity = 'common',
    tags = { 'map', 'economy' },
    mods = {
        { stat = 'gold_bonus', op = 'mul', value = 1.5 },
    },
}

Upgrades['beacon'] = {
    id = 'beacon',
    name = 'Beacon',
    description = 'Reveals the location of the map boss.',
    icon = 'icons/beacon.png',
    rarity = 'uncommon',
    tags = { 'map', 'utility' },
    mods = {},
    unlocks = { 'show_boss_location' },
}

Upgrades['sanctuary'] = {
    id = 'sanctuary',
    name = 'Sanctuary',
    description = 'At the start of the next battle, all creatures gain a random buff for 3 turns.',
    icon = 'icons/sanctuary.png',
    rarity = 'rare',
    tags = { 'map', 'buff' },
    mods = {},
    hooks = {
        on_battle_start = function(battle)
            local pool = {
                { stat = 'damage',     value = 1.2 },
                { stat = 'armor',      value = 3   },
                { stat = 'max_health', value = 10  },
                { stat = 'initiative', value = 2   },
            }
            for _, unit in ipairs(battle.units) do
                if unit.is_player then
                    local b = pool[math.random(#pool)]
                    unit:addModifier({
                        id = 'sanctuary_buff',
                        scope = 'battle',
                        stat = b.stat,
                        op = b.stat == 'armor' or b.stat == 'max_health' or b.stat == 'initiative' and 'add' or 'mul',
                        value = b.value,
                        duration = { type = 'turn', value = 3 },
                        stack = 'refresh',
                    })
                end
            end
        end,
    },
}

-- ------------------------------------------------------------------
-- 7. CURSES (risk / reward)
-- ------------------------------------------------------------------

Upgrades['blood_deal'] = {
    id = 'blood_deal',
    name = 'Blood Deal',
    description = '+30% damage, but each creature loses 5% HP at the start of battle.',
    icon = 'icons/blood_deal.png',
    rarity = 'rare',
    tags = { 'curse', 'damage' },
    mods = {
        { stat = 'damage', op = 'mul', value = 1.3 },
    },
    hooks = {
        on_battle_start = function(battle)
            for _, unit in ipairs(battle.units) do
                if unit.is_player then
                    local loss = math.floor(unit.max_health * 0.05)
                    unit:take_damage(nil, loss, false)
                end
            end
        end,
    },
}

Upgrades['fragility'] = {
    id = 'fragility',
    name = 'Fragility',
    description = '+2 initiative, but -20% max HP.',
    icon = 'icons/fragility.png',
    rarity = 'rare',
    tags = { 'curse', 'speed' },
    mods = {
        { stat = 'initiative', op = 'add', value = 2    },
        { stat = 'max_health', op = 'mul', value = 0.8  },
    },
}

Upgrades['greed'] = {
    id = 'greed',
    name = 'Greed',
    description = '+2 shards per enemy, but -10% armor.',
    icon = 'icons/greed.png',
    rarity = 'rare',
    tags = { 'curse', 'economy' },
    mods = {
        { stat = 'shard_bonus', op = 'add', value = 2 },
        { stat = 'armor',       op = 'mul', value = 0.9 },
    },
}

Upgrades['obsession'] = {
    id = 'obsession',
    name = 'Obsession',
    description = '+1 action per battle, but -10% accuracy.',
    icon = 'icons/obsession.png',
    rarity = 'legendary',
    tags = { 'curse', 'action' },
    mods = {
        { stat = 'miss_chance', op = 'add', value = 0.1 },
    },
    unlocks = { 'extra_action_once_per_battle' },
}

Upgrades['dark_pact'] = {
    id = 'dark_pact',
    name = 'Dark Pact',
    description = 'Spells deal +30% damage, but +1 to cooldown.',
    icon = 'icons/dark_pact.png',
    rarity = 'legendary',
    tags = { 'curse', 'spell' },
    mods = {
        { stat = 'spell_power', op = 'mul', value = 1.3 },
    },
    hooks = {
        on_battle_start = function(battle)
            for _, unit in ipairs(battle.units) do
                if unit.is_player then
                    for _, spell in ipairs(unit.spells) do
                        spell.cooldown_mod = (spell.cooldown_mod or 0) + 1
                    end
                end
            end
        end,
    },
}

-- ------------------------------------------------------------------
-- 8. SPELL MODIFIERS
-- ------------------------------------------------------------------

Upgrades['double_cast'] = {
    id = 'double_cast',
    name = 'Double Cast',
    description = '10% chance for a spell to trigger twice.',
    icon = 'icons/double_cast.png',
    rarity = 'rare',
    tags = { 'spell', 'proc' },
    mods = {
        { stat = 'double_cast_chance', op = 'add', value = 0.1 },
    },
}

Upgrades['echo'] = {
    id = 'echo',
    name = 'Echo',
    description = '15% chance for a spell not to go on cooldown.',
    icon = 'icons/echo.png',
    rarity = 'rare',
    tags = { 'spell', 'proc' },
    mods = {
        { stat = 'echo_chance', op = 'add', value = 0.15 },
    },
}

Upgrades['amplify_area'] = {
    id = 'amplify_area',
    name = 'Amplified Area',
    description = 'Area attacks gain +1 to radius.',
    icon = 'icons/amplify_area.png',
    rarity = 'rare',
    tags = { 'spell', 'aoe' },
    mods = {
        { stat = 'aoe_bonus', op = 'add', value = 1 },
    },
}

Upgrades['exhaustion'] = {
    id = 'exhaustion',
    name = 'Exhaustion',
    description = 'Attacks deal extra damage equal to 10% of the target\'s max HP.',
    icon = 'icons/exhaustion.png',
    rarity = 'legendary',
    tags = { 'spell', 'damage' },
    mods = {
        { stat = 'percent_hp_damage', op = 'add', value = 0.1 },
    },
}

-- ------------------------------------------------------------------
-- Rarity registry (for the selection UI)
-- ------------------------------------------------------------------

Upgrades.RARITY_WEIGHTS = {
    common    = 60,
    uncommon  = 25,
    rare      = 12,
    legendary = 3,
}

-- Group by tag for the shop/filter
Upgrades.BY_TAG = {}
for id, up in pairs(Upgrades) do
    if type(up) == 'table' and up.tags then
        for _, tag in ipairs(up.tags) do
            Upgrades.BY_TAG[tag] = Upgrades.BY_TAG[tag] or {}
            table.insert(Upgrades.BY_TAG[tag], id)
        end
    end
end

return Upgrades