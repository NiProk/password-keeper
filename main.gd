extends Control
# =====================================================================
#  Хранитель паролей — современный интерфейс.
#  Весь интерфейс (и даже иконки) создаётся кодом, поэтому в сцене
#  нужен только один узел Control с этим скриптом.
#
#  Горячие клавиши:  Ctrl+N — новая запись,  Ctrl+F — поиск,
#                    Ctrl+L — заблокировать,  Esc — закрыть окно.
# =====================================================================

# Файл с паролями. "user://" на Windows — это папка
# %APPDATA%\Godot\app_userdata\PasswordKeeper\
const VAULT_PATH := "user://vault.dat"     # хранилище
const BACKUP_PATH := "user://vault.bak"    # предыдущая версия (на случай сбоя)
const TEMP_PATH := "user://vault.tmp"      # временный файл при сохранении
const LEGACY_PATH := "user://passwords.dat"  # старый формат, переводится автоматически

# Метка в начале файла, чтобы отличить наш формат от чужих файлов
const MAGIC := "PKV2"
# Сколько раз прогонять мастер-пароль через хеш. Чем больше — тем дольше
# перебор пароля для взломщика (и чуть дольше вход для тебя: ~0.5 с).
const KDF_ITERATIONS := 300000

# Через сколько секунд очищать скопированный пароль из буфера обмена
const CLIPBOARD_CLEAR_SEC := 30
# Через сколько секунд бездействия хранилище блокируется само (5 минут)
const AUTO_LOCK_SEC := 300

# Настройки вида (не секретные): сортировка и масштаб
const SETTINGS_PATH := "user://settings.cfg"
# Варианты сортировки: внутреннее имя -> подпись в списке
const SORT_MODES := ["name", "old", "new", "added"]
const SORT_LABELS := ["По названию", "Давно не менялись", "Недавно изменённые", "По добавлению"]
# Пароль старше стольких дней подсвечивается как "пора сменить"
const OLD_PASSWORD_DAYS := 365
# Логотипы сайтов: зашифрованный кэш и сервис, откуда они берутся
const ICONS_PATH := "user://icons.dat"
const ICON_PARALLEL := 4          # сколько логотипов качаем одновременно
const ICON_RETRY_DAYS := 7        # не нашёлся логотип — повторим через неделю
# Иконки рисуются в 2 раза крупнее и уменьшаются — так они чёткие и при масштабе 200%
const ICON_OVERSAMPLE := 2
const C_STAR := Color("f5b83d")

# Защита от двойного запуска: номер "места" (порта), которое занимает
# первая копия программы. Число произвольное, лишь бы не популярное.
const INSTANCE_PORT := 47219
# "Пароль и отзыв": так копии узнают друг друга и не путают с чужой программой.
const INSTANCE_HELLO := "PASSWORD-KEEPER:SHOW\n"
const INSTANCE_REPLY := "PASSWORD-KEEPER:OK\n"
# Через сколько секунд показанный пароль снова прячется
const REVEAL_SEC := 15

# Символы для генератора паролей (без похожих l/1/I/O/0)
const CHARS_LOWER := "abcdefghijkmnopqrstuvwxyz"
const CHARS_UPPER := "ABCDEFGHJKLMNPQRSTUVWXYZ"
const CHARS_DIGITS := "23456789"
const CHARS_SYMBOLS := "!@#$%^&*-_=+?"

# Пропорции колонок таблицы: сервис, логин, пароль, комментарий
const COL_RATIOS := [3.0, 2.2, 2.0, 2.0]
# Ширина блока с кнопками справа: 5 кнопок по 34 пикселя + 4 промежутка по 4
const ACTIONS_WIDTH := 5 * 34 + 4 * 4

# ---------------------------------------------------------------------
#  ПАЛИТРЫ. Две темы — тёмная и светлая. Поменяй цвета здесь, и
#  изменится вся программа. Ключ "BG" превращается в переменную C_BG и т.д.
# ---------------------------------------------------------------------
# Переводы: словарь "русский текст -> английский" лежит в отдельном файле
const LANG_EN := preload("res://lang_en.gd")

const PALETTES := {
	"dark": {
		"BG": "0e1016",            # фон окна
		"SURFACE": "161922",       # карточки
		"SURFACE_2": "1d212c",     # карточка под мышкой, кнопки
		"SURFACE_3": "272b38",     # наведение на кнопки
		"INPUT": "11141b",         # поля ввода
		"BORDER": "262a36",        # рамки
		"BORDER_HOVER": "363b4b",
		"TEXT": "e9ebf1",          # основной текст
		"MUTED": "8a90a2",         # второстепенный текст
		"ACCENT": "7c5cff",        # фирменный фиолетовый
		"ACCENT_HOVER": "9179ff",
		"ACCENT_PRESSED": "6847f0",
		"DANGER": "f04b6a",
		"DANGER_HOVER": "f4667f",
		"WARNING": "f5a524",
		"GOOD": "a3d65c",
		"SUCCESS": "2fcf8f",
	},
	"light": {
		"BG": "f3f4f8",
		"SURFACE": "ffffff",
		"SURFACE_2": "f3f4f8",
		"SURFACE_3": "e7e9f0",
		"INPUT": "ffffff",
		"BORDER": "e1e4eb",
		"BORDER_HOVER": "cdd2dc",
		"TEXT": "1a1d26",
		"MUTED": "686f82",
		"ACCENT": "6b47f5",
		"ACCENT_HOVER": "7c5cff",
		"ACCENT_PRESSED": "5a36e6",
		"DANGER": "e0375a",
		"DANGER_HOVER": "e85273",
		"WARNING": "c47800",
		"GOOD": "5e9c1e",
		"SUCCESS": "13a06a",
	},
}
# Сами цвета — обычные переменные: их заполняет _apply_palette()
var C_BG: Color
var C_SURFACE: Color
var C_SURFACE_2: Color
var C_SURFACE_3: Color
var C_INPUT: Color
var C_BORDER: Color
var C_BORDER_HOVER: Color
var C_TEXT: Color
var C_MUTED: Color
var C_ACCENT: Color
var C_ACCENT_HOVER: Color
var C_ACCENT_PRESSED: Color
var C_DANGER: Color
var C_DANGER_HOVER: Color
var C_WARNING: Color
var C_GOOD: Color
var C_SUCCESS: Color
# То, что в светлой теме должно быть мягче
var shadow_alpha := 0.45     # густота теней
var dim_alpha := 0.6         # затемнение под окнами
var avatar_value := 0.95     # яркость букв в кружках
var theme_mode := "system"   # "system", "dark" или "light"
var current_theme := ""      # какая тема реально включена сейчас
var lang_mode := "system"    # "system", "ru" или "en"

# ---------------------------------------------------------------------
#  ИКОНКИ. Это кусочки SVG-картинок (набор Lucide, свободная лицензия).
#  Функция _icon() превращает их в текстуры прямо во время работы.
# ---------------------------------------------------------------------
const SVG_TEMPLATE := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#%s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">%s</svg>'
const ICONS := {
	"shield": '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>',
	"search": '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
	"plus": '<path d="M5 12h14"/><path d="M12 5v14"/>',
	"eye": '<path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
	"eye_off": '<path d="M9.88 9.88a3 3 0 1 0 4.24 4.24"/><path d="M10.73 5.08A10.43 10.43 0 0 1 12 5c7 0 10 7 10 7a13.16 13.16 0 0 1-1.67 2.68"/><path d="M6.61 6.61A13.53 13.53 0 0 0 2 12s3 7 10 7a9.74 9.74 0 0 0 5.39-1.61"/><path d="M2 2l20 20"/>',
	"user": '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
	"key": '<path d="M2 18v3c0 .6.4 1 1 1h4v-3h3v-3h2l1.4-1.4a6.5 6.5 0 1 0-4-4Z"/><circle cx="16.5" cy="7.5" r="1"/>',
	"external": '<path d="M15 3h6v6"/><path d="M10 14 21 3"/><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>',
	"pencil": '<path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/><path d="m15 5 4 4"/>',
	"trash": '<path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/><path d="M10 11v6"/><path d="M14 11v6"/>',
	"lock": '<rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
	"refresh": '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/>',
	"x": '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
	"check": '<path d="M20 6 9 17l-5-5"/>',
	"alert": '<circle cx="12" cy="12" r="10"/><path d="M12 8v4"/><path d="M12 16h.01"/>',
	"more": '<circle cx="12" cy="5" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="12" cy="19" r="1"/>',
	"save": '<path d="M15.2 3a2 2 0 0 1 1.4.6l3.8 3.8a2 2 0 0 1 .6 1.4V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z"/><path d="M17 21v-7a1 1 0 0 0-1-1H8a1 1 0 0 0-1 1v7"/><path d="M7 3v4a1 1 0 0 0 1 1h7"/>',
	"history": '<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/><path d="M12 7v5l4 2"/>',
	"star": '<polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>',
	"star_on": '<polygon fill="#f5b83d" points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>',
	"sliders": '<path d="M21 4h-7"/><path d="M10 4H3"/><path d="M21 12h-9"/><path d="M8 12H3"/><path d="M21 20h-5"/><path d="M12 20H3"/><path d="M14 2v4"/><path d="M8 10v4"/><path d="M16 18v4"/>',
	"languages": '<path d="m5 8 6 6"/><path d="m4 14 6-6 2-3"/><path d="M2 5h12"/><path d="M7 2h1"/><path d="m22 22-5-10-5 10"/><path d="M14 18h6"/>',
	"sun": '<circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/>',
	"globe": '<circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/>',
}

# ---------------------------------------------------------------------
#  ДАННЫЕ
# ---------------------------------------------------------------------
# Все записи: массив словарей {"url", "login", "password", "comment"}
var entries: Array = []
# Ключи шифрования. Сам мастер-пароль в памяти не хранится —
# только ключи, полученные из него.
var enc_key := PackedByteArray()   # ключ для шифрования AES-256
var mac_key := PackedByteArray()   # ключ для проверки целостности (HMAC)
var salt := PackedByteArray()      # "соль" — случайные байты, свои у каждого хранилища
var iterations := KDF_ITERATIONS
var busy := false                  # идёт проверка пароля — повторные нажатия игнорируем
var notice := ""                   # сообщение, которое покажем после входа
var editing_index := -1    # -1 = новая запись, иначе номер изменяемой
var deleting_index := -1
# Показанные пароли: номер записи -> момент (в мс), когда пароль надо спрятать
var revealed := {}
# Функции, которые перерисовывают пароль в строке: номер записи -> Callable
var row_updaters := {}
var last_activity_ms := 0  # когда пользователь последний раз что-то делал
var settings := ConfigFile.new()
var sort_mode := "name"
var ui_zoom := 1.0                  # ручная подстройка масштаба (Ctrl + / Ctrl -)
var sort_button: OptionButton
var password_counts := {}           # пароль -> в скольких записях он встречается
var dup_filter := false             # показывать только записи с повторами
var dup_button: Button
# Настройки генератора паролей
var gen_length := 18
var gen_upper := true
var gen_digits := true
var gen_symbols := true
var gen_panel: PanelContainer
var gen_length_label: Label
# Логотипы
var icons_enabled := true
# Адрес сервиса логотипов: %s заменяется на адрес сайта (например, github.com)
var icon_url_template := "https://www.google.com/s2/favicons?sz=64&domain=%s"
var icon_cache := {}        # сайт -> {"png": картинка в base64 или "", "t": когда скачали}
var icon_textures := {}     # сайт -> готовая текстура (чтобы не собирать каждый раз)
var icon_queue := []        # сайты, ждущие загрузки
var icon_pending := {}      # сайты в очереди или в процессе загрузки
var icon_active := 0        # сколько загрузок идёт прямо сейчас
var icons_changed := false  # есть новые логотипы, которые надо сохранить
var avatar_slots := {}      # сайт -> квадратики в строках списка, ждущие логотип
var name_input: LineEdit
var instance_server: TCPServer      # "занятое место" первой копии
var instance_clients := []          # подключившиеся вторые копии: [соединение, время подключения]
var last_copied := ""      # последний скопированный пароль

var _icon_cache := {}      # чтобы не рисовать одну иконку дважды
var font_regular: Font
var font_bold: Font
var font_mono: Font

# --- Экран входа ---
var login_screen: CenterContainer
var login_card: PanelContainer
var login_title: Label
var login_subtitle: Label
var master_input: LineEdit
var confirm_input: LineEdit
var open_button: Button
var login_error: Label

# --- Главный экран ---
var main_screen: MarginContainer
var count_label: Label
var search_input: LineEdit
var scroll: ScrollContainer
var list_header: Control
var list_box: VBoxContainer
var empty_state: CenterContainer
var empty_title: Label
var empty_text: Label
var empty_button: Button

# --- Окна поверх интерфейса (модальные) ---
var current_modal: Control = null   # верхнее открытое окно
var modal_stack := []               # все открытые окна, снизу вверх
var discard_modal: Control          # "Закрыть без сохранения?"
var edit_snapshot := []             # значения полей при открытии окна записи
var edit_modal: Control
var edit_title: Label
var url_input: LineEdit
var login_input: LineEdit
var pass_input: LineEdit
var comment_input: LineEdit
# --- Окно смены мастер-пароля ---
var password_modal: Control
var current_pw_input: LineEdit
var new_pw_input: LineEdit
var confirm_pw_input: LineEdit
var change_pw_error: Label
var change_pw_button: Button

# --- Меню "⋮" и работа с файлами ---
var menu: PopupMenu
var file_dialog_open := false     # пока открыт выбор файла, автоблокировка ждёт
# Окно "Восстановить из копии"
var restore_modal: Control
var restore_file_label: Label
var restore_pw_input: LineEdit
var restore_error: Label
var restore_button: Button
var pending_backup := {}          # разобранный файл копии, ждущий пароля
# Окно с результатом (информация + необязательное действие)
var info_modal: Control
var info_tile: PanelContainer
var info_title: Label
var info_text: Label
var info_close_button: Button
var info_action_button: Button
var info_action := Callable()
var edit_error: Label
var delete_modal: Control
var delete_text: Label

# --- Всплывающее уведомление ---
var toast: PanelContainer
var toast_icon: TextureRect
var toast_label: Label
var toast_tween: Tween
var clipboard_timer: Timer


func _ready() -> void:
	# Самое первое — проверить, не запущена ли программа уже.
	if not _claim_single_instance():
		# Уже запущена: попросили её показаться, а сами тихо выходим.
		set_process(false)
		set_process_input(false)
		get_tree().quit()
		return

	_load_settings()
	_register_translations()
	# Переводим сами через tr(). Автоперевод выключаем, иначе Godot попробовал бы
	# "перевести" и данные пользователя (например, комментарий "Готово").
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_setup_window()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

	clipboard_timer = Timer.new()
	clipboard_timer.one_shot = true
	clipboard_timer.timeout.connect(_clear_clipboard_if_ours)
	add_child(clipboard_timer)

	# "Часы" программы: раз в секунду проверяем автоблокировку
	# и прячем пароли, у которых вышло время.
	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(_on_tick)
	add_child(tick)

	_show_login()


