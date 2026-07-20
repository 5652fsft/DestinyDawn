extends "res://Characters/BaseCharacter.gd"

var active_skill: BaseSkill
var passive_skill: BaseSkill

func _ready():
	max_hp = 65
	super()
	character_name = "银狼"
	hp = 65
	move_points = 4
	attack_range = 2
	attack = 16

	passive_skill = BaseSkill.new()
	passive_skill.skill_name = "数据篡改"
	passive_skill.description = "攻击时50%概率附加随机减益"
	passive_skill.is_passive = true

	active_skill = BaseSkill.new()
	active_skill.skill_name = "系统入侵"
	active_skill.description = "目标虚弱+迟缓各3回合"
	active_skill.cooldown = 4
	active_skill.target_type = BaseSkill.SkillTarget.ENEMY_SINGLE
	active_skill.is_passive = false

@rpc("any_peer", "call_local", "reliable")
func perform_attack(target_path: NodePath):
	super(target_path)
	if randi() % 2 == 0:
		var target = get_node_or_null(target_path)
		if target and buff_manager:
			var debuff = "attack_debuff" if randi() % 2 == 0 else "move_debuff"
			var val = -5 if debuff == "attack_debuff" else -2
			buff_manager.apply_buff(target, debuff, val, 1, self)
			print("[Skill] %s [数据篡改] → %s %s" % [character_name, target.name, "虚弱" if debuff == "attack_debuff" else "迟缓"])

func use_active_skill(target: Node) -> bool:
	return SkillEffect.execute_active(self, active_skill, target, main)
