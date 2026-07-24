extends Panel

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")

var current_character: Node = null
var active_skill: BaseSkill = null
var _targeting: bool = false

signal skill_used(skill: BaseSkill, target_type: int)
signal skill_cancelled()

@onready var passive_name_label = $VBoxContainer/PassiveNameLabel
@onready var passive_desc_label = $VBoxContainer/PassiveDescLabel
@onready var separator = $VBoxContainer/HSeparator
@onready var skill_name_label = $VBoxContainer/SkillNameLabel
@onready var skill_desc_label = $VBoxContainer/SkillDescLabel
@onready var use_button = $VBoxContainer/UseButton
@onready var cooldown_label = $VBoxContainer/CooldownLabel

func _ready():
	ButtonTheme.apply_menu(use_button)
	ButtonTheme.set_font(use_button, 18)
	use_button.pressed.connect(_on_use_button_pressed)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.15, 0.85)
	bg.content_margin_left = 12
	bg.content_margin_top = 12
	bg.content_margin_right = 12
	bg.content_margin_bottom = 12
	bg.corner_radius_top_left = 8
	bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_right = 8
	bg.corner_radius_bottom_left = 8
	add_theme_stylebox_override("panel", bg)
	mouse_filter = Control.MOUSE_FILTER_STOP

func show_for(character: Node):
	current_character = character
	if not character:
		hide()
		return

	var has_passive = "passive_skill" in character and character.passive_skill
	passive_name_label.visible = has_passive
	passive_desc_label.visible = has_passive
	separator.visible = has_passive
	if has_passive:
		var ps = character.passive_skill
		passive_name_label.text = "天赋·%s" % ps.skill_name
		passive_name_label.add_theme_font_override("font", FONT)
		passive_desc_label.text = ps.description
		passive_desc_label.add_theme_font_override("normal_font", FONT)

	var has_active = "active_skill" in character and character.active_skill
	skill_name_label.visible = has_active
	skill_desc_label.visible = has_active
	cooldown_label.visible = has_active
	use_button.visible = has_active
	if has_active:
		active_skill = character.active_skill
		skill_name_label.text = active_skill.skill_name
		skill_name_label.add_theme_font_override("font", FONT)
		skill_desc_label.text = active_skill.description
		skill_desc_label.add_theme_font_override("font", FONT)
		cooldown_label.add_theme_font_override("font", FONT)
		_targeting = false
		use_button.text = "使用技能"
		_update_cooldown()
	else:
		active_skill = null
	show()

func update_passive(chara):
	if "passive_skill" in chara and chara.passive_skill:
		var ps = chara.passive_skill
		passive_name_label.text = "天赋·%s" % ps.skill_name
		passive_desc_label.text = ps.description
		passive_name_label.visible = true
		passive_desc_label.visible = true
		separator.visible = true
	else:
		passive_name_label.visible = false
		passive_desc_label.visible = false
		separator.visible = false

func set_targeting_mode(active: bool):
	_targeting = active
	if active:
		use_button.text = "取消使用技能"
		use_button.disabled = false
	else:
		use_button.text = "使用技能"
		_update_cooldown()

func _update_cooldown():
	if not active_skill:
		return
	var cd = active_skill.current_cooldown
	cooldown_label.text = "冷却: %d 回合" % cd if cd > 0 else "就绪"
	if _targeting:
		return
	if cd > 0:
		use_button.disabled = true
		return
	# 技能阻挡检查（能量不足等）
	if current_character:
		var main = get_tree().current_scene
		if main:
			var reason = SkillEffect.get_skill_block_reason(current_character, main)
			if reason:
				use_button.disabled = true
				use_button.text = reason
				return
	if current_character and current_character.has_method("get_current_phase"):
		var phase = current_character.get_current_phase()
		if phase != "Active":
			use_button.disabled = true
			use_button.text = "不在当前回合"
			return
	if current_character and GlobalGameData.character_attack_used.get(current_character.name, false):
		if not current_character.has_method("_consumes_attack_on_skill") or current_character._consumes_attack_on_skill():
			use_button.disabled = true
			use_button.text = "本回合已行动"
			return
	use_button.disabled = false
	use_button.text = "使用技能"

func _on_use_button_pressed():
	if not active_skill:
		return
	if _targeting:
		var main = get_tree().current_scene
		if main and main.has_method("cancel_targeting"):
			main.cancel_targeting()
		return
	skill_used.emit(active_skill, active_skill.target_type)