# Построить весь интерфейс с текущей палитрой
func _build_ui() -> void:
	_apply_language()
	get_window().title = tr("Хранитель паролей")
	_apply_palette()
	RenderingServer.set_default_clear_color(C_BG)
	# Тема задаётся окну целиком: так её получат и подсказки (tooltip).
	get_window().theme = _build_theme()

	_build_login_screen()
	_build_main_screen()
	_build_edit_modal()
	_build_delete_modal()
	_build_password_modal()
	_build_restore_modal()
	_build_info_modal()
	_build_discard_modal()   # после окна записи — чтобы рисоваться поверх него
	_build_toast()   # последним, чтобы уведомление было поверх всего


# Какая тема должна быть: если "как в системе" — спрашиваем Windows
func _wanted_theme() -> String:
	if theme_mode != "system":
		return theme_mode
	if DisplayServer.is_dark_mode_supported():
		return "dark" if DisplayServer.is_dark_mode() else "light"
	return "dark"


func _apply_palette() -> void:
	current_theme = _wanted_theme()
	var p: Dictionary = PALETTES[current_theme]
	for key in p:
		# set("C_BG", ...) — то же самое, что C_BG = ..., только имя задаём строкой
		set("C_" + key, Color(p[key]))
	var light := current_theme == "light"
	shadow_alpha = 0.10 if light else 0.45
	dim_alpha = 0.35 if light else 0.6
	avatar_value = 0.72 if light else 0.95


# Сменить тему: стираем интерфейс и строим заново. Записи, ключи
# и текст поиска при этом остаются — они хранятся в переменных, а не в кнопках.
func _rebuild_ui() -> void:
	var was_main := main_screen != null and main_screen.visible
	var search := search_input.text if search_input != null else ""
	_close_all_modals()
	if toast_tween:
		toast_tween.kill()
	for child in get_children():
		if child is Timer or child is FileDialog or child is HTTPRequest:
			continue   # таймеры, окно выбора файла и загрузки не трогаем
		remove_child(child)
		child.queue_free()
	row_updaters.clear()
	_icon_cache.clear()   # иконки были нарисованы старыми цветами
	_build_ui()
	if was_main:
		login_screen.hide()
		main_screen.show()
		search_input.text = search
		_refresh_list()
	else:
		_show_login()


# =====================================================================
#  ЯЗЫК ИНТЕРФЕЙСА
#  Все тексты в коде обёрнуты в tr("..."). Godot ищет текст в зарегистрированных
#  переводах для текущего языка и, если находит, возвращает перевод.
#  Для русского перевода нет — tr() возвращает текст как есть.
# =====================================================================

func _register_translations() -> void:
	var en := Translation.new()
	en.locale = "en"
	var ru := Translation.new()
	ru.locale = "ru"
	var strings: Dictionary = LANG_EN.STRINGS
	for text in strings:
		en.add_message(text, strings[text])
		# Русский "перевод" — текст сам в себя. Без него Godot, не найдя
		# русского перевода, взял бы запасной язык (английский).
		ru.add_message(text, text)
	TranslationServer.add_translation(en)
	TranslationServer.add_translation(ru)


func _wanted_language() -> String:
	if lang_mode != "system":
		return lang_mode
	# Язык Windows: для русского и соседних языков — русский, иначе английский
	return "ru" if OS.get_locale_language() in ["ru", "uk", "be", "kk"] else "en"


func _apply_language() -> void:
	TranslationServer.set_locale(_wanted_language())


func _set_lang_mode(mode: String) -> void:
	lang_mode = mode
	_save_settings()
	_rebuild_ui()   # тексты, собранные из кусочков, проще построить заново
	_toast("Language: English" if _wanted_language() == "en" else "Язык: русский")


func _set_theme_mode(mode: String) -> void:
	theme_mode = mode
	_save_settings()
	_rebuild_ui()
	_toast(tr("Тема: ") + {"system": tr("как в системе"), "dark": tr("тёмная"), "light": tr("светлая")}[mode])


func _setup_window() -> void:
	var win := get_window()
	# Не растягивать интерфейс при изменении окна — просто давать больше места.
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	# Когда игра запущена внутри редактора, размер окна менять нельзя.
	# Иконки уменьшаются плавно (через "мипмапы" — заранее уменьшенные копии).
	win.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_apply_ui_scale()
	var ui_scale := win.content_scale_factor
	var embedded: bool = Engine.has_method("is_embedded_in_editor") and Engine.call("is_embedded_in_editor")
	if not embedded:
		# Окно тоже делаем крупнее, но не больше экрана.
		var screen := DisplayServer.screen_get_usable_rect(win.current_screen).size
		win.size = Vector2i(mini(int(1140 * ui_scale), screen.x - 40), mini(int(720 * ui_scale), screen.y - 40))
		win.min_size = Vector2i(mini(int(900 * ui_scale), screen.x - 40), mini(int(560 * ui_scale), screen.y - 40))
		win.move_to_center()


# Масштаб Windows (100%, 125%, 150%…) узнаём по плотности точек экрана:
# 96 точек на дюйм — это 100%, 144 — это 150%.
func _system_scale() -> float:
	var dpi := DisplayServer.screen_get_dpi(get_window().current_screen)
	if dpi <= 0:
		return 1.0
	return clampf(snappedf(dpi / 96.0, 0.25), 1.0, 3.0)


# content_scale_factor увеличивает ВСЁ содержимое окна: шрифты, кнопки, отступы.
func _apply_ui_scale() -> void:
	var target := clampf(_system_scale() * ui_zoom, 0.75, 4.0)
	if not is_equal_approx(get_window().content_scale_factor, target):
		get_window().content_scale_factor = target


func _change_zoom(delta: float) -> void:
	ui_zoom = 1.0 if delta == 0.0 else clampf(snappedf(ui_zoom + delta, 0.1), 0.7, 2.0)
	_apply_ui_scale()
	_save_settings()
	_toast(tr("Масштаб: %d%%") % roundi(ui_zoom * 100))


func _load_settings() -> void:
	settings.load(SETTINGS_PATH)   # если файла нет — просто останутся значения по умолчанию
	sort_mode = settings.get_value("view", "sort", "name")
	if not sort_mode in SORT_MODES:
		sort_mode = "name"
	ui_zoom = clampf(float(settings.get_value("view", "zoom", 1.0)), 0.7, 2.0)
	lang_mode = settings.get_value("view", "language", "system")
	if not lang_mode in ["system", "ru", "en"]:
		lang_mode = "system"
	theme_mode = settings.get_value("view", "theme", "system")
	if not theme_mode in ["system", "dark", "light"]:
		theme_mode = "system"
	gen_length = clampi(int(settings.get_value("generator", "length", 18)), 8, 64)
	gen_upper = bool(settings.get_value("generator", "upper", true))
	gen_digits = bool(settings.get_value("generator", "digits", true))
	gen_symbols = bool(settings.get_value("generator", "symbols", true))
	icons_enabled = bool(settings.get_value("view", "icons", true))


func _save_settings() -> void:
	settings.set_value("view", "sort", sort_mode)
	settings.set_value("view", "zoom", ui_zoom)
	settings.set_value("view", "theme", theme_mode)
	settings.set_value("view", "language", lang_mode)
	settings.set_value("generator", "length", gen_length)
	settings.set_value("generator", "upper", gen_upper)
	settings.set_value("generator", "digits", gen_digits)
	settings.set_value("generator", "symbols", gen_symbols)
	settings.set_value("view", "icons", icons_enabled)
	settings.save(SETTINGS_PATH)


# =====================================================================
#  ТЕМА — как выглядят все кнопки, поля, панели
# =====================================================================

