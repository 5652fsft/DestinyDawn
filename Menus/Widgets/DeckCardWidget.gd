extends Panel

const FONT = preload("res://Assets/Fronts/SourceHanSerifCN-Heavy-4.otf")

var card_id: String = ""

signal added(cid: String)
signal removed(cid: String)

func setup(id: String, name_text: String, cost_text: String, type_text: String):
	card_id = id
	$NameLabel.text = name_text
	$CostLabel.text = cost_text
	$TypeLabel.text = type_text
	for c in get_children():
		if c is Label:
			c.add_theme_font_override("font", FONT)

func set_pool_mode(in_deck: bool, count: int = 0):
	$AddButton.visible = not in_deck
	$RemoveButton.visible = false
	$CountLabel.text = "" if count == 0 else "x%d" % count
	$CountLabel.show()

func set_deck_mode():
	$AddButton.visible = false
	$RemoveButton.visible = true
	$CountLabel.hide()

func _on_add_pressed():
	added.emit(card_id)

func _on_remove_pressed():
	removed.emit(card_id)
