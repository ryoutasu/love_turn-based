local CommandPanel = Class{}
local skip = require 'src.actions.skip_turn'

function CommandPanel:init(urutora, x, y)
    self.x = x
    self.y = y
    self.u = urutora

    local w = 160
    local h = (love.graphics.getHeight() - y) / 2 - 10
    self.w = w
    self.h = h

    local skipButton = Urutora.button({
        x = x, y = y,
        w = w, h = h,
        text = 'Skip'
    })
    :action(function(e)
        BattleState:add_action(skip(BattleState:current_actor()))
    end)
    local cancelButton = Urutora.button({
        x = x, y = y,
        w = w, h = h,
        text = 'Cancel'
    })
    cancelButton:action(function(e)
        BattleState:cancel_target_mode()
        self:show_cancel_button(false)
    end)
    :hide()

    local readyButton = Urutora.button({
        x = x, y = y,
        w = w, h = h,
        text = 'Ready'
    })
    readyButton:action(function(e)
        BattleState:start_turn()
        self.readyButton:setEnabled(false):setVisible(false)
    end)
    :hide()

    y = y + h + 7.5

    local spellPanel = Urutora.panel({
        x = x, y = y,
        w = w, h = h,
        rows = 2, cols = 1,
        cellHeight = h/2
    })

    skipButton:disable()
    cancelButton:disable()
    readyButton:disable()
    spellPanel:disable()

    self.u:add(skipButton)
    self.u:add(cancelButton)
    self.u:add(readyButton)
    self.u:add(spellPanel)
    
    self.skipButton = skipButton
    self.cancelButton = cancelButton
    self.readyButton = readyButton
    self.spellPanel = spellPanel
end

function CommandPanel:start_turn(actor)
    self.skipButton:enable()
    self.spellPanel:enable()
    self.spellPanel:clear()

    local spells = actor:get_spells()
    self.spellPanel.rows = #spells

    for i, spell in pairs(spells) do
        local btn = Urutora.button({ text = spell.name })
        :action(function(e)
            BattleState:set_target_mode(spell)
        end)

        self.spellPanel:addAt(i, 1, btn)
    end
    self.spellPanel:setScrollY(0)
end

function CommandPanel:end_turn()
    self.spellPanel:clear()
end

function CommandPanel:show_cancel_button(show)
    self.skipButton:setEnabled(not show):setVisible(not show)
    self.cancelButton:setEnabled(show):setVisible(show)
end

function CommandPanel:disable()
    self.cancelButton:hide():disable()
    self.readyButton:hide():disable()
    self.skipButton:disable()
    self.spellPanel:disable()
end

function CommandPanel:clear()
    if self.cancelButton then self.u:remove(self.cancelButton) end
    if self.readyButton then self.u:remove(self.readyButton) end
    if self.skipButton then self.u:remove(self.skipButton) end
    if self.spellPanel then self.u:remove(self.spellPanel) end
end

return CommandPanel