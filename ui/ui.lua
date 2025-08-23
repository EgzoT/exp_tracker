function UI()
    local ui = {
        window = nil;
        windowContents = nil;
        menuButton = nil;
        optionPanel = nil;
        updateEvent = false;

        init = function(self)
            g_keyboard.bindKeyDown('Ctrl+E', function() ui:toggle() end)

            self.menuButton = modules.client_topmenu.addRightGameToggleButton('expTrackerButton', tr('Exp Tracker') .. ' (Ctrl+E)', '/exp_tracker/ui/icon', function() ui:toggle() end)
            self.menuButton:setOn(true)

            self.window = g_ui.loadUI('window', modules.game_interface.getRightPanel())
            self.window:disableResize()
            self.windowContents = self.window:getChildById('expTrackerWindowContents')
            self.window:setup()
            self:addToOptionsModule()
            self:setupUI()
        end;

        terminate = function(self)
            if self.updateEvent ~= false then
                removeEvent(self.updateEvent)
                self.updateEvent = false
            end

            g_keyboard.unbindKeyDown('Ctrl+E')
            self:destroyOptionsModule()
            self.menuButton:destroy()
            self.menuButton = nil
            self.window:destroy()
            self.window = nil
        end;

        setupUI = function(self)
            local adjustedBtn = self.windowContents:getChildById('modeAdjusted')
            local rawBtn = self.windowContents:getChildById('modeRaw')

            adjustedBtn.onClick = function()
                expTracker.currentMode = 'adjusted'
                self:setButtonStates()
            end

            rawBtn.onClick = function()
                expTracker.currentMode = 'raw'
                self:setButtonStates()
            end

            self:setButtonStates()

            -- Update Exp Tab
            local updateExp = function()
                local intervals = {60, 180, 300, 600, 900, 1800, 3600, 7200, 10800, 21600, 43200, 86400, 172800}
                for _, seconds in ipairs(intervals) do
                    local expLabel = self.windowContents:getChildById('exp' .. seconds)
                    local playersLabel = self.windowContents:getChildById('players' .. seconds)
                    expLabel:setText(expTracker:getExpForInterval(seconds, expTracker.currentMode) .. ' exp')
                    playersLabel:setText(expTracker:getUniquePlayersForInterval(seconds) .. ' players')
                end
            end

            -- Update Progress Tab
            local updateProgress = function()
                local timeToLevel = expTracker:getTimeToNextLevel()
                local levelAtStaminaEnd = expTracker:getLevelAtStaminaEnd()
                self.windowContents:getChildById('timeToLevel'):setText(self:formatTime(timeToLevel))
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

        setButtonStates = function(self)
            local adjustedBtn = self.windowContents:getChildById('modeAdjusted')
            local rawBtn = self.windowContents:getChildById('modeRaw')
            if expTracker.currentMode == 'adjusted' then
                adjustedBtn:setColor('green')
                rawBtn:setColor('white')
            else
                adjustedBtn:setColor('white')
                rawBtn:setColor('green')
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

        -- Format time in seconds to a concise string (days, hours, minutes)
        formatTime = function(self, seconds)
            if seconds < 3600 then -- Less than 1 hour
                local minutes = math.floor(seconds / 60)
                return minutes .. " minutes"
            elseif seconds < 86400 then -- Less than 1 day
                local hours = math.floor(seconds / 3600)
                local minutes = math.floor((seconds % 3600) / 60)
                if minutes == 0 then
                    return hours .. " hours"
                end
                return hours .. " hours " .. minutes .. " minutes"
            else -- 1 day or more
                local days = math.floor(seconds / 86400)
                local hours = math.floor((seconds % 86400) / 3600)
                local minutes = math.floor((seconds % 3600) / 60)
                local parts = {days .. " days"}
                if hours > 0 then
                    table.insert(parts, hours .. " hours")
                end
                if minutes > 0 then
                    table.insert(parts, minutes .. " min")
                end
                return table.concat(parts, " ")
            end
        end;

        addToOptionsModule = function(self)
            -- Add to options module
            self.optionPanel = g_ui.loadUI('options')
            modules.client_options.addTab(tr('Exp Tracker'), self.optionPanel, '/exp_tracker/ui/options_icon')

            -- Setup stamina checkbox
            local staminaCheckbox = self.optionPanel:getChildById('staminaCheckbox')
            staminaCheckbox:setChecked(expTracker:getStateManager():get('staminaEnabled'))
            staminaCheckbox.onClick = function()
                expTracker:getStateManager():set('staminaEnabled', not staminaCheckbox:isChecked())
            end
            -- Listen for staminaEnabled state changes
            expTracker:getStateManager():onStateChange('staminaEnabled', function(value)
                staminaCheckbox:setChecked(value)
            end)
        end;

        destroyOptionsModule = function(self)
            if self.optionPanel then
                self.optionPanel:destroy()
                self.optionPanel = nil
            end

            if modules.client_options.removeTab then
                modules.client_options.removeTab('Exp Tracker')
            end
            self.optionPanel = nil
        end
    }

    return ui
end
