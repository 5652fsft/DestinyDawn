# 联机开局同步问题排查报告（docs/14）

> 状态：**修复完成、待人工确认（2026-08-21）** | 目标版本：1.7.6（随下次发布）
> 本文档记录问题复现、根因分析、ready 阶段实施与扩展实战测试记录。
> **探针默认未挂载**：`tests/NetTest.gd` 与 `tests/` 保留复用，需要复测时按 `tests/README.md` 取消 project.godot 的 autoload 注释。
> **待办**：人工双端实测确认 → git 提交推送 → 导出发布（流程见 docs/11）。

## 0. 用户反馈场景（原始描述还原）

| # | 场景 | 现象 |
|---|------|------|
| 1 | A 设备开启自动战斗完成一局**单机**游戏后，创建联机游戏，B 设备加入 | B 未显示自己的角色；A 侧角色（服务端）在 B 端位置不更新；回合仍正常推进 |
| 2 | 成功退出后，B 作为服务端创建联机，A 加入 | 开局 A 能显示全部角色；B 端操作后 A 端显示大量 B 的角色（重复）；一段时间后两端都显示"对方回合"，游戏卡死 |

## 1. 测试环境搭建

- **探针**：`tests/NetTest.gd`（autoload 脚本，`--nettest=<role>:<scenario>` 启用，默认未挂载）。
- **运行器**：`tests/run_case.ps1`（双进程 ENet 真实对局，headless，日志落盘 `tests/logs/`）。
- **场景**：s0 干净对照 / s1 host 残留单机状态 / s1full 真实先打单机再开联机 / s2 client 残留单机状态 / s3 client 延迟进场。
- **自动化**：双端自动战斗（AI 对 AI），相位/角色/位置周期采样，卡死检测（90s 无相位变化或连续非本端回合 → 快照退出）。

## 2. 静态分析（实证前的代码审查结论）

### 2.1 根因 A：`is_ai_mode` 状态残留（主因，覆盖两个场景）

`GlobalGameData.is_ai_mode` 全项目**只有** `Menus/MainMenu.gd:239`（单机按钮 `_on_solo_pressed`）被置为 `true`，
而 `_on_host_pressed`（开房）与 `_on_connect_to_room`（加入）**均未将其重置为 `false`**；
`reset_battle_state()` 也不重置该标志。因此：

> 设备在**同一进程**里打完一局单机（不重启游戏）后开联机或加入联机，战斗场景 `main.gd:_ready` 会走
> `if GlobalGameData.is_ai_mode:` 的单机分支，即使该进程已挂 ENet peer —— 形成"**带联机 peer 的单机 AI 对局**"。

由此产生的连锁问题（与用户现象逐条对应）：

| 现象 | 机制 |
|------|------|
| 场景1：B 未显示自己的角色 | host 处于 AI 单机分支：`_ready` 已按 AI 流程生成 `ClientCharacter_*`（AI 队），当 B 的 `_client_send_setup` 到达时，`_spawn_client_characters` 的幂等守卫（`client_characters` 非空即返回）**直接吞掉** B 的角色生成与 `_spawn_character_remote` 广播 → B 永远收不到自己的角色 |
| 场景1：A 侧角色位置不更新 | host 的 AI 移动走 `_execute_move` 瞬移（`is_ai_mode` 分支不广播 `_sync_position`，v1.7.5 只在 `not is_ai_mode` 分支补了显式广播）→ B 端看到 A 的角色定在原地 |
| 场景1：回合正常推进 | host 的 AI 单机回合机照常跑，且因 host 挂着 peer，`advance_turn_phase` 会 `rpc_id(0, "_sync_turn_phase")` 广播到 B → B 的回合指示器跟着动 |
| 场景2：A 开局显示全部角色 | client（A）处于 AI 单机分支：本地按自己队伍 + AI 队伍生成 6 个角色 |
| 场景2：A 端大量重复的 B 角色 | A 的本地角色外，服务端（B）正常执行 `_on_client_joined`/`_spawn_client_characters` 还会向 A 广播 `_spawn_character_remote`（Host×3 + Client×3），与 A 本地角色重名 → Godot 自动改名生成重复节点（如 `ClientCharacter_0@2`）→ A 端画面出现"好多角色" |
| 场景2：双端"对方回合"卡死 | 两端各自跑一套回合机（A 的 AI 单机机 + B 的正常服务端机），互相通过 `_sync_turn_phase`/`reset_character_state`/`draw_for_new_turn` 广播覆盖对方状态（`_sync_turn_phase` 无发送者/会话校验），最终出现 A 端 `(PLAYER_TURN, host_turn=true)` 与 B 端 `(ENEMY_TURN, host_turn=true)` 的交叉状态：按 `is_my_turn()` 两端都非本端回合、两端角色相位都是 Wait、无人能推进 → 卡死 |

