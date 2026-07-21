extends "res://Characters/BaseCharacter.gd"

var active_skill: BaseSkill
var passive_skill: BaseSkill

func _ready():
	max_hp = 60
	super()
	character_name = "伊蕾娜"
	hp = 60
	attack = 20
	attack_range = 3
	move_points = 5

	passive_skill = BaseSkill.new()
	passive_skill.skill_name = "魔力共鸣"
	passive_skill.description = "使用攻击/减益卡牌时，获得一层 [魔力充盈]，攻击力 +15%，最多可叠加 3 层"
	passive_skill.is_passive = true

	active_skill = BaseSkill.new()
	active_skill.skill_name = "星尘爆裂"
	active_skill.description = "对 6 格范围内目标及周围 1 格敌人造成 35 点伤害"
	active_skill.cooldown = 4
	active_skill.skill_range = 6
	active_skill.target_type = BaseSkill.SkillTarget.ENEMY_SINGLE
	active_skill.is_passive = false

func use_active_skill(target: Node) -> bool:
	return SkillEffect.execute_active(self, active_skill, target, main)
