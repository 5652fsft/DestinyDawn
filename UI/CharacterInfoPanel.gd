extends Panel

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")

@onready var name_label = $NameLabel
@onready var hp_label = $HPLabel
@onready var attack_label = $AttackLabel
@onready var move_label = $MovePointsLabel
@onready var attack_range_label = $AttackRangeLabel
@onready var shield_label = $ShieldLabel
@onready var passive_label = $PassiveLabel
@onready var passive_desc_container = $PassiveDescContainer
@onready var buffs_container = $BuffsContainer

var current_character: Node = null

func _ready():
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.15, 0.85)
	add_theme_stylebox_override("panel", bg)

func show_for(character: Node):
	if not character:
		_disconnect_buffs()
		hide()
		current_character = null
		return
	if current_character:
		_disconnect_buffs()
	current_character = character
	if current_character.has_signal("buffs_changed"):
		current_character.buffs_changed.connect(refresh)
	refresh()
	show()

func _disconnect_buffs():
	if current_character and current_character.has_signal("buffs_changed") and current_character.buffs_changed.is_connected(refresh):
		current_character.buffs_changed.disconnect(refresh)

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
		attack_label.text = "攻击: %d  [color=%s]%s%d[/color]" % [base_atk, color, sign, diff]
	else:
		attack_label.text = "攻击: %d" % base_atk

	var move_pts = current_character.effective_move_points if "effective_move_points" in current_character else current_character.move_points
	move_label.text = "移动范围: %d" % move_pts

	var atk_range = current_character.attack_range if "attack_range" in current_character else 1
	attack_range_label.text = "攻击范围: %d" % atk_range

	if "shield" in current_character and current_character.shield > 0:
		shield_label.show()
		shield_label.text = "护盾: %d" % current_character.shield
	else:
		shield_label.hide()

	_update_passive()
	_update_buffs()

func _update_passive():
	if "passive_skill" in current_character and current_character.passive_skill:
		var ps = current_character.passive_skill
		passive_label.show()
		passive_label.text = "天赋: %s" % ps.skill_name
		_update_passive_desc(ps.description)
	else:
		passive_label.hide()
		_passive_desc_queue_free()

func _passive_desc_queue_free():
	for c in passive_desc_container.get_children():
		c.queue_free()

func _update_passive_desc(desc: String):
	_passive_desc_queue_free()
	var label = Label.new()
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_font_override("font", FONT)
	label.text = desc
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = 1
	passive_desc_container.add_child(label)

func _update_buffs():
	for child in buffs_container.get_children():
		child.queue_free()
	if not current_character or not "buffs" in current_character:
		return
	var buf = current_character.buffs
	if buf.is_empty():
		return
	for key in buf:
		var list = buf[key]
		for entry in list:
			var label = Label.new()
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_font_override("font", FONT)
			label.text = _buff_desc(key, entry, list.size())
			buffs_container.add_child(label)

func _buff_desc(key: String, entry: Dictionary, stacks: int = 1) -> String:
	var dur = entry.get("remaining", 0)
	var val = entry.get("value", 0)
	var stack_tag = " x%d" % stacks if stacks > 1 else ""
	match key:
		"attack_buff":
			return "力量强化 +%d%s（%d回合）" % [val, stack_tag, dur]
		"attack_debuff":
			return "虚弱 %d%s（%d回合）" % [val, stack_tag, dur]
		"move_debuff":
			return "迟缓 %d%s（%d回合）" % [val, stack_tag, dur]
		"defense_buff":
			return "铁壁%s（%d回合）" % [stack_tag, dur]
		"poison":
			return "中毒 %d%s（%d回合）" % [val, stack_tag, dur]
		"burn":
			return "灼烧 %d%s（%d回合）" % [val, stack_tag, dur]
		"regen":
			return "再生 +%d%s（%d回合）" % [val, stack_tag, dur]
		"mark":
			return "标记 +%d%%%s（%d回合）" % [val, stack_tag, dur]
		"extra_move":
			return "加速 +%d%s（%d回合）" % [val, stack_tag, dur]
		"taunt":
			return "嘲讽%s（%d回合）" % [stack_tag, dur]
	return "%s: %d%s（%d回合）" % [key, val, stack_tag, dur]

func _on_CloseButton_pressed():
	_disconnect_buffs()
	hide()
	current_character = null