### 2.2 根因 B：重同步路径不补发主机角色（次要，独立于残留状态）

v1.7.5 防竞态修复中，客户端"等待主机"重试 `_client_request_state` 只补发
`_sync_client_peer_id` / `_sync_opponent_name` / `_request_client_setup` 三个同步，
**没有补发 `_spawn_character_remote`（主机 3 个角色）**。若客户端场景就绪晚于主机首次加入处理
（移动端加载慢等"小概率"情形），首次广播被丢弃后客户端**永久缺失主机角色**：
看不到敌方、主机角色位置"不更新"（节点不存在）、而自己的角色与回合正常。

### 2.3 其他观察（防御性，非本次必改）

- `_sync_turn_phase` / `reset_character_state` / `draw_for_new_turn` 等广播无会话标识，任意一端（含残留状态端）都能覆盖对端。
- `MainMenu._on_peer_disconnected`（lobby 内断线）不重置 `pending_client_id`，极端时序下可能带入下一局。
- `MainMenu._on_host_pressed` / `_on_connect_to_room` 不显式设置 `is_ai_mode=false`（即根因 A 的修复点）。

## 3. 实证结果（双端真实 ENet 对局，headless，日志见 `tests/logs/`）

### 3.1 s0 对照组（干净开局）—— 通过

- 双端各 3+3 角色、位置/HP/相位同步正常，AI 对 AI 完整对局，双端一致 GAME_OVER 退出（码 0）。
- 探针与运行流程有效。

### 3.2 s1：host 残留 `is_ai_mode=true`（用户场景 1）—— 完整复现

> 另以 **s1full（用户完整路径）** 复现：host 真实打完一局单机自动战斗（AI 对 AI 至 battle_over）→ 返回主菜单（`is_ai_mode=true` 残留，探针日志确认）→ 创建联机房间 → B 加入。结果与 s1 完全一致：host 进入战斗场景快照为 `is_ai_mode=true has_peer=true`（联机局仍走 AI 单机分支），B 端全程 `chars=3`（仅 HostCharacter_0..2，**无自己的角色**），host 的 AI 单机机跑完整局并广播 GAME_OVER。**用户场景 1 按真实操作路径 100% 复现。**

| 现象 | 日志证据（tests/logs/s1_*.log） |
|------|------|
| 主机进入 AI 单机分支 | `[NetTest] 进入战斗场景 \| is_ai_mode=true ...`；`[Mode] AI 模式初始化开始`；`[AI] AI 队伍: ["zephyr","silverwolf","karrigan"]`（AI 随机队，非 B 的队伍） |
| **B 未显示自己的角色** | 客户端全程 `chars=3 ["HostCharacter_0..2"]`，**无 ClientCharacter_***；B 的 `_client_send_setup` 被 `_spawn_client_characters` 的幂等守卫吞掉（`client_characters` 已被主机 AI 分支生成的 AI 角色占满）→ 不生成、不广播 |
| 回合正常推进 | 主机 AI 单机机照常跑，`advance_turn_phase` 借 ENet peer 广播 `_sync_turn_phase`，B 端相位跟随；B 的 AI（0 角色）空转，`rpc(advance_turn_phase)` 被主机机拒绝：`[Warn] 拒绝非当前回合玩家 X 推进回合` |
| 位置"不更新"（机制澄清） | 角色位置由 `MultiplayerSynchronizer`（角色场景内，同步 `.:position`）**自动同步**——主机角色一旦被移动，B 端会收到（探针中主机 AI 对 AI 移动时 B 端位置确实跟随）。用户场景 1 中 A 开联机后 **host 侧无人操作**（auto 被 `reset_battle_state` 关闭、A 手动操作少）→ 主机角色从未移动 → B 端看到位置"不更新"——**是"角色根本没动"，不是同步失效** |

