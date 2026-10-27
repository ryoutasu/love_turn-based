# DumbBeasts Adventures — Техническая спецификация проекта

> Документ для агента, разрабатывающего систему процедурно-генерируемого сюжета. Содержит обзор движка, жанра, ключевых механик, архитектуры и точек расширения.

---

## 1. Движок и стек

| Параметр | Значение |
|---|---|
| Engine | **LÖVE** (Love2D), Lua 5.1 (LuaJIT) |
| Язык | Lua, с самописной системой ООП (`Class{}` — простая реализация через метатаблицы) |
| Разрешение | 1920×1080 (динамическое, привязка к `love.graphics.getWidth/Height`) |
| UI | Самописный модуль `src/ui.lua` — immediate-mode-like, с anchors (TOPLEFT, CENTER, BOTTOMRIGHT…), `nextPosition`, `button`, `text`, `image`, `backdrop`, `bar`, `inputText`. Состояние hover/press/release вычисляется из `love.mouse` в `ui.update(dt)`. |
| Сохранения | `serpent` (serialization), один файл `run.sav` в `love.filesystem.getSaveDirectory()` |
| Аудио | Глобалы: `BattleMusic`, `FieldMusic`, `VictoryMusic`, `IntroMusic`, SFX через `PlaySound(...)` |
| Hot reload | `lurker` + `love.event.quit("restart")` как fallback |

---

## 2. Жанр и ядро игры

**Жанр:** пошаговая тактическая roguelike с коллекционированием существ.

Смешение:
- **Darkest Dungeon** — структура вылазок (граф локаций, забег с ограниченными ресурсами, риск/награда).
- **HOMM3** — гексагональные пошаговые бои с отрядом, инициатива, позиционирование.
- **Pokémon** — коллекционирование существ, атрибуты/элементы, «покедекс».

**Игровой цикл:**
1. Игрок начинает в **TownState** (город) с двумя стартовыми существами.
2. Через `Levelmap` (карта забега) отправляется в поход по узлам: бои, магазины, ивенты, отдых, элиты, босс.
3. Между боями — прокачка, покупки, выбор **улучшений забега** (`RunState`), управление существом в **Stables**.
4. Крафт новых существ за осколки / эссенцию в Town.
5. Смерть при `lives == 0` → возврат в Town, `RunState:reset` при следующем забеге.

**Ключевое отличие:** существ нельзя поймать после боя (механика захвата убрана). Вместо этого — **крафт** по осколкам.

---

## 3. Система существ

### 3.1. Два слоя

- **Character** (`src/character.lua`) — персистентный, хранится в `Player.charactersActive/Spare/Stables`. Содержит: `name`, `sprite_path`, `attribute`, `element`, `health`, `energy`, `modifiers` (permanent), `spells`, `prepare_x/y`.
- **Unit** (`src/objects/unit.lua`) — боевой актор, живёт только в бою. Строится из Character через `Unit(tile, is_player):setup(character, runModifiers)`. Содержит: tile, sprite, shader, `health/energy` (текущие), `status_effects`, `modifiers` (battle scope), `stats` (объект Stats).

### 3.2. Атрибуты (5)

| Атрибут | Роль |
|---|---|
| `wild` | Танк / физический |
| `mystic` | Магия |
| `mechanic` | Конструкты |
| `ancient` | Нейтральный (сильные способности) |
| `chaos` | Нейтральный (непредсказуемые) |

Треугольник: **Wild > Mystic > Mechanic > Wild** (взаимно, ×1.5 / ×0.5).

Ancient и Chaos не «нейтральны» — у них есть собственный обмен, иначе это был бы
бесплатный апгрейд:

| Пара | Множитель | Смысл |
|---|---|---|
| `ancient` → `chaos` | ×1.5 | Ancient пробивает Chaos |
| `ancient` → `wild`/`mystic`/`mechanic` | ×0.75 | Ancient уязвим ко всему обычному |
| `chaos` → `ancient` | ×0.5 | Chaos сопротивляется Ancient |
| `chaos` → обычные | ×1.0 | Chaos нейтрален |

