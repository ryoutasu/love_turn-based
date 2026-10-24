-- Модуль-хелпер для Player.meta_story. Хранит мета-состояние кампании,
-- которое переживает вылазки: мастера, соперник, активная нить,
-- persistent-ключи, key_threads.
--
-- Сериализуется целиком (только данные, без функций).

local PlayerMetaStory = {}

local VERSION = 1
local DEFAULT_MASTERS_REQUIRED    = 8
local DEFAULT_CHAMPIONS_REQUIRED  = 4

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

local function default_seed()
    if love and love.math and love.math.random then
        return love.math.random(1, 2147483646)
    end
    return math.random(1, 2147483646)
end

function PlayerMetaStory.create(seed)
    seed = seed or default_seed()
    return {
        version = VERSION,
        campaign_seed = seed,

        -- progression
        phase = 'dojo',                  -- 'dojo' | 'tournament' | 'champion'
        masters_required    = DEFAULT_MASTERS_REQUIRED,
        masters_defeated    = 0,
        champions_required  = DEFAULT_CHAMPIONS_REQUIRED,
        champions_defeated  = 0,
        current_master_id   = nil,       -- заполняется в MasterGenerator.ensure_campaign

        -- masters: [id] = generated master object (см. master_generator.lua)
        masters = {},

        -- rival: генерируется лениво (rival_generator.lua)
        rival = nil,

        -- активная нить (переживает поражение, пока не завершена)
        -- { id, params, started_run }
        active_thread = nil,

        -- persistent keys (cross-run)
        persistent_keys = {},            -- [key] = true
        key_threads     = {},            -- [key] = { giver_scene, payoff_scene,
                                         --              locked_hint, giver_placed_run,
                                         --              payoff_consumed }

        -- активные lore-нити (засеяны, но не завершены)
        threads = {},                    -- [thread_id] = { state, stage, data }

        completed_threads = {},
        total_runs        = 0,
        runs_since_story  = 0,
    }
end

local function ensure_field(t, k, default)
    if t[k] == nil then t[k] = default end
end

-- Восстановление из сейва. Толерантно к старым сейвам без meta_story.
function PlayerMetaStory.deserialize(data)
    if type(data) ~= 'table' then
        return PlayerMetaStory.create()
    end

    ensure_field(data, 'version', VERSION)
    ensure_field(data, 'campaign_seed', default_seed())
    ensure_field(data, 'phase', 'dojo')
    ensure_field(data, 'masters_required', DEFAULT_MASTERS_REQUIRED)
    ensure_field(data, 'masters_defeated', 0)
    ensure_field(data, 'champions_required', DEFAULT_CHAMPIONS_REQUIRED)
    ensure_field(data, 'champions_defeated', 0)
    ensure_field(data, 'masters', {})
    ensure_field(data, 'persistent_keys', {})
    ensure_field(data, 'key_threads', {})
    ensure_field(data, 'threads', {})
    ensure_field(data, 'completed_threads', {})
    ensure_field(data, 'total_runs', 0)
    ensure_field(data, 'runs_since_story', 0)

    return data
end

-- Сериализация — identity, всё и так чистые данные.
-- Оставлено как точка расширения (например, для миграций).
function PlayerMetaStory.serialize(meta)
    return meta
end

-- ---------------------------------------------------------------------------
-- Persistent keys
-- ---------------------------------------------------------------------------

function PlayerMetaStory.has_story_key(meta, key)
    return meta.persistent_keys[key] == true
end

function PlayerMetaStory.grant_story_key(meta, key)
    meta.persistent_keys[key] = true
end

-- Потребление: ключ исчезает, payoff помечается consumed.
function PlayerMetaStory.consume_story_key(meta, key)
    meta.persistent_keys[key] = nil
    if meta.key_threads[key] then
        meta.key_threads[key].payoff_consumed = true
    end
end

-- Регистрация "ружья Чехова": giver-сцена поставлена на карту.
-- Вызывается из levelmap при раскладке сцен.
function PlayerMetaStory.register_key_thread(meta, key, info)
    if meta.key_threads[key] then return end
    meta.key_threads[key] = {
        giver_scene      = info.giver_scene,
        payoff_scene     = info.payoff_scene,
        locked_hint      = info.locked_hint or 'Заперто',
        giver_placed_run = meta.total_runs,
        payoff_consumed  = false,
    }
end

-- Пора ли ставить payoff-узел на карту?
-- Условия: giver был поставлен в ПРОШЛОЙ вылазке, payoff ещё не сработал.
function PlayerMetaStory.key_thread_pending(meta, key)
    local kt = meta.key_threads[key]
    if not kt then return false end
    if kt.payoff_consumed then return false end
    return kt.giver_placed_run < meta.total_runs
end

-- Giver можно ставить повторно, если ключ ещё не взят,
-- payoff ещё не сработал, и прошло >= 2 вылазок с последней постановки.
function PlayerMetaStory.can_replay_giver(meta, key)
    local kt = meta.key_threads[key]
    if not kt then return true end                 -- ещё не было
    if meta.persistent_keys[key] then return false end  -- уже есть ключ
    if kt.payoff_consumed then return false end
    return (meta.total_runs - kt.giver_placed_run) >= 2
end

-- ---------------------------------------------------------------------------
-- Threads
-- ---------------------------------------------------------------------------

function PlayerMetaStory.set_active_thread(meta, thread_id, params)
    meta.active_thread = {
        id          = thread_id,
        params      = params or {},
        started_run = meta.total_runs,
    }
end

function PlayerMetaStory.clear_active_thread(meta)
    meta.active_thread = nil
end

function PlayerMetaStory.mark_thread_complete(meta, thread_id)
    meta.completed_threads[thread_id] = true
    meta.threads[thread_id] = nil
    if meta.active_thread and meta.active_thread.id == thread_id then
        meta.active_thread = nil
    end
end

-- ---------------------------------------------------------------------------
-- Run counter
-- ---------------------------------------------------------------------------

function PlayerMetaStory.begin_new_run(meta)
    meta.total_runs = meta.total_runs + 1
end

function PlayerMetaStory.mark_story_run(meta)
    meta.runs_since_story = 0
end

function PlayerMetaStory.mark_filler_run(meta)
    meta.runs_since_story = meta.runs_since_story + 1
end

return PlayerMetaStory