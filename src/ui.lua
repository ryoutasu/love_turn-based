local UI = Class{}
local skip = require 'src.actions.skip_turn'

function UI:init(urutora, x, y)
    self.x = x
    self.y = y
    self.u = urutora

    local w = 200
    local h = (love.graphics.getHeight() - y) / 2 - 10
    self.w = w
    self.h = h

    self.queue_list_x = x + w + 15
    self.queue_list_y = y

    local skipButton = Urutora.button({
        x = x, y = y,
        w = w, h = h,
        text = 'Skip'
    })
    :action(function(e)
        BattleState:current_actor():set_current_action(skip)
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

    y = y + h + 7.5

    local spellPanel = Urutora.panel({
        x = x, y = y,
        w = w, h = h,
        rows = 2, cols = 1,
        cellHeight = h/2
    })

    skipButton:disable()
    cancelButton:disable()
    spellPanel:disable()

    self.u:add(skipButton)
    self.u:add(cancelButton)
    self.u:add(spellPanel)
    
    self.skipButton = skipButton
    self.cancelButton = cancelButton
    self.spellPanel = spellPanel

    self.awaiting = {}
end

function UI:start_turn(actor)
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

function UI:end_turn()
    
end

function UI:show_cancel_button(show)
    self.skipButton:setEnabled(not show):setVisible(not show)
    self.cancelButton:setEnabled(show):setVisible(show)
end

function UI:disable()
    self.cancelButton:hide():disable()
    self.skipButton:disable()
    self.spellPanel:disable()
end

function UI:clear()
    if self.cancelButton then self.u:remove(self.cancelButton) end
    if self.skipButton then self.u:remove(self.skipButton) end
    if self.spellPanel then self.u:remove(self.spellPanel) end
end

return UI