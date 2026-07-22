extends Panel

func _ready():
	var overlay = StyleBoxFlat.new()
	overlay.bg_color = Color(0, 0, 0, 0.7)
	add_theme_stylebox_override("panel", overlay)

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.13, 0.18, 0.95)
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_color = Color(0.3, 0.32, 0.35, 0.6)
	card_style.corner_radius_top_left = 12
	card_style.corner_radius_top_right = 12
	card_style.corner_radius_bottom_left = 12
	card_style.corner_radius_bottom_right = 12
	card_style.shadow_size = 8
	card_style.shadow_color = Color(0, 0, 0, 0.5)
	card_style.shadow_offset = Vector2(0, 4)
	$Card.add_theme_stylebox_override("panel", card_style)

	ButtonTheme.apply_menu($Card/VBox/HBox/ConfirmButton)
	ButtonTheme.set_font($Card/VBox/HBox/ConfirmButton, 22)
	ButtonTheme.apply_menu($Card/VBox/HBox/CancelButton)
	ButtonTheme.set_font($Card/VBox/HBox/CancelButton, 22)

func _on_confirm_pressed():
	var main = get_tree().current_scene
	if main and main.has_method("_confirm_surrender"):
		main._confirm_surrender()

func _on_cancel_pressed():
	hide()
