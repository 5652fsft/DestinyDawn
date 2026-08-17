extends Panel

@export var player_side: String = "Host"

@onready var player_name_label: Label = $VBoxContainer/PlayerName
@onready var turn_highlight: ColorRect = $TurnHighlight
@onready var energy_dots: HBoxContainer = $VBoxContainer/FactionRow/EnergyDots

func _ready():
	refresh_name()

	for dot in energy_dots.get_children():
		var style = StyleBoxFlat.new()
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		if dot is ColorRect:
			dot.add_theme_stylebox_override("panel", style)

	var effective_host = GlobalGameData.is_host
	if not multiplayer.has_multiplayer_peer():
		effective_host = true
	var is_local = (player_side == "Host") == effective_host
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.2, 1.0) if is_local else Color(0.2, 0.1, 0.1, 1.0)
	bg.corner_radius_top_left = 8
	bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_left = 8
	bg.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", bg)

	var blink_tween = create_tween().set_loops()
	blink_tween.tween_property(turn_highlight, "modulate:a", 0.0, 1.5)
	blink_tween.tween_property(turn_highlight, "modulate:a", 1.0, 1.5)

func refresh_name():
	var is_local = (player_side == "Host") == GlobalGameData.is_host
	if is_local:
		player_name_label.text = GlobalGameData.player_name
	else:
		player_name_label.text = GlobalGameData.opponent_name

func refresh(is_my_turn: bool, energy: int = -1):
	turn_highlight.visible = is_my_turn
	if energy >= 0:
		var is_local = (player_side == "Host") == GlobalGameData.is_host
		var full_color = Color(0.3, 0.5, 1.0, 1.0) if is_local else Color(1.0, 0.3, 0.3, 1.0)
		var empty_color = Color(0.2, 0.2, 0.3, 1.0)
		for i in range(energy_dots.get_child_count()):
			var dot = energy_dots.get_child(i)
			if dot is ColorRect:
				dot.color = full_color if i < energy else empty_color
