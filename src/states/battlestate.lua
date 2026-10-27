local move = require 'src.actions.move'
local map = require 'src.map'
local pathfinder = require 'src.pathfinder'
local queue = require 'src.actorQueue'
local panel = require 'src.commandPanel'
local Unit = require 'src.objects.unit'
local inventory = require 'src.inventory'
local Sprite = require 'src.sprite'
local Tween = require 'lib.tween'
local Character = require 'src.character'
local Characters = require 'src.characters'
local Stats = require 'src.stats'
local RivalGenerator = require 'data.story.generators.rival_generator'
local RunState = require 'src.states.run_state'

local Actions = require 'src.actions'

local AI = require 'src.ai'

local characterList = require 'src.characters'

local BattleUI = require 'src.battlestate.BattleUI'
local BattleInput = require 'src.battlestate.BattleInput'

-- Константы (оставлены здесь)
local fontSize = 14
local font = love.graphics.newFont(fontSize)
local mapWidth = 7
local mapHeight = 5

-- Вспомогательная функция (осталась локальной)
local function find_tile(map, offset)
    for i = offset, offset + 1 do
        for j = 1, map.height do
            local tile = map:get_tile(i, j)
            if tile and not tile.is_blocked then
                return tile
            end
        end
    end
    return false
end

-- Мастер-отряды приходят из master_generator набором дескрипторов
-- { species, attribute, element, level }. Имена видов там не совпадают с
-- ключами бестиария, поэтому вид ищется в три шага:
--   1. точный ключ бестиария (src/characters/);
--   2. пул видов по атрибуту (те же существа, что использует rival_generator);
--   3. нил — вызывающая сторона создаст минимальный Character.
-- Выбор по индексу, а не случайный: построение боя остаётся детерминированным.
local function resolve_species(template_name, attribute, index)
    if type(template_name) == 'string' and Characters[template_name] then
        return template_name
    end

    local pools = RivalGenerator and RivalGenerator.SPECIES_POOL
    local pool = pools and pools[attribute]
    if pool and #pool > 0 then
        local sorted = {}
        for i, name in ipairs(pool) do sorted[i] = name end
        table.sort(sorted)
        return sorted[((index or 1) - 1) % #sorted + 1]
    end

    return nil
end

local BattleState = {}

function BattleState:init()
    self.panel = panel(self.u)
    self.result = nil
    self.paused = false
    self.active = false

    -- Инициализация подсистем
    self.ui = BattleUI(self)          -- отрисовка лога, наград, результата
    self.input = BattleInput(self)    -- обработка мыши/клавиатуры

    -- Остальные поля (сохранены)
    self.background = Sprite('resources/background.jpg')
    self.rewards_print_progress = 0
    self.rewards_tween = nil
    self.rewards = {}
    self.shards_gained = {}
    self.essence_gained = 0
    self.grabbed_actor = nil
    self.shaking = 0
    self.defeatedEnemies = {}
    self.log = {}
    self.info_unit = nil

    self.pressed_actor   = nil    -- юнит, на котором нажали ЛКМ
    self.pressed_x       = 0
    self.pressed_y       = 0
    self.drag_started    = false  -- стал ли drag (превысили порог)
    self.drag_threshold  = 8      -- пикселей, чтобы отличить клик от drag
    self.pressed_tile    = nil

    self.map = nil
    self.pathfinder = nil
    self.queue = nil
    self.type = nil
    self.objects = {}
    self.units = {}
    self.actions = {}
    self.state = 'none'
    self.phase = 'none'
    self.target_mode = 'none'
    self.current_spell = nil
    self.action_complete = false
    self.player = nil
    self.inventory = nil
    self.level = 1

    -- Story battle: runtime reference to Player.meta_story.masters[id].
    -- Never serialized here — the master already lives in Player (R6).
    self.master  = nil   -- nil → legacy enemy generation
    self.enraged = false -- stored only; applied in Task B
    
    self._extra_action_available = 0
    self._extra_action_pending = false
end

function BattleState:enter(from, args)
    self.active = true
    FieldMusic:stop()
    BattleMusic:play()

    self.result = nil
    self.paused = false
    self.level = args.node and args.node.level or 1
    self.type = args.node and args.node.type or 'nil'

    self.map = map(mapWidth, mapHeight)
    self.pathfinder = pathfinder(self.map)
    self.queue = queue(230, love.graphics.getHeight() - 210)
    self.objects = {}
    self.units = {}
    self.actions = {}
    self.log = { 'Prepare to battle!' }
    self.state = 'prepare'
    self.phase = 'none'
    self.target_mode = 'none'
    self.current_spell = nil
    self.action_complete = false
    
    self._extra_action_available = 0
    self._extra_action_pending = false

    self.player = args.player
    self.inventory = inventory(100, 10, self.player.inventory)

    -- Story battle args. `master` may be nil → legacy enemies below.
    self.master  = args.master
    self.enraged = args.enraged or false

    -- Расстановка игроков (активные)
    for i = 1, self.player.charactersActiveSize do
        local character = self.player.charactersActive[i]
        if character then
            local tile
            if character.prepare_x and character.prepare_y then
                tile = self.map:get_tile(character.prepare_x, character.prepare_y)
            end
            if not tile or tile.is_blocked then
                tile = find_tile(self.map, 0)
            end
            self:add_unit(character, true, tile)
        end
    end

    -- Расстановка запасных
    for i = 1, self.player.charactersSpareSize do
        local character = self.player.charactersSpare[i]
        if character then
            local tile = self.map.tilesSpare[character.prepare_y]
            if not tile then
                for _, t in ipairs(self.map.tilesSpare) do
                    if not t.unit then
                        tile = t
                        break
                    end
                end
            end
            if tile then
                self:add_unit(character, true, tile, true)
            end
        end
    end

    -- Клетки врагов (правые две колонки). Раскладка общая для обоих путей.
    local enemy_tiles = {}
    for i = 0, 1 do
        for j = 1, self.map.height do
            local tile = self.map:get_tile(self.map.width - i, j)
            if not tile.is_blocked then
                table.insert(enemy_tiles, tile)
            end
        end
    end

    if self.master then
        -- Сюжетный бой: отряд мастера берётся как есть — один юнит на
        -- дескриптор, без фильтрации и без добивки.
        local party = self.master.battle_party or {}
        local spawned = 0
        for i, desc in ipairs(party) do
            local tile = table.remove(enemy_tiles, 1)
            if not tile then
                print(('[BattleState] master party wants %d enemies, only %d tiles free')
                    :format(#party, spawned))
                break
            end
            self:_spawn_enemy_from_descriptor(desc, i, tile)
            spawned = spawned + 1
        end
    else
        -- Legacy: случайные враги из бестиария.
        local possibleEnemies = {}
        for name, character in pairs(characterList) do
            if not character.starter_character then
                table.insert(possibleEnemies, name)
            end
        end

        local enemies_count = args.node and args.node.enemies_count or 2
        for i = 1, enemies_count do
            local tile = table.remove(enemy_tiles, math.random(1, #enemy_tiles))
            local name = possibleEnemies[math.random(#possibleEnemies)]
            local character = Character.new(Characters[name])
            local u = self:add_unit(character, false, tile)
            u.name = u.name .. ' ' .. i
        end
    end

    -- Ярость мастера: те же боевые модификаторы на каждого врага.
    -- Действует только в сюжетном бою и только при enraged — на
    -- legacy-путь и на юнитов игрока не распространяется.
    if self.master and self.enraged then
        for _, unit in ipairs(self.units) do
            if not unit.is_player then
                self:_apply_enraged(unit)
            end
        end
    end

    -- Открытые клетки для игроков
    for _, tile in pairs(self.map.tiles._props) do
        if tile.tx <= 2 then
            if not tile.actor then
                tile.is_open = true
            end
        end
    end
    for _, tile in ipairs(self.map.tilesSpare) do
        if not tile.actor then
            tile.is_open = true
        end
    end

    -- Сохраняем врагов для возможного рекрутинга
    self.defeatedEnemies = {}
    for _, unit in ipairs(self.units) do
        if not unit.is_player then
            table.insert(self.defeatedEnemies, unit:convertToParty())
        end
    end

    self.shards_gained = {}

    -- Сброс UI
    self.ui:reset()
end

function BattleState:leave()
    self.active = false
    self.map = nil
    self.pathfinder = nil
    self.queue = nil
    self.state = 'none'
    self.current_spell = nil
    self.action_type = nil
    self.action_complete = false
    self.result = nil
    self.rewards_h = 0
    self.rewards_tween = nil
    self.rewards_print_progress = 0
    self.rewards = {}
    self.grabbed_actor = nil
    self.pressed_actor = nil
    self.drag_started  = false
    self.pressed_tile  = nil
    self.defeatedEnemies = {}
    self.shards_gained = {}
    self.info_unit = nil
end

function BattleState:isActive()
    return self.active
end

-- --- Основные методы (логика) ---

function BattleState:startBattle()
    self.state = 'battle'
    RunState:fireHook('on_battle_start', self)
    for _, tile in ipairs(self.map.tilesSpare) do
        tile.is_open = false
    end
    self.log = {}
    self:addLog('Battle begin!')
    
    if RunState:hasUnlock('extra_action_once_per_battle') then
        self._extra_action_available = 1
    end
    self:start_turn()
end

function BattleState:add_object(object)
    table.insert(self.objects, object)
    table.sort(self.objects, function(a, b) return (a.y or 0) < (b.y or 0) end)
end

function BattleState:remove_object(object)
    for i, v in ipairs(self.objects) do
        if v == object then
            table.remove(self.objects, i)
            break
        end
    end
end

function BattleState:add_unit(character, is_player, tile, spare)
    if not tile or tile.is_blocked then return false end

    -- local character = type(table_or_name) == 'string'
    --     and characterList[table_or_name]
    --     or table_or_name

    if is_player then
        return self:_add_player_unit(character, tile, spare)
    else
        return self:_add_enemy_unit(character, tile)
    end
end

function BattleState:_add_player_unit(character, tile, spare)
    local unit = Unit(tile, true):setup(character, RunState:getModifiers())
    unit.spare = spare or false
    table.insert(self.units, unit)
    if not spare then
        self.queue:add_actor(unit)
    end
    self:add_object(unit)
    return unit
end

function BattleState:_add_enemy_unit(character, tile)
    local unit = Unit(tile, false):setup(character, {})
    unit.spare = false
    table.insert(self.units, unit)
    self.queue:add_actor(unit)
    self:add_object(unit)
    return unit
end

-- Создаёт врага из дескриптора master.battle_party:
--   { species = <string>, attribute = ..., element = ..., level = <int> }
-- Атрибут и элемент дескриптора главнее шаблона, поэтому выставляются после
-- Character.new. Если вид не нашёлся в бестиарии — минимальный Character
-- с предупреждением в консоль, без падения боя.
function BattleState:_spawn_enemy_from_descriptor(desc, index, tile)
    index = index or 1
    local species = resolve_species(desc.species, desc.attribute, index)

    local character
    if species then
        character = Character.new(Characters[species])
    else
        print(('[BattleState] unknown creature species %q (attribute %q) — using minimal character')
            :format(tostring(desc.species), tostring(desc.attribute)))
        character = Character.new({
            name      = tostring(desc.species or ('beast ' .. index)),
            attribute = desc.attribute,
            element   = desc.element,
            spells    = {},
        })
    end

    character.attribute = desc.attribute
    character.element   = desc.element
    character.level     = desc.level or character.level

    -- Базовые запасы — через Stats без модификаторов (так же Unit:setup берёт
    -- max_health/max_energy). Уровень пока не масштабирует статы — это Task B.
    local baseStats = Stats(character, {}, {})
    character.health = baseStats:get('max_health')
    character.energy = baseStats:get('max_energy')

    local unit = self:add_unit(character, false, tile)
    if unit then
        unit.name = unit.name .. ' ' .. index
    end
    return unit
end

-- Ярость мастера: battle-scope модификаторы на одного врага.
-- Только damage и max_health — initiative и броня не трогаются, чтобы
-- поведение ActorQueue осталось прежним. Значения идут через Unit:addModifier,
-- то есть через агрегацию Stats (unit.modifiers → Stats:get()), а не правкой
-- character.* или unit.stats напрямую.
function BattleState:_apply_enraged(unit)
    if unit.is_player then return end

    local enragedModifiers = {
        -- ENRAGED_TUNING: damage ×1.15, max_health ×1.10
        { id = 'master_enraged_damage', stat = 'damage',     op = 'mul', value = 1.15 },
        { id = 'master_enraged_health', stat = 'max_health', op = 'mul', value = 1.10 },
    }

    for _, mod in ipairs(enragedModifiers) do
        unit:addModifier({
            id     = mod.id,
            scope  = 'battle',
            stat   = mod.stat,
            op     = mod.op,
            value  = mod.value,
            source = 'master_enraged',
        })
    end

    -- После подъёма max_health текущее здоровье выводится на новый максимум,
    -- чтобы враг не стартовал бой «уже раненым».
    unit.health = unit.stats:get('max_health')
end

function BattleState:remove_unit(unit)
    for i, other in ipairs(self.units) do
        if other == unit then
            table.remove(self.units, i)
            break
        end
    end
    self.queue:remove_actor(unit)
    unit:remove()
    self:remove_object(unit)

    self:check_result()
end

function BattleState:unit_death(unit, killer)
    self.queue:remove_actor(unit)

    RunState:fireHook('on_enemy_killed', unit, killer, self)

    self:check_result()
end

function BattleState:check_result()
    local is_win = true
    local is_lose = true
    for _, unit in ipairs(self.units) do
        if not unit.is_dead and not unit.spare then
            if unit.is_player then
                is_lose = false
            else
                is_win = false
            end
        end
    end
    if is_win then
        self.result = 'win'
        self.state = 'result'
    end
    if is_lose then
        self.result = 'lose'
        self.state = 'result'
    end
end

function BattleState:_calculateRewards()
    local player = self.player
    if not player then return end

    -- ---------- 1. Золото ----------
    local base_gold = 0
    if self.type == 'trainer' then
        base_gold = 30
    end
    if base_gold > 0 then
        local _, gold_mul = RunState:getStat('gold_bonus')
        if gold_mul <= 0 then gold_mul = 1 end
        local gold = math.floor(base_gold * gold_mul)
        player:addCurrency('gold', gold)
        table.insert(self.rewards, {
            type = 'currency', currency = 'gold', value = gold,
        })
    end

    -- ---------- 2. Осколки за убитых врагов ----------
    local shard_bonus = select(1, RunState:getStat('shard_bonus'))
    local per_enemy   = 1 + shard_bonus

    for _, unit in ipairs(self.units) do
        if not unit.is_player and unit.is_dead then
            local attr = unit.attribute
            if attr then
                player:addShard(attr, per_enemy)
                self.shards_gained[attr] = (self.shards_gained[attr] or 0) + per_enemy
            end
        end
    end

    -- ---------- 3. Эссенция ----------
    local essence_bonus = select(1, RunState:getStat('essence_bonus'))
    local base_essence  = 1
    local total_essence = base_essence + essence_bonus
    self.essence_gained = total_essence
    if total_essence > 0 then
        player:addEssence(total_essence)
    end

    -- ---------- 4. Опыт ----------
    self.exp_reward = 25 + 25 * self.level
    player:addExperience(self.exp_reward)
end

function BattleState:showResult()
    assert(self.result ~= 'win' or self.result ~= 'lose', "Wrong result!")

    BattleMusic:stop()
    for _, unit in ipairs(self.units) do
        for _, effect in ipairs(unit.status_effects) do
            effect:on_expire()
        end
    end
    
    self.paused = true
    local result
    if self.result == 'win' then
        self:_calculateRewards()
        RunState:fireHook('on_battle_win', self.player)
        result = "Victory!"
        VictoryMusic:play()
    elseif self.result == 'lose' then
        RunState:fireHook('on_battle_lose', self.player)
        result = "Defeat..."
    end
    self.ui:showResult(result)
end

function BattleState:returnToLevelmap(color)
    Gamestate.push(FadeInState, {
        color = color,
        time = 1,
        onFadeComplete = function()
            VictoryMusic:stop()
            FieldMusic:play()
            Levelmap.active = true
            Gamestate.pop({ result = self.result, charactersToSelect = self.defeatedEnemies })
            Gamestate.push(FadeOutState, { color = color, time = 1 })
        end
    })
end

function BattleState:addLog(text)
    table.insert(self.log, 1, text)
end

-- --- Действия и ходы ---

function BattleState:current_actor()
    return self.queue.current
end

function BattleState:current_action()
    return self.actions[1]
end

function BattleState:add_action(action, ...)
    if type(action) == 'string' then
        action = Actions[action](...)
    end
    table.insert(self.actions, action)
end

local function applyStatusEffects(actor)
    for i, effect in ipairs(actor.status_effects) do
        effect:on_tick()
        if effect.duration and effect.duration > 0 then
            effect.duration = effect.duration - 1
        end
        if effect.duration <= 0 then
            actor:remove_status_effect(effect)
        end
    end
end

local function tickModifiers(unit)
    for i = #unit.modifiers, 1, -1 do
        local m = unit.modifiers[i]
        local d = m.duration
        if not d then goto continue end

        -- тикаем только на ходах владельца
        if d.tick_on == nil or d.tick_on == 'owner' then
            if d.type == 'turn' then
                d.value = d.value - 1
            end
        end

        if d.value <= 0 then
            unit:removeModifier(m)
        end

        ::continue::
    end
end

function BattleState:start_turn()
    self._extra_action_pending = false
    self.queue:start_turn()
    self.phase = 'start_turn'
    local actor = self:current_actor()
    if not actor then return end

    applyStatusEffects(actor)

    tickModifiers(actor)

    if actor.is_dead then
        if self.state == 'result' then
            self:showResult()
        end
        return
    end

    for _, spell in ipairs(actor.spells) do
        if spell.current_cooldown and spell.current_cooldown > 0 then
            spell.current_cooldown = spell.current_cooldown - 1
        end
    end
end

function BattleState:useExtraAction()
    if self.state ~= 'battle' then return end
    if self.phase ~= 'idle' then return end
    if self._extra_action_available <= 0 then return end

    local actor = self:current_actor()
    if not actor or not actor.is_player then return end

    self._extra_action_available = 0
    self._extra_action_pending   = true

    self:addLog(actor.name .. ' takes an extra action!')
    PlaySound(ButtonClickSound)
end

function BattleState:handle_action(dt)
    local actor = self:current_actor()
    for i, action in ipairs(self.actions) do
        if action.is_new then
            self.map:reset_tiles()
            self.inventory:disable()
            action:start()
            action.is_new = false
            if self.phase ~= 'start_turn' then
                self.phase = 'action'
            end
        end
        local complete = action:update(dt)
        if complete then
            table.remove(self.actions, i)
            if action.name == 'Item' then
                self.nextPhase = 'start_turn'
            end
        end
    end

    if #self.actions == 0 then
        if self.state == 'result' then
            self:showResult()
            return
        end
        if self.nextPhase then
            self.phase = self.nextPhase
            self.nextPhase = nil
        end
        if self.phase == 'action' then
            if self._extra_action_pending then
                self._extra_action_pending = false
                self.queue:restart_turn()
                self.phase = 'start_turn'
            else
                self:start_turn()
            end
        elseif self.phase == 'start_turn' then
            self.phase = 'idle'
            if actor and actor.is_player then
                self:recalculate_path()
                self.inventory:enable()
            elseif actor then
                AI.think(self, actor)
            end
        end
    end
end

-- --- Целеуказание и пути ---

function BattleState:set_target_mode(current_spell, actionType)
    self.current_spell = current_spell
    self.action_type = actionType or 'spell'
    local actor = self:current_actor()
    self.map:reset_tiles()
    self.pathfinder:calculate_range2(actor.tile, current_spell.range)
    for _, t in pairs(self.map.tiles._props) do
        t.can_be_selected = current_spell.filter(t, actor) and t.range <= current_spell.range
        t:change_color()
    end
    self.target_mode = 'targeting'
    self.panel:show_cancel_button(true)
end

function BattleState:cancel_target_mode()
    self.current_spell = nil
    self.map:reset_tiles()
    self.target_mode = 'none'
    self.panel:show_cancel_button(false)
    if self.state == 'prepare' then
        for _, tile in pairs(self.map.tiles._props) do
            if tile.tx <= 2 and not tile.actor then
                tile.is_open = true
            end
            tile:change_color()
        end
        return
    end
    self:recalculate_path()
end

function BattleState:process_tiles(gscore, parents, actor, range)
    range = range or 99
    local is_melee = actor.attack_range == 1
    for _, tile in pairs(self.map.tiles._props) do
        local score = gscore[tile] or 0
        if not tile.is_blocked then
            if score > 0 and score <= range then
                tile.is_open = true
            end
        end
        if not tile.is_open and score <= range + 1 then
            if is_melee and tile.actor and actor:enemy_to(tile.actor) then
                tile.can_be_selected = true
            end
            tile.in_attack_range = true
        end
        tile.parent = parents[tile]
        tile:change_color()
    end
end

function BattleState:recalculate_path(tile, range)
    local actor = self:current_actor()
    if not actor then return end
    tile = tile or actor.tile
    range = range or actor.move_range
    self.map:reset_tiles()
    local gscore, parents = self.pathfinder:calculate(tile)
    self:process_tiles(gscore, parents, actor, range)
    if self.target_mode == 'drawing_path' then
        self.pathfinder:calculate_range(tile, 1)
        for i, t in ipairs(self.map.drawing_path) do
            t.parent = i == 1 and actor.tile or self.map.drawing_path[i-1]
        end
    else
        self.pathfinder:calculate_range(tile, actor.attack_range)
    end
    actor.tile.parent = nil
end

function BattleState:spawn_random_trap()
    
end

-- --- Боевая фаза: drag-путь + попап характеристик ---

-- ЛКМ вниз в бою. Только запоминаем тайл, ничего не начинаем.
function BattleState:battlePress(tile)
    if self.state ~= 'battle' then return end
    if self.phase ~= 'idle' then return end
    if self.target_mode ~= 'none' then return end
    if not tile then return end

    self.pressed_tile = tile
    self.pressed_x, self.pressed_y = love.mouse.getPosition()
    self.drag_started = false
end

-- Движение мыши. Как только порог пройден — стартуем путь.
function BattleState:battleMove(x, y, dx, dy)
    if self.state ~= 'battle' then return end
    if self.drag_started then return end
    if not self.pressed_tile then return end
    if self.target_mode ~= 'none' then return end

    local actor = self:current_actor()
    local t = self.pressed_tile

    -- Путь рисуем только от актора или из открытого тайла
    if not (t.actor == actor or t.is_open) then return end

    local mx, my = love.mouse.getPosition()
    local dist = math.sqrt((mx - self.pressed_x)^2 + (my - self.pressed_y)^2)
    if dist >= self.drag_threshold then
        self.drag_started = true
        self.map:start_drawing_path(t)
    end
end

-- ЛКМ вверх в бою: либо завершаем drag-путь, либо toggle попапа.
function BattleState:battleRelease()
    if self.state ~= 'battle' then return end

    if self.target_mode == 'drawing_path' then
        -- Завершение drag-пути
        self:hideUnitInfo()

        local path = self.map.drawing_path
        if next(path) then
            self.target_mode = 'none'
            local actor = self:current_actor()
            local target = self.map.last_tile and self.map.last_tile.actor
            self:add_action(move(actor, path, self.pathfinder, target))
        else
            self.map:stop_drawing_path()
        end

    elseif self.pressed_tile and not self.drag_started then
        -- Одиночный клик: открыть/переключить/закрыть попап
        local unit = self.pressed_tile.actor
        if unit then
            if self.info_unit == unit then
                self:hideUnitInfo()
            else
                self:showUnitInfo(unit)
            end
        else
            self:hideUnitInfo()
        end
    end

    self.pressed_tile = nil
    self.drag_started = false
end

-- --- Подготовительная фаза (захват юнитов) ---

-- Вызывается из BattleInput:mousepressed (ЛКМ), только в фазе prepare.
-- НЕ начинает drag — только запоминает потенциальный источник.
function BattleState:preparePress(tile)
    if self.state ~= 'prepare' then return end
    if self.grabbed_actor then return end
    if not tile then return end
    if not (tile.actor and tile.actor.is_player) then return end

    self.pressed_actor = tile.actor
    self.pressed_x, self.pressed_y = love.mouse.getPosition()
    self.drag_started = false
end

-- Вызывается из BattleInput:mousemoved.
-- Как только курсор ушёл дальше порога — стартуем drag.
function BattleState:prepareMove(x, y, dx, dy)
    if self.state ~= 'prepare' then return end
    if self.drag_started then return end
    if not self.pressed_actor then return end

    local mx, my = love.mouse.getPosition()
    local dist = math.sqrt((mx - self.pressed_x)^2 + (my - self.pressed_y)^2)
    if dist >= self.drag_threshold then
        self.drag_started = true
        self.grabbed_actor = self.pressed_actor
        self.player:removeCharacter(self.pressed_actor.character)
        PlaySound(ButtonClickSound)
    end
end

-- Вызывается из BattleInput:mousereleased (ЛКМ) в фазе prepare.
function BattleState:prepareRelease(tile)
    if self.state ~= 'prepare' then return end

    if self.drag_started and self.grabbed_actor then
        -- Завершение drag-переноса
        self:dropActor(tile)
        self.grabbed_actor = nil
        self.map.highlighted = nil
        self:hideUnitInfo()

    elseif self.pressed_actor then
        -- Одиночный клик: toggle попапа
        if self.info_unit == self.pressed_actor then
            self:hideUnitInfo()
        else
            self:showUnitInfo(self.pressed_actor)
        end
    else
        -- Клик по пустому месту — закрыть попап
        self:hideUnitInfo()
    end

    self.pressed_actor = nil
    self.drag_started = false
end

-- Логика «положить в тайл / поменять местами / вернуть обратно».
-- tile может быть nil, если отпустили вне карты.
function BattleState:dropActor(tile)
    local actor = self.grabbed_actor
    if not actor then return end

    -- Некуда класть — вернуть на исходный тайл.
    if not tile then
        self:setActorToTile(actor, actor.tile)
        return
    end

    local same_tile   = (tile == actor.tile)
    local is_place    = tile.is_open or same_tile
    local is_swap     = tile.actor and tile.actor.is_player and tile.actor ~= actor

    if not is_place and not is_swap then
        -- Невалидная цель — вернуть на исходный тайл.
        self:setActorToTile(actor, actor.tile)
        return
    end

    if is_place then
        -- Проверяем лимиты по слотам.
        if tile.spare then
            if self.player:getLen('spare') >= self.player.charactersSpareSize then
                self:setActorToTile(actor, actor.tile)
                return
            end
        else
            if self.player:getLen('active') >= self.player.charactersActiveSize then
                self:setActorToTile(actor, actor.tile)
                return
            end
        end

        actor.tile.is_open = true
        actor.tile:change_color()
        self:setActorToTile(actor, tile)
        PlaySound(ButtonClickSound)
    elseif is_swap then
        local tile_actor   = tile.actor
        local grabbed_tile = actor.tile
        self.player:removeCharacter(tile_actor.character)
        self:setActorToTile(actor, tile)
        self:setActorToTile(tile_actor, grabbed_tile)
        tile_actor.show_name = false
        PlaySound(ButtonClickSound)
    end
end

-- Окно характеристик юнита (ЛКМ)
function BattleState:showUnitInfo(unit)
    if not unit then return end
    self.info_unit = unit
end

function BattleState:hideUnitInfo()
    self.info_unit = nil
end

-- Хук на одиночный клик по юниту в фазе подготовки.
function BattleState:onPrepareUnitClick(actor)
    self:showUnitInfo(actor)
end

-- Отмена drag (например, по Escape) — вернуть юнита на исходный тайл.
function BattleState:cancelPrepareDrag()
    if self.grabbed_actor then
        self:setActorToTile(self.grabbed_actor, self.grabbed_actor.tile)
        self.grabbed_actor = nil
        self.map.highlighted = nil
    end
    self.pressed_actor = nil
    self.drag_started  = false
end

function BattleState:grabActor(tile)
    if not tile then return end
    if self.grabbed_actor then
        if tile.is_open or tile == self.grabbed_actor.tile then
            if tile.spare then
                if self.player:getLen('spare') >= self.player.charactersSpareSize then return end
            else
                if self.player:getLen('active') >= self.player.charactersActiveSize then return end
            end
            self.grabbed_actor.tile.is_open = true
            self.grabbed_actor.tile:change_color()
            self:setActorToTile(self.grabbed_actor, tile)
            self.grabbed_actor = nil
            self.map.highlighted = nil
            PlaySound(ButtonClickSound)
        elseif tile.actor and tile.actor.is_player then
            local tile_actor = tile.actor
            local grabbed_tile = self.grabbed_actor.tile
            self.player:removeCharacter(tile_actor.character)
            self:setActorToTile(self.grabbed_actor, tile)
            self:setActorToTile(tile_actor, grabbed_tile)
            tile_actor.show_name = false
            self.grabbed_actor = nil
            self.map.highlighted = nil
            PlaySound(ButtonClickSound)
        end
    elseif tile.actor and tile.actor.is_player then
        self.grabbed_actor = tile.actor
        self.player:removeCharacter(tile.actor.character)
        PlaySound(ButtonClickSound)
    end
end

function BattleState:setActorToTile(actor, tile)
    local old_tile = actor.tile
    actor:set_tile(tile)
    actor.x = tile.x
    actor.y = tile.y + UNIT_ALIVE_OFFSET
    actor.character.prepare_x = tile.tx
    actor.character.prepare_y = tile.ty
    tile.is_open = false
    if not tile.spare then
        if not self.queue:actor_exists(actor) then
            self.queue:add_actor(actor)
        end
        self.player:addCharacterTo(actor.character, 'active')
    else
        self.queue:remove_actor(actor)
        self.player:addCharacterTo(actor.character, 'spare')
    end
    actor.spare = tile.spare
end

-- --- Основные циклы ---

function BattleState:update(dt)
    self.queue:update(dt)
    if not self.paused then
        self:handle_action(dt)
    end

    self.map:update(dt)
    table.sort(self.objects, function(a, b) return a.y < b.y end)
    for i, object in ipairs(self.objects) do
        object:update(dt)
        if object.toRemove then
            table.remove(self.objects, i)
        end
    end
    self.inventory:update(dt)
    self.panel:update(dt)

    -- Подготовительная фаза (только UI)
    if self.state == 'prepare' then
        self.ui:updatePrepare(dt)
        
        if self.grabbed_actor then
            self.grabbed_actor.x, self.grabbed_actor.y = love.mouse.getPosition()
        end
    end

    -- Результат и награды
    if self.state == 'result' or self.state == 'rewards' then
        self.ui:updateResult(dt)
    end
    
    self.ui:updateExtraActionButton(self)

    -- Тряска
    local speed = 7
    self.shaking = math.lerp(self.shaking, 0, speed * dt)
end

function BattleState:draw()
    love.graphics.push()
    love.graphics.translate((math.random() - 0.5) * self.shaking, (math.random() - 0.5) * self.shaking / 2)

    local size = 1.3
    local sprite_width = self.background.w * size
    self.background:draw(_, love.graphics.getWidth() / 2 - sprite_width / 2, -260, 0, size, 1)

    self.map:draw()
    for _, object in ipairs(self.objects) do
        object:draw()
    end
    local current_action = self:current_action()
    if current_action then
        current_action:draw()
    end
    love.graphics.pop()

    -- UI (лог, награды, инвентарь, очередь)
    self.queue:draw()
    self.inventory:draw()
    self.ui:draw(self)   -- передаём self для доступа к данным

    -- Отображение текущего заклинания
    if self.current_spell then
        local w, h = self.inventory.w, self.inventory.h
        local x, y = self.inventory.x + w + 10, self.inventory.y
        local text = 'Casting: ' .. self.current_spell.name
        local textW = font:getWidth(text)
        local textH = font:getHeight(text)
        local padding = 4
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle('fill', x, y, textW + padding * 2, textH + padding * 2)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle('line', x, y, textW + padding * 2, textH + padding * 2)
        love.graphics.setFont(font)
        PrintText(text, x + padding, y + padding)
    end

    love.graphics.print(self.phase, 0, 0)
end

-- --- Обработка ввода (делегируется) ---

function BattleState:mousepressed(x, y, button)
    self.input:mousepressed(x, y, button)
end

function BattleState:mousereleased(x, y, button)
    self.input:mousereleased(x, y, button)
end

function BattleState:mousemoved(x, y, dx, dy)
    self.input:mousemoved(x, y, dx, dy)
end

function BattleState:keypressed(key, scancode, isrepeat)
    if key == 'escape' then
        if self.info_unit then
            self:hideUnitInfo()
            return
        end
        if self.state == 'prepare' and self.drag_started then
            self:cancelPrepareDrag()
            return
        end
    end
    self.input:keypressed(key, scancode, isrepeat)
end

return BattleState