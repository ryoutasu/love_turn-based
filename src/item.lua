-- Runtime-инстанс: создаётся на одно использование предмета (в бою или на карте).
-- Принимает декларативную таблицу из ItemList и применяет её.

local animation = require 'src.animation'
local Effects   = require 'src.items.effects'

local Item = Class{}

function Item:init(data, caster, target)
    -- Копируем данные (name, color, effect, on_apply, ...)
    for k, v in pairs(data) do self[k] = v end

    self.caster = caster
    self.target = target
    self.subject, self.context = self:_resolve(target)
    self.x = target and target.x or 0
    self.y = target and target.y or 0

    self:_play_visual()
end

-- Определяем, на кого применяется эффект.
-- Бой: tile -> actor (Unit).
-- Карта: Unit-обёртка (.character) -> Character.
-- Если передан Character напрямую — Character.
function Item:_resolve(target)
    if not target then return nil, 'none' end
    if target.actor then return target.actor, 'unit' end
    if target.character then return target.character, 'character' end
    if target.sprite then return target, 'character' end
    return nil, 'none'
end

function Item:_play_visual()
    self.visual = animation('resources/simplefx-alpha.png', true)
    local x = 0
    for _ = 1, 5 do
        self.visual:add_frame(x, 0, 16, 16)
        x = x + 16
    end
    self.visual.frameTime = 0.15
    self.visual.play = true

    local _, _, w, h = self.visual:get_frame():getViewport()
    self.ox, self.oy = w / 2, h / 2
end

function Item:update(dt)
    self.visual:update(dt)
    if self.visual.play then return false end

    self:_apply()
    return true
end

function Item:_apply()
    local subject, context = self.subject, self.context
    if not subject then return end

    -- Декларативный эффект
    if self.effect then
        Effects.apply(self.effect, self, subject, context)
    end
    -- Уникальная логика (для сложных предметов)
    if self.on_apply then
        self.on_apply(self.caster, subject, context, self)
    end
end

function Item:draw()
    love.graphics.setColor(self.color or { 1, 1, 1, 1 })
    self.visual:draw(self.x, self.y, 0, 3, 3, self.ox, self.oy)
end

return Item