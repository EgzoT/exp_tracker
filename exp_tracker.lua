if g_graphics then
    dofile('ui/ui')
end

-- UI
if g_graphics then
    ui = UI()
end

function init()
    if g_graphics then
        ui:init()
    end

    --TODO
end

function terminate()
    if g_graphics then
        ui:terminate()
    end

    --TODO
end

function disable()
    if g_graphics then
        ui.menuButton:hide()
    end
end