**Осколки (shards)** дропаются по атрибутам убитых врагов → используются для крафта. Пять типов осколков в `Player.shards[attr]`.

> ⚠️ **Контентный пробел:** существа в `src/characters/` сейчас имеют только
> `wild` (7) и `mystic` (7) — ни одного `mechanic`/`ancient`/`chaos`.
> Поэтому осколки этих трёх типов невозможно получить, а targeted-крафт
> для них возвращает `nil`. Чарт уже готов — нужны существа.

### 3.3. Элементы (8)

`ember`, `water`, `earth`, `storm`, `light`, `dark`, `plant` + служебный `neutral`.

Взаимодействия в `data/type_chart.lua` (матрица заполнена полностью, 7×7 + neutral):

| Правило | Множитель |
|---|---|
| Ember > Earth, Plant | ×1.5 |
| Earth > Storm | ×1.5 |
| Storm > Water, Plant | ×1.5 |
| Water > Ember; Plant > Water, Earth | ×1.5 |
| Light ↔ Dark | ×2.0 (взаимно) |
| Своя стихия против своей | ×0.5 |
| `neutral` против чего угодно | ×1.0 |

`neutral` — это «физический» урон заклинаний `claws`, `sand_throw`, `healing`.
Строка и столбец существуют, чтобы горячий путь не проверял `nil`.
**STAB на `neutral` не выдаётся** — иначе любой нейтральный спелл получал бы +50% бесплатно.

**Атрибут × Элемент = два независимых множителя урона** (по модели Digimon).
Максимум без баффов: ×1.5 (атрибут) × ×2.0 (элемент) × ×1.5 (STAB) = **×4.5**.

### 3.4. Урон

`src/damage_calculator.lua` — семь шагов, в этом же порядке:

```
damage = base
       × attr_mul            -- атрибут атакующего vs атрибут цели
       × elem_mul            -- элемент заклинания vs элемент цели
       × stab                -- ×1.5, если элемент совпал с элементом кастера
       × spell_power         -- глобальный и поэлементный (spell_power_ember)
       × (1 - resist_elem)   -- сопротивление цели, кап 75%
       × (1 - armor_reduction)  -- ТОЛЬКО is_attack, кап 75%
       + floor(max_hp × percent_hp_damage)  -- Exhaustion, после брони
```

**Броня** — не вычитание, а насыщающаяся кривая `armor / (armor + K)` при `K = 5`.
Раньше было `base - armor`: при броне 2 и базе 10 это −80%, то есть шаг
«броня 0 → 1 → 2» ломал игру. Теперь при базе 10:

| armor | 0 | 1 | 2 | 3 | 4 | 6 | 10 |
|---|---|---|---|---|---|---|---|
| снижение | 0% | 17% | 29% | 38% | 44% | 55% | 67% |

`K = 5` выбран под фактический диапазон брони в игре (0–3); при `K = 20`
броня 1 давала 5%, и характеристика была незаметной.

`resist_<element>` приходит из модификаторов (`adaptation`), кап 75%.
`percent_hp_damage` (`exhaustion`) добавляется **после** брони и сопротивлений.
`armor_pierce` снижает эффективную броню **до** применения кривой.

Возвращаются две функции:
- `DamageCalculator.calculate(...) -> number` — только итог;
- `DamageCalculator.details(...) -> table` — вся разбивка (`attr_mul`, `elem_mul`,
  `stab`, `resist`, `armor_reduction`, `attr_tier`, `elem_tier`, `total`).
  Используется для цвета всплывающего урона и боевого лога.

`Unit:take_damage(source, damage, is_attack, element, opts)` — `opts.is_spell = true`
включает STAB и `spell_power`; `is_attack = true` включает броню.

