.pragma library
// Каталог редактора Hyprland: ЧТО показывать человеку и КАК это называется. Здесь нет ни одного имени поля,
// которое пользователь должен знать: у каждой настройки есть понятное название, пояснение и подходящий
// контрол (переключатель / ползунок / список), а значения в списках подписаны словами.
//
// Тексты — пары {ru, en} (их выбирает ConfigEditor.tx() по I18n.lang), остальные строки интерфейса — в I18n.qml.
// Контролы (ctl): toggle | int | num | select | color | text | layouts | kbswitch
//   int/num: min, max, step, unit — есть min и max → ползунок + поле
//   select:  options [{value, ru, en}] либо from: "monitors" | "workspaces" | "curves" | "devices" | ...
// Опции hl.config идут в `options`-блоках страницы (path — путь в hl.config через точку).

function T(ru, en) { return { ru: ru, en: en === undefined ? ru : en } }
function O(value, ru, en) { return { value: value, ru: ru, en: en === undefined ? ru : en } }

// Опция hl.config: I(путь, ctl, T(название), T(пояснение), доп. свойства)
function I(path, ctl, title, hint, x) {
    var r = { path: path, ctl: ctl, title: title, hint: hint || null }
    for (var k in x) r[k] = x[k]
    return r
}
function B(title, items, note) { return { type: "options", title: title, note: note || null, items: items } }

var ON_OFF = [O(false, "Выкл", "Off"), O(true, "Вкл", "On")]

// ─── Окна ────────────────────────────────────────────────────────────────────
var WINDOWS = [
    B(T("Отступы и рамки", "Gaps and borders"), [
        I("general.gaps_in", "int", T("Отступ между окнами", "Gap between windows"),
          T("Расстояние между соседними окнами.", "Space between neighbouring windows."), { min: 0, max: 60, unit: "px" }),
        I("general.gaps_out", "int", T("Отступ от края экрана", "Gap to the screen edge"),
          T("Расстояние между окнами и краем экрана (панель учитывается отдельно).", "Space between windows and the screen edge (bars are counted separately)."), { min: 0, max: 120, unit: "px" }),
        I("general.border_size", "int", T("Толщина рамки", "Border width"), T("0 — без рамки.", "0 means no border."), { min: 0, max: 12, unit: "px" }),
        I("general.col.active_border", "color", T("Цвет рамки активного окна", "Active window border colour"),
          T("Обычно задаётся темой оформления.", "Usually set by the colour theme.")),
        I("general.col.inactive_border", "color", T("Цвет рамки неактивных окон", "Inactive window border colour"),
          T("Обычно задаётся темой оформления.", "Usually set by the colour theme.")),
        I("general.gaps_workspaces", "int", T("Зазор между рабочими столами", "Gap between workspaces"),
          T("Видно в анимации переключения столов.", "Visible in the workspace-switch animation."), { min: 0, max: 400, unit: "px" })
    ]),
    B(T("Расположение окон", "Window layout"), [
        I("general.layout", "select", T("Как раскладывать окна", "How windows are arranged"),
          T("Dwindle делит экран пополам при каждом новом окне, Master держит одно главное окно и стопку остальных, Scrolling выстраивает окна в ленту.",
            "Dwindle splits the screen in half for each new window, Master keeps one main window plus a stack, Scrolling lines windows up in a strip."),
          { options: [O("dwindle", "Деление пополам (Dwindle)", "Split in halves (Dwindle)"),
                      O("master", "Главное окно + стопка (Master)", "Main window + stack (Master)"),
                      O("scrolling", "Горизонтальная лента (Scrolling)", "Scrolling strip (Scrolling)")] }),
        I("general.resize_on_border", "toggle", T("Менять размер за рамку", "Resize by dragging the border"),
          T("Тянуть мышью границу окна или зазор между окнами, чтобы изменить размер.", "Drag a window edge or the gap between windows to resize.")),
        I("general.extend_border_grab_area", "int", T("Зона захвата рамки", "Border grab area"),
          T("Насколько далеко от рамки курсор «цепляет» границу.", "How far from the border the cursor still grabs it."), { min: 0, max: 40, unit: "px" }),
        I("general.hover_icon_on_border", "toggle", T("Менять курсор над рамкой", "Change cursor over borders"), null),
        I("general.no_focus_fallback", "toggle", T("Не искать окно в пустом направлении", "Do not search past the last window"),
          T("Если в выбранную сторону окон нет, фокус не перескочит на другое окно.", "If there is no window in the chosen direction, focus will not jump elsewhere.")),
        I("general.allow_tearing", "toggle", T("Разрешить тиринг (для игр)", "Allow tearing (for games)"),
          T("Снижает задержку в играх, но на экране могут появляться разрывы. Работает вместе с правилом окна «Разрешить тиринг».",
            "Lowers input lag in games but can cause screen tearing. Works together with the window rule “Allow tearing”."))
    ]),
    B(T("Примагничивание плавающих окон", "Floating window snapping"), [
        I("general.snap.enabled", "toggle", T("Примагничивать окна друг к другу", "Snap windows to each other"),
          T("Плавающие окна «прилипают» к соседям и краям экрана при перетаскивании.", "Floating windows stick to neighbours and screen edges while dragged.")),
        I("general.snap.window_gap", "int", T("Дистанция до окон", "Distance to windows"), null, { min: 0, max: 60, unit: "px" }),
        I("general.snap.monitor_gap", "int", T("Дистанция до края монитора", "Distance to monitor edge"), null, { min: 0, max: 60, unit: "px" })
    ]),
    B(T("Режим «Деление пополам» (Dwindle)", "Dwindle layout"), [
        I("dwindle.preserve_split", "toggle", T("Запоминать направление деления", "Remember split direction"),
          T("Окна не перестраиваются, когда вы закрываете соседнее.", "Windows keep their split when a neighbour is closed.")),
        I("dwindle.smart_split", "toggle", T("Делить по положению курсора", "Split by cursor position"),
          T("Новое окно появится с той стороны, ближе к которой курсор.", "The new window appears on the side the cursor is closest to.")),
        I("dwindle.force_split", "select", T("Куда ставить новое окно", "Where the new window goes"), null,
          { options: [O(0, "По ситуации (обычно)", "Automatic"), O(1, "Всегда слева / сверху", "Always left / top"), O(2, "Всегда справа / снизу", "Always right / bottom")] }),
        I("dwindle.default_split_ratio", "num", T("Пропорция деления", "Split ratio"),
          T("1 — поровну; меньше — новое окно уже, больше — шире.", "1 splits evenly; lower makes the new window narrower, higher wider."), { min: 0.2, max: 1.8, step: 0.05 }),
        I("dwindle.smart_resizing", "toggle", T("Умное изменение размера", "Smart resizing"),
          T("Размер меняется в ту сторону, к которой ближе курсор.", "Resizing happens toward the side the cursor is nearest to.")),
        I("dwindle.use_active_for_splits", "toggle", T("Делить активное окно, а не под курсором", "Split the focused window, not the one under the cursor"), null)
    ]),
    B(T("Режим «Главное окно» (Master)", "Master layout"), [
        I("master.new_status", "select", T("Новое окно становится", "A new window becomes"), null,
          { options: [O("master", "Главным", "The master"), O("slave", "Рядовым (в стопке)", "A stack window"), O("inherit", "Как у активного окна", "Same as the focused window")] }),
        I("master.orientation", "select", T("Где главное окно", "Where the master window is"), null,
          { options: [O("left", "Слева", "Left"), O("right", "Справа", "Right"), O("top", "Сверху", "Top"), O("bottom", "Снизу", "Bottom"), O("center", "По центру", "Centre")] }),
        I("master.mfact", "num", T("Доля главного окна", "Master window share"), T("Какую часть экрана занимает главное окно.", "How much of the screen the master window takes."),
          { min: 0.1, max: 0.9, step: 0.05 }),
        I("master.new_on_top", "toggle", T("Новые окна — в начало стопки", "New windows go to the top of the stack"), null),
        I("master.focus_master_on_close", "toggle", T("После закрытия фокус на главное окно", "Focus the master after closing a window"), null),
        I("master.smart_resizing", "toggle", T("Умное изменение размера", "Smart resizing"), null)
    ]),
    B(T("Режим «Лента» (Scrolling)", "Scrolling layout"), [
        I("scrolling.column_width", "num", T("Ширина колонки", "Column width"), T("Доля ширины экрана.", "Fraction of the screen width."), { min: 0.1, max: 1, step: 0.05 }),
        I("scrolling.fullscreen_on_one_column", "toggle", T("Одна колонка — на весь экран", "A single column fills the screen"), null),
        I("scrolling.follow_focus", "toggle", T("Лента следует за фокусом", "Strip follows focus"), null),
        I("scrolling.wrap_focus", "toggle", T("Зацикливать фокус по краям", "Wrap focus at the ends"), null)
    ])
]