func _build_theme() -> Theme:
	font_regular = _system_font(400)
	font_bold = _system_font(600)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "JetBrains Mono", "DejaVu Sans Mono", "monospace"])
	font_mono = mono

	var t := Theme.new()
	t.default_font = font_regular
	t.default_font_size = 15

	# --- Надписи. Вариации — это "подвиды" Label со своим шрифтом и цветом.
	t.set_color("font_color", "Label", C_TEXT)
	_label_style(t, "Title", font_bold, 20, C_TEXT)
	_label_style(t, "ModalTitle", font_bold, 18, C_TEXT)
	_label_style(t, "Strong", font_bold, 15, C_TEXT)
	_label_style(t, "Muted", font_regular, 14, C_MUTED)
	_label_style(t, "Small", font_regular, 12, C_MUTED)
	_label_style(t, "FieldLabel", font_bold, 13, C_MUTED)
	_label_style(t, "ColumnHeader", font_bold, 12, C_MUTED)
	_label_style(t, "Error", font_regular, 13, C_DANGER)

	# --- Кнопки
	t.set_font("font", "Button", font_bold)
	t.set_constant("h_separation", "Button", 8)
	_button_style(t, "Button", C_SURFACE_2, C_SURFACE_3, C_SURFACE, C_TEXT, C_TEXT, C_BORDER, 16, 10)
	_button_style(t, "AccentButton", C_ACCENT, C_ACCENT_HOVER, C_ACCENT_PRESSED, Color.WHITE, Color.WHITE, Color.TRANSPARENT, 18, 10)
	_button_style(t, "DangerButton", C_DANGER, C_DANGER_HOVER, C_DANGER.darkened(0.15), Color.WHITE, Color.WHITE, Color.TRANSPARENT, 18, 10)
	_button_style(t, "IconButton", C_SURFACE_2, C_SURFACE_3, C_SURFACE, C_MUTED, C_TEXT, C_BORDER, 8, 8)
	_button_style(t, "GhostIcon", Color.TRANSPARENT, C_SURFACE_3, C_SURFACE_2, C_MUTED, C_TEXT, Color.TRANSPARENT, 6, 6)
	_button_style(t, "GhostDanger", Color.TRANSPARENT, Color(C_DANGER, 0.15), Color(C_DANGER, 0.25), C_MUTED, C_DANGER, Color.TRANSPARENT, 6, 6)
	# Звёздочка "в избранном": белый цвет кнопки = иконка остаётся своего, жёлтого цвета
	# Оранжевая "ссылка" про одинаковые пароли
	_button_style(t, "WarnLink", Color.TRANSPARENT, Color(C_WARNING, 0.12), Color(C_WARNING, 0.2), C_WARNING, C_WARNING, Color.TRANSPARENT, 6, 1)
	t.set_font_size("font_size", "WarnLink", 13)
	_button_style(t, "StarOn", Color.TRANSPARENT, C_SURFACE_3, C_SURFACE_2, Color.WHITE, Color.WHITE, Color.TRANSPARENT, 6, 6)
	# Переключатель сортировки — неброский, как надписи колонок
	_button_style(t, "SortButton", Color.TRANSPARENT, C_SURFACE_2, C_SURFACE, C_MUTED, C_TEXT, Color.TRANSPARENT, 10, 4, "OptionButton")
	t.set_font_size("font_size", "SortButton", 13)
	t.set_constant("modulate_arrow", "SortButton", 1)

	# --- Поля ввода
	var le := _sb(C_INPUT, 10, C_BORDER, 1, 12, 10)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("read_only", "LineEdit", le)
	# Рамка фокуса рисуется ПОВЕРХ обычного фона, поэтому без заливки.
	var focus := _sb(Color.TRANSPARENT, 10, C_ACCENT, 2, 12, 10)
	focus.draw_center = false
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_color("font_color", "LineEdit", C_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(C_MUTED, 0.7))
	t.set_color("caret_color", "LineEdit", C_ACCENT)
	t.set_color("selection_color", "LineEdit", Color(C_ACCENT, 0.35))
	t.set_color("clear_button_color", "LineEdit", C_MUTED)
	t.set_color("clear_button_color_pressed", "LineEdit", C_TEXT)

	# --- Панели (карточки)
	_panel_style(t, "Card", _shadow(_sb(C_SURFACE, 18, C_BORDER, 1, 34, 30), 30))
	_panel_style(t, "Modal", _shadow(_sb(C_SURFACE, 16, C_BORDER, 1, 24, 22), 40))
	_panel_style(t, "Row", _sb(C_SURFACE, 12, C_BORDER, 1, 14, 10))
	_panel_style(t, "RowHover", _sb(C_SURFACE_2, 12, C_BORDER_HOVER, 1, 14, 10))
	_panel_style(t, "Toast", _shadow(_sb(C_SURFACE_3, 12, C_BORDER_HOVER, 1, 16, 11), 20))
	t.set_stylebox("panel", "Panel", _sb(C_SURFACE_3, 2))

	# --- Полоса прокрутки: тонкая, без стрелок
	var track := StyleBoxEmpty.new()
	track.content_margin_left = 3
	track.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("scroll_focus", "VScrollBar", track)
	t.set_stylebox("grabber", "VScrollBar", _sb(C_SURFACE_3, 3))
	t.set_stylebox("grabber_highlight", "VScrollBar", _sb(C_BORDER_HOVER, 3))
	t.set_stylebox("grabber_pressed", "VScrollBar", _sb(C_MUTED, 3))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

	# --- Флажки (CheckBox): свои квадратики, нарисованные из SVG
	t.set_icon("unchecked", "CheckBox", _svg_texture('<rect x="2" y="2" width="16" height="16" rx="4" fill="#%s" stroke="#%s" stroke-width="1.5"/>' % [C_INPUT.to_html(false), C_BORDER_HOVER.to_html(false)], 20))
	t.set_icon("checked", "CheckBox", _svg_texture('<rect x="2" y="2" width="16" height="16" rx="4" fill="#%s"/><path d="M6 10.5l2.5 2.5 5.5-6" fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>' % C_ACCENT.to_html(false), 20))
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		t.set_stylebox(st, "CheckBox", _sb(Color.TRANSPARENT, 6, Color.TRANSPARENT, 0, 2, 2))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, "CheckBox", C_TEXT)
	t.set_constant("h_separation", "CheckBox", 8)
	t.set_font_size("font_size", "CheckBox", 14)

	# --- Ползунок (HSlider)
	var slider_track := _sb(C_SURFACE_3, 3)
	slider_track.content_margin_top = 3
	slider_track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", slider_track)
	var filled := _sb(C_ACCENT, 3)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var knob := _svg_texture('<circle cx="10" cy="10" r="8" fill="#ffffff" stroke="#%s" stroke-width="2"/>' % C_ACCENT.to_html(false), 20)
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob)

	_panel_style(t, "OptionsPanel", _sb(C_SURFACE_2, 10, C_BORDER, 1, 14, 10))

	# --- Выпадающее меню
	t.set_stylebox("panel", "PopupMenu", _shadow(_sb(C_SURFACE_2, 12, C_BORDER_HOVER, 1, 6, 6), 18))
	t.set_stylebox("hover", "PopupMenu", _sb(C_SURFACE_3, 8))
	var sep := StyleBoxLine.new()
	sep.color = C_BORDER_HOVER
	sep.thickness = 1
	t.set_stylebox("separator", "PopupMenu", sep)
	t.set_color("font_color", "PopupMenu", C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", C_TEXT)
	t.set_font_size("font_size", "PopupMenu", 14)
	t.set_constant("v_separation", "PopupMenu", 12)
	t.set_constant("h_separation", "PopupMenu", 10)
	t.set_constant("item_start_padding", "PopupMenu", 10)
	t.set_constant("item_end_padding", "PopupMenu", 16)
	t.set_icon("radio_checked", "PopupMenu", _svg_texture('<circle cx="10" cy="10" r="7" fill="none" stroke="#%s" stroke-width="2"/><circle cx="10" cy="10" r="3.5" fill="#%s"/>' % [C_ACCENT.to_html(false), C_ACCENT.to_html(false)], 16))
	t.set_icon("radio_unchecked", "PopupMenu", _svg_texture('<circle cx="10" cy="10" r="7" fill="none" stroke="#%s" stroke-width="2"/>' % C_BORDER_HOVER.to_html(false), 16))
	t.set_icon("checked", "PopupMenu", _svg_texture('<rect x="3" y="3" width="14" height="14" rx="3.5" fill="#%s"/><path d="M6.5 10.2l2.3 2.3 4.7-5" fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>' % C_ACCENT.to_html(false), 16))
	t.set_icon("unchecked", "PopupMenu", _svg_texture('<rect x="3" y="3" width="14" height="14" rx="3.5" fill="none" stroke="#%s" stroke-width="1.6"/>' % C_BORDER_HOVER.to_html(false), 16))
	t.set_icon("submenu", "PopupMenu", _svg_texture('<path d="M8 5l5 5-5 5" fill="none" stroke="#%s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>' % C_MUTED.to_html(false), 16))

	# --- Всплывающие подсказки
	t.set_stylebox("panel", "TooltipPanel", _sb(C_SURFACE_3, 8, C_BORDER_HOVER, 1, 10, 6))
	t.set_color("font_color", "TooltipLabel", C_TEXT)
	t.set_font_size("font_size", "TooltipLabel", 13)
	return t


func _system_font(weight: int) -> SystemFont:
	# SystemFont берёт шрифт, установленный в системе. Первый найденный
	# из списка и будет использован (на Windows это Segoe UI).
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI Variable Text", "Segoe UI", "Inter", "Noto Sans", "Cantarell", "sans-serif"])
	f.font_weight = weight
	return f


# StyleBoxFlat — прямоугольник со скруглёнными углами, рамкой и отступами.
func _sb(bg: Color, radius := 10, border := Color.TRANSPARENT, border_w := 0, pad_h := 0, pad_v := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


func _shadow(s: StyleBoxFlat, size: int) -> StyleBoxFlat:
	s.shadow_color = Color(0, 0, 0, shadow_alpha)
	s.shadow_size = size
	s.shadow_offset = Vector2(0, size * 0.3)
	return s


func _label_style(t: Theme, name: String, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)


func _panel_style(t: Theme, name: String, s: StyleBox) -> void:
	t.set_type_variation(name, "PanelContainer")
	t.set_stylebox("panel", name, s)


func _button_style(t: Theme, name: String, bg: Color, bg_hover: Color, bg_pressed: Color,
		fg: Color, fg_hover: Color, border: Color, pad_h: int, pad_v: int, base := "Button") -> void:
	if name != "Button":
		t.set_type_variation(name, base)
	var bw := 1 if border.a > 0.0 else 0
	t.set_stylebox("normal", name, _sb(bg, 10, border, bw, pad_h, pad_v))
	t.set_stylebox("hover", name, _sb(bg_hover, 10, border, bw, pad_h, pad_v))
	t.set_stylebox("pressed", name, _sb(bg_pressed, 10, border, bw, pad_h, pad_v))
	t.set_stylebox("hover_pressed", name, _sb(bg_pressed, 10, border, bw, pad_h, pad_v))
	t.set_stylebox("disabled", name, _sb(Color(bg, bg.a * 0.4), 10, border, bw, pad_h, pad_v))
	t.set_stylebox("focus", name, StyleBoxEmpty.new())
	for c in ["font_color", "font_focus_color"]:
		t.set_color(c, name, fg)
	for c in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, name, fg_hover)
	t.set_color("font_disabled_color", name, Color(fg, 0.35))
	# Иконки нарисованы белыми, а кнопка перекрашивает их в нужный цвет.
	for c in ["icon_normal_color", "icon_focus_color"]:
		t.set_color(c, name, fg)
	for c in ["icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		t.set_color(c, name, fg_hover)
	t.set_color("icon_disabled_color", name, Color(fg, 0.25))


# =====================================================================
#  МАЛЕНЬКИЕ ПОМОЩНИКИ ДЛЯ СОЗДАНИЯ ЭЛЕМЕНТОВ
# =====================================================================

func _icon(name: String, color := Color.WHITE, size := 18) -> Texture2D:
	var key := "%s_%s_%d" % [name, color.to_html(), size]
	if _icon_cache.has(key):
		return _icon_cache[key]
	var svg: String = SVG_TEMPLATE % [color.to_html(false), ICONS[name]]
	var img := Image.new()
	img.load_svg_from_string(svg, size * ICON_OVERSAMPLE / 24.0)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	# Картинка вдвое больше, но "притворяется" нужного размера.
	tex.set_size_override(Vector2i(size, size))
	_icon_cache[key] = tex
	return tex


# Картинка из произвольного SVG (для флажков и ползунка)
func _svg_texture(inner: String, size: int) -> Texture2D:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20">%s</svg>' % inner
	var img := Image.new()
	img.load_svg_from_string(svg, size * ICON_OVERSAMPLE / 20.0)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	tex.set_size_override(Vector2i(size, size))
	return tex


# Поставить курсор в поле "чуть позже" (когда окно уже покажется).
# Проверяем, что поле всё ещё на экране: интерфейс могли перестроить.
func _focus_later(c: Control) -> void:
	(func():
		if is_instance_valid(c) and c.is_inside_tree():
			c.grab_focus()
	).call_deferred()


func _label(text: String, variation := "") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	return l


# Надпись для ячейки таблицы: обрезается многоточием, если не влезает.
func _cell(text: String, variation := "") -> Label:
	var l := _label(text, variation)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


# Делает элемент колонкой таблицы с нужной пропорцией ширины.
func _col(c: Control, index: int) -> void:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = COL_RATIOS[index]
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _button(text: String, variation := "", icon_name := "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	if icon_name != "":
		b.icon = _icon(icon_name)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _icon_button(icon_name: String, tooltip: String, variation := "GhostIcon", size := 34) -> Button:
	var b := _button("", variation, icon_name)
	b.tooltip_text = tooltip
	b.custom_minimum_size = Vector2(size, size)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


# Цветной квадратик со скруглёнными углами и иконкой внутри.
func _icon_tile(icon_name: String, bg: Color, icon_color: Color, size: int, icon_size: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(size, size)
	p.add_theme_stylebox_override("panel", _sb(bg, int(size * 0.3)))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tr := TextureRect.new()
	tr.texture = _icon(icon_name, icon_color, icon_size)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	p.add_child(tr)
	return p


# Поле пароля + кнопка-глаз "показать/скрыть".
func _password_row(input: LineEdit) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)
	var eye := _icon_button("eye", tr("Показать / скрыть"), "IconButton", 40)
	input.set_meta("eye", eye)   # запоминаем кнопку внутри поля
	eye.pressed.connect(func(): _set_secret(input, not input.secret))
	row.add_child(eye)
	_set_secret(input, true)
	return row


func _set_secret(input: LineEdit, value: bool) -> void:
	input.secret = value
	if input.has_meta("eye"):
		var eye: Button = input.get_meta("eye")
		eye.icon = _icon("eye" if value else "eye_off")


# Подпись над полем + само поле. Возвращает поле.
func _form_field(parent: Control, caption: String, placeholder: String) -> LineEdit:
	var box := _field_box(parent, caption)
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	box.add_child(input)
	return input


func _field_box(parent: Control, caption: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_label(caption, "FieldLabel"))
	parent.add_child(box)
	return box


func _vspace(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


# =====================================================================
#  ЭКРАН ВХОДА
# =====================================================================

func _build_login_screen() -> void:
	login_screen = CenterContainer.new()
	login_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(login_screen)

	login_card = PanelContainer.new()
	login_card.theme_type_variation = "Card"
	login_card.custom_minimum_size = Vector2(420, 0)
	login_screen.add_child(login_card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	login_card.add_child(box)

	var logo := _icon_tile("shield", C_ACCENT, Color.WHITE, 64, 32)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(logo)
	box.add_child(_vspace(4))

	login_title = _label("", "Title")
	login_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(login_title)

	login_subtitle = _label("", "Muted")
	login_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	login_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(login_subtitle)
	box.add_child(_vspace(6))

	master_input = LineEdit.new()
	master_input.placeholder_text = tr("Мастер-пароль")
	# Enter в первом поле: при первом запуске — перейти ко второму полю.
	master_input.text_submitted.connect(func(_t):
		if confirm_input.visible:
			confirm_input.grab_focus()
		else:
			_on_open_pressed()
	)
	box.add_child(_password_row(master_input))

	confirm_input = LineEdit.new()
	confirm_input.placeholder_text = tr("Повторите мастер-пароль")
	confirm_input.secret = true
	confirm_input.text_submitted.connect(func(_t): _on_open_pressed())
	box.add_child(confirm_input)

	login_error = _label("", "Error")
	login_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(login_error)

	open_button = _button("", "AccentButton")
	open_button.custom_minimum_size = Vector2(0, 44)
	open_button.pressed.connect(_on_open_pressed)
	box.add_child(open_button)

	box.add_child(_vspace(4))
	var note := _label(tr("Записи шифруются AES-256, ключ защищён PBKDF2. Всё хранится только на этом компьютере"), "Small")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)


func _vault_exists() -> bool:
	return FileAccess.file_exists(VAULT_PATH) or FileAccess.file_exists(BACKUP_PATH) \
		or FileAccess.file_exists(LEGACY_PATH)


func _update_login_texts() -> void:
	var first_run := not _vault_exists()
	if first_run:
		login_title.text = tr("Создайте хранилище")
		login_subtitle.text = tr("Придумайте мастер-пароль. Восстановить его нельзя, поэтому запомните его хорошо.")
		open_button.text = tr("Создать хранилище")
	else:
		login_title.text = tr("С возвращением")
		login_subtitle.text = tr("Введите мастер-пароль, чтобы открыть хранилище.")
		open_button.text = tr("Открыть")
	confirm_input.visible = first_run


func _show_login() -> void:
	_update_login_texts()
	master_input.text = ""
	confirm_input.text = ""
	login_error.text = ""
	_set_secret(master_input, true)

	main_screen.hide()
	login_screen.show()
	login_screen.modulate.a = 0.0
	create_tween().tween_property(login_screen, "modulate:a", 1.0, 0.25)
	_focus_later(master_input)


func _on_open_pressed() -> void:
	if busy:
		return
	var password := master_input.text
	if password.is_empty():
		_login_fail(tr("Введите пароль."))
		return
	var first_run := not _vault_exists()
	if first_run:
		if password.length() < 4:
			_login_fail(tr("Пароль слишком короткий — минимум 4 символа."))
			return
		if password != confirm_input.text:
			_login_fail(tr("Пароли не совпадают."))
			return

	# Проверка пароля занимает около полсекунды. Сначала показываем
	# "Проверяю…" и ждём два кадра, чтобы надпись успела нарисоваться.
	busy = true
	open_button.disabled = true
	open_button.text = tr("Проверяю…")
	await get_tree().process_frame
	await get_tree().process_frame

	var ok := _create_vault(password) if first_run else _unlock(password)

	busy = false
	open_button.disabled = false
	_update_login_texts()
	if not ok:
		_login_fail(tr("Неверный пароль."))
		return
	_enter_main()


func _login_fail(message: String) -> void:
	login_error.text = message
	master_input.select_all()
	master_input.grab_focus()
	# Карточка "трясётся" влево-вправо, как в телефоне при неверном коде.
	var x := login_card.position.x
	var t := create_tween()
	for offset in [-10, 10, -7, 7, -3, 0]:
		t.tween_property(login_card, "position:x", x + offset, 0.045)


func _enter_main() -> void:
	master_input.text = ""
	confirm_input.text = ""
	revealed.clear()
	last_activity_ms = Time.get_ticks_msec()
	search_input.text = ""
	login_screen.hide()
	main_screen.show()
	main_screen.modulate.a = 0.0
	create_tween().tween_property(main_screen, "modulate:a", 1.0, 0.25)
	_load_icons()
	_refresh_list()
	_queue_missing_icons()
	if notice != "":
		_toast(notice)
		notice = ""


func _lock() -> void:
	_clear_clipboard_if_ours()
	# Стираем ключи из памяти: без мастер-пароля их не восстановить.
	enc_key = PackedByteArray()
	mac_key = PackedByteArray()
	entries = []
	revealed.clear()
	_stop_icons()   # логотипы тоже выдают, на каких сайтах ты есть — стираем из памяти
	_close_all_modals()
	_clear_list()
	_show_login()


# =====================================================================
#  ГЛАВНЫЙ ЭКРАН
# =====================================================================

func _build_main_screen() -> void:
	main_screen = MarginContainer.new()
	main_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_screen.add_theme_constant_override("margin_left", 32)
	main_screen.add_theme_constant_override("margin_right", 32)
	main_screen.add_theme_constant_override("margin_top", 26)
	main_screen.add_theme_constant_override("margin_bottom", 26)
	add_child(main_screen)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 22)
	main_screen.add_child(root)

	# --- Шапка: логотип, название, поиск, кнопки
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	header.add_child(_icon_tile("shield", C_ACCENT, Color.WHITE, 44, 22))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_child(_label(tr("Хранитель паролей"), "Title"))
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 8)
	count_label = _label("", "Muted")
	sub.add_child(count_label)
	dup_button = _button("", "WarnLink")
	dup_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dup_button.pressed.connect(func():
		dup_filter = not dup_filter
		_refresh_list()
	)
	sub.add_child(dup_button)
	titles.add_child(sub)
	header.add_child(titles)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	search_input = LineEdit.new()
	search_input.placeholder_text = tr("Поиск…")
	search_input.custom_minimum_size = Vector2(300, 40)
	search_input.clear_button_enabled = true
	search_input.right_icon = _icon("search", C_MUTED)
	search_input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	search_input.text_changed.connect(func(_t): _refresh_list())
	header.add_child(search_input)

	var add_btn := _button(tr("Добавить"), "AccentButton", "plus")
	add_btn.tooltip_text = tr("Новая запись (Ctrl+N)")
	add_btn.custom_minimum_size = Vector2(0, 40)
	add_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_btn.pressed.connect(func(): _open_edit(-1))
	header.add_child(add_btn)

	# Кнопка "⋮" с выпадающим меню
	var menu_btn := _icon_button("more", tr("Ещё"), "IconButton", 40)
	menu_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(menu_btn)
	menu = PopupMenu.new()
	menu.add_icon_item(_icon("save", C_MUTED), tr("Сделать резервную копию…"), 0)
	menu.add_icon_item(_icon("history", C_MUTED), tr("Восстановить из копии…"), 1)
	menu.add_icon_item(_icon("globe", C_MUTED), tr("Импорт из браузера (CSV)…"), 2)
	menu.add_separator()
	menu.add_icon_item(_icon("key", C_MUTED), tr("Сменить мастер-пароль"), 3)
	menu.add_check_item(tr("Загружать логотипы сайтов"), 5)
	menu.set_item_checked(menu.get_item_index(5), icons_enabled)
	# Подменю "Тема" с тремя вариантами-кружочками (radio)
	var theme_menu := PopupMenu.new()
	theme_menu.add_radio_check_item(tr("Как в системе"), 0)
	theme_menu.add_radio_check_item(tr("Светлая"), 1)
	theme_menu.add_radio_check_item(tr("Тёмная"), 2)
	var modes := ["system", "light", "dark"]
	theme_menu.set_item_checked(modes.find(theme_mode), true)
	theme_menu.id_pressed.connect(func(id: int): _set_theme_mode.call_deferred(modes[id]))
	menu.add_submenu_node_item(tr("Тема"), theme_menu)
	menu.set_item_icon(menu.item_count - 1, _icon("sun", C_MUTED))
	# Подменю языка. Название на двух языках — чтобы его нашёл
	# и тот, кто случайно включил незнакомый язык.
	var lang_menu := PopupMenu.new()
	lang_menu.add_radio_check_item(tr("Как в системе"), 0)
	lang_menu.add_radio_check_item("Русский", 1)
	lang_menu.add_radio_check_item("English", 2)
	var langs := ["system", "ru", "en"]
	lang_menu.set_item_checked(langs.find(lang_mode), true)
	lang_menu.id_pressed.connect(func(id: int): _set_lang_mode.call_deferred(langs[id]))
	menu.add_submenu_node_item("Язык / Language", lang_menu)
	menu.set_item_icon(menu.item_count - 1, _icon("languages", C_MUTED))
	menu.id_pressed.connect(_on_menu)
	add_child(menu)
	menu_btn.pressed.connect(func():
		# Показываем меню под кнопкой, выровняв по её правому краю
		menu.reset_size()
		var r := menu_btn.get_global_rect()
		menu.popup(Rect2i(int(r.end.x) - menu.size.x, int(r.end.y) + 6, 0, 0))
	)

	var lock_btn := _icon_button("lock", tr("Заблокировать (Ctrl+L)"), "IconButton", 40)
	lock_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lock_btn.pressed.connect(_lock)
	header.add_child(lock_btn)

	# --- Список записей с прокруткой
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.get_v_scroll_bar().custom_minimum_size.x = 10
	root.add_child(scroll)

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 10)   # место под полосу прокрутки
	scroll.add_child(pad)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	pad.add_child(content)

	list_header = _build_column_header()
	content.add_child(list_header)

	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 8)
	content.add_child(list_box)

	# --- Заглушка, когда записей нет или поиск ничего не нашёл
	empty_state = CenterContainer.new()
	empty_state.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(empty_state)

	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 10)
	empty_state.add_child(ev)
	var tile := _icon_tile("key", C_SURFACE_2, C_MUTED, 72, 32)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ev.add_child(tile)
	ev.add_child(_vspace(4))
	empty_title = _label("", "ModalTitle")
	empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev.add_child(empty_title)
	empty_text = _label("", "Muted")
	empty_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev.add_child(empty_text)
	ev.add_child(_vspace(6))
	empty_button = _button(tr("Добавить первую запись"), "AccentButton", "plus")
	empty_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	empty_button.pressed.connect(func(): _open_edit(-1))
	ev.add_child(empty_button)


