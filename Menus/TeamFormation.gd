extends Control

const FONT = preload("res://Assets/Fronts/SourceHanSerifCN-Heavy-4.otf")
const CHARACTERS = {
	"bronya":    {name:"布洛妮娅", hp:120, move:6, atk:20, skill:"护卫指令"},
	"seele":     {name:"希儿",    hp:90,  move:5, atk:20, skill:"相位突进"},
	"elaina":    {name:"伊蕾娜",  hp:85,  move:5, atk:22, skill:"星尘爆裂"},
	"firefly":   {name:"流萤",    hp:130, move:5, atk:18, skill:"烈焰冲锋"},
	"silverwolf":{name:"银狼",    hp:90,  move:6, atk:20, skill:"系统入侵"},
}

const CARD_SCENE = preload("res://Menus/Widgets/CharacterCard.tscn")

var slots: Array[String] = []
var cards: Dictionary = {}  # char_id -> CharacterCard node

func _ready():
	_clear_team()
	_build_roster()
	_update_slots()

func _build_roster():
	var grid = $RosterGrid
	for cid in CHARACTERS:
		var card = CARD_SCENE.instantiate()
		card.setup(cid, CHARACTERS[cid])
		card.selected.connect(_on_character_selected)
		grid.add_child(card)
		cards[cid] = card

func _on_character_selected(cid: String):
	if slots.size() >= 3:
		return
	if cid in slots:
		return
	slots.append(cid)
	_update_slots()

func _clear_team():
	slots.clear()
	for i in range(1, 4):
		var label = get_node("Slot%d/NameLabel" % i)
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
		var label = get_node("Slot%d/NameLabel" % (i + 1))
		var remove_btn = get_node("Slot%d/RemoveButton" % (i + 1))
		if i < slots.size():
			var cid = slots[i]
			label.text = CHARACTERS[cid].name
			remove_btn.show()
		else:
			label.text = "空"
			remove_btn.hide()

func _on_save_pressed():
	if slots.size() != 3:
		$HintLabel.text = "请选择 3 名角色"
		$HintLabel.show()
		await get_tree().create_timer(1.5).timeout
		$HintLabel.hide()
		return
	GlobalGameData.selected_team = slots.duplicate()
	get_tree().change_scene_to_file("res://Menus/NewMainMenu.tscn")

func _on_slot1_remove(): _remove_slot(0)
func _on_slot2_remove(): _remove_slot(1)
func _on_slot3_remove(): _remove_slot(2)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Menus/NewMainMenu.tscn")
