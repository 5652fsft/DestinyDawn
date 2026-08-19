class_name AIPlaybook
extends RefCounted

# ==================== AI 角色打法档案（Playbook） ====================
# 职责：定义每个角色的"技能使用时机 / 目标选择 / 技能价值 / 独占性"
# 通用查询与评分逻辑在 AIStrategist（AI/Strategist.gd）
#
# 各角色策略（权威说明，随代码维护；docs/08-ai-mode.md 不再重复）：
#   布洛妮娅   [护卫指令]      给 2 格内敌最多的受威胁队友 +30 盾；价值按目标血线 90/65/40
#   希儿       [相位突进]      瞬移收割：可击杀 150 分，否则 100-hp；冷却好即评估
#   伊蕾娜     [星尘爆裂]      125% 攻击 AOE：目标 + 周围 2 格，选敌密度最高处；冷却好即评估
#   流萤       [烈焰冲锋]      180% 攻击 + 灼烧：击杀优先，否则 atk+hp；冷却好即评估
#   银狼       [系统入侵]      虚弱+迟缓各 3 回合，给最高攻击敌人（被动已 100% 附加随机减益）
#   芝士仓鼠   [动作如潮]      有可攻击目标才用（额外行动回合结束清零，无目标=浪费+进冷却）
#   karrigan   [狂野·纵横烟中] 半径 8 内敌覆盖最高格放烟（BFS），价值 <40 不用
#   Zephyr     [引煞赴烬]      攀升 <2 层且自伤后血量 ≥35% 才用；无冷却可同回合连续释放
#                              （plan_unit 循环评估，模拟自伤/层数直至 2 层或血量线）
#   M1DorG     [我玩蔚蓝去了]  团队损血 ≥35% 或 ≥2 人 <50%；exclusive：先普攻再技能（away 锁行动）
#   Richardovo [突破]          自身 buff ≥1 且有可攻击目标才用（清 buff 换的额外行动同样会被清零）
#   あんパン   [极速高温烘焙]  能量≥4、资源缺口(手牌+能量)≥3、血量≥35%；耗行动
#   Anjing     [不打气不气]    牌运≥2 层、能量≥2；耗行动（能量预留 2）
#
# 新增角色流程：
#   1. 在 evaluate_skill() 的 match 中添加角色分支
#   2. 编写 _skill_<name>() 返回技能评估字典（并在上方策略表补一行）
#   3. 无需同步 docs/08-ai-mode.md（Playbook 表已并入此处注释）
#
# evaluate_skill 返回结构：
#   {"use": bool, "target": Node, "cell": Vector2i, "value": int, "exclusive": bool}
#   - target: 技能目标（SELF/单体型）
#   - cell: CELL 型技能（karrigan 烟雾）的目标格子
#   - value: 技能价值（用于与攻击价值比较、行动优先级排序）
#   - exclusive: 技能是否独占本回合其余动作（如 M1DorG 用技能后立即 away 锁行动）

static func _no_skill() -> Dictionary:
	return {"use": false, "target": null, "cell": Vector2i(-1, -1), "value": 0, "exclusive": false}

static func evaluate_skill(chara: Node, main: Node, sim_state: Dictionary = {}) -> Dictionary:
	if not chara or not main or not chara.active_skill:
		return _no_skill()
	if chara.active_skill.current_cooldown > 0:
		return _no_skill()
	if GlobalGameData.character_attack_used.get(chara.name, false):
		if not chara.has_method("_consumes_attack_on_skill") or chara._consumes_attack_on_skill():
			return _no_skill()
	var reason = SkillEffect.get_skill_block_reason(chara, main)
	if reason:
		return _no_skill()
	match chara.character_name:
		"布洛妮娅": return _skill_bronya(chara, main)
		"希儿": return _skill_seele(chara, main)
		"伊蕾娜": return _skill_elaina(chara, main)
		"流萤": return _skill_firefly(chara, main)
		"银狼": return _skill_silverwolf(chara, main)
		"芝士仓鼠": return _skill_hamster(chara, main)
		"karrigan": return _skill_karrigan(chara, main)
		"Zephyr": return _skill_zephyr(chara, main, sim_state)
		"M1DorG": return _skill_m1dorg(chara, main)
		"Richardovo": return _skill_richardovo(chara, main)
		"あんパン": return _skill_anpan(chara, main)
		"Anjing": return _skill_anjing(chara, main)
		_: return _no_skill()

# 技能是否可在同一回合连续释放（无冷却 + 不耗行动，如 Zephyr）
static func can_repeat_skill(chara: Node) -> bool:
	return chara.character_name == "Zephyr"