func _build_column_header() -> Control:
	# Отступы такие же, как внутри карточки строки, чтобы колонки совпали.
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 15)
	m.add_theme_constant_override("margin_right", 15)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	m.add_child(h)
	var titles := [tr("СЕРВИС"), tr("ЛОГИН"), tr("ПАРОЛЬ"), tr("КОММЕНТАРИЙ")]
	for k in titles.size():
		var l := _cell(titles[k], "ColumnHeader")
		_col(l, k)
		h.add_child(l)
	# Над колонкой кнопок — переключатель сортировки
	sort_button = OptionButton.new()
	sort_button.theme_type_variation = "SortButton"
	sort_button.custom_minimum_size = Vector2(ACTIONS_WIDTH, 0)
	sort_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sort_button.focus_mode = Control.FOCUS_NONE
	sort_button.tooltip_text = tr("Сортировка (избранное всегда сверху)")
	for k in SORT_LABELS.size():
		sort_button.add_item(tr(SORT_LABELS[k]), k)
	sort_button.select(SORT_MODES.find(sort_mode))
	sort_button.item_selected.connect(func(index: int):
		sort_mode = SORT_MODES[index]
		_save_settings()
		_refresh_list()
	)
	h.add_child(sort_button)
	return m


func _clear_list() -> void:
	row_updaters.clear()   # старые строки удаляются — их функции больше не нужны
	avatar_slots.clear()
	for child in list_box.get_children():
		list_box.remove_child(child)
		child.queue_free()


# Полностью перерисовать список по массиву entries (с учётом поиска)
func _refresh_list() -> void:
	_clear_list()
	var query := search_input.text.strip_edges().to_lower()
	# Собираем номера подходящих записей и сортируем их.
	# Сами записи в entries не переставляем — номер i остаётся "адресом" записи.
	# Считаем, сколько раз встречается каждый пароль (пустые не считаем).
	password_counts.clear()
	for e in entries:
		var pw: String = e.get("password", "")
		if pw != "":
			password_counts[pw] = password_counts.get(pw, 0) + 1
	var dup_total := 0
	for e in entries:
		if password_counts.get(e.get("password", ""), 0) > 1:
			dup_total += 1
	if dup_total == 0:
		dup_filter = false   # повторов не осталось — фильтр не нужен

	var order := []
	for i in entries.size():
		if dup_filter and password_counts.get(entries[i].get("password", ""), 0) < 2:
			continue
		if query == "" or _matches(entries[i], query):
			order.append(i)
	order.sort_custom(_entry_before)
	for i in order:
		list_box.add_child(_make_row(i))
	var shown := order.size()

	count_label.text = _count_text(entries.size())
	dup_button.visible = dup_total > 0
	if dup_filter:
		dup_button.text = tr("Показать все записи")
		dup_button.icon = null
	else:
		dup_button.text = tr("%d %s с одинаковыми паролями") % [dup_total, _plural(dup_total, tr("запись"), tr("записи"), tr("записей"))]
		dup_button.icon = _icon("alert", Color.WHITE, 14)
	dup_button.tooltip_text = tr("Один пароль на нескольких сайтах опасен: утечка с одного сайта откроет все.")
	scroll.visible = shown > 0
	empty_state.visible = shown == 0
	if entries.is_empty():
		empty_title.text = tr("Здесь пока пусто")
		empty_text.text = tr("Сохраните первый пароль — он будет зашифрован.")
		empty_button.visible = true
	else:
		empty_title.text = tr("Ничего не найдено")
		empty_text.text = tr("Попробуйте изменить запрос.")
		empty_button.visible = false


func _matches(e: Dictionary, query: String) -> bool:
	for key in ["name", "url", "login", "comment"]:
		if str(e.get(key, "")).to_lower().contains(query):
			return true
	return false


# "1 запись", "3 записи", "7 записей" — русские окончания
func _count_text(n: int) -> String:
	return "%d %s" % [n, _plural(n, tr("запись"), tr("записи"), tr("записей"))]


# Из "https://www.vk.com/feed" получаем "vk.com"
func _host_of(url: String) -> String:
	var s := url.strip_edges().to_lower()
	var p := s.find("://")
	if p != -1:
		s = s.substr(p + 3)
	if s.begins_with("www."):
		s = s.substr(4)
	for sep in ["/", "?", "#"]:
		var k := s.find(sep)
		if k != -1:
			s = s.substr(0, k)
	# Без точки это не адрес сайта, а просто название ("Роутер") — оставляем как есть.
	if not s.contains("."):
		return url.strip_edges()
	return s


# Кружок с первой буквой сервиса. Цвет зависит от названия,
# поэтому у одного и того же сайта он всегда одинаковый.
# Квадратик слева от названия: логотип сайта, а пока его нет — первая буква.
func _avatar(host: String, title: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(40, 40)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.set_meta("title", title)
	_fill_avatar(p, host)
	# Запоминаем квадратик: когда логотип скачается, подставим его сюда.
	if host.contains("."):
		if not avatar_slots.has(host):
			avatar_slots[host] = []
		avatar_slots[host].append(p)
	return p


func _fill_avatar(p: PanelContainer, host: String) -> void:
	for c in p.get_children():
		p.remove_child(c)
		c.queue_free()
	var tex := _icon_texture(host)
	if tex != null:
		# Светлая подложка: многие логотипы тёмные и пропали бы на тёмном фоне.
		p.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.94), 12, C_BORDER, 1, 8, 8))
		var tr_icon := TextureRect.new()
		tr_icon.texture = tex
		tr_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p.add_child(tr_icon)
		return
	var title: String = p.get_meta("title", host)
	var key := title if title != "" else host
	var hue := float(absi(key.to_lower().hash()) % 360) / 360.0
	var color := Color.from_hsv(hue, 0.6, avatar_value)
	p.add_theme_stylebox_override("panel", _sb(Color(color, 0.16), 12))
	var l := Label.new()
	l.text = key.substr(0, 1).to_upper() if key != "" else "?"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", font_bold)
	l.add_theme_font_size_override("font_size", 17)
	p.add_child(l)


# Одна строка-карточка списка
func _make_row(i: int) -> Control:
	var e: Dictionary = entries[i]
	var url: String = e.get("url", "")
	var login: String = e.get("login", "")
	var password: String = e.get("password", "")
	var comment: String = e.get("comment", "")
	var host := _host_of(url)

	var card := PanelContainer.new()
	card.theme_type_variation = "Row"
	# Подсветка при наведении мыши
	card.mouse_entered.connect(func(): card.theme_type_variation = "RowHover")
	card.mouse_exited.connect(func(): card.theme_type_variation = "Row")
	# Двойной клик по строке — редактирование
	card.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.double_click and ev.button_index == MOUSE_BUTTON_LEFT:
			_open_edit(i)
	)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	card.add_child(h)

	# 1. Сервис: кружок + название + полная ссылка
	var svc := HBoxContainer.new()
	svc.add_theme_constant_override("separation", 12)
	_col(svc, 0)
	var fav := bool(e.get("favorite", false))
	var star := _icon_button("star_on" if fav else "star",
		tr("Убрать из избранного") if fav else tr("В избранное"), "StarOn" if fav else "GhostIcon", 28)
	if fav:
		star.icon = _icon("star_on", C_STAR)
	star.pressed.connect(func(): _toggle_favorite(i))
	svc.add_child(star)
	var title := _display_name(e)
	svc.add_child(_avatar(host, title))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_child(_cell(title if title != "" else tr("Без ссылки"), "Strong"))
	if url != "" and url != title:
		names.add_child(_cell(url, "Small"))
	svc.add_child(names)
	h.add_child(svc)

	# 2. Логин
	var login_label := _cell(login if login != "" else "—", "" if login != "" else "Muted")
	_col(login_label, 1)
	h.add_child(login_label)

	# 3. Пароль (точки или сам пароль) + глаз, а под ними — когда менялся
	var pw_col := VBoxContainer.new()
	pw_col.add_theme_constant_override("separation", 0)
	_col(pw_col, 2)
	var pw := HBoxContainer.new()
	pw.add_theme_constant_override("separation", 6)
	pw_col.add_child(pw)
	var changed := int(e.get("changed", 0))
	var date_label := _cell(_changed_text(changed), "Small")
	date_label.add_theme_font_size_override("font_size", 11)
	if changed > 0 and _days_since(changed) >= OLD_PASSWORD_DAYS:
		date_label.add_theme_color_override("font_color", C_WARNING)   # пора сменить
	pw_col.add_child(date_label)
	var eye := _icon_button("eye", tr("Показать пароль"), "GhostIcon", 30)
	eye.disabled = password == ""
	pw.add_child(eye)
	var pw_label := _cell("")
	pw_label.add_theme_font_override("font", font_mono)
	pw_label.add_theme_font_size_override("font_size", 14)
	pw.add_child(pw_label)
	var same := int(password_counts.get(password, 0)) - 1
	if same > 0:
		var warn := TextureRect.new()
		warn.texture = _icon("alert", C_WARNING, 16)
		warn.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		warn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		warn.mouse_filter = Control.MOUSE_FILTER_PASS   # чтобы показывалась подсказка
		warn.tooltip_text = tr("Такой же пароль ещё в %d %s") % [same, _plural(same, tr("записи"), tr("записях"), tr("записях"))]
		pw.add_child(warn)
		pw.move_child(warn, 1)   # сразу после "глаза", перед точками
	# Функцию можно положить в переменную и вызывать через .call()
	var update_pw := func():
		var shown := revealed.has(i)
		if password == "":
			pw_label.text = "—"
		else:
			pw_label.text = password if shown else "••••••••"
		eye.icon = _icon("eye_off" if shown else "eye")
		eye.tooltip_text = tr("Скрыть пароль") if shown else tr("Показать пароль (на %d с)") % REVEAL_SEC
	update_pw.call()
	# Запоминаем функцию, чтобы "часы" могли спрятать пароль в этой строке.
	row_updaters[i] = update_pw
	eye.pressed.connect(func():
		if revealed.has(i):
			revealed.erase(i)
		else:
			revealed[i] = Time.get_ticks_msec() + REVEAL_SEC * 1000
		update_pw.call()
	)
	h.add_child(pw_col)

	# 4. Комментарий
	# Перенос строки в списке заменяем пробелом, чтобы строка не растягивалась.
	var comment_label := _cell(comment.replace("\r", "").replace("\n", " "), "Muted")
	_col(comment_label, 3)
	h.add_child(comment_label)

	# 5. Кнопки действий
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	actions.custom_minimum_size = Vector2(ACTIONS_WIDTH, 0)
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var b_login := _icon_button("user", tr("Копировать логин"))
	b_login.pressed.connect(func(): _copy(login, tr("Логин")))
	var b_pass := _icon_button("key", tr("Копировать пароль"))
	b_pass.pressed.connect(func(): _copy(password, tr("Пароль"), true))
	var b_open := _icon_button("external", tr("Открыть сайт"))
	b_open.disabled = not host.contains(".")   # открыть можно только адрес сайта
	b_open.pressed.connect(func(): _open_url(url))
	var b_edit := _icon_button("pencil", tr("Изменить"))
	b_edit.pressed.connect(func(): _open_edit(i))
	var b_del := _icon_button("trash", tr("Удалить"), "GhostDanger")
	b_del.pressed.connect(func(): _ask_delete(i))
	for b in [b_login, b_pass, b_open, b_edit, b_del]:
		actions.add_child(b)
	h.add_child(actions)
	return card