> ⚠️ **Заклинания не должны звать `take_damage` напрямую** — только через
> `spellcast:dealDamage(target, amount, element)`. Метод сам подставляет элемент
> и флаг `is_spell`. Прямой вызов без элемента — причина, по которой стихийные
> множители раньше не работали вообще.

---

## 4. Система характеристик и модификаторов

### 4.1. Stats (`src/stats.lua`)

`Stats(character, runModifiers, battleModifiers)`:
- Собирает три списка модификаторов: `character.modifiers` (permanent), `runModifiers` (run-scope), `battleModifiers` (battle-scope).
- `stats:get(name)` — кеширует итоговое значение.
- `stats:invalidate()` — сбрасывает кеш при добавлении/удалении модификатора.
- Операции: `add`, `mul`, `set`. Применяются в порядке: `set > (base + add) × mul`.

Поля: `max_health`, `max_energy`, `damage`, `attack_range`, `move_range`, `initiative`, `armor`.

**База отсутствующего стата не всегда 0.** Это критично:

| Группа | База | Примеры |
|---|---|---|
| Абсолютные | `0` | `max_health`, `damage`, `armor`, `initiative` |
| Множители | `1` | `spell_power`, `spell_power_<elem>` |
| Доли/флаги | `0` | `armor_pierce`, `percent_hp_damage`, `miss_chance`, `resist_<elem>` |

Раньше всё стартовало с `0`, поэтому `mul`-модификатор обнулял стат:
`spell_power = (0 + 0) × 1.15 = 0`. Из-за этого четыре апгрейда на силу
заклинаний не делали ничего. Дефолты заданы в `Stats.DEFAULTS` и
`DYNAMIC_DEFAULTS` (префиксы `spell_power_` / `resist_`).

Дополнительно читаются динамически (не перечислены в `Stats.STATS`, но работают):
`spell_power`, `spell_power_<elem>`, `armor_pierce`, `percent_hp_damage`,
`miss_chance`, `resist_<elem>`.

### 4.2. Модификаторы

Модификатор — таблица:
```lua
{
  id       = 'string',           -- уникальный
  scope    = 'permanent'|'run'|'battle',
  stat     = 'damage'|...,       -- какое поле меняется
  op       = 'add'|'mul'|'set',
  value    = number,
  source   = 'level_up'|'upgrade_id'|'spell_id'|...,
  duration = { type = 'turn'|'battle', value = N } or nil,
  stack    = 'add'|'refresh'|'ignore',
  filter   = function(character) -> bool or nil,
}
```

- **`duration.type = 'turn'`** — тикает в `BattleState:start_turn` для владельца (через `tickModifiers(actor)`).
- **`duration.type = 'battle'`** — тикает в `RunState:tickBattleModifiers()` после боя.
- **Permanent** — живёт в `character.modifiers` до конца забега (или навсегда, если сохраняется в сейве).

---

## 5. Боевая система

`BattleState` (`src/battlestate.lua`) + `BattleUI` + `BattleInput`.

### 5.1. Фазы

1. **`prepare`** — расстановка отряда. Drag-and-drop по гексам (порог 8 px, чтобы отличить клик от drag). ЛКМ по юниту → окно статов.
2. **`battle`** — основной цикл. Очередь акторов (`ActorQueue`), старт хода → `phase = 'start_turn'` → `phase = 'idle'` → действие → `phase = 'action'` → следующий актор.
3. **`result`** → **`rewards`** — победа/поражение, начисление наград.

### 5.2. ActorQueue (`src/actorQueue.lua`)

- `awaiting[]` — акторы в текущем раунде, `next_turn[]` — в следующем, `all_units[]` — все.
- `queue:start_turn()` — удаляет `current` из `awaiting`, если `awaiting` пуст → `new_round()` (сортировка по инициативе).
- Панели визуализируются справа с tween-анимацией.

