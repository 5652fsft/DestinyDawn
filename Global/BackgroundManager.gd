extends Node

const SETTING_KEY = "menu_background"

var backgrounds: Array[Dictionary] = [
	{"id": "bronya_seele", "name": "布洛妮娅 & 希儿", "path": "res://Assets/Video/BronyaAndSeele1.mp4"},
	{"id": "elaina",       "name": "伊蕾娜",           "path": "res://Assets/Video/Elaina1.mp4"},
	{"id": "static",       "name": "静态背景",          "path": ""},
]

var current_id: String = "bronya_seele"

func _ready():
	if ProjectSettings.has_setting(SETTING_KEY):
		var saved = ProjectSettings.get_setting(SETTING_KEY)
		if saved and typeof(saved) == TYPE_STRING:
			current_id = saved

func set_background(id: String):
	for bg in backgrounds:
		if bg.id == id:
			current_id = id
			ProjectSettings.set_setting(SETTING_KEY, id)
			ProjectSettings.save()
			get_tree().call_group("menu_bg", "_on_background_changed", id)
			return
	print("[BackgroundManager] unknown id: ", id)

func get_current_bg_path() -> String:
	for bg in backgrounds:
		if bg.id == current_id:
			return bg.path
	return ""

func get_current_bg_name() -> String:
	for bg in backgrounds:
		if bg.id == current_id:
			return bg.name
	return ""

func get_available_backgrounds() -> Array[Dictionary]:
	return backgrounds.duplicate()
