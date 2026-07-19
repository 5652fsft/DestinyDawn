extends "res://Characters/BaseCharacter.gd"

var active_skill: BaseSkill
var passive_skill: BaseSkill

func _ready():
	max_hp = 80
	super()
	character_name = "布洛妮娅"
	hp = 80
	move_points = 3
	attack = 15

	passive_skill = BaseSkill.new()
	passive_skill.skill_name = "铁壁"
	passive_skill.description = "受到伤害 -20%（HP<50% 时 -35%）"
	passive_skill.is_passive = true

	active_skill = BaseSkill.new()
	active_skill.skill_name = "护卫指令"
	active_skill.description = "为友方提供 30 点护盾"
	active_skill.cooldown = 3
	active_skill.target_type = BaseSkill.SkillTarget.ALLY_SINGLE
	active_skill.is_passive = false

@rpc("any_peer", "call_local", "reliable")
func take_damage(damage: int):
	var modified = SkillEffect.get_passive_modifier(self, "incoming_damage", damage)
	super(modified)

func use_active_skill(target: Node) -> bool:
	return SkillEffect.execute_active(self, active_skill, target, main)