### 3.3 s2：client 残留 `is_ai_mode=true`（用户场景 2）—— 完整复现

| 现象 | 日志证据（tests/logs/s2_*.log） |
|------|------|
| A（client）进入 AI 单机分支 | `[NetTest] 进入战斗场景 \| is_ai_mode=true is_host=false ...` |
| **A 端显示大量 B 的角色（重复）** | A 端 `chars=12`：本地 AI 机 6 个（Host/ClientCharacter_0..2）+ **B 的 6 个角色副本**（`@CharacterBody2D@20..28`，位置=B 端角色出生点；B 的 `_on_client_joined`/`_spawn_client_characters` 广播到达 A，与本地角色重名 → Godot 自动改名，且与 `MultiplayerSpawner`（scene.tscn `spawn_path=../Characters`）自动生成通道叠加） |
| **双端回合状态交叉 → 卡死** | 两端各跑一套回合机，互相用 `_sync_turn_phase`/`reset_character_state`/`draw_for_new_turn` 覆盖对方状态：A 端长时间停在 `ENEMY_TURN host_turn=false my_turn=false`（"对方回合"）；B 端机器独立跑完结算退出（码 0），A 端仍卡死直至收到 B 的 GAME_OVER 广播才退出——用户实测"两端都显示当前非自己回合 → 卡死"即此交叉态的终局（手动对局下双端都会卡住） |

### 3.4 s3：客户端延迟 4s 进场（根因 B）—— 复现

- 客户端进场前，主机首次 `_on_client_joined` 的 4 个一次性 RPC（含 `_spawn_character_remote`×3）全部丢弃。
- 客户端"等待主机"重试 `_client_request_state` 只补发 `_sync_client_peer_id`/`_sync_opponent_name`/`_request_client_setup`，**不补发主机角色 spawn**。
- 结果：客户端全程 `chars=3`（只有自己的 ClientCharacter），**主机角色永久缺失**、看不到敌方；对局照常进行至 GAME_OVER。
- 结论：这是"开局小概率"缺失角色的第二个独立缺口（与根因 A 无关，纯时序竞态；移动端场景加载慢时更易触发）。

### 3.5 排查过程中的关键机制澄清（重要）

1. **角色位置是"双通道同步"**：`MultiplayerSynchronizer`（每个角色 tscn 内，`SceneReplicationConfig: ".:position"`，replication_mode=ALWAYS）自动同步 position + 手动 `_sync_position` RPC（`BaseCharacter`/AIController）。实测自动通道生效（引擎 C++ 写入，表现为客户端收到非 authority 角色的位置跳变、`target_world`/`velocity` 不变）；`_sync_position` 手动通道在 AI 模式下不触发。正常流程下双通道同值写入无冲突，但 ALWAYS 模式每帧同步（含无变化时）存在带宽/写入冗余（探针观测到客户端高频同值 transform 写入）。
2. **`MultiplayerSpawner`（scene.tscn，`spawn_path=../Characters`）会自动生成权威端新增的角色**，与手动 `_spawn_character_remote` 构成"双通道生成"。s2 中 A 端出现的 `@CharacterBody2D@20..28` 副本与此机制相关。正常流程（s0）未见重复，残留状态流程（s2）下叠加出重复角色——建议后续统一生成通道或明确禁用一个。
3. `_spawn_client_characters` 的幂等守卫基于"`client_characters` 非空"这一旁路状态，被根因 A 直接利用（AI 机已生成 client 角色 → B 的角色永不被生成）。

