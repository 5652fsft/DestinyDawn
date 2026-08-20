# v1.7.4 修复计划（执行依据，防止上下文丢失）

> 状态：**实现完成，待发布（版本升至 1.7.5）** | 目标版本：1.7.5 | 本文档为 1.7.4→1.7.5 的逐文件改动清单与验证方式。
> 完成后此文档保留为发布记录，可归档。

## 实现进度与验证结果（2026-08-19）

- ✅ 全部代码改动已实现（第 1-6 节清单），`godot --headless` 全项目解析零 SCRIPT ERROR。
- ✅ 用临时测试 autoload（已删除）跑真实战斗场景断言，13 项全部 PASS：
  1. host/client 阵营注册 3+3；2. move_debuff 移动 -2；3. max_stacks=1 不叠加；4. 净化只清减益；5. 布洛妮娅不削治疗；6. simulate_damage 含铁壁减伤；7. 希儿满血被动对技能生效；8. karrigan 死亡仅同阵营获加成（双向）；9. 流萤燃烧装甲每回合重置；10. DOT 单次结算；11. AI 减益卡目标为敌方
- ✅ 额外确认：AI 出血类卡目标选取正常（此前 headless 日志中"对手/karrigan"为 is_host 未设置导致的标签翻转，非 bug）。
- ✅ **追加修复（芝士仓鼠额外行动计数回归，2026-08-19 晚）**：
  - 根因：M5 将 `character_attack_used` 置位挪入 `perform_attack` 且保留外部 consume 块 → 玩家路径双扣（攻击 1 次后剩余 0 次）、AI 路径不消耗额外次数（无限攻击）。
  - 修复：计数统一收敛到 `perform_attack` 内部（call_local 两端同步），语义恢复为"优先消耗额外次数，无额外才占用基础次数"；删除 `_input` / `AIController._execute_attack` 的外部计数块；Seele/Zephyr 覆写同步改。
  - 验证：临时测试 autoload 31 项断言全部 PASS（芝士仓鼠技能后 2 次攻击序列、普通角色单次、Hamster 击杀被动、karrigan 传承消耗、move_debuff、max_stacks、净化、铁壁、simulate_damage、希儿 1.5x、流萤重置、DOT 单次），零 SCRIPT ERROR。
- ✅ **二轮追加（2026-08-19）**：
  - karrigan 天赋改版：取消死亡触发，改为开局 [拧绳]（攻击力+5 永久）全阵营发放（见第 1 节）。
  - 面板属性显示：移动/攻击范围与攻击力一致，显示"基础 ±x（红/绿）"（当前无攻击范围增减源，预留同构逻辑）。
  - 银狼攻击范围 2 → 7（数据驱动）。
  - 顺带修复：`Strategist.simulate_damage` 希儿被动判定 `"Seele"` 与 `character_name=="希儿"` 不匹配 → AI 模拟伤害低估希儿（已改为"希儿"）；`Strategist.gd:674` BUFF_ATTACK 评分列表同样改为正确角色名（`"希儿"/"芝士仓鼠"`，Richardovo/Zephyr/Anjing 原名有效）。
  - 验证：临时测试 autoload 36 项断言全部 PASS（rope 发放/幂等/永久、双方独立发放、karrigan 死亡保留、银狼 range=7、芝士仓鼠完整攻击序列、普通单次、move_debuff、max_stacks、净化保留增益、铁壁 80、simulate 100、希儿 1.5x=27、流萤重置、灼烧单次），零 SCRIPT ERROR。
