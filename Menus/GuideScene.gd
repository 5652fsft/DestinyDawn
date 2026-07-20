extends Control

@onready var guide_text = $VBoxContainer/ScrollContainer/GuideText

func _ready():
	ButtonTheme.apply_menu($VBoxContainer/BackButton)
	ButtonTheme.set_font($VBoxContainer/BackButton, 20)
	$VBoxContainer/BackButton.pressed.connect(_on_back_pressed)
	_load_guide()

func _load_guide():
	var text = ""
	var file = FileAccess.open("res://README.md", FileAccess.READ)
	if file:
		text = file.get_as_text()
		file.close()
	else:
		text = "游戏指南文件未找到。\n请访问 GitHub 仓库查看最新指南：\nhttps://github.com/5652fsft/DestinyDawn"
	guide_text.bbcode_enabled = true
	guide_text.text = MarkdownConverter.to_bbcode(text)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
