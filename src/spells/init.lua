local path = (...) and (...):gsub('%.init$', '') .. "." or ""
local spells = {}

local allFiles = love.filesystem.getDirectoryItems(path:gsub('[.]', '/'))
for i, filename in ipairs(allFiles) do
    filename = filename:match"^(.*)%.lua$"
    if filename and filename ~= 'init' then
        local spell = require(path..filename)
        spells[filename] = spell
    end
end

return spells