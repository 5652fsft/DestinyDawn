extends Control

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")

# 样式常量（统一控件规格）
const CONTROL_HEIGHT := 36
const LABEL_COLOR := Color(0.92, 0.93, 0.95, 1)
const STATUS_COLOR := Color(0.92, 0.93, 0.95, 1)
const GLASS_BG := Color(0.32, 0.4, 0.52, 0.45)
const GLASS_BORDER := Color(0.5, 0.55, 0.65, 0.4)

@onready var name_edit = $BasePanel/VBox/BaseGrid/NameEdit
@onready var port_edit = $BasePanel/VBox/BaseGrid/PortEdit
@onready var master_slider = $BasePanel/VBox/BaseGrid/MasterSlider
@onready var bgm_slider = $BasePanel/VBox/BaseGrid/BGMSlider
@onready var sfx_slider = $BasePanel/VBox/BaseGrid/SFXSlider
@onready var back_btn = $BackButton
@onready var save_btn = $SaveButton
@onready var bg_option = $BasePanel/VBox/BaseGrid/BgOption
@onready var auto_toggle = $UpdatePanel/VBox/UpdateGrid/AutoToggle
@onready var proxy_option = $UpdatePanel/VBox/UpdateGrid/ProxyOption
@onready var proxy_edit = $UpdatePanel/VBox/UpdateGrid/ProxyEdit
@onready var proxy_host_edit = $UpdatePanel/VBox/UpdateGrid/ProxyHostRow/ProxyHostEdit
@onready var proxy_port_edit = $UpdatePanel/VBox/UpdateGrid/ProxyHostRow/ProxyPortEdit
@onready var check_update_btn = $UpdatePanel/VBox/UpdateRow/CheckUpdateButton
@onready var download_btn = $UpdatePanel/VBox/UpdateRow/DownloadButton
@onready var update_status_label = $UpdatePanel/VBox/UpdateRow/UpdateStatusLabel

var _downloaded: bool = false

