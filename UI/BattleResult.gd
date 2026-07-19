extends Panel

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")

func _ready():
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.1, 0.92)
	add_theme_stylebox_override("panel", bg)
	_setup_return_button()
	hide()

func _setup_return_button():
	var btn = $VBoxContainer/ReturnButton
	btn.mouse_entered.connect(_on_btn_enter.bind(btn))
	btn.mouse_exited.connect(_on_btn_exit.bind(btn))
	btn.button_down.connect(_on_btn_down.bind(btn))
	btn.button_up.connect(_on_btn_up.bind(btn))

func _on_btn_enter(btn):
	var t = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)

func _on_btn_exit(btn):
	var t = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1, 1), 0.1)

func _on_btn_down(btn):
	var t = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(0.97, 0.97), 0.05)

func _on_btn_up(btn):
	var t = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.05)

func show_result(is_winner: bool, stats: Dictionary):
	$VBoxContainer/ReturnButton.pivot_offset = $VBoxContainer/ReturnButton.size * 0.5
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
		node.add_theme_font_override("font", FONT)
	for child in node.get_children():
		_set_font_recursive(child)

func _on_return_pressed():
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
