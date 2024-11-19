
local delaunay = require 'lib.delaunay'
local pds = require 'src.PoissonDiskSampling'

Point = delaunay.Point

local Generator = Class{}

function Generator:init()
    
end

function Generator:generate(radius, width, height)
    -- local width, height = love.graphics.getWidth(), love.graphics.getHeight()
    local points = pds(radius, 30, width, height)
    local triangles = delaunay.triangulate(points)
    local edges = {}

    self.points = points
    self.edges = edges

    for _, triangle in ipairs(triangles) do
        table.insert(edges, triangle.e1)
        table.insert(edges, triangle.e2)
        table.insert(edges, triangle.e3)
    end

    for i = 1, #edges - 1 do
        local edge = edges[i]
        for j = #edges, i + 1, -1 do
            local other = edges[j]

            if edge:same(other) then
                table.remove(edges, j)
            end
        end

        if edge then
            edge.p1.neighbors = edge.p1.neighbors or {}
            edge.p2.neighbors = edge.p2.neighbors or {}
    
            table.insert(edge.p1.neighbors, edge.p2)
            table.insert(edge.p2.neighbors, edge.p1)
        end
    end

    local startPoint, startIndex
    for i, point in ipairs(points) do
        local neighborsCount = #point.neighbors

        if not startPoint or neighborsCount < #startPoint.neighbors then
            startPoint = point
            startIndex = i
        end
    end

    local endPoint, endIndex
    local maxDistance = 0
    for i, point in ipairs(points) do
        -- local neighborsCount = #point.neighbors
        local distance = startPoint:dist2(point)
        point.distance = distance

        if point ~= startPoint
        and not self:isNeighbors(point, startPoint) then
            if (distance > maxDistance) then
                endPoint = point
                endIndex = i
                maxDistance = distance
            end
        end

    end

    self.startPoint = startPoint
    self.endPoint = endPoint
end

function Generator:isNeighbors(point, other)
    for _, edge in ipairs(self.edges) do
        local p1, p2 = edge.p1, edge.p2
        if (p1 == point and p2 == other) or (p1 == other and p2 == point) then
            return true, edge
        end
    end

    return false
end

return Generator