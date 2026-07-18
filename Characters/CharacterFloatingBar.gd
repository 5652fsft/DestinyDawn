extends Node2D

var parent_character: CharacterBody2D
var faction_color: Color = Color.WHITE
var pulse_tween: Tween = null

@onready var hp_bar: ColorRect = $HPBar
@onready var hp_fill: ColorRect = $HPBar/HPFill
@onready var hp_label: Label = $HPBar/HPLabel
@onready var shield_outline: Panel = $HPBar/ShieldOutline
@onready var faction_ring: Line2D = $FactionRing
@onready var selection_indicator: Line2D = $SelectionIndicator

static func make_hexagon_points(radius: float) -> PackedVector2Array:
	var w = radius * sqrt(3) / 2.0
	var h = radius
	return PackedVector2Array([
		Vector2(0, -h),
		Vector2(w, -h / 2.0),
		Vector2(w, h / 2.0),
		Vector2(0, h),
		Vector2(-w, h / 2.0),
		Vector2(-w, -h / 2.0),
		Vector2(0, -h)
	])

func _ready():
	parent_character = get_parent() as CharacterBody2D
	if not parent_character:
		queue_free()
		return

	faction_ring.points = make_hexagon_points(55.0)
	faction_ring.z_index = -1
	faction_ring.antialiased = true
	faction_ring.width = 6

	selection_indicator.points = make_hexagon_points(55.0)
	selection_indicator.z_index = -1
	selection_indicator.antialiased = true

	var shield_style = StyleBoxFlat.new()
	shield_style.draw_center = false
	shield_style.border_width_left = 2
	shield_style.border_width_top = 2
	shield_style.border_width_right = 2
	shield_style.border_width_bottom = 2
	shield_style.border_color = Color(1, 1, 1, 0.8)
	shield_style.corner_radius_top_left = 2
	shield_style.corner_radius_top_right = 2
	shield_style.corner_radius_bottom_left = 2
	shield_style.corner_radius_bottom_right = 2
	shield_outline.add_theme_stylebox_override("panel", shield_style)

	_update_faction()
	refresh()

func _update_faction():
	var is_host = parent_character.name.begins_with("Host")
	var is_friendly = is_host == GlobalGameData.is_host
	faction_color = Color(0.3, 0.5, 1.0, 0.5) if is_friendly else Color(1.0, 0.3, 0.3, 0.5)
	if faction_ring:
		faction_ring.default_color = faction_color

func refresh():
	if not parent_character or not is_inside_tree():
		return
	_update_hp()
	_update_shield()
	_update_faction()

func _update_hp():
	var hp = parent_character.hp if "hp" in parent_character else 0
	var max_hp = parent_character.max_hp if "max_hp" in parent_character else 100
	var ratio = float(hp) / float(max_hp) if max_hp > 0 else 0
	var fill_width = clamp(ratio, 0, 1) * 58.0
	hp_fill.size.x = fill_width
	hp_fill.position.x = 1
	hp_label.text = "%d/%d" % [hp, max_hp]
	if ratio > 0.6:
		hp_fill.color = Color(0.2, 0.8, 0.2)
	elif ratio > 0.3:
		hp_fill.color = Color(0.8, 0.8, 0.1)
	else:
		hp_fill.color = Color(0.8, 0.2, 0.1)

func _update_shield():
	var s = parent_character.shield if "shield" in parent_character else 0
	var has_shield = s > 0
	if shield_outline:
		shield_outline.visible = has_shield

func show_selected(selected: bool):
	if selection_indicator:
		if selected:
			selection_indicator.default_color.a = 0.0
			selection_indicator.visible = true
			_start_pulse()
		else:
			selection_indicator.visible = false
			if pulse_tween:
				pulse_tween.kill()

func _start_pulse():
	if pulse_tween:
		pulse_tween.kill()
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(selection_indicator, "default_color:a", 0.6, 0.6)
	pulse_tween.tween_property(selection_indicator, "default_color:a", 0.1, 0.6)
