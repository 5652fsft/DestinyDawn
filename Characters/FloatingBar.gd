extends Node2D

var parent_character: CharacterBody2D
var pulse_tween: Tween = null

@onready var hp_bar: ColorRect = $HPBar
@onready var hp_fill: ColorRect = $HPBar/HPFill
@onready var hp_label: Label = $HPBar/HPLabel
@onready var shield_outline: Panel = $HPBar/ShieldOutline
@onready var selection_indicator: Line2D = $SelectionIndicator

func _ready():
	parent_character = get_parent() as CharacterBody2D
	if not parent_character:
		queue_free()
		return

	selection_indicator.points = _hexagon(75.0)
	selection_indicator.closed = true
	selection_indicator.z_index = 5
	selection_indicator.antialiased = true
	hp_bar.z_index = 10
	hp_fill.z_index = 11

	var shield_style = StyleBoxFlat.new()
	shield_style.draw_center = false
	shield_style.border_width_left = 6
	shield_style.border_width_top = 6
	shield_style.border_width_right = 6
	shield_style.border_width_bottom = 6
	shield_style.border_color = Color(1, 1, 1, 1.0)
	shield_style.corner_radius_top_left = 2
	shield_style.corner_radius_top_right = 2
	shield_style.corner_radius_bottom_left = 2
	shield_style.corner_radius_bottom_right = 2
	shield_outline.add_theme_stylebox_override("panel", shield_style)

	refresh()

func _hexagon(radius: float) -> PackedVector2Array:
	var w = radius * sqrt(3) / 2.0
	var h = radius
	return PackedVector2Array([
		Vector2(0, -h),
		Vector2(w, -h / 2.0),
		Vector2(w, h / 2.0),
		Vector2(0, h),
		Vector2(-w, h / 2.0),
		Vector2(-w, -h / 2.0),
	])

func refresh():
	if not parent_character or not is_inside_tree():
		return
	_update_hp()
	_update_shield()

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
			selection_indicator.visible = true
			selection_indicator.default_color = Color(1, 1, 0, 0.8)
			_start_pulse()
		else:
			selection_indicator.visible = false
			if pulse_tween:
				pulse_tween.kill()
			selection_indicator.default_color.a = 0.8

func _start_pulse():
	if pulse_tween:
		pulse_tween.kill()
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(selection_indicator, "default_color:a", 0.8, 0.5)
	pulse_tween.tween_property(selection_indicator, "default_color:a", 0.5, 0.5)