func _copy(text: String, what: String, is_secret := false) -> void:
	if text == "":
		_toast(tr("%s не заполнен") % what, false)
		return
	DisplayServer.clipboard_set(text)
	if is_secret:
		last_copied = text
		clipboard_timer.start(CLIPBOARD_CLEAR_SEC)
		_toast(tr("%s скопирован · буфер очистится через %d с") % [what, CLIPBOARD_CLEAR_SEC])
	else:
		_toast(tr("%s скопирован") % what)


# Очищаем буфер, только если там всё ещё наш пароль
func _clear_clipboard_if_ours() -> void:
	if last_copied != "" and DisplayServer.clipboard_get() == last_copied:
		DisplayServer.clipboard_set("")
	last_copied = ""


func _open_url(url: String) -> void:
	if url == "":
		return
	OS.shell_open(url if url.contains("://") else "https://" + url)


# =====================================================================
#  МОДАЛЬНЫЕ ОКНА (затемнение + карточка по центру)
# =====================================================================

func _create_modal(width: int) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP   # блокирует клики под собой
	overlay.visible = false
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, dim_alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.theme_type_variation = "Modal"
	card.custom_minimum_size = Vector2(width, 0)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)
	overlay.set_meta("box", box)   # чтобы потом достать и наполнить
	return overlay


# Окна лежат стопкой: новое открывается поверх, Esc закрывает верхнее.
func _open_modal(m: Control) -> void:
	modal_stack.erase(m)
	modal_stack.append(m)
	current_modal = m
	if m.has_meta("tween"):
		(m.get_meta("tween") as Tween).kill()
	m.visible = true
	m.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(m, "modulate:a", 1.0, 0.16)
	m.set_meta("tween", t)


func _close_modal() -> void:
	if modal_stack.is_empty():
		return
	var m: Control = modal_stack.pop_back()
	current_modal = modal_stack.back() if not modal_stack.is_empty() else null
	if m.has_meta("tween"):
		(m.get_meta("tween") as Tween).kill()
	var t := create_tween()
	t.tween_property(m, "modulate:a", 0.0, 0.12)
	t.tween_callback(m.hide)
	m.set_meta("tween", t)


func _close_all_modals() -> void:
	for m in modal_stack:
		if m.has_meta("tween"):
			(m.get_meta("tween") as Tween).kill()
		m.hide()
	modal_stack.clear()
	current_modal = null


# Закрыть верхнее окно "по-вежливому": если в окне записи есть
# несохранённые изменения — сначала спросить.
func _request_close() -> void:
	if current_modal == edit_modal and _edit_is_dirty():
		_open_modal(discard_modal)
	else:
		_close_modal()


func _edit_values() -> Array:
	return [name_input.text, url_input.text, login_input.text, pass_input.text, comment_input.text]


func _edit_is_dirty() -> bool:
	return _edit_values() != edit_snapshot


func _build_discard_modal() -> void:
	discard_modal = _create_modal(420)
	var box: VBoxContainer = discard_modal.get_meta("box")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.add_child(_icon_tile("alert", Color(C_WARNING, 0.15), C_WARNING, 48, 22))
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 4)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(_label(tr("Закрыть без сохранения?"), "ModalTitle"))
	var text := _label(tr("Изменения в записи будут потеряны."), "Muted")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(text)
	top.add_child(texts)
	box.add_child(top)
	box.add_child(_vspace(4))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	var keep := _button(tr("Продолжить"), "AccentButton")
	keep.pressed.connect(_close_modal)          # закрываем только вопрос
	buttons.add_child(keep)
	var discard := _button(tr("Не сохранять"), "DangerButton")
	discard.pressed.connect(func():
		_close_modal()   # вопрос
		_close_modal()   # и окно записи
	)
	buttons.add_child(discard)
	box.add_child(buttons)


func _modal_header(box: VBoxContainer) -> Label:
	var h := HBoxContainer.new()
	var title := _label("", "ModalTitle")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(title)
	var close := _icon_button("x", tr("Закрыть (Esc)"), "GhostIcon", 32)
	close.pressed.connect(_request_close)
	h.add_child(close)
	box.add_child(h)
	return title


# --- Окно добавления / редактирования ---
func _build_edit_modal() -> void:
	edit_modal = _create_modal(500)
	var box: VBoxContainer = edit_modal.get_meta("box")
	edit_title = _modal_header(box)

	# Название и ссылка — в одну строку, чтобы окно не вырастало
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	box.add_child(top_row)
	name_input = _form_field(top_row, tr("Название"), tr("Например: GitHub"))
	name_input.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	url_input = _form_field(top_row, tr("Ссылка на сервис"), "https://example.com")
	url_input.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	url_input.get_parent().size_flags_stretch_ratio = 1.4
	# Пока название пустое, подсказываем в нём адрес сайта
	url_input.text_changed.connect(func(t: String):
		var host := _host_of(t)
		name_input.placeholder_text = host if host != "" else tr("Например: GitHub")
	)
	login_input = _form_field(box, tr("Логин"), tr("Email или имя пользователя"))

	var pw_box := _field_box(box, tr("Пароль"))
	pass_input = LineEdit.new()
	pass_input.placeholder_text = tr("Пароль")
	var row := _password_row(pass_input)
	var gen := _icon_button("refresh", tr("Сгенерировать надёжный пароль"), "IconButton", 40)
	gen.pressed.connect(_fill_generated_password)
	row.add_child(gen)
	var gen_opts := _icon_button("sliders", tr("Настройки генератора"), "IconButton", 40)
	gen_opts.toggle_mode = true
	gen_opts.toggled.connect(func(on: bool): gen_panel.visible = on)
	row.add_child(gen_opts)
	pw_box.add_child(row)

	pw_box.add_child(_strength_meter(pass_input))
	gen_panel = _build_generator_panel()
	gen_panel.visible = false
	pw_box.add_child(gen_panel)

	comment_input = _form_field(box, tr("Комментарий"), tr("Необязательно"))

	edit_error = _label("", "Error")
	box.add_child(edit_error)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	var cancel := _button(tr("Отмена"))
	cancel.pressed.connect(_request_close)
	buttons.add_child(cancel)
	var save := _button(tr("Сохранить"), "AccentButton", "check")
	save.pressed.connect(_on_edit_confirmed)
	buttons.add_child(save)
	box.add_child(buttons)

	# Enter в любом поле = "Сохранить"
	for input in [name_input, url_input, login_input, pass_input, comment_input]:
		input.text_submitted.connect(func(_t): _on_edit_confirmed())


func _fill_generated_password() -> void:
	pass_input.text = _generate_password()
	_set_secret(pass_input, false)   # показать сгенерированный пароль
	_update_strength(pass_input)


# Панель настроек генератора: длина + какие символы использовать
func _build_generator_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "OptionsPanel"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var len_row := HBoxContainer.new()
	len_row.add_theme_constant_override("separation", 12)
	var cap := _label(tr("Длина"), "FieldLabel")
	cap.custom_minimum_size = Vector2(56, 0)
	len_row.add_child(cap)
	var slider := HSlider.new()
	slider.min_value = 8
	slider.max_value = 64
	slider.step = 1
	slider.value = gen_length
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	len_row.add_child(slider)
	gen_length_label = _label(str(gen_length), "Strong")
	gen_length_label.custom_minimum_size = Vector2(28, 0)
	gen_length_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	len_row.add_child(gen_length_label)
	slider.value_changed.connect(func(value: float):
		gen_length = int(value)
		gen_length_label.text = str(gen_length)
		_on_generator_changed()
	)
	v.add_child(len_row)

	var checks := HBoxContainer.new()
	checks.add_theme_constant_override("separation", 18)
	checks.add_child(_gen_check("A–Z", gen_upper, func(on): gen_upper = on))
	checks.add_child(_gen_check("0–9", gen_digits, func(on): gen_digits = on))
	checks.add_child(_gen_check("!@#$%", gen_symbols, func(on): gen_symbols = on))
	var note := _label(tr("a–z есть всегда"), "Small")
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	checks.add_child(note)
	v.add_child(checks)
	return panel


func _gen_check(text: String, value: bool, setter: Callable) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = value
	cb.focus_mode = Control.FOCUS_NONE
	cb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cb.toggled.connect(func(on: bool):
		setter.call(on)
		_on_generator_changed()
	)
	return cb


# Любая настройка поменялась — запоминаем и сразу показываем новый пароль
func _on_generator_changed() -> void:
	_save_settings()
	_fill_generated_password()


func _open_edit(i: int) -> void:
	editing_index = i
	var e: Dictionary = entries[i] if i >= 0 else {}
	edit_title.text = tr("Новая запись") if i < 0 else tr("Изменить запись")
	name_input.text = e.get("name", "")
	url_input.text = e.get("url", "")
	url_input.text_changed.emit(url_input.text)   # обновить подсказку в названии
	login_input.text = e.get("login", "")
	pass_input.text = e.get("password", "")
	comment_input.text = e.get("comment", "")
	edit_error.text = ""
	_set_secret(pass_input, true)
	_update_strength(pass_input)
	edit_snapshot = _edit_values()   # запоминаем, как было — чтобы заметить изменения
	_open_modal(edit_modal)
	_focus_later(name_input)


func _on_edit_confirmed() -> void:
	var entry_name := name_input.text.strip_edges()
	var url := url_input.text.strip_edges()
	var login := login_input.text.strip_edges()
	if entry_name == "" and url == "" and login == "":
		edit_error.text = tr("Укажите название, ссылку или логин.")
		return
	var is_new := editing_index == -1
	var old: Dictionary = {} if is_new else entries[editing_index]
	var e := {
		"name": entry_name,
		"url": url,
		"login": login,
		"password": pass_input.text,
		"comment": comment_input.text.strip_edges(),
		"favorite": bool(old.get("favorite", false)),
		# Дата меняется, только если поменялся сам пароль
		"changed": int(old.get("changed", 0)),
	}
	if is_new or pass_input.text != str(old.get("password", "")):
		e["changed"] = int(Time.get_unix_time_from_system())
	if is_new:
		entries.append(e)
	else:
		entries[editing_index] = e
	_save()
	_close_modal()
	_refresh_list()
	_queue_missing_icons()   # могла появиться новая ссылка
	_toast(tr("Запись добавлена") if is_new else tr("Изменения сохранены"))


# --- Окно подтверждения удаления ---
func _build_delete_modal() -> void:
	delete_modal = _create_modal(440)
	var box: VBoxContainer = delete_modal.get_meta("box")

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.add_child(_icon_tile("trash", Color(C_DANGER, 0.15), C_DANGER, 48, 22))
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 4)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(_label(tr("Удалить запись?"), "ModalTitle"))
	delete_text = _label("", "Muted")
	delete_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(delete_text)
	top.add_child(texts)
	box.add_child(top)
	box.add_child(_vspace(4))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	var cancel := _button(tr("Отмена"))
	cancel.pressed.connect(_close_modal)
	buttons.add_child(cancel)
	var del := _button(tr("Удалить"), "DangerButton", "trash")
	del.pressed.connect(_on_delete_confirmed)
	buttons.add_child(del)
	box.add_child(buttons)


func _ask_delete(i: int) -> void:
	deleting_index = i
	var e: Dictionary = entries[i]
	var entry_name := _display_name(e)
	if entry_name == "":
		entry_name = tr("без названия")
	delete_text.text = tr("«%s» будет удалена без возможности восстановления.") % entry_name
	_open_modal(delete_modal)


func _on_delete_confirmed() -> void:
	entries.remove_at(deleting_index)
	revealed.clear()   # номера записей сдвинулись
	_save()
	_close_modal()
	_refresh_list()
	_toast(tr("Запись удалена"))


# --- Окно смены мастер-пароля ---
func _build_password_modal() -> void:
	password_modal = _create_modal(480)
	var box: VBoxContainer = password_modal.get_meta("box")
	var title := _modal_header(box)
	title.text = tr("Смена мастер-пароля")

	var cur_box := _field_box(box, tr("Текущий мастер-пароль"))
	current_pw_input = LineEdit.new()
	current_pw_input.placeholder_text = tr("Текущий пароль")
	cur_box.add_child(_password_row(current_pw_input))

	var new_box := _field_box(box, tr("Новый мастер-пароль"))
	new_pw_input = LineEdit.new()
	new_pw_input.placeholder_text = tr("Новый пароль")
	new_box.add_child(_password_row(new_pw_input))
	new_box.add_child(_strength_meter(new_pw_input))

	var conf_box := _field_box(box, tr("Повторите новый пароль"))
	confirm_pw_input = LineEdit.new()
	confirm_pw_input.placeholder_text = tr("Ещё раз новый пароль")
	confirm_pw_input.secret = true
	conf_box.add_child(confirm_pw_input)

	var hint := _label(tr("Запомните новый пароль: восстановить его будет нельзя."), "Muted")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	change_pw_error = _label("", "Error")
	box.add_child(change_pw_error)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	var cancel := _button(tr("Отмена"))
	cancel.pressed.connect(_close_modal)
	buttons.add_child(cancel)
	change_pw_button = _button(tr("Сменить пароль"), "AccentButton", "key")
	change_pw_button.pressed.connect(_on_change_password)
	buttons.add_child(change_pw_button)
	box.add_child(buttons)

	# Enter: переходим к следующему полю, в последнем — подтверждаем
	current_pw_input.text_submitted.connect(func(_t): new_pw_input.grab_focus())
	new_pw_input.text_submitted.connect(func(_t): confirm_pw_input.grab_focus())
	confirm_pw_input.text_submitted.connect(func(_t): _on_change_password())


func _open_password_modal() -> void:
	for input in [current_pw_input, new_pw_input, confirm_pw_input]:
		input.text = ""
	_set_secret(current_pw_input, true)
	_set_secret(new_pw_input, true)
	_update_strength(new_pw_input)
	change_pw_error.text = ""
	change_pw_button.text = tr("Сменить пароль")
	change_pw_button.disabled = false
	_open_modal(password_modal)
	_focus_later(current_pw_input)


func _on_change_password() -> void:
	if busy:
		return
	var current := current_pw_input.text
	var new_pw := new_pw_input.text
	# Сначала простые проверки — они мгновенные.
	if current.is_empty():
		change_pw_error.text = tr("Введите текущий пароль.")
		return
	if new_pw.length() < 4:
		change_pw_error.text = tr("Новый пароль слишком короткий — минимум 4 символа.")
		return
	if new_pw != confirm_pw_input.text:
		change_pw_error.text = tr("Новые пароли не совпадают.")
		return
	if new_pw == current:
		change_pw_error.text = tr("Новый пароль совпадает с текущим.")
		return

	busy = true
	change_pw_button.disabled = true
	change_pw_button.text = tr("Меняю…")
	change_pw_error.text = ""
	await get_tree().process_frame
	await get_tree().process_frame

	var result := _change_master_password(current, new_pw)

	busy = false
	change_pw_button.disabled = false
	change_pw_button.text = tr("Сменить пароль")
	last_activity_ms = Time.get_ticks_msec()   # пока считали, мышь не двигалась
	if result != "":
		change_pw_error.text = result
		if result == tr("Текущий пароль неверный."):
			current_pw_input.select_all()
			current_pw_input.grab_focus()
		return
	_close_modal()
	_toast(tr("Мастер-пароль изменён"))