// ─── Внешний вид ─────────────────────────────────────────────────────────────
var APPEARANCE = [
    B(T("Скругления и прозрачность", "Rounding and transparency"), [
        I("decoration.rounding", "int", T("Скругление углов окон", "Window corner radius"), T("0 — прямые углы.", "0 gives square corners."), { min: 0, max: 40, unit: "px" }),
        I("decoration.rounding_power", "num", T("Форма скругления", "Corner shape"),
          T("2 — обычная дуга, больше — «квадратнее», как у iOS.", "2 is a normal arc, higher gives squarer, iOS-like corners."), { min: 2, max: 10, step: 0.5 }),
        I("decoration.active_opacity", "num", T("Прозрачность активного окна", "Focused window opacity"), T("1 — непрозрачное.", "1 is fully opaque."), { min: 0.1, max: 1, step: 0.05 }),
        I("decoration.inactive_opacity", "num", T("Прозрачность неактивных окон", "Unfocused window opacity"), null, { min: 0.1, max: 1, step: 0.05 }),
        I("decoration.fullscreen_opacity", "num", T("Прозрачность полноэкранных окон", "Fullscreen window opacity"), null, { min: 0.1, max: 1, step: 0.05 }),
        I("decoration.dim_inactive", "toggle", T("Затемнять неактивные окна", "Dim unfocused windows"), null),
        I("decoration.dim_strength", "num", T("Сила затемнения", "Dimming strength"), null, { min: 0, max: 1, step: 0.05 })
    ]),
    B(T("Тени", "Shadows"), [
        I("decoration.shadow.enabled", "toggle", T("Тени под окнами", "Window shadows"), null),
        I("decoration.shadow.range", "int", T("Размер тени", "Shadow size"), null, { min: 0, max: 80, unit: "px" }),
        I("decoration.shadow.render_power", "int", T("Резкость тени", "Shadow sharpness"),
          T("Чем больше, тем быстрее тень исчезает от края окна.", "Higher values make the shadow fade out faster."), { min: 1, max: 4 }),
        I("decoration.shadow.color", "color", T("Цвет тени", "Shadow colour"), null),
        I("decoration.shadow.color_inactive", "color", T("Цвет тени неактивных окон", "Unfocused shadow colour"), null),
        I("decoration.shadow.scale", "num", T("Масштаб тени", "Shadow scale"), null, { min: 0.5, max: 1.5, step: 0.05 }),
        I("decoration.shadow.sharp", "toggle", T("Резкая тень без размытия", "Hard-edged shadow"), null)
    ]),
    B(T("Размытие фона", "Background blur"), [
        I("decoration.blur.enabled", "toggle", T("Размывать фон за окнами", "Blur behind windows"),
          T("Работает для полупрозрачных окон.", "Visible on translucent windows.")),
        I("decoration.blur.size", "int", T("Радиус размытия", "Blur radius"), null, { min: 1, max: 30 }),
        I("decoration.blur.passes", "int", T("Качество (число проходов)", "Quality (passes)"),
          T("Больше проходов — плавнее, но тяжелее для видеокарты.", "More passes look smoother but cost more GPU time."), { min: 1, max: 8 }),
        I("decoration.blur.vibrancy", "num", T("Насыщенность цветов", "Colour vibrancy"), null, { min: 0, max: 1, step: 0.05 }),
        I("decoration.blur.noise", "num", T("Зернистость", "Noise"), null, { min: 0, max: 0.3, step: 0.01 }),
        I("decoration.blur.contrast", "num", T("Контраст", "Contrast"), null, { min: 0, max: 2, step: 0.05 }),
        I("decoration.blur.brightness", "num", T("Яркость", "Brightness"), null, { min: 0, max: 2, step: 0.05 }),
        I("decoration.blur.xray", "toggle", T("Размывать только обои (без окон под низом)", "Blur only the wallpaper (x-ray)"),
          T("Быстрее и аккуратнее для плавающих окон.", "Faster and cleaner for floating windows.")),
        I("decoration.blur.popups", "toggle", T("Размывать всплывающие меню", "Blur popup menus"), null),
        I("decoration.blur.special", "toggle", T("Размывать фон спец. рабочего стола", "Blur behind the special workspace"), null)
    ])
]

var ANIMATION_SWITCH = [
    B(T("Общие", "General"), [
        I("animations.enabled", "toggle", T("Анимации включены", "Animations enabled"), T("Выключите, чтобы всё происходило мгновенно.", "Turn off to make everything instant.")),
        I("animations.workspace_wraparound", "toggle", T("Зацикливать прокрутку столов", "Wrap around when scrolling workspaces"), null)
    ])
]

