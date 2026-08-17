extends Control

@onready var guide_text = $GuideText
@onready var back_btn = $BackButton

func _ready():
	ButtonTheme.apply_menu(back_btn)
	ButtonTheme.apply_glass_blue(back_btn)
	ButtonTheme.set_font(back_btn, 18)
	back_btn.pressed.connect(_on_back_pressed)
	_load_guide()
	
	# 初始化单例背景
	BackgroundSingleton.setup(BackgroundManager.get_current_bg_path())

func _load_guide():
	var text = _read_readme()
	if text.is_empty():
		text = "游戏指南文件未找到。\n请访问 GitHub 仓库查看最新指南：\nhttps://github.com/5652fsft/DestinyDawn"
	guide_text.text = MarkdownConverter.to_bbcode(text)

# 读取优先级：包内 res:// → 桌面端 exe 同目录 → 空则走 GitHub 兜底
func _read_readme() -> String:
	var file = FileAccess.open("res://README.md", FileAccess.READ)
	if file:
		var text = file.get_as_text()
		file.close()
		return text
	if OS.get_name() in ["Windows", "macOS", "Linux"]:
		var side_path = OS.get_executable_path().get_base_dir().path_join("README.md")
		file = FileAccess.open(side_path, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			file.close()
			return text
	return ""

func _on_back_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")