- ⏳ 待办：真机联机对局验证（含 karrigan 开局 [拧绳] 双端一致、银狼 7 格远程、移动范围 ± 红绿显示）、杀软误报观察、安装替换全链路、安卓图标实机观察。
- ✅ **三轮追加（2026-08-20，联机结算 + move_debuff）**：
  - 根因调研：`rpc()` 与 `rpc_id(0)` 为同一代码路径（node.cpp `rpc` → `rpcp(0,...)`），服务端 `rpc_id(0)` 即广播——原"rpc_id(0) 不广播"假设作废。结算链路完全依赖服务端：死亡 → `unregister_character` → `check_victory`（服务端专属）→ rpc advance → GAME_OVER 广播 → 客户端结算。当**最后一击未在服务端登记**（karrigan 掉血 bug：客户端普攻经 `perform_attack` 双端各自执行，服务端副本被 `perform_attack` 守卫拦截 → 服务端不掉血）时，GAME_OVER 永不广播 → 客户端卡死。move_debuff 根因：`show_move_range` 用 `move_points` 而非 `effective_move_points` → 高亮与实际移动（`valid_move_cells`）均无视 debuff。
  - 修复 1（结算兜底）：`unregister_character` 的 `check_victory()` 双端执行；服务端/AI 维持原 rpc 流程，客户端本地置 `GAME_OVER` + `show_battle_result()`（`_battle_over` 守卫幂等，服务端迟到广播自动跳过）。battle_stats 三处累加（heal/damage/death）移出服务端门控，客户端本地结算统计完整。
  - 修复 2（move_debuff）：`BaseCharacter.gd:234` `show_move_range` 改用 `effective_move_points`（面板 CharacterInfoPanel 与 AI Strategist 本已正确）。
  - 验证：临时 test autoload 16 项断言全 PASS（effective_move_points==base-2、可达格 91→59 单调递减丢失 32 格、全灭→GAME_OVER、client_kills 统计、_sync_turn_phase 链路、客户端视角胜负、幂等），零 SCRIPT ERROR。数据 91-32=59 自洽。
  - **已知待办（karrigan 掉血 bug，用户搁置后续修）**：客户端普攻服务端 karrigan 有概率不掉血（快结束/服务端仅剩 karrigan 时更易触发，可能非 karrigan 特有）。根因收敛：`perform_attack`（BaseCharacter.gd:463-471）服务端副本被守卫（target_path 解析失败/hp<=0/相位非 Active/行动次数）拦截；普攻伤害无强制同步（`_sync_hp` 仅死亡/治疗分支广播）。下一步：临时日志定位服务端被哪个守卫拦截。
  - ✅ **四轮追加（2026-08-20，服务端对齐结算）**：
    - 用户实测反馈：客户端胜利时客户端已能及时弹结算，但**服务端仍卡在回合中不结算**。根因：服务端结算依赖自身登记最后一击（`unregister_character` → 服务端 `check_victory`），当最后一击因 karrigan bug 未在服务端登记时，服务端 `check_victory` 恒 false → 永不广播 GAME_OVER → 服务端卡死。
    - 修复：客户端本地结算（`unregister_character` else 分支）时 `rpc_id(1, "_client_settled", host_win)` 通知服务端；服务端新增 `_client_settled(host_win)`：校验发送者（0=本地/OfflinePeer 或 client_peer_id），将败方角色全部 hp=0 并从列表移除，然后走标准 `advance_turn_phase` 结算（幂等，`_battle_over` 已置则忽略）。
    - **环境事实修正**：Godot 4.7 的 `multiplayer.has_multiplayer_peer()` 在无外部 peer 时仍返回 **true**（默认 `OfflineMultiplayerPeer`）；本地直调 RPC 函数 `get_remote_sender_id()` 返回 0。全项目现有 `has_multiplayer_peer()` 守卫在此环境下等价走 rpc 分支（call_local 本地执行），行为不变。
    - 验证：临时 test autoload 11 项断言全 PASS（`_client_settled(true/false)` 对齐+结算、败方全灭并移除、重复通知幂等、`_battle_over` 后忽略、相位 GAME_OVER），零 SCRIPT ERROR。**待人工验证**：双端局域网重打"客户端普攻杀光服务端"场景，确认双端同时弹结算。
  - ✅ **五轮追加（2026-08-20，`_client_settled` 败方语义修正）**：
    - 用户实测：客户端胜利时**服务端也错误显示胜利**。根因：`_client_settled` 的败方取反（`host_win`=host 队是否有存活，host 全灭时应清 **host** 队，原代码清了 **client** 队 → 服务端 check_victory 误判"服务端胜利"）。教训：此前测试断言"传入方被清空"，与实现错得一致，未验证语义。
    - 修复：`loser_side = client_characters if host_win else host_characters`（host 存活→败方 client；host 全灭→败方 host）。
    - 验证：重写断言按语义验证（host_win=true → client 队移除且 host 保留；host_win=false → host 队全灭移除），12 项全 PASS，零 SCRIPT ERROR。
  - ✅ **六轮追加（2026-08-20，服务端拦截实证排查 + 移除双兜底）**：
    - 目标：实证"客户端普攻服务端角色有概率不掉血"（服务端 perform_attack 守卫拦截）根因。搭建真实 ENet 双进程自动对局探针（临时 autoload `net_auto.gd` + main_scene 临时指向 scene.tscn，已还原）：`--probe=host`（服务端）/`--probe=client`（客户端），客户端每回合打牌/放技能/普攻/结束回合，服务端同构，对局结束自动退出。
    - **探针结论**：35 轮真实对局（普攻、host 攻击、卡牌、技能全覆盖）全部一致——零守卫拦截、零双端分歧、双端正确结算。静态审查亦确认攻击链路双端对称（call_local 同一守卫+计数）、状态同步全走可靠 rpc。原始"不掉血"场景无法在本地复现，触发条件指向真实网络环境竞态。
    - **决策（用户确认）**：移除双兜底（客户端本地结算 else 分支 + `_client_settled` 函数），回归纯服务端权威结算单一路径。验证：移除后探针 5 轮回归全绿（sa=ca、零 REJECT、双端正常结算）。
    - AttackDebug 诊断日志（SEREVR/CLIENT ACCEPT/REJECT/counted/unregister）**保留**（联机攻击时低频打印，供线上排查）。
    - 版本号升 1.7.5（UpdateManager + export_presets.cfg 同步），待用户双端实测后推送发布。

