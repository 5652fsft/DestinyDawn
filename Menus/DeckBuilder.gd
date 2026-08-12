extends Control

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")
const CARD_SCENE = preload("res://Menus/Widgets/DeckCardUI.tscn")

const TYPE_NAMES = {0:"攻击",1:"治疗",2:"增益",3:"减益",4:"位移",5:"护盾",6:"战术"}
const DECK_SIZE = 8

var deck_ids: Array[String] = []
var pool_widgets: Dictionary = {}

func _ready():
	deck_ids = GlobalGameData.selected_deck.duplicate()
	var transparent = StyleBoxEmpty.new()
	$VBoxContainer/DeckPanel.add_theme_stylebox_override("panel", transparent)
	$VBoxContainer/CardPool.add_theme_stylebox_override("panel", transparent)
	_build_pool()
	_update_ui()

	for btn in [$BackButton, $SaveButton]:
		ButtonTheme.apply_menu(btn)
		ButtonTheme.apply_glass_blue(btn)
		ButtonTheme.set_font(btn, 20)
	
	# 初始化单例背景
	BackgroundSingleton.setup(BackgroundManager.get_current_bg_path())

func _build_pool():
	var grid = $VBoxContainer/CardPool/PoolScroll/GridContainer
	if not grid: return
	for cid in CardDatabase.get_all_card_ids():
		var data = CardDatabase.get_card(cid)
		if not data: continue
		var w = CARD_SCENE.instantiate()
		w.clicked.connect(_on_pool_card_clicked)
		grid.add_child(w)
		w.setup(cid, data.card_name, data.cost, TYPE_NAMES.get(data.card_type, "?"), data.description, data.card_type)
		pool_widgets[cid] = w

func _on_pool_card_clicked(cid: String):
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("deck_select")
	if cid in deck_ids:
		deck_ids.erase(cid)
		_update_ui()
		_show_toast("已移出卡组")
		return
	if deck_ids.size() >= DECK_SIZE:
		_show_toast("卡组已满")
		return
	deck_ids.append(cid)
	_update_ui()
	_show_toast("已加入卡组")

func _on_deck_card_clicked(cid: String):
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("deck_select")
	deck_ids.erase(cid)
	_update_ui()
	_show_toast("已移出卡组")

func _update_ui():
	# 更新牌库显示（已加入卡组的卡显示选中态）
	for cid in pool_widgets.keys():
		var w = pool_widgets[cid]
		if is_instance_valid(w):
			w.set_in_deck_mode(cid in deck_ids)
		else:
			pool_widgets.erase(cid)
	# 重建出战卡组
	var deck_grid = $VBoxContainer/DeckPanel/DeckGrid
	var existing_ids: Array[String] = []
	var to_free: Array[Node] = []
	for c in deck_grid.get_children():
		var is_card = false
		if "card_id" in c:
			var cid = c.card_id
			if cid in deck_ids:
				existing_ids.append(cid)
				is_card = true
		if not is_card:
			to_free.append(c)
	for c in to_free:
		deck_grid.remove_child(c)
		c.queue_free()
	# 确保现有卡牌scale正确（出战卡组区不显示选中高亮）
	for c in deck_grid.get_children():
		if "card_id" in c and c.has_method("_reset_scale"):
			c._reset_scale()
			if c.card_id in deck_ids:
				c.set_in_deck_mode(false)
	# 添加缺失的卡牌（到末尾）
	for cid in deck_ids:
		if cid in existing_ids: continue
		var data = CardDatabase.get_card(cid)
		if not data: continue
		var w = CARD_SCENE.instantiate()
		w.clicked.connect(_on_deck_card_clicked)
		deck_grid.add_child(w)
		w.setup(cid, data.card_name, data.cost, TYPE_NAMES.get(data.card_type, "?"), data.description, data.card_type)
		w.set_in_deck_mode(false)
		existing_ids.append(cid)
	var card_count = existing_ids.size()
	for i in range(DECK_SIZE - card_count):
		var empty = Panel.new()
		empty.custom_minimum_size = Vector2(125, 183)
		var es = StyleBoxFlat.new()
		es.bg_color = Color(0.15, 0.15, 0.25, 0.3)
		es.corner_radius_top_left = 8
		es.corner_radius_top_right = 8
		es.corner_radius_bottom_left = 8
		es.corner_radius_bottom_right = 8
		empty.add_theme_stylebox_override("panel", es)
		deck_grid.add_child(empty)
	$VBoxContainer/DeckPanel/CountLabel.text = "%d / %d" % [deck_ids.size(), DECK_SIZE]
	var sb = get_node_or_null("SaveButton")
	if sb: sb.disabled = deck_ids.size() < DECK_SIZE

func _show_toast(msg: String):
	var label = Label.new()
	label.text = msg
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 18)
	label.horizontal_alignment = 1
	label.modulate = Color(1, 1, 0.85, 1)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.custom_minimum_size = Vector2(700, 0)
	label.position = Vector2(290, 16)
	add_child(label)
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(1.2)
	tw.finished.connect(func():
		if is_instance_valid(label): label.queue_free())

func _on_save_pressed():
	if deck_ids.size() < DECK_SIZE:
		_show_toast("请选择 %d 张卡牌" % DECK_SIZE)
		return
	GlobalGameData.selected_deck = deck_ids.duplicate()
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")

func _on_back_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
