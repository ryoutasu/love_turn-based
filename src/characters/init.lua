local path = (...) and (...):gsub('%.init$', '') .. "." or ""
local characters = {}

local allFiles = love.filesystem.getDirectoryItems(path:gsub('[.]', '/'))
for i, filename in ipairs(allFiles) do
    filename = filename:match"^(.*)%.lua$"
    if filename and filename ~= 'init' then
        local character = require(path..filename)
        characters[character.name] = character
    end
end

return characters