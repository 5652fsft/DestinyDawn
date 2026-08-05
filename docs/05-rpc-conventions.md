# 网络同步 / RPC 规范

## 权限模型

- **Server (peer 1)**：生成角色、初始化卡组、推进回合、验证卡牌
- **Client (peer 2+)**：控制己方角色、发送编队/卡组、发起卡牌使用请求

## RPC 注解模式

| 模式 | 用途 | 示例 |
|------|------|------|
| `@rpc("authority", "call_local", "reliable")` | 服务端发起的状态变更 | `DeckManager.draw_cards`, `EnergySystem.set_energy` |
| `@rpc("any_peer", "call_local", "reliable")` | 战斗动作，双方都要看到 | `perform_attack`, `take_damage`, `advance_turn_phase` |
| `@rpc("any_peer", "reliable")` | 一次性操作，无需本地执行 | `_spawn_character_remote`, `_client_send_setup` |
| `@rpc("call_local", "reliable")` | 状态同步广播 | `_sync_turn_phase`, `_sync_energy` |

## 关键规则

### 1. 单人/联机模式守卫 — 注意短路顺序

所有涉及 `multiplayer.is_server()` 的函数必须将 `GlobalGameData.is_ai_mode` 放在前面：

```gdscript
# ✅ 正确
if not GlobalGameData.is_ai_mode and not multiplayer.is_server():
	return
# ❌ 错误 — AI 模式无 peer，is_server() 抛异常
if not multiplayer.is_server() and not GlobalGameData.is_ai_mode:
	return
```

### 2. RPC 调用必须有 peer 保护

所有 `rpc()` / `rpc_id()` 调用前需检查 `multiplayer.has_multiplayer_peer()`。优先使用 `_safe` 封装：

```gdscript
take_damage_safe(dmg)         # 自动判断 peer
play_vfx_preset_safe("hit")   # 同上
```

### 3. 卡牌与技能均由服务端单次执行

`CardEffect.execute()` 仅在服务端运行（通过 `_server_play_card`），内部用 `take_damage_safe` 广播一次 RPC，不会重复。

主动技能同样由服务端执行：操作端通过 `_server_execute_skill` 转发（目标类型 SELF/NONE 传角色路径，CELL 传格子世界坐标），服务端执行 `use_active_skill`（含 SkillEffect 校验能量/范围/冷却），成功后统一广播 `_sync_skill_state` 与 `_sync_hand`/`_sync_energy`。AI 模式（无 peer）不经 RPC，直接本地执行。

### 4. `call_local` 函数内部不要再调 `rpc()`

`@rpc("any_peer", "call_local")` 已在所有端执行，内部对同一数据的操作应直接调用（或用 `_safe` 封装），否则会重复触发。

### 5. `rpc_id(0, ...)` 配合 `call_local` 时发送者执行两次

需确保幂等或只处理一次。

### 6. 状态同步始终由服务端驱动

客户端从不主动修改游戏状态。`_sync_hand` 只发送给手牌持有者。

### 7. 技能能量消耗定义在 CharacterData

通过 `CharacterData.get_data(id).get("skill_energy", 0)` 读取，不硬编码。技能阻挡查询统一使用 `SkillEffect.get_skill_block_reason()`。

### 8. 技能服务端执行 RPC 一览

| RPC | 注解 | 方向 | 说明 |
|-----|------|------|------|
| `_server_execute_skill(character_path, target_path, cell_pos)` | `any_peer, call_local` | Client → Server | 技能执行入口，仅服务端生效；CELL 技能在服务端建临时 marker 定位 |
| `_sync_skill_state(character_path, cooldown, attack_consumed, skill_name)` | `call_local` | Server → All | 广播冷却/行动点/UI 刷新，全端执行 |
| `_sync_skill_failed(reason)` | `call_local` | Server → Client | 服务端校验失败提示（服务端跳过，避免重复 toast） |

客户端 pid 从角色名解析（`Client{pid}Character_{i}`），统一用 `SkillEffect.get_character_pid()`，**不假设 pid == 2**。
