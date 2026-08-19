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
		var main_node = get_tree().current_scene
		var last = main_node.get("last_attacker") if main_node else null
		# 仅存在有效攻击者时消耗"每回合首次受击"（卡牌/持续伤害无攻击者，不消耗触发机会）
		if last and last != self and is_instance_valid(last):
			_burn_armor_used = true
			if GlobalGameData.is_ai_mode or multiplayer.is_server():
				var d = CharacterData.get_data("firefly")
				# 被动 [燃烧装甲]：每回合首次受击必然反击灼烧（服务端权威，客户端经广播同步）
				if buff_manager:
					buff_manager.apply_buff(last, "burn", d["passive_buff_value"], d["passive_buff_duration"], self)
					print("[Skill] %s [燃烧装甲] → %s 灼烧 %d×%d回合" % [GlobalGameData.get_char_label(self), GlobalGameData.get_char_label(last), d["passive_buff_value"], d["passive_buff_duration"]])
	super(damage)

func use_active_skill(target: Node) -> bool:
	return SkillEffect.execute_active(self, active_skill, target, main)