## 4. 开局同步稳定性研究（含 ready 阶段方案）

### 4.1 现状开局链路（v1.7.5）

```
客户端连接 → 主机 MainMenu peer_connected → 双端切战斗场景
主机 _ready：本地生成 Host×3；0.5s 定时 _on_client_joined
  ├─ rpc_id: _sync_client_peer_id / _sync_opponent_name / _request_client_setup / _spawn_character_remote×3
客户端 _ready：_show_client_waiting + 0.5s 周期 _client_request_state（防一次性 RPC 丢失）
客户端响应 _client_send_setup(队伍,卡组) → 主机 _spawn_client_characters：
  本地生成 Client×3 + 广播 _spawn_character_remote×3 → advance_turn_phase 开局
```

脆弱点：一次性 RPC 丢失靠"重试+补发"兜底，但补发不完整（根因 B）；无显式开局栅栏；
角色生成幂等依赖 `client_characters` 非空这种旁路状态（被根因 A 直接利用）。

### 4.2 方案对比

| 方案 | 复杂度 | 风险 | 覆盖 |
|------|--------|------|------|
| **A. 修复入口状态 + 补全补发**（最小）：主机/加入流程置 `is_ai_mode=false`；`main._ready` 防御（挂 peer 时强制非 AI 模式）；`_client_request_state` 补发主机角色；`_spawn_client_characters` 幂等改按"已生成角色名集合"判断 | 低（~30 行） | 低 | 根因 A+B，本次两个用户场景 |
| **B. ready 阶段（用户提议）**：设队伍/卡组 → 主机广播**完整初始快照**（双方角色定义：场景路径/名字/pid/出生点，含主机角色）→ 客户端按快照生成本地全部角色并回执 `_client_ready` → 主机收齐后（或 5s 超时兜底）才 `advance_turn_phase` | 中（新状态机 + 快照 RPC，~100 行） | 中（需回归开局时序） | 根因 A+B + 一切"开局 RPC 丢失"类竞态；开局确定性最强 |
| **C. 会话标识（epoch）**：`_sync_turn_phase` 等广播带本局随机 session_id，不符即忽略 | 低 | 低 | 防"双回合机互相覆盖"（根因 A 的终局表现），单用不能防 A 本身 |

**推荐**：A 立即修（治本次报告的两场景），B 作为后续稳定性升级（与 A 兼容，B 的快照天然替代"补发"逻辑，
`_client_ready` 回执即开局栅栏）。C 可作为 B 的配套加固。

### 4.3 ready 阶段设计要点（方案 B 细化，已按最终实现修正）

1. **不加新相位**：复用 `NONE` 相位 + 开局栅栏标志（`_battle_ready_clients`），相位机零改动。
2. 主机 `_on_client_joined` 不再逐条 rpc_id 主机角色，客户端 `_client_send_setup` 到达后由主机构建**完整快照**并广播 `_sync_initial_snapshot(host_chars, client_chars)`（含角色场景路径、命名、owner_pid、出生点）。
3. 客户端收到快照：按快照全部生成（本地节点名 = 快照名，天然防重名重复；已存在同名角色跳过，快照重发安全）→ 生成完毕后 `rpc_id(1, "_client_ready")`。
4. 主机维护 `_battle_ready_clients: Dictionary[pid→bool]`；全部就绪（或 5s 超时兜底 `_start_ready_timeout`）→ `advance_turn_phase()`；`_client_request_state` 重试经 `_client_send_setup` 触发幂等快照重发（覆盖根因 B）。
5. 快照阶段同时校验队伍/卡组合法性（长度、重复 id），失败可提示重选（后续可选）。
6. 对端掉线/超时处理沿用现有断连结算。

### 4.4 验证方式

- 探针回归：s0 全自动对局双端一致至 GAME_OVER；s1/s1full/s2 修复后不再出现缺角色/重复/卡死；
- s3 修复后客户端不再缺失主机角色；
- 新增"客户端延迟 4s/8s 进场"边界用例；双端随机先手多轮复跑。

## 5. 实施记录（2026-08-21，用户确认采用 ready 方案）

