local path = (...) and (...):gsub('%.init$', '') .. "." or ""
local events = {}

local allFiles = love.filesystem.getDirectoryItems(path:gsub('[.]', '/'))
for i, filename in ipairs(allFiles) do
    filename = filename:match"^(.*)%.lua$"
    if filename and filename ~= 'init' then
        local event = require(path..filename)
        events[filename] = event
    end
end

return events