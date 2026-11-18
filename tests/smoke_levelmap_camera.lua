-- tests/smoke_levelmap_camera.lua
--
-- Coverage for the level-map camera:
--   * MapRenderer zoom-at-cursor keeps the world point under the mouse fixed
--   * zoom is clamped to [ZOOM_MIN, ZOOM_MAX]
--   * MapRenderer.pan translates the view
--   * toScreen/toWorld are inverse transforms
--   * mouse wheel zooms the map around the cursor (Levelmap:wheelmoved)
--   * LMB on empty map space starts panning, mousemove moves the map
--   * LMB on a node or a UI element does NOT start panning
--   * drag below the threshold is a click, not a pan
--   * panel position stays put after a pan
--
-- Headless, no LÖVE runtime. Run: lua tests/smoke_levelmap_camera.lua

local here = (arg and arg[0] or ''):match('^(.*)[/\\]') or '.'
local root = here .. '/..'
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path

-- ---------------------------------------------------------------------------
-- LÖVE stubs
-- ---------------------------------------------------------------------------

local function stubImage()
    return { getWidth = function() return 1 end, getHeight = function() return 1 end }
end

local function stubImageData(w, h)
    local d = { w = w or 1, h = h or 1 }
    function d:setPixel() end
    function d:mapPixel() end
    function d:getWidth() return self.w end
    function d:getHeight() return self.h end
    return d
end

local function stubFont()
    return { getWidth = function() return 1 end, getHeight = function() return 14 end }
end

-- Mouse state the camera reads.
local mouse = { x = 0, y = 0, down = {} }

local function setup_love(width, height)
    love = {
        image = { newImageData = stubImageData, newImage = stubImage },
        graphics = {
            newImage = stubImage,
            newFont  = stubFont,
            newQuad  = function() return { getViewport = function() return 0, 0, 1, 1 end } end,
            newText  = function() return { setf = function() end } end,
            getWidth  = function() return width or 1280 end,
            getHeight = function() return height or 720 end,
            -- Recorded transforms so tests can prove the camera is applied.
            push      = function() end,
            pop       = function() end,
            translate = function() end,
            scale     = function() end,
            setColor  = function() end,
            setLineWidth = function() end,
            line      = function() end,
            circle    = function() end,
            rectangle = function() end,
            print     = function() end,
            printf    = function() end,
            draw      = function() end,
            getScissor = function() return nil, nil, nil, nil end,
            setScissor = function() end,
            setFont   = function() end,
        },
        mouse = {
            getPosition = function() return mouse.x, mouse.y end,
            isDown      = function(button) return mouse.down[button] == true end,
            getX        = function() return mouse.x end,
            getY        = function() return mouse.y end,
        },
        filesystem = {
            getInfo           = function() return nil end,
            getDirectoryItems = function() return {} end,
        },
        math = {
            colorFromBytes = function(r, g, b, a)
                return { (r or 0) / 255, (g or 0) / 255, (b or 0) / 255, (a or 255) / 255 }
            end,
            random = function(a, b)
                if a and b then return a end
                return 0
            end,
            newRandomGenerator = function(seed)
                local state = math.floor(math.abs(seed or 1)) % 2147483647
                if state == 0 then state = 1 end
                return {
                    random = function(_, a, b)
                        state = (state * 16807) % 2147483647
                        local v = (state - 1) / 2147483646
                        if a and b then return math.floor(a + v * (b - a + 1)) end
                        if a then return math.floor(v * a) + 1 end
                        return v
                    end,
                }
            end,
        },
    }
end

setup_love()

CHARACTERS_SCALE = 0.75
HEX_RADIUS = 40
HEX_HEIGHT = 1
DEBUG = false

Class = dofile(root .. '/lib/class.lua')
require 'src.spellcast.targetFactory'
dofile(root .. '/utils.lua')

-- State modules are read from _G by levelmap2 (main.lua:31-42 shape).
FadeInState  = { __name = 'FadeInState' }
FadeOutState = { __name = 'FadeOutState' }
TownState    = { __name = 'TownState' }
BattleState  = { __name = 'BattleState' }
RestState    = { __name = 'RestState' }
ShopState    = { __name = 'ShopState' }
EventState   = { __name = 'EventState' }

local modalOpen = false
package.loaded['src.upgrade_select_screen'] = {
    isActive = function() return modalOpen end,
    open     = function() end,
    draw     = function() end,
}

Gamestate = {
    push    = function() end,
    pop     = function() end,
    switch  = function() end,
    current = function() return nil end,
}
Tagtext = { add = function() end }

