extends Panel

func _ready():
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.7)
	add_theme_stylebox_override("panel", bg)

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.13, 0.18, 0.95)
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_color = Color(0.3, 0.32, 0.35, 0.6)
	card_style.corner_radius_top_left = 12
	card_style.corner_radius_top_right = 12
	card_style.corner_radius_bottom_left = 12
	card_style.corner_radius_bottom_right = 12
	card_style.shadow_size = 8
	card_style.shadow_color = Color(0, 0, 0, 0.5)
	card_style.shadow_offset = Vector2(0, 4)
	$VBoxContainer.add_theme_stylebox_override("panel", card_style)

	var stats_style = StyleBoxFlat.new()
	stats_style.bg_color = Color(0.15, 0.16, 0.2, 0.6)
	stats_style.border_width_top = 1
	stats_style.border_width_bottom = 1
	stats_style.border_width_left = 1
	stats_style.border_width_right = 1
	stats_style.border_color = Color(0.25, 0.27, 0.3, 0.5)
	stats_style.corner_radius_top_left = 8
	stats_style.corner_radius_top_right = 8
	stats_style.corner_radius_bottom_left = 8
	stats_style.corner_radius_bottom_right = 8
	$VBoxContainer/StatsContainer/MyPanel.add_theme_stylebox_override("panel", stats_style)
	$VBoxContainer/StatsContainer/EnemyPanel.add_theme_stylebox_override("panel", stats_style)

	ButtonTheme.apply_menu($VBoxContainer/ButtonVBox/ReturnButton)
	ButtonTheme.set_font($VBoxContainer/ButtonVBox/ReturnButton, 22)
	ButtonTheme.apply_menu($VBoxContainer/ButtonVBox/RetryButton)
	ButtonTheme.set_font($VBoxContainer/ButtonVBox/RetryButton, 22)
	hide()

func show_result(is_winner: bool, stats: Dictionary):
	$VBoxContainer/TitleLabel.text = "胜 利" if is_winner else "败 北"
	$VBoxContainer/TitleLabel.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if is_winner else Color(1.0, 0.3, 0.3))

	var my_prefix = "host" if GlobalGameData.is_host else "client"
	var en_prefix = "client" if GlobalGameData.is_host else "host"

	$VBoxContainer/StatsContainer/MyPanel/MyDamage.text = "造成伤害: %d" % stats[my_prefix + "_damage_dealt"]
	$VBoxContainer/StatsContainer/MyPanel/MyHeal.text = "治疗量: %d" % stats[my_prefix + "_healing_done"]
	$VBoxContainer/StatsContainer/MyPanel/MyCards.text = "使用卡牌: %d" % stats[my_prefix + "_cards_played"]
	$VBoxContainer/StatsContainer/MyPanel/MyKills.text = "击杀: %d" % stats[my_prefix + "_kills"]

	$VBoxContainer/StatsContainer/EnemyPanel/EnDamage.text = "造成伤害: %d" % stats[en_prefix + "_damage_dealt"]
	$VBoxContainer/StatsContainer/EnemyPanel/EnHeal.text = "治疗量: %d" % stats[en_prefix + "_healing_done"]
	$VBoxContainer/StatsContainer/EnemyPanel/EnCards.text = "使用卡牌: %d" % stats[en_prefix + "_cards_played"]
	$VBoxContainer/StatsContainer/EnemyPanel/EnKills.text = "使用卡牌: %d" % stats[en_prefix + "_kills"]

	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.4)
	show()

func _on_return_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	BackgroundSingleton.exit_battle()
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")

func _on_retry_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	BackgroundSingleton.exit_battle()
	get_tree().change_scene_to_file("res://Scenes/scene.tscn")
