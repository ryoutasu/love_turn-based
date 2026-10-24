local serpent = require 'lib.serpent'

local SaveManager = {}
local SAVE_FILE = 'run.sav'

function SaveManager.exists()
    return love.filesystem.getInfo(SAVE_FILE) ~= nil
end

--- screen: 'town' | 'levelmap' — где игрок сохранился.
--- levelmap передаётся только если сохраняем из Levelmap (см. следующий шаг).
function SaveManager.save(player, runState, levelmap, screen)
    local data = {
        version   = 1,
        timestamp = os.time(),
        screen    = screen or 'town',
        player    = player:serialize(),
        run       = runState:serialize(),
        levelmap  = levelmap and levelmap:serialize() or nil,
    }

    local ok, str = pcall(serpent.dump, data, { comment = false, nocode = true })
    if not ok then
        print('[SaveManager] dump failed: ' .. tostring(str))
        return false
    end

    love.filesystem.write(SAVE_FILE, str)
    print("Game saved")
    return true
end

function SaveManager.load()
    if not SaveManager.exists() then return nil end

    local content = love.filesystem.read(SAVE_FILE)
    if not content then return nil end

    local ok, success, data = pcall(serpent.load, content, { safe = true })
    if not ok or not success or type(data) ~= 'table' then
        print('[SaveManager] load failed: ' .. tostring(data))
        return nil
    end
    return data
end

function SaveManager.delete()
    if SaveManager.exists() then love.filesystem.remove(SAVE_FILE) end
end

return SaveManager