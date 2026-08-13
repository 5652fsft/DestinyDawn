extends Control

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
	_apply_deck_glass()
	$VBoxContainer/DeckPanel/DeckGlassPanel/DeckGrid.resized.connect(func():
		_ensure_scale_later($VBoxContainer/DeckPanel/DeckGlassPanel/DeckGrid))
	_build_pool()
	_update_ui()

	for btn in [$BackButton, $SaveButton]:
		ButtonTheme.apply_menu(btn)
		ButtonTheme.apply_glass_blue(btn)
		ButtonTheme.set_font(btn, 20)
	
	# 初始化单例背景
	BackgroundSingleton.setup(BackgroundManager.get_current_bg_path())

# 出战卡组区：浅色毛玻璃底色（参照主菜单按钮玻璃样式）
func _apply_deck_glass():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.4, 0.43, 0.45)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color(0.6, 0.6, 0.65, 0.4)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	$VBoxContainer/DeckPanel/DeckGlassPanel.add_theme_stylebox_override("panel", style)

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
		return
	if deck_ids.size() >= DECK_SIZE:
		return
	deck_ids.append(cid)
	_update_ui()

func _on_deck_card_clicked(cid: String):
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("deck_select")
	deck_ids.erase(cid)
	_update_ui()

func _update_ui():
	# 更新牌库显示（已加入卡组的卡显示选中态）
	for cid in pool_widgets.keys():
		var w = pool_widgets[cid]
		if is_instance_valid(w):
			w.set_in_deck_mode(cid in deck_ids)
		else:
			pool_widgets.erase(cid)
	# 重建出战卡组
	var deck_grid = $VBoxContainer/DeckPanel/DeckGlassPanel/DeckGrid
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
	_ensure_scale(deck_grid)
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
		empty.scale = Vector2(0.93, 0.93)
		empty.position.y = 6
		var es = StyleBoxFlat.new()
		es.bg_color = Color(0.15, 0.15, 0.25, 0.3)
		es.corner_radius_top_left = 8
		es.corner_radius_top_right = 8
		es.corner_radius_bottom_left = 8
		es.corner_radius_bottom_right = 8
		empty.add_theme_stylebox_override("panel", es)
		deck_grid.add_child(empty)
	# Container 布局会把子节点 scale 重置为 1.0，且布局消息在同步代码之后执行，
	# 等两帧布局完全稳定后再修正占位格 scale
	_ensure_scale_later(deck_grid)
	$VBoxContainer/DeckPanel/CountLabel.text = "%d / %d" % [deck_ids.size(), DECK_SIZE]
	
	
	var sb = get_node_or_null("SaveButton")
	if sb: sb.disabled = deck_ids.size() < DECK_SIZE

func _ensure_scale_later(grid):
	await get_tree().process_frame
	await get_tree().process_frame
	_ensure_scale(grid)

func _ensure_scale(deck_grid):
	# 确保现有卡牌scale正确（出战卡组区不显示选中高亮）
	for c in deck_grid.get_children():
		if "card_id" in c and c.has_method("_reset_scale"):
			c._reset_scale()
			if c.card_id in deck_ids:
				c.set_in_deck_mode(false)
		elif not "card_id" in c:
			c.scale = Vector2(0.93, 0.93)
			c.position.y = 6

func _on_save_pressed():
	if deck_ids.size() < DECK_SIZE:
		return
	GlobalGameData.selected_deck = deck_ids.duplicate()
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")

func _on_back_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