### 5.3. Управление в бою

- **ЛКМ без движения** → окно статов юнита (toggle).
- **ЛКМ + движение ≥ 8 px** → drag-путь → move action.
- **ПКМ** → атака / каст / перемещение с ударом.
- **Spell targeting** — через `BattleState:set_target_mode(spell)`.

### 5.4. Extra Action (`extra_action_once_per_battle`)

Флаг `_extra_action_available`. Кнопка `Use Extra Action` в фазе `idle` для игрока. Клик → `_extra_action_pending = true`, после текущего действия очередь не сдвигается, актор действует ещё раз.

---

## 6. Система улучшений забега (`RunState` + `Upgrades`)

### 6.1. RunState (`src/states/run_state.lua`)

Синглтон, живёт один забег.

| Поле | Что |
|---|---|
| `active` | флаг |
| `seed`, `rng` | детерминированный RNG |
| `player` | ссылка |
| `modifiers[]` | run-scope модификаторы |
| `unlocks{}` | `{ [key] = count }` — флаги (consume). |
| `hooks{}` | `{ [upgrade_id] = { on_xxx = fn } }` |
| `conditionals{}` | synergy-апгрейды |
| `applied_upgrades{}` | `{ [upgrade_id] = count }` |

**`RunState:reset(player, seed)`** вызывается на каждый новый забег. Очищает всё выше, **не трогает** `Player.meta_unlocks`, `Player.shards`.

**`RunState:getStat(name)`** — агрегирует `add` и `mul` из `modifiers` для meta-статов: `shard_bonus`, `essence_bonus`, `gold_bonus`. Не для per-unit статов.

**`RunState:fireHook(name, ...)`** — вызывает одноимённые функции всех зарегистрированных хуков.

### 6.2. Upgrades (`data/upgrades.lua`)

30+ улучшений, выбираются после победы (экран `UpgradeSelectScreen`, 3 варианта, взвешенный ролл по редкости).

Формат:
```lua
Upgrades['vitality'] = {
    id, name, description, icon, rarity,   -- common|uncommon|rare|legendary
    tags = { 'stat', 'health' },
    mods = { { stat = 'max_health', op = 'mul', value = 1.15 } },
    filter = function(character) ... end,   -- опционально
    condition = function(party) ... end,    -- для synergy
    unlocks = { 'flag_name' },
    target = 'single',                      -- если апгрейд на конкретное существо
    hooks = { on_battle_start = fn, ... },
    on_apply = function(character) ... end,
}
```

### 6.3. Хуки (все вызываются)

| Хук | Сигнатура | Откуда |
|---|---|---|
| `on_battle_start` | `(battle)` | `BattleState:startBattle` |
| `on_battle_win` | `(player)` | `BattleState:showResult` |
| `on_battle_lose` | `(player)` | `BattleState:showResult` |
| `on_damage_taken` | `(target, element)` | `Unit:take_damage` |
| `on_melee_hit_taken` | `(target, attacker)` | `Unit:take_damage` (melee) |
| `on_spell_hit` | `(target, spell)` | `Actions.spell` |
| `on_death` | `(unit)` | `Unit:die` |
| `on_enemy_killed` | `(victim, killer, battle)` | `BattleState:unit_death` |

---

## 7. Roguelike-слой: Levelmap

`Levelmap` (`src/levelmap2.lua`) — карта забега.

### 7.1. Структура

- **Seed-based** генерация: `RunState:getSeed()` → `math.randomseed(seed)` → `_generateMap()`. Воспроизводимо при загрузке сейва.
- Граф `generator.points` + `generator.edges`. `Node` (гекс-точки) + `Path` (связи).
- `currentNode` — узел, откуда игрок пришёл. После `resume` сбрасывается.

### 7.2. Типы узлов