## 0. 决策汇总（用户已确认）

| 项 | 决策 |
|---|---|
| karrigan 天赋 | 简化改版：取消死亡触发，战斗开始我方全体获得 [拧绳]（攻击力+5，永久），服务端幂等发放 |
| 逻辑错误 | 所有确认存在的高/中/低危问题全部修复 |
| 杀毒/安装 | 安装器健壮性本轮做；杀毒走方案 A（补全导出版本信息，不做误报申诉） |
| 安卓图标 | 保持现版图标资源；导出配置引用已验证正确（uid 匹配）；本轮仅记录 + 检查导出产物 |
| 版本 | 升 1.7.4 |

---

## 1. karrigan 天赋改版（[拧绳] 战斗开始发放，方案已变更）

**变更原因**（2026-08-19）：人工测试发现"karrigan 死亡 → 友方获得传承与额外行动"在联机下表现不稳定（发放耦合死亡触发/阵亡判定/广播时序），机制脆弱。用户决定简化：**取消死亡触发，改为战斗开始时使我方全体获得 [拧绳]（攻击力+5，永久）**。

**改动清单**：

| 文件 | 改动 | 影响范围 |
|---|---|---|
| `Global/CharacterData.gd:37-38` | passive 改名"老将·领袖气质"；desc 改为"战斗开始时，使我方全体获得[拧绳]，效果为攻击力+5"；`passive_legacy_*` → `passive_rope_value:5` | 角色面板/编队卡被动描述 |
| `Cards/BuffDatabase.gd` | 新增 `rope`（拧绳）：ATTACK_BUFF、增益、max_stacks=1；删除 `legacy` 条目 | 全项目 |
| `Characters/BaseCharacter.gd:751-752` | `effective_attack` 加 `base += get_total(self, "rope")` | 所有角色攻击力计算 |
| `Scenes/main.gd reset_character_state` | 删除 karrigan 死亡发放块；新增 [拧绳] 幂等发放：`is_ai_mode or is_server` 守卫内，遍历 host/client 两侧，队伍含 karrigan（无论死活）→ 该阵营存活全员 `apply_buff(rope, 5, 999)`（max_stacks=1 幂等；净化后下回合重补） | 联机/单机 |
| `Characters/Karrigan/Karrigan.gd` | 删除 take_damage 覆写（恢复基类，护盾/防御正常结算） | 无 |
| `Global/GlobalGameData.gd` | 删除 `karrigan_death_side` 声明与 reset 处理 | grep 无残留 |
| `UI/CharacterInfoPanel.gd` | `_buff_desc` legacy 分支 → rope 分支（"攻击力+%d（永久）"） | 面板显示 |