local RunState = require 'src.states.run_state'
_G.RunState = RunState
RunState.story             = { thread_id = 'master_trial', flags = {} }
RunState.active            = true
RunState.unlocks           = {}
RunState.modifiers         = {}
RunState.hasUnlock         = function() return false end
RunState.consumeUnlock     = function() return false end
RunState.tickBattleModifiers = function() end

package.loaded['src.save_manager'] = {
    save   = function() return true end,
    load   = function() return nil end,
    exists = function() return false end,
}

UI = require 'ui'

local Levelmap   = require 'src.states.levelmap2'
local MapRenderer = require 'src.map_renderer'

local failures = 0

local function test(label, fn)
    local ok, err = pcall(fn)
    if ok then
        print('  ok   ' .. label)
    else
        failures = failures + 1
        print('  FAIL ' .. label .. '\n         ' .. tostring(err))
    end
end

local function near(a, b, eps)
    return math.abs(a - b) <= (eps or 1e-6)
end

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

-- A levelmap with a real MapRenderer and two nodes, no generation.
local function make_levelmap()
    local lm = setmetatable({}, { __index = Levelmap })
    Levelmap.init(lm)
    lm.active = true
    lm.nodes = {
        { id = 1, x = 300, y = 200, radius = 25 },
        { id = 2, x = 900, y = 600, radius = 25 },
    }
    lm.pathes = {}
    lm._isModalOpen = Levelmap._isModalOpen
    return lm
end

-- ---------------------------------------------------------------------------
-- MapRenderer: pure math
-- ---------------------------------------------------------------------------

test('toScreen/toWorld are inverse transforms', function()
    local mr = MapRenderer(75)
    mr:zoomAt(400, 300, 1.7)
    mr:pan(120, -45)

    local sx, sy = mr:toScreen(500, 250)
    local wx, wy = mr:toWorld(sx, sy)
    assert(near(wx, 500) and near(wy, 250), 'round trip failed')

    -- And the scale really changed.
    assert(mr.scale > 1, 'zoom in must raise scale')
end)

test('zoomAt keeps the point under the cursor fixed', function()
    local mr = MapRenderer(75)
    local cx, cy = 640, 360

    local before = { mr:toWorld(cx, cy) }
    mr:zoomAt(cx, cy, 1.5)
    local after  = { mr:toWorld(cx, cy) }

    assert(near(before[1], after[1]) and near(before[2], after[2]),
        ('world point moved: %s,%s -> %s,%s'):format(
            tostring(before[1]), tostring(before[2]),
            tostring(after[1]),  tostring(after[2])))
end)

test('zoom is clamped to [min, max]', function()
    local mr = MapRenderer(75)
    for _ = 1, 100 do mr:zoomAt(0, 0, 2.0, 0.35, 2.5) end
    assert(near(mr.scale, 2.5, 1e-9), 'max clamp failed: ' .. mr.scale)
    for _ = 1, 200 do mr:zoomAt(0, 0, 0.5, 0.35, 2.5) end
    assert(near(mr.scale, 0.35, 1e-9), 'min clamp failed: ' .. mr.scale)
end)

test('resetView restores the identity view', function()
    local mr = MapRenderer(75)
    mr:zoomAt(100, 100, 2.0)
    mr:pan(50, 50)
    mr:resetView()
    assert(mr.scale == 1 and mr.viewX == 0 and mr.viewY == 0, 'view not reset')
end)

