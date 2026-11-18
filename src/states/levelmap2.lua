local RunState              = require 'src.states.run_state'
local SaveManager           = require 'src.save_manager'
local gen                   = require 'src.levelgenerator'

local Player                = require 'src.player'
local Node                  = require 'src.node'
local Events                = require 'src.events'
local MapRenderer           = require 'src.map_renderer'
local CharacterSelectScreen = require 'src.character_select_screen'
local UpgradeSelectScreen   = require 'src.upgrade_select_screen'
local Stats                 = require 'src.stats'
local Path                  = MapRenderer.Path
local StoryPlacement        = require 'src.story.story_placement'
local PlayerMetaStory       = require 'src.player_meta_story'
local MasterGenerator       = require 'data.story.generators.master_generator'

local MAP_WIDTH      = 1200
local MAP_HEIGHT     = 700
-- Камера карты.
local ZOOM_MIN       = 0.35   -- насколько карту можно отдалить
local ZOOM_MAX       = 2.5    -- и приблизить
local ZOOM_STEP      = 1.12   -- множитель на одно деление колеса
-- Сдвиг мыши на нажатой ЛКМ меньше этого (в пикселях) считается кликом, а не
-- перетаскиванием. Иначе ноды не выбирались бы: UI отпускает кнопку только
-- если курсор ещё внутри нода.
local DRAG_THRESHOLD = 4
-- На сколько карта должна выйти за экран, чтобы её можно было утащить за край.
local PAN_EDGE_SLACK = 80

-- Вступительная анимация камеры при первом заходе на карту в забеге.
local INTRO_DELAY   = 0.4    -- сколько секунд показать карту целиком
local INTRO_TIME    = 1.6  -- длительность полёта к начальному ноду
local INTRO_ZOOM    = 1.2  -- во сколько раз приблизиться по дороге
-- Поля вокруг карты при вписывании её в экран, px.
local MAP_MARGIN    = 40

---@class Levelmap
local Levelmap = {}

function Levelmap:init()
    self.nodes         = {}
    self.pathes        = {}
    self.currentNode   = nil
    self.active        = false
    self.mapRenderer   = MapRenderer()
    self.seed          = nil

    -- Панорамирование: ЛКМ, зажатая на пустом месте карты.
    self.panning       = false
    self.panMoved      = false
    self.panLastX      = 0
    self.panLastY      = 0
    self.panStartX     = 0
    self.panStartY     = 0

    -- Вступительный полёт камеры к начальному ноду.
    self.camIntro      = nil
    self.introSeen     = false
    self.dragSkippedIntro = false
end

-- ================================================================
-- Enter / leave
-- ================================================================

function Levelmap:enter(from, args)
    self.active = true
    self.camIntro = nil

    -- ---- Загрузка из сейва ----
    if args.load_from_save then
        self.player = args.player
        self:deserialize(args.save_data)
        -- Вид по центру. Вступление при загрузке не играем: карта уже
        -- знакома, а начальный нод давно пройден.
        self.introSeen = true
        self:_layoutView()
        return
    end

    -- ---- Новая игра ----
    self.nodes = {}
    self.pathes = {}
    self.currentNode = nil

    if args.player then
        self.player = args.player
    else
        self.player = Player()
        self.player:addCharacter(args.character, true)
        self.player:addCharacter(args.character2, true)
        self.player:addItem('healPotion', 2)
        self.player:addItem('energyPotion', 2)
        self.player:addCurrency('gold', 100)
    end

    -- Seed для воспроизводимости (единый источник — RunState)
    RunState:reset(self.player, args.seed)
    self.seed = RunState:getSeed()

    -- Кампания мета-прогресса (мастера, соперник) живёт дольше забега
    -- и нужна до раскладки сцен.
    self:_ensure_campaign()

    -- Генерация детерминирована: math.randomseed + _generateMap подряд,
    -- без посторонних вызовов math.random между ними.
    math.randomseed(self.seed)
    self:_generateMap()

    -- Раскладка активной сюжетной нити поверх готовой карты.
    -- Нет нити — забег остаётся обычным roguelite-забегом.
    self:_place_story()

    -- Новый забег: карта целиком по центру, затем камера наводится на
    -- начальный нод. introSeen живёт в сейве: это «первый заход в этот
    -- забег», а не «первый запуск игры».
    self:_layoutView()
    if not self.introSeen then
        self:_startCameraIntro(self.currentNode)
    end

    self:_saveGame()
