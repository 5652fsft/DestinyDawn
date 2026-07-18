extends Panel

const FONT = preload("res://Assets/Fronts/SourceHanSerifCN-Heavy-4.otf")

var current_character: Node = null
var active_skill: BaseSkill = null
var _targeting: bool = false

signal skill_used(skill: BaseSkill, target_type: int)
signal skill_cancelled()

@onready var skill_name_label = $VBoxContainer/SkillNameLabel
@onready var skill_desc_label = $VBoxContainer/SkillDescLabel
@onready var use_button = $VBoxContainer/UseButton
@onready var cooldown_label = $VBoxContainer/CooldownLabel

func _ready():
	use_button.pressed.connect(_on_use_button_pressed)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.15, 0.85)
	bg.content_margin_left = 20
	bg.content_margin_top = 16
	bg.content_margin_right = 20
	bg.content_margin_bottom = 16
	add_theme_stylebox_override("panel", bg)

func show_for(character: Node):
	current_character = character
	if not character or not "active_skill" in character:
		hide()
		return
	active_skill = character.active_skill
	if not active_skill:
		hide()
		return
	skill_name_label.text = active_skill.skill_name
	skill_name_label.add_theme_font_override("font", FONT)
	skill_desc_label.text = active_skill.description
	skill_desc_label.add_theme_font_override("font", FONT)
	cooldown_label.add_theme_font_override("font", FONT)
	_update_cooldown()
	_targeting = false
	use_button.text = "使用技能"
	show()

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
	if not _targeting:
		use_button.disabled = cd > 0

func _on_use_button_pressed():
	if not active_skill:
		return
	if _targeting:
		# 取消技能选择
		var main = get_tree().current_scene
		if main and main.has_method("cancel_targeting"):
			main.cancel_targeting()
		return
	skill_used.emit(active_skill, active_skill.target_type)
