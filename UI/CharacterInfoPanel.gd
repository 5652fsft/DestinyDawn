extends Panel

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")

@onready var name_label = $ScrollContainer/VBox/NameLabel
@onready var action_label = $ScrollContainer/VBox/ActionLabel
@onready var hp_label = $ScrollContainer/VBox/HPLabel
@onready var attack_label = $ScrollContainer/VBox/AttackLabel
@onready var move_label = $ScrollContainer/VBox/MovePointsLabel
@onready var attack_range_label = $ScrollContainer/VBox/AttackRangeLabel
@onready var shield_label = $ScrollContainer/VBox/ShieldLabel
@onready var buff_header = $ScrollContainer/VBox/BuffHeader
@onready var buff_label = $ScrollContainer/VBox/BuffLabel
@onready var buffs_container = $ScrollContainer/VBox/BuffsContainer

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
	var main_node = get_tree().current_scene
	var viewing_enemy = main_node.is_viewing_enemy if main_node else false

	if viewing_enemy:
		name_label.text = "敌方·%s" % current_character.character_name
		modulate = Color(1.0, 0.85, 0.85)
	else:
		name_label.text = current_character.character_name
		modulate = Color(1, 1, 1)

	var atk_used = GlobalGameData.character_attack_used.get(current_character.name, false)
	var extra = current_character._get_extra_attacks() if current_character.has_method("_get_extra_attacks") else 0
	var remaining = (0 if atk_used else 1) + extra

	var move_pts = current_character.effective_move_points if "effective_move_points" in current_character else current_character.move_points
	var move_used = GlobalGameData.character_move_used.get(current_character.name, false)
	var move_remaining = 0 if move_used else 1

	action_label.text = "剩余行动: %d | 移动: %d" % [remaining, move_remaining]

	hp_label.text = "生命值: %d / %d" % [current_character.hp, current_character.max_hp]

	var base_atk = current_character.attack
	var buffed_atk = current_character.effective_attack if "effective_attack" in current_character else base_atk
	if buffed_atk != base_atk:
		var diff = buffed_atk - base_atk
		var sign = "+" if diff > 0 else ""
		var color = "green" if diff > 0 else "red"
		attack_label.text = "攻击力: %d  [color=%s]%s%d[/color]" % [base_atk, color, sign, diff]
	else:
		attack_label.text = "攻击力: %d" % base_atk

	move_label.text = "移动范围: %d" % move_pts

	var atk_range = current_character.attack_range if "attack_range" in current_character else 1
	attack_range_label.text = "攻击范围: %d" % atk_range

	if "shield" in current_character and current_character.shield > 0:
		shield_label.show()
		shield_label.text = "护盾: %d" % current_character.shield
	else:
		shield_label.hide()

	_update_buffs()

func _update_buffs():
	for child in buffs_container.get_children():
		child.queue_free()
	if not current_character or not "buffs" in current_character or current_character.buffs.is_empty():
		var placeholder = RichTextLabel.new()
		placeholder.add_theme_font_size_override("normal_font_size", 14)
		placeholder.add_theme_font_override("normal_font", FONT)
		placeholder.bbcode_enabled = true
		placeholder.text = "暂无效果"
		placeholder.modulate = Color(1, 1, 1, 0.5)
		placeholder.fit_content = true
		placeholder.scroll_active = false
		buffs_container.add_child(placeholder)
		buff_header.hide()
		buff_label.hide()
		return
	buff_header.show()
	buff_label.show()
	for key in current_character.buffs:
		var list = current_character.buffs[key]
		for entry in list:
			var rtl = RichTextLabel.new()
			rtl.add_theme_font_size_override("normal_font_size", 14)
			rtl.add_theme_font_override("normal_font", FONT)
			rtl.bbcode_enabled = true
			rtl.text = _buff_desc(key, entry)
			rtl.fit_content = true
			rtl.scroll_active = false
			buffs_container.add_child(rtl)

func _buff_desc(key: String, entry: Dictionary) -> String:
	var dur = entry.get("remaining", 0)
	var val = entry.get("value", 0)
	match key:
		"attack_buff":
			return "[color=#668c66][攻击强化][/color] 攻击力+%d（%d回合）" % [val, dur]
		"attack_debuff":
			return "[color=#994d4d][虚弱][/color] 攻击力-%d（%d回合）" % [val, dur]
		"move_debuff":
			return "[color=#8c6640][迟缓][/color] 移动力-%d（%d回合）" % [val, dur]
		"defense_buff":
			var abs_val = abs(val)
			if val > 0:
				return "[color=#59668c][防御][/color] 受到伤害 -%d（%d回合）" % [abs_val, dur]
			else:
				return "[color=#994d4d][易伤][/color] 受到伤害 +%d（%d回合）" % [abs_val, dur]
		"poison":
			return "[color=#804040][中毒][/color] 每回合-%d生命（%d回合）" % [val, dur]
		"burn":
			return "[color=#804040][灼烧][/color] 每回合-%d生命（%d回合）" % [val, dur]
		"regen":
			return "[color=#598060][再生][/color] 每回合恢复+%d生命（%d回合）" % [val, dur]
		"mark":
			return "[color=#734d80][标记][/color] 受伤加深+%d%%（%d回合）" % [val, dur]
		"extra_move":
			return "[color=#4d808c][加速][/color] 移动力+%d（%d回合）" % [val, dur]
		"taunt":
			return "[color=#8c804d][嘲讽][/color] 强制攻击（%d回合）" % [dur]
		"magic_flow":
			return "[color=#668066][魔力充盈][/color] 攻击力+%d%%（%d回合）" % [val, dur]
		"bloodthirst":
			return "[color=#805959][嗜血成性][/color] 攻击力+%d%%（%d回合）" % [val, dur]
	return "%s %d（%d回合）" % [key, val, dur]

func _on_CloseButton_pressed():
	_disconnect_buffs()
	hide()
	current_character = null
