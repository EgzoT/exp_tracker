dofile('tools/stateManager')

function ExpTrackerSystem()
    local system = {
        configFile = '/exp_tracker/config.json';
        isInit = false;
        trackExpEvent = false;
        cleanOldDataEvent = false;
        currentMode = 'adjusted';
        stateManager = StateManager({ staminaEnabled = true, expStagesEnabled = true, expStages = {} });

        -- Time intervals for exp tracking (in seconds)
        timeIntervals = {60, 180, 300, 600, 900, 1800, 3600, 7200, 10800, 21600, 43200, 86400, 172800};

        -- Experience data storage
        expData = {
            history = {}, -- Stores exp gains with timestamps
            deaths = {}, -- Stores death events
            lastExp = 0,
            currentLevel = 0,
            currentExp = 0,
            playerMap = {}, -- Maps player names to unique IDs
            nextPlayerId = 1,
            playerEvents = {}, -- List of player visibility events: {id, appear, disappear}
            uniquePlayers = {} -- Maps player ID to last update timestamp for unique count optimization
        };

        -- Module initialization
        init = function(self)
            if not self.isInit then
                self:loadConfig()
                self:connect()

                self.trackExpEvent = cycleEvent(function() self:trackExp() end, 1000)
                self.cleanOldDataEvent = cycleEvent(function() self:cleanOldData() end, 60000)

                -- Listen for changes to save config
                self.stateManager:onStateChange('staminaEnabled', function() self:saveConfig() end)
                self.stateManager:onStateChange('expStagesEnabled', function() self:saveConfig() end)

                self.isInit = true
            end
        end;

        -- Module termination
        terminate = function(self)
            if self.isInit then
                self:disconnect()
                if self.trackExpEvent ~= false then
                    removeEvent(self.trackExpEvent)
                    self.trackExpEvent = false
                end
                if self.cleanOldDataEvent ~= false then
                    removeEvent(self.cleanOldDataEvent)
                    self.cleanOldDataEvent = false
                end

                self.isInit = false
            end
        end;

        connect = function(self)
            connect(g_game, { onDeath = self.onDeath })
            connect(LocalPlayer, { onPositionChange = self.onLocalPlayerPositionChange })
            connect(Player, {
                onAppear = self.onPlayerAppear,
                onDisappear = self.onPlayerDisappear,
                onPositionChange = self.onPlayerPositionChange
            })
        end;

        disconnect = function(self)
            disconnect(g_game, { onDeath = self.onDeath })
            disconnect(LocalPlayer, { onPositionChange = self.onLocalPlayerPositionChange })
            disconnect(Player, {
                onAppear = self.onPlayerAppear,
                onDisappear = self.onPlayerDisappear,
                onPositionChange = self.onPlayerPositionChange
            })
        end;

        -- Load configuration
        loadConfig = function(self)
            if g_resources.fileExists(self.configFile) then
                local parsed = JSON.decode(g_resources.readFileContents(self.configFile))
                self.stateManager:setState({
                    staminaEnabled = parsed.staminaEnabled == nil and true or parsed.staminaEnabled,
                    expStagesEnabled = parsed.expStagesEnabled == nil and true or parsed.expStagesEnabled,
                    expStages = parsed.stages or {}
                })
            else
                self.stateManager:setState({ staminaEnabled = true, expStagesEnabled = true, expStages = {} })
            end
        end;

        getModuleOrMods = function(self)
            local splitPath = string.split(g_resources.getRealDir(), '/')
            return splitPath[#splitPath]
        end;

        writeFile = function(self, path, text)
            local file = io.open(g_resources.getWorkDir() .. self:getModuleOrMods() .. path, "w")
            if file then
                file:write(text)
                file:close()
                return true
            else
                return false
            end
        end;

        -- Save configuration
        saveConfig = function(self)
            local config = {
                stages = self.stateManager:get('expStages'),
                staminaEnabled = self.stateManager:get('staminaEnabled'),
                expStagesEnabled = self.stateManager:get('expStagesEnabled')
            }
            self:writeFile(self.configFile, JSON.encode(config))
        end;

        -- Get experience multiplier based on level
        getExpMultiplier = function(self, level)
            if not self.stateManager:get('expStagesEnabled') then
                return 1.0 -- Default multiplier when exp stages are disabled
            end
            for _, stage in ipairs(self.stateManager:get('expStages')) do
                if level >= stage.levelMin and level <= stage.levelMax then
                    return stage.multiplier
                end
            end
            return 1.0 -- Default multiplier
        end;

        -- Calculate stamina multiplier (150% for 42-40 hours)
        getStaminaMultiplier = function(self)
            if not self.stateManager:get('staminaEnabled') then return 1.0 end
            local stamina = g_game.getLocalPlayer():getStamina() / 60 -- Convert to hours
            return stamina >= 40 and stamina <= 42 and 1.5 or 1.0
        end;

        -- Calculate experience needed for next level
        getExpForLevel = function(self, level)
            return math.floor(((50 * level * level * level) - (150 * level * level) + (400 * level)) / 3)
        end;

        -- Get current number of visible players
        getCurrentPlayersCount = function(self)
            local count = 0
            for _, event in ipairs(self.expData.playerEvents) do
                if event.disappear == nil then
                    count = count + 1
                end
            end
            return count
        end;

        -- Track experience gain
        trackExp = function(self)
            local player = g_game.getLocalPlayer()
            if not player then return end

            local currentExp = player:getExperience()
            local level = player:getLevel()

            if self.expData.lastExp > 0 and currentExp > self.expData.lastExp then
                local expGain = currentExp - self.expData.lastExp
                local multiplier = self:getExpMultiplier(level) * self:getStaminaMultiplier()
                local adjustedExp = math.floor(expGain / multiplier)

                table.insert(self.expData.history, {
                    timestamp = os.time(),
                    adjusted = adjustedExp,
                    raw = expGain,
                    level = level,
                    players = self:getCurrentPlayersCount()
                })
            end

            self.expData.lastExp = currentExp
            self.expData.currentLevel = level
            self.expData.currentExp = currentExp
        end;

        -- Clean old data
        cleanOldData = function(self)
            local now = os.time()
            local maxInterval = self.timeIntervals[#self.timeIntervals]
            for i = #self.expData.history, 1, -1 do
                if now - self.expData.history[i].timestamp > maxInterval then
                    table.remove(self.expData.history, i)
                end
            end
            for i = #self.expData.playerEvents, 1, -1 do
                local event = self.expData.playerEvents[i]
                if event.disappear and now - event.disappear > maxInterval then
                    table.remove(self.expData.playerEvents, i)
                end
            end
            for id, ts in pairs(self.expData.uniquePlayers) do
                if now - ts > maxInterval then
                    self.expData.uniquePlayers[id] = nil
                end
            end
        end;

        -- Handle player death
        onDeathAction = function(self)
            local player = g_game.getLocalPlayer()
            if not player then return end

            local expLoss = self.expData.currentExp - player:getExperience()
            table.insert(self.expData.deaths, {
                timestamp = os.time(),
                expLost = expLoss,
                previousExp = self.expData.currentExp,
                level = self.expData.currentLevel
            })
        end;

        onPlayerAppearAction = function(self, player)
            if not player:isLocalPlayer() and player:getPosition().z == g_game.getLocalPlayer():getPosition().z then
                local name = player:getName()
                if not self.expData.playerMap[name] then
                    self.expData.playerMap[name] = self.expData.nextPlayerId
                    self.expData.nextPlayerId = self.expData.nextPlayerId + 1
                end
                local id = self.expData.playerMap[name]
                table.insert(self.expData.playerEvents, {id = id, appear = os.time(), disappear = nil})
                self.expData.uniquePlayers[id] = os.time()
            end
        end;

        onPlayerDisappearAction = function(self, player)
            if g_game.isOnline() and not player:isLocalPlayer() and player:getPosition().z == g_game.getLocalPlayer():getPosition().z then
                local name = player:getName()
                local id = self.expData.playerMap[name]
                if id then
                    for i = #self.expData.playerEvents, 1, -1 do
                        local event = self.expData.playerEvents[i]
                        if event.id == id and event.disappear == nil then
                            event.disappear = os.time()
                            break
                        end
                    end
                    self.expData.uniquePlayers[id] = os.time()
                end
            end
        end;

        onLocalPlayerFloorChangeAction = function(self, localPlayer, newPos, oldPos)
            if oldPos and newPos.z ~= oldPos.z then
                -- Get spectators: multiFloor -> true
                local spectators = g_map.getSpectators(localPlayer:getPosition(), true)
                for _, creature in ipairs(spectators) do
                    if creature:isPlayer() and not creature:isLocalPlayer() then
                        if oldPos.z == creature:getPosition().z then
                            self:onPlayerDisappearAction(creature)
                        elseif newPos.z == creature:getPosition().z then
                            self:onPlayerAppearAction(creature)
                        end
                    end
                end
            end
        end;

        onPlayerFloorChangeAction = function(self, player, newPos, oldPos)
            if not player:isLocalPlayer() and newPos and oldPos then
                if oldPos.z == g_game.getLocalPlayer():getPosition().z and oldPos.z ~= newPos.z then
                    self:onPlayerDisappearAction(player)
                elseif newPos.z == g_game.getLocalPlayer():getPosition().z and oldPos.z ~= newPos.z then
                    self:onPlayerAppearAction(player)
                end
            end
        end;

        -- Calculate exp gain for interval
        getExpForInterval = function(self, seconds, mode)
            mode = mode or self.currentMode
            local field = (mode == 'adjusted') and 'adjusted' or 'raw'
            local now = os.time()
            local totalExp = 0
            for _, entry in ipairs(self.expData.history) do
                if now - entry.timestamp <= seconds then
                    totalExp = totalExp + entry[field]
                end
            end
            return totalExp
        end;

        -- Calculate unique players for interval
        getUniquePlayersForInterval = function(self, seconds)
            local now = os.time()
            local start = now - seconds
            local count = 0
            for _, ts in pairs(self.expData.uniquePlayers) do
                if ts >= start then
                    count = count + 1
                end
            end
            return count
        end;

        -- Calculate time to next level
        getTimeToNextLevel = function(self)
            local player = g_game.getLocalPlayer()
            if not player then return 0 end

            local level = player:getLevel()
            local currentExp = player:getExperience()
            local expNeeded = self:getExpForLevel(level + 1) - currentExp
            local expPerSecond = self:getExpForInterval(3600, 'raw') / 3600 -- Exp per second based on last hour
            return expPerSecond > 0 and math.floor(expNeeded / expPerSecond) or 0
        end;

        -- Calculate level at stamina end
        getLevelAtStaminaEnd = function(self)
            local player = g_game.getLocalPlayer()
            if not player then return 0 end

            local stamina = player:getStamina() / 60 -- In hours
            if stamina > 40 then stamina = 40 end -- Cap at 40 hours (stamina limit)
            
            local expPerSecond = self:getExpForInterval(3600, 'raw') / 3600
            local totalExp = expPerSecond * stamina * 3600
            local level = player:getLevel()
            local currentExp = player:getExperience()
            
            while totalExp > 0 do
                local expToNext = self:getExpForLevel(level + 1) - currentExp
                if totalExp >= expToNext then
                    totalExp = totalExp - expToNext
                    currentExp = self:getExpForLevel(level + 1)
                    level = level + 1
                else
                    break
                end
            end
            return level
        end;

        -- Get death history
        getDeathHistory = function(self)
            return self.expData.deaths
        end;

        -- Get exp stages
        getExpStages = function(self)
            return self.stateManager:get('expStages')
        end;

        -- Add new exp stage
        addExpStage = function(self, levelMin, levelMax, multiplier)
            local expStages = self.stateManager:get('expStages')
            table.insert(expStages, {
                levelMin = levelMin,
                levelMax = levelMax,
                multiplier = multiplier
            })
            table.sort(expStages, function(a, b) return a.levelMin < b.levelMin end)
            self.stateManager:set('expStages', expStages)
            self:saveConfig()
        end;

        -- Remove exp stage by index
        removeExpStage = function(self, index)
            local expStages = self.stateManager:get('expStages')
            if expStages[index] then
                table.remove(expStages, index)
                self.stateManager:set('expStages', expStages)
                self:saveConfig()
            end
        end;

        -- Get StateManager instance
        getStateManager = function(self)
            return self.stateManager
        end;
    }

    system.onDeath = function()
        system:onDeathAction()
    end

    system.onPlayerAppear = function(player)
        system:onPlayerAppearAction(player)
    end

    system.onPlayerDisappear = function(player)
        system:onPlayerDisappearAction(player)
    end

    system.onLocalPlayerPositionChange = function(localPlayer, newPos, oldPos)
        system:onLocalPlayerFloorChangeAction(localPlayer, newPos, oldPos)
    end

    system.onPlayerPositionChange = function(player, newPos, oldPos)
        system:onPlayerFloorChangeAction(player, newPos, oldPos)
    end

    return system
end
