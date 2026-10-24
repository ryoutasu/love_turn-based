-- Отрисовка карты: связи между узлами (Path) и сами узлы (Node).
-- MapRenderer держит offset (отступ от края экрана) и вызывает draw у Path и Node.

local OPEN_LINE_WIDTH      = 3
local CLOSED_LINE_WIDTH    = 1
local OPEN_COLOR           = { 1,   1,   1,   1 }
local COMPLETED_COLOR      = { 0.3, 0.3, 0.3, 1 }
local CLOSED_COLOR         = { 0,   0,   0,   1 }

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

function Path:draw(offset)
    offset = offset or 0
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
        edge.p1.x + offset, edge.p1.y + offset,
        edge.p2.x + offset, edge.p2.y + offset
    )
end

-- ------------------------------------------------------------------
-- MapRenderer
-- ------------------------------------------------------------------
local MapRenderer = Class{}

function MapRenderer:init(offset)
    self.offset = offset or 0
end

function MapRenderer:setOffset(offset)
    self.offset = offset
end

-- Рисует все связи, потом все узлы.
-- Порядок важен: узлы должны быть поверх линий.
function MapRenderer:draw(paths, nodes)
    for _, path in ipairs(paths) do
        path:draw(self.offset)
    end
    for _, node in ipairs(nodes) do
        node:draw()
    end
end

MapRenderer.Path = Path

return MapRenderer