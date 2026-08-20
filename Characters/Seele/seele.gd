extends BaseCharacter

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
	attack_range = _cd.range

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
	if target.hp <= 0:
		return
	if get_current_phase() != "Active":
		return
	if GlobalGameData.character_attack_used.get(name, false) and _get_extra_attacks() <= 0:
		return
	last_target_hp = target.hp
	last_target_max_hp = target.max_hp

	var dmg = SkillEffect.get_passive_modifier(self, "outgoing_damage", effective_attack)

	if main:
		main.last_attacker = self
	target.take_damage(dmg)
	# 计数（守卫通过后）：优先消耗额外行动次数，无额外才占用基础次数（与基类一致，延迟到伤害结算后避免广播时序竞态）
	if _get_extra_attacks() > 0:
		_consume_extra_attack()
	elif not GlobalGameData.character_attack_used.get(name, false):
		GlobalGameData.character_attack_used[name] = true
		GlobalGameData.character_attack_used_num += 1
	print("[Combat] %s → %s 造成 %d 点伤害（暗影突袭）" % [GlobalGameData.get_char_label(self), GlobalGameData.get_char_label(target), dmg])
	if multiplayer.has_multiplayer_peer():
		rpc_id(0, "_play_attack_animation", target_path)
	else:
		_play_attack_animation(target_path)

func use_active_skill(target: Node) -> bool:
	return SkillEffect.execute_active(self, active_skill, target, main)
