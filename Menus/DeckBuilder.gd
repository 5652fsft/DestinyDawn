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
		w.card_double_clicked.connect(_on_card_double_clicked)
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
	# 重建出战卡组—增量更新
	var deck_grid = $VBoxContainer/DeckPanel/DeckGrid
	# 收集当前卡牌和占位格
	var existing_ids: Array[String] = []
	var to_free: Array[Node] = []
	for c in deck_grid.get_children():
		var is_card = false
		if "card_id" in c:
			var cid = c.card_id
			if cid in deck_ids:
				existing_ids.append(cid)
				is_card = true
			# 不在deck_ids中的卡牌→标记移除
		if not is_card:
			to_free.append(c)
	# 移除非卡牌节点（占位格等）
	for c in to_free:
		deck_grid.remove_child(c)
		c.queue_free()
	# 添加缺失的卡牌（到末尾）
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
		existing_ids.append(cid)
	# 补充空槽位
	var card_count = existing_ids.size()
	for i in range(DECK_SIZE - card_count):
		var empty = Panel.new()
		empty.custom_minimum_size = Vector2(120, 170)
		empty.modulate = Color(1, 1, 1, 0.15)
		deck_grid.add_child(empty)
	# 更新计数
	$VBoxContainer/DeckPanel/CountLabel.text = "%d / %d" % [deck_ids.size(), DECK_SIZE]
	var sb = get_node_or_null("SaveButton")
	if sb: sb.disabled = deck_ids.size() < DECK_SIZE

func _on_card_double_clicked(cid: String):
	if deck_ids.size() >= DECK_SIZE:
		_show_toast("卡组已满")
		return
	if cid in deck_ids:
		_show_toast("该卡牌已在卡组中")
		return
	deck_ids.append(cid)
	_update_ui()
	_show_toast("已自动配置到卡槽 %d" % deck_ids.size())

func _show_toast(msg: String):
	$HintLabel.text = msg
	$HintLabel.show()
	$HintLabel.modulate.a = 1.0
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property($HintLabel, "modulate:a", 0.0, 0.35).set_delay(1.2)
	tw.finished.connect(func(): $HintLabel.hide())

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
