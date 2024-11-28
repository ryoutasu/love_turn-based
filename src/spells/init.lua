local path = (...) and (...):gsub('%.init$', '') .. "." or ""
local files = {}

local allFiles = love.filesystem.getDirectoryItems(path:gsub('[.]', '/'))
for i, filename in ipairs(allFiles) do
    filename = filename:match"^(.*)%.lua$"
    if filename and filename ~= 'init' then
        local file = require(path..filename)
        files[filename] = file
    end
end

return files