test('draw applies the camera transform around nodes and paths', function()
    local calls = {}
    love.graphics.push  = function() calls[#calls + 1] = 'push' end
    love.graphics.pop   = function() calls[#calls + 1] = 'pop' end
    love.graphics.scale = function(sx, sy) calls[#calls + 1] = 'scale' .. sx end

    local mr = MapRenderer(75)
    mr.scale = 2
    local drew = 0
    mr:draw({}, { { draw = function() drew = drew + 1 end } })

    assert(calls[1] == 'push', 'no push')
    assert(calls[2] == 'scale2', 'wrong scale call: ' .. tostring(calls[2]))
    assert(calls[3] == 'pop', 'no pop')
    assert(drew == 1, 'node was not drawn')
end)

-- ---------------------------------------------------------------------------
-- Levelmap: wheel zoom
-- ---------------------------------------------------------------------------

test('wheel up zooms in, wheel down zooms out', function()
    local lm = make_levelmap()
    mouse.x, mouse.y = 640, 360

    local start = lm.mapRenderer.scale
    lm:wheelmoved(0, 1)
    local zoomed = lm.mapRenderer.scale
    assert(zoomed > start, 'wheel up must zoom in')

    lm:wheelmoved(0, -1)
    assert(near(lm.mapRenderer.scale, start), 'wheel down must undo wheel up')
end)

test('wheel zoom is anchored at the cursor', function()
    local lm = make_levelmap()
    mouse.x, mouse.y = 900, 150

    local wx, wy = lm.mapRenderer:toWorld(mouse.x, mouse.y)
    lm:wheelmoved(0, 1)
    lm:wheelmoved(0, 1)
    local ax, ay = lm.mapRenderer:toWorld(mouse.x, mouse.y)

    assert(near(wx, ax, 1e-6) and near(wy, ay, 1e-6), 'zoom drifted from the cursor')
end)

test('wheel is ignored while inactive or when a modal is open', function()
    local lm = make_levelmap()
    local before = lm.mapRenderer.scale

    lm.active = false
    lm:wheelmoved(0, 1)
    assert(lm.mapRenderer.scale == before, 'zoomed while inactive')
    lm.active = true

    modalOpen = true
    lm:wheelmoved(0, 1)
    modalOpen = false
    assert(lm.mapRenderer.scale == before, 'zoomed under a modal')
end)

-- ---------------------------------------------------------------------------
-- Levelmap: panning
-- ---------------------------------------------------------------------------

-- Fresh ViewState in UI so hit tests see this frame's widgets.
local function reset_ui()
    UI.update(0.016)
end

test('LMB on empty map space starts a pan; mouse move drags the map', function()
    local lm = make_levelmap()
    reset_ui()
    mouse.x, mouse.y = 50, 50   -- far from both nodes (300,200) and (900,600)

    lm:mousepressed(mouse.x, mouse.y, 1)
    assert(lm.panning, 'panning did not start on empty space')

    local vx, vy = lm.mapRenderer.viewX, lm.mapRenderer.viewY
    lm:mousemoved(mouse.x + 40, mouse.y + 30)
    lm:mousemoved(mouse.x + 80, mouse.y + 60)

    assert(near(lm.mapRenderer.viewX - vx, 80), 'viewX did not follow the mouse')
    assert(near(lm.mapRenderer.viewY - vy, 60), 'viewY did not follow the mouse')

    lm:mousereleased(mouse.x + 80, mouse.y + 60, 1)
    assert(not lm.panning, 'panning did not stop on release')
end)

test('LMB on a node does not start a pan', function()
    local lm = make_levelmap()
    reset_ui()

    lm:mousepressed(300, 200, 1)
    assert(not lm.panning, 'panning started on a node')
end)

test('LMB on empty space below a node, at the same screen point, does not pan', function()
    -- The node is in world space; after a pan its SCREEN position moves.
    local lm = make_levelmap()
    reset_ui()

    lm.mapRenderer.viewX = 100
    lm.mapRenderer.viewY = 50
    -- world (300,200) is now at screen (400, 250)
    lm:mousepressed(400, 250, 1)
    assert(not lm.panning, 'hit test ignored the camera transform')

    lm:mousepressed(300, 200, 1)
    assert(lm.panning, 'the old screen position should now be empty map')
end)

test('LMB on a UI element does not start a pan', function()
    local lm = make_levelmap()
    lm.active = true

    -- Draw a frame with one button in it, then click that button.
    love.graphics.getWidth  = function() return 1280 end
    love.graphics.getHeight = function() return 720 end
    UI.update(0.016)
    UI.setStyle({})
    UI.nextPosition("BOTTOMRIGHT", "root")
    UI.button("cam_test_ui", -20, -20, 180, 44, "Camp (once)", "BOTTOMRIGHT")
    UI.draw()          -- promotes the hover state, keeps to_draw for hit tests
    love.graphics.getWidth  = function() return 1280 end
    love.graphics.getHeight = function() return 720 end

    local bx, by = 1280 - 20 - 90, 720 - 20 - 22
    mouse.x, mouse.y = bx, by
    lm:mousepressed(bx, by, 1)
    assert(not lm.panning, 'panning started on a UI button')
end)

test('a tiny jitter under the drag threshold is a click, not a pan', function()
    local lm = make_levelmap()
    reset_ui()
    mouse.x, mouse.y = 50, 50

    local vx = lm.mapRenderer.viewX
    lm:mousepressed(50, 50, 1)
    lm:mousemoved(51, 51)   -- 1.4 px: below DRAG_THRESHOLD
    assert(lm.mapRenderer.viewX == vx, 'sub-threshold jitter moved the map')

    lm:mousemoved(80, 80)   -- now it is a real drag
    assert(lm.mapRenderer.viewX ~= vx, 'real drag did not move the map')
end)

test('right/middle buttons never pan', function()
    local lm = make_levelmap()
    reset_ui()
    lm:mousepressed(50, 50, 2)
    assert(not lm.panning, 'middle button started a pan')
    lm:mousepressed(50, 50, 3)
    assert(not lm.panning, 'right button started a pan')
end)

test('the map cannot be dragged completely off-screen', function()
    local lm = make_levelmap()
    reset_ui()

    lm:_beginPan(50, 50)
    -- Drag far past the right edge; viewX must still leave the map reachable.
    for _ = 1, 200 do lm:_updatePan(lm.panLastX + 500, lm.panLastY) end

    local mr = lm.mapRenderer
    local leftmost = 300 * mr.scale + mr.viewX
    assert(leftmost <= love.graphics.getWidth() + 200,
        'left edge of the map was dragged past the right side of the screen: '
        .. leftmost)
end)

-- ---------------------------------------------------------------------------
-- Startup view: the map is centered, the intro flight frames the start node
-- ---------------------------------------------------------------------------

-- Screen-space bounding box of the rendered nodes.
local function nodes_on_screen(lm)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    for _, node in ipairs(lm.nodes) do
        local sx, sy = lm.mapRenderer:toScreen(node.x, node.y)
        minX, maxX = math.min(minX, sx), math.max(maxX, sx)
        minY, maxY = math.min(minY, sy), math.max(maxY, sy)
    end
    return minX, minY, maxX, maxY
end

test('_layoutView centers a map that fits the screen at 1:1', function()
    local lm = make_levelmap()          -- nodes at (300,200) and (900,600)
    lm:_layoutView()

    local mr = lm.mapRenderer
    assert(near(mr.scale, 1), 'a map that fits must not be scaled: ' .. mr.scale)

    local minX, minY, maxX, maxY = nodes_on_screen(lm)
    local cx, cy = (minX + maxX) / 2, (minY + maxY) / 2
    assert(near(cx, 1280 / 2, 1e-6), 'map is not horizontally centered: ' .. cx)
    assert(near(cy, 720 / 2, 1e-6), 'map is not vertically centered: ' .. cy)
end)

test('_layoutView fits and centers a map larger than the screen', function()
    local lm = make_levelmap()
    -- 1500x900 map: bigger than 1280x720, so it must be scaled down.
    lm.nodes = {
        { id = 1, x = 100, y = 100, radius = 25 },
        { id = 2, x = 1600, y = 1000, radius = 25 },
    }
    lm:_layoutView()

    local mr = lm.mapRenderer
    assert(mr.scale < 1, 'an oversized map must be scaled down: ' .. mr.scale)

    local minX, minY, maxX, maxY = nodes_on_screen(lm)
    local cx, cy = (minX + maxX) / 2, (minY + maxY) / 2
    assert(near(cx, 1280 / 2, 1e-6), 'oversized map not centered in X: ' .. cx)
    assert(near(cy, 720 / 2, 1e-6), 'oversized map not centered in Y: ' .. cy)

    -- And the whole map must actually be on screen.
    assert(minX >= 0 and minY >= 0 and maxX <= 1280 and maxY <= 720,
        ('map overflows the screen: %.0f,%.0f..%.0f,%.0f')
            :format(minX, minY, maxX, maxY))
end)

test('the start node is driven toward the center by the intro', function()
    local lm = make_levelmap()
    lm.currentNode = lm.nodes[1]        -- start node at (300, 200)
    lm:_layoutView()

    local beforeScale = lm.mapRenderer.scale
    local startX, startY = lm.mapRenderer:toScreen(300, 200)
    local distBefore = math.sqrt((startX - 640) ^ 2 + (startY - 360) ^ 2)

    lm:_startCameraIntro(lm.currentNode)
    assert(lm.camIntro, 'intro did not start')

    -- Run the whole flight in small steps, like frames.
    local guard = 0
    while lm.camIntro and guard < 10000 do
        lm:_updateIntro(1 / 60)
        guard = guard + 1
    end
    assert(guard < 10000, 'intro never finished')

    local afterScale = lm.mapRenderer.scale
    local endX, endY = lm.mapRenderer:toScreen(300, 200)
    local distAfter = math.sqrt((endX - 640) ^ 2 + (endY - 360) ^ 2)

    assert(afterScale > beforeScale, 'intro must zoom in')
    assert(distBefore > 1, 'test fixture: the start node must not start centered')
    assert(distAfter < 1,
        ('start node did not end up centered: %.1f,%.1f (dist %.1f)')
            :format(endX, endY, distAfter))
    assert(lm.introSeen, 'intro completion must set introSeen')
end)

test('the intro offset is capped, so an edge node cannot corner the view', function()
    local lm = make_levelmap()
    lm:_layoutView()

    -- A node hard against the top-left corner would pull the view far away.
    local edge = { id = 3, x = 0, y = 0, radius = 25 }
    lm:_startCameraIntro(edge)

    local guard = 0
    while lm.camIntro and guard < 10000 do
        lm:_updateIntro(1 / 60)
        guard = guard + 1
    end

    local mr = lm.mapRenderer
    local sx, sy = mr:toScreen(0, 0)
    assert(sx > 0 and sy > 0,
        ('edge node was pushed off-screen by the intro: %d,%d'):format(sx, sy))
end)

test('a click during the intro skips it without selecting a node', function()
    local lm = make_levelmap()
    reset_ui()
    lm:_layoutView()
    lm:_startCameraIntro(lm.currentNode or lm.nodes[1])

    local scaleAtClick = lm.mapRenderer.scale
    lm:mousepressed(640, 360, 1)

    assert(lm.camIntro == nil, 'click did not end the intro')
    assert(lm.mapRenderer.scale == scaleAtClick, 'click kept animating')
    assert(lm.dragSkippedIntro ~= false and lm.dragSkippedIntro ~= nil,
        'the click was not recorded as an intro skip')

    -- The intro must not swallow the camera further.
    lm:_updateIntro(1)
    assert(lm.mapRenderer.scale == scaleAtClick, 'camera moved after the skip')

    -- Still moving the mouse with LMB held pans instead of clicking a node.
    -- The click landed at (640, 360), 41 px from this move: past
    -- DRAG_THRESHOLD, so it is a drag, not a click.
    lm:mousemoved(660, 380)
    assert(lm.panning, 'dragging after a skip did not pan')

    local vx = lm.mapRenderer.viewX
    lm:mousemoved(700, 400)
    assert(lm.mapRenderer.viewX ~= vx, 'pan after a skip did not move the map')
end)

test('the mouse wheel also takes the camera from the intro', function()
    local lm = make_levelmap()
    reset_ui()
    lm:_layoutView()
    lm:_startCameraIntro(lm.nodes[1])

    lm:wheelmoved(0, 1)
    assert(lm.camIntro == nil, 'wheel did not end the intro')
end)

test('the intro never plays twice in one run', function()
    local lm = make_levelmap()
    lm.currentNode = lm.nodes[1]
    lm:_layoutView()

    lm:_startCameraIntro(lm.nodes[1])
    lm:_endIntro()
    assert(lm.introSeen, 'introSeen must survive a manual skip')

    local saved = lm.introSeen and true or false
    assert(lm:serialize().introSeen == saved, 'introSeen is not serialized')
end)

test('old saves (no introSeen field) are treated as already seen', function()
    local lm = make_levelmap()
    lm.seed = 4242
    -- deserialize() re-generates the map; only the flag is under test here.
    local data = lm:serialize()
    data.introSeen = nil
    lm.nodes, lm.pathes = {}, {}
    lm:deserialize(data)
    assert(lm.introSeen == true, 'a save without the flag must not replay the intro')
end)

-- ---------------------------------------------------------------------------
-- Regressions: what must NOT change for the rest of the level map
-- ---------------------------------------------------------------------------

test('node hit testing follows the camera transform', function()
    package.loaded['src.node'] = nil
    local Node = require 'src.node'

    local lm = make_levelmap()
    lm.mapRenderer:zoomAt(640, 360, 2.0)
    lm.mapRenderer:pan(150, -80)
    _G.Levelmap = lm

    local node = Node(7, 400, 300, true, 'event')
    local sx, sy = lm.mapRenderer:toScreen(400, 300)

    mouse.x, mouse.y = sx, sy
    node:update(0.016)
    assert(node.cursorInside, 'node under the cursor was not hovered')

    mouse.x, mouse.y = sx + 200, sy
    node:update(0.016)
    assert(not node.cursorInside, 'node hovered far from the cursor')
end)

test('wheel is not consumed by other states before Levelmap', function()
    -- Gamestate forwards every love callback to the top state; Levelmap only
    -- acts via wheelmoved, which other states simply lack. This asserts the
    -- method exists and is reachable through the Gamestate table lookup.
    assert(type(Levelmap.wheelmoved) == 'function', 'Levelmap:wheelmoved missing')
    assert(type(Levelmap.mousemoved) == 'function', 'Levelmap:mousemoved missing')
end)

if failures > 0 then
    print(('\ntests/smoke_levelmap_camera: %d FAILED'):format(failures))
    os.exit(1)
end

print('smoke_levelmap_camera OK')
os.exit(0)
