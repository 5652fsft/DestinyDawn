extends Control

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")
const CardTheme = preload("res://UI/CardTheme.gd")
const CharData = preload("res://Global/CharacterData.gd")

const CARD_SCENE = preload("res://Menus/Widgets/CharacterCard.tscn")

var slots: Array[String] = []
var cards: Dictionary = {}

func _ready():
	slots = GlobalGameData.selected_team.duplicate()
	_apply_slot_glass()
	_build_roster()
	_update_slots()

	for btn in [$BackButton, $SaveButton]:
		ButtonTheme.apply_menu(btn)
		ButtonTheme.apply_glass_blue(btn)
		ButtonTheme.set_font(btn, 20)
	
	# 初始化单例背景
	BackgroundSingleton.setup(BackgroundManager.get_current_bg_path())

# 我的队伍区：容器透明（不显示毛玻璃底框，由小卡自身承载视觉）
func _apply_slot_glass():
	$SlotGlassPanel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func _build_roster():
	var grid = $RosterScroll/Margin/RosterGrid
	for cid in CharData.DATA:
		var data = CharData.DATA[cid]
		var card = CARD_SCENE.instantiate()
		card.setup(cid, data)
		card.clicked.connect(_on_card_clicked)
		grid.add_child(card)
		cards[cid] = card

func _on_card_clicked(cid: String):
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("deck_select")
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
	var container = $SlotGlassPanel/SlotContainer
	for c in container.get_children():
		c.queue_free()
	for i in range(3):
		if i < slots.size():
			var cid = slots[i]
			var data = CharData.DATA[cid]
			var slot = Panel.new()
			slot.custom_minimum_size = Vector2(220, 80)
			var p = StyleBoxFlat.new()
			p.bg_color = Color(0.2, 0.22, 0.3, 0.75)
			p.corner_radius_top_left = CardTheme.CARD_BORDER_RADIUS
			p.corner_radius_top_right = CardTheme.CARD_BORDER_RADIUS
			p.corner_radius_bottom_left = CardTheme.CARD_BORDER_RADIUS
			p.corner_radius_bottom_right = CardTheme.CARD_BORDER_RADIUS
			p.border_color = Color(1, 1, 1, 0.14)
			p.border_width_top = 1
			p.border_width_right = 1
			p.border_width_bottom = 1
			p.border_width_left = 1
			slot.add_theme_stylebox_override("panel", p)
			container.add_child(slot)

			var frame = Panel.new()
			frame.custom_minimum_size = Vector2(90, 54)
			frame.clip_contents = true
			var fs = StyleBoxFlat.new()
			fs.bg_color = Color(0.12, 0.13, 0.18, 0.9)
			fs.corner_radius_top_left = 8
			fs.corner_radius_top_right = 8
			fs.corner_radius_bottom_left = 8
			fs.corner_radius_bottom_right = 8
			fs.border_color = Color(1, 1, 1, 0.08)
			fs.border_width_top = 1
			fs.border_width_right = 1
			fs.border_width_bottom = 1
			fs.border_width_left = 1
			frame.add_theme_stylebox_override("panel", fs)
			frame.position = Vector2(10, 13)
			slot.add_child(frame)

			var spr = TextureRect.new()
			spr.texture = load("res://Assets/Sprites/Standee/%s_Standee.png" % CharData.get_sprite_id(cid))
			spr.expand_mode = 1
			spr.stretch_mode = 5
			spr.size = Vector2(90, 54)
			frame.add_child(spr)

			var lbl = Label.new()
			lbl.text = data.name
			lbl.add_theme_font_override("font", FONT)
			lbl.add_theme_font_size_override("font_size", 15)
			lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
			lbl.add_theme_constant_override("shadow_offset_x", 1)
			lbl.add_theme_constant_override("shadow_offset_y", 1)
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.position = Vector2(108, 24)
			lbl.size = Vector2(102, 32)
			slot.add_child(lbl)

			var slot_idx = i
			slot.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("deck_select")
					_remove_slot(slot_idx))
		else:
			var empty = Panel.new()
			empty.custom_minimum_size = Vector2(220, 80)
			var es = StyleBoxFlat.new()
			es.bg_color = Color(0.2, 0.22, 0.3, 0.35)
			es.corner_radius_top_left = CardTheme.CARD_BORDER_RADIUS
			es.corner_radius_top_right = CardTheme.CARD_BORDER_RADIUS
			es.corner_radius_bottom_left = CardTheme.CARD_BORDER_RADIUS
			es.corner_radius_bottom_right = CardTheme.CARD_BORDER_RADIUS
			es.border_color = Color(1, 1, 1, 0.14)
			es.border_width_top = 1
			es.border_width_right = 1
			es.border_width_bottom = 1
			es.border_width_left = 1
			empty.add_theme_stylebox_override("panel", es)
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
	SaveManager.save_all()
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")

func _on_back_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("click")
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
