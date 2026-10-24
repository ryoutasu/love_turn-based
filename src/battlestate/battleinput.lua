local move = require 'src.actions.move'
local attack = require 'src.actions.attack'
local Actions = require 'src.actions'

local BattleInput = Class{}

function BattleInput:init(state)
    self.state = state
end

function BattleInput:mousepressed(x, y, button)
    local state = self.state
    local actor = state:current_actor()
    local tile  = state.map.highlighted

    if button == 1 then
        -- 1. Target mode (spell/item) — приоритет, отдельная ветка.
        if state.target_mode == 'targeting' then
            if tile and tile.can_be_selected then
                local a = state.action_type == 'item' and state.player or actor
                local action = Actions[state.action_type](a, state.current_spell, tile)
                if not action.is_aborted then
                    state:add_action(action)
                    state.current_spell = nil
                else
                    Tagtext:add('Not enough energy!', a.x - 25, a.y - 40, 2, 30, {1,1,1})
                end
                state:cancel_target_mode()
                PlaySound(ButtonClickSound)
            end
            return  -- не запускаем drag/клик-попап
        end

        -- 2. Prepare: регистрируем press. Drag/попап решаются на release.
        if state.state == 'prepare' then
            state:preparePress(tile)
            return
        end

        -- 3. Battle: регистрируем press. Drag/попап решаются на release.
        if state.state == 'battle' then
            state:battlePress(tile)
            return
        end
    end

    if button == 2 then
        if state.target_mode == 'none' and state.phase == 'idle' then
            if tile then
                if tile.is_open then
                    state:add_action(move(actor, tile:get_path(), state.pathfinder))
                elseif tile.can_be_selected then
                    if actor.attack_range == 1 and tile.range > 1 then
                        state:add_action(move(actor, tile.parent:get_path(), state.pathfinder, tile.actor))
                    else
                        state:add_action(attack(actor, tile.actor))
                    end
                end
            end
        end

        if state.target_mode == 'drawing_path' then
            state.map:stop_drawing_path()
        end

        -- ПКМ в prepare — отмена drag/захвата
        if state.state == 'prepare' then
            if state.grabbed_actor or state.pressed_actor then
                state:cancelPrepareDrag()
                PlaySound(ButtonClickSound)
            end
        end

        -- ПКМ в бою во время drag — отмена пути
        if state.state == 'battle' and state.target_mode == 'drawing_path' then
            state.map:stop_drawing_path()
            state.pressed_tile  = nil
            state.drag_started  = false
        end
    end

    state.inventory:mousepressed(x, y)
end

function BattleInput:mousemoved(x, y, dx, dy)
    local state = self.state
    if state.state == 'prepare' then
        state:prepareMove(x, y, dx, dy)
    elseif state.state == 'battle' then
        state:battleMove(x, y, dx, dy)
    end
end

function BattleInput:mousereleased(x, y, button)
    local state = self.state

    if button == 1 then
        if state.state == 'prepare' then
            state:prepareRelease(state.map.highlighted)
        elseif state.state == 'battle' then
            state:battleRelease()
        end
    end
end

function BattleInput:keypressed(key, scancode, isrepeat)
    local state = self.state
    if key == 'escape' then
        if state.target_mode == 'targeting' then
            state:cancel_target_mode()
        elseif state.target_mode == 'drawing_path' then
            state.map:stop_drawing_path()
            state.pressed_tile = nil
            state.drag_started = false
        end
    end
    if key == 'f3' then
        state.result = 'win'
        state.state = 'result'
        state:showResult()
    end
    if key == 'f4' then
        state.result = 'lose'
        state.state = 'result'
        state:showResult()
    end
end

return BattleInput