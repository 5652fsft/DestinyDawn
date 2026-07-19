# 网络同步 / RPC 模式规范

## 权限模型

| 角色 | 权限 |
|---|---|
| **Server (Host, peer 1)** | 最终决策者：生成角色、初始化卡组、推进回合、验证卡牌 |
| **Client (peer 2+)** | 只能控制己方角色、发送编队/卡组、发起卡牌使用请求 |

检查方法：

```gdscript
if not multiplayer.is_server():
	return  # 仅服务端执行
```

## RPC 注解模式

### 模式一：`@rpc("authority", "call_local", "reliable")`

| 属性 | 含义 |
|---|---|
| `authority` | 只有服务器可以**发起**此 RPC |
| `call_local` | 发起者本地也执行一遍 |
| `reliable` | 可靠传输 |

**用途**：服务端发起的状态变更，本地和远程都需要执行。

**示例**：`DeckManager.draw_cards()`, `EnergySystem.set_energy()`

### 模式二：`@rpc("any_peer", "call_local", "reliable")`

| 属性 | 含义 |
|---|---|
| `any_peer` | 任何 peer 都可以发起 |
| `call_local` | 发起者本地也执行 |

**用途**：战斗动作（攻击、受伤、移动），双方都需要看到结果。

**示例**：`perform_attack()`, `take_damage()`, `_sync_hp()`, `advance_turn_phase()`

### 模式三：`@rpc("any_peer", "reliable")`

| 属性 | 含义 |
|---|---|
| `any_peer` | 任何 peer 可以发起 |
| 无 `call_local` | 仅在远端执行 |

**用途**：角色生成、编队同步等一次性操作。

**示例**：`_spawn_character_remote()`, `_client_send_setup()`

### 模式四：`@rpc("call_local", "reliable")`

| 属性 | 含义 |
|---|---|
| 无 `authority` | 任何 peer 发起（通常由服务端调用） |
| `call_local` | 发起者也执行 |

**用途**：状态同步广播。

**示例**：`_sync_turn_phase()`, `_sync_energy()`, `_sync_hand()`

---

## 同步模式对照

### 回合阶段同步

```
Server: advance_turn_phase()
  → check_victory() → if game over: rpc_id(0, "_sync_turn_phase", GAME_OVER, host_turn, battle_stats)
  → else: change phase → rpc_id(0, "_sync_turn_phase", phase, host_turn)
  → Client: _sync_turn_phase() updates local state + UI
```

### 角色状态同步

| 状态 | RPC | 频率 |
|---|---|---|
| HP | `rpc_id(0, "_sync_hp", hp)` | take_damage / heal 后 |
| Shield | `rpc_id(0, "_sync_shield", shield)` | shield 变化后 |
| Buffs | `target.rpc("_sync_buffs", packed)` | BuffManager 每次变更后 |
| Position | `rpc("_sync_position", pos)` + MultiplayerSynchronizer | 移动每帧 |

### 手牌 / 能量同步

```
Server: _execute_play_card()
  → deck_manager.play_card()
  → energy_system.spend_energy()
  → CardEffect.execute()
  → hand = deck_manager.get_hand(player_id)
  → rpc("_sync_hand", player_id, hand)
  → rpc("_sync_energy", player_id, energy)
  → Client: _sync_hand() → hand_panel.play_draw_animation()
  → Client: _sync_energy() → energy bar update
```

### 抽牌同步

```
Server: draw_for_new_turn()
  → deck_manager.draw_cards(1/2, count)            # RPC authority call_local
  → sync_all_card_state()
	 → for pid in [1,2]:
		 rpc_id(0, "_sync_hand", pid, hand)
		 rpc_id(0, "_sync_energy", pid, energy)
```

---

## 多人游戏启动流程

```
Host: _ready()
  → load_defaults_if_empty()
  → _build_team_from_selection()           # 读取 host_team
  → _init_player_card_systems()            # 初始化双方卡组（默认）
  → spawn host characters                  # 生成 HostCharacter_0/1/2
  → peer_connected.connect(_on_client_joined)

Client connects:
  → Host: _on_client_joined(id)
	 → rpc_id(id, "_request_client_setup")   # 请求客户端编队/卡组
	 → re-init card systems
	 → spawn host chars

  → Client: receives _request_client_setup
	 → rpc_id(1, "_client_send_setup", team, deck)

  → Host: receives _client_send_setup
	 → GlobalGameData.client_team = team
	 → deck_manager.init_player(2, deck)     # 使用客户端卡组
	 → _spawn_client_characters(id)          # 生成 ClientCharacter_0/1/2
	 → rpc("advance_turn_phase")            # 开始游戏
```

## 生成角色规则

- Host 角色：命名 `HostCharacter_0/1/2`，权限 = host_id，出生点 = `host_birth_point`
- Client 角色：命名 `Client{id}Character_0/1/2`，权限 = client_id，出生点 = `client_birth_point`
- 角色名称影响阵营判定：`name.begins_with("Host")` → host_characters

## 关键注意事项

1. **不要对 `@rpc` 函数使用 `call_local` + 无 `authority`**：会导致双方都试图处理同一逻辑
2. **不要在 `_ready()` 中调用 RPC**：MultiplayerPeer 可能尚未就绪
3. **`rpc_id(0, ...)`** 广播到所有 peer（包含发送者自己）。配合 `call_local` 使用时，发送者会执行两次——一次来自 `call_local`，一次来自网络接收。需要确保幂等或只处理一次
4. **状态同步始终由服务端驱动**：客户端从不主动修改游戏状态
5. **`_sync_hand` 只发送给手牌持有者**：`if player_id == my_pid` 过滤
