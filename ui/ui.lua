function UI()
    local ui = {
        window = nil;
        button = nil;

        init = function(self)
            g_keyboard.bindKeyDown('Ctrl+E', function() ui:toggle() end)

            self.button = modules.client_topmenu.addRightGameToggleButton('expTrackerButton', tr('Exp tracker') .. ' (Ctrl+E)', '/exp_tracker/ui/icon', function() ui:toggle() end)
            self.button:setOn(true)

            self.window = g_ui.loadUI('window', modules.game_interface.getRightPanel())
            self.window:disableResize()

            self.window:setup()
        end;

        terminate = function(self)
            g_keyboard.unbindKeyDown('Ctrl+E')

            self:clear()
        end;

        clear = function(self)
            -- Menu right button
            self.button:destroy()
            self.button = nil

            -- Main
            self.window:destroy()
            self.window = nil
        end;

        close = function(self)
            self.window:close()
            self.button:setOn(false)
        end;

        open = function(self)
            self.window:open()
            self.button:setOn(true)
        end;

        toggle = function(self)
            if self.button:isOn() then
                self:close()
            else
                self:open()
            end
        end;
    }

    return ui
end