// ─── Ввод ────────────────────────────────────────────────────────────────────
var INPUT = [
    B(T("Клавиатура", "Keyboard"), [
        I("input.kb_layout", "layouts", T("Раскладки клавиатуры", "Keyboard layouts"),
          T("Переключаться между ними можно сочетанием клавиш ниже.", "You can switch between them with the shortcut below.")),
        I("input.kb_options", "kbswitch", T("Переключение раскладки", "Layout switch shortcut"), null),
        I("input.repeat_rate", "int", T("Скорость автоповтора", "Key repeat rate"), T("Символов в секунду при удержании клавиши.", "Characters per second while a key is held."), { min: 1, max: 100, unit: "/s" }),
        I("input.repeat_delay", "int", T("Задержка до автоповтора", "Key repeat delay"), null, { min: 100, max: 1000, step: 10, unit: "ms" }),
        I("input.numlock_by_default", "toggle", T("Включать NumLock при старте", "Turn NumLock on at start"), null),
        I("input.resolve_binds_by_sym", "toggle", T("Горячие клавиши работают на любой раскладке", "Shortcuts work on any layout"),
          T("Иначе сочетания привязаны к положению клавиши, а не к букве.", "Otherwise shortcuts follow the key position, not the letter."))
    ]),
    B(T("Мышь", "Mouse"), [
        I("input.sensitivity", "num", T("Чувствительность", "Sensitivity"), T("0 — без изменений, −1 — самая медленная, 1 — самая быстрая.", "0 is unchanged, −1 slowest, 1 fastest."), { min: -1, max: 1, step: 0.05 }),
        I("input.accel_profile", "select", T("Ускорение курсора", "Pointer acceleration"), null,
          { options: [O("flat", "Выключено (точное)", "Off (flat)"), O("adaptive", "Адаптивное", "Adaptive"), O("custom", "Своя кривая", "Custom curve")] }),
        I("input.natural_scroll", "toggle", T("Естественная прокрутка", "Natural scrolling"), T("Содержимое двигается вслед за пальцем/колесом.", "Content follows the wheel or finger.")),
        I("input.scroll_factor", "num", T("Скорость прокрутки", "Scroll speed"), null, { min: 0.1, max: 4, step: 0.1 }),
        I("input.left_handed", "toggle", T("Режим для левши", "Left-handed mode"), T("Меняет местами левую и правую кнопки.", "Swaps the left and right buttons.")),
        I("input.follow_mouse", "select", T("Фокус и мышь", "Focus and mouse"), null,
          { options: [O(0, "Фокус меняется только кликом", "Focus changes only on click"),
                      O(1, "Фокус следует за курсором", "Focus follows the cursor"),
                      O(2, "Клик меняет фокус, курсор не переключает", "Click focuses, hovering does not"),
                      O(3, "Фокус следует за курсором неточно", "Loose focus follows the cursor")] }),
        I("input.mouse_refocus", "toggle", T("Возвращать фокус под курсор", "Refocus under the cursor"), null)
    ]),
    B(T("Тачпад", "Touchpad"), [
        I("input.touchpad.natural_scroll", "toggle", T("Естественная прокрутка", "Natural scrolling"), null),
        I("input.touchpad.tap_to_click", "toggle", T("Касание = клик", "Tap to click"), null),
        I("input.touchpad.tap_and_drag", "toggle", T("Касание и перетаскивание", "Tap and drag"), null),
        I("input.touchpad.disable_while_typing", "toggle", T("Отключать при наборе текста", "Disable while typing"), null),
        I("input.touchpad.clickfinger_behavior", "toggle", T("Клик по числу пальцев", "Click by finger count"),
          T("1, 2 и 3 пальца — левая, правая и средняя кнопка.", "1, 2 and 3 fingers click left, right and middle.")),
        I("input.touchpad.middle_button_emulation", "toggle", T("Эмулировать среднюю кнопку", "Emulate middle button"), null),
        I("input.touchpad.scroll_factor", "num", T("Скорость прокрутки", "Scroll speed"), null, { min: 0.1, max: 4, step: 0.1 }),
        I("input.touchpad.tap_button_map", "select", T("Какая кнопка при касании 1/2/3 пальцами", "Button for 1/2/3 finger taps"), null,
          { options: [O("lrm", "Левая, правая, средняя", "Left, right, middle"), O("lmr", "Левая, средняя, правая", "Left, middle, right")] })
    ]),
    B(T("Жесты на тачпаде: переключение столов", "Touchpad gestures: workspace swipe"), [
        I("gestures.workspace_swipe_create_new", "toggle", T("Создавать новый стол при свайпе за последний", "Create a new workspace when swiping past the last"), null),
        I("gestures.workspace_swipe_invert", "toggle", T("Инвертировать направление свайпа", "Invert swipe direction"), null),
        I("gestures.workspace_swipe_distance", "int", T("Длина свайпа", "Swipe distance"), T("Сколько нужно провести пальцами, чтобы сменить стол.", "How far to swipe to switch workspace."), { min: 50, max: 800, step: 10, unit: "px" }),
        I("gestures.workspace_swipe_cancel_ratio", "num", T("Порог отмены", "Cancel threshold"), T("Если пальцы убрали раньше этой доли пути, переключение отменяется.", "Releasing before this fraction of the way cancels the switch."), { min: 0.05, max: 0.95, step: 0.05 }),
        I("gestures.workspace_swipe_forever", "toggle", T("Листать без ограничения за один свайп", "Swipe through many workspaces at once"), null),
        I("gestures.workspace_swipe_direction_lock", "toggle", T("Фиксировать направление жеста", "Lock swipe direction"), null)
    ])
]

