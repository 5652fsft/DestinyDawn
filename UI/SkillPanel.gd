extends Panel

var current_character: Node = null
var active_skill: BaseSkill = null

signal skill_used(skill: BaseSkill, target_type: int)

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
	skill_desc_label.text = active_skill.description
	_update_cooldown()
	show()

func _update_cooldown():
	if not active_skill:
		return
	var cd = active_skill.cooldown
	cooldown_label.text = "冷却: %d 回合" % cd if cd > 0 else "就绪"
	use_button.disabled = cd > 0

func _on_use_button_pressed():
	if not active_skill:
		return
	skill_used.emit(active_skill, active_skill.target_type)
