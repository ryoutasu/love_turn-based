local Animation = require 'src.animation'

return function (x, y, w, h, frames, frame_time)
    x = x or 0
    y = y or 96
    frames = frames or 7
    w = w or 32
    h = h or 48

    local animation = Animation('resources/simplefx-alpha.png', true)
    for i = 1, frames do
        animation:add_frame(x, y, w, h)
        x = x + w
    end
    animation.frameTime = frame_time or 0.25

    return animation
end