# 自动战斗功能规划（docs/13）

> 状态：**规划已落盘，待用户确认问题后实施** | 目标版本：1.7.5（与联机结算修复同版本发布）
> 本文件为自动战斗功能的完整方案与待确认问题，防止上下文丢失。

## 0. 需求背景

- 用户诉求：战斗界面添加"自动战斗"小按钮（与安卓端两个独占 UI 按钮同一行，**双端都显示**），开启后按钮点亮，AI 接管开启自动战斗方的操作。
- 功能双重价值：实际玩法功能 + 模拟更实战的环境操作调试（可复现联机 bug 场景）。
- 追加诉求（用户提问"单机模式能不能也有自动功能"）：**单机模式下玩家也能开自动**（AI 接管玩家方）。已确认可行，成本近乎为零（AIStrategist 参数化的自然结果）。

## 1. 已确认决策

| 项 | 决策 |
|---|---|
| 按钮位置 | `UI/AutoBattleButton`，与 HandToggleButton / SurrenderMenuButton 同一行（scene.tscn 中 offset_left=-200~-160，两按钮为 -280~-240、-240~-200） |
| 按钮显示 | **双端都显示**（PC 也显示，不套用安卓独占逻辑）；单机也显示 |
| 点亮状态 | 开启自动战斗时按钮点亮（高亮/自发光） |
| 图标 | "主机"（游戏手柄）256px，`C:\Users\10932\Documents\5652\DestinyDawn\图标\2.媒体与科技\主机_256px.png` → 复制到 `Assets/Icons/gamepad.png` |
| 开关 | 本地变量 `GlobalGameData.auto_battle_self`（本端只管自己），**无需网络同步** |
| 单机语义 | 默认：敌方 AI（现行为不变）；玩家开自动：AI 接管玩家方 → **AI 对 AI 观战** |
| 联机语义 | 开自动的一端由本端进程的 AIController 接管本端操作；双方可同时开（AI 对 AI） |
| AI 接管范围 | 出牌 / 技能 / 普攻 / 移动 / 结束回合（与单机 AI 能力一致） |

## 2. 方案设计

### 2.1 执行端与架构

- **AI 在操作方本地执行**：host 开自动 → host 进程跑 AI 并以"玩家同构方式" rpc 操作；client 同理。与玩家操作完全同构，无额外同步负担，不触碰服务端权威逻辑。
- 单机（is_ai_mode=true）：AI 直接本地调用（现逻辑，无 rpc）。

### 2.2 AI 控制方判定（AIController）

```
_ai_controls(side) -> bool:
	return (is_ai_mode and side == "client")            # 单机默认：敌方
		or (GlobalGameData.auto_battle_self and side == 本端方)
# 本端方 = "host" if GlobalGameData.is_host else "client"
```

- `_process` 守卫：`if not GlobalGameData.is_ai_mode and not GlobalGameData.auto_battle_self: return`。
- `_is_ai_turn()` 改为：当前相位对应的行动方（PLAYER_TURN→host_turn?host:client；ENEMY_TURN→host_turn?client:host）是否被 `_ai_controls`。
- **双队列**：`_queues = { "host": [], "client": [] }`（按控制方分组）；相位切换时清空双方队列；当前行动方为 AI 控制方时规划+执行。

### 2.3 AIStrategist 阵营参数化

- 新增 `static var ai_side: String = "client"`（默认单机语义不变）。
- 顶部访问器改读 ai_side（改动集中，内部函数通过访问器解耦，全局生效）：
  - `get_ai_alive(main)` / `get_ally_alive(main)` → ai_side 侧角色
  - `get_enemy_alive(main)` → 另一侧角色
  - `get_energy(main)` / `get_hand(main)` → 改用 `get_pid(ai_side)`
  - 新增 `static func get_pid(side) -> int`：host→1；client→联机 `GlobalGameData.client_peer_id` / 单机 2（AI_PID 保留）