**说明**：
- "战斗开始"由每回合 `reset_character_state`（rpc call_local 双端执行）触发；发放块带服务端守卫（`is_ai_mode or is_server`），客户端只收 `_sync_buffs` 广播，与全项目"状态同步由服务端驱动"约定一致。
- 永久实现：`duration=999`（大值，`remaining` 每回合递减但实战回合数远小于 999）；`max_stacks=1` 保证不叠加；净化只清有害不清增益 [拧绳]，karrigan 存活时被清也会下回合重补。

---

## 2. 高危逻辑修复

### P1 联机 DOT/HOT 双倍结算
| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `Scenes/main.gd:1189-1192` | `process_all_buffs` 开头加 `if not GlobalGameData.is_ai_mode and not multiplayer.is_server(): return` | 中毒/灼烧/再生每回合结算次数 | 联机：给目标上毒后每回合只扣 1 次 |
| `Characters/BaseCharacter.gd:779-783` | 双保险：tick 应用循环同样加服务端守卫 | 同上 | — |

### P2 move_debuff 双负号（减速变加速）
| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `Characters/BaseCharacter.gd:767` | `base -= get_total("move_debuff")` → `base += ...`（debuff 全项目存负值） | 冰晶碎片/迟缓术/冰冻术/银狼技能被动 | 给目标施迟缓后其移动距离应 -2 |

### P3 max_stacks 判定写错
| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `Global/BuffManager.gd:12` | `data.max_stacks > 1` → `> 0` | 标记/hot_burn/松软/独狼不再无限叠加 | 连续对同一目标放两张标记 → 只有 1 层 |

### P4 净化误清增益
| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `Global/BuffManager.gd:51-62` | 新增 `cleanse_harmful(target)`（按 `BuffDatabase.is_harmful` 过滤；无数据的兜底也清除） | 净化卡 | 对带"力量强化+中毒"的友方用净化 → 只移除中毒 |
| `Cards/CardEffect.gd:538-549` | `_execute_cleanse` 改调 `cleanse_harmful`；fallback 分支同步只清有害 | 净化卡 | 同上 |
| 注意 | `SkillEffect._Richardovo_active` 继续用 `cleanse("all")`（技能设计为清全部，不改） | — | — |

### P5 银狼/M1DorG/Anpan 被动随机与广播 desync
| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `Characters/SilverWolf/SilverWolf.gd:30-40` | 被动段加 `if not GlobalGameData.is_ai_mode and not multiplayer.is_server(): return`；附加前判 `target.hp > 0` | 银狼被动 | 联机：两端减益类型一致 |
| `Characters/M1DorG/M1DorG.gd:54-92` | 同上守卫；随机选择只在服务端；`take_damage(-heal)` 改 `take_damage_safe(-heal)`；补充基类守卫（L7） | M1DorG 被动 | 联机：净化/治疗对象两端一致 |
| `Characters/Anpan/Anpan.gd:33-41` | 被动段加服务端守卫 + `target.hp > 0` | あんパン 被动 | 联机不重复广播 |

---

## 3. 中危逻辑修复

### P6 流萤燃烧装甲每回合不重置 + 无攻击者消耗 + 无守卫
| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `Characters/Firefly/Firefly.gd:31-43` | 仅在有有效攻击者（`last_attacker` 非空、非自身）时置 `_burn_armor_used=true`；灼烧施加加服务端守卫 | 流萤被动 | 每回合首次受击都触发；卡牌伤害不消耗触发 |
| `Scenes/main.gd:1404-1410` | `reset_character_state` 循环中重置 `_burn_armor_used = false` | 回合重置 | 连续两回合受击均触发 |

### P7 布洛妮娅铁壁削减治疗
| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `Skills/SkillEffect.gd:72-82` | `_bronya_passive` 开头 `if base_value <= 0: return base_value` | 布洛妮娅回血 | 治疗量不再被削减 |