end

-- Кампания мета-прогресса: мастера и соперник генерируются один раз
-- на сейв и не перегенерируются между забегами.
function Levelmap:_ensure_campaign()
    local meta = self.player and self.player.meta_story
    if not meta then return end

    local okMaster, MasterGenerator = pcall(require, 'data.story.generators.master_generator')
    if okMaster and MasterGenerator then
        MasterGenerator.ensure_campaign(meta)
    end

    local okRival, RivalGenerator = pcall(require, 'data.story.generators.rival_generator')
    if okRival and RivalGenerator then
        RivalGenerator.ensure(meta, self.player)
    end
end

-- Ставит сцены активной нити на карту. Сюжет — надстройка, поэтому
-- любая ошибка раскладки логируется, но забег не ломает.
function Levelmap:_place_story()
    local PlayerMetaStory = require 'src.player_meta_story'
    local meta = self.player and self.player.meta_story
    if meta then
        PlayerMetaStory.begin_new_run(meta)
    end

    -- One select() per run: it pins active_thread and bumps total_runs, so a
    -- second call would return a forced continuation. select() also builds the
    -- graph, which place() reuses instead of rebuilding.
    local ok, result = pcall(function()
        local ThreadGenerator = require 'src.story.thread_generator'
        local Threads         = require 'data.story.threads'
        local thread, _, graph = ThreadGenerator.select(self.player, RunState, Threads)
        if not thread or not graph then return nil end
        return StoryPlacement.place(self, self.player, RunState,
            { thread = thread, graph = graph })
    end)
    if not ok then
        print('[story] placement failed: ' .. tostring(result))
        self.story = nil
        return
    end
    self.story = result
end

-- Сдвигает указатель сюжетной нити после проигранной сцены.
-- Если узел линейный (есть .next) — идём дальше; если граф закончился —
-- закрываем нить через её on_complete.
function Levelmap:_advance_story(node)
    if not node or not node.story_id then return end

    local okRunner, SceneRunner = pcall(require, 'src.story.scene_runner')
    if not okRunner or not SceneRunner then return end

    if not RunState.story then return end

    RunState.story.node_id = node.story_id

    local moved = SceneRunner.advance(RunState)
    -- on_complete fires only when the thread has nowhere left to go. `not moved`
    -- alone is not enough: branch nodes (crossroads) have no .next, so advance
    -- returns false while the thread is still very much in progress — using OR
    -- marked the master defeated at the crossroads, before the boss fight.
    if not moved and SceneRunner.is_terminal(RunState) then
        local okThread, thread = pcall(function()
            return require('data.story.threads')[RunState.story.thread_id]
        end)
        if okThread and thread and thread.on_complete then
            pcall(thread.on_complete, self.player.meta_story, RunState.story.thread_state)
        end
    end
end

-- Закрытие сюжетного узла. Обычная сцена просто отмечается пройденной,
-- а узел босса-мастера вместо этого запускает бой: нить двигаем только
-- после его исхода.
function Levelmap:_handle_story_node_complete(node)
    -- Ключ, который открыл эту сцену, израсходован.
    if node.requires and node.requires.story_key then
        PlayerMetaStory.consume_story_key(
            self.player.meta_story, node.requires.story_key)
    end

    if node.is_master_boss then
        local master = MasterGenerator.current(self.player.meta_story)
        if not master then
            -- Без мастера бой не собрать, но и узел не оставляем висеть.
            node.isCompleted = true
            self:_saveGame()
            return
        end

        local enraged = RunState.story and RunState.story.flags
                        and RunState.story.flags.boss_enraged

        self.active = false
        Gamestate.push(BattleState, {
            player  = self.player,
            node    = node,
            master  = master,
            enraged = enraged or false,
        })

        -- Нарочно: узел НЕ завершаем и нить НЕ двигаем. Исход боя решается
        -- в _handle_master_victory / _handle_master_defeat.
        return
    end

    node.isCompleted = true
    self:_advance_story(node)
    self:_saveGame()