func _ready():
	GlobalGameData.load_defaults_if_empty()
	name_edit.text = GlobalGameData.player_name
	port_edit.text = str(GlobalGameData.server_port)
	master_slider.value = GlobalGameData.audio_volume_master
	bgm_slider.value = GlobalGameData.audio_volume_bgm
	sfx_slider.value = GlobalGameData.audio_volume_sfx
	auto_toggle.button_pressed = GlobalGameData.auto_update
	_refresh_auto_toggle_text()
	_init_proxy_option()
	update_status_label.text = "当前版本 v" + UpdateManager.VERSION
	UpdateManager.check_state_changed.connect(_on_check_state_changed)
	UpdateManager.download_state_changed.connect(_on_download_state_changed)
	update_status_label.meta_clicked.connect(_on_status_meta_clicked)
	_sync_status_from_manager()

	# 面板透明（无灰色底框，与主菜单风格一致）
	$BasePanel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	$UpdatePanel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	# 按钮（底部主按钮 20 号，栏内按钮 16 号统一）
	for btn in [save_btn, back_btn]:
		ButtonTheme.apply_menu(btn)
		ButtonTheme.apply_glass_blue(btn)
		ButtonTheme.set_font(btn, 20)
	ButtonTheme.apply_menu(check_update_btn)
	ButtonTheme.apply_glass_blue(check_update_btn)
	ButtonTheme.set_font(check_update_btn, 16)
	ButtonTheme.apply_menu(download_btn)
	ButtonTheme.apply_glass_blue(download_btn)
	ButtonTheme.set_font(download_btn, 16)
	ButtonTheme.apply_menu(auto_toggle)
	ButtonTheme.apply_glass_blue(auto_toggle)
	ButtonTheme.set_font(auto_toggle, 16)
	_unify_button_height(check_update_btn)
	_unify_button_height(download_btn)
	_unify_button_height(auto_toggle)
	download_btn.pressed.connect(_on_download_pressed)

	# 输入框统一（高度 36 / 字号 16 / 毛玻璃）
	for le in [name_edit, port_edit, proxy_edit, proxy_host_edit, proxy_port_edit]:
		_style_input(le)

	# 下拉框统一（与输入框同规格 + 浅色弹窗、无夸张悬停）
	_style_option(bg_option)
	_style_option(proxy_option)

	# 滑块样式（淡蓝底 + 白色拖拽头）
	var track = StyleBoxFlat.new()
	track.bg_color = Color(0.25, 0.3, 0.4, 0.5)
	track.corner_radius_top_left = 4
	track.corner_radius_top_right = 4
	track.corner_radius_bottom_left = 4
	track.corner_radius_bottom_right = 4
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(0.6, 0.75, 1.0, 0.6)
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	var thumb = StyleBoxFlat.new()
	thumb.bg_color = Color(0.9, 0.92, 0.95, 1)
	thumb.corner_radius_top_left = 8
	thumb.corner_radius_top_right = 8
	thumb.corner_radius_bottom_left = 8
	thumb.corner_radius_bottom_right = 8
	for s in [master_slider, bgm_slider, sfx_slider]:
		s.add_theme_stylebox_override("slider", track)
		s.add_theme_stylebox_override("grabber_area", fill)
		s.add_theme_stylebox_override("grabber", thumb)
		s.add_theme_stylebox_override("grabber_highlight", thumb)

	save_btn.pressed.connect(_on_save_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	check_update_btn.pressed.connect(_on_check_update_pressed)
	auto_toggle.toggled.connect(_on_auto_toggle_toggled)
	proxy_option.item_selected.connect(_on_proxy_selected)
	master_slider.value_changed.connect(_on_master_volume_changed)
	bgm_slider.value_changed.connect(_on_bgm_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_init_bg_option()
	
	# 初始化单例背景
	BackgroundSingleton.setup(BackgroundManager.get_current_bg_path())

# 输入框统一样式（与下拉框同规格，避免高度参差）
func _style_input(le: LineEdit):
	ButtonTheme.apply_glass_edit(le)
	var sb = le.get_theme_stylebox("normal").duplicate()
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	for state in ["normal", "focus", "read_only"]:
		le.add_theme_stylebox_override(state, sb)
	le.add_theme_font_override("font", FONT)
	le.add_theme_font_size_override("font_size", 16)
	le.add_theme_color_override("font_placeholder_color", Color(0.85, 0.87, 0.92, 0.55))

# 栏内按钮高度与输入框统一（36）
func _unify_button_height(btn: Button):
	var sb = btn.get_theme_stylebox("normal").duplicate()
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, sb)

# 下拉框统一：本体与输入框同规格；弹窗浅蓝灰毛玻璃，悬停仅微亮
func _style_option(option: OptionButton):
	var style = StyleBoxFlat.new()
	style.bg_color = GLASS_BG
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = GLASS_BORDER
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	var hover = style.duplicate()
	hover.bg_color = Color(0.36, 0.44, 0.56, 0.5)
	var pressed = style.duplicate()
	pressed.bg_color = Color(0.4, 0.48, 0.6, 0.55)
	for state in ["normal", "focus", "disabled"]:
		option.add_theme_stylebox_override(state, style)
	option.add_theme_stylebox_override("hover", hover)
	option.add_theme_stylebox_override("pressed", pressed)
	option.add_theme_font_override("font", FONT)
	option.add_theme_font_size_override("font_size", 16)

	var popup = option.get_popup()
	# 弹窗颜色与透明度与选项框本体完全一致
	var popup_bg = StyleBoxFlat.new()
	popup_bg.bg_color = GLASS_BG
	popup_bg.border_width_top = 1
	popup_bg.border_width_bottom = 1
	popup_bg.border_width_left = 1
	popup_bg.border_width_right = 1
	popup_bg.border_color = GLASS_BORDER
	popup_bg.corner_radius_top_left = 8
	popup_bg.corner_radius_top_right = 8
	popup_bg.corner_radius_bottom_left = 8
	popup_bg.corner_radius_bottom_right = 8
	popup.add_theme_stylebox_override("panel", popup_bg)
	var popup_hover = StyleBoxFlat.new()
	popup_hover.bg_color = Color(0.36, 0.44, 0.56, 0.5)
	popup.add_theme_stylebox_override("hover", popup_hover)
	popup.add_theme_font_override("font", FONT)
	popup.add_theme_font_size_override("font_size", 16)
	popup.add_theme_constant_override("h_separation", 4)
	popup.add_theme_constant_override("v_separation", 2)
	# 选中项指示：浅蓝柔边圆点（check/radio 都覆盖，统一图标样式）
	var dot = _make_dot_icon(12, Color(0.62, 0.8, 1, 0.95))
	popup.add_theme_icon_override("check", dot)
	popup.add_theme_icon_override("radio", dot)
	popup.add_theme_constant_override("icon_max_width", 12)

# 柔边圆点图标（径向渐变，中心实色边缘透明）
func _make_dot_icon(size: int, color: Color) -> GradientTexture2D:
	var grad = Gradient.new()
	grad.set_color(0, color)
	grad.set_color(1, Color(color.r, color.g, color.b, 0))
	var tex = GradientTexture2D.new()
	tex.width = size
	tex.height = size
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex

func _refresh_auto_toggle_text():
	auto_toggle.text = "开" if auto_toggle.button_pressed else "关"

func _init_proxy_option():
	proxy_option.add_item("直连 GitHub", 0)
	proxy_option.add_item("镜像 gh-proxy.com", 1)
	proxy_option.add_item("镜像 gh.ddlc.top", 2)
	proxy_option.add_item("镜像 ghfast.top", 3)
	proxy_option.add_item("镜像 gh.zwy.one", 4)
	proxy_option.add_item("镜像 mirror.ghproxy.com", 5)
	proxy_option.add_item("自定义镜像", 6)
	var mode = GlobalGameData.proxy_mode
	var idx = 0
	if mode == "ghproxy": idx = 1
	elif mode == "ghddlc": idx = 2
	elif mode == "ghfast": idx = 3
	elif mode == "zwy": idx = 4
	elif mode == "ghproxy_mirror": idx = 5
	elif mode == "custom": idx = 6
	proxy_option.select(idx)
	proxy_edit.text = GlobalGameData.proxy_prefix
	_update_proxy_edit_state(idx == 6)
	proxy_host_edit.text = GlobalGameData.update_proxy_host
	proxy_port_edit.text = str(GlobalGameData.update_proxy_port) if GlobalGameData.update_proxy_port > 0 else ""

func _update_proxy_edit_state(enabled: bool):
	proxy_edit.editable = enabled
	proxy_edit.modulate = Color(1, 1, 1, 1) if enabled else Color(1, 1, 1, 0.75)
	proxy_edit.placeholder_text = "https://gh-proxy.com/（自定义前缀）" if enabled else "选择「自定义镜像」通道后生效"

func _on_proxy_selected(index: int):
	match index:
		1: GlobalGameData.proxy_mode = "ghproxy"
		2: GlobalGameData.proxy_mode = "ghddlc"
		3: GlobalGameData.proxy_mode = "ghfast"
		4: GlobalGameData.proxy_mode = "zwy"
		5: GlobalGameData.proxy_mode = "ghproxy_mirror"
		6: GlobalGameData.proxy_mode = "custom"
		_: GlobalGameData.proxy_mode = "direct"
	_update_proxy_edit_state(index == 6)

func _on_auto_toggle_toggled(on: bool):
	GlobalGameData.auto_update = on
	_refresh_auto_toggle_text()
	SaveManager.save_all()

func _on_check_update_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	update_status_label.text = "正在检查更新..."
	download_btn.visible = false
	_downloaded = false
	UpdateManager.update_dismissed = false
	UpdateManager.check_for_update()

func _sync_status_from_manager():
	match UpdateManager.current_check_state:
		UpdateManager.CheckState.CHECKING:
			update_status_label.text = "自动检查更新中..."
			download_btn.visible = false
		UpdateManager.CheckState.UP_TO_DATE:
			update_status_label.text = "已是最新版本 v" + UpdateManager.last_check_message
			download_btn.visible = false
		UpdateManager.CheckState.UPDATE_AVAILABLE:
			update_status_label.text = _update_available_text(UpdateManager.last_check_message)
			download_btn.visible = true
			download_btn.text = "前往下载页" if OS.get_name() == "Android" else "下载更新"
			download_btn.disabled = false
		UpdateManager.CheckState.ERROR:
			update_status_label.text = UpdateManager.last_check_message
			download_btn.visible = false
		_:
			update_status_label.text = "当前版本 v" + UpdateManager.VERSION
			download_btn.visible = false

func _on_check_state_changed(state: int, message: String):
	match state:
		UpdateManager.CheckState.CHECKING:
			update_status_label.text = "正在检查更新..."
			download_btn.visible = false
		UpdateManager.CheckState.UP_TO_DATE:
			update_status_label.text = "已是最新版本 v" + message
			download_btn.visible = false
		UpdateManager.CheckState.UPDATE_AVAILABLE:
			update_status_label.text = _update_available_text(message)
			download_btn.visible = true
			download_btn.text = "前往下载页" if OS.get_name() == "Android" else "下载更新"
			download_btn.disabled = false
		UpdateManager.CheckState.ERROR:
			update_status_label.text = message
			download_btn.visible = false
		_:
			pass

func _on_download_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	if OS.get_name() == "Android":
		UpdateManager.open_release_page()
		return
	if _downloaded:
		UpdateManager.install_update()
	else:
		UpdateManager.download_update()

# 发现新版本的状态文本：电脑端附加可点击的网页下载链接（自助兜底）
func _update_available_text(version: String) -> String:
	if OS.get_name() == "Android":
		return "发现新版本 v" + version
	return "发现新版本 v%s　[color=#6EB8FF][url=release]点此跳转下载页[/url][/color]" % version

func _on_status_meta_clicked(meta: Variant):
	if meta == "release":
		UpdateManager.open_release_page()

func _fmt_size(bytes: int) -> String:
	if bytes >= 1024 * 1024 * 1024:
		return "%.1f GB" % (bytes / 1073741824.0)
	if bytes >= 1024 * 1024:
		return "%.1f MB" % (bytes / 1048576.0)
	if bytes >= 1024:
		return "%.1f KB" % (bytes / 1024.0)
	return "%d B" % bytes

func _on_download_state_changed(state: int, progress: int, total: int, message: String):
	match state:
		UpdateManager.DownloadState.DOWNLOADING:
			download_btn.disabled = true
			if total > 0:
				var pct = int(progress * 100.0 / max(total, 1))
				download_btn.text = "下载中 %d%%" % pct
				update_status_label.text = "正在下载 %d%%（%s / %s%s）" % [pct, _fmt_size(progress), _fmt_size(total), ("　" + message) if not message.is_empty() else ""]
			else:
				download_btn.text = "下载中..."
				update_status_label.text = "正在下载..."
		UpdateManager.DownloadState.READY:
			_downloaded = true
			download_btn.disabled = false
			download_btn.text = "安装并重启"
			update_status_label.text = "下载完成，点击「安装并重启」"
		UpdateManager.DownloadState.ERROR:
			download_btn.disabled = false
			download_btn.text = "重试下载"
			update_status_label.text = message
		UpdateManager.DownloadState.INSTALLING:
			download_btn.disabled = true
			download_btn.text = "正在安装..."
			update_status_label.text = "正在替换游戏文件，即将重启..."
		_:
			pass

func _init_bg_option():
	var bgs = BackgroundManager.get_available_backgrounds()
	var idx = 0
	for bg in bgs:
		bg_option.add_item(bg.name, idx)
		if bg.id == BackgroundManager.current_id:
			bg_option.select(idx)
		idx += 1
	bg_option.item_selected.connect(_on_bg_selected)

func _on_bg_selected(index: int):
	var bgs = BackgroundManager.get_available_backgrounds()
	var real_index = 0
	for bg in bgs:
		if real_index == index:
			BackgroundManager.set_background(bg.id)
			return
		real_index += 1

func _on_master_volume_changed(v: float):
	var am = Engine.get_singleton("AudioManager")
	if am: am.set_master_volume(v)

func _on_bgm_volume_changed(v: float):
	var am = Engine.get_singleton("AudioManager")
	if am: am.set_bgm_volume(v)

func _on_sfx_volume_changed(v: float):
	var am = Engine.get_singleton("AudioManager")
	if am: am.set_sfx_volume(v)

func _on_save_pressed():
	GlobalGameData.player_name = name_edit.text
	var port_str = port_edit.text.strip_edges()
	if port_str.is_valid_int():
		var p = port_str.to_int()
		if p > 0 and p <= 65535:
			GlobalGameData.server_port = p
	if GlobalGameData.proxy_mode == "custom":
		GlobalGameData.proxy_prefix = proxy_edit.text.strip_edges()
	var proxy_host = proxy_host_edit.text.strip_edges()
	GlobalGameData.update_proxy_host = proxy_host
	var proxy_port_str = proxy_port_edit.text.strip_edges()
	if proxy_port_str.is_valid_int():
		var pp = proxy_port_str.to_int()
		if pp > 0 and pp <= 65535:
			GlobalGameData.update_proxy_port = pp
	elif proxy_host.is_empty():
		GlobalGameData.update_proxy_port = 0
	SaveManager.save_all()
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")

func _on_back_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
