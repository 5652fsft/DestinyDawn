extends Control

const FONT = preload("res://Assets/Fronts/SourceHanSerifCN-Heavy-4.otf")
const CARD_WIDGET = preload("res://Menus/Widgets/DeckCardWidget.tscn")

const TYPE_NAMES = {0:"攻击",1:"治疗",2:"增益",3:"减益",4:"位移",5:"护盾",6:"战术"}

var deck: Array[String] = []
var pool_widgets: Dictionary = {}  # card_id -> DeckCardWidget

func _ready():
	_build_pool()
	_update_all()

func _build_pool():
	var all_ids = CardDatabase.get_all_card_ids()
	var grid = $HBoxContainer/CardPool/PoolScroll/GridContainer
	for cid in all_ids:
		var data = CardDatabase.get_card(cid)
		if not data:
			continue
		var w = CARD_WIDGET.instantiate()
		w.setup(cid, data.card_name, "费用: %d" % data.cost, TYPE_NAMES.get(data.card_type, "?"))
		w.added.connect(_on_card_added)
		grid.add_child(w)
		pool_widgets[cid] = w

func _on_card_added(cid: String):
	if deck.count(cid) >= 2:
		return
	deck.append(cid)
	_update_all()

func _on_card_removed(cid: String):
	deck.erase(cid)
	_update_all()

func _update_all():
	# Update pool widgets
	for cid in pool_widgets:
		var count = deck.count(cid)
		pool_widgets[cid].set_pool_mode(count > 0, count)
	# Update deck list
	var deck_list = $HBoxContainer/DeckPanel/DeckScroll/DeckList
	for c in deck_list.get_children():
		c.queue_free()
	for cid in deck:
		var data = CardDatabase.get_card(cid)
		if not data:
			continue
		var w = CARD_WIDGET.instantiate()
		w.setup(cid, data.card_name, "费用: %d" % data.cost, TYPE_NAMES.get(data.card_type, "?"))
		w.set_deck_mode()
		w.removed.connect(_on_card_removed)
		deck_list.add_child(w)
	# Update count
	$HBoxContainer/DeckPanel/CountLabel.text = "%d 张 (最少 8, 最多 15)" % deck.size()

func _on_save_pressed():
	if deck.size() < 8:
		$HintLabel.text = "至少需要 8 张卡牌"
		$HintLabel.show()
		await get_tree().create_timer(1.5).timeout
		$HintLabel.hide()
		return
	GlobalGameData.selected_deck = deck.duplicate()
	get_tree().change_scene_to_file("res://Menus/NewMainMenu.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Menus/NewMainMenu.tscn")