# 释放一次技能后的模拟状态（供连续释放评估），非可重复技能返回空
static func simulate_after_skill(chara: Node, main: Node, plan: Dictionary, sim_state: Dictionary) -> Dictionary:
	if chara.character_name == "Zephyr" and plan.get("use", false):
		var z_data = CharacterData.get_data("zephyr")
		var hp = sim_state.get("hp", chara.hp)
		var stacks = sim_state.get("ascend", AIStrategist.buff_stack_count(chara, "ascend"))
		var self_dmg = max(1, int(hp * z_data["skill_self_damage_pct"]))
		return {"hp": max(1, hp - self_dmg), "ascend": stacks + 1}
	return {}

# === 布洛妮娅 [护卫指令]：给受威胁队友 +30 护盾 ===
static func _skill_bronya(chara: Node, main: Node) -> Dictionary:
	var target = AIStrategist.find_most_threatened_ally(main, chara)
	if not target:
		return _no_skill()
	var hp_pct = float(target.hp) / target.max_hp
	var value = 90 if hp_pct < 0.5 else (65 if hp_pct < 0.8 else 40)
	return {"use": true, "target": target, "cell": Vector2i(-1, -1), "value": value, "exclusive": false}

# === 希儿 [相位突进]：瞬移 10 格 + 120% 攻击伤害，收割残血 ===
static func _skill_seele(chara: Node, main: Node) -> Dictionary:
	var skill_dmg = int(chara.effective_attack * CharacterData.get_data("seele")["skill_multiplier"])
	var enemies = AIStrategist.get_enemy_alive(main)
	var best = null
	var best_score = -999
	for e in enemies:
		var score = 150 if e.hp + e.shield <= skill_dmg else (100 - e.hp)
		if score > best_score:
			best_score = score
			best = e
	if not best:
		return _no_skill()
	return {"use": true, "target": best, "cell": Vector2i(-1, -1), "value": best_score, "exclusive": false}

# === 伊蕾娜 [星尘爆裂]：125% 攻击 AOE（目标 + 周围 2 格） ===
static func _skill_elaina(chara: Node, main: Node) -> Dictionary:
	var d = CharacterData.get_data("elaina")
	var radius = d["skill_radius"]
	var enemies = AIStrategist.get_enemy_alive(main)
	var best = null
	var best_count = -1
	for e in enemies:
		var count = AIStrategist.count_enemies_near(main, AIStrategist.get_cell(e), radius)
		if count > best_count:
			best_count = count
			best = e
	if best_count <= 0:
		return _no_skill()
	var dmg_per = int(chara.effective_attack * d["skill_multiplier"])
	return {"use": true, "target": best, "cell": Vector2i(-1, -1), "value": dmg_per * (best_count + 1), "exclusive": false}

# === 流萤 [烈焰冲锋]：180% 攻击单伤 + 灼烧 ===
static func _skill_firefly(chara: Node, main: Node) -> Dictionary:
	var dmg = int(chara.effective_attack * CharacterData.get_data("firefly")["skill_multiplier"])
	var enemies = AIStrategist.get_enemy_alive(main)
	var best = null
	var best_score = -999
	for e in enemies:
		var score = 150 if e.hp + e.shield <= dmg else (e.effective_attack + e.hp)
		if score > best_score:
			best_score = score
			best = e
	if not best:
		return _no_skill()
	return {"use": true, "target": best, "cell": Vector2i(-1, -1), "value": best_score, "exclusive": false}

# === 银狼 [系统入侵]：虚弱 + 迟缓各 3 回合，给最高攻击敌人 ===
static func _skill_silverwolf(chara: Node, main: Node) -> Dictionary:
	var enemies = AIStrategist.get_enemy_alive(main)
	var best = null
	var best_attack = -1
	for e in enemies:
		if AIStrategist.has_buff(e, "attack_debuff"):
			continue
		var a = e.effective_attack
		if a > best_attack:
			best_attack = a
			best = e
	if not best:
		return _no_skill()
	return {"use": true, "target": best, "cell": Vector2i(-1, -1), "value": 60 + best_attack, "exclusive": false}

# === 芝士仓鼠 [动作如潮]：+1 额外行动，不耗行动（不耗行动技能仅此三人：Zephyr / 芝士仓鼠 / Richardovo） ===
static func _skill_hamster(chara: Node, main: Node) -> Dictionary:
	# 额外行动回合结束清零（main.gd 回合切换 _extra_attacks=0）：无攻击目标时用技能 = 白白浪费 + 进冷却
	if not AIStrategist.can_attack_someone(chara, main):
		return _no_skill()
	return {"use": true, "target": chara, "cell": Vector2i(-1, -1), "value": 60, "exclusive": false}