> 用户决策：**采用方案 B（ready 阶段 + 初始快照）**；**保留引擎自带 `MultiplayerSpawner`**（不做删除，实测正常流程下 Spawner 不产生角色、不产生重复，零干扰）。

### 5.1 已实施改动（逐文件）

| 文件 | 改动 |
|------|------|
| `Menus/MainMenu.gd` | `_on_host_pressed` / `_on_connect_to_room` 置 `GlobalGameData.is_ai_mode = false`（根因 A 入口修复） |
| `Scenes/main.gd` | ① `_ready` 防御：挂 ENet peer 且残留 `is_ai_mode=true` 时强制关闭并告警（根因 A 兜底）；② **ready 阶段**：`_client_send_setup` 到达后由主机构建完整初始快照（`_build_initial_snapshot`：双方角色场景/名字/pid/出生点）→ 本地生成（`_spawn_characters_from_snapshot`，按角色名集合幂等）→ 广播 `_sync_initial_snapshot` → 客户端按快照生成并回执 `_client_ready` → 主机 `_try_start_battle` 全部就绪（或 5s 超时兜底 `_start_ready_timeout`）才开局；③ 重同步 `_client_request_state` 改为触发幂等快照重发（根因 B：延迟进场客户端补全全部角色）；④ 删除 `_spawn_character_remote` / `_spawn_client_characters`（被快照取代，含原 `client_characters` 非空的旁路幂等守卫） |
| `docs/05-rpc-conventions.md` | 同步新增 RPC 表项（见 5.3） |

### 5.2 ready 阶段流程（实施后）

```
客户端连接 → 主机 MainMenu peer_connected → 双端切战斗场景
主机 _ready：本地生成 Host×3；0.5s 定时 _on_client_joined
  ├─ rpc_id: _sync_client_peer_id / _sync_opponent_name / _request_client_setup
客户端 _ready：_show_client_waiting + 0.5s 周期 _client_request_state（防一次性 RPC 丢失）
客户端响应 _client_send_setup(队伍,卡组) → 主机：
  ├─ 存 client_team + init 卡组 → 构建快照（host×3 + client×3）
  ├─ 主机本地生成（角色名幂等）→ rpc 广播 _sync_initial_snapshot
客户端：按快照生成全部 6 角色（幂等）→ rpc_id(1, _client_ready)
主机：全部客户端就绪（或 5s 超时兜底）→ advance_turn_phase 开局
```

- 快照重发幂等：客户端经 `_client_request_state` 重同步时再次 `_client_send_setup` → 主机重发快照 → 已存在角色跳过、回执再发无害（`_battle_ready_clients` 幂等）。
- 保留 `MultiplayerSpawner`（scene.tscn `spawn_path=../Characters`）与 `MultiplayerSynchronizer`（角色内 position 同步）——实测正常流程不产生重复/冲突，位置同步为双保险。

### 5.3 新 RPC 一览（docs/05 同步）

| RPC | 注解 | 方向 | 说明 |
|-----|------|------|------|
| `_sync_initial_snapshot(host_chars, client_chars)` | `any_peer, reliable` | Server → Client | 开局完整快照（角色场景/名字/pid/出生点），幂等重发安全 |
| `_client_ready()` | `any_peer, reliable` | Client → Server | 客户端按快照生成完毕的回执（服务端 `_battle_ready_clients` 幂等） |

### 5.4 回归验证（全部通过，日志见 `tests/logs/`）

| 场景 | 结果 |
|------|------|
| s0 对照 | 快照广播 → 就绪回执 → 开局栅栏 → 双端 3+3 → 完整对局 → 一致 GAME_OVER ✅ |
| s1（host 残留） | 注入的 `is_ai_mode=true` 被清除（MainMenu 入口生效）→ 正常服务端流程 → B 端 3+3 全角色 ✅ |
| s1full（完整用户路径） | 真实单机打完 → 回菜单（残留）→ 开联机 → **联机局快照 `is_ai_mode=false`** → 正常对局 ✅ |
| s2（client 残留） | 残留清除 → **无重复角色**（chars=6）→ 无卡死 → 双端正常结算 ✅ |
| s3（延迟 4s 进场） | 首次同步全丢 → 重同步触发快照重发 → **补全全部 6 角色**（不再缺失主机角色）✅ |

