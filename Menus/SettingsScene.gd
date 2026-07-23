extends Control

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")

@onready var name_edit = $VBoxContainer/NameEdit
@onready var port_edit = $VBoxContainer/PortEdit
@onready var master_slider = $VBoxContainer/MasterSlider
@onready var bgm_slider = $VBoxContainer/BGMSlider
@onready var sfx_slider = $VBoxContainer/SFXSlider
@onready var save_btn = $VBoxContainer/SaveButton
@onready var back_btn = $VBoxContainer/BackButton
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
		ButtonTheme.set_font(btn, 20)
	for le in [name_edit, port_edit]:
		le.add_theme_font_override("font", FONT)
		le.add_theme_font_size_override("font_size", 18)
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