| Тип | Gamestate | Описание |
|---|---|---|
| `wild` | `BattleState` | Бой с дикими |
| `trainer` | `BattleState` | Бой с тренером (золото в награду) |
| `elite` | `BattleState` | Элитный бой |
| `event` | `EventState` | Сюжетное событие |
| `shop` | `ShopState` | Магазин |
| `rest` | `RestState` | Отдых (лечение) |
| `end` | `BattleState` (босс) | Финальный узел |

Узлы генерируются в `_generateMap` с ограничениями:
- 1 rest, 1 shop на карту.
- До 30% event, до 35% trainer.

### 7.3. Переходы

**`Node:mousepressed`** → `Gamestate.push(node:getGamestate(), { player, node })`. `Levelmap.active = false`.

**`Levelmap:resume(from, args)`** — возврат:
- `from == BattleState`: `currentNode.isCompleted = true`, если победа → `RunState:tickBattleModifiers()` → `UpgradeSelectScreen:open()`. Если поражение — `player.lives -= 1`.
- `from == RestState/ShopState/EventState`: `currentNode.isCompleted = true`.
- После — `_saveGame()`.

---

## 8. Сюжетная система: EventState

**Это ключевая точка для процедурного сюжета.**

### 8.1. EventState (`src/states/eventstate.lua`)

Универсальный движок для многошаговых нарративных событий с выбором.

**Возможности шага:**
```lua
{
  text = "static string" or function(player, step) -> string,
  buttons = {
    { text = "...", action = function(player) -> nextStepIndex end },
    ...
  },
  on_enter = function(player, step) end,  -- один раз при входе
}
```

**Формат события:**
```lua
-- события возвращают либо:
return { steps = { [1] = {...}, ... }, title = "..." }

-- либо (старый формат, обратная совместимость):
return { [1] = {...}, [2] = {...} }
```

**Логика перехода:**
- `action` возвращает индекс следующего шага (`1`, `2`…).
- `action` возвращает `0` → закрытие события, `Gamestate.pop({ complete = true })`.
- `Escape` → принудительное закрытие.

**Уже реализовано:**
- Обёртка длинного текста.
- Обрезка текста с `...` при переполнении.
- Хук `on_enter` для применения эффектов один раз.
- `text` как функция — для динамических значений (HP, ресурсы).

### 8.2. Реестр событий (`src/events.lua`)

```lua
local Events = {
    abandonedCamp    = require 'src.events.abandonedCamp',
    foundItem        = require 'src.events.foundItem',
    healingSpring    = require 'src.events.healingSpring',
    mysteryCave      = require 'src.events.mysteryCave',
    buyItem          = require 'src.events.buyItem',
    darkShrine       = require 'src.events.darkShrine',
    wanderingHealer  = require 'src.events.wanderingHealer',
    cursedIdol       = require 'src.events.cursedIdol',
    ambush           = require 'src.events.ambush',
    forgottenForge   = require 'src.events.forgottenForge',
    travelingScholar = require 'src.events.travelingScholar',
    lostChild        = require 'src.events.lostChild',
}
```

В `Levelmap:_generateMap` при выборе `type = 'event'`:
```lua
node.event = events[math.random(#events)]
```

**Внимание:** порядок событий детерминирован (сортировка ключей перед `pairs` в `_generateMap`), чтобы seed воспроизводился корректно.

### 8.3. Что сейчас умеют события

- Давать предметы (`player:addItem`).
- Давать золото (`player:addCurrency`), осколки (`player:addShard`), эссенцию (`player:addEssence`).
- Лечить персонажей напрямую (с учётом `Stats` для max_hp).
- Наносить урон (не убивает — `math.max(1, ...)`).
- Накладывать **permanent** модификаторы (`Character.addModifier`).
- Накладывать **временные** модификаторы (`RunState:addModifier` с `duration = { type = 'battle', value = N }`).
- Условные эффекты (проверка `player.currencies.gold` при клике).
- Разные исходы по `RunState:random()` с отложенным применением через `on_enter`.

