function UI()
    local ui = {
        window = nil;
        windowContents = nil;
        menuButton = nil;
        optionPanel = nil;
        updateEvent = false;
        expStagesElementsUI = {};

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

            -- Setup exp stages UI
            self:setupExpStagesUI()
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

            -- Setup exp stages checkbox
            local expStagesCheckbox = self.optionPanel:getChildById('expStagesCheckbox')
            expStagesCheckbox:setChecked(expTracker:getStateManager():get('expStagesEnabled'))
            expStagesCheckbox.onClick = function()
                expTracker:getStateManager():set('expStagesEnabled', not expStagesCheckbox:isChecked())
            end
            -- Listen for expStagesEnabled state changes
            expTracker:getStateManager():onStateChange('expStagesEnabled', function(value)
                expStagesCheckbox:setChecked(value)
                self:updateExpStagesVisibility(value)
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
        end;

        -- Setup exp stages UI elements
        setupExpStagesUI = function(self)
            local expStagesList = self.optionPanel:getChildById('expStagesList')
            local prevButton = self.optionPanel:getChildById('prevButton')
            local nextButton = self.optionPanel:getChildById('nextButton')
            local removeButton = self.optionPanel:getChildById('removeButton')
            local levelMinInput = self.optionPanel:getChildById('levelMinInput')
            local levelMaxInput = self.optionPanel:getChildById('levelMaxInput')
            local multiplierInput = self.optionPanel:getChildById('multiplierInput')
            local addButton = self.optionPanel:getChildById('addButton')

            -- Setup exp stages
            expTracker:getStateManager():onStateChange('expStages', function()
                self:updateExpStagesList()
            end)

            -- Populate exp stages list
            self:updateExpStagesList()

            -- Update visibility based on initial state
            self:updateExpStagesVisibility(expTracker:getStateManager():get('expStagesEnabled'))

            -- Previous button
            prevButton.onClick = function()
                local focusedChild = expStagesList:getFocusedChild()
                local find = false
                for i = #self.expStagesElementsUI, 1, -1 do
                    if find then
                        expStagesList:focusChild(self.expStagesElementsUI[i])
                        break
                    end

                    if focusedChild == self.expStagesElementsUI[i] then
                        find = true
                    end
                end
            end

            -- Next button
            nextButton.onClick = function()
                local focusedChild = expStagesList:getFocusedChild()
                local find = false
                for i,_ in ipairs(self.expStagesElementsUI) do
                    if find then
                        expStagesList:focusChild(self.expStagesElementsUI[i])
                        break
                    end

                    if focusedChild == self.expStagesElementsUI[i] then
                        find = true
                    end
                end
            end

            -- Remove button
            removeButton.onClick = function()
                expTracker:removeExpStage(tonumber(expStagesList:getFocusedChild():getId()))
            end

            -- Add button
            addButton.onClick = function()
                local levelMin = tonumber(levelMinInput:getText())
                local levelMax = tonumber(levelMaxInput:getText())
                local multiplier = tonumber(multiplierInput:getText())
                if levelMin and levelMax and levelMin > 0 and levelMax >= levelMin then
                    expTracker:addExpStage(levelMin, levelMax, multiplier)
                    self:updateExpStagesList()
                    levelMinInput:setText('')
                    levelMaxInput:setText('')
                    multiplierInput:setText('')
                end
            end
        end;

        -- Update exp stages list UI
        updateExpStagesList = function(self)
            -- Delete
            for i,_ in pairs(self.expStagesElementsUI) do
                self.expStagesElementsUI[i]:destroy()
                self.expStagesElementsUI[i] = nil
            end

            -- Add
            local expStagesList = self.optionPanel:getChildById('expStagesList')
            local expStages = expTracker.stateManager:get('expStages')
            for i,v in pairs(expStages) do
                self.expStagesElementsUI[i] = g_ui.createWidget('ListLabel', expStagesList)
                local name = v.levelMin .. '-' .. v.levelMax .. ' [' .. v.multiplier .. 'x]'
                self.expStagesElementsUI[i]:setText(name)
                self.expStagesElementsUI[i]:setId(i)
            end

            --[[
            local expStagesList = self.optionPanel:getChildById('expStagesList')
            -- TODO
            -- expStagesList:clear()
            for _, stage in ipairs(expTracker:getExpStages()) do
                expStagesList:addOption(string.format("Level %d-%d: %.2fx", stage.levelMin, stage.levelMax, stage.multiplier))
            end
            if #expTracker:getExpStages() > 0 then
                expStagesList:moveToIndex(1)
            end
            ]]
        end;

        -- Update visibility of exp stages UI elements
        updateExpStagesVisibility = function(self, isVisible)
            local elements = {
                'expStagesList',
                'expStagesScrollBar',
                'prevButton',
                'nextButton',
                'removeButton',
                'levelMinLabel',
                'levelMinInput',
                'levelMaxLabel',
                'levelMaxInput',
                'multiplierLabel',
                'multiplierInput',
                'addButton'
            }
            for _, id in ipairs(elements) do
                local widget = self.optionPanel:getChildById(id)
                if isVisible then
                    widget:show()
                else
                    widget:hide()
                end
            end
        end;
    }

    return ui
end
