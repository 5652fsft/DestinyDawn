extends Panel

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")

func _ready():
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.1, 0.92)
	add_theme_stylebox_override("panel", bg)
	ButtonTheme.apply_menu($VBoxContainer/ReturnButton)
	ButtonTheme.set_font($VBoxContainer/ReturnButton, 22)
	hide()

func show_result(is_winner: bool, stats: Dictionary):
	$VBoxContainer/TitleLabel.text = "胜 利" if is_winner else "败 北"
	$VBoxContainer/TitleLabel.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if is_winner else Color(1.0, 0.3, 0.3))
	$VBoxContainer/TitleLabel.add_theme_font_override("font", FONT)
	
	var my_prefix = "host" if GlobalGameData.is_host else "client"
	var en_prefix = "client" if GlobalGameData.is_host else "host"
	
	$VBoxContainer/StatsContainer/MyPanel/MyDamage.text = "造成伤害: %d" % stats[my_prefix + "_damage_dealt"]
	$VBoxContainer/StatsContainer/MyPanel/MyHeal.text = "治疗量: %d" % stats[my_prefix + "_healing_done"]
	$VBoxContainer/StatsContainer/MyPanel/MyCards.text = "使用卡牌: %d" % stats[my_prefix + "_cards_played"]
	$VBoxContainer/StatsContainer/MyPanel/MyKills.text = "击杀: %d" % stats[my_prefix + "_kills"]
	
	$VBoxContainer/StatsContainer/EnemyPanel/EnDamage.text = "造成伤害: %d" % stats[en_prefix + "_damage_dealt"]
	$VBoxContainer/StatsContainer/EnemyPanel/EnHeal.text = "治疗量: %d" % stats[en_prefix + "_healing_done"]
	$VBoxContainer/StatsContainer/EnemyPanel/EnCards.text = "使用卡牌: %d" % stats[en_prefix + "_cards_played"]
	$VBoxContainer/StatsContainer/EnemyPanel/EnKills.text = "击杀: %d" % stats[en_prefix + "_kills"]
	
	for c in $VBoxContainer.get_children():
		_set_font_recursive(c)
	
	show()

func _set_font_recursive(node: Node):
	if node is Label:
		node.add_theme_font_override("font", FONT)
	elif node is Button:
		ButtonTheme.set_font(node, 22)
	for child in node.get_children():
		_set_font_recursive(child)

func _on_return_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	# 退出战斗模式，恢复背景
	BackgroundSingleton.exit_battle()
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
