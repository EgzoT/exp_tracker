function StateManager(values)
    local stateManager = {
        list = {};
        values = {};
        events = {};

        setValues = function(self, values)
            self:clear()

            for a,b in pairs(values) do
                self.list[a] = a
                self.values[a] = b
                self.events[a] = Event()
            end

            return self
        end;

        setState = function(self, values)
            for a,b in pairs(values) do
                if self.list[a] ~= nil then
                    self:updateState(a, b)
                else
                    perror("State [" .. a .. "] doesn't exist in StateManager.")
                    perror("Value: " .. b)
                    perror(debug.traceback())
                end
            end

            return self
        end;

        setStateCheck = function(self, values)
            for a,b in pairs(values) do
                if self.list[a] ~= nil then
                    if self.values[a] ~= b then
                        self:updateState(a, b)
                    end
                else
                    perror("State [" .. a .. "] doesn't exist in StateManager.")
                    perror("Value: " .. b)
                    perror(debug.traceback())
                end
            end

            return self
        end;

        setStateSilent = function(self, values)
            for a,b in pairs(values) do
                if self.list[a] ~= nil then
                    self.values[a] = b
                else
                    perror("State [" .. a .. "] doesn't exist in StateManager.")
                    perror("Value: " .. b)
                    perror(debug.traceback())
                end
            end

            return self
        end;

        set = function(self, state, value)
            if self.list[state] ~= nil then
                self:updateState(state, value)
            else
                perror("State [" .. state .. "] doesn't exist in StateManager.")
                perror("Value: " .. value)
                perror(debug.traceback())
            end

            return self
        end;

        setCheck = function(self, state, value)
            if self.list[state] ~= nil then
                if self.values[state] ~= value then
                    self:updateState(state, value)
                end
            else
                perror("State [" .. state .. "] doesn't exist in StateManager.")
                perror("Value: " .. value)
                perror(debug.traceback())
            end

            return self
        end;

        setSilent = function(self, state, value)
            if self.list[state] ~= nil then
                self.values[state] = value
            else
                perror("State [" .. state .. "] doesn't exist in StateManager.")
                perror("Value: " .. value)
                perror(debug.traceback())
            end

            return self
        end;

        get = function(self, state)
            if self.list[state] ~= nil then
                return self.values[state]
            else
                perror("State [" .. state .. "] doesn't exist in StateManager.")
                perror(debug.traceback())
            end
        end;

        getAll = function(self)
            return self.values
        end;

        getList = function(self)
            return self.list
        end;

        updateState = function(self, state, value)
            local prev = self.values[state]
            self.values[state] = value
            self.events[state]:emit(value, prev)

            return self
        end;

        onStateChange = function(self, state, listener)
            self.events[state]:addListener(listener)

            return self
        end;

        offStateChange = function(self, state, listener)
            self.events[state]:removeListener(listener)

            return self
        end;

        clear = function(self)
            self.list = {}
            self.values = {}
            self.events = {}

            return self
        end;
    }

    if values then
        stateManager:setValues(values)
    end

    return stateManager
end