- `get_energy_of` 已用 `owner_pid`，无需改。
- AIController `_plan_and_queue(side)` 规划前显式设置 `AIStrategist.ai_side = side`（消除静态变量跨对局残留风险）。

### 2.4 执行层联机化（唯一破坏性改动点）

| 函数 | 单机（现逻辑不变） | 联机新增分支 |
|---|---|---|
| `_execute_attack` | `chara.perform_attack(...)` | `perform_attack_safe` |
| `_execute_skill` | `use_active_skill` + 手动冷却/计数 | `rpc("_server_execute_skill", ...)` |
| `_execute_card` | `_main._execute_play_card(AI_PID, ...)` | `rpc("_server_play_card", pid, ...)`，pid 用 `get_pid(ai_side)` |
| `_end_phase` | `_main.advance_turn_phase()` | `main.rpc("advance_turn_phase")` |

### 2.5 UI 改动

- scene.tscn：新增 `AutoBattleButton`（Button，-200~-160 同一行，双端可见）。
- main.gd：`_setup_auto_battle_button()`（icon=gamepad.png、点击切换 `auto_battle_self`、点亮状态调制、双击/长按无特殊逻辑）；战斗中按钮常显（不套 `_set_mobile_buttons_visible` 的安卓独占逻辑，但全屏界面打开时是否隐藏待确认）。

### 2.6 开关切换语义

- 随时可开/关；**关闭时清空该方未执行队列**（防残留动作）；开/关不影响对端。

## 3. 改动清单（逐文件）

| 文件 | 改动 |
|---|---|
| `Global/GlobalGameData.gd` | `var auto_battle_self: bool = false` |
| `AI/Strategist.gd` | `ai_side` 静态变量、`get_pid(side)`、顶部访问器参数化 |
| `AI/AIController.gd` | `_ai_controls`、双队列、`_is_ai_turn` 改造、4 个执行函数联机分支、`_plan_and_queue(side)` |
| `Scenes/main.gd` | 自动战斗按钮初始化/点亮/切换（`_setup_auto_battle_button` 等） |
| `Scenes/scene.tscn` | 新增 `AutoBattleButton` 节点（同一行布局） |
| `Assets/Icons/gamepad.png` | 从外部图标库复制"主机"图标（含 .import 由 Godot 生成） |
| `docs/13-auto-battle.md` | 本文档实施后更新为完成记录 |

## 4. 验证方式

- **单机回归**：headless 跑 is_ai_mode 全对局（不开自动），断言行为与现有完全一致（AI 控制 client 方、玩家手动操作 host 方）。
- **单机自动**：单机开自动 → AI 控制双方，对局正常完成（AI 对 AI）。
- **联机探针**：复用临时 net_auto 探针（已删除，需重建）——双端 `auto_battle_self=true`，AI 对 AI 自动对局，验证：攻击/技能/出牌/结束回合经 rpc 在服务端正确登记、双端结算一致、零守卫拦截。
- **语法**：`godot --headless --path <项目> --quit` 零 SCRIPT ERROR。
- **人工**：双端实测（PC 双开或 PC+安卓）：按钮点亮、AI 接管、随时关停、结算正常。

## 5. 影响现有功能评估

- **单机 AI**（核心玩法）：is_ai_mode 路径行为必须完全等价——`ai_side` 默认 "client"、`_ai_controls` 单机默认只控 client，需完整回归。
- **联机未开自动**：AIController `_process` 守卫不通过 → 完全不介入，零影响。
- **执行层 4 函数**：单机分支逻辑不变，仅新增联机 rpc 分支；skill/card 联机走服务端权威（与玩家操作同构），本地不再手动计数（避免双加）。
- **UI**：新增按钮不触碰现有按钮逻辑。

## 6. 用户确认记录（2026-08-20）

