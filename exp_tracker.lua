dofile('expTrackerSystem')
if g_graphics then
    dofile('ui/ui')
end

expTracker = ExpTrackerSystem()
-- UI
if g_graphics then
    ui = UI()
end

function init()
    if g_graphics then
        ui:init()
    end
    expTracker:init()
end

function terminate()
    if g_graphics then
        ui:terminate()
    end
    expTracker:terminate()
end

function disable()
    if g_graphics then
        ui.menuButton:hide()
    end
end
