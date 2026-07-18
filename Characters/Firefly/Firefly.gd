extends "res://Characters/BaseCharacter.gd"

var active_skill: BaseSkill
var passive_skill: BaseSkill
var _burn_armor_used: bool = false

func _ready():
	max_hp = 130
	super()
	character_name = "流萤"
	hp = 130
	attack = 18
	attack_range = 1
	affinity = { attack_bonus = 0.0, heal_bonus = 0.0, shield_bonus = 0.25, debuff_bonus = 0.0 }

	passive_skill = BaseSkill.new()
	passive_skill.skill_name = "燃烧装甲"
	passive_skill.description = "每回合首次受击50%概率反击灼烧"
	passive_skill.is_passive = true

	active_skill = BaseSkill.new()
	active_skill.skill_name = "烈焰冲锋"
	active_skill.description = "造成25伤害并附加灼烧2回合"
	active_skill.cooldown = 3
	active_skill.target_type = BaseSkill.SkillTarget.ENEMY_SINGLE
	active_skill.is_passive = false

func take_damage(damage: int):
	if damage > 0 and not _burn_armor_used:
		_burn_armor_used = true
		if randi() % 2 == 0 and buff_manager:
			# find attacker — use the one who damaged us
			var main_node = get_tree().current_scene
			var last = main_node.get("last_attacker") if main_node else null
			if last:
				buff_manager.apply_buff(last, "burn", 5, 2, self)
				print("[Skill] %s [燃烧装甲] → %s 灼烧 5×2回合" % [character_name, last.name])
	super(damage)

func use_active_skill(target: Node) -> bool:
	return SkillEffect.execute_active(self, active_skill, target, main)
