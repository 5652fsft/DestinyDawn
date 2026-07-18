extends Panel

@onready var name_label = $NameLabel
@onready var hp_label = $HPLabel
@onready var attack_label = $AttackLabel
@onready var move_label = $MovePointsLabel
@onready var shield_label = $ShieldLabel
@onready var buffs_container = $BuffsContainer

var current_character: Node = null

func show_for(character: Node):
	if not character:
		hide()
		return
	current_character = character
	refresh()
	show()

func refresh():
	if not current_character:
		return
	name_label.text = current_character.character_name
	hp_label.text = "HP: %d / %d" % [current_character.hp, current_character.max_hp]

	var base_atk = current_character.attack
	var buffed_atk = current_character.effective_attack if "effective_attack" in current_character else base_atk
	if buffed_atk != base_atk:
		var diff = buffed_atk - base_atk
		var sign = "+" if diff > 0 else ""
		var color = "green" if diff > 0 else "red"
		attack_label.text = "攻击: %d[color=%s]%s%d[/color]" % [base_atk, color, sign, diff]
	else:
		attack_label.text = "攻击: %d" % base_atk

	var move_pts = current_character.effective_move_points if "effective_move_points" in current_character else current_character.move_points
	move_label.text = "移动力: %d" % move_pts

	if "shield" in current_character and current_character.shield > 0:
		shield_label.show()
		shield_label.text = "护盾: %d" % current_character.shield
	else:
		shield_label.hide()

	_update_buffs()

func _update_buffs():
	for child in buffs_container.get_children():
		child.queue_free()
	if not current_character or not "buffs" in current_character:
		return
	var buf = current_character.buffs
	if buf.is_empty():
		return
	for key in buf:
		var entry = buf[key]
		var label = Label.new()
		label.add_theme_font_size_override("font_size", 18)
		label.text = _buff_desc(key, entry)
		buffs_container.add_child(label)

func _buff_desc(key: String, entry: Dictionary) -> String:
	var dur = entry.get("remaining", 0)
	var val = entry.get("value", 0)
	match key:
		"attack_buff":
			return "力量强化: 攻击 +%d（%d回合）" % [val, dur]
		"attack_debuff":
			return "虚弱: 攻击 %d（%d回合）" % [val, dur]
		"move_debuff":
			return "迟缓: 移动力 %d（%d回合）" % [val, dur]
		"defense_buff":
			return "防御强化（%d回合）" % dur
	return "%s（%d回合）" % [key, dur]

func _on_CloseButton_pressed():
	hide()
	current_character = null
