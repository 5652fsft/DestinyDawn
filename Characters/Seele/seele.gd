extends "res://Characters/BaseCharacter.gd"

var active_skill: BaseSkill
var passive_skill: BaseSkill

var last_target_hp: int = -1
var last_target_max_hp: int = -1

func _ready():
	super()
	character_name = "希儿"
	hp = 90
	max_hp = 90
	move_points = 5

	passive_skill = BaseSkill.new()
	passive_skill.skill_name = "暗影突袭"
	passive_skill.description = "攻击满血敌人时伤害 +50%"
	passive_skill.is_passive = true

	active_skill = BaseSkill.new()
	active_skill.skill_name = "相位突进"
	active_skill.description = "瞬移至目标旁并发动一次强化攻击"
	active_skill.cooldown = 3
	active_skill.target_type = BaseSkill.SkillTarget.ENEMY_SINGLE
	active_skill.is_passive = false

@rpc("any_peer", "call_local", "reliable")
func perform_attack(target_path: NodePath):
	var target = get_node_or_null(target_path)
	if target and target is CharacterBody2D:
		last_target_hp = target.hp
		last_target_max_hp = target.max_hp
	super(target_path)

func use_active_skill(target: Node) -> bool:
	return SkillEffect.execute_active(self, active_skill, target, main)