---

## 9. Экономика

### 9.1. Ресурсы

| Ресурс | Где | Что даёт |
|---|---|---|
| **Gold** | `player.currencies.gold` | Покупки в магазине, лечение, слоты отряда |
| **Shards** | `player.shards[attr]` — 5 типов | Крафт существ |
| **Essence** | `player.essence` | Доплата при крафте, рероллы |
| **Items** | `player.inventory` | Расходники, свитки |

### 9.2. Магазин (`ShopState`)

- Ассортимент генерится из `ItemList` по `RunState.rng`, 6 карточек (сетка 2×3).
- Цена = `item.cost × (0.8 + rand*0.4)`.
- Две вкладки: **Buy** / **Sell** (40% от цены).
- При нехватке золота — `Tagtext:add("Not enough gold")`.

### 9.3. Крафт (`CraftScreen`)

Два режима:
- **Targeted** — 5 осколков выбранного атрибута → существо этого атрибута.
- **Wild** — 5 осколков любых типов → существо из атрибутов, которые игрок потратил.

**Оплата:** `5 × shards` **или** `N shards + (5−N) × 2 essence`. Осколков может быть 0, тогда чистая эссенция 10.

### 9.4. Обмен (`ExchangeScreen`)

3 осколка одного типа → 1 другого. Безлимитно.

### 9.5. Награды за бой

`BattleState:_calculateRewards()`:
- Золото: базовое (только trainer) × `RunState:getStat('gold_bonus')`.
- Осколки: `1 + shard_bonus` за каждого убитого врага, тип по `unit.attribute`.
- Эссенция: `1 (базовая) + essence_bonus`.
- Опыт: `25 + 25 × level`.

---

## 10. Прочие состояния

- **`TownState`** — хаб. Кнопки: Begin (в `Levelmap`), Stables, Shop, Exchange, Craft. Показывает `player:drawLives()`, `player:drawShards()`, `player:drawCurrency()`. Автосохранение при переходе в Town.
- **`Stables`** — живой загон (`PenCreature` бродит, разворачивается по направлению), drag-and-drop между отрядом (party slots) и загоном (pen creatures). Плюс **Pokedex** — сетка всех существ с фильтром по атрибуту.
- **`RestState`** — три варианта лечения (+50% HP / +50% EN / +25% каждое), карточки с HP/EN. Лечит и active, и spare.
- **`ShopState`** — см. 9.2.
- **`EventState`** — см. 8.
- **`MainMenu`**, **`CharacterSelect`** (стартовые существа), **`FadeIn/OutState`**.

---

## 11. Сохранения

`SaveManager` (`src/save_manager.lua`):
- `save(player, runState, levelmap, screen)` — сериализует через `serpent` в `run.sav`.
- `load()` — возвращает `{ version, timestamp, screen, player, run, levelmap }`.
- `screen: 'town' | 'levelmap'` — куда вернуть игрока.
- `pcall + (ok, success, result)` — двойная проверка на ошибки `serpent`.

**Сериализуется:**
- `Player`: characters (active/spare/stables), inventory, currencies, shards, essence, lives, level, exp, meta_unlocks.
- `RunState`: seed, modifiers, unlocks, applied_upgrades, active_conditions.
- `Levelmap`: seed + состояния узлов/путей (карта регенерируется по seed).

**Не сериализуется:** функции (`filter`, `on_apply`, `hooks`, `condition`) — восстанавливаются из `Upgrades[source]` при десериализации.

---

## 12. Точки расширения для процедурного сюжета

### 12.1. Данные, доступные событию