### P8 希儿
| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `Characters/Seele/Seele.gd:32-52` | `perform_attack` 补 `main.last_attacker = self`、补行动次数守卫、补 `character_attack_used` 标记；伤害改走 `SkillEffect.get_passive_modifier(self,"outgoing_damage",effective_attack)`（激活被动代码） | 希儿攻击/流萤联动 | 满血加伤对攻击与技能都生效 |
| `Skills/SkillEffect.gd:111-136` | `_seele_active` 先写 `last_target_hp/max_hp` 再用 `get_passive_modifier("outgoing_damage")` 计算技能伤害 | 希儿技能 | 技能打满血目标 +50% |

### P9 服务端技能缺冷却/行动校验
| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `Scenes/main.gd:849-865` | `_server_execute_skill` 补：`skill.current_cooldown > 0` → 拒绝；耗行动技能在 `character_attack_used` 已用且无额外行动时 → 拒绝 | 服务端权威 | 冷却中连发被拒 |

### P10 AI 操作 away 角色
| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `AI/AIController.gd:210`、`:277`、`:306` | `_execute_move/_execute_attack/_execute_skill` 开头加 `get_current_phase() != "Active" → return` | AI 行为 | AI 的 M1DorG 离场期间不移动/攻击 |
| `AI/Strategist.gd:402-405` | `plan_unit` 同条件返回空计划 | AI 决策 | 同上 |

### P11 AI 伤害模拟与实战公式不一致
| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `AI/Strategist.gd:179-207` | 顺序改为：攻击者被动 → **受击者被动（Zephyr 攀升 / 布洛妮娅铁壁，先于 MARK/防御，与 take_damage 覆写一致）** → MARK → 防御 | AI 击杀判定准确性 | AI 对布洛妮娅不再高估伤害 |

### P12 Anjing AI 层数口径错误
| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `AI/Playbook.gd:222-229` | `luck_stacks` 改用 `chara.get_buffs("luck").size()`（层数）；评估伤害时扣除牌运攻击加成（`effective_attack - stacks * passive_luck_value`） | AI 技能使用时机 | AI 牌运 ≥2 层才放技能 |

### P13 `_sync_skill_state` 服务端计数双加
| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `Scenes/main.gd:883-891` | `_sync_skill_state` 中 `attack_consumed` 分支加 `if not multiplayer.is_server():`（服务端已在 `_server_execute_skill:870-871` 处理） | 行动计数一致性 | 服务端计数不再翻倍 |

### M3 断连处理（中危，功能缺失）
| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `Scenes/main.gd:169` 附近 | 服务端监听 `peer_disconnected`：客户端掉线 → 按投降处理（`show_battle_result(true, false)`，投降方非主机 → 主机获胜），先清空客户端角色 HP 避免 check_victory 误判 | 联机鲁棒性 | 联机中杀客户端进程 → 主机弹结算 |
| `Scenes/main.gd`（客户端） | 客户端监听 `peer_disconnected`（peer=1）：toast + 返回主菜单 | 客户端不被卡死 | 联机中杀主机 → 客户端回主菜单 |

### M2 结束回合无服务端校验（中危）
| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `Scenes/main.gd`（advance_turn_phase 开头） | 服务端校验：远端发送者必须等于 `get_current_player_id()`，否则拒绝推进 | 防客户端越权/连点 | 客户端伪造结束回合被拒 |

### M4 `_on_client_joined` 可能重复触发
| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `Scenes/main.gd:393-403` | 增加 `_joined_clients: Array[int]` 幂等守卫（同 id 已处理则跳过） | 角色重复生成 | 快速重连不双份生成 |

### M5 客户端行动状态不广播（最小修复）
| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `Characters/BaseCharacter.gd:465-487` | `perform_attack` 守卫通过后置 `character_attack_used[name]=true`（未用→用时 `num += 1`，幂等） | 两端行动状态一致 | 联机攻击后服务端副本同步置位 |
| `Characters/BaseCharacter.gd:423-427` | `handle_attack` 删除冗余 elif 置位（保留额外行动消耗） | 避免双加 | — |
| `Characters/Seele/Seele.gd`、`Characters/Zephyr/Zephyr.gd:37-57` | 覆写（不调 super）补同样的置位 | 同上 | — |

