# 网络同步 / RPC 规范

## 权限模型

- **Server (peer 1)**：生成角色、初始化卡组、推进回合、验证卡牌
- **Client (peer 2+)**：控制己方角色、发起卡牌请求

## RPC 注解模式

| 注解 | 用途 | 示例 |
|------|------|------|
| `@rpc("authority", "call_local", "reliable")` | 服务端发起的状态变更 | `DeckManager.draw_cards`, `EnergySystem.set_energy` |
| `@rpc("any_peer", "call_local", "reliable")` | 战斗动作，双方都需要看到结果 | `perform_attack`, `take_damage`, `advance_turn_phase` |
| `@rpc("any_peer", "reliable")` | 一次性操作，无需本地执行 | `_spawn_character_remote`, `_client_send_setup` |
| `@rpc("call_local", "reliable")` | 状态同步广播 | `_sync_turn_phase`, `_sync_energy` |

## 关键规则

### 1. `multiplayer.is_server()` 注意短路顺序

AI 模式无 multiplayer peer，调用 `is_server()` 前必须确保 `GlobalGameData.is_ai_mode` 在前：

```gdscript
# ✅ 正确：is_ai_mode 在前短路
if not GlobalGameData.is_ai_mode and not multiplayer.is_server():
    return

# ❌ 错误：is_server() 会因无 peer 抛异常
if not multiplayer.is_server() and not GlobalGameData.is_ai_mode:
    return
```

### 2. RPC 调用必须有 peer 保护

所有 `rpc()` / `rpc_id()` 调用前需检查 `multiplayer.has_multiplayer_peer()`，单机/AI 模式走本地调用：

```gdscript
# 使用 _safe 封装（推荐）
target.take_damage_safe(dmg)       # 自动判断 peer 存在
target.play_vfx_preset_safe("hit")  # 同上

# 或手动守卫
if target.multiplayer and target.multiplayer.has_multiplayer_peer():
    target.rpc("_sync_shield", shield)
```

### 3. 卡牌由服务端单次执行

卡牌通过 `_server_play_card`（`@rpc`）调用，仅服务端执行 `CardEffect.execute()`，因此内部 `take_damage_safe` 只会广播一次 RPC。

### 4. 避免 `call_local` + 无 `authority` 时的重复执行

`@rpc("any_peer", "call_local")` 函数内部**不要**再调 `rpc()`（用直接调用或 `_safe` 封装），否则会在所有端重复触发。

### 5. `rpc_id(0, ...)` 注意事项

`rpc_id(0, ...)` 广播到所有 peer + 发送者自己，配合 `call_local` 时发送者执行两次。需确保幂等或只处理一次。

### 6. 状态同步始终由服务端驱动

客户端从不主动修改游戏状态。`_sync_hand` 只发送给手牌持有者（`if player_id == my_pid`）。
