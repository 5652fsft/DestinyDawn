extends Node

const SETTING_KEY = "menu_background"

var backgrounds: Array[Dictionary] = [
	{"id": "bronya_seele", "name": "布洛妮娅 & 希儿", "filename": "BronyaAndSeele1.ogv"},
	{"id": "elaina",       "name": "伊蕾娜",           "filename": "Elaina1.ogv"},
	{"id": "static",       "name": "静态背景",          "filename": ""},
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
			if OS.has_feature("editor"):
				ProjectSettings.set_setting(SETTING_KEY, id)
				ProjectSettings.save()
			get_tree().call_group("menu_bg", "_on_background_changed", id)
			return

func get_current_bg_filename() -> String:
	for bg in backgrounds:
		if bg.id == current_id:
			return bg.filename
	return ""

func get_current_bg_path() -> String:
	var filename = get_current_bg_filename()
	if filename.is_empty():
		return ""
	if OS.has_feature("editor"):
		return "res://Assets/Video/" + filename
	var exe_dir = OS.get_executable_path().get_base_dir()
	var local = exe_dir + "/" + filename
	if FileAccess.file_exists(local):
		return local
	return "res://Assets/Video/" + filename

func get_current_bg_name() -> String:
	for bg in backgrounds:
		if bg.id == current_id:
			return bg.name
	return ""

func get_available_backgrounds() -> Array[Dictionary]:
	return backgrounds.duplicate()
