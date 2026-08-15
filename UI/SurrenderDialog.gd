extends Panel

var _hand_was_hidden: bool = false
var _hiding_hand: bool = false

func _ready():
	var overlay = StyleBoxFlat.new()
	overlay.bg_color = Color(0.08, 0.08, 0.12, 0.8)
	add_theme_stylebox_override("panel", overlay)

	var card_bg = StyleBoxFlat.new()
	card_bg.bg_color = Color(0, 0, 0, 0)
	$Card.add_theme_stylebox_override("panel", card_bg)

	ButtonTheme.apply_menu($Card/VBox/HBox/ConfirmButton)
	ButtonTheme.set_font($Card/VBox/HBox/ConfirmButton, 22)
	ButtonTheme.apply_menu($Card/VBox/HBox/CancelButton)
	ButtonTheme.set_font($Card/VBox/HBox/CancelButton, 22)

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and not _hiding_hand:
		_hiding_hand = true
		var main = get_tree().current_scene if get_tree() else null
		if main and main.has_method("_hide_hand"):
			_hand_was_hidden = "_hand_hidden" in main and main._hand_hidden
			if not _hand_was_hidden:
				main._hide_hand()
		_hiding_hand = false

func _on_confirm_pressed():
	var main = get_tree().current_scene if get_tree() else null
	if main and main.has_method("_confirm_surrender"):
		main._confirm_surrender()

func _on_cancel_pressed():
	if not _hand_was_hidden:
		var main = get_tree().current_scene if get_tree() else null
		if main and "_hand_hidden" in main:
			main._hand_hidden = false
			var hand = main.get_node_or_null("UI/HandPanel")
			if hand: hand.show()
	var main = get_tree().current_scene if get_tree() else null
	if main and main.has_method("_hide_surrender_dialog"):
		main._hide_surrender_dialog()
	else:
		hide()
