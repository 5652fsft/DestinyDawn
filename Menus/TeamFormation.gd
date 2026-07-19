extends Control

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")
var CHARACTERS = {
	"bronya":    {"name":"布洛妮娅", "hp":80,  "move":5, "atk":15, "skill":"护卫指令"},
	"seele":     {"name":"希儿",    "hp":65,  "move":6, "atk":18, "skill":"相位突进"},
	"elaina":    {"name":"伊蕾娜",  "hp":60,  "move":5, "atk":20, "skill":"星尘爆裂"},
	"firefly":   {"name":"流萤",    "hp":90,  "move":5, "atk":14, "skill":"烈焰冲锋"},
	"silverwolf":{"name":"银狼",    "hp":65,  "move":5, "atk":16, "skill":"系统入侵"},
}

const CARD_SCENE = preload("res://Menus/Widgets/CharacterCard.tscn")

var slots: Array[String] = []
var cards: Dictionary = {}  # char_id -> CharacterCard node

func _build_roster():
	var grid = $RosterGrid
	for cid in CHARACTERS:
		var card = CARD_SCENE.instantiate()
		card.setup(cid, CHARACTERS[cid])
		card.selected.connect(_on_character_selected)
		grid.add_child(card)
		cards[cid] = card
	# 检查 slot sprite 是否加载了图片
	_refresh_slot_sprites()

func _refresh_slot_sprites():
	for i in range(3):
		var slot = get_node_or_null("Slot%d" % (i + 1))
		if not slot: continue
		var spr = slot.get_node_or_null("Sprite")
		if not spr: continue
		if i < slots.size():
			var cid = slots[i]
			var tex = load("res://Assets/Sprites/Characters/%s_Blue.png" % cid)
			if tex: spr.texture = tex
		else:
			spr.texture = null

func _on_character_selected(cid: String):
	if slots.size() >= 3:
		return
	if cid in slots:
		return
	slots.append(cid)
	_update_slots()

var _slot_labels: Array = []
var _slot_buttons: Array = []

func _ready():
	for i in range(1, 4):
		var lbl = get_node_or_null("Slot%d/NameLabel" % i)
		var btn = get_node_or_null("Slot%d/RemoveButton" % i)
		_slot_labels.append(lbl)
		_slot_buttons.append(btn)
		if btn:
			btn.pressed.connect(_remove_slot.bind(i - 1))
	if _slot_labels.is_empty() or not _slot_labels[0]:
		push_error("TeamFormation: Slot1 nodes missing — check tscn")
	else:
		_clear_team()
	_build_roster()

func _clear_team():
	slots.clear()
	for label in _slot_labels:
		if label:
			label.text = "空"

func _remove_slot(index: int):
	if index < slots.size():
		slots.remove_at(index)
		_update_slots()

func _update_slots():
	for cid in cards:
		cards[cid].set_team_status(cid in slots)
	for i in range(3):
		if i >= _slot_labels.size():
			continue
		var label = _slot_labels[i]
		var remove_btn = _slot_buttons[i]
		if not label or not remove_btn:
			continue
		if i < slots.size():
			var cid = slots[i]
			label.text = CHARACTERS[cid]["name"]
			remove_btn.show()
		else:
			label.text = "空"
			remove_btn.hide()
	_refresh_slot_sprites()

func _on_save_pressed():
	if slots.size() != 3:
		$HintLabel.text = "请选择 3 名角色"
		$HintLabel.show()
		await get_tree().create_timer(1.5).timeout
		$HintLabel.hide()
		return
	GlobalGameData.selected_team = slots.duplicate()
	get_tree().change_scene_to_file("res://Menus/NewMainMenu.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Menus/NewMainMenu.tscn")