// ─── Система ─────────────────────────────────────────────────────────────────
var SYSTEM = [
    B(T("Экран и энергия", "Display and power"), [
        I("misc.vrr", "select", T("Переменная частота кадров (VRR / FreeSync / G-Sync)", "Variable refresh rate (VRR)"),
          T("Требует поддержки монитора.", "Needs monitor support."),
          { options: [O(0, "Выключено", "Off"), O(1, "Всегда", "Always"), O(2, "Только в полноэкранных приложениях", "Only in fullscreen apps")] }),
        I("misc.mouse_move_enables_dpms", "toggle", T("Будить экран движением мыши", "Wake the screen on mouse move"), null),
        I("misc.key_press_enables_dpms", "toggle", T("Будить экран нажатием клавиши", "Wake the screen on key press"), null)
    ]),
    B(T("Окна", "Windows"), [
        I("misc.focus_on_activate", "toggle", T("Переключаться на окно, которое просит внимания", "Switch to windows that ask for attention"), null),
        I("misc.enable_swallow", "toggle", T("Терминал «поглощается» запущенной из него программой", "Terminal swallows programs launched from it"),
          T("Окно терминала скрывается, пока работает программа, и возвращается после её закрытия.", "The terminal hides while its child program runs and returns after it closes.")),
        I("misc.animate_manual_resizes", "toggle", T("Анимировать ручное изменение размера", "Animate manual resizing"), null),
        I("misc.animate_mouse_windowdragging", "toggle", T("Анимировать перетаскивание окон", "Animate window dragging"), null),
        I("misc.middle_click_paste", "toggle", T("Вставка средней кнопкой мыши", "Middle-click paste"), null)
    ]),
    B(T("Курсор", "Cursor"), [
        I("cursor.hide_on_key_press", "toggle", T("Прятать курсор при наборе текста", "Hide the cursor while typing"), null),
        I("cursor.inactive_timeout", "num", T("Прятать курсор после бездействия", "Hide the cursor when idle"), T("Секунд; 0 — не прятать.", "Seconds; 0 never hides."), { min: 0, max: 60, step: 1, unit: "s" }),
        I("cursor.no_hardware_cursors", "select", T("Программный курсор", "Software cursor"),
          T("Включите, если на NVIDIA курсор мерцает или пропадает.", "Enable if the cursor flickers or vanishes on NVIDIA."),
          { options: [O(0, "Нет (аппаратный)", "No (hardware)"), O(1, "Да", "Yes"), O(2, "Автоматически", "Automatic")] }),
        I("cursor.no_warps", "toggle", T("Не переносить курсор при смене фокуса", "Do not warp the cursor on focus change"), null),
        I("cursor.warp_on_change_workspace", "select", T("Курсор при смене рабочего стола", "Cursor on workspace change"), null,
          { options: [O(0, "Не трогать", "Leave it"), O(1, "Переносить на активное окно", "Move to the focused window"), O(2, "Переносить на активное окно (всегда)", "Always move to the focused window")] }),
        I("cursor.default_monitor", "select", T("Монитор, где курсор появляется при запуске", "Monitor the cursor starts on"), null, { from: "monitors" })
    ]),
    B(T("Рабочие столы и клавиши", "Workspaces and keys"), [
        I("binds.workspace_back_and_forth", "toggle", T("Повторный выбор стола возвращает на предыдущий", "Selecting the current workspace goes back"), null),
        I("binds.window_direction_monitor_fallback", "toggle", T("Фокус может переходить на соседний монитор", "Focus can move to the neighbouring monitor"), null),
        I("binds.allow_workspace_cycles", "toggle", T("Разрешить цикл «предыдущий стол»", "Allow previous-workspace cycling"), null),
        I("binds.hide_special_on_workspace_change", "toggle", T("Прятать спец. стол при смене рабочего стола", "Hide the special workspace when switching"), null)
    ]),
    B(T("Заставка и приложения", "Splash and apps"), [
        I("misc.disable_hyprland_logo", "toggle", T("Скрыть логотип Hyprland на фоне", "Hide the Hyprland logo background"), null),
        I("misc.force_default_wallpaper", "select", T("Фон по умолчанию", "Default background"), T("Видно, пока не запущены свои обои.", "Visible until your own wallpaper starts."),
          { options: [O(-1, "Случайный", "Random"), O(0, "Без картинок-маскотов", "No mascot art"), O(1, "Картинка 1", "Picture 1"), O(2, "Картинка 2", "Picture 2")] }),
        I("misc.disable_splash_rendering", "toggle", T("Не показывать текст-заставку", "Do not show the splash text"), null),
        I("xwayland.enabled", "toggle", T("Поддержка старых (X11) приложений", "Support legacy (X11) apps"), null),
        I("xwayland.force_zero_scaling", "toggle", T("Чёткие X11-приложения на HiDPI", "Sharp X11 apps on HiDPI screens"),
          T("Отключает растягивание, приложения сами отвечают за масштаб.", "Disables stretching; apps handle scaling themselves.")),
        I("ecosystem.no_update_news", "toggle", T("Не показывать новости об обновлении", "Hide update news"), null),
        I("ecosystem.no_donation_nag", "toggle", T("Не просить о пожертвованиях", "Hide donation reminders"), null)
    ])
]

// ─── Страницы ────────────────────────────────────────────────────────────────
// blocks: options-блок (см. B) или { type: "<имя особого блока>" }
var SECTIONS = [
    { id: "windows", title: T("Окна", "Windows"), hint: T("Отступы, рамки и расположение окон", "Gaps, borders and window layout"), blocks: WINDOWS },
    { id: "appearance", title: T("Внешний вид", "Appearance"), hint: T("Скругления, прозрачность, тени и размытие", "Corners, transparency, shadows and blur"), blocks: APPEARANCE },
    { id: "animations", title: T("Анимации", "Animations"), hint: T("Как появляются, двигаются и исчезают окна", "How windows appear, move and vanish"),
      blocks: ANIMATION_SWITCH.concat([{ type: "animations" }, { type: "curves" }]) },
    { id: "monitors", title: T("Мониторы", "Monitors"), hint: T("Разрешение, частота, положение и масштаб", "Resolution, refresh rate, position and scale"), blocks: [{ type: "monitors" }] },
    { id: "workspaces", title: T("Рабочие столы", "Workspaces"), hint: T("Какой стол на каком мониторе", "Which workspace lives on which monitor"), blocks: [{ type: "workspaces" }] },
    { id: "input", title: T("Клавиатура и мышь", "Keyboard and mouse"), hint: T("Раскладки, чувствительность, тачпад, жесты", "Layouts, sensitivity, touchpad, gestures"),
      blocks: INPUT.concat([{ type: "devices" }, { type: "gestures" }]) },
    { id: "binds", title: T("Горячие клавиши", "Shortcuts"), hint: T("Что делает каждое сочетание клавиш", "What each key combination does"), blocks: [{ type: "binds" }] },
    { id: "rules", title: T("Правила для окон", "Window rules"), hint: T("Автоматические действия для конкретных программ", "Automatic actions for specific programs"), blocks: [{ type: "windowRules" }] },
    { id: "autostart", title: T("Автозапуск", "Autostart"), hint: T("Что запускать вместе с Hyprland", "What to launch with Hyprland"), blocks: [{ type: "autostart" }] },
    { id: "env", title: T("Переменные окружения", "Environment"), hint: T("Настройки для программ и драйверов", "Settings for programs and drivers"), blocks: [{ type: "env" }] },
    { id: "system", title: T("Система", "System"), hint: T("Экран, курсор, поведение и мелочи", "Display, cursor, behaviour and small things"), blocks: SYSTEM },
    { id: "all", title: T("Все параметры", "All options"), hint: T("Полный список настроек Hyprland под их оригинальными названиями — для опытных", "Every Hyprland setting under its original name, for experts"), blocks: [{ type: "rawOptions" }] },
    { id: "source", title: T("Исходные файлы", "Source files"), hint: T("Текст конфигов целиком — на случай, если нужно что-то особенное", "The raw config text, for anything unusual"), blocks: [{ type: "source" }] }
]

// ─── Мониторы ────────────────────────────────────────────────────────────────
var SCALES = [O("1", "100%"), O("1.25", "125%"), O("1.5", "150%"), O("1.75", "175%"), O("2", "200%"), O("2.5", "250%"), O("3", "300%"), O("auto", "Автоматически", "Automatic")]
var TRANSFORMS = [O(0, "Обычная", "Normal"), O(1, "Повёрнут на 90°", "Rotated 90°"), O(2, "Повёрнут на 180°", "Rotated 180°"), O(3, "Повёрнут на 270°", "Rotated 270°"),
                  O(4, "Зеркально", "Flipped"), O(5, "Зеркально + 90°", "Flipped + 90°"), O(6, "Зеркально + 180°", "Flipped + 180°"), O(7, "Зеркально + 270°", "Flipped + 270°")]
