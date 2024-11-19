function math.clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function PrintText(text, x, y)
    love.graphics.print(text, math.ceil(x), math.ceil(y))
end