### 5.5 扩展实战场景测试（2026-08-21 追加，全部通过）

| 场景 | 内容 | 结果 |
|------|------|------|
| s4 | 客户端开局 8s 后进程退出（模拟中途掉线） | host：`客户端 X 断线，判定其投降` → 结算 ✅ |
| s5 | 客户端连接后永不进场/永不响应编队（模拟卡死客户端） | host：**30s setup 超时** `客户端未上报编队，按投降结算`（新增机制，见 5.6-3）✅ |
| s6 | 客户端延迟 12s 进场（ready 超时兜底 + 重同步补全组合） | 快照重发补全 6 角色 → 对局完整至 GAME_OVER ✅ |
| s7 | 客户端开局 12s 后投降（`_confirm_surrender`） | 双端一致结算：`投降，胜利方: 服务端`（client 投降 → host 胜）✅ |
| s8 | 双端同进程连续打两局（打完回菜单再开） | 两局均完整对局；`is_ai_mode`/peer/卡组无残留 ✅ |
| s9 | 开局 8s 后才开自动战斗（中途接管） | 8s 内对局静止 → AI 接管后正常推进至结算 ✅ |
| s11 | 主机开局 8s 后进程退出（模拟中途掉线） | client：`服务端断开连接，判定其投降` → 本端获胜结算（对称处理，见 5.6-1）✅ |

### 5.6 扩展测试发现并处理的问题

1. **断线结算对称化（行为变更，用户确认）**：原实现主机掉线时客户端"提示并返回主菜单"；现改为与客户端掉线对称——**任意一方掉线均按对方投降结算**（客户端掉线→主机胜；主机掉线→客户端胜，`_on_peer_disconnected` 双端分支同构）。
2. **投降日志语义 bug（已修）**：`show_battle_result` 的 `[Phase] 投降，胜利方: X` 原用 `i_win`（本端是否胜）直接判断字符串，客户端进程打印反（仅日志误导，结算不受影响）；改为 `host_won = i_win == is_host` 绝对语义。
3. **ready 方案缺口：setup 等待无超时（已修）**：客户端连接后若永不响应 `_client_send_setup`（卡在加载/异常），原实现主机无限等待（600s 总超时兜底）。新增 `_start_setup_timeout`：30s 未上报编队 → 按"客户端未就绪"投降结算（移动端极端加载慢 12s 实测不误伤，s6 验证）。
4. **已知遗留（记录，建议后续）**：客户端瞬断后快速重连（网络抖动/WIFI 切换）会被主机立即判投降结算，**无重连容忍窗口**（s6 首次运行意外暴露：探针误重连被 host 判投降）。后续可评估"断线后 N 秒重连窗口"或"断线不立即结算、等待短重连"。
5. **已知观察（无害）**：host 进程退出（quit）时场景树销毁触发角色 `_exit_tree` → `unregister_character` → `check_victory` → `rpc(advance_turn_phase)` 可能在 peer 关闭前发出 GAME_OVER 广播，客户端可能收到结算广播——行为无害（客户端正常结算），属"退出时意外广播"。
6. **探针自修**：s4/s11 自杀检测加 `not scene._battle_over` 守卫（防对局已结算还自杀）；s3/s5/s6 延迟进场场景禁用加入重试（防误关已成功的连接）。

### 5.7 遗留观察（非本次必改）

- `MultiplayerSynchronizer` 的 ALWAYS 模式每帧同步 position（含无变化时），存在带宽/写入冗余；与手动 `_sync_position` 双通道同值写入。保留作为双保险，后续可评估按需/间隔同步。
- ready 超时兜底 5s：客户端异常不回执时主机仍开局（防卡死），异常客户端后续经重同步补全。
- 测试探针 `NetTest` autoload 与 `tests/` 为临时产物，发布前移除（或纳入 gitignore）。