### M2（agent1）/ 其他中危
| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `Scenes/main.gd:1028-1036`（L5） | `_active_skill_post_exec` 的 pid 改用 `SkillEffect.get_character_pid(selected_character)`（能量/手牌同步） | 本地/AI 模式 | — |
| `Scenes/main.gd:1117-1127`（L4） | `draw_extra_card`：`get_current_player_id() <= 0` 直接 return（去掉 `max(1, pid)` 掩蔽） | 抽牌时机安全 | 阶段异常不补给主机 |
| `Scenes/main.gd:918-922`（L2） | 出牌失败退款后补 `_sync_energy/_sync_hand` 广播 | 手牌/能量一致 | — |
| `Scenes/main.gd:834-838`（L9） | `_server_play_card`：`get_remote_sender_id() != 0` 且与 player_id 不符时校正为发送者 | 防伪造玩家身份 | 客户端改包打不出主机牌 |
| `Scenes/main.gd:1100-1115`（L1） | `_check_anpan_passive` 内冗余手牌广播删除（外层 `_execute_play_card` 已广播） | 少一条 RPC | — |

---

## 4. 低危修复

| 文件:行 | 改动 | 影响范围 | 验证方式 |
|---|---|---|---|
| `Cards/CardDatabase.gd:14-16` + `Cards/CardEffect.gd:110-118` | 冰晶碎片迟缓数值/时长从卡牌数据读取（`secondary_value=2, secondary_duration=1`） | 数值可配置 | 冰晶碎片仍 -2/1 回合 |
| `UI/CharacterInfoPanel.gd:123-126` | `attack_debuff/move_debuff` 显示用 `abs(val)` 修双负号 | 面板文本 | 显示"攻击力-6"而非"--6" |
| `Cards/CardEffect.gd:462-482` + `:68-69` | 删除死代码 `_execute_linear_aoe`（方向判定恒为圆形、无卡使用、无 caster 概念无法正确定义） | 无（死代码） | grep 无引用 |
| `Cards/CardEffect.gd:394-417` | AOE 伤害/治疗加 `c.hp > 0` 过滤；`if target: is_caster_host=_is_host_side(target)` 覆盖逻辑删除（无卡走 target 分支，避免阵营推导反） | 烈焰风暴/箭雨/治疗波/群体治愈 | 不命中尸体 |
| `Cards/CardEffect.gd:486-493` | `_get_characters_in_range` 加 `c.hp > 0` | 范围检索 | — |
| `Cards/CardEffect.gd:5-74` | 重构：`execute` 拆 `_execute_dispatch`，效果成功后再触发 `_apply_magic_resonance` | 魔力共鸣不再空放叠层 | 对尸体用伤害卡不叠层 |
| `Cards/CardEffect.gd:397/409/522` | `current_card_player_id == 1` 判式改为 `<= 0` 时回退 pid=1 的显式处理 | AOE 阵营判定 | — |
| `Scenes/main.gd:1470` + 两处调用（1444-1445/1466-1467） | `_sync_turn_phase` 增加 `drawn` 参数同步 `turn_has_been_drawn` | 客户端抽牌音效 | 联机客户端出牌有声 |
| `Cards/CardEffect.gd:94` | 惩戒保底 1 点伤害：**维持现状**（疑似有意下限，与描述偏差已记录） | 不改 | — |
| `Cards/CardEffect.gd:401-403` 等 | AOE 命中尸体问题随第 4 节 AOE 过滤一并修复 | — | — |

---

## 5. 更新安装器健壮性 + 杀毒方案 A

### 安装器重写（`Global/UpdateManager.gd:548-580`）
- 生成 bat 前检查 `new_exe` 存在（被杀毒隔离时给出明确错误 + 提示网页下载兜底）。
- bat 改为：`%~1`/`%~2` 传参（new/current exe）→ `tasklist` 循环等待旧进程退出（≤10s）→ `move /y` 失败重试 ≤5 次（1s 间隔，抗杀软扫描锁/句柄未释放）→ 成功后 `start` 新 exe → 自删；`%~dp0install.log` 记录每一步（时间戳 + errorlevel），失败不删旧 exe。
- `OS.create_process("cmd.exe", ["/c", bat_path, new_exe, current_exe])` 传参方式。
- 同步更新 `docs/11-save-and-update.md` 的"下载与安装（Windows）"一节。

