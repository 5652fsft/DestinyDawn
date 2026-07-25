# 音效系统

实际实现在 `Global/AudioManager.gd`（autoload），音效文件在 `Assets/Audio/`。

## 架构

- **全局单例**：`AudioManager`（autoload），菜单与战斗共用
- **BGM**：`AudioStreamPlayer` 循环播放，支持 crossfade
- **SFX**：`AudioStreamPlayer2D` 池（6 个），支持 2D 空间定位
- **音量**：三路独立（Master / BGM / SFX），值存于 `GlobalGameData.audio_volume_*`

## 使用方式

```gdscript
# 全局调用
var _am = Engine.get_singleton("AudioManager")
if _am: _am.play_sfx("click")

# 2D 空间定位（角色位置播放）
if _am: _am.play_sfx(attack_sfx, self)

# BGM（使用简单名称，非路径）
if _am: _am.play_bgm("battle1")
```

角色攻击音效通过 `var attack_sfx: String` 属性定义，每个角色可指定不同音效。

## 添加新音效

1. SFX 的 `.ogg` 放入 `Assets/Audio/SFX/`，BGM 的 `.mp3` 放入 `Assets/Audio/BGM/`
2. `AudioManager.gd` 的 `load_all_audio()` 中 `sfx_list` 添加文件名（不含扩展名）
3. 代码中调用 `play_sfx("name")`