Через `function(player)` при вызове события доступно:
- `player.currencies.gold`, `player.shards`, `player.essence`
- `player.charactersActive[i]` — активные существа (`.name`, `.health`, `.max_health`, `.attribute`, `.element`, `.spells`)
- `player.charactersSpare[i]`
- `player.charactersStables[i]`
- `player.inventory` — предметы
- `RunState:getSeed()`, `RunState:randomInt(min, max)`, `RunState:random()`
- `RunState:hasUnlock(key)`, `RunState:getStat(name)`
- `RunState.applied_upgrades` — список взятых улучшений забега

### 12.2. Действия, доступные событию

- `player:addItem(id, qty)`, `player:removeItem(item, qty)`
- `player:addCurrency('gold', ±N)`, `player:addShard(attr, N)`, `player:addEssence(N)`
- `player:addCharacter(name)` — добавить существо в отряд
- `player:removeCharacter(character)` — убрать
- `Character.addModifier(character, mod)` — permanent-модификатор
- `RunState:addModifier(mod)` — run-модификатор (можно с `duration`)
- `RunState:addUnlock(key, count)`, `RunState:consumeUnlock(key)`
- Прямое изменение `character.health`, `character.energy` (с клампом)

### 12.3. Потенциальные направления для процедурного сюжета

1. **Ветвящиеся цепочки событий** — на карте может быть «сюжетный узел», который знает о предыдущих событиях через `RunState.story_flags` (нужно добавить новое поле).
2. **Персонажные арки** — существо получает уникальное событие в зависимости от своей истории (например, если погибло в бою, а потом воскресло через `second_chance`).
3. **Мир и фракции** — набор флагов забега, которые влияют на частоту событий определённого типа.
4. **Narrative templates** — события как шаблоны с переменными (`{item}`, `{creature.name}`, `{damage}`), заполняемыми процедурно.
5. **Мета-сюжет** — цепочки между забегами через `Player.meta_unlocks` и постоянные флаги.

### 12.4. Что потребуется добавить

- **`RunState.story{}`** — таблица произвольных флагов забега (например, `RunState.story.met_scholar = true`).
- **`Player.meta_story{}`** — флаги между забегами.
- **Категории событий** (`event.category = 'combat' | 'story' | 'shrine'`) — для взвешенного выбора.
- **Цепочки** (`event.requires = { flag = true }`, `event.on_complete = function() ... end`).
- **Хранение seed и истории событий** в сейве — чтобы при загрузке не потерять прогресс цепочки.

---

## 13. Статус реализации

| Система | Готово | В работе / нужно |
|---|---|---|
| Бои (HOMM3) | ✅ | Баланс, анимации |
| Атрибут × Элемент (чарт, STAB, resist) | ✅ | Нужны существа `mechanic`/`ancient`/`chaos` |
| Броня (кривая с насыщением) | ✅ | — |
| Модификаторы (permanent/run/battle) | ✅ | — |
| Осколки + эссенция | ✅ | Тюнинг наград |
| Крафт + обмен | ✅ | Иконки, UX-поливка; 3 из 5 атрибутов пусты |
| Улучшения (30+) | ⚠️ | `aoe_bonus`, `echo_chance`, `double_cast_chance` не имеют потребителя |
| Магазин (2×3, seed-based) | ✅ | Иконки предметов |
| События (12 штук) | ✅ | **← точка расширения для сюжета** |
| Stables + Pokedex | ✅ | Скроллинг, дубликаты |
| Карта (seed-based) | ✅ | Иконки узлов |
| Сохранения | ✅ | `RunState.active` не сбрасывается (см. §7.3) |
| Тесты (`tests/`) | ✅ | 47 тестов, чистые данные и математика |
| Обучение способностей | ❌ | Level-up choice, scrolls, trainer |
| Мета-прогресс (`collector`) | ❌ | `Player.meta_shards`, `meta_story` |
| Туториал | ❌ | — |
| Иконки апгрейдов/предметов | ❌ | Заглушки |
| Звук / анимации боя | ⚠️ | Базовые есть |

---

## 13.1. Тесты

`tests/` — не требует LÖVE, запускается обычным Lua:

```
lua tests/run.lua
```

| Файл | Что проверяет |
|---|---|
| `tests/test_damage.lua` | Чарт, конвейер урона, STAB, resist, броня, дефолты `Stats` |
| `tests/test_data_integrity.lua` | Существа ↔ чарт ↔ заклинания ↔ апгрейды ↔ UI-метки |

`tests/test_data_integrity.lua` — это регрессия на исходный баг: в чарте не было
строк `ancient`/`chaos`, а существа и осколки их используют. Тест также ловит
ссылки на несуществующие заклинания (сейчас 15 известных — см.
`KNOWN_MISSING_SPELLS` в тесте; **новая** такая ссылка уронит тест).

---

## 14. Ключевые файлы

```
data/
  upgrades.lua             -- 30+ улучшений забега
  type_chart.lua           -- атрибуты/элементы × эффективность

src/
  character.lua            -- Character (персистентный)
  player.lua               -- Player (контейнер существ, ресурсов)
  stats.lua                -- Stats (compute с модификаторами)
  item.lua                 -- runtime Item (инстанс предмета)
  items.lua                -- реестр ItemList
  items/effects.lua        -- общие эффекты (restore_hp, add_modifier, ...)
  items/healPotion.lua     -- декларативные данные
  items/energyPotion.lua
  items/battleHorn.lua
  events.lua               -- реестр событий
  events/*.lua             -- конкретные события
  damage_calculator.lua    -- attr × elem × armor
  save_manager.lua         -- serialize / deserialize / save file

  states/
    townstate.lua          -- хаб
    run_state.lua          -- состояние забега (синглтон)
    levelmap2.lua          -- карта забега
    stables.lua            -- загон + Pokedex
    reststate.lua          -- отдых
    shopstate.lua          -- магазин
    eventstate.lua         -- движок событий
    mainmenu.lua
    character_select_screen.lua
    exchange_screen.lua    -- обмен осколков
    craft_screen.lua       -- крафт существ
    upgrade_select_screen.lua -- выбор улучшения после боя
    battlestate.lua          -- бой (главный)

  battlestate/battleui.lua
  battlestate/battleinput.lua
  actorQueue.lua           -- очередь ходов
  objects/unit.lua         -- боевой актор
  stables/pen_creature.lua -- визуальная сущность в загоне
  ui.lua                   -- immediate-mode-like UI
```

---

## 15. Ключевые принципы для интеграции сюжета

1. **Детерминизм.** Всё случайное — через `RunState:random()` / `RunState:randomInt()`. `math.random` — только для визуала, не для логики.
2. **Сериализация.** Всё состояние — таблицы чисел/строк. Функции не сохраняются, восстанавливаются из кода по `id`/`source`.
3. **Модификаторы вместо прямых изменений.** Не менять `character.damage` напрямую — добавлять `modifier`. Permanent — на `character.modifiers`, run — на `RunState.modifiers`, battle — на `unit.modifiers`.
4. **Условные эффекты — в `action` или `on_enter`.** `action` — для выбора/перехода, `on_enter` — для одноразового эффекта.
5. **Текст как функция — для динамических данных.** Если значение меняется после события (например, HP после лечения), использовать `text = function() ... end`.
6. **Не убивать персонажей событиями.** Клампить урон через `math.max(1, ...)` — `Unit:die` вызывает боевую логику (`check_result`), которая не рассчитана на внебоевой контекст.
7. **События — изолированные модули.** Каждое событие — `return function(player) -> steps end`. Никаких сайд-эффектов при загрузке модуля.

---

Этот документ можно использовать как базу для агента, разрабатывающего процедурный сюжет. Все ключевые точки расширения (EventState, реестр событий, доступные данные, действия, модификаторы) описаны. Если агенту понадобится больше деталей по конкретной системе — он может запросить исходники соответствующих файлов или уточнения.