## 6. 后程同步问题排查记录（2026-08-21 追加）

### 6.1 用户反馈

联机对局**后程**有概率出现伤害/位置/血量同步问题，甚至**双端都结算显示胜利**。

### 6.2 复现与根因（实证）

- 探针 AI 对 AI（修复前）：对局结束快照对比——host 端 `HostCharacter_2 hp=44` 存活（服务端胜利），client 端 `chars=0` 全灭（客户端胜利）——**双端都胜利**；另有对局卡死（客户端全灭等不到服务端广播、服务端 AI 无目标空转）。
- **根因链**：`perform_attack` 为 `any_peer, call_local`——**伤害在攻击端/服务端各自独立应用**（`take_damage` 内 MARK/防御/护盾计算、死亡判定、计数全端独立执行）→ 攻击端（客户端）本地先掉血/判死；服务端执行时**守卫拦截**（目标已死/相位不符/次数已用——客户端本地视图滞后于服务端权威视图）→ 服务端未应用伤害**且不广播 `_sync_hp` 修正** → 双端 HP/死亡判定漂移 → 后程（低血量、死亡多、回合切换频繁）累积 → 客户端本地结算与服务端不一致 → **双端都胜利 / 卡死**。
- 拦截高发原因：AI（客户端本地）基于**本地视图**（相位/目标 hp/行动计数）决策，与**服务端权威视图**存在同步延迟窗口（reliable rpc 排队 + 处理顺序）；AI 节奏 0.5s/动作 + 回合切换瞬间 + 双端同时操作 → 拦截是常态。**拦截本身是正确防御，危害在于拦截的副作用（攻击端本地已应用的伤害/计数未回滚）。**
- **历史关联**：此即 v1.7.5 记录中"karrigan 掉血 bug（客户端普攻服务端角色有概率不掉血，快结束/仅剩单角色时更易触发）"的同一根因——当时探针 35 轮未复现（AttackDebug 零拦截、结论指向网络竞态）；本次以**双端日志对比分析**（`tests/analyze.ps1`：结算/最终态对比）在首轮即复现"双端都胜利"分裂，并定位到"伤害三端独立应用 + 拦截不广播修正"的机制。

### 6.3 修复：伤害应用服务端权威化

`BaseCharacter.take_damage` 开头加守卫：

```gdscript
if not GlobalGameData.is_ai_mode and not multiplayer.is_server():
    return
```

- 伤害/MARK/防御/护盾计算、死亡判定、统计**仅在服务端执行**；客户端只收 `_sync_hp`/`_sync_shield` 广播应用结果。
- 攻击动画 `_play_attack_animation` 广播保留（受击反馈）；飘字/死亡特效在客户端暂缺（可后续广播优化）。
- 所有伤害路径已核查统一走 `take_damage_safe`/rpc：普攻（perform_attack）、技能（SkillEffect）、卡牌（`_rpc_take_damage`）、DOT/HOT（process_buffs）、治疗、M1DorG 回归、投降；单机（is_ai_mode）与断线结算（直接置 hp）不受影响。
- 行动计数（attack_used）仍为双端独立（客户端预测，服务端权威拦截时不计数）——回合内 UI 预测偏差，下回合 `reset_character_state` 重置，影响小（可后续再权威化）。

### 6.4 验证（修复后 4 轮 AI 对 AI，全部通过）

| 项 | 结果 |
|----|------|
| 结算一致性 | 4 轮双端胜利方完全一致（修复前首轮即分裂"双端都胜利"）|
| 服务端攻击拦截 | 4 轮零拦截（修复前存在）|
| 最终态（BATTLE-OVER 快照） | 双端存活角色与 hp 一致（仅存 GAME_OVER 后 `hp=0` 残影：客户端收 `_sync_hp(0)` 时 battle_over 已置位、unregister 被拦截——无害，结算界面不可见）|
| 采样 hp 漂移 | 仍有采样差值——为双端 1s 采样相位差 + 广播延迟窗口的**假象**（最终态一致证明无真实漂移）|
| s1/s2 回归 | 结算一致、零拦截、开局修复未破坏 ✅ |
| s12（先联机再单机，新增） | 联机局完整 → 回菜单（`is_ai_mode=false`）→ 单机局正常（AI 模式初始化）→ 完整结束——**联机残留不影响单机** ✅ |

