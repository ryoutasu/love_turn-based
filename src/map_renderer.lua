-- Отрисовка карты: связи между узлами (Path) и сами узлы (Node).
--
-- Камера карты: узел — это точка в мировых координатах, на экран он попадает
-- как screen = world * scale + x/y. Узлы, пути и подписи рисуются внутри
-- love.graphics.push/pop, поэтому зум и панорамирование применяются ко всей
-- карте разом. Хитбоксы нодов идут через UI и пересчитываются в экранные
-- координаты тем же преобразованием (toScreen).

local OPEN_LINE_WIDTH      = 3
local CLOSED_LINE_WIDTH    = 1
local OPEN_COLOR           = { 1,   1,   1,   1 }
local COMPLETED_COLOR      = { 0.3, 0.3, 0.3, 1 }
local CLOSED_COLOR         = { 0,   0,   0,   0 }

-- ------------------------------------------------------------------
-- Path — связь между двумя узлами.
-- isOpen / isCompleted выставляются извне (Levelmap) при навигации.
-- ------------------------------------------------------------------
local Path = Class{}

function Path:init(edge)
    self.edge        = edge
    self.isOpen      = false
    self.isCompleted = false
end

-- Рисуется снаружи MapRenderer:draw, уже внутри трансформации камеры.
function Path:draw()
    local edge = self.edge

    if self.isCompleted then
        love.graphics.setLineWidth(OPEN_LINE_WIDTH)
        love.graphics.setColor(COMPLETED_COLOR)
    elseif self.isOpen then
        love.graphics.setLineWidth(OPEN_LINE_WIDTH)
        love.graphics.setColor(OPEN_COLOR)
    else
        love.graphics.setLineWidth(CLOSED_LINE_WIDTH)
        love.graphics.setColor(CLOSED_COLOR)
    end

    love.graphics.line(
        edge.p1.x, edge.p1.y,
        edge.p2.x, edge.p2.y
    )
end

-- ------------------------------------------------------------------
-- MapRenderer
-- ------------------------------------------------------------------
local MapRenderer = Class{}

function MapRenderer:init()
    self.scale  = 1   -- 1 = карта вписывается в экран при генерации
    self.viewX  = 0   -- экранный X мирового нуля
    self.viewY  = 0   -- экранный Y мирового нуля
end

-- Сбрасывает камеру: карта 1:1 и отцентрована, как при генерации.
function MapRenderer:resetView()
    self.scale = 1
    self.viewX = 0
    self.viewY = 0
end

-- Мировые координаты -> экранные.
function MapRenderer:toScreen(x, y)
    return x * self.scale + self.viewX, y * self.scale + self.viewY
end

-- Экранные координаты -> мировые.
function MapRenderer:toWorld(x, y)
    return (x - self.viewX) / self.scale, (y - self.viewY) / self.scale
end

-- Зум вокруг экранной точки (sx, sy): точка под курсором остаётся на месте.
-- scale не выходит за [minScale, maxScale]; когда масштаб уже упёрся в
-- предел, вид не меняется вовсе.
function MapRenderer:zoomAt(sx, sy, factor, minScale, maxScale)
    local old = self.scale
    local new = self:_zoomScale(factor, minScale, maxScale)
    if new == old then return end

    -- Держим мировую точку под курсором на том же экранном месте.
    -- screen = world * scale + view, значит view' = screen - (screen - view) * k.
    local k = new / old
    self.viewX = sx - (sx - self.viewX) * k
    self.viewY = sy - (sy - self.viewY) * k
    self.scale = new
end

function MapRenderer:_zoomScale(factor, minScale, maxScale)
    local new = self.scale * factor
    if minScale then new = math.max(new, minScale) end
    if maxScale then new = math.min(new, maxScale) end
    return new
end

-- Сдвиг карты в экранных пикселях.
function MapRenderer:pan(dx, dy)
    self.viewX = self.viewX + dx
    self.viewY = self.viewY + dy
end

-- Рисует все связи, потом все узлы.
-- Порядок важен: узлы должны быть поверх линий.
function MapRenderer:draw(paths, nodes)
    love.graphics.push()
    love.graphics.translate(self.viewX, self.viewY)
    love.graphics.scale(self.scale, self.scale)

    for _, path in ipairs(paths) do
        path:draw()
    end
    for _, node in ipairs(nodes) do
        node:draw()
    end

    love.graphics.pop()
end

MapRenderer.Path = Path

return MapRenderer