var POSITIONS = [O("auto", "Автоматически", "Automatic"), O("auto-right", "Справа от предыдущего", "Right of the previous one"), O("auto-left", "Слева от предыдущего", "Left of the previous one"),
                 O("auto-up", "Над предыдущим", "Above the previous one"), O("auto-down", "Под предыдущим", "Below the previous one"), O("__xy", "Точные координаты…", "Exact coordinates…")]

// ─── Рабочие столы ───────────────────────────────────────────────────────────
var WS_FIELDS = [
    { key: "default", ctl: "toggle", title: T("Стол по умолчанию на этом мониторе", "Default workspace of the monitor") },
    { key: "persistent", ctl: "toggle", title: T("Не удалять, когда стол пуст", "Keep the workspace when it is empty") },
    { key: "gaps_in", ctl: "int", title: T("Свой отступ между окнами", "Own gap between windows"), min: 0, max: 60, unit: "px" },
    { key: "gaps_out", ctl: "int", title: T("Свой отступ от края", "Own gap to the edge"), min: 0, max: 120, unit: "px" },
    { key: "border_size", ctl: "int", title: T("Своя толщина рамки", "Own border width"), min: 0, max: 12, unit: "px" },
    { key: "no_border", ctl: "toggle", title: T("Без рамок", "No borders") },
    { key: "no_rounding", ctl: "toggle", title: T("Без скруглений", "No rounding") },
    { key: "no_shadow", ctl: "toggle", title: T("Без теней", "No shadows") },
    { key: "layout", ctl: "select", title: T("Свой режим расположения окон", "Own window layout"),
      options: [O("dwindle", "Деление пополам", "Dwindle"), O("master", "Главное окно + стопка", "Master"), O("scrolling", "Лента", "Scrolling")] }
]

var MONITOR_FIELDS = [
    { key: "mode", ctl: "mode", title: T("Разрешение и частота", "Resolution and refresh rate") },
    { key: "position", ctl: "position", title: T("Положение", "Position"), hint: T("Где монитор расположен относительно остальных.", "Where the monitor sits relative to the others.") },
    { key: "scale", ctl: "select", title: T("Масштаб интерфейса", "Interface scale"), options: SCALES, def: "1" },
    { key: "transform", ctl: "select", title: T("Поворот", "Rotation"), options: TRANSFORMS, def: 0 },
    { key: "vrr", ctl: "select", title: T("Переменная частота кадров", "Variable refresh rate"),
      options: [O(0, "Выключено", "Off"), O(1, "Всегда", "Always"), O(2, "Только в полноэкранных", "Fullscreen only")], def: 0 },
    { key: "bitdepth", ctl: "select", title: T("Глубина цвета", "Colour depth"),
      options: [O(8, "8 бит (обычная)", "8-bit (normal)"), O(10, "10 бит (HDR/градиенты)", "10-bit (HDR / smooth gradients)")], def: 8 },
    { key: "mirror", ctl: "select", title: T("Дублировать другой монитор", "Mirror another monitor"), from: "monitorsNone" },
    { key: "disabled", ctl: "toggleInverse", title: T("Монитор включён", "Monitor enabled") }
]

// ─── Устройства и жесты ──────────────────────────────────────────────────────
var DEVICE_FIELDS = [
    { key: "name", ctl: "select", from: "devices", title: T("Устройство", "Device"), hint: T("Список — устройства, которые сейчас подключены.", "Currently connected devices.") },
    { key: "enabled", ctl: "toggle", title: T("Устройство включено", "Device enabled"), def: true },
    { key: "sensitivity", ctl: "num", title: T("Чувствительность", "Sensitivity"), min: -1, max: 1, step: 0.05, def: 0 },
    { key: "accel_profile", ctl: "select", title: T("Ускорение курсора", "Pointer acceleration"),
      options: [O("flat", "Выключено (точное)", "Off (flat)"), O("adaptive", "Адаптивное", "Adaptive")] },
    { key: "natural_scroll", ctl: "toggle", title: T("Естественная прокрутка", "Natural scrolling") },
    { key: "scroll_factor", ctl: "num", title: T("Скорость прокрутки", "Scroll speed"), min: 0.1, max: 4, step: 0.1, def: 1 },
    { key: "left_handed", ctl: "toggle", title: T("Режим для левши", "Left-handed mode") },
    { key: "tap_to_click", ctl: "toggle", title: T("Касание = клик (тачпад)", "Tap to click (touchpad)") },
    { key: "disable_while_typing", ctl: "toggle", title: T("Отключать при наборе текста (тачпад)", "Disable while typing (touchpad)") },
    { key: "middle_button_emulation", ctl: "toggle", title: T("Эмулировать среднюю кнопку", "Emulate middle button") },
    { key: "kb_layout", ctl: "layouts", title: T("Раскладки клавиатуры", "Keyboard layouts") }
]

var GESTURE_FIELDS = [
    { key: "fingers", ctl: "select", title: T("Сколько пальцев", "Number of fingers"), options: [O(2, "2"), O(3, "3"), O(4, "4"), O(5, "5")] },
    { key: "direction", ctl: "select", title: T("Жест", "Gesture"),
      options: [O("horizontal", "Свайп по горизонтали", "Horizontal swipe"), O("vertical", "Свайп по вертикали", "Vertical swipe"),
                O("left", "Свайп влево", "Swipe left"), O("right", "Свайп вправо", "Swipe right"), O("up", "Свайп вверх", "Swipe up"), O("down", "Свайп вниз", "Swipe down"),
                O("swipe", "Свайп в любую сторону", "Swipe any direction"), O("pinch", "Щипок (любой)", "Pinch (any)"),
                O("pinchin", "Щипок: сведение", "Pinch in"), O("pinchout", "Щипок: разведение", "Pinch out")] },
    { key: "action", ctl: "select", title: T("Что делает", "What it does"),
      options: [O("workspace", "Переключает рабочие столы", "Switches workspaces"), O("move", "Перемещает окно", "Moves the window"), O("resize", "Меняет размер окна", "Resizes the window"),
                O("special", "Показывает скрытый стол", "Shows the special workspace"), O("close", "Закрывает окно", "Closes the window"),
                O("float", "Плавающее / тайловое окно", "Toggles floating"), O("fullscreen", "На весь экран", "Toggles fullscreen"), O("unset", "Отключить этот жест", "Disable this gesture")] },
    { key: "mods", ctl: "select", title: T("Удерживать клавишу", "Hold a key"),
      options: [O("", "Не нужно", "None"), O("SUPER", "Super (Win)"), O("SHIFT", "Shift"), O("CTRL", "Ctrl"), O("ALT", "Alt")] }
]

