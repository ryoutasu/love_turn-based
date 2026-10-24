local CommandPanel = Class{}

local margin = 15
local skipButtonWidth = 160
local skipButtonHeight = 100

function CommandPanel:init()
    self.show_cancel = false
end

function CommandPanel:show_cancel_button(show)
    self.show_cancel = show
end

function CommandPanel:disable()
    self.show_cancel = false
end

function CommandPanel:update(dt)
    UI.setStyle()
    UI.nextPosition("BOTTOMLEFT", "root")
    if BattleState.state == 'prepare' then
        if UI.button("prepare_ready", margin, -margin, skipButtonWidth, skipButtonHeight, "Ready", "BOTTOMLEFT") then
            PlaySound(ButtonClickSound)
            BattleState:startBattle()
        end
    end

    if BattleState.state == 'battle' then
        local actor = BattleState:current_actor()

        local is_active = BattleState.phase == 'idle'

        if self.show_cancel then
            if UI.button("battle_cancel", margin, -margin, skipButtonWidth, skipButtonHeight, "Cancel", "BOTTOMLEFT") then
                PlaySound(ButtonClickSound)
                BattleState:cancel_target_mode()
            end
        else
            if UI.button("battle_wait", margin, -margin, skipButtonWidth, skipButtonHeight, "Wait", "BOTTOMLEFT", is_active) then
                PlaySound(ButtonClickSound)
                BattleState:add_action('skip_turn', BattleState:current_actor())
            end
        end

        local spells = actor:get_spells()
        if spells then
            for i, spell in pairs(spells) do
                local text = spell.name
                local disabled = false
                if spell.current_cooldown > 0 then
                    text = text .. ' : ' .. tonumber(spell.current_cooldown)
                    disabled = true
                end

                UI.nextPosition("TOPLEFT")
                if UI.button("spell_"..i, 0, -margin, skipButtonWidth, skipButtonHeight / 2, text, "BOTTOMLEFT", is_active and not disabled) then
                    PlaySound(ButtonClickSound)
                    BattleState:set_target_mode(spell)
                end
            end
        end
    end
end

return CommandPanel