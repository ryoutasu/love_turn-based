-- data/type_chart.lua
-- Двухосевая система урона: АТРИБУТ × ЭЛЕМЕНТ.
--
-- Модель основана на трёх источниках:
--   * Pokémon — матрица типов, множители 0.5/1/2 и STAB ×1.5;
--   * Digimon — треугольник атрибутов (Vaccine > Virus > Data > Vaccine);
--   * SMT — явные «слабость / сопротивление / иммунитет» вместо голых чисел.
--
-- Два независимых множителя урона, как и было задумано в specs.md §3.3:
--   final = base × attr_mul × elem_mul × stab
-- Поэтому возможен урон ×2.25 (атрибут 1.5 × элемент 1.5).
--
-- ВАЖНО про безопасность: раньше чарт был разреженным и
-- `Chart.attributes[attAttr][defAttr]` падал с попыткой индексации nil,
-- как только в игре появлялся ancient/chaos. Теперь каждая строка
-- заполнена явно, а сеттеры в конце файла проверяют целостность.

local Chart = {}

-- ------------------------------------------------------------------
-- Множители. Держим их в одном месте, чтобы баланс правился тут.
-- ------------------------------------------------------------------

Chart.MULT = {
    immune    = 0.0,   -- полный иммунитет (пока не используется, но поддержан)
    resist    = 0.5,   -- сопротивление: вдвое слабее
    weak      = 0.75,  -- лёгкое сопротивление
    neutral   = 1.0,
    strong    = 1.5,   -- уязвимость
    crush     = 2.0,   -- «супер-эффективно»
}

-- STAB (Same-Type Attack Bonus): если элемент/атрибут заклинания
-- совпадает с таковым у кастера, урон выше. Значение из Pokémon.
Chart.STAB = 1.5

local M = Chart.MULT

-- ------------------------------------------------------------------
-- АТРИБУТЫ: 5 типов.
--
-- Треугольник (взаимный, как в Digimon):
--   wild > mystic > mechanic > wild
-- ancient и chaos — нейтральные полюса: они не имеют преимуществ,
-- но у каждого есть своя уязвимость, чтобы не были «чистым апгрейдом».
--
-- Строка = атакующий, столбец = защищающийся.
-- ------------------------------------------------------------------

Chart.attributes = {
    wild = {
        wild     = M.neutral,
        mystic   = M.strong,   -- wild бьёт mystic
        mechanic = M.resist,   -- wild слаб против mechanic
        ancient  = M.neutral,
        chaos    = M.neutral,
    },
    mystic = {
        wild     = M.resist,
        mystic   = M.neutral,
        mechanic = M.strong,   -- mystic бьёт mechanic
        ancient  = M.neutral,
        chaos    = M.neutral,
    },
    mechanic = {
        wild     = M.strong,   -- mechanic бьёт wild
        mystic   = M.resist,
        mechanic = M.neutral,
        ancient  = M.neutral,
        chaos    = M.neutral,
    },
    -- Ancient: устойчив к «мирским» типам, но уязвим к chaos
    -- и сам пробивает chaos. Это делает его дорогим, но уязвимым.
    ancient = {
        wild     = M.weak,
        mystic   = M.weak,
        mechanic = M.weak,
        ancient  = M.neutral,
        chaos    = M.strong,
    },
    -- Chaos: зеркалит ancient — устойчив к ancient, слаб к ordinary.
    chaos = {
        wild     = M.neutral,
        mystic   = M.neutral,
        mechanic = M.neutral,
        ancient  = M.resist,
        chaos    = M.neutral,
    },
}

-- ------------------------------------------------------------------
-- ЭЛЕМЕНТЫ: 7 типов.
--
-- Континентальный цикл: ember > earth > storm > water > ember
-- Ember/Storm > Plant > Water/Earth
-- Light ↔ Dark взаимно ×2
--
-- Neutral — не элемент, а «физический» урон: не имеет ни преимуществ,
-- ни слабостей. Добавлен строкой и столбцом, чтобы не городить
-- проверок на nil в горячем пути.
-- ------------------------------------------------------------------