**验证**：正常升级全链路（替换+重启成功）；模拟失败（新文件被改名）→ 旧 exe 保留、install.log 有记录。

### 杀毒误报方案 A（低成本）
- `export_presets.cfg` Windows 预设补全版本信息（当前 file_version/product_version/file_description 全空，空信息 exe 更可疑）：
  - `application/file_version="1.7.4.0"`、`application/product_version="1.7.4"`、`application/file_description="DestinyDawn"`、`application/copyright="5652"`、`application/trademarks="DestinyDawn"`（company/product 已有）。
- Android 预设 `version/name="1.7.4"`（当前为空）。
- 记录：误报根因是 embed_pck 启发式（官方文档明示），治本需代码签名 + 改独立 pck（方案 B，暂缓）。

**验证**：导出后右键 exe → 属性 → 详细信息可见版本号；发布后观察报毒情况。

---

## 6. 安卓图标（保持现图，记录）

- 已验证 `export_presets.cfg` 引用 uid 与 `Assets/Icons/*.import` 完全匹配（`dnqvejgve3qe5`/`djessdj85lkay`），Godot 导出会自动生成 `mipmap-anydpi-v26/ic_launcher.xml` 自适应图标。
- "部分设备 mask 裁其他应用图标不裁我的图标" 属 OEM 启动器行为（图标缓存/对旧安装回退 legacy），非本包图标裁剪问题。
- 本轮动作：导出后抽查 APK 是否含 `mipmap-anydpi-v26/ic_launcher.xml`（确认生成）；文档记录现象与说明（旧安装需重装/换启动器图标样式后生效）。

---

## 7. 版本号与文档同步

| 文件 | 改动 | 状态 |
|---|---|---|
| `Global/UpdateManager.gd:5` | `VERSION = "1.7.5"` | ✅ |
| `export_presets.cfg:15,86` | 两个预设 export_path 改 `DestinyDawn-v1.7.5.exe/.apk` | ✅ |
| `export_presets.cfg` | 版本信息字段：file_version=1.7.5.0、product_version=1.7.5.0、file_description、copyright、trademarks；Android version/name=1.7.5 | ✅ |
| `docs/11-save-and-update.md` | 安装器新机制（tasklist 等待/重试/install.log/缺包提示） | ✅ |
| `docs/12-v174-fix-plan.md` | 本文档随实现同步更新 | ✅ |
| `docs/05-rpc-conventions.md` | 服务端校验补充说明（advance_turn_phase 发送者校验、技能冷却校验） | ✅ |
| `readme.md` | 无版本号需同步（左下角版本为运行时读取，示例文字不改） | — |

## 8. 实施顺序

1. karrigan（1 节）→ 2. 高危（P1-P5）→ 3. 中危（P6-P13/M2/M3/M4/M5）→ 4. 低危 → 5. 安装器+版本信息 → 6. 版本号/文档 → 7. 语法验证（godot --headless）+ 提交。

## 9. 最终验证方式

- 语法：`godot.windows.opt.tools.64.exe --headless --path <项目> --quit` 无 SCRIPT ERROR。✅ 已通过（含编辑器全量扫描）
- 自动化断言：临时 test autoload 跑真实战斗场景，累计 36 项全 PASS（含 rope 发放/芝士仓鼠序列等，见文件头部"实现进度"）。✅
- 功能（人工，发布前）：
  - 单机 AI 快速对局：开局我方全员 [拧绳]（面板图标+攻击力+5）、迟缓生效（移动范围显示 基础-2 红字）、净化只清减益且不清 [拧绳]、流萤每回合触发、标记不叠加、DOT 正常单次结算、银狼可攻击 7 格
  - 联机双开：karrigan 开局 [拧绳] 双端一致、银狼远程同步、DOT 同步、断连结算、技能冷却拒绝、结束回合伪造被拒
- 更新：模拟低版本触发下载 → 安装 → 替换重启；失败场景看 `.dd_update/install.log`
- 杀软：发布后观察报毒变化（版本信息已补全）
- 安卓图标：导出后抽查 APK 含 `mipmap-anydpi-v26/ic_launcher.xml`；实机观察 mask 行为
