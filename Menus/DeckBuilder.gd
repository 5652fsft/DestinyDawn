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
	var grid = $HBoxContainer/CardPool/PoolScroll/GridContainer
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
		return  # 同名最�?�?	deck_ids.append(cid)
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
	# 更新牌库显示
	for cid in pool_widgets:
		pool_widgets[cid].set_in_deck_mode(cid in deck_ids)
	# 重建出战卡组
	var deck_grid = $HBoxContainer/DeckPanel/DeckScroll/DeckGrid
	for c in deck_grid.get_children():
		c.queue_free()
	for cid in deck_ids:
		var data = CardDatabase.get_card(cid)
		if not data: continue
		var w = CARD_SCENE.instantiate()
		w.setup(cid, data.card_name, data.cost, TYPE_NAMES.get(data.card_type, "?"), data.description)
		w.card_removed.connect(_on_card_removed)
		w.card_reordered.connect(_on_card_reordered)
		w.set_in_deck_mode(true)
		deck_grid.add_child(w)
	# 空槽位占�?	for i in range(DECK_SIZE - deck_ids.size()):
		var empty = Panel.new()
		empty.custom_minimum_size = Vector2(120, 170)
		empty.modulate = Color(1, 1, 1, 0.15)
		deck_grid.add_child(empty)
	# 更新计数
	$HBoxContainer/DeckPanel/CountLabel.text = "%d / %d" % [deck_ids.size(), DECK_SIZE]
	$SaveButton.disabled = deck_ids.size() < DECK_SIZE

func _on_save_pressed():
	if deck_ids.size() < DECK_SIZE:
		$HintLabel.text = "请选择 %d 张卡�? % DECK_SIZE
		$HintLabel.show()
		await get_tree().create_timer(1.5).timeout
		$HintLabel.hide()
		return
	GlobalGameData.selected_deck = deck_ids.duplicate()
	get_tree().change_scene_to_file("res://Menus/NewMainMenu.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Menus/NewMainMenu.tscn")
