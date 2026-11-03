-- Оконный режим Quickshell (qs -c butler, services/WinMode.qml).
-- Подключается ПОСЛЕДНИМ в hyprland.lua (правило должно идти после остальных
-- window_rule: побеждает последнее совпадение).
--
-- Режим хранит Quickshell в <state>/winmode.mode ("tiling" | "windowed"); здесь он
-- только читается при (пере)загрузке конфига, чтобы reload не сбрасывал режим.
-- QS переключает режим через `hyprctl eval`:  WM_SET(true | false)

local path = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state"))
    .. "/quickshell/by-shell/butler/winmode.mode"

local function readMode()
    local f = io.open(path, "r")
    if not f then return "tiling" end
    local s = f:read("*l") or "tiling"
    f:close()
    return s
end

-- Новые окна в оконном режиме: плавающие, по центру, 60% монитора, на активном воркспейсе.
-- float=false в match — только окна, которые иначе были бы тайловыми (диалоги не трогаем).
WM_FLOAT = hl.window_rule({
    name = "winmode-float",
    match = { class = ".*", float = false },
    float = true,
    workspace = "unset",
    center = true,
    size = { "monitor_w*0.6", "monitor_h*0.6" },
    enabled = false,
})

-- Resize за рамку и прилипание: нужны в оконном режиме, в тайлинге безвредны.
hl.config({
    general = {
        resize_on_border = true,
        extend_border_grab_area = 15,
        hover_icon_on_border = true,
        snap = { enabled = true },
    },
})

-- WM_LOCK = true блокирует бинды смены воркспейсов (обёртка WM_GUARD в keybindings.lua).
WM_LOCK = false
-- заголовки окон (hyprbars), стиль выбирает Quickshell; без плагина файл ничего не делает
do
    local path = os.getenv("HOME") .. "/.config/quickshell/butler/scripts/hypr/winframe.lua"
    local f = io.open(path, "r")
    if f then
        f:close()
        local ok, err = pcall(dofile, path)
        if not ok then hl.notification.create({ text = "winframe: " .. tostring(err), timeout = 5000, icon = "error" }) end
    end
end

function WM_SET(windowed)
    WM_LOCK = windowed and true or false
    WM_FLOAT:set_enabled(WM_LOCK)
    if WM_FRAME_SET then WM_FRAME_SET(WM_LOCK) end
end

WM_SET(readMode() == "windowed")