1. 自动战斗按钮在结算/投降菜单等全屏界面打开时**隐藏**（与安卓按钮一致，纳入 `_set_mobile_buttons_visible` 逻辑但双端生效）。
2. 单机开自动 = AI 对 AI 观战，**接受**。
3. 执行节奏沿用单机 AI 动作延迟（一拍一动作，可观察，不加速动画）。
4. 图标"主机"（游戏手柄）认可。
5. 关闭自动战斗**立即清空未执行队列**。
6. 待测试无问题后，并入 1.7.5 一起提交发布。
7. 单机 AI 回归：能测清楚就行（复用临时 test autoload 模式 / 探针均可）。

## 6.1 用户问题答复（研究结论，2026-08-20）

**Q1 回合内已操作几步后中途开自动，会不会有问题？**
- 已定位 2 处守卫缺口 + 1 处残留清理，实施时修复：
  - `_execute_move`（AIController.gd:210）**无 move_used 守卫** → 玩家已移动角色会被 AI 再移动一次。补守卫。
  - `_execute_skill`（AIController.gd:305）**无冷却守卫且无行动次数守卫**（SkillEffect.execute_active 只校验目标/范围，不查冷却）→ 玩家已放技能角色会被 AI 重复释放。补：`current_cooldown > 0` 跳过 + `attack_used 且无额外` 跳过（与 main._server_execute_skill:925 同构）。
  - 已有守卫无需补：`_execute_attack`（attack_used ✓）、`_execute_card`（手牌/能量 ✓）。
- 玩家移动动画残留无冲突：AI `_execute_move` 瞬移后 `move_toward_target` 自动收尾（is_moving→false）。
- 开自动瞬间执行 UI 清理：`main.cancel_targeting()` + `main.unselect_character(null, true)`。
- 预期效果：开自动瞬间 AI 重新规划整回合，玩家已消耗资源（行动/移动/手牌/能量/冷却）由执行层守卫自然跳过，不重复执行。

**Q2 单机敌方永远 AI 操作；单机玩家/联机双方开启后 AI 只接管本端，不串场？**
- 对。`_ai_controls(side)`：`(is_ai_mode and side=="client") or (auto_battle_self and side==本端方)`；联机 is_ai_mode=false → 只受 auto_battle_self 影响。
- 实施关键点（防串场）：AIController 规划前**显式设置** `AIStrategist.ai_side`（同一进程控制双方时每回合切换两次）；pid 统一走 `get_pid(side)`（host→1、client→联机 client_peer_id/单机 2），`_execute_card` 的硬编码 `AI_PID` 必须改。

**Q3 其他问题/预期效果（补充确认）**
- 联机对端**看不到**本端自动战斗状态（本端变量），对端只见角色自行行动。
- 联机 AI 操作全部走 rpc，服务端权威校验（发送者/冷却/行动次数）原样生效，不破坏越权防护。
- 战斗结束（GAME_OVER）AIController 自动停止（相位变化清队列 + `_is_ai_turn` 返回 false）。
- 开自动后**本端操作锁定**（推荐）：按钮切换时禁用本端移动/攻击按钮 + 取消选中/选卡；关自动恢复。防玩家与 AI 竞争操作（竞争虽被执行层守卫容忍，但体验混乱）。
- 手牌会被 AI 使用（消耗本端能量）——预期行为。
- AI 对 AI 观战时镜头沿用现有"玩家回合聚焦"逻辑（单机玩家=host 方）。

## 7. 实施结果（2026-08-20 完成，待用户实测）

已按顺序完成全部 7 步：GlobalGameData 开关 → Strategist 参数化 → AIController 双队列+执行层 → UI 按钮/图标 → 单机回归 → 联机探针 AI 对 AI → 文档+提交。

### 7.1 实现要点

