extends Node

var backgrounds: Array[Dictionary] = [
	{"id": "bronya_seele", "name": "布洛妮娅 & 希儿", "filename": "BronyaAndSeele1.ogv"},
	{"id": "elaina",       "name": "伊蕾娜",           "filename": "Elaina1.ogv"},
	{"id": "static",       "name": "静态背景",          "filename": ""},
]

var current_id: String = "elaina"

func _ready():
	# 背景选择由 GlobalGameData + SaveManager 持久化（user://settings.cfg）
	if GlobalGameData.menu_background != "":
		current_id = GlobalGameData.menu_background

func set_background(id: String):
	for bg in backgrounds:
		if bg.id == id:
			current_id = id
			GlobalGameData.menu_background = id
			SaveManager.save_all()
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
