extends BaseCharacter

var active_skill: BaseSkill
var passive_skill: BaseSkill
var _burn_armor_used: bool = false

func _ready():
	var _cd = CharacterData.get_data("firefly")
	max_hp = _cd.hp
	super()
	character_name = _cd.name
	hp = _cd.hp
	attack = _cd.atk
	attack_range = _cd.range
	move_points = _cd.move

	passive_skill = BaseSkill.new()
	passive_skill.skill_name = _cd.passive
	passive_skill.description = _cd.passive_desc
	passive_skill.is_passive = true

	active_skill = BaseSkill.new()
	active_skill.skill_name = _cd.skill
	active_skill.description = _cd.skill_desc
	active_skill.cooldown = 3
	active_skill.skill_range = 6
	active_skill.target_type = BaseSkill.SkillTarget.ENEMY_SINGLE
	active_skill.is_passive = false

@rpc("any_peer", "call_local", "reliable")
func take_damage(damage: int):
	if damage > 0 and not _burn_armor_used:
		_burn_armor_used = true
		if randi() % 2 == 0 and buff_manager:
			# find attacker — use the one who damaged us
			var main_node = get_tree().current_scene
			var last = main_node.get("last_attacker") if main_node else null
			if last:
				buff_manager.apply_buff(last, "burn", 5, 2, self)
				print("[Skill] %s [燃烧装甲] → %s 灼烧 5×2回合" % [GlobalGameData.get_char_label(self), GlobalGameData.get_char_label(last)])
	super(damage)

func use_active_skill(target: Node) -> bool:
	return SkillEffect.execute_active(self, active_skill, target, main)