# Сама смена. Возвращает "" при успехе или текст ошибки.
func _change_master_password(current: String, new_pw: String) -> String:
	# 1. Проверяем текущий пароль: он должен дать те же ключи, что сейчас в памяти.
	var old_enc := enc_key
	var old_mac := mac_key
	var old_salt := salt
	var old_iterations := iterations
	_derive_keys(current)
	if enc_key != old_enc or mac_key != old_mac:
		enc_key = old_enc
		mac_key = old_mac
		return tr("Текущий пароль неверный.")

	# 2. Новая соль и новые ключи из нового пароля.
	salt = Crypto.new().generate_random_bytes(16)
	iterations = KDF_ITERATIONS
	_derive_keys(new_pw)

	# 3. Сохраняем ДВАЖДЫ. После первого сохранения в vault.bak попадает
	#    старый файл, зашифрованный СТАРЫМ паролем. Второе сохранение
	#    заменяет его копией с новым паролем — иначе старый пароль
	#    всё ещё открывал бы резервную копию.
	if not _save():
		# Не получилось — возвращаем старые ключи, на диске ничего не поменялось.
		enc_key = old_enc
		mac_key = old_mac
		salt = old_salt
		iterations = old_iterations
		return tr("Не удалось сохранить файл. Пароль не изменён.")
	_save()
	_save_icons()   # и кэш логотипов — новым ключом
	return ""


# =====================================================================
#  РЕЗЕРВНЫЕ КОПИИ И ИМПОРТ
# =====================================================================

# Какие названия колонок бывают в CSV разных программ.
# Chrome / Edge / Яндекс:  name, url, username, password, note
# Firefox:                 url, username, password, httpRealm, ...
# Bitwarden:               name, notes, login_uri, login_username, login_password, ...
# KeePass / KeePassXC:     Title / Account, Username / Login Name, Password, URL / Web Site, Notes / Comments
const CSV_COLUMNS := {
	"url": ["url", "login_uri", "web site", "website", "origin", "hostname"],
	"login": ["username", "login_username", "login name", "login", "user name", "user", "email"],
	"password": ["password", "login_password"],
	"comment": ["note", "notes", "comments", "comment"],
	"name": ["name", "title", "account"],
	"changed": ["timepasswordchanged"],   # Firefox: когда менялся пароль (в миллисекундах)
}


func _on_menu(id: int) -> void:
	match id:
		0:
			var file_name := "PasswordKeeper-backup-%s.dat" % Time.get_date_string_from_system()
			_ask_file(true, tr("Куда сохранить резервную копию"), PackedStringArray([tr("*.dat ; Резервная копия")]),
				OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS), file_name, _make_backup)
		1:
			_ask_file(false, tr("Выберите резервную копию"), PackedStringArray([tr("*.dat ; Резервная копия")]),
				OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS), "", _on_restore_file_chosen)
		2:
			_ask_file(false, tr("Выберите CSV-файл с паролями"), PackedStringArray([tr("*.csv ; CSV из браузера")]),
				OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS), "", _import_csv)
		3:
			_open_password_modal()
		5:
			_set_icons_enabled(not icons_enabled)


# Открыть окно выбора файла. На Windows это будет обычное системное окно.
func _ask_file(save: bool, title: String, filters: PackedStringArray, dir: String,
		file_name: String, on_chosen: Callable) -> void:
	var fd := FileDialog.new()
	fd.use_native_dialog = true
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE if save else FileDialog.FILE_MODE_OPEN_FILE
	fd.title = title
	fd.filters = filters
	fd.current_dir = dir
	if file_name != "":
		fd.current_file = file_name
	var finish := func():
		file_dialog_open = false
		last_activity_ms = Time.get_ticks_msec()
		fd.queue_free()
	fd.file_selected.connect(func(path: String):
		finish.call()
		if enc_key.is_empty():
			return   # хранилище успели заблокировать — ничего не делаем
		on_chosen.call(path)
	)
	fd.canceled.connect(finish)
	add_child(fd)
	file_dialog_open = true
	fd.popup_centered_ratio(0.6)


# --- Сделать копию: просто копируем зашифрованный vault.dat ---
func _make_backup(path: String) -> void:
	if not path.to_lower().ends_with(".dat"):
		path += ".dat"
	if not FileAccess.file_exists(VAULT_PATH) and not _save():
		return
	var data := FileAccess.get_file_as_bytes(VAULT_PATH)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_show_info(tr("Не удалось сохранить копию"), tr("Нет доступа к файлу:\n%s") % path, "alert", C_DANGER)
		return
	file.store_buffer(data)
	file.close()
	# Читаем обратно и сравниваем — копия, которая не читается, хуже, чем никакой.
	if FileAccess.get_file_as_bytes(path) != data:
		_show_info(tr("Не удалось сохранить копию"), tr("Файл записался с ошибкой:\n%s") % path, "alert", C_DANGER)
		return
	_show_info(tr("Резервная копия сохранена"), tr("%s\n\nКопия зашифрована текущим мастер-паролем — хранить её в облаке безопасно. Чтобы достать из неё записи, выберите в меню «Восстановить из копии».") % path, "check", C_SUCCESS)


# --- Восстановить из копии ---
func _build_restore_modal() -> void:
	restore_modal = _create_modal(480)
	var box: VBoxContainer = restore_modal.get_meta("box")
	var title := _modal_header(box)
	title.text = tr("Восстановить из копии")
	restore_file_label = _label("", "Muted")
	restore_file_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(restore_file_label)

	var pw_box := _field_box(box, tr("Мастер-пароль этой копии"))
	restore_pw_input = LineEdit.new()
	restore_pw_input.placeholder_text = tr("Пароль, который был, когда делали копию")
	pw_box.add_child(_password_row(restore_pw_input))
	restore_pw_input.text_submitted.connect(func(_t): _on_restore_confirm())

	var hint := _label(tr("Записи из копии добавятся к текущим, одинаковые пропустятся. Ничего не удалится."), "Muted")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	restore_error = _label("", "Error")
	box.add_child(restore_error)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	var cancel := _button(tr("Отмена"))
	cancel.pressed.connect(_close_modal)
	buttons.add_child(cancel)
	restore_button = _button(tr("Восстановить"), "AccentButton", "history")
	restore_button.pressed.connect(_on_restore_confirm)
	buttons.add_child(restore_button)
	box.add_child(buttons)


func _on_restore_file_chosen(path: String) -> void:
	var v := _read_vault(path)
	if v.is_empty():
		_show_info(tr("Это не резервная копия"), tr("Файл не похож на копию хранилища:\n%s") % path, "alert", C_WARNING)
		return
	pending_backup = v
	restore_file_label.text = tr("Файл: ") + path
	restore_pw_input.text = ""
	_set_secret(restore_pw_input, true)
	restore_error.text = ""
	_open_modal(restore_modal)
	_focus_later(restore_pw_input)


func _on_restore_confirm() -> void:
	if busy or pending_backup.is_empty():
		return
	if restore_pw_input.text.is_empty():
		restore_error.text = tr("Введите пароль.")
		return
	busy = true
	restore_button.disabled = true
	restore_button.text = tr("Проверяю…")
	restore_error.text = ""
	await get_tree().process_frame
	await get_tree().process_frame

	# Ключи копии считаем ОТДЕЛЬНО — текущие ключи хранилища не трогаем.
	var k := _keys_for(restore_pw_input.text, pending_backup["salt"], pending_backup["iterations"])
	var data = _decrypt(pending_backup, k[0], k[1])

	busy = false
	restore_button.disabled = false
	restore_button.text = tr("Восстановить")
	last_activity_ms = Time.get_ticks_msec()
	if data == null:
		restore_error.text = tr("Пароль не подходит к этой копии.")
		restore_pw_input.select_all()
		restore_pw_input.grab_focus()
		return
	pending_backup = {}
	var r := _merge_entries(data)
	if r.x > 0:
		_save()
	_refresh_list()
	_queue_missing_icons()
	_close_modal()
	_show_info(tr("Готово"), tr("Добавлено записей: %d\nУже были в хранилище: %d") % [r.x, r.y], "check", C_SUCCESS)


# --- Импорт CSV из браузера ---
func _import_csv(path: String) -> void:
	var parsed = _parse_csv(path)
	if parsed is String:
		_show_info(tr("Не удалось импортировать"), parsed, "alert", C_WARNING)
		return
	var items: Array = parsed["items"]
	var r := _merge_entries(items)
	if r.x > 0:
		_save()
	_refresh_list()
	_queue_missing_icons()
	var text := tr("Добавлено записей: %d\nУже были в хранилище: %d") % [r.x, r.y]
	if parsed["skipped"] > 0:
		text += tr("\nПропущено строк без пароля: %d") % parsed["skipped"]
	text += tr("\n\nВажно: файл «%s» хранит все пароли открытым текстом — их увидит любой, кто его откроет. Удалите его, если он больше не нужен.") % path.get_file()
	_show_info(tr("Импорт завершён"), text, "check", C_SUCCESS, tr("Удалить CSV-файл"), func():
		if DirAccess.remove_absolute(path) == OK:
			_toast(tr("CSV-файл удалён"))
		else:
			_toast(tr("Не удалось удалить файл — удалите его вручную"), false)
	)


# Разобрать CSV. Вернёт {"items": [...], "skipped": N} или строку с ошибкой.
func _parse_csv(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return tr("Не удалось открыть файл:\n") + path
	# get_csv_line() сам понимает кавычки, запятые и переносы строк внутри полей.
	var header := file.get_csv_line()
	var col := {}   # "url" -> номер колонки
	for i in header.size():
		# \uFEFF — невидимая метка BOM, которую Windows любит ставить в начало файла
		var h := header[i].replace("\uFEFF", "").strip_edges().to_lower()
		for field in CSV_COLUMNS:
			if not col.has(field) and h in CSV_COLUMNS[field]:
				col[field] = i
	if not col.has("password"):
		file.close()
		return tr("В файле нет колонки с паролями.\n\nПодходят CSV из Chrome, Edge, Яндекс.Браузера, Firefox, Bitwarden и KeePass.")

	var items := []
	var skipped := 0
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() <= 1 and (row.is_empty() or row[0].strip_edges() == ""):
			continue   # пустая строка (обычно последняя)
		var get_cell := func(field: String) -> String:
			if not col.has(field) or col[field] >= row.size():
				return ""
			return row[col[field]].strip_edges()
		var password: String = row[col["password"]] if col["password"] < row.size() else ""
		if password == "":
			skipped += 1
			continue
		items.append({
			"name": get_cell.call("name"),
			"url": get_cell.call("url"),
			"login": get_cell.call("login"),
			"password": password,
			"comment": get_cell.call("comment"),
			"changed": _parse_timestamp(get_cell.call("changed")),
		})
	file.close()
	return {"items": items, "skipped": skipped}


# Добавить записи, пропуская уже существующие (тот же сайт + логин + пароль).
# Возвращает Vector2i(добавлено, пропущено).
func _merge_entries(items: Array) -> Vector2i:
	var known := {}
	for e in entries:
		known[_entry_key(e)] = true
	var added := 0
	var duplicates := 0
	for e in items:
		if not e is Dictionary:
			continue
		var clean := {
			"name": str(e.get("name", "")).strip_edges(),
			"url": str(e.get("url", "")).strip_edges(),
			"login": str(e.get("login", "")).strip_edges(),
			"password": str(e.get("password", "")),
			"comment": str(e.get("comment", "")).strip_edges(),
			"favorite": bool(e.get("favorite", false)),
			"changed": int(e.get("changed", 0)),
		}
		var key := _entry_key(clean)
		if known.has(key):
			duplicates += 1
			continue
		known[key] = true
		entries.append(clean)
		added += 1
	return Vector2i(added, duplicates)


func _entry_key(e: Dictionary) -> String:
	return "%s\n%s\n%s" % [_host_of(str(e.get("url", ""))),
		str(e.get("login", "")).strip_edges().to_lower(), str(e.get("password", ""))]


# --- Окно с результатом ---
func _build_info_modal() -> void:
	info_modal = _create_modal(460)
	var box: VBoxContainer = info_modal.get_meta("box")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	info_tile = _icon_tile("check", Color(C_SUCCESS, 0.15), C_SUCCESS, 48, 22)
	info_tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(info_tile)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 6)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_title = _label("", "ModalTitle")
	texts.add_child(info_title)
	info_text = _label("", "Muted")
	info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(info_text)
	top.add_child(texts)
	box.add_child(top)
	box.add_child(_vspace(4))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	info_close_button = _button(tr("Готово"))
	info_close_button.pressed.connect(_close_modal)
	buttons.add_child(info_close_button)
	info_action_button = _button("", "DangerButton", "trash")
	info_action_button.pressed.connect(func():
		_close_modal()
		if info_action.is_valid():
			info_action.call()
	)
	buttons.add_child(info_action_button)
	box.add_child(buttons)


# Показать сообщение. Если передать action_text и action — появится
# вторая кнопка (например, "Удалить CSV-файл").
func _show_info(title: String, text: String, icon_name: String, color: Color,
		action_text := "", action := Callable()) -> void:
	info_title.text = title
	info_text.text = text
	info_tile.add_theme_stylebox_override("panel", _sb(Color(color, 0.15), 14))
	(info_tile.get_child(0) as TextureRect).texture = _icon(icon_name, color, 22)
	info_action = action
	info_action_button.visible = action_text != ""
	info_action_button.text = action_text
	info_close_button.text = tr("Оставить") if action_text != "" else tr("Готово")
	_close_all_modals()
	_open_modal(info_modal)


# =====================================================================
#  ИЗБРАННОЕ, СОРТИРОВКА, ДАТЫ
# =====================================================================

func _toggle_favorite(i: int) -> void:
	entries[i]["favorite"] = not bool(entries[i].get("favorite", false))
	_save()
	_refresh_list()


# Правило сортировки: true, если запись a должна стоять выше записи b.
# sort_custom() вызывает эту функцию много раз, сравнивая пары записей.
func _entry_before(a: int, b: int) -> bool:
	var ea: Dictionary = entries[a]
	var eb: Dictionary = entries[b]
	# В режиме "одинаковые пароли" ставим записи с одним паролем рядом
	if dup_filter:
		var pa := str(ea.get("password", ""))
		var pb := str(eb.get("password", ""))
		if pa != pb:
			return pa < pb
	# Избранное — всегда выше остального
	var fa := bool(ea.get("favorite", false))
	var fb := bool(eb.get("favorite", false))
	if fa != fb:
		return fa
	match sort_mode:
		"name":
			var na := _display_name(ea)
			var nb := _display_name(eb)
			if na.to_lower() != nb.to_lower():
				# naturalnocasecmp_to: "site2" раньше "site10", регистр не важен
				return na.naturalnocasecmp_to(nb) < 0
		"old", "new":
			var ca := int(ea.get("changed", 0))
			var cb := int(eb.get("changed", 0))
			if ca != cb:
				return ca < cb if sort_mode == "old" else ca > cb
	return a < b   # при равенстве — в порядке добавления


