extends BaseCharacter

var active_skill: BaseSkill
var passive_skill: BaseSkill
var _away_turns_left: int = 0

func _ready():
	var _cd = CharacterData.get_data("M1DorG")
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
	active_skill.cooldown = 4
	active_skill.skill_range = 0
	active_skill.target_type = BaseSkill.SkillTarget.SELF
	active_skill.is_passive = false

func use_active_skill(target: Node) -> bool:
	return SkillEffect.execute_active(self, active_skill, target, main)

func _consumes_attack_on_skill() -> bool:
	return false

func get_current_phase() -> String:
	if _away_turns_left > 0:
		return "Away"
	return super()

func _get_deselect_color() -> Color:
	return Color(0.5, 0.5, 0.5) if _away_turns_left > 0 else Color.WHITE

@rpc("any_peer", "call_local", "reliable")
func _sync_away_state(value: int):
	_away_turns_left = value
	var spr = get_node_or_null("Sprite2D")
	if spr:
		spr.modulate = Color(0.5, 0.5, 0.5) if value > 0 else Color.WHITE
	if has_signal("buffs_changed"):
		buffs_changed.emit()

@rpc("any_peer", "call_local", "reliable")
func perform_attack(target_path: NodePath):
	super(target_path)
	# 与基类守卫一致：目标/阶段/行动次数任一不满足则不触发被动
	var target = get_node_or_null(target_path)
	if not target or not target is CharacterBody2D or target.hp <= 0:
		return
	if get_current_phase() != "Active":
		return
	if GlobalGameData.character_attack_used.get(name, false) and _get_extra_attacks() <= 0:
		return
	# 随机选择只在服务端执行一次（权威），客户端经广播同步
	if not GlobalGameData.is_ai_mode and not multiplayer.is_server():
		return
	var bm = main.buff_manager if main else null
	if not bm:
		return
	var team = GlobalGameData.host_characters if self in GlobalGameData.host_characters else GlobalGameData.client_characters
	var allies = []
	for c in team:
		if c.hp > 0:
			allies.append(c)
	if allies.is_empty():
		return
	var harmed_allies = []
	for c in allies:
		for bid in c.buffs:
			var bd = BuffDatabase.get_buff_data(bid)
			if bd and bd.is_harmful:
				harmed_allies.append(c)
				break
	if harmed_allies.is_empty():
		return
	var target_ally = harmed_allies[randi() % harmed_allies.size()]
	var harmful_bids = []
	for bid in target_ally.buffs:
		var bd = BuffDatabase.get_buff_data(bid)
		if bd and bd.is_harmful:
			harmful_bids.append(bid)
	if harmful_bids.is_empty():
		return
	var remove_bid = harmful_bids[randi() % harmful_bids.size()]
	if bm.has_method("remove_buff"):
		bm.remove_buff(target_ally, remove_bid, 0)
	var heal = CharacterData.get_data("M1DorG")["passive_heal"]
	target_ally.take_damage_safe(-heal)
	print("[Passive] %s [Intel工程师] 移除 %s 的 [%s]，恢复 %d 点生命值" % [GlobalGameData.get_char_label(self), GlobalGameData.get_char_label(target_ally), remove_bid, heal])