Chart.elements = {
    ember = {
        ember    = M.resist,
        water    = M.resist,
        earth    = M.strong,
        storm    = M.neutral,
        light    = M.neutral,
        dark     = M.neutral,
        plant    = M.strong,
        neutral  = M.neutral,
    },
    water = {
        ember    = M.strong,
        water    = M.resist,
        earth    = M.neutral,
        storm    = M.resist,
        light    = M.neutral,
        dark     = M.neutral,
        plant    = M.resist,
        neutral  = M.neutral,
    },
    earth = {
        ember    = M.resist,
        water    = M.neutral,
        earth    = M.resist,
        storm    = M.strong,
        light    = M.neutral,
        dark     = M.neutral,
        plant    = M.resist,
        neutral  = M.neutral,
    },
    storm = {
        ember    = M.neutral,
        water    = M.strong,
        earth    = M.resist,
        storm    = M.resist,
        light    = M.neutral,
        dark     = M.neutral,
        plant    = M.strong,
        neutral  = M.neutral,
    },
    light = {
        ember    = M.neutral,
        water    = M.neutral,
        earth    = M.neutral,
        storm    = M.neutral,
        light    = M.resist,
        dark     = M.crush,     -- ×2
        plant    = M.neutral,
        neutral  = M.neutral,
    },
    dark = {
        ember    = M.neutral,
        water    = M.neutral,
        earth    = M.neutral,
        storm    = M.neutral,
        light    = M.crush,     -- ×2
        dark     = M.resist,
        plant    = M.neutral,
        neutral  = M.neutral,
    },
    plant = {
        ember    = M.resist,
        water    = M.strong,
        earth    = M.strong,
        storm    = M.resist,
        light    = M.neutral,
        dark     = M.neutral,
        plant    = M.resist,
        neutral  = M.neutral,
    },
    -- «Физический» урон: нейтрален ко всему.
    neutral = {
        ember    = M.neutral,
        water    = M.neutral,
        earth    = M.neutral,
        storm    = M.neutral,
        light    = M.neutral,
        dark     = M.neutral,
        plant    = M.neutral,
        neutral  = M.neutral,
    },
}

-- ------------------------------------------------------------------
-- Безопасный доступ
-- ------------------------------------------------------------------

--- Множитель по атрибутам. Никогда не падает: неизвестный тип = 1.0.
function Chart.getAttributeMultiplier(attAttr, defAttr)
    if not attAttr or not defAttr then return M.neutral end
    local row = Chart.attributes[attAttr]
    if not row then return M.neutral end
    return row[defAttr] or M.neutral
end

--- Множитель по элементам. Никогда не падает: неизвестный тип = 1.0.
function Chart.getElementMultiplier(attElem, defElem)
    if not attElem or not defElem then return M.neutral end
    local row = Chart.elements[attElem]
    if not row then return M.neutral end
    return row[defElem] or M.neutral
end

--- Комбинированный множитель (без STAB). Используется в UI-подсказках.
function Chart.getCombinedMultiplier(attAttr, defAttr, attElem, defElem)
    return Chart.getAttributeMultiplier(attAttr, defAttr)
         * Chart.getElementMultiplier(attElem, defElem)
end

-- ------------------------------------------------------------------
-- Классификация для UI и логов
-- ------------------------------------------------------------------

--- Возвращает 'weak' | 'neutral' | 'strong' — для окраски всплывающего
--- текста урона и подсказок при наведении.
function Chart.classify(mult)
    if not mult then return 'neutral' end
    if mult <= 0.001       then return 'immune' end
    if mult < 0.99         then return 'weak'   end
    if mult <= 1.01        then return 'neutral' end
    if mult >= 1.99        then return 'crush'  end
    return 'strong'
end

--- Человекочитаемая метка для боевого лога.
Chart.LABELS = {
    immune  = 'immune',
    weak    = 'resisted',
    neutral = '',
    strong  = 'effective',
    crush   = 'super effective',
}

-- ------------------------------------------------------------------
-- Валидация целостности.
-- Вызывается при загрузке: лучше упасть на старте, чем в бою.
-- ------------------------------------------------------------------

local ATTRS  = { 'wild', 'mystic', 'mechanic', 'ancient', 'chaos' }
local ELEMS  = { 'ember', 'water', 'earth', 'storm', 'light', 'dark', 'plant', 'neutral' }

function Chart.validate()
    local problems = {}

    for _, a in ipairs(ATTRS) do
        local row = Chart.attributes[a]
        if not row then
            problems[#problems + 1] = 'missing attribute row: ' .. a
        else
            for _, d in ipairs(ATTRS) do
                if type(row[d]) ~= 'number' then
                    problems[#problems + 1] = ('attribute %s vs %s is not a number'):format(a, d)
                end
            end
        end
    end

    for _, e in ipairs(ELEMS) do
        local row = Chart.elements[e]
        if not row then
            problems[#problems + 1] = 'missing element row: ' .. e
        else
            for _, d in ipairs(ELEMS) do
                if type(row[d]) ~= 'number' then
                    problems[#problems + 1] = ('element %s vs %s is not a number'):format(e, d)
                end
            end
        end
    end

    if #problems > 0 then
        error('data/type_chart.lua is incomplete:\n  ' .. table.concat(problems, '\n  '))
    end
    return true
end

Chart.ATTRIBUTES = ATTRS
Chart.ELEMENTS   = ELEMS

return Chart