end

-- Победа над мастером: узел закрыт, нить двигается (на терминальном узле
-- это поднимает thread.on_complete -> MasterGenerator.on_victory).
function Levelmap:_handle_master_victory(node)
    node.isCompleted = true
    self:_advance_story(node)
    self:_saveGame()
    self.currentNode = nil
    if self.cancel_target_mode then self:cancel_target_mode() end
end

-- Поражение от мастера: мастер запоминает попытку, жизни кончаются.
function Levelmap:_handle_master_defeat(node)
    -- Нить ищем так же, как _advance_story: через RunState.story.thread_id
    -- и реестр data.story.threads.
    local thread
    if RunState.story then
        local okThread, found = pcall(function()
            return require('data.story.threads')[RunState.story.thread_id]
        end)
        if okThread then thread = found end
    end

    if thread and thread.on_fail then
        thread.on_fail(self.player.meta_story,
            RunState.story and RunState.story.thread_state)
    end

    self.player.lives = 0
    self:_handle_run_failed()
end

-- Жизни кончились — выход с карты тем же путём, что и в resume.
function Levelmap:_handle_run_failed()
    self.active = false
    self.currentNode = nil
    Gamestate.pop()
    if self.cancel_target_mode then self:cancel_target_mode() end
end

function Levelmap:leave()
    self.active = false
    FieldMusic:stop()
end

function Levelmap:isActive()
    return self.active
end

-- ================================================================
-- Генерация карты (вынесено из enter)
-- ================================================================