- **GlobalGameData**：新增 `auto_battle_self`（本端开关，无需网络同步）；`reset_battle_state()` 重置为 false（新对局默认手动）。
- **AIStrategist**：新增 `static var ai_side`（规划前由 AIController 显式设置）+ `static func get_pid(side)`（host→1；client→联机 client_peer_id / 单机 2）；`get_ai_alive/get_enemy_alive/get_ally_alive/get_energy/get_hand` 全部按 `ai_side`/`get_pid` 取值；`get_energy_of` 兜底改 `get_pid(ai_side)`。
- **AIController**：
  - `_queues` 字典（side→队列）替代单队列；`_process` 按 `_active_side()` + `_ai_controls()` 决策；`_ai_controls(side)` = 单机 client 方恒真，或 auto 且 side==本端。
  - 执行层补中途接管守卫：`_execute_move` 跳过已移动角色（move_used）；`_execute_skill` 跳过冷却中/行动次数已尽角色（与 `_server_execute_skill` 同构）。
  - 联机分支（is_ai_mode=false 时）：移动/攻击走 `perform_attack_safe`；技能走 `rpc("_server_execute_skill")`（CELL 型转世界坐标）；出牌走 `rpc("_server_play_card")` 且 pid 用 `get_pid(ai_side)`（替换硬编码 `AI_PID`）；结束回合走 `rpc("advance_turn_phase")`。单机（is_ai_mode）保持本地执行原路径。
- **main.gd**：新增 `UI/AutoBattleButton`（右上同行 -200~-160，双端+单机显示，图标 gamepad.png，开自动金色点亮）；`_toggle_auto_battle()` 开启时补建 AIController（联机/战斗中开启场景）、清理残留 UI（取消选中/选卡/移动/攻击模式）+ 锁定本端按钮（`_auto_input_locked`），关闭时恢复；`_set_mobile_buttons_visible` 扩展为包含自动按钮（安卓两按钮仅安卓，自动按钮双端）。

### 7.2 回归验证（全部通过）

- **单机回归**（临时 test autoload）：阶段 A 纯 AI 模式 4 个完整回合推进正常（玩家回合程序化结束、敌方 AI 正常行动）；阶段 B 开自动 + 注入玩家方已消耗状态（移动/行动/技能冷却）→ AI 接管双方至 battle_over，中途接管守卫不重复执行。exit=0。
- **联机探针 AI 对 AI**（真实 ENet 双进程，host/client 各自 `_toggle_auto_battle`）：双端 12 次相位变化（PLAYER_TURN↔ENEMY_TURN 5 轮）后一致 battle_over PASS；AI 出牌/技能/攻击/Buff 全部执行；零 SCRIPT ERROR。
- 语法验证零错误；`gamepad.png` 已导入（生成 .import）。

### 7.3 实施中定位并修复的问题

