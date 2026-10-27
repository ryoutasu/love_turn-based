#!/usr/bin/env lua
-- tests/run.lua — запускает все тесты и возвращает код выхода.
--   lua tests/run.lua
--
-- Тесты не требуют LÖVE: они проверяют чистую математику и целостность
-- данных. Визуал и состояния по-прежнему проверяются запуском игры.

local suites = {
    'tests/test_damage.lua',
    'tests/test_data_integrity.lua',
}

local failed = 0

for _, file in ipairs(suites) do
    print('')
    print('=== ' .. file .. ' ===')
    local ok = os.execute('lua ' .. file)
    -- os.execute возвращает true/nil в 5.1 и число в 5.2+
    if not (ok == true or ok == 0) then
        failed = failed + 1
    end
end

print('')
if failed == 0 then
    print('ALL SUITES PASSED')
    os.exit(0)
end

print(failed .. ' suite(s) FAILED')
os.exit(1)
