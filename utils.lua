function math.clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function Badprint(text, progress)
    return text:sub(1, #text*progress)
end

function PrintText(text, x, y, r, sx, sy)
    love.graphics.print(text, math.ceil(x), math.ceil(y), r, sx, sy)
end