// ─── Анимации ────────────────────────────────────────────────────────────────
var LEAVES = [
    ["global", T("Все анимации (основа)", "All animations (base)")],
    ["windows", T("Окна (общая)", "Windows (general)")], ["windowsIn", T("Окно появляется", "Window opens")], ["windowsOut", T("Окно закрывается", "Window closes")], ["windowsMove", T("Окно перемещается", "Window moves")],
    ["layers", T("Панели и меню (общая)", "Bars and menus (general)")], ["layersIn", T("Панель или меню появляется", "Bar or menu appears")], ["layersOut", T("Панель или меню исчезает", "Bar or menu disappears")],
    ["fade", T("Прозрачность (общая)", "Fading (general)")], ["fadeIn", T("Окно проявляется", "Window fades in")], ["fadeOut", T("Окно исчезает", "Window fades out")],
    ["fadeSwitch", T("Смена фокуса", "Focus change")], ["fadeShadow", T("Тени окон", "Window shadows")], ["fadeDim", T("Затемнение неактивных", "Dimming of unfocused windows")],
    ["fadeLayers", T("Прозрачность панелей и меню", "Fading of bars and menus")], ["fadeLayersIn", T("Панель или меню проявляется", "Bar or menu fades in")], ["fadeLayersOut", T("Панель или меню гаснет", "Bar or menu fades out")],
    ["fadePopups", T("Всплывающие окна", "Popups")], ["fadePopupsIn", T("Всплывающее окно проявляется", "Popup fades in")], ["fadePopupsOut", T("Всплывающее окно гаснет", "Popup fades out")],
    ["border", T("Смена цвета рамки", "Border colour change")], ["borderangle", T("Вращение градиента рамки", "Border gradient rotation")],
    ["workspaces", T("Рабочие столы (общая)", "Workspaces (general)")], ["workspacesIn", T("Переход на рабочий стол", "Switching to a workspace")], ["workspacesOut", T("Уход с рабочего стола", "Leaving a workspace")],
    ["specialWorkspace", T("Спец. рабочий стол (общая)", "Special workspace (general)")], ["specialWorkspaceIn", T("Спец. стол открывается", "Special workspace opens")], ["specialWorkspaceOut", T("Спец. стол закрывается", "Special workspace closes")],
    ["zoomFactor", T("Увеличение", "Zoom")], ["monitorAdded", T("Подключение монитора", "Monitor connected")]
]

var STYLE_LABELS = {
    slide: T("Выезд сбоку", "Slide"), slidevert: T("Выезд сверху/снизу", "Vertical slide"), popin: T("Рост из центра", "Pop in"),
    fade: T("Плавное появление", "Fade"), slidefade: T("Выезд с затуханием", "Slide + fade"), slidefadevert: T("Выезд сверху/снизу с затуханием", "Vertical slide + fade"),
    gnomed: T("Как в GNOME", "GNOME-like"), once: T("Один раз", "Once"), loop: T("По кругу", "Loop")
}
function stylesFor(leaf) {
    if (/^windows/.test(leaf)) return ["slide", "popin", "gnomed"]
    if (/^layers/.test(leaf)) return ["slide", "popin", "fade"]
    if (/^(workspaces|specialWorkspace)/.test(leaf)) return ["slide", "slidevert", "fade", "slidefade", "slidefadevert"]
    if (leaf === "borderangle") return ["once", "loop"]
    return []
}
var STYLES_WITH_PERCENT = { popin: 1, slidefade: 1, slidefadevert: 1 }

var CURVE_PRESETS = [
    { id: "linear", points: [0, 0, 1, 1], title: T("Равномерно (линейно)", "Even (linear)") },
    { id: "ease", points: [0.25, 0.1, 0.25, 1], title: T("Мягко (ease)", "Soft (ease)") },
    { id: "easeIn", points: [0.42, 0, 1, 1], title: T("Медленный старт", "Slow start") },
    { id: "easeOut", points: [0, 0, 0.58, 1], title: T("Медленный финиш", "Slow finish") },
    { id: "easeInOut", points: [0.42, 0, 0.58, 1], title: T("Медленно в начале и в конце", "Slow at both ends") },
    { id: "easeOutQuint", points: [0.23, 1, 0.32, 1], title: T("Резкий старт, долгое затухание", "Fast start, long settle") },
    { id: "easeInOutCubic", points: [0.65, 0.05, 0.36, 1], title: T("Плавно, с ускорением в середине", "Smooth, quickest in the middle") },
    { id: "overshoot", points: [0.34, 1.56, 0.64, 1], title: T("С отскоком", "With overshoot") }
]

// ─── Правила для окон ────────────────────────────────────────────────────────
var WS_NAMES = [O(1, "1"), O(2, "2"), O(3, "3"), O(4, "4"), O(5, "5"), O(6, "6"), O(7, "7"), O(8, "8"), O(9, "9"), O(10, "10")]

var MATCH_FIELDS = [
    { key: "class", ctl: "text", pick: "classes", title: T("Программа (класс окна)", "Program (window class)"), hint: T("Регулярное выражение, например ^(firefox)$. Можно выбрать из открытых окон.", "A regular expression such as ^(firefox)$. You can pick from open windows.") },
    { key: "title", ctl: "text", title: T("Заголовок окна", "Window title"), hint: T("Регулярное выражение.", "A regular expression.") },
    { key: "initial_class", ctl: "text", title: T("Исходный класс окна", "Initial window class") },
    { key: "initial_title", ctl: "text", title: T("Исходный заголовок", "Initial window title") },
    { key: "xwayland", ctl: "toggle", title: T("Это приложение X11 (XWayland)", "It is an X11 (XWayland) app") },
    { key: "float", ctl: "toggle", title: T("Окно плавающее", "Window is floating") },
    { key: "fullscreen", ctl: "toggle", title: T("Окно на весь экран", "Window is fullscreen") },
    { key: "pin", ctl: "toggle", title: T("Окно закреплено", "Window is pinned") },
    { key: "focus", ctl: "toggle", title: T("Окно в фокусе", "Window is focused") },
    { key: "workspace", ctl: "text", title: T("Находится на рабочем столе", "Is on workspace") }
]

