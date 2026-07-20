extends Control

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")

@onready var name_edit = $VBoxContainer/NameEdit
@onready var ip_edit = $VBoxContainer/IPEdit
@onready var save_btn = $VBoxContainer/SaveButton
@onready var back_btn = $VBoxContainer/BackButton

func _ready():
	GlobalGameData.load_defaults_if_empty()
	name_edit.text = GlobalGameData.player_name
	ip_edit.text = GlobalGameData.server_ip
	for btn in [save_btn, back_btn]:
		ButtonTheme.apply_menu(btn)
		ButtonTheme.set_font(btn, 20)
	for le in [name_edit, ip_edit]:
		le.add_theme_font_override("font", FONT)
		le.add_theme_font_size_override("font_size", 18)
	save_btn.pressed.connect(_on_save_pressed)
	back_btn.pressed.connect(_on_back_pressed)

func _on_save_pressed():
	GlobalGameData.player_name = name_edit.text
	GlobalGameData.server_ip = ip_edit.text
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
