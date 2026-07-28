extends Control

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")

@onready var name_edit = $VBoxContainer/NameEdit
@onready var port_edit = $VBoxContainer/PortEdit
@onready var master_slider = $VBoxContainer/MasterSlider
@onready var bgm_slider = $VBoxContainer/BGMSlider
@onready var sfx_slider = $VBoxContainer/SFXSlider
@onready var back_btn = $BackButton
@onready var save_btn = $SaveButton
@onready var bg_option = $VBoxContainer/BgOption

func _ready():
	GlobalGameData.load_defaults_if_empty()
	name_edit.text = GlobalGameData.player_name
	port_edit.text = str(GlobalGameData.server_port)
	master_slider.value = GlobalGameData.audio_volume_master
	bgm_slider.value = GlobalGameData.audio_volume_bgm
	sfx_slider.value = GlobalGameData.audio_volume_sfx
	for btn in [save_btn, back_btn]:
		ButtonTheme.apply_menu(btn)
		ButtonTheme.apply_glass_blue(btn)
		ButtonTheme.set_font(btn, 20)

	# 下拉框样式（加左边距 + 弹出菜单美化）
	ButtonTheme.apply_menu(bg_option)
	ButtonTheme.apply_glass_blue(bg_option)
	ButtonTheme.set_font(bg_option, 20)
	var opt_style = bg_option.get_theme_stylebox("normal").duplicate()
	opt_style.content_margin_left = 10
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		bg_option.add_theme_stylebox_override(state, opt_style)
	var popup = bg_option.get_popup()
	var popup_bg = StyleBoxFlat.new()
	popup_bg.bg_color = Color(0.18, 0.18, 0.22, 0.95)
	popup_bg.border_width_top = 1
	popup_bg.border_width_bottom = 1
	popup_bg.border_width_left = 1
	popup_bg.border_width_right = 1
	popup_bg.border_color = Color(0.4, 0.4, 0.45, 0.5)
	popup_bg.corner_radius_top_left = 8
	popup_bg.corner_radius_top_right = 8
	popup_bg.corner_radius_bottom_left = 8
	popup_bg.corner_radius_bottom_right = 8
	popup.add_theme_stylebox_override("panel", popup_bg)
	popup.add_theme_font_override("font", FONT)
	popup.add_theme_font_size_override("font_size", 16)
	var hover_popup = StyleBoxFlat.new()
	hover_popup.bg_color = Color(0.32, 0.4, 0.52, 0.6)
	popup.add_theme_stylebox_override("hover", hover_popup)
	popup.add_theme_constant_override("h_separation", 4)
	popup.add_theme_constant_override("v_separation", 2)
	for le in [name_edit, port_edit]:
		ButtonTheme.apply_glass_edit(le)
		le.add_theme_font_override("font", FONT)
		le.add_theme_font_size_override("font_size", 18)

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
	master_slider.value_changed.connect(_on_master_volume_changed)
	bgm_slider.value_changed.connect(_on_bgm_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_init_bg_option()
	
	# 初始化单例背景
	BackgroundSingleton.setup(BackgroundManager.get_current_bg_path())

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
	if index >= 0 and index < bgs.size():
		BackgroundManager.set_background(bgs[index].id)

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
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")

func _on_back_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