function Levelmap:_generateMap()
    self.generator = gen()
    self.generator:generate(170, MAP_WIDTH, MAP_HEIGHT)

    for _, edge in ipairs(self.generator.edges) do
        local path = Path(edge)
        table.insert(self.pathes, path)
        edge.path = path
    end

    local startPoint = self.generator.startPoint
    local endPoint   = self.generator.endPoint
    local rest_nodes = 0
    local shop_nodes = 0

    local max_event_nodes   = math.floor(#self.generator.points * 0.30)
    local event_nodes       = 0
    local max_trainer_nodes = math.floor(#self.generator.points * 0.35)
    local trainer_nodes     = 0

    -- Детерминированный порядок Events (иначе pairs() даёт разный порядок
    -- при регенерации, и события «съезжают» при загрузке).
    local events = {}
    local event_keys = {}
    for key in pairs(Events) do table.insert(event_keys, key) end
    table.sort(event_keys)
    for _, key in ipairs(event_keys) do table.insert(events, Events[key]) end

    for i, point in ipairs(self.generator.points) do
        local isStartingPoint = point == startPoint
        local isEndingPoint   = point == endPoint

        local ntype = 'wild'
        if isStartingPoint then
            ntype = 'wild'
        elseif isEndingPoint then
            ntype = 'end'
        else
            local startNeighbor = self.generator:isNeighbors(point, startPoint)
            local endNeighbor   = self.generator:isNeighbors(point, endPoint)
            local rand = math.random() * 100
            if not startNeighbor and not endNeighbor and rest_nodes < 1 then
                ntype = 'rest'
                rest_nodes = rest_nodes + 1
            elseif not startNeighbor and not endNeighbor and shop_nodes < 1 then
                ntype = 'shop'
                shop_nodes = shop_nodes + 1
            elseif rand <= 35 and event_nodes < max_event_nodes then
                ntype = 'event'
                event_nodes = event_nodes + 1
            elseif rand <= 65 and trainer_nodes < max_trainer_nodes then
                ntype = 'trainer'
                trainer_nodes = trainer_nodes + 1
            end
        end

        local node = Node(i, point.x, point.y,
            isStartingPoint, ntype)
        node.point = point
        node.level = point.cost

        if isStartingPoint then
            self.currentNode = node
            node.enemies_count = 2
        end

        if ntype == 'event' then
            node.event = events[math.random(#events)]
        end

        table.insert(self.nodes, node)
    end

    self.mode          = 'none'
    self.currentAction = nil

    -- Карта пересобрана — вид на неё ставит _layoutView в enter().
    -- mapRenderer может не быть: тесты собирают Levelmap без init().
    if self.mapRenderer then
        self.mapRenderer:resetView()
    end
    self:_resetPan()
end

-- ================================================================
-- Serialization
-- ================================================================

-- Story node fields are saved per node, and only for story nodes, so legacy
-- saves stay compact.
-- Without story fields, deserialize leaves story nodes as generic
-- event nodes because _place_story is not re-run on load (see AGENTS.md).
function Levelmap:serialize()
    local nodeStates = {}
    for i, node in ipairs(self.nodes) do
        local state = {
            isOpen       = node.isOpen       or false,
            isCompleted  = node.isCompleted  or false,
            isDiscovered = node.isDiscovered or false,
        }

        if node.story_scene then
            state.story_id        = node.story_id
            state.story_scene     = node.story_scene
            state.is_master_boss  = node.is_master_boss
            state.is_boss         = node.is_boss
            state.alt_when_locked = node.alt_when_locked
            state.locked_hint     = node.locked_hint
            state.requires        = node.requires
            state.grants          = node.grants
        end

        nodeStates[i] = state
    end

    local pathStates = {}
    for i, path in ipairs(self.pathes) do
        pathStates[i] = {
            isOpen      = path.isOpen      or false,
            isCompleted = path.isCompleted or false,
        }
    end

    return {
        seed       = self.seed,
        -- Вступление камеры играется один раз за забег. Флаг — обычное
        -- скалярное поле (сохраняемое состояние), а не объект камеры.
        introSeen  = self.introSeen or false,
        nodeStates = nodeStates,
        pathStates = pathStates,
    }
end

function Levelmap:deserialize(data)
    self.seed = data.seed
    -- Старые сейвы флага не имеют: считаем вступление уже сыгранным.
    self.introSeen = data.introSeen ~= false

    -- Перегенерируем карту с тем же seed'ом — узлы/типы/события совпадут
    self.nodes       = {}
    self.pathes      = {}
    self.currentNode = nil
    math.randomseed(self.seed)
    self:_generateMap()

    -- Накатываем сохранённые состояния
    for i, state in ipairs(data.nodeStates or {}) do
        local node = self.nodes[i]
        if node then
            node.isOpen       = state.isOpen       or false
            node.isCompleted  = state.isCompleted  or false
            node.isDiscovered = state.isDiscovered or false

            -- Сюжетная личность узла берётся из сейва, а не из повторной
            -- раскладки: _place_story здесь нарочно не вызывается.
            -- Старые сейвы без этих полей остаются как есть.
            if state.story_scene then
                node.story_id        = state.story_id
                node.story_scene     = state.story_scene
                node.is_master_boss  = state.is_master_boss
                node.is_boss         = state.is_boss
                node.alt_when_locked = state.alt_when_locked
                node.locked_hint     = state.locked_hint
                node.requires        = state.requires
                node.grants          = state.grants
                node.type            = 'event'   -- matches StoryPlacement
                node.event           = nil       -- story scenes are not random events
            end
        end
    end

    for i, state in ipairs(data.pathStates or {}) do
        local path = self.pathes[i]
        if path then
            path.isOpen      = state.isOpen      or false
            path.isCompleted = state.isCompleted or false
        end
    end

    self.currentNode = nil
end

-- ================================================================
-- Save
-- ================================================================

function Levelmap:_saveGame()
    SaveManager.save(self.player, RunState, self, 'levelmap')
end

-- ================================================================
-- Resume (возврат из другого state)
-- ================================================================

function Levelmap:resume(from, args)
    if from == FadeInState or from == FadeOutState then return end

    -- Если currentNode нет — мы вернулись из модалки внутри Levelmap,
    -- нечего сохранять.
    if not self.currentNode then return end

    self:openNeighborNodes(self.currentNode)

    if from == BattleState then
        -- Бой с мастером: исход решают обработчики, узел закрывает только
        -- победа. Раньше узел отмечался пройденным здесь, до проверки
        -- результата.
        if self.currentNode.is_master_boss then
            if args.result == 'lose' then
                self:_handle_master_defeat(self.currentNode)
            else
                self:_handle_master_victory(self.currentNode)
            end
            return
        end

        self.currentNode.isCompleted = true

        if args.result == 'lose' then
            self.player.lives = self.player.lives - 1
            if self.player.lives <= 0 then
                Gamestate.pop()
                return
            end
            self:_saveGame()
        else
            RunState:tickBattleModifiers()
            -- Сохраняем ПОСЛЕ выбора апгрейда, иначе при загрузке
            -- игрок останется без выбранного улучшения.
            UpgradeSelectScreen:open(self.player, nil, function()
                self:_saveGame()
            end)
        end

    elseif from == RestState then
        self.currentNode.isCompleted = true
        self:_saveGame()

    elseif from == ShopState then
        self.currentNode.isCompleted = true
        self:_saveGame()

    elseif from == EventState then
        -- Сюжетный узел идёт через свой обработчик: он решает, закрыть узел
        -- и сдвинуть нить (обычная сцена) или запустить бой (босс мастера).
        if self.currentNode.story_scene then
            self:_handle_story_node_complete(self.currentNode)
        else
            self.currentNode.isCompleted = true
            self:_saveGame()
        end

    else
        self.currentNode.isCompleted = true
        self:_saveGame()
    end

    self.currentNode = nil
    self:cancel_target_mode()
end

-- ================================================================
-- Навигация
-- ================================================================

function Levelmap:openNeighborNodes(node)
    if not node then return end
    local currentPoint = node.point

    for _, other in ipairs(self.nodes) do
        local point = other.point
        local isNeighbors, edge = self.generator:isNeighbors(currentPoint, point)
        if isNeighbors then
            if not other.isCompleted then
                other.isOpen       = true
                other.isDiscovered = true
                edge.path.isOpen   = true
            end
        end
    end
    node.isOpen = false
end

function Levelmap:set_target_mode(spell)
    self.mode = 'target'
end

function Levelmap:cancel_target_mode()
    self.mode = 'none'
end

-- ================================================================
-- Камера: зум колесом и панорамирование ЛКМ по пустому месту
-- ================================================================

-- Модальные окна карты (выбор апгрейда, выбор существа) перекрывают её
-- целиком и сами ловят мышь.
function Levelmap:_isModalOpen()
    return (UpgradeSelectScreen and UpgradeSelectScreen:isActive())
        or (CharacterSelectScreen and CharacterSelectScreen:isActive())
end

function Levelmap:_resetPan()
    self.panning   = false
    self.panMoved  = false
    self.panLastX  = 0
    self.panLastY  = 0
end

-- Экранная точка под курсором и в каком узле он сейчас лежит.
-- Ноды в мировых координатах, курсор — в экранных, поэтому и считаем через
-- камеру, а не через node.cursorInside (его обновляет Node:update).
function Levelmap:_nodeAtScreen(sx, sy)
    local wx, wy = self.mapRenderer:toWorld(sx, sy)
    local scale  = self.mapRenderer.scale

    for _, node in ipairs(self.nodes) do
        local dx, dy = node.x - wx, node.y - wy
        local radius = node.radius * scale
        if dx * dx + dy * dy <= radius * radius then
            return node
        end
    end
    return nil
end

-- Отступ при ограничении панорамирования: не даём крайним нодам целиком
-- уехать за экран.
local PAN_PADDING = 25

-- Нажатие ЛКМ на пустом месте карты начинает панорамирование.
function Levelmap:_beginPan(x, y)
    self.panning   = true
    self.panMoved  = false
    self.panLastX  = x
    self.panLastY  = y
    self.panStartX = x
    self.panStartY = y
end

-- Двигает камеру за курсором. Пока сдвиг меньше порога, это ещё не
-- перетаскивание: ноды продолжают реагировать как на обычный клик.
function Levelmap:_updatePan(x, y)
    if not self.panning then return end

    local dx, dy = x - self.panLastX, y - self.panLastY
    if dx == 0 and dy == 0 then return end

    self.panLastX, self.panLastY = x, y

    if not self.panMoved then
        local startX = self.panStartX or x
        local startY = self.panStartY or y
        local total = (x - startX) ^ 2 + (y - startY) ^ 2
        if total < DRAG_THRESHOLD * DRAG_THRESHOLD then
            return
        end
        self.panMoved = true
    end

    self.mapRenderer:pan(dx, dy)
    self:_clampPan()
end

-- Не даёт утащить карту целиком за край экрана: хотя бы часть карты всегда
-- остаётся видимой.
function Levelmap:_clampPan()
    local minX, minY, maxX, maxY = self:_mapBounds()
    if not minX then return end

    local mr = self.mapRenderer
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

    -- Экранные координаты крайних точек карты:
    --   left = minX * scale + view, right = maxX * scale + view.
    -- Допустимо: left не правее (w + margin) и right не левее (-margin).
    -- Иначе карта уехала за экран целиком.
    local function clampAxis(view, lo, hi, screenSize)
        local margin  = PAN_EDGE_SLACK
        local maxView = screenSize + margin - lo * mr.scale - PAN_PADDING
        local minView = -hi * mr.scale - margin + PAN_PADDING
        if minView > maxView then
            -- Карта мельче видимой области: центр вида держим по центру,
            -- но смещение всё равно ограничено, чтобы она не «прыгала».
            local center = (maxView + minView) / 2
            local slack  = (maxView - minView) / 2
            return math.min(math.max(view, center - slack), center + slack)
        end
        return math.min(math.max(view, minView), maxView)
    end

    mr.viewX = clampAxis(mr.viewX, minX, maxX, w)
    mr.viewY = clampAxis(mr.viewY, minY, maxY, h)
end

-- Колесо мыши: зум карты (узлы, пути, подписи) вокруг курсора.
function Levelmap:wheelmoved(x, y)
    -- Любое осмысленное действие мышью забирает камеру у вступления.
    self:_endIntro()

    if not self:isActive() then return end
    if self:_isModalOpen() then return end

    local wheel = y or x
    if not wheel or wheel == 0 then return end

    local mx, my = love.mouse.getPosition()
    local factor = wheel > 0 and ZOOM_STEP or (1 / ZOOM_STEP)
    self.mapRenderer:zoomAt(mx, my, factor, ZOOM_MIN, ZOOM_MAX)
    self:_clampPan()
end

-- ================================================================
-- Кадрирование карты: стартовый вид и вступительный полёт
-- ================================================================
--
-- Состояние вида — тройка (scale, viewX, viewY). Стартовый вид и полёт
-- описывают только (scale, centerX, centerY) — центр вида в мировых
-- координатах; в viewX/viewY он переводится в самом конце (_applyView).
-- Так зум и сдвиг не конфликтуют: оба меняют scale и center независимо.

-- Границы карты по узлам: minX, minY, maxX, maxY. nil для пустой карты.
function Levelmap:_mapBounds()
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    for _, node in ipairs(self.nodes) do
        minX, maxX = math.min(minX, node.x), math.max(maxX, node.x)
        minY, maxY = math.min(minY, node.y), math.max(maxY, node.y)
    end
    if minX > maxX then return nil end
    return minX, minY, maxX, maxY
end

-- Область экрана, реально видимая под HUD.
-- MAP_AREA — необязательная настройка вида { x, y, w, h } в долях экрана
-- (например, оставить поля под сердца/таблички). По умолчанию — весь экран.
function Levelmap:_mapArea()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local area = MAP_AREA or {}
    return (area.x or 0) * w, (area.y or 0) * h,
           w * (area.w or 1), h * (area.h or 1)
end

-- Текущий центр вида в мировых координатах.
function Levelmap:_viewCenter()
    local ax, ay, aw, ah = self:_mapArea()
    local mr = self.mapRenderer
    return (ax + aw / 2 - mr.viewX) / mr.scale,
           (ay + ah / 2 - mr.viewY) / mr.scale
end

-- Ставит вид по (scale, center). Ограничения вида сюда НЕ применяются:
-- и стартовый кадр, и полёт считают переход от самих себя, а не от
-- зажатого на каждом кадре вида. Иначе полёт застревал бы на границе
-- (шаг от текущей позиции каждый раз отсекается) и не долетал до цели.
-- Посторонний ввод ограничивает вид обычным _clampPan.
function Levelmap:_applyView(scale, cx, cy)
    local mr = self.mapRenderer
    local ax, ay, aw, ah = self:_mapArea()

    mr.scale = math.min(math.max(scale, ZOOM_MIN), ZOOM_MAX)
    mr.viewX = ax + aw / 2 - cx * mr.scale
    mr.viewY = ay + ah / 2 - cy * mr.scale
end

-- Стартовый вид: вся карта по центру видимой области.
--   * влезает в экран  — 1:1 по центру;
--   * не влезает       — вписываем с полями.
function Levelmap:_frameOverview()
    local b = { self:_mapBounds() }
    if #b == 0 then
        self:_applyView(1, 0, 0)
        return
    end

    local margin = MAP_MARGIN
    local mapW = (b[3] - b[1]) + margin * 2
    local mapH = (b[4] - b[2]) + margin * 2
    local _, _, aw, ah = self:_mapArea()

    local scale = math.min(aw / mapW, ah / mapH, 1)
    self:_applyView(scale, (b[1] + b[3]) / 2, (b[2] + b[4]) / 2)
end

-- Ставит стартовый вид под текущий размер экрана.
function Levelmap:_layoutView()
    self:_frameOverview()
end

-- Итоговый центр вступления: начальный нод, но центр вида не выходит за
-- границы самой карты. Нод у края карты поэтому доводит камеру до края
-- карты и не утаскивает кадр в угол экрана; _clampPan при этом ничего не
-- сдвигает, и полёт доходит до цели ровно.
function Levelmap:_introTarget(nodeX, nodeY)
    local minX, minY, maxX, maxY = self:_mapBounds()
    if not minX then return nodeX, nodeY end

    return math.min(math.max(nodeX, minX), maxX),
           math.min(math.max(nodeY, minY), maxY)
end

-- Начало вступления: запоминаем стартовый вид, а цели полёта считаем
-- один раз от него (а не от текущего вида на каждом кадре).
function Levelmap:_startCameraIntro(node)
    self.camIntro = nil
    if not node then return end

    local fromScale = self.mapRenderer.scale
    local fromCX, fromCY = self:_viewCenter()

    -- Приближается к начальному ноду, но всего карту в один нод не
    -- превращает.
    local toScale = math.min(fromScale * INTRO_ZOOM, ZOOM_MAX)
    local toCX, toCY = self:_introTarget(node.x, node.y)

    self.camIntro = {
        t         = 0,
        fromScale = fromScale,
        fromCX    = fromCX,
        fromCY    = fromCY,
        toScale   = toScale,
        toCX      = toCX,
        toCY      = toCY,
    }
end

-- Кадр вступления. Возвращает true, пока камера в движении: на это время
-- клики по карте не проходят (случайное нажатие не «выберет» нод).
function Levelmap:_updateIntro(dt)
    local intro = self.camIntro
    if not intro then return false end

    intro.t = intro.t + dt

    if intro.t < INTRO_DELAY then
        return true   -- карта показана целиком, полёт ещё не начался
    end

    local k = math.min((intro.t - INTRO_DELAY) / INTRO_TIME, 1)
    local e = k * k * (3 - 2 * k)   -- smoothstep: плавные начало и конец

    self:_applyView(
        math.lerp(intro.fromScale, intro.toScale, e),
        math.lerp(intro.fromCX, intro.toCX, e),
        math.lerp(intro.fromCY, intro.toCY, e))

    if k >= 1 then
        self:_endIntro()
        return false
    end
    return true
end

-- Обрывает вступление там, где камера сейчас: дальше управляет игрок.
function Levelmap:_endIntro()
    if not self.camIntro then return end
    self.camIntro  = nil
    self.introSeen = true
end

-- ================================================================
-- Update / draw / input
-- ================================================================

function Levelmap:update(dt)
    if self.active then
        self:_updateIntro(dt)

        local mx, my = love.mouse.getPosition()
        if self.panning then
            if love.mouse.isDown(1) then
                self:_updatePan(mx, my)
            else
                self:_resetPan()
            end
        end
    end

    for _, node in ipairs(self.nodes) do
        node:update(dt)
    end
end

function Levelmap:_camp()
    for _, c in ipairs(self.player.charactersActive) do
        if c then
            local stats  = Stats(c, RunState:getModifiers(), {})
            local max_hp = stats:get('max_health')
            local max_en = stats:get('max_energy')
            c.health = math.min(max_hp, c.health + max_hp * 0.3)
            c.energy = math.min(max_en, c.energy + max_en * 0.3)
        end
    end
    for _, c in ipairs(self.player.charactersSpare) do
        if c then
            local stats  = Stats(c, RunState:getModifiers(), {})
            local max_hp = stats:get('max_health')
            local max_en = stats:get('max_energy')
            c.health = math.min(max_hp, c.health + max_hp * 0.3)
            c.energy = math.min(max_en, c.energy + max_en * 0.3)
        end
    end
    PlaySound(ButtonClickSound)
    Tagtext:add("+30% HP/EN", 120, 90, 2, 40, { 0.5, 1, 0.5, 1 })
end

local font = love.graphics.newFont(18)
function Levelmap:draw()
    if not self:isActive() then return end

    self.mapRenderer:draw(self.pathes, self.nodes)
    UpgradeSelectScreen:draw()
    self.player:drawLives()
    
    if RunState:hasUnlock('camp_once') then
        UI.setStyle({
            draw_border      = true,
            border_color     = { 0, 0, 0, 1 },
            background_color = { 0.35, 0.55, 0.35, 1 },
            corner_radius    = 6,
        })
        UI.setFont(font)
        UI.nextPosition("BOTTOMRIGHT", "root")
        if UI.button("levelmap_camp", -20, -20, 180, 44, "Camp (once)", "BOTTOMRIGHT") then
            if RunState:consumeUnlock('camp_once') then
                self:_camp()
                self:_saveGame()
            end
        end
    end
end

function Levelmap:mousepressed(x, y, button)
    if self:_isModalOpen() then return end
    if button ~= 1 then return end

    -- Во время вступления карта движется сама. Клик по карте его
    -- пропускает, но не выбирает нод: под курсором в этот момент может
    -- оказаться что угодно.
    if self.camIntro then
        self:_endIntro()
        self.dragSkippedIntro = { x = x, y = y }
        return
    end

    -- Пустое место карты: ни нод, ни кликабельного элемента интерфейса
    -- (кнопка Camp, сердца, подписи) — начинаем панорамирование.
    -- Хитбоксы UI — это последний отрисованный кадр, а он всегда есть:
    -- mousepressed приходит уже после первого draw.
    if self:_nodeAtScreen(x, y) then return end
    if UI.isOverInteractive and UI.isOverInteractive(x, y) then return end

    self:_beginPan(x, y)
end

function Levelmap:mousemoved(x, y)
    -- Клик во время вступления только остановил камеру (camIntro уже nil).
    -- Если мышь ведут, не отпуская ЛКМ, — это перетаскивание карты, а не
    -- нажатие. Точкой начала берём место клика: _beginPan иначе записал бы
    -- текущую точку и потерял сдвиг.
    if self.dragSkippedIntro then
        local skipX, skipY = self.dragSkippedIntro.x, self.dragSkippedIntro.y
        self.dragSkippedIntro = false
        self:_beginPan(x, y)
        self.panStartX, self.panStartY = skipX, skipY
        return
    end

    if not self.panning then return end
    self:_updatePan(x, y)
end

function Levelmap:mousereleased(x, y, button)
    if button ~= 1 then return end
    self.dragSkippedIntro = false
    if not self.panning then return end

    self:_updatePan(x, y)
    self:_resetPan()
end

function Levelmap:keypressed(key)
    if key == "f3" and not UpgradeSelectScreen:isActive() then
        UpgradeSelectScreen:open(self.player)
    elseif key == "home" then
        -- Возврат к виду по умолчанию: вся карта по центру.
        self:_endIntro()
        self:_frameOverview()
    end
end

return Levelmap