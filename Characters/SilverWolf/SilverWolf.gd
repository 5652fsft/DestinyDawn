extends "res://Characters/BaseCharacter.gd"

var active_skill: BaseSkill
var passive_skill: BaseSkill

func _ready():
	var _cd = CharacterData.get_data("silverwolf")
	max_hp = _cd.hp
	super()
	character_name = _cd.name
	hp = _cd.hp
	move_points = _cd.move
	attack_range = _cd.range
	attack = _cd.atk
	attack_sfx = "attack_digital"

	passive_skill = BaseSkill.new()
	passive_skill.skill_name = _cd.passive
	passive_skill.description = _cd.passive_desc
	passive_skill.is_passive = true

	active_skill = BaseSkill.new()
	active_skill.skill_name = _cd.skill
	active_skill.description = _cd.skill_desc
	active_skill.cooldown = 4
	active_skill.skill_range = 0
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
