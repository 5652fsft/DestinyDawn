extends "res://Characters/BaseCharacter.gd"

var active_skill: BaseSkill
var passive_skill: BaseSkill

var last_target_hp: int = -1
var last_target_max_hp: int = -1

func _ready():
	var _cd = CharacterData.get_data("seele")
	max_hp = _cd.hp
	super()
	character_name = _cd.name
	hp = _cd.hp
	move_points = _cd.move
	attack = _cd.atk

	passive_skill = BaseSkill.new()
	passive_skill.skill_name = _cd.passive
	passive_skill.description = _cd.passive_desc
	passive_skill.is_passive = true

	active_skill = BaseSkill.new()
	active_skill.skill_name = _cd.skill
	active_skill.description = _cd.skill_desc
	active_skill.cooldown = 3
	active_skill.skill_range = 10
	active_skill.target_type = BaseSkill.SkillTarget.ENEMY_SINGLE
	active_skill.is_passive = false

@rpc("any_peer", "call_local", "reliable")
func perform_attack(target_path: NodePath):
	var target = get_node_or_null(target_path)
	if not target or not target is CharacterBody2D:
		return
	if get_current_phase() != "Active":
		return
	
	last_target_hp = target.hp
	last_target_max_hp = target.max_hp

	var dmg = effective_attack
	if last_target_max_hp > 0 and last_target_hp >= last_target_max_hp:
		dmg = int(dmg * 1.5)

	target.take_damage_safe(dmg)
	print("[Combat] %s → %s 造成 %d 点伤害（暗影突袭）" % [_char_label(self), _char_label(target), dmg])
	if multiplayer.has_multiplayer_peer():
		rpc_id(0, "_play_attack_animation", target_path)
	else:
		_play_attack_animation(target_path)

func use_active_skill(target: Node) -> bool:
	return SkillEffect.execute_active(self, active_skill, target, main)
