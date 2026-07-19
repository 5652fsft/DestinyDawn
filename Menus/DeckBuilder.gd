extends Control

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")
const CARD_SCENE = preload("res://Menus/Widgets/DeckCardUI.tscn")

const TYPE_NAMES = {0:"攻击",1:"治疗",2:"增益",3:"减益",4:"位移",5:"护盾",6:"战术"}
const DECK_SIZE = 8

var deck_ids: Array[String] = []
var pool_widgets: Dictionary = {}  # card_id -> DeckCardUI

func _ready():
	_build_pool()
	_update_ui()

func _build_pool():
	var grid = $VBoxContainer/CardPool/PoolScroll/GridContainer
	if not grid:
		return
	for cid in CardDatabase.get_all_card_ids():
		var data = CardDatabase.get_card(cid)
		if not data: continue
		var w = CARD_SCENE.instantiate()
		w.setup(cid, data.card_name, data.cost, TYPE_NAMES.get(data.card_type, "?"), data.description)
		w.card_added.connect(_on_card_added)
		grid.add_child(w)
		pool_widgets[cid] = w

func _on_card_added(cid: String):
	if deck_ids.size() >= DECK_SIZE:
		return
	if cid in deck_ids:
		return  # 同名最多1张
	deck_ids.append(cid)
	_update_ui()

func _on_card_removed(cid: String):
	deck_ids.erase(cid)
	_update_ui()

func _on_card_reordered(cid: String, from: int, to: int):
	if from < 0 or from >= deck_ids.size() or to < 0 or to >= deck_ids.size():
		return
	deck_ids.remove_at(from)
	deck_ids.insert(to, cid)
	_update_ui()

func _update_ui():
	# 更新牌库显示 — 跳过已释放的widget
	for cid in pool_widgets.keys():
		var w = pool_widgets[cid]
		if is_instance_valid(w):
			w.set_in_deck_mode(cid in deck_ids)
		else:
			pool_widgets.erase(cid)
	# 重建出战卡组
	var deck_grid = $VBoxContainer/DeckPanel/DeckGrid
	# 保留已有卡牌节点，只移除多余的
	var existing = deck_grid.get_children()
	var existing_ids: Array[String] = []
	for c in existing:
		if c.has_method("get") and c.get("card_id") != null:
			var cid = c.card_id
			if cid in deck_ids:
				existing_ids.append(cid)
			else:
				c.queue_free()
		else:
			c.queue_free()
	# 添加缺失的卡牌
	for cid in deck_ids:
		if cid in existing_ids: continue
		var data = CardDatabase.get_card(cid)
		if not data: continue
		var w = CARD_SCENE.instantiate()
		w.setup(cid, data.card_name, data.cost, TYPE_NAMES.get(data.card_type, "?"), data.description)
		w.card_removed.connect(_on_card_removed)
		w.card_reordered.connect(_on_card_reordered)
		w.set_in_deck_mode(true)
		deck_grid.add_child(w)
	# 空槽位占位
	var current_cards = 0
	for c in deck_grid.get_children():
		if c.has_method("get") and c.get("card_id") != null:
			current_cards += 1
	for i in range(DECK_SIZE - current_cards):
		var empty = Panel.new()
		empty.custom_minimum_size = Vector2(120, 170)
		empty.modulate = Color(1, 1, 1, 0.15)
		deck_grid.add_child(empty)
	# 更新计数
	$VBoxContainer/DeckPanel/CountLabel.text = "%d / %d" % [deck_ids.size(), DECK_SIZE]
	var sb = get_node_or_null("SaveButton")
	if sb: sb.disabled = deck_ids.size() < DECK_SIZE

func _on_save_pressed():
	if deck_ids.size() < DECK_SIZE:
		$HintLabel.text = "请选择 %d 张卡牌" % DECK_SIZE
		$HintLabel.show()
		await get_tree().create_timer(1.5).timeout
		$HintLabel.hide()
		return
	GlobalGameData.selected_deck = deck_ids.duplicate()
	get_tree().change_scene_to_file("res://Menus/NewMainMenu.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Menus/NewMainMenu.tscn")
