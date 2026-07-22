extends Panel

func _ready():
	var overlay = StyleBoxFlat.new()
	overlay.bg_color = Color(0, 0, 0, 0.7)
	add_theme_stylebox_override("panel", overlay)

	# Card 全透明
	var card_bg = StyleBoxFlat.new()
	card_bg.bg_color = Color(0, 0, 0, 0)
	$Card.add_theme_stylebox_override("panel", card_bg)

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
