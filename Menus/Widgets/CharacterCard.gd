extends Panel

const CardTheme = preload("res://UI/CardTheme.gd")

var char_id: String = ""
var _in_team: bool = false
var _flipped: bool = false
var _hover_tween: Tween = null
var _flip_tween: Tween = null
var _base_scale: Vector2 = Vector2.ONE
var _full_scale: Vector2 = Vector2.ONE

signal clicked(cid: String)

func setup(id: String, data: Dictionary):
	char_id = id
	$CardFront/PortraitRect.texture = load("res://Assets/Sprites/Standee/%s_Standee.png" % CharacterData.get_sprite_id(id))
	$CardFront/NameLabel.text = data.name
	$CardFront/HPLabel.text = "生命值: %d" % data.hp
	$CardFront/ATKLabel.text = "攻击力: %d" % data.atk
	$CardFront/MoveLabel.text = "移动范围: %d" % data.move
	$CardFront/RangeLabel.text = "攻击范围: %d" % data.get("range", 1)
	$CardFront/SkillLabel.text = data.skill
	$CardFront/PassiveLabel.text = "天赋·%s" % data.get("passive", "")
	$InfoButton.icon = preload("res://Assets/Icons/info.png")
	$InfoButton.text = ""
	$InfoButton.expand_icon = true

	$CardBack/Scroll/VBox/NameLabel.text = data.name
	$CardBack/Scroll/VBox/HPLabel.text = "生命值: %d" % data.hp
	$CardBack/Scroll/VBox/ATKLabel.text = "攻击力: %d" % data.atk
	$CardBack/Scroll/VBox/MoveLabel.text = "移动范围: %d" % data.move
	$CardBack/Scroll/VBox/RangeLabel.text = "攻击范围: %d" % data.get("range", 1)
	$CardBack/Scroll/VBox/SkillLabel.text = data.skill
	$CardBack/Scroll/VBox/SkillLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$CardBack/Scroll/VBox/SkillDescLabel.text = "%s (CD: %d)" % [data.get("skill_desc", ""), data.get("skill_cd", 0)]
	$CardBack/Scroll/VBox/SkillDescLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$CardBack/Scroll/VBox/SkillDescLabel.modulate = Color(0.8, 0.8, 0.9)
	$CardBack/Scroll/VBox/PassiveLabel.text = "天赋·%s" % data.get("passive", "")
	$CardBack/Scroll/VBox/PassiveLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$CardBack/Scroll/VBox/PassiveDescLabel.text = data.get("passive_desc", "")
	$CardBack/Scroll/VBox/PassiveDescLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$CardBack/Scroll/VBox/PassiveDescLabel.modulate = Color(0.8, 0.8, 0.9)

	pivot_offset = size * 0.5
	_base_scale = scale
	_full_scale = scale
	_apply_style()

func _apply_style():
	var p = StyleBoxFlat.new()
	p.bg_color = Color(0.15, 0.15, 0.25, 0.8)
	p.corner_radius_top_left = CardTheme.CARD_BORDER_RADIUS
	p.corner_radius_top_right = CardTheme.CARD_BORDER_RADIUS
	p.corner_radius_bottom_left = CardTheme.CARD_BORDER_RADIUS
	p.corner_radius_bottom_right = CardTheme.CARD_BORDER_RADIUS
	p.border_color = Color(1, 1, 1, 0.08)
	p.border_width_top = 1
	p.border_width_right = 1
	p.border_width_bottom = 1
	p.border_width_left = 1
	p.corner_radius_top_left = CardTheme.CARD_BORDER_RADIUS
	p.corner_radius_top_right = CardTheme.CARD_BORDER_RADIUS
	p.corner_radius_bottom_left = CardTheme.CARD_BORDER_RADIUS
	p.corner_radius_bottom_right = CardTheme.CARD_BORDER_RADIUS
	add_theme_stylebox_override("panel", p)
	var ib = StyleBoxFlat.new()
	ib.bg_color = CardTheme.COST_BG
	ib.corner_radius_top_left = 11
	ib.corner_radius_top_right = 11
	ib.corner_radius_bottom_left = 11
	ib.corner_radius_bottom_right = 11
	$InfoButton.add_theme_stylebox_override("normal", ib)
	var ibh = StyleBoxFlat.new()
	ibh.bg_color = CardTheme.COST_BG + Color(0.15, 0.15, 0.15, 0)
	ibh.corner_radius_top_left = 11
	ibh.corner_radius_top_right = 11
	ibh.corner_radius_bottom_left = 11
	ibh.corner_radius_bottom_right = 11
	$InfoButton.add_theme_stylebox_override("hover", ibh)
	var b = StyleBoxFlat.new()
	b.bg_color = Color(0.15, 0.15, 0.25, 0.8)
	b.corner_radius_top_left = CardTheme.CARD_BORDER_RADIUS
	b.corner_radius_top_right = CardTheme.CARD_BORDER_RADIUS
	b.corner_radius_bottom_left = CardTheme.CARD_BORDER_RADIUS
	b.corner_radius_bottom_right = CardTheme.CARD_BORDER_RADIUS
	b.border_color = Color(1, 1, 1, 0.08)
	b.border_width_top = 1
	b.border_width_right = 1
	b.border_width_bottom = 1
	b.border_width_left = 1
	$CardBack/Scroll/VBox.add_theme_stylebox_override("panel", b)

func _ready():
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	pivot_offset = size * 0.5
	_base_scale = scale
	_full_scale = scale
	z_index = 5

func _gui_input(event: InputEvent):
	if _flipped:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(char_id)

func set_team_status(in_team: bool):
	_in_team = in_team
	if _flipped:
		return
	modulate = Color(1, 1, 1, 1) if not in_team else Color(CardTheme.DISABLED_ALPHA, CardTheme.DISABLED_ALPHA, CardTheme.DISABLED_ALPHA, 1)

func _on_hover_enter():
	if _hover_tween: _hover_tween.kill()
	z_index = 20
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_method(_set_full_scale, _full_scale, _base_scale * 1.08, CardTheme.HOVER_TWEEN_SEC)
	_hover_tween.parallel().tween_property(self, "self_modulate", CardTheme.HOVER_MODULATE, CardTheme.HOVER_TWEEN_SEC)

func _on_hover_exit():
	if _hover_tween: _hover_tween.kill()
	z_index = 5
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_method(_set_full_scale, scale, _base_scale, CardTheme.HOVER_TWEEN_SEC)
	_hover_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, CardTheme.HOVER_TWEEN_SEC)

func _set_full_scale(s: Vector2):
	_full_scale = s
	if not _flip_tween or not _flip_tween.is_running():
		scale = s

func _on_info_pressed():
	var _am = Engine.get_singleton("AudioManager"); if _am: _am.play_sfx("card_play")
	if _flip_tween: _flip_tween.kill()
	_flipped = not _flipped
	_flip_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_flip_tween.tween_method(_set_flip_x, _full_scale.x, 0.0, 0.12)
	_flip_tween.tween_callback(_swap_face)
	_flip_tween.tween_method(_set_flip_x, 0.0, _full_scale.x, 0.12)

func _set_flip_x(v: float):
	var s = _full_scale
	s.x = v
	scale = s

func _swap_face():
	$CardFront.visible = not _flipped
	$CardBack.visible = _flipped
	if _flipped:
		modulate = Color.WHITE
	else:
		modulate = Color(1, 1, 1, 1) if not _in_team else Color(CardTheme.DISABLED_ALPHA, CardTheme.DISABLED_ALPHA, CardTheme.DISABLED_ALPHA, 1)
