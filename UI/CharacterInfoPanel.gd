extends Panel

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")

@onready var name_label = $ScrollContainer/VBox/NameLabel
@onready var action_label = $ScrollContainer/VBox/ActionLabel
@onready var hp_label = $ScrollContainer/VBox/HPLabel
@onready var attack_label = $ScrollContainer/VBox/AttackLabel
@onready var move_label = $ScrollContainer/VBox/MovePointsLabel
@onready var attack_range_label = $ScrollContainer/VBox/AttackRangeLabel
@onready var shield_label = $ScrollContainer/VBox/ShieldLabel

@onready var buffs_container = $ScrollContainer/VBox/BuffsContainer

@onready var passive_header = $ScrollContainer/VBox/PassiveHeader
@onready var passive_label = $ScrollContainer/VBox/PassiveLabel
@onready var passive_panel = $ScrollContainer/VBox/PassiveSkillPanel

var current_character: Node = null

func _ready():
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.15, 0.85)
	add_theme_stylebox_override("panel", bg)
	passive_panel.get_node("VBoxContainer/UseButton").hide()

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

	var atk_used = GlobalGameData.character_attack_used.get(current_character.name, false)
	var extra = current_character._get_extra_attacks() if current_character.has_method("_get_extra_attacks") else 0
	var remaining = (0 if atk_used else 1) + extra
	action_label.text = "剩余行动: %d" % remaining

	hp_label.text = "生命值: %d / %d" % [current_character.hp, current_character.max_hp]

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
		passive_panel.get_node("VBoxContainer/SkillNameLabel").text = ps.skill_name
		passive_panel.get_node("VBoxContainer/SkillDescLabel").text = ps.description
		passive_panel.get_node("VBoxContainer/CooldownLabel").hide()
		passive_panel.get_node("VBoxContainer/UseButton").hide()
		passive_header.show()
		passive_label.show()
		passive_panel.show()
	else:
		passive_header.hide()
		passive_label.hide()
		passive_panel.hide()

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
			label.text = _buff_desc(key, entry)
			buffs_container.add_child(label)

func _buff_desc(key: String, entry: Dictionary) -> String:
	var dur = entry.get("remaining", 0)
	var val = entry.get("value", 0)
	match key:
		"attack_buff":
			return "[攻击强化] 攻击力+%d（%d回合）" % [val, dur]
		"attack_debuff":
			return "[虚弱] 攻击力-%d（%d回合）" % [val, dur]
		"move_debuff":
			return "[迟缓] 移动力-%d（%d回合）" % [val, dur]
		"defense_buff":
			var abs_val = abs(val)
			if val > 0:
				return "[防御] 受到伤害 -%d（%d回合）" % [abs_val, dur]
			else:
				return "[易伤] 受到伤害 +%d（%d回合）" % [abs_val, dur]
		"poison":
			return "[中毒] 每回合-%d生命（%d回合）" % [val, dur]
		"burn":
			return "[灼烧] 每回合-%d生命（%d回合）" % [val, dur]
		"regen":
			return "[再生] 每回合恢复+%d生命（%d回合）" % [val, dur]
		"mark":
			return "[标记] 受伤加深+%d%%（%d回合）" % [val, dur]
		"extra_move":
			return "[加速] 移动力+%d（%d回合）" % [val, dur]
		"taunt":
			return "[嘲讽] 强制攻击（%d回合）" % [dur]
		"bloodthirst":
			return "[嗜血成性] 攻击力+%d%%（%d回合）" % [val, dur]
	return "%s %d（%d回合）" % [key, val, dur]

func _on_CloseButton_pressed():
	_disconnect_buffs()
	hide()
	current_character = null
