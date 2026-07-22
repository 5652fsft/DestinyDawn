extends "res://Characters/BaseCharacter.gd"

var active_skill: BaseSkill
var passive_skill: BaseSkill

func _ready():
	var _cd = CharacterData.get_data("zephyr")
	max_hp = _cd.hp
	attack_sfx = "attack_largesword"
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
	active_skill.cooldown = 0
	active_skill.skill_range = 0
	active_skill.target_type = BaseSkill.SkillTarget.SELF
	active_skill.is_passive = false

func use_active_skill(target: Node) -> bool:
	return SkillEffect.execute_active(self, active_skill, target, main)

func _consumes_attack_on_skill() -> bool:
	return false

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
	var bonus = int((max_hp - hp) * 0.6)
	var total_damage = effective_attack + bonus
	if main:
		main.last_attacker = self
	target.take_damage(total_damage)
	print("[Passive] Zephyr [血煞逆锋] 造成 %d 点伤害（基础 %d + 已损 %d HP × 40%%）" % [total_damage, effective_attack, max_hp - hp])
	rpc_id(0, "_play_attack_animation", target_path)

@rpc("any_peer", "call_local", "reliable")
func take_damage(damage: int):
	if damage > 0 and buff_manager:
		var ascend_val = buff_manager.get_total(self, "ascend")
		if ascend_val > 0:
			var reduction = clamp(ascend_val, 0, 20)
			damage = max(1, damage * (100 - reduction) / 100)
			print("[Buff] Zephyr [攀升] 减免 %d%% 伤害" % reduction)
	super(damage)
