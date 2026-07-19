extends Control

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")
const CardTheme = preload("res://UI/CardTheme.gd")
const CharacterData = preload("res://Global/CharacterData.gd")

const CARD_SCENE = preload("res://Menus/Widgets/CharacterCard.tscn")

var slots: Array[String] = []
var cards: Dictionary = {}

func _ready():
	slots = GlobalGameData.selected_team.duplicate()
	_build_roster()
	_update_slots()

func _build_roster():
	var grid = $RosterScroll/RosterGrid
	for cid in CharacterData.get_all_ids():
		var data = CharacterData.get(cid)
		var card = CARD_SCENE.instantiate()
		card.setup(cid, data)
		card.clicked.connect(_on_card_clicked)
		grid.add_child(card)
		cards[cid] = card

func _on_card_clicked(cid: String):
	if cid in slots:
		slots.erase(cid)
	else:
		if slots.size() >= 3:
			return
		slots.append(cid)
	_update_slots()

func _update_slots():
	for cid in cards:
		cards[cid].set_team_status(cid in slots)
	_build_slot_uis()

func _build_slot_uis():
	var container = $SlotContainer
	for c in container.get_children():
		c.queue_free()
	for i in range(3):
		if i < slots.size():
			var cid = slots[i]
			var data = CharacterData.get(cid)
			var slot = Panel.new()
			slot.custom_minimum_size = Vector2(220, 80)
			var p = StyleBoxFlat.new()
			p.bg_color = CardTheme.CARD_BG
			p.corner_radius_top_left = CardTheme.CARD_BORDER_RADIUS
			p.corner_radius_top_right = CardTheme.CARD_BORDER_RADIUS
			p.corner_radius_bottom_left = CardTheme.CARD_BORDER_RADIUS
			p.corner_radius_bottom_right = CardTheme.CARD_BORDER_RADIUS
			slot.add_theme_stylebox_override("panel", p)
			container.add_child(slot)

			var spr = TextureRect.new()
			spr.texture = load("res://Assets/Sprites/Standee/%s_Standee.png" % cid)
			spr.expand_mode = 1
			spr.stretch_mode = 5
			spr.size = Vector2(80, 48)
			spr.position = Vector2(8, 16)
			slot.add_child(spr)

			var lbl = Label.new()
			lbl.text = data.name
			lbl.add_theme_font_override("font", FONT)
			lbl.add_theme_font_size_override("font_size", 18)
			lbl.position = Vector2(96, 16)
			lbl.size = Vector2(110, 28)
			slot.add_child(lbl)

			var slot_idx = i
			slot.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					_remove_slot(slot_idx))
		else:
			var empty = Panel.new()
			empty.custom_minimum_size = Vector2(220, 80)
			empty.modulate = Color(1, 1, 1, 0.15)
			container.add_child(empty)

func _remove_slot(index: int):
	if index < slots.size():
		slots.remove_at(index)
		_update_slots()

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
