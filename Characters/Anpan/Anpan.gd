extends "res://Characters/BaseCharacter.gd"

var active_skill: BaseSkill
var passive_skill: BaseSkill

func _ready():
	var _cd = CharacterData.get_data("anpan")
	max_hp = _cd.hp
	attack_sfx = "attack_magic"
	super()
	character_name = _cd.name
	hp = _cd.hp
	move_points = _cd.move
	attack = _cd.atk
	attack_range = _cd.range

	passive_skill = BaseSkill.new()
	passive_skill.skill_name = _cd.passive
	passive_skill.description = _cd.passive_desc
	passive_skill.is_passive = true

	active_skill = BaseSkill.new()
	active_skill.skill_name = _cd.skill
	active_skill.description = _cd.skill_desc
	active_skill.cooldown = 3
	active_skill.skill_range = 0
	active_skill.target_type = BaseSkill.SkillTarget.SELF
	active_skill.is_passive = false

func use_active_skill(target: Node) -> bool:
	return SkillEffect.execute_active(self, active_skill, target, main)

@rpc("any_peer", "call_local", "reliable")
func perform_attack(target_path: NodePath):
	super(target_path)
	var target = get_node_or_null(target_path)
	if not target:
		return
	if main and main.buff_manager and main.buff_manager.has_method("apply_buff"):
		main.buff_manager.apply_buff(target, "hot_burn", 5, 2, self)
		print("[Passive] あんパン [面包大家族] 对 %s 施加高温烫嘴" % target.name)
