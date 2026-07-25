extends BaseCharacter

var active_skill: BaseSkill
var passive_skill: BaseSkill

func _ready():
	var _cd = CharacterData.get_data("hamster")
	max_hp = _cd.hp
	super()
	character_name = _cd.name
	hp = _cd.hp
	attack = _cd.atk
	attack_range = _cd.range
	move_points = _cd.move
	attack_sfx = "attack_gun"

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

func _consumes_attack_on_skill() -> bool:
	return false

func _get_extra_attacks() -> int:
	return _extra_attacks

func _consume_extra_attack():
	_extra_attacks -= 1

@rpc("any_peer", "call_local", "reliable")
func perform_attack(target_path: NodePath):
	super(target_path)
	var target = get_node_or_null(target_path)
	if target and target.hp <= 0 and not target.visible and main and main.buff_manager:
		_extra_attacks += 1
		main.buff_manager.apply_buff(self, "bloodthirst", 50, 2, self)
		print("[Skill] %s [钢铁直架] 击杀获得1次额外行动，1层嗜血成性" % GlobalGameData.get_char_label(self))
