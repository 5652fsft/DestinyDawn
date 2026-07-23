extends Control

@onready var guide_text = $GuideText
@onready var back_btn = $BackButton

func _ready():
	ButtonTheme.apply_menu(back_btn)
	ButtonTheme.apply_glass_blue(back_btn)
	ButtonTheme.set_font(back_btn, 20)
	back_btn.pressed.connect(_on_back_pressed)
	_load_guide()
	
	# 初始化单例背景
	BackgroundSingleton.setup(BackgroundManager.get_current_bg_path())

func _load_guide():
	var text = ""
	var file = FileAccess.open("res://README.md", FileAccess.READ)
	if file:
		text = file.get_as_text()
		file.close()
	else:
		text = "游戏指南文件未找到。\n请访问 GitHub 仓库查看最新指南：\nhttps://github.com/5652fsft/DestinyDawn"
	guide_text.text = MarkdownConverter.to_bbcode(text)

func _on_back_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")