# 音效系统 — 参考

> 此文档记录设计方案，实际实现以 `Global/AudioManager.gd` 及 `Assets/Audio/` 为准。

## 架构

- **全局单例**：`Global/AudioManager.gd`（autoload），菜单与战斗共用
- **BGM**：`AudioStreamPlayer`，循环播放，支持 `crossfade` 过渡
- **SFX**：`AudioStreamPlayer2D` 池（16 个），支持 2D 空间定位
- **音量**：三路独立（Master / BGM / SFX），值存于 `GlobalGameData.audio_volume_*`

## SFX 命名

SFX 文件为 `.ogg`，按类型分三组：

| 类型 | 示例 | 触发方式 |
|------|------|----------|
| UI 操作 | `click.ogg`, `deck_select.ogg` | 按钮/菜单事件 |
| 战斗动作 | `attack_sword.ogg`, `move.ogg` | 角色 `attack_sfx` 属性 |
| 角色技能 | `bronya_skill.ogg`, `seele_skill.ogg` | 技能效果函数中调用 |

角色攻击音效通过 `var attack_sfx: String = "attack_sword"` 属性定义，每个角色可指定不同攻击音效。

## 使用方式

```gdscript
# 全局（Engine.get_singleton）
var _am = Engine.get_singleton("AudioManager")
if _am: _am.play_sfx("click")

# 角色组件引用（_am 在 BaseCharacter 中预先获取）
if _am: _am.play_sfx(attack_sfx, self)        # 带 2D 空间定位
if _am: _am.play_sfx("heal", target)           # 在目标位置播放

# BGM
Engine.get_singleton("AudioManager").play_bgm("res://Assets/Audio/BGM/battle1.mp3")
```

## 添加新音效

1. 将 `.ogg` 放入 `Assets/Audio/SFX/` 或 `Assets/Audio/BGM/`
2. `AudioManager.gd` 的 `load_all_audio()` 中 `sfx_list` 添加文件名（不含扩展名）
3. 代码中调用 `play_sfx("name")`