# Что показывать как название: своё название -> адрес сайта -> логин
func _display_name(e: Dictionary) -> String:
	var entry_name := str(e.get("name", "")).strip_edges()
	if entry_name != "":
		return entry_name
	var host := _host_of(str(e.get("url", "")))
	return host if host != "" else str(e.get("login", ""))


func _days_since(timestamp: int) -> int:
	return int((Time.get_unix_time_from_system() - timestamp) / 86400.0)


# "изменён 3 месяца назад"
func _changed_text(timestamp: int) -> String:
	if timestamp <= 0:
		return tr("дата неизвестна")
	var days := _days_since(timestamp)
	if days < 1:
		return tr("изменён сегодня")
	if days == 1:
		return tr("изменён вчера")
	if days < 30:
		return tr("изменён %d %s назад") % [days, _plural(days, tr("день"), tr("дня"), tr("дней"))]
	if days < 365:
		var months := int(days / 30.0)
		return tr("изменён %d %s назад") % [months, _plural(months, tr("месяц"), tr("месяца"), tr("месяцев"))]
	var years := int(days / 365.0)
	return tr("изменён %d %s назад") % [years, _plural(years, tr("год"), tr("года"), tr("лет"))]


# Русские окончания: 1 день, 2 дня, 5 дней, 11 дней, 21 день
# В английском всего две формы: 1 entry, 2 entries — "few" не нужна.
func _plural(n: int, one: String, few: String, many: String) -> String:
	if TranslationServer.get_locale().begins_with("en"):
		return one if n == 1 else many
	if n % 10 == 1 and n % 100 != 11:
		return one
	if n % 10 in [2, 3, 4] and not (n % 100 in [12, 13, 14]):
		return few
	return many


# Число из CSV -> секунды. Firefox пишет миллисекунды (13 цифр).
func _parse_timestamp(text: String) -> int:
	if not text.is_valid_int():
		return 0
	var value := text.to_int()
	return int(value / 1000.0) if value > 100000000000 else value


# =====================================================================
#  ЛОГОТИПЫ САЙТОВ
#  Скачиваются один раз через сервис icon_url_template и хранятся в
#  icons.dat — зашифрованными тем же ключом, что и пароли. Открытые
#  картинки на диске выдали бы, на каких сайтах у тебя аккаунты.
# =====================================================================

func _set_icons_enabled(on: bool) -> void:
	icons_enabled = on
	_save_settings()
	menu.set_item_checked(menu.get_item_index(5), on)
	if on:
		_queue_missing_icons()
		_show_info(tr("Логотипы сайтов"), tr("Логотипы загружаются через сервис Google: он узнает адреса сайтов из списка, но не логины и не пароли. Каждый логотип скачивается один раз и хранится зашифрованным."), "globe", C_ACCENT)
	else:
		icon_queue.clear()
		icon_pending.clear()
	_refresh_list()


func _icon_texture(host: String) -> Texture2D:
	if not icons_enabled or host == "":
		return null
	if icon_textures.has(host):
		return icon_textures[host]
	var item: Dictionary = icon_cache.get(host, {})
	var png: String = item.get("png", "")
	if png == "":
		return null
	var img := Image.new()
	if img.load_png_from_buffer(Marshalls.base64_to_raw(png)) != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()   # плавное уменьшение до размера квадратика
	var tex := ImageTexture.create_from_image(img)
	icon_textures[host] = tex
	return tex


func _load_icons() -> void:
	icon_cache = {}
	icon_textures.clear()
	var v := _read_vault(ICONS_PATH)
	if v.is_empty():
		return
	# Кэш зашифрован ключом хранилища. Не подошёл (например, сменили пароль
	# в другой копии программы) — ничего страшного, скачаем заново.
	var plain = _decrypt_bytes(v, enc_key, mac_key)
	if plain == null:
		return
	var parsed = JSON.parse_string((plain as PackedByteArray).get_string_from_utf8())
	if parsed is Dictionary:
		icon_cache = parsed


