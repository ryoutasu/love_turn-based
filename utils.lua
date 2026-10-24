function math.clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function math.lerp(v0, v1, t)
    return (1 - t) * v0 + t * v1;
end

function Badprint(text, progress)
    return text:sub(1, #text*progress)
end

function PrintText(text, x, y, r, sx, sy, ox, oy, kx, ky)
    love.graphics.print(text, math.ceil(x), math.ceil(y), r, sx, sy, ox, oy, kx, ky)
end

function PrintfText(text, x, y, limit, align, r, sx, sy, ox, oy, kx, ky)
    love.graphics.printf(text, math.ceil(x), math.ceil(y), limit, align, r, sx, sy, ox, oy, kx, ky)
end

function PrintTextOutlined(text, color, outline_color, x, y, r, sx, sy, ox, oy, kx, ky)
    love.graphics.setColor(outline_color)
    -- love.graphics.print(text, math.ceil(x) + 1, math.ceil(y) + 1, r, sx, sy, ox, oy, kx, ky)
    -- love.graphics.print(text, math.ceil(x) - 1, math.ceil(y) - 1, r, sx, sy, ox, oy, kx, ky)
    -- love.graphics.print(text, math.ceil(x) + 1, math.ceil(y) - 1, r, sx, sy, ox, oy, kx, ky)
    -- love.graphics.print(text, math.ceil(x) - 1, math.ceil(y) + 1, r, sx, sy, ox, oy, kx, ky)
    
    love.graphics.printf(text, math.ceil(x) + 1, math.ceil(y), r, sx, sy, ox, oy, kx, ky)
    love.graphics.printf(text, math.ceil(x), math.ceil(y) + 1, r, sx, sy, ox, oy, kx, ky)
    love.graphics.printf(text, math.ceil(x) - 1, math.ceil(y), r, sx, sy, ox, oy, kx, ky)
    love.graphics.printf(text, math.ceil(x), math.ceil(y) - 1, r, sx, sy, ox, oy, kx, ky)

    love.graphics.setColor(color)
    love.graphics.print(text, math.ceil(x), math.ceil(y), r, sx, sy, ox, oy, kx, ky)
end

function PrintfTextOutlined(text, color, outline_color, x, y, limit, align, r, sx, sy, ox, oy, kx, ky)
    love.graphics.setColor(outline_color)
    -- love.graphics.printf(text, math.ceil(x) + 1, math.ceil(y) + 1, limit, align, r, sx, sy, ox, oy, kx, ky)
    -- love.graphics.printf(text, math.ceil(x) - 1, math.ceil(y) - 1, limit, align, r, sx, sy, ox, oy, kx, ky)
    -- love.graphics.printf(text, math.ceil(x) + 1, math.ceil(y) - 1, limit, align, r, sx, sy, ox, oy, kx, ky)
    -- love.graphics.printf(text, math.ceil(x) - 1, math.ceil(y) + 1, limit, align, r, sx, sy, ox, oy, kx, ky)
    
    love.graphics.printf(text, math.ceil(x) + 1, math.ceil(y), limit, align, r, sx, sy, ox, oy, kx, ky)
    love.graphics.printf(text, math.ceil(x), math.ceil(y) + 1, limit, align, r, sx, sy, ox, oy, kx, ky)
    love.graphics.printf(text, math.ceil(x) - 1, math.ceil(y), limit, align, r, sx, sy, ox, oy, kx, ky)
    love.graphics.printf(text, math.ceil(x), math.ceil(y) - 1, limit, align, r, sx, sy, ox, oy, kx, ky)

    love.graphics.setColor(color)
    love.graphics.printf(text, math.ceil(x), math.ceil(y), limit, align, r, sx, sy, ox, oy, kx, ky)
end

function Darker(color, amount)
  amount = 1 - (amount or 0.2)
  local r, g, b = color[1], color[2], color[3]
  r = r * amount
  g = g * amount
  b = b * amount

  return { r, g, b, color[4] }
end

function Brighter(color, amount)
  amount = amount or 0.2
  local r, g, b = color[1], color[2], color[3]
  r = r + ((1 - r) * amount)
  g = g + ((1 - g) * amount)
  b = b + ((1 - b) * amount)

  return { r, g, b, color[4] }
end