extends "res://Characters/BaseCharacter.gd"

var active_skill: BaseSkill
var passive_skill: BaseSkill
var _extra_attacks: int = 0

func _ready():
	max_hp = 48
	super()
	character_name = "芝士仓鼠"
	hp = 48
	attack = 26
	attack_range = 3
	move_points = 6

	passive_skill = BaseSkill.new()
	passive_skill.skill_name = "钢铁直架"
	passive_skill.description = "消灭敌方后获得1次额外行动，攻击力+50%（可叠加3层）"
	passive_skill.is_passive = true

	active_skill = BaseSkill.new()
	active_skill.skill_name = "动作如潮"
	active_skill.description = "立即获得 1 次额外行动"
	active_skill.cooldown = 3
	active_skill.skill_range = 0
	active_skill.target_type = BaseSkill.SkillTarget.SELF
	active_skill.is_passive = false

func use_active_skill(target: Node) -> bool:
	return SkillEffect.execute_active(self, active_skill, target, main)

func _consumes_attack_on_skill() -> bool:
	return false

func _get_extra_attacks() -> int:
	return _extra_attacks

func _consume_extra_attack():
	_extra_attacks -= 1

func perform_attack(target_path: NodePath):
	super(target_path)
	var target = get_node_or_null(target_path)
	if target and target.hp <= 0 and not target.visible and main and main.buff_manager:
		_extra_attacks += 1
		main.buff_manager.apply_buff(self, "bloodthirst", 50, 2, self)
		print("[Skill] %s [钢铁直架] 击杀获得1次额外行动，1层嗜血成性" % character_name)