func _save_icons() -> void:
	if enc_key.is_empty():
		return
	var file := FileAccess.open(ICONS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(_seal(JSON.stringify(icon_cache).to_utf8_buffer()))
	file.close()
	icons_changed = false


# Поставить в очередь сайты, для которых логотипа ещё нет.
func _queue_missing_icons() -> void:
	if not icons_enabled or enc_key.is_empty():
		return
	var now := int(Time.get_unix_time_from_system())
	for e in entries:
		var host := _host_of(str(e.get("url", "")))
		if not host.contains(".") or icon_pending.has(host):
			continue
		var item: Dictionary = icon_cache.get(host, {})
		if not item.is_empty():
			if item.get("png", "") != "":
				continue   # уже есть
			if now - int(item.get("t", 0)) < ICON_RETRY_DAYS * 86400:
				continue   # недавно не нашли — не мучаем сервис
		icon_pending[host] = true
		icon_queue.append(host)
	_pump_icons()


# Запустить загрузки, но не больше ICON_PARALLEL одновременно.
func _pump_icons() -> void:
	while icon_active < ICON_PARALLEL and not icon_queue.is_empty():
		var host: String = icon_queue.pop_front()
		var req := HTTPRequest.new()
		req.timeout = 15
		add_child(req)
		# bind() добавляет к аргументам сигнала ещё наши: сам запрос и сайт
		req.request_completed.connect(_on_icon_downloaded.bind(req, host))
		if req.request(icon_url_template % host.uri_encode()) != OK:
			req.queue_free()
			icon_pending.erase(host)
			continue
		icon_active += 1


func _on_icon_downloaded(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray, req: HTTPRequest, host: String) -> void:
	req.queue_free()
	icon_active -= 1
	icon_pending.erase(host)
	if enc_key.is_empty() or not icons_enabled:
		return   # пока качали, хранилище заблокировали или логотипы выключили
	var png := ""
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var img := Image.new()
		# Сервис обычно отдаёт PNG, но на всякий случай пробуем и другие форматы
		var ok := img.load_png_from_buffer(body) == OK
		if not ok:
			ok = img.load_jpg_from_buffer(body) == OK or img.load_webp_from_buffer(body) == OK
		if ok and img.get_width() >= 8:
			png = Marshalls.raw_to_base64(img.save_png_to_buffer())
	if png == "" and result != HTTPRequest.RESULT_SUCCESS:
		# Нет интернета или сервис недоступен — не запоминаем неудачу, попробуем позже
		pass
	else:
		icon_cache[host] = {"png": png, "t": int(Time.get_unix_time_from_system())}
		icons_changed = true
		icon_textures.erase(host)
		for p in avatar_slots.get(host, []):
			if is_instance_valid(p):
				_fill_avatar(p, host)
	if icon_active == 0 and icon_queue.is_empty():
		if icons_changed:
			_save_icons()
	else:
		_pump_icons()


func _stop_icons() -> void:
	icon_queue.clear()
	icon_pending.clear()
	for child in get_children():
		if child is HTTPRequest:
			child.cancel_request()
			child.queue_free()
	icon_active = 0
	icon_cache = {}
	icon_textures.clear()
	avatar_slots.clear()


# =====================================================================
#  ПАРОЛИ: генератор и оценка надёжности
# =====================================================================

func _generate_password() -> String:
	# Собираем набор символов по настройкам
	var groups := [CHARS_LOWER]
	if gen_upper:
		groups.append(CHARS_UPPER)
	if gen_digits:
		groups.append(CHARS_DIGITS)
	if gen_symbols:
		groups.append(CHARS_SYMBOLS)
	var chars := "".join(groups)
	# Генерируем, пока в пароль не попадёт хотя бы по одному символу из
	# каждой выбранной группы (обычно с первой попытки).
	while true:
		var result := _random_string(chars, gen_length)
		var ok := true
		for g in groups:
			if not _contains_any(result, g):
				ok = false
				break
		if ok:
			return result
	return ""


func _random_string(chars: String, length: int) -> String:
	# Crypto даёт по-настоящему случайные байты (randi() для паролей не годится).
	var crypto := Crypto.new()
	var n := chars.length()
	var limit := 256 - 256 % n   # отбрасываем "лишние" байты, чтобы все символы были равновероятны
	var result := ""
	while result.length() < length:
		for b in crypto.generate_random_bytes(32):
			if b < limit and result.length() < length:
				result += chars[b % n]
	return result


func _contains_any(text: String, chars: String) -> bool:
	for ch in text:
		if chars.contains(ch):
			return true
	return false


# Оценка от 0 (пусто) до 4 (надёжный)
func _password_score(pw: String) -> int:
	if pw.is_empty():
		return 0
	var lower := false
	var upper := false
	var digit := false
	var symbol := false
	for ch in pw:
		if ch.is_valid_int():
			digit = true
		elif ch != ch.to_upper():
			lower = true
		elif ch != ch.to_lower():
			upper = true
		else:
			symbol = true
	var kinds := int(lower) + int(upper) + int(digit) + int(symbol)
	var score := 0
	if pw.length() >= 8:
		score += 1
	if pw.length() >= 12:
		score += 1
	if kinds >= 3:
		score += 1
	if kinds == 4 or pw.length() >= 16:
		score += 1
	return clampi(score, 1, 4)


# Индикатор надёжности (4 полоски + подпись), привязанный к полю пароля.
# Можно повесить на любое поле — он сам обновляется при вводе.
func _strength_meter(input: LineEdit) -> HBoxContainer:
	var meter := HBoxContainer.new()
	meter.add_theme_constant_override("separation", 6)
	var bars := []
	for k in 4:
		var bar := Panel.new()
		bar.custom_minimum_size = Vector2(0, 4)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sb := _sb(C_SURFACE_3, 2)
		bar.add_theme_stylebox_override("panel", sb)
		bars.append(sb)
		meter.add_child(bar)
	var label := _label("", "Small")
	label.custom_minimum_size = Vector2(76, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meter.add_child(label)
	# Запоминаем полоски и подпись прямо в поле — как кнопку-глаз.
	input.set_meta("meter", {"bars": bars, "label": label})
	input.text_changed.connect(func(_t): _update_strength(input))
	return meter


func _update_strength(input: LineEdit) -> void:
	var meter: Dictionary = input.get_meta("meter")
	var label: Label = meter["label"]
	var score := _password_score(input.text)
	var colors := [C_DANGER, C_WARNING, C_GOOD, C_SUCCESS]
	var names := [tr("Слабый"), tr("Средний"), tr("Хороший"), tr("Надёжный")]
	for k in 4:
		var sb: StyleBoxFlat = meter["bars"][k]
		sb.bg_color = colors[score - 1] if k < score else C_SURFACE_3
	if score == 0:
		label.text = ""
	else:
		label.text = names[score - 1]
		label.add_theme_color_override("font_color", colors[score - 1])


# =====================================================================
#  ВСПЛЫВАЮЩЕЕ УВЕДОМЛЕНИЕ ("тост")
# =====================================================================

func _build_toast() -> void:
	# Контейнеры на весь экран не должны перехватывать мышь — MOUSE_FILTER_IGNORE
	var holder := MarginContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_constant_override("margin_bottom", 28)
	add_child(holder)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_END
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(v)

	toast = PanelContainer.new()
	toast.theme_type_variation = "Toast"
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toast.visible = false
	v.add_child(toast)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_child(h)
	toast_icon = TextureRect.new()
	toast_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	h.add_child(toast_icon)
	toast_label = Label.new()
	h.add_child(toast_label)


func _toast(text: String, ok := true) -> void:
	toast_label.text = text
	toast_icon.texture = _icon("check", C_SUCCESS) if ok else _icon("alert", C_WARNING)
	if toast_tween:
		toast_tween.kill()
	toast.visible = true
	toast.modulate.a = 0.0
	toast_tween = create_tween()
	toast_tween.tween_property(toast, "modulate:a", 1.0, 0.15)
	toast_tween.tween_interval(2.2)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.3)
	toast_tween.tween_callback(toast.hide)


# =====================================================================
#  КЛАВИАТУРА И ЗАКРЫТИЕ ПРОГРАММЫ
# =====================================================================

# _input получает нажатия раньше, чем поля ввода — поэтому Esc
# закрывает окно, даже если курсор стоит в поле.
# =====================================================================
#  ЗАЩИТА ОТ ДВОЙНОГО ЗАПУСКА
# =====================================================================

# Возвращает true, если мы — единственная копия и можно работать.
func _claim_single_instance() -> bool:
	instance_server = TCPServer.new()
	# Слушаем только 127.0.0.1 — это "этот компьютер", снаружи к порту не подключиться.
	if instance_server.listen(INSTANCE_PORT, "127.0.0.1") == OK:
		return true   # место свободно — мы первые
	instance_server = null
	# Место занято. Если там наша программа — она ответит на "пароль".
	if _ask_running_instance_to_show():
		return false
	# Ответа нет — порт занят чужой программой. Работаем без защиты.
	push_warning(tr("Порт %d занят другой программой — защита от двойного запуска отключена") % INSTANCE_PORT)
	return true


# Вторая копия: подключиться к первой и попросить её показать окно.
func _ask_running_instance_to_show() -> bool:
	var peer := StreamPeerTCP.new()
	if peer.connect_to_host("127.0.0.1", INSTANCE_PORT) != OK:
		return false
	var deadline := Time.get_ticks_msec() + 1500
	var sent := false
	var reply := ""
	while Time.get_ticks_msec() < deadline:
		peer.poll()
		var status := peer.get_status()
		if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			return false
		if status == StreamPeerTCP.STATUS_CONNECTED:
			if not sent:
				peer.put_data(INSTANCE_HELLO.to_utf8_buffer())
				sent = true
			var available := peer.get_available_bytes()
			if available > 0:
				reply += (peer.get_partial_data(available)[1] as PackedByteArray).get_string_from_utf8()
				if reply.begins_with(INSTANCE_REPLY):
					peer.disconnect_from_host()
					return true
				if reply.length() >= INSTANCE_REPLY.length():
					break   # ответили что-то не то — это чужая программа
		OS.delay_msec(20)
	peer.disconnect_from_host()
	return false


# Первая копия: каждый кадр проверяем, не стучится ли вторая.
func _process(_delta: float) -> void:
	if instance_server == null:
		return
	while instance_server.is_connection_available():
		instance_clients.append([instance_server.take_connection(), Time.get_ticks_msec()])
	for client in instance_clients.duplicate():
		var peer: StreamPeerTCP = client[0]
		peer.poll()
		var timed_out: bool = Time.get_ticks_msec() - client[1] > 2000
		if peer.get_available_bytes() >= INSTANCE_HELLO.length():
			var msg := (peer.get_partial_data(peer.get_available_bytes())[1] as PackedByteArray).get_string_from_utf8()
			if msg.begins_with(INSTANCE_HELLO):
				peer.put_data(INSTANCE_REPLY.to_utf8_buffer())
				_bring_to_front()
			peer.disconnect_from_host()
			instance_clients.erase(client)
		elif timed_out or peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			peer.disconnect_from_host()
			instance_clients.erase(client)


func _bring_to_front() -> void:
	var win := get_window()
	if win.mode == Window.MODE_MINIMIZED:
		win.mode = Window.MODE_WINDOWED
	win.move_to_foreground()
	win.grab_focus()
	_toast(tr("Программа уже открыта — вот она"))


func _input(event: InputEvent) -> void:
	# Любое нажатие клавиши, клик или движение мыши — это "активность".
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		last_activity_ms = Time.get_ticks_msec()

	# Ctrl + плюс / минус / 0 — масштаб (работает везде, даже на экране входа)
	var zk := event as InputEventKey
	if zk and zk.pressed and zk.ctrl_pressed:
		var zoom_step := 0.0
		var handled := true
		match zk.keycode:
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				zoom_step = 0.1
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_step = -0.1
			KEY_0, KEY_KP_0:
				zoom_step = 0.0
			_:
				handled = false
		if handled:
			_change_zoom(zoom_step)
			get_viewport().set_input_as_handled()
			return

	if current_modal != null:
		if event.is_action_pressed("ui_cancel"):
			_request_close()
			get_viewport().set_input_as_handled()
		elif current_modal == delete_modal and event.is_action_pressed("ui_accept"):
			_on_delete_confirmed()
			get_viewport().set_input_as_handled()
		return

	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not key.ctrl_pressed or not main_screen.visible:
		return
	match key.keycode:
		KEY_N:
			_open_edit(-1)
		KEY_F:
			search_input.grab_focus()
		KEY_L:
			_lock()
		_:
			return
	get_viewport().set_input_as_handled()


# Вызывается раз в секунду
func _on_tick() -> void:
	# Окно могли перетащить на другой монитор с другим масштабом
	_apply_ui_scale()
	# В Windows переключили тему, а у нас "как в системе" — подстраиваемся
	# (но не посреди редактирования: перестройка закрыла бы окна).
	if theme_mode == "system" and _wanted_theme() != current_theme and modal_stack.is_empty() and not busy:
		_rebuild_ui()
	if not main_screen.visible:
		return   # хранилище и так закрыто
	var now := Time.get_ticks_msec()

	# 1. Автоблокировка (не во время выбора файла — там мышь "не видна" программе)
	if file_dialog_open:
		last_activity_ms = now
	if now - last_activity_ms >= AUTO_LOCK_SEC * 1000:
		_lock()
		_toast(tr("Хранилище заблокировано из-за бездействия (%d мин)") % int(AUTO_LOCK_SEC / 60.0))
		return

	# 2. Прячем пароли, у которых вышло время.
	# keys() делает копию списка ключей — так можно удалять из словаря прямо в цикле.
	for i in revealed.keys():
		if now >= revealed[i]:
			revealed.erase(i)
			if row_updaters.has(i):
				row_updaters[i].call()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_clear_clipboard_if_ours()


# =====================================================================
#  ШИФРОВАНИЕ И СОХРАНЕНИЕ
#
#  Как это работает:
#  1. Мастер-пароль + соль прогоняются через PBKDF2 300 000 раз.
#     Получается 32-байтный "главный ключ". Это медленно специально:
#     перебирать пароли взломщику придётся так же медленно.
#  2. Из главного ключа делаем два ключа: для шифрования и для проверки.
#  3. Записи (JSON) шифруются AES-256, а к файлу добавляется "подпись"
#     HMAC. Неверный пароль даст другую подпись — так мы его и узнаём.
#     Испорченный или подменённый файл тоже не пройдёт проверку.
#
#  Устройство файла vault.dat (по байтам):
#    "PKV2"(4) | повторы(4) | соль(16) | IV(16) | подпись(32) | шифр(...)
# =====================================================================

const HASH := HashingContext.HASH_SHA256
const HEADER_SIZE := 4 + 4 + 16 + 16   # всё до подписи


# PBKDF2-HMAC-SHA256 — стандартный способ превратить пароль в ключ.
# Каждый повтор: u = HMAC(пароль, u), а результат — XOR всех u.
func _pbkdf2(password: PackedByteArray, salt_bytes: PackedByteArray, rounds: int) -> PackedByteArray:
	var crypto := Crypto.new()
	var block := salt_bytes.duplicate()
	block.append_array(PackedByteArray([0, 0, 0, 1]))   # номер блока = 1
	var u := crypto.hmac_digest(HASH, password, block)
	# 32 байта храним как 4 больших числа по 8 байт — так XOR быстрее,
	# чем по одному байту.
	var t0 := u.decode_u64(0)
	var t1 := u.decode_u64(8)
	var t2 := u.decode_u64(16)
	var t3 := u.decode_u64(24)
	for r in rounds - 1:
		u = crypto.hmac_digest(HASH, password, u)
		t0 ^= u.decode_u64(0)
		t1 ^= u.decode_u64(8)
		t2 ^= u.decode_u64(16)
		t3 ^= u.decode_u64(24)
	var result := PackedByteArray()
	result.resize(32)
	result.encode_u64(0, t0)
	result.encode_u64(8, t1)
	result.encode_u64(16, t2)
	result.encode_u64(24, t3)
	return result


# Посчитать пару ключей [шифрование, проверка] для любого пароля и соли.
func _keys_for(password: String, salt_bytes: PackedByteArray, rounds: int) -> Array:
	var crypto := Crypto.new()
	var master := _pbkdf2(password.to_utf8_buffer(), salt_bytes, rounds)
	return [
		crypto.hmac_digest(HASH, master, "encrypt".to_utf8_buffer()),
		crypto.hmac_digest(HASH, master, "verify".to_utf8_buffer()),
	]


# Посчитать ключи текущего хранилища
func _derive_keys(password: String) -> void:
	var k := _keys_for(password, salt, iterations)
	enc_key = k[0]
	mac_key = k[1]


# Первый запуск: новая соль, новые ключи, пустое хранилище
func _create_vault(password: String) -> bool:
	salt = Crypto.new().generate_random_bytes(16)
	iterations = KDF_ITERATIONS
	_derive_keys(password)
	entries = []
	return _save()


# Открыть существующее хранилище. Возвращает false при неверном пароле.
#
# Файлов может быть до трёх, и мы выбираем самый свежий целый:
#   vault.tmp — новое сохранение, если программу прервали посреди замены;
#   vault.dat — основной файл;
#   vault.bak — предыдущая версия.
# "Целый" = подпись HMAC сошлась, то есть файл не обрезан и не испорчен.
func _unlock(password: String) -> bool:
	var candidates := []
	for path in [TEMP_PATH, VAULT_PATH, BACKUP_PATH]:
		var v := _read_vault(path)
		if not v.is_empty():
			v["path"] = path
			candidates.append(v)
	if candidates.is_empty():
		return _migrate_legacy(password)

	# Обычно у всех файлов одна соль, и ключ считается один раз (это медленно).
	# Но если смену пароля прервали, соли могут различаться — тогда считаем
	# ключ для каждой соли отдельно и запоминаем, чтобы не считать дважды.
	var keys_by_salt := {}
	var chosen := {}
	var main_ok := false
	for v in candidates:
		var id: String = (v["salt"] as PackedByteArray).hex_encode() + ":" + str(v["iterations"])
		if not keys_by_salt.has(id):
			if not chosen.is_empty():
				continue   # нужный файл уже найден — лишний медленный расчёт не нужен
			salt = v["salt"]
			iterations = v["iterations"]
			_derive_keys(password)
			keys_by_salt[id] = [enc_key, mac_key, salt, iterations]
		var k: Array = keys_by_salt[id]
		enc_key = k[0]
		mac_key = k[1]
		var data = _decrypt(v, enc_key, mac_key)
		if data == null:
			continue
		if v["path"] == VAULT_PATH:
			main_ok = true
		if chosen.is_empty():
			chosen = v   # первый целый в списке — самый свежий
			chosen["data"] = data
			chosen["keys"] = k

	if chosen.is_empty():
		enc_key = PackedByteArray()
		mac_key = PackedByteArray()
		return false

	var ck: Array = chosen["keys"]
	enc_key = ck[0]
	mac_key = ck[1]
	salt = ck[2]
	iterations = ck[3]
	entries = chosen["data"]
	if chosen["path"] == VAULT_PATH:
		# Всё в порядке. Недописанный временный файл, если он есть, не нужен.
		if FileAccess.file_exists(TEMP_PATH):
			DirAccess.remove_absolute(TEMP_PATH)
		return true

	# Восстановление. Испорченный основной файл удаляем, иначе _save()
	# сделал бы его "резервной копией" и затёр бы хорошую.
	if not main_ok and FileAccess.file_exists(VAULT_PATH):
		DirAccess.remove_absolute(VAULT_PATH)
	# Сохраняем дважды, чтобы и резервная копия гарантированно была
	# с текущим паролем и текущими записями.
	_save()
	_save()
	if chosen["path"] == TEMP_PATH:
		notice = tr("Прошлое сохранение было прервано — изменения восстановлены")
	else:
		notice = tr("Основной файл был повреждён — записи восстановлены из копии")
	return true


# Старый формат (passwords.dat): открываем по-старому и сразу
# пересохраняем в новом, а старый файл удаляем.
func _migrate_legacy(password: String) -> bool:
	var file := FileAccess.open_encrypted_with_pass(LEGACY_PATH, FileAccess.READ, password)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	salt = Crypto.new().generate_random_bytes(16)
	iterations = KDF_ITERATIONS
	_derive_keys(password)
	entries = parsed if parsed is Array else []
	if _save():
		DirAccess.remove_absolute(LEGACY_PATH)
		notice = tr("Защита хранилища усилена — файл переведён в новый формат")
	return true


# Прочитать файл и разобрать его на части. Пустой словарь = файла нет или он чужой.
func _read_vault(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < HEADER_SIZE + 32 + 16 or bytes.slice(0, 4).get_string_from_ascii() != MAGIC:
		return {}
	return {
		"header": bytes.slice(0, HEADER_SIZE),
		"iterations": bytes.decode_u32(4),
		"salt": bytes.slice(8, 24),
		"iv": bytes.slice(24, 40),
		"mac": bytes.slice(40, 72),
		"cipher": bytes.slice(72),
	}


# Зашифровать любые байты в наш формат (тот же, что у vault.dat).
func _seal(data: PackedByteArray) -> PackedByteArray:
	var crypto := Crypto.new()
	var iv := crypto.generate_random_bytes(16)   # новый IV при каждом сохранении
	# AES шифрует блоками по 16 байт, поэтому дополняем данные до кратного 16.
	var plain := data.duplicate()
	var pad := 16 - plain.size() % 16
	for k in pad:
		plain.append(pad)
	var aes := AESContext.new()
	aes.start(AESContext.MODE_CBC_ENCRYPT, enc_key, iv)
	var cipher := aes.update(plain)
	aes.finish()

	var header := MAGIC.to_ascii_buffer()
	var it := PackedByteArray()
	it.resize(4)
	it.encode_u32(0, iterations)
	header.append_array(it)
	header.append_array(salt)
	header.append_array(iv)
	var mac := crypto.hmac_digest(HASH, mac_key, header + cipher)
	return header + mac + cipher


# Расшифровать. Вернёт массив записей или null, если ключ не подошёл.
func _decrypt(vault: Dictionary, e_key: PackedByteArray, m_key: PackedByteArray) -> Variant:
	var plain = _decrypt_bytes(vault, e_key, m_key)
	if plain == null:
		return null
	var parsed = JSON.parse_string((plain as PackedByteArray).get_string_from_utf8())
	return parsed if parsed is Array else null


# Расшифровать в "сырые" байты (null — ключ не подошёл или файл испорчен).
func _decrypt_bytes(vault: Dictionary, e_key: PackedByteArray, m_key: PackedByteArray) -> Variant:
	var cipher: PackedByteArray = vault["cipher"]
	# Сначала проверяем подпись: заголовок + шифр должны дать ту же HMAC.
	var signed: PackedByteArray = vault["header"] + cipher
	if Crypto.new().hmac_digest(HASH, m_key, signed) != vault["mac"]:
		return null
	if cipher.size() % 16 != 0:
		return null
	var aes := AESContext.new()
	aes.start(AESContext.MODE_CBC_DECRYPT, e_key, vault["iv"])
	var plain := aes.update(cipher)
	aes.finish()
	# Убираем "набивку" (PKCS#7): последний байт говорит, сколько байт добавлено.
	var pad := plain[plain.size() - 1]
	if pad < 1 or pad > 16:
		return null
	return plain.slice(0, plain.size() - pad)


func _save() -> bool:
	# Без ключей (хранилище заблокировано) сохранять нечем — и нельзя,
	# иначе на диск попадёт испорченный файл.
	if enc_key.size() != 32 or mac_key.size() != 32:
		push_error(tr("Попытка сохранить заблокированное хранилище"))
		return false
	var out := _seal(JSON.stringify(entries).to_utf8_buffer())

	# Сначала пишем во временный файл. Если в этот момент пропадёт свет,
	# пострадает только он, а старое хранилище останется целым.
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error(tr("Не удалось сохранить файл: %s") % FileAccess.get_open_error())
		_toast(tr("Не удалось сохранить файл!"), false)
		return false
	file.store_buffer(out)
	file.close()

	# Читаем обратно и сравниваем байт в байт. Если диск записал не то
	# (кончилось место, сбой), старый файл не трогаем.
	if FileAccess.get_file_as_bytes(TEMP_PATH) != out:
		DirAccess.remove_absolute(TEMP_PATH)
		push_error(tr("Проверка записанного файла не прошла"))
		_toast(tr("Не удалось сохранить файл!"), false)
		return false

	# Текущий файл становится резервной копией, временный — основным.
	# Если программа прервётся между этими шагами, при следующем входе
	# _unlock() найдёт целый vault.tmp или vault.bak и восстановит записи.
	if FileAccess.file_exists(VAULT_PATH):
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.remove_absolute(BACKUP_PATH)
		var move_err := DirAccess.rename_absolute(VAULT_PATH, BACKUP_PATH)
		if move_err != OK:
			# Новые данные всё равно уже лежат в vault.tmp и не потеряются.
			push_error(tr("Не удалось создать резервную копию: %s") % error_string(move_err))
			_toast(tr("Не удалось сохранить файл!"), false)
			return false
	var err := DirAccess.rename_absolute(TEMP_PATH, VAULT_PATH)
	if err != OK:
		push_error(tr("Не удалось заменить файл хранилища: %s") % error_string(err))
		_toast(tr("Не удалось сохранить файл!"), false)
		return false
	return true