var EFFECTS = [
    { key: "workspace", ctl: "select", from: "workspaces", asString: true, title: T("Открыть на рабочем столе", "Open on workspace") },
    { key: "monitor", ctl: "select", from: "monitors", title: T("Открыть на мониторе", "Open on monitor") },
    { key: "float", ctl: "toggle", title: T("Сделать плавающим", "Make floating") },
    { key: "tile", ctl: "toggle", title: T("Сделать тайловым", "Make tiled") },
    { key: "fullscreen", ctl: "toggle", title: T("Открыть на весь экран", "Open fullscreen") },
    { key: "maximize", ctl: "toggle", title: T("Развернуть", "Maximise") },
    { key: "center", ctl: "toggle", title: T("Поставить по центру", "Centre on screen") },
    { key: "pin", ctl: "toggle", title: T("Закрепить на всех рабочих столах", "Pin to all workspaces") },
    { key: "move", ctl: "text", title: T("Положение (x y)", "Position (x y)"), hint: T("Например: 20 100 или 20 monitor_h-120", "For example: 20 100 or 20 monitor_h-120") },
    { key: "size", ctl: "text", title: T("Размер (ширина высота)", "Size (width height)"), hint: T("Например: 800 600 или 50% 50%", "For example: 800 600 or 50% 50%") },
    { key: "opacity", ctl: "num", title: T("Прозрачность", "Opacity"), min: 0.1, max: 1, step: 0.05 },
    { key: "rounding", ctl: "int", title: T("Скругление углов", "Corner radius"), min: 0, max: 40, unit: "px" },
    { key: "border_size", ctl: "int", title: T("Толщина рамки", "Border width"), min: 0, max: 12, unit: "px" },
    { key: "no_focus", ctl: "toggle", title: T("Не забирать фокус", "Never take focus") },
    { key: "no_initial_focus", ctl: "toggle", title: T("Не фокусировать при открытии", "Do not focus on open") },
    { key: "stay_focused", ctl: "toggle", title: T("Не отдавать фокус другим окнам", "Keep focus") },
    { key: "no_anim", ctl: "toggle", title: T("Без анимаций", "No animations") },
    { key: "no_blur", ctl: "toggle", title: T("Без размытия", "No blur") },
    { key: "no_shadow", ctl: "toggle", title: T("Без тени", "No shadow") },
    { key: "immediate", ctl: "toggle", title: T("Разрешить тиринг (для игр)", "Allow tearing (for games)") },
    { key: "idle_inhibit", ctl: "select", title: T("Не давать системе засыпать", "Prevent the system from idling"),
      options: [O("none", "Нет", "Never"), O("always", "Всегда", "Always"), O("focus", "Пока окно в фокусе", "While focused"), O("fullscreen", "Пока окно на весь экран", "While fullscreen")] },
    { key: "suppress_event", ctl: "select", title: T("Игнорировать запросы окна", "Ignore requests from the window"),
      options: [O("maximize", "Развернуть", "Maximise"), O("fullscreen", "Во весь экран", "Fullscreen"), O("activate", "Получить фокус", "Activate"), O("activatefocus", "Получить фокус и перейти", "Activate and focus")] }
]

// ─── Горячие клавиши ─────────────────────────────────────────────────────────
var BIND_CATS = {
    apps: T("Программы", "Programs"), windows: T("Окна", "Windows"), focus: T("Фокус и перемещение", "Focus and moving"),
    workspaces: T("Рабочие столы", "Workspaces"), mouse: T("Мышь", "Mouse"), misc: T("Прочее", "Other")
}

var DIRS = [O("left", "Влево", "Left"), O("right", "Вправо", "Right"), O("up", "Вверх", "Up"), O("down", "Вниз", "Down")]
var WS_TARGETS = WS_NAMES.concat([O("e+1", "Следующий занятый", "Next occupied"), O("e-1", "Предыдущий занятый", "Previous occupied"),
                                   O("previous", "Предыдущий (откуда пришли)", "Previously visited"), O("empty", "Первый пустой", "First empty"),
                                   O("special:magic", "Скрытый стол (scratchpad)", "Hidden workspace (scratchpad)")])

// Действие бинда = вызов диспетчера Hyprland. form: "pos" — позиционные аргументы fn(a, b), "table" — fn({ k = v }).
// match — ключ таблицы, по которому отличается от других действий с тем же fn.
var ACTIONS = [
    { id: "exec", cat: "apps", fn: "hl.dsp.exec_cmd", form: "pos", title: T("Запустить программу или команду", "Run a program or command"),
      params: [{ key: 0, ctl: "command", title: T("Команда", "Command") }] },
    { id: "close", cat: "windows", fn: "hl.dsp.window.close", form: "pos", title: T("Закрыть окно", "Close window"), params: [] },
    { id: "kill", cat: "windows", fn: "hl.dsp.window.kill", form: "pos", title: T("Принудительно завершить окно", "Force-kill window"), params: [] },
    { id: "float", cat: "windows", fn: "hl.dsp.window.float", form: "table", title: T("Плавающее / тайловое окно", "Floating / tiled window"),
      params: [{ key: "action", ctl: "select", title: T("Действие", "Action"), options: [O("toggle", "Переключить", "Toggle"), O("enable", "Сделать плавающим", "Make floating"), O("disable", "Сделать тайловым", "Make tiled")] }] },
    { id: "fullscreen", cat: "windows", fn: "hl.dsp.window.fullscreen", form: "pos", title: T("На весь экран", "Fullscreen"), params: [] },
    { id: "pseudo", cat: "windows", fn: "hl.dsp.window.pseudo", form: "pos", title: T("Псевдотайлинг окна", "Pseudo-tile window"), params: [] },
    { id: "pin", cat: "windows", fn: "hl.dsp.window.pin", form: "pos", title: T("Закрепить окно на всех столах", "Pin window to all workspaces"), params: [] },
    { id: "center", cat: "windows", fn: "hl.dsp.window.center", form: "pos", title: T("Поставить окно по центру", "Centre window"), params: [] },
    { id: "layout", cat: "windows", fn: "hl.dsp.layout", form: "pos", title: T("Команда режиму расположения", "Layout command"),
      params: [{ key: 0, ctl: "select", title: T("Команда", "Command"), options: [O("togglesplit", "Сменить направление деления", "Toggle split direction"), O("swapsplit", "Поменять половины местами", "Swap the two halves"), O("movetoroot", "Вынести окно в корень", "Move window to root")] }] },
    { id: "group", cat: "windows", fn: "hl.dsp.group.toggle", form: "pos", title: T("Группа окон: создать / разобрать", "Window group: create / dissolve"), params: [] },
    { id: "focusdir", cat: "focus", fn: "hl.dsp.focus", form: "table", match: "direction", title: T("Перейти к окну рядом", "Focus the neighbouring window"),
      params: [{ key: "direction", ctl: "select", title: T("Куда", "Direction"), options: DIRS }] },
    { id: "movedir", cat: "focus", fn: "hl.dsp.window.move", form: "table", match: "direction", title: T("Переместить окно", "Move window"),
      params: [{ key: "direction", ctl: "select", title: T("Куда", "Direction"), options: DIRS }] },
    { id: "swapdir", cat: "focus", fn: "hl.dsp.window.swap", form: "table", match: "direction", title: T("Поменять окно с соседним", "Swap with the neighbouring window"),
      params: [{ key: "direction", ctl: "select", title: T("С каким", "With"), options: DIRS }] },
    { id: "focusws", cat: "workspaces", fn: "hl.dsp.focus", form: "table", match: "workspace", title: T("Перейти на рабочий стол", "Go to workspace"),
      params: [{ key: "workspace", ctl: "select", title: T("Стол", "Workspace"), options: WS_TARGETS }] },
    { id: "movews", cat: "workspaces", fn: "hl.dsp.window.move", form: "table", match: "workspace", title: T("Перенести окно на рабочий стол", "Move window to workspace"),
      params: [{ key: "workspace", ctl: "select", title: T("Стол", "Workspace"), options: WS_TARGETS }] },
    { id: "special", cat: "workspaces", fn: "hl.dsp.workspace.toggle_special", form: "pos", title: T("Показать / скрыть скрытый стол (scratchpad)", "Show / hide the scratchpad"),
      params: [{ key: 0, ctl: "text", title: T("Название стола", "Workspace name"), def: "magic" }] },
    { id: "drag", cat: "mouse", fn: "hl.dsp.window.drag", form: "pos", title: T("Перетаскивать окно мышью", "Drag window with the mouse"), params: [] },
    { id: "resize", cat: "mouse", fn: "hl.dsp.window.resize", form: "pos", title: T("Менять размер окна мышью", "Resize window with the mouse"), params: [] },
    { id: "exit", cat: "misc", fn: "hl.dsp.exit", form: "pos", title: T("Выйти из Hyprland", "Exit Hyprland"), params: [] }
]