1. **联机/战斗中开启自动时 AIController 不存在**：`_setup_ai_controller` 原只在 is_ai_mode 分支调用；联机分支缺失 + `reset_battle_state` 清 auto 后玩家战斗中点按钮不会创建控制器。修复：`_toggle_auto_battle` 开启时 `if not get_node_or_null("AIController"): _setup_ai_controller()`。
2. **联机 client 端 AI 出牌守卫全失败**：client 端 `deck_manager` 从未 `init_player`（仅服务端初始化），本地 `get_hand` 恒空 → 出牌全跳过。修复：`_sync_hand` 同步手牌数据结构到 `deck_manager.player_hands`（服务端写回同值无害；仅显示本端手牌逻辑不变）。
3. **中途接管重复执行**：`_execute_move` 无 move_used 守卫、`_execute_skill` 无冷却/行动次数守卫（`SkillEffect.execute_active` 不查冷却）。已补守卫（见 7.1）。
4. **联机 AI 移动位置不同步**（用户实测反馈）：`_execute_move` 直接瞬移（`global_position = world_pos`），玩家移动靠 `_finish_move_to_target` 的 `_sync_position` 广播（BaseCharacter.gd:891），AI 瞬移未广播 → 对端位置滞留。修复：`_execute_move` 联机分支（`not is_ai_mode`）显式 `chara.rpc("_sync_position", world_pos)`。验证：联机探针双端 battle_over 时同角色位置完全一致（708.0,-277.75 等三处），10s 采样差异为 host/client 进程启动时间差（host 早 2s）造成的假象。
5. **客户端卡"等待主机"**（用户实测反馈，概率性）：主机 `_on_client_joined` 在客户端 main.gd 就绪前发出 `_sync_client_peer_id`/`_sync_opponent_name`/`_request_client_setup` 一次性 RPC，客户端场景节点不存在 → RPC 被丢弃 → 客户端 `_show_client_waiting` 永久等待。修复：客户端 `_show_client_waiting` 启动 0.5s 周期重试 `rpc_id(1, "_client_request_state")`（收到 `_sync_opponent_name` 停止）；服务端新增 `_client_request_state` 幂等补发关键同步（已加入则重发，未加入则走 `_on_client_joined`）；`_spawn_client_characters` 加角色存在幂等 + 相位非 NONE 不再重复 `advance_turn_phase`。验证：探针复现竞态（client 延迟 4s 切场景、首次同步 RPC 全丢）→ 重试恢复、client_peer_id 同步、对局正常开始、client 端至 battle_over PASS。
6. **客户端比主机先切场景**（用户追问，验证安全）：连接建立时主机 MainMenu `_on_peer_connected` 必已触发（ENet 服务器先于客户端收到连接确认）→ `pending_client_id` 已设置 → 主机进场景后 0.5s 定时 `_on_client_joined` 时客户端已就绪，RPC 正常到达；客户端重试可提前触发 `_on_client_joined`（`_joined_clients` 幂等）。另加兜底：主机 `_ready` 枚举 `multiplayer.get_peers()` 补处理已连接但 peer_connected 已错过、pending_client_id 未设置（如直接调试战斗场景）的客户端。验证：探针（client 立即连+切场景、host 延迟 3s 切场景）→ host 端 `get_peers` 兜底识别真实 client_peer_id、客户端正常至 battle_over PASS。

### 7.4 UI 布局调整（用户确认，2026-08-20）

1. 手牌/投降/自动战斗三按钮**双端+单机全部显示**（原手牌/投降按钮仅安卓）。`_setup_mobile_buttons` 去掉 `_is_mobile` 门控；`_set_mobile_buttons_visible` 三按钮统一显隐（全屏界面隐藏逻辑不变）。
2. 自动战斗按钮移到三按钮**最左**（offset -320~-280，原 -200~-160；右起：手牌 -280、投降 -240、自动 -320）。
3. 卡牌按钮**点亮**：手牌展开时金色高亮（与自动按钮一致 `Color(1.5,1.1,0.3)`）、收起恢复白色；初始状态同步（手牌默认展开 → 初始即亮）。
4. 快捷键冲突检查：按钮与 F 键（`_toggle_hand`）/ESC 键（`_toggle_surrender_menu`）共用同一处理函数、输入源独立，无双重触发；按钮命中防护沿用安卓同按钮已验证路径；`_apply_safe_area` 在 PC 返回 ZERO（`_active` 仅安卓）无副作用。

### 7.5 已知观察（防御性告警，无害）

- 联机 AI 对局中偶发 `[Warn] 拒绝非当前回合玩家 X 推进回合`：client 端收到回合广播滞后时发出冗余推进请求，服务端权威校验正确拒绝，下一帧同步后自然恢复。对局正常完成、双端一致。属回合边界同步时序的正常防御行为，不改代码。

### 7.6 提交

待用户实测 1.7.5（含自动战斗）通过后，与版本号一并提交发布。本次改动文件：AI/AIController.gd、AI/Strategist.gd、Global/GlobalGameData.gd、Scenes/main.gd、Scenes/scene.tscn、Assets/Icons/gamepad.png（新增）、docs/13-auto-battle.md（新增）。
