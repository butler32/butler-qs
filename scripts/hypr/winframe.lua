-- Заголовки окон в оконном режиме (плагин hyprbars + патч scripts/hyprbars/butler-buttons.patch).
-- Стиль выбирает Quickshell (Меню → Конфигурация → Оконный режим) и пишет его в
-- <state>/winmode.style: "none" | "mac" | "windows". Здесь он только читается при (пере)загрузке
-- конфига. Без загруженного плагина (scripts/hyprbars/build.sh) файл ничего не делает.
--
-- Подключается из winmode.lua; WM_FRAME_SET(windowed) вызывается из WM_SET.

local home = os.getenv("HOME")
local state = (os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")) .. "/quickshell/by-shell/butler/"

local function read(name, default)
    local f = io.open(state .. name, "r")
    if not f then return default end
    local s = f:read("*l") or default
    f:close()
    return s
end

local style = os.getenv("BUTLER_FRAME_STYLE") or read("winmode.style", "none")
WM_FRAME_STYLE = style

-- заголовок скрыт у всех окон, пока включён тайлинг (правило снимается в WM_FRAME_SET(true))
local nobar = nil

local function qs(cmd) return "qs -c butler ipc call winmode " .. cmd end
local function dispatch(expr) return "hyprctl dispatch '" .. expr .. "'" end

local styles = {
    -- macOS: светлая полоса, три кружка слева (закрыть, свернуть, развернуть), значки при наведении
    mac = function()
        hl.config({ plugin = { hyprbars = {
            enabled = true,
            bar_height = 28,
            bar_color = "rgb(ececec)",
            ["col.text"] = "rgb(4d4d4d)",
            bar_text_size = 12,
            bar_text_align = "center",
            bar_buttons_alignment = "left",
            bar_padding = 12,
            bar_button_padding = 8,
            icon_on_hover = true,
            bar_precedence_over_border = true,
            inactive_button_color = "rgb(cfcfcf)",
        } } })
        local function button(bg, fg, icon, action)
            hl.plugin.hyprbars.add_button({ bg_color = bg, fg_color = fg, size = 12, icon = icon, action = action })
        end
        button("rgb(ff5f57)", "rgb(4d0000)", "×", dispatch("hl.dsp.window.close()"))
        button("rgb(febc2e)", "rgb(5a3d00)", "−", qs("minimizeActive"))
        button("rgb(28c840)", "rgb(004d0a)", "+",
            dispatch('hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })'))
    end,

    -- Windows 11 (тёмная тема): полоса 32 px, плоские кнопки 46 px справа (свернуть, развернуть, закрыть)
    windows = function()
        hl.config({ plugin = { hyprbars = {
            enabled = true,
            bar_height = 32,
            bar_color = "rgb(202020)",
            ["col.text"] = "rgb(ffffff)",
            bar_text_size = 12,
            bar_text_align = "left",
            bar_buttons_alignment = "right",
            bar_padding = 0,
            bar_button_padding = 0,
            icon_on_hover = false,
            bar_precedence_over_border = true,
        } } })
        local function button(icon, hover, action, fg)
            hl.plugin.hyprbars.add_button({
                bg_color = "rgb(202020)", hover_color = hover, fg_color = fg or "rgb(ffffff)",
                size = 16, width = 46, icon = icon, action = action,
            })
        end
        -- порядок справа налево
        button("✕", "rgb(c42b1c)", dispatch("hl.dsp.window.close()"))
        button("☐", "rgb(373737)",
            dispatch('hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })'))
        button("─", "rgb(373737)", qs("minimizeActive"))
    end,
}

-- Плагин здесь НЕ грузим: hl.plugin.load внутри конфига вызывает reload, а reload выгружает плагины
-- конфига — получается бесконечный цикл. Плагин грузит Quickshell (`hyprctl plugin load`, services/WinMode)
-- и делает reload; к этому моменту hl.plugin.hyprbars уже существует.
if style == "none" and hl.plugin and hl.plugin.hyprbars then
    hl.config({ plugin = { hyprbars = { enabled = false } } })
end

if style ~= "none" and styles[style] and hl.plugin and hl.plugin.hyprbars then
    styles[style]()
    nobar = hl.window_rule({
        name = "winmode-nobar",
        match = { class = ".*" },
        ["hyprbars:no_bar"] = true,
        enabled = true,
    })
end

function WM_FRAME_SET(windowed)
    if nobar then nobar:set_enabled(not windowed) end
end