var BIND_FLAGS = [
    ["locked", T("Работает и при блокировке экрана", "Works on the lock screen")],
    ["repeating", T("Повторять при удержании", "Repeat while held")],
    ["release", T("Срабатывать при отпускании", "Trigger on release")],
    ["long_press", T("Срабатывать при долгом нажатии", "Trigger on long press")],
    ["non_consuming", T("Передавать клавишу и приложению", "Also pass the key to the app")],
    ["ignore_mods", T("Не учитывать Caps/Num Lock", "Ignore lock modifiers")],
    ["mouse", T("Клавиша мыши (перетаскивание)", "Mouse button (dragging)")]
]

var MODS = [["SUPER", T("Super (Win)", "Super (Win)")], ["SHIFT", T("Shift", "Shift")], ["CTRL", T("Ctrl", "Ctrl")], ["ALT", T("Alt", "Alt")]]

function keyList() {
    var out = []
    var L = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    for (var i = 0; i < L.length; i++) out.push(O(L.charAt(i), L.charAt(i), L.charAt(i)))
    for (var d = 0; d <= 9; d++) out.push(O(String(d), String(d), String(d)))
    for (var f = 1; f <= 12; f++) out.push(O("F" + f, "F" + f, "F" + f))
    var named = [
        ["space", "Пробел", "Space"], ["Return", "Enter", "Enter"], ["Escape", "Esc", "Esc"], ["Tab", "Tab", "Tab"], ["BackSpace", "Backspace", "Backspace"],
        ["Delete", "Delete", "Delete"], ["Insert", "Insert", "Insert"], ["Home", "Home", "Home"], ["End", "End", "End"], ["Prior", "Page Up", "Page Up"], ["Next", "Page Down", "Page Down"],
        ["left", "Стрелка влево", "Left arrow"], ["right", "Стрелка вправо", "Right arrow"], ["up", "Стрелка вверх", "Up arrow"], ["down", "Стрелка вниз", "Down arrow"],
        ["Print", "Print Screen", "Print Screen"], ["Caps_Lock", "Caps Lock", "Caps Lock"],
        ["comma", "Запятая ,", "Comma ,"], ["period", "Точка .", "Period ."], ["minus", "Минус −", "Minus −"], ["equal", "Равно =", "Equals ="],
        ["slash", "Слэш /", "Slash /"], ["backslash", "Обратный слэш \\", "Backslash \\"], ["semicolon", "Точка с запятой ;", "Semicolon ;"], ["apostrophe", "Апостроф '", "Apostrophe '"],
        ["bracketleft", "Скобка [", "Bracket ["], ["bracketright", "Скобка ]", "Bracket ]"], ["grave", "Гравис `", "Grave `"],
        ["XF86AudioRaiseVolume", "Громкость +", "Volume up"], ["XF86AudioLowerVolume", "Громкость −", "Volume down"], ["XF86AudioMute", "Выключить звук", "Mute"],
        ["XF86AudioMicMute", "Выключить микрофон", "Mic mute"], ["XF86AudioPlay", "Воспроизведение", "Play"], ["XF86AudioPause", "Пауза", "Pause"],
        ["XF86AudioNext", "Следующий трек", "Next track"], ["XF86AudioPrev", "Предыдущий трек", "Previous track"], ["XF86AudioStop", "Стоп", "Stop"],
        ["XF86MonBrightnessUp", "Яркость +", "Brightness up"], ["XF86MonBrightnessDown", "Яркость −", "Brightness down"],
        ["XF86Calculator", "Калькулятор", "Calculator"], ["XF86Mail", "Почта", "Mail"], ["XF86HomePage", "Домашняя страница", "Home page"], ["XF86Search", "Поиск", "Search"],
        ["mouse:272", "Мышь: левая кнопка", "Mouse: left button"], ["mouse:273", "Мышь: правая кнопка", "Mouse: right button"], ["mouse:274", "Мышь: средняя кнопка", "Mouse: middle button"],
        ["mouse:275", "Мышь: боковая «назад»", "Mouse: side back"], ["mouse:276", "Мышь: боковая «вперёд»", "Mouse: side forward"],
        ["mouse_down", "Колесо мыши вниз", "Mouse wheel down"], ["mouse_up", "Колесо мыши вверх", "Mouse wheel up"]
    ]
    for (var n = 0; n < named.length; n++) out.push(O(named[n][0], named[n][1], named[n][2]))
    return out
}

// ─── Автозапуск и окружение ──────────────────────────────────────────────────
var ENV_PRESETS = [
    ["XCURSOR_SIZE", T("Размер курсора (X11)", "Cursor size (X11)"), "24"],
    ["HYPRCURSOR_SIZE", T("Размер курсора (Hyprland)", "Cursor size (Hyprland)"), "24"],
    ["XCURSOR_THEME", T("Тема курсора", "Cursor theme"), "Adwaita"],
    ["GDK_BACKEND", T("Бэкенд GTK-приложений", "GTK backend"), "wayland,x11"],
    ["QT_QPA_PLATFORM", T("Бэкенд Qt-приложений", "Qt backend"), "wayland;xcb"],
    ["QT_QPA_PLATFORMTHEME", T("Тема Qt-приложений", "Qt platform theme"), "qt6ct"],
    ["ELECTRON_OZONE_PLATFORM_HINT", T("Electron на Wayland", "Electron on Wayland"), "auto"],
    ["MOZ_ENABLE_WAYLAND", T("Firefox на Wayland", "Firefox on Wayland"), "1"],
    ["XDG_SESSION_TYPE", T("Тип сессии", "Session type"), "wayland"],
    ["GBM_BACKEND", T("Бэкенд GBM (NVIDIA)", "GBM backend (NVIDIA)"), "nvidia-drm"],
    ["__GLX_VENDOR_LIBRARY_NAME", T("Драйвер GLX (NVIDIA)", "GLX vendor (NVIDIA)"), "nvidia"],
    ["LIBVA_DRIVER_NAME", T("Драйвер видеоускорения", "Video acceleration driver"), "nvidia"],
    ["WLR_NO_HARDWARE_CURSORS", T("Программный курсор (wlroots)", "Software cursor (wlroots)"), "1"],
    ["NVD_BACKEND", T("Бэкенд NVIDIA-декодера видео", "NVIDIA video decode backend"), "direct"]
]
