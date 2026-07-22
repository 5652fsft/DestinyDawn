extends RichTextLabel

func _gui_input(event):
	super._gui_input(event)
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP):
		accept_event()
