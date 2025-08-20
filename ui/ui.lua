function UI()
    local ui = {
        window = nil;
        windowContents = nil;
        menuButton = nil;
        updateEvent = false;

        init = function(self)
            g_keyboard.bindKeyDown('Ctrl+E', function() ui:toggle() end)

            self.menuButton = modules.client_topmenu.addRightGameToggleButton('expTrackerButton', tr('Exp Tracker') .. ' (Ctrl+E)', '/exp_tracker/ui/icon', function() ui:toggle() end)
            self.menuButton:setOn(true)

            self.window = g_ui.loadUI('window', modules.game_interface.getRightPanel())
            self.window:disableResize()
            self.windowContents = self.window:getChildById('expTrackerWindowContents')
            self.window:setup()
            self:setupUI()
        end;

        terminate = function(self)
            if self.updateEvent ~= false then
                removeEvent(self.updateEvent)
                self.updateEvent = false
            end

            g_keyboard.unbindKeyDown('Ctrl+E')
            self.menuButton:destroy()
            self.menuButton = nil
            self.window:destroy()
            self.window = nil
        end;

        setupUI = function(self)
            -- Update Exp Tab
            local updateExp = function()
                local intervals = {60, 180, 300, 600, 900, 1800, 3600, 7200, 10800, 21600, 43200, 86400, 172800}
                for _, seconds in ipairs(intervals) do
                    local expLabel = self.windowContents:getChildById('exp' .. seconds)
                    local playersLabel = self.windowContents:getChildById('players' .. seconds)
                    expLabel:setText(expTracker:getExpForInterval(seconds) .. ' exp')
                    playersLabel:setText(expTracker:getUniquePlayersForInterval(seconds) .. ' players')
                end
            end

            -- Update Progress Tab
            local updateProgress = function()
                local timeToLevel = expTracker:getTimeToNextLevel()
                local levelAtStaminaEnd = expTracker:getLevelAtStaminaEnd()
                self.windowContents:getChildById('timeToLevel'):setText(math.floor(timeToLevel / 60) .. ' minutes')
                self.windowContents:getChildById('levelAtStaminaEnd'):setText(levelAtStaminaEnd)
            end

            -- Periodic UI updates
            if self.updateEvent == false then
                self.updateEvent = cycleEvent(function()
                    updateExp()
                    updateProgress()
                end, 1000)
            end
        end;

        close = function(self)
            self.window:close()
            self.menuButton:setOn(false)
        end;

        open = function(self)
            self.window:open()
            self.menuButton:setOn(true)
        end;

        toggle = function(self)
            if self.menuButton:isOn() then
                self:close()
            else
                self:open()
            end
        end;
    }

    return ui
end