# === karrigan [狂野·纵横烟中]：敌密集区 / 推进路径放烟 ===
static func _skill_karrigan(chara: Node, main: Node) -> Dictionary:
	var cell = AIStrategist.find_best_smoke_cell(chara, main)
	if cell == Vector2i(-1, -1):
		return _no_skill()
	var value = AIStrategist.evaluate_smoke_cell(cell, main, chara)
	if value < 40:
		return _no_skill()
	return {"use": true, "target": null, "cell": cell, "value": value, "exclusive": false}

# === Zephyr [引煞赴烬]：自伤 20% 换 1 层攀升（减伤 10%，最多 2 层）；无冷却可连续释放，sim_state 为连续释放的模拟状态 ===
static func _skill_zephyr(chara: Node, main: Node, sim_state: Dictionary = {}) -> Dictionary:
	var z_data = CharacterData.get_data("zephyr")
	var ascend_bd = BuffDatabase.get_buff_data("ascend")
	var max_stacks = ascend_bd.max_stacks if ascend_bd else 2
	var stacks = sim_state.get("ascend", AIStrategist.buff_stack_count(chara, "ascend"))
	if stacks >= max_stacks:
		return _no_skill()
	var hp = sim_state.get("hp", chara.hp)
	var hp_after = hp - max(1, int(hp * z_data["skill_self_damage_pct"]))
	if hp_after < chara.max_hp * 0.35:
		return _no_skill()
	return {"use": true, "target": chara, "cell": Vector2i(-1, -1), "value": 45, "exclusive": false}

# === M1DorG [我玩蔚蓝去了]：下回合空过，再下回合全队奶满（exclusive：用后立即锁行动） ===
static func _skill_m1dorg(chara: Node, main: Node) -> Dictionary:
	var missing = 0
	var total = 0
	var low_count = 0
	for c in AIStrategist.get_ally_alive(main, chara):
		missing += c.max_hp - c.hp
		total += c.max_hp
		if c.hp < c.max_hp * 0.5:
			low_count += 1
	if total == 0:
		return _no_skill()
	var loss_pct = float(missing) / total
	if loss_pct < 0.35 and low_count < 2:
		return _no_skill()
	var value = int(loss_pct * 200) + low_count * 30
	return {"use": true, "target": chara, "cell": Vector2i(-1, -1), "value": value, "exclusive": true}

# === Richardovo [突破]：消除自身所有效果，每消 1 个 +1 额外行动 ===
static func _skill_richardovo(chara: Node, main: Node) -> Dictionary:
	var count = AIStrategist.count_own_buffs(chara)
	if count <= 0:
		return _no_skill()
	# 额外行动回合结束清零：无攻击目标时清 buff 换来的行动也是浪费（仅剩"为下回合闭麦创造条件"的间接收益，不值冷却）
	if not AIStrategist.can_attack_someone(chara, main):
		return _no_skill()
	return {"use": true, "target": chara, "cell": Vector2i(-1, -1), "value": 30 + count * 45, "exclusive": false}

# === あんパン [极速高温烘焙]：耗 4 能量 → 抽满手牌 + 回满能量 + 松软副作用 ===
static func _skill_anpan(chara: Node, main: Node) -> Dictionary:
	var energy = AIStrategist.get_energy(main)
	var hand_gap = AIStrategist.get_hand_limit(main) - AIStrategist.get_hand(main).size()
	var energy_gap = AIStrategist.get_max_energy(main) - energy
	var need = hand_gap + energy_gap
	if energy < 4 or need < 3:
		return _no_skill()
	if chara.hp < chara.max_hp * 0.35:
		return _no_skill()
	return {"use": true, "target": chara, "cell": Vector2i(-1, -1), "value": 30 + need * 12, "exclusive": false}

# === Anjing [不打气不气]：耗 2 能量 → 群伤 + 抽增益牌（先出牌攒牌运再放） ===
static func _skill_anjing(chara: Node, main: Node) -> Dictionary:
	# 层数口径与实战一致（get_buffs().size()，非数值之和）
	var luck_stacks = chara.get_buffs("luck").size() if chara.has_method("get_buffs") else 0
	if luck_stacks < 2 or AIStrategist.get_energy(main) < 2:
		return _no_skill()
	var enemies = AIStrategist.get_enemy_alive(main)
	# 实战先移除牌运再计算伤害，评估时同样扣除牌运攻击加成
	var a_data = CharacterData.get_data("anjing")
	var real_atk = max(0, chara.effective_attack - luck_stacks * a_data["passive_luck_value"])
	var dmg = int(real_atk * a_data["skill_multiplier"]) + AIStrategist.get_hand(main).size() * a_data["skill_hand_damage"]
	var value = dmg * enemies.size() + luck_stacks * 15
	return {"use": true, "target": chara, "cell": Vector2i(-1, -1), "value": value, "exclusive": false}