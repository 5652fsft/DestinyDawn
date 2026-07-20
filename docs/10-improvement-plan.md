# 改进规划

## 一、游戏音效系统

### 目标
为游戏添加基本的音效反馈，提升操作手感与沉浸感。

### 实现方案

**技术选型**：使用 Godot 的 `AudioStreamPlayer2D` 节点，创建全局音效管理器作为 autoload。

**文件结构**：
```
Assets/Audio/
├── BGM/           # 背景音乐
│   └── battle.ogg
├── SFX/           # 音效
│   ├── click.ogg        # 按钮点击
│   ├── hover.ogg        # 按钮悬停
│   ├── move.ogg         # 角色移动
│   ├── attack.ogg       # 攻击命中
│   ├── hit.ogg          # 受击
│   ├── skill.ogg        # 释放技能
│   ├── card_play.ogg    # 使用卡牌
│   ├── heal.ogg         # 治疗
│   ├── shield.ogg       # 护盾
│   ├── death.ogg        # 角色阵亡
│   ├── victory.ogg      # 胜利
│   └── defeat.ogg       # 败北
```

**核心组件**：

| 文件 | 说明 |
|---|---|
| `Global/AudioManager.gd` | 音效管理器（autoload），提供 `play_sfx(name)` / `play_bgm(name)` / `set_volume(v)` |
| `project.godot` | 注册 `AudioManager` 为 autoload |

**集成点**：

| 触发时机 | 音效 | 集成位置 |
|---|---|---|
| 按钮点击 | click | `ButtonTheme._up()` 或各按钮 pressed 信号 |
| 角色移动完成 | move | `BaseCharacter.move_toward_target()` 到达目标时 |
| 攻击命中 | attack | `BaseCharacter.take_damage()` 中 |
| 释放技能 | skill | `_active_skill_post_exec()` 或 `SkillEffect` 中 |
| 卡牌释放 | card_play | `_execute_play_card()` 中 |
| 治疗触发 | heal | `take_damage()` 当 damage < 0 时 |
| 护盾触发 | shield | `_execute_shield()` 中 |
| 角色阵亡 | death | `take_damage()` 当 hp <= 0 时 |
| 战斗结算 | victory/defeat | `show_battle_result()` 中 |

---

## 二、动态背景

### 目标
主菜单、编队界面、卡组构筑、设置界面共用一个动态背景（粒子/动画效果），替代当前的静态图片。

### 实现方案

**技术选型**：Godot 的 `GPUParticles2D` 或 `CPUParticles2D`，创建背景场景实例化到各个菜单。

**文件结构**：
```
Scenes/
└── MenuBackground.tscn     # 动态背景场景
Global/
└── MenuBackground.gd       # 背景控制脚本
```

**背景效果建议**：
- 缓慢飘浮的光点（粒子系统）
- 深蓝/紫色色调（与当前 UI 配色协调）
- 低性能消耗（适合长时间显示在菜单）

**集成方式**：
在各菜单场景（MainMenu / TeamFormation / DeckBuilder / SettingsScene）中添加：
```tscn
[node name="MenuBackground" parent="." instance=ExtResource("menu_bg")]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
```

当前背景图片 `Assets/Sprites/menubg.jpg` 可保留作为回退或图层叠加。

---

## 三、实施顺序

| Phase | 内容 | 估算 |
|---|---|---|
| 1 | 创建 `AudioManager.gd` + 注册 autoload | 1h |
| 2 | 收集/制作音效素材（可使用免费音效库） | 2h |
| 3 | 在 `ButtonTheme` / `BaseCharacter` / `main.gd` 中集成音效调用 | 2h |
| 4 | 创建 `MenuBackground.tscn` 粒子场景 | 1h |
| 5 | 在各菜单场景中实例化动态背景 | 0.5h |
| 6 | 测试 + 调优（音量平衡、性能） | 1h |

---

## 四、依赖项

- 音效素材不在本仓库中，需自行下载或录制后放入 `Assets/Audio/` 目录
- 建议使用 [freesound.org](https://freesound.org) 或 [kenney.nl](https://kenney.nl) 的免费音效
- 粒子背景无需额外素材
