extends Panel

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

func _on_confirm_pressed():
	var main = get_tree().current_scene if get_tree() else null
	if main and main.has_method("_confirm_surrender"):
		main._confirm_surrender()

# 手牌记忆与恢复统一由 main 的 _show/_hide_surrender_dialog 管理（ESC 与取消共用同一路径）
func _on_cancel_pressed():
	var main = get_tree().current_scene if get_tree() else null
	if main and main.has_method("_hide_surrender_dialog"):
		main._hide_surrender_dialog()
	else:
		hide()