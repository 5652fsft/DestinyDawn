extends "res://Characters/BaseCharacter.gd"

var active_skill: BaseSkill
var passive_skill: BaseSkill

var last_target_hp: int = -1
var last_target_max_hp: int = -1

func _ready():
	max_hp = 55
	hp = 55
	super()
	character_name = "希儿"
	hp = 55
	move_points = 6
	attack = 18

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
	if not target or not target is CharacterBody2D:
		return
	if get_current_phase() != "Attack":
		return
	
	last_target_hp = target.hp
	last_target_max_hp = target.max_hp

	var dmg = effective_attack
	if last_target_max_hp > 0 and last_target_hp >= last_target_max_hp:
		dmg = int(dmg * 1.5)

	target.rpc("take_damage", dmg)
	print("[Combat] %s → %s 造成 %d 点伤害（暗影突袭）" % [name, target.name, dmg])
	rpc_id(0, "_play_attack_animation", target_path)

func use_active_skill(target: Node) -> bool:
	return SkillEffect.execute_active(self, active_skill, target, main)
