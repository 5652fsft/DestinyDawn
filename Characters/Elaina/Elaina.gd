extends "res://Characters/BaseCharacter.gd"

var active_skill: BaseSkill
var passive_skill: BaseSkill
var magic_combo: int = 0

func _ready():
	max_hp = 60
	super()
	character_name = "伊蕾娜"
	hp = 60
	attack = 20
	attack_range = 3
	move_points = 3
	affinity = { attack_bonus = 0.15, heal_bonus = 0.0, shield_bonus = 0.0, debuff_bonus = 0.0 }

	passive_skill = BaseSkill.new()
	passive_skill.skill_name = "魔力共鸣"
	passive_skill.description = "连续使用攻击/减益卡时每张伤害+15%（最多3层）"
	passive_skill.is_passive = true

	active_skill = BaseSkill.new()
	active_skill.skill_name = "星尘爆裂"
	active_skill.description = "对目标及周围1格敌人造成35点伤害"
	active_skill.cooldown = 4
	active_skill.target_type = BaseSkill.SkillTarget.ENEMY_SINGLE
	active_skill.is_passive = false

func use_active_skill(target: Node) -> bool:
	return SkillEffect.execute_active(self, active_skill, target, main)
