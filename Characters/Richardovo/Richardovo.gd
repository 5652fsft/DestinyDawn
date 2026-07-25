extends "res://Characters/BaseCharacter.gd"

var active_skill: BaseSkill
var passive_skill: BaseSkill

func _ready():
	var _cd = CharacterData.get_data("Richardovo")
	max_hp = _cd.hp
	super()
	character_name = _cd.name
	hp = _cd.hp
	move_points = _cd.move
	attack = _cd.atk
	attack_range = _cd.range
	attack_sfx = "attack_sword"

	passive_skill = BaseSkill.new()
	passive_skill.skill_name = _cd.passive
	passive_skill.description = _cd.passive_desc
	passive_skill.is_passive = true

	active_skill = BaseSkill.new()
	active_skill.skill_name = _cd.skill
	active_skill.description = _cd.skill_desc
	active_skill.cooldown = 2
	active_skill.skill_range = 0
	active_skill.target_type = BaseSkill.SkillTarget.SELF
	active_skill.is_passive = false

func use_active_skill(target: Node) -> bool:
	return SkillEffect.execute_active(self, active_skill, target, main)

func _consumes_attack_on_skill() -> bool:
	return false

func on_turn_start():
	var is_my_team_host = self in GlobalGameData.host_characters
	var is_enemy_phase = GlobalGameData.current_turn_phase == GlobalGameData.TurnPhase.ENEMY_TURN
	if (GlobalGameData.is_host_turn == is_my_team_host) == is_enemy_phase:
		print("[Passive] %s [闭麦] 跳过（不是己方回合，host=%s, phase=%d）" % [GlobalGameData.get_char_label(self), is_my_team_host, GlobalGameData.current_turn_phase])
		return
	var bm = main.buff_manager if main else null
	if not bm:
		print("[Passive] %s [闭麦] 跳过（buff_manager 为空）" % GlobalGameData.get_char_label(self))
		return
	if buffs.keys().size() == 0:
		bm.apply_buff(self, "solo_leveling", 20, 1, self)
		print("[Passive] %s [闭麦] 获得 [我独自升级]，伤害 +20%%" % GlobalGameData.get_char_label(self))
	else:
		print("[Passive] %s [闭麦] 已有 %d 个效果，跳过" % [GlobalGameData.get_char_label(self), buffs.keys().size()])