### 6.5 遗留与建议

1. ~~飘字/死亡特效客户端缺失~~ —— **已实现（特效广播）**：新增 `_play_damage_fx(amount, kind)`（0=伤害飘字+震屏 / 1=治疗飘字+音效 / 2=护盾飘字+音效）与 `_play_death_fx()`（死亡特效+音效），服务端 `take_damage` 应用伤害后 `_broadcast_damage_fx`/`_broadcast_death_fx` 广播（`not is_ai_mode` 且存在对端时才广播，单机不受影响）；客户端只做表现，隐藏仍由 `_sync_hp` 处理。验证：s0/s7 回归双端结算一致、客户端零 SCRIPT ERROR。
2. 行动计数权威化（拦截时服务端广播计数修正，消除客户端回合内预测偏差）——可选优化。
3. 分析脚本 `tests/analyze.ps1`：双端日志对比（结算/拦截/最终态），ASCII 编写（避开 PS 编码坑）；采样漂移仅作参考，**最终态对比为准**；投降场景快照可能早于最后一批 `_sync_hp` 到达（角色 hp 归零稍晚），属已知时序。

### 6.6 AI 额外行动次数浪费（2026-08-21 追加，已修）

- **问题**：存在额外行动次数（技能如芝士仓鼠 [动作如潮]、击杀被动如 [钢铁直架]）的角色，AI 有时只攻击一次就结束回合，浪费额外次数。
- **根因**：`AIStrategist.plan_unit` 的 `_plan_attack` 每个角色只规划 **1 个攻击动作**（不感知 `_extra_attacks`）；执行层队列耗尽即 `_end_phase`——额外次数从未被使用。
- **修复（执行层动态补攻击）**：`AIController._execute_current_action` 的 attack 分支执行后，若 `_has_attack_left(chara)`（基础次数未用或 `_get_extra_attacks() > 0`）且相位仍 Active，则 `_pick_attack_target`（当前格射程内 hp+护盾最高者；无目标返回 null 保证收敛）补一个攻击动作到队列前端——额外次数用尽为止、目标实时重选。
- **验证**：AI 对 AI 日志确认——芝士仓鼠 [动作如潮] 额外次数消耗后补攻击继续用掉基础次数；[钢铁直架] 击杀获得额外行动后立即追加攻击下一目标；s0/s1 回归结算一致、零拦截、无卡死。
- **防循环设计**：补攻击仅当 `_has_attack_left` 且 `_pick_attack_target` 有射程内目标；目标死光/超射程返回 null 即停止；每次成功攻击消耗 1 次次数（收敛）。
- **测试基建**：新增 `tests/mount_probe.ps1` / `tests/unmount_probe.ps1`（挂载/恢复探针 autoload 的一键脚本，行级匹配 + 验证，避免手动改 project.godot 的注释行丢失问题）。

## 7. 附：测试产物

- 探针：`tests/NetTest.gd`（autoload 脚本，`--nettest=<role>:<scenario>` 启用，默认未挂载）
- 运行器：`tests/run_case.ps1`（双进程 ENet 真实对局，headless，自动战斗 AI 对 AI）
- 场景：`s0` 干净对照 / `s1` host 残留 / `s1full` 完整用户路径 / `s2` client 残留 / `s3` 延迟 4s 进场 / `s4` 客户端掉线 / `s5` 客户端永不进场 / `s6` 延迟 12s 进场 / `s7` 中途投降 / `s8` 连续两局 / `s9` 延迟开自动 / `s11` 主机掉线
- 日志：`tests/logs/<scenario>_host.log` / `_client.log`（UTF-8）
- 复测：`pwsh tests/run_case.ps1 -Scenario <s0|s1|s1full|s2|s3|s4|s5|s6|s7|s8|s9|s11>`
