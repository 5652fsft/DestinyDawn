extends Control

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")

@onready var name_edit = $VBoxContainer/NameEdit
@onready var ip_edit = $VBoxContainer/IPEdit

func _ready():
	GlobalGameData.load_defaults_if_empty()
	name_edit.text = GlobalGameData.player_name
	ip_edit.text = GlobalGameData.server_ip
	for btn in [$VBoxContainer/SaveButton, $VBoxContainer/BackButton]:
		ButtonTheme.apply_menu(btn)
		ButtonTheme.set_font(btn, 20)
	for le in [name_edit, ip_edit]:
		le.add_theme_font_override("font", FONT)
		le.add_theme_font_size_override("font_size", 18)

func _on_save_pressed():
	GlobalGameData.player_name = name_edit.text
	GlobalGameData.server_ip = ip_edit.text
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
