# 改进规划（v0.4.0）

## UI 改进

### 1 阅读项目架构以及文档，修改不影响游戏正常游玩，做好版本管理

### 2.1 卡牌系统

| 改进项 | 现状 | 目标 |
|--------|------|------|
| 费用不足灰化 | 无，能量不足时仍可拖拽但释放失败 | 手牌中费用 > 当前能量的卡牌灰化 + 禁用拖拽，鼠标悬停显示消耗提示 |
| 卡面重设计 | 纯文字卡片，仅有名称/描述/费用 | 重新排版：增加卡牌边框，元素图标（火/冰/毒/盾），效果数值加粗，费用醒目展示（已有点，需要美化） |

**卡面重设计详细方案**：

```
┌─────────────┐
│ 1           │  ← 费用（左上角圆形，颜色随类型变化）
│             │
│  火球术     │  ← 卡名（居中，大字，带阴影）
│             │
│  造成 20    │  ← 描述区（小字，效果数值加粗）
│  点伤害     │
│             │
│ ⚡ATTACK   │  ← 类型标签（右下角，颜色区分：红=攻击，绿=治疗，蓝=Buff等）
└─────────────┘
```

**卡面颜色方案**：

| 卡牌类型 | 边框 | 费用颜色 | 标签文字 |
|----------|-----------|----------|----------|
| ATTACK   | 暗红 (#8B0000) | 红   | ATTACK |
| HEAL     | 深绿 (#006400) | 绿   | HEAL   |
| BUFF     | 蓝紫 (#4B0082) | 蓝   | BUFF   |
| DEBUFF   | 暗紫 (#800080) | 紫   | DEBUFF |
| SHIELD   | 钢蓝 (#4682B4) | 蓝   | SHIELD |
| TACTICAL | 金 (#B8860B)   | 金   | TACTICAL |
| DISPLACE | 橙 (#FF8C00)   | 橙   | DISPLACE |

**实现方式**：
- 修改 `CardUI.gd` 中的 `setup(data)` 方法，根据 `card_data.card_type` 设置不同颜色主题
- 使用 `StyleBoxFlat` 动态设置卡牌面板的 `border_color`
- 添加 `CardType` 标签显示
- 添加图标系统（可选）：为每种效果类型预设 Emoji/图标字符（资源文件可参考C:\Users\10932\Documents\5652\DestinyDawn\570+图标-v1.0.3）

### 2.2 角色信息面板（CharacterInfoPanel）

**目标**：增强信息可读性和视觉层次。

**需要修改的**：
剩余移动次数显示合并到剩余行动次数的同一行右侧



**Buff 标签样式**（`_buff_desc` 返回值增加颜色标记）：

只改中括号部分

| Buff 类型 | 文本颜色 | 示例 |
|-----------|---------|------|
| ATTACK_BUFF | 绿色 | `[color=green][魔力充盈][/color] +15%（2回合）` |
| ATTACK_DEBUFF | 红色 | `[color=red][虚弱][/color] -8（2回合）` |
| DEFENSE_BUFF | 蓝色 | `[color=blue][防御][/color] -20%伤害（2回合）` |
| DAMAGE_OVER_TIME | 暗红 | `[color=darkred][中毒][/color] 每回合-5（3回合）` |
| HEAL_OVER_TIME | 绿色 | `[color=green][再生][/color] 每回合+5（3回合）` |
| MARK | 紫色 | `[color=purple][标记][/color] +50%伤害（2回合）` |
| MOVE_DEBUFF | 橙色 | `[color=orange][迟缓][/color] -2移动（1回合）` |
| TAUNT | 金色 | `[color=gold][嘲讽][/color] 强制攻击（1回合）` |

**实现方式**：
- `CharacterInfoPanel._buff_desc()` 改用 RichTextLabel 支持 BBCode
- 或每个 Buff 标签用 `Label.add_theme_color_override("font_color", color)` 单独着色
- 在 `show_for()` 中添加 `current_character` 的类型标签（可从 CharacterData 扩展）

### 2.3 主界面 UI 美化

**主菜单（充分参考明日方舟ui设计）**：
- 背景切换为动态视频（已完成）
- 按钮间距、悬停效果微调（已有 HOVER_SCALE，可增加阴影过渡）
- 重新排布标题位置
- 增大各按钮大小，并靠右重新排布，部分按钮可设置到同一排，设置毛玻璃底色，比如————角色编队和卡牌构筑构筑用白底且居同一行，“单人单机”改名“单人游戏”且用蓝底，还要丰富按钮元素
- 设置和游戏指南按钮改用小图标，置于屏幕左上角

**卡组构筑界面**：
- 卡牌列表按费用/类型排序


### 2.4 全局 UI

| 改进项 | 详细方案 | 实现位置 |
|--------|----------|----------|
| 回合过渡动画 | 阶段切换时半屏遮罩从右向左移入 + "你的回合"/"敌方回合"大字（变速缓动），停留 1s 后从中间向左移出 | `main.gd` 的 `_sync_turn_phase` 或 `TurnIndicator.gd` |
| 战斗结果界面 | 胜利/失败弹窗：半透明全屏遮罩 + 居中卡片（带圆角阴影），显示战斗统计（伤害/治疗/击杀/回合数），"返回主菜单"/"再来一局"按钮（美化样式） | `BattleResult.tscn` 重新排版 |

---

## 三、特效改进

### 3.1 VFX 预设补充

当前 `_play_vfx_preset` 支持的预设：

| 预设 | 效果 | 使用场景 |
|------|------|----------|
| `buff` | 绿色上升粒子 | 增益效果 |
| `debuff` | 红色下降粒子 | 减益效果 |
| `heal` | 绿色十字/光晕 | 治疗类效果 |
| `explosion` | 爆炸粒子 | AOE 伤害 |
| `skill` | 技能特效 | 角色主动技能 |

需要补充：

| 新增预设 | 实现方案 | 使用场景 |
|----------|----------|----------|
| `shield` | 蓝色护盾光晕：Sprite2D 缩放 + 淡出，或环形粒子 | 护盾类卡牌/技能（`_execute_shield`） |
| `death` | 消散粒子：角色原地分解为向上飘散的碎片 | 角色阵亡时（`hp <= 0` → `_play_vfx_preset("death")`） |
| `teleport` | 闪烁：角色变半透明 → 位移 → 恢复，带拖尾粒子 | 位移类卡牌（shadowstep, teleport） |
| `critical` | 冲击波：圆形扩散环 + 屏幕震动 | 高伤害/暴击时（伤害 > 20 或特定技能） |

另外，对于角色的技能要专门做独立特效

**VFX 预设实现方式**：

每个预设对应一个场景（`tscn`）或通过代码动态创建粒子/动画：

```gdscript
# VFXManager.gd 或 BuffManager.gd 中预加载场景
const VFX_SCENES = {
	"explosion": preload("res://Effects/Explosion.tscn"),
	"shield": preload("res://Effects/ShieldEffect.tscn"),
	"death": preload("res://Effects/DeathEffect.tscn"),
	"teleport": preload("res://Effects/TeleportEffect.tscn"),
	"critical": preload("res://Effects/CriticalEffect.tscn"),
}

func play_vfx(name: String, target: Node):
	var scene = VFX_SCENES.get(name)
	if not scene:
		return
	var instance = scene.instantiate()
	target.add_child(instance)
	# 自动播放后清除
```

**地图范围效果**：（暂时还没有）

对地图释放的卡牌/技能，需要在地图上显示对应效果：
- AOE 范围预览：高亮目标地格 + 周围受影响区域（使用 `highlight_layer.set_cell()`）
- 范围命中动画：在受影响的每个地格播放爆炸/命中粒子
- 指定地格技能：点击地格后在该位置播放特效

实现位置：`CardEffect.gd` 和 `SkillEffect.gd` 中，在执行效果前调用高亮函数，执行后清除高亮并播放命中特效。

### 3.2 屏幕震动

**CameraShake 组件**：

```gdscript
# Effects/CameraShake.gd
extends Camera2D

var shake_strength: float = 0.0
var shake_decay: float = 5.0

func apply_shake(strength: float):
	shake_strength = strength

func _process(delta):
	if shake_strength > 0:
		offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		shake_strength = max(0, shake_strength - shake_decay * delta)
	else:
		offset = Vector2.ZERO
```

**触发逻辑**（在 `BaseCharacter.take_damage()` 中）：

```gdscript
func take_damage(damage: int):
	...
	# 伤害 > 20 时触发屏幕震动
	if damage > 20 and main and main.has_method("_apply_shake"):
		main._apply_shake(min(damage * 0.1, 5.0))
	...
```

**集成方式**：
- 场景的 Camera2D 添加 CameraShake 脚本
- 或在 `main.gd` 中添加 `_apply_shake(strength)` 方法，遍历场景中所有 Camera2D

### 3.3 浮动数字改进

当前 `FloatingNumber.tscn` 仅有简单数字位移。为其增加更多动效。

---

## 四、交互改进

### 4.1 操作优化

| 改进项 | 详细方案 | 实现位置 |
|--------|----------|----------|
| 回车结束回合 | 我的回合时按回车键直接结束回合（等同于点击结束回合按钮），非回合阶段忽略 | `main.gd._input` 中新增 KEY_ENTER 处理 |
| ESC 取消选中 | 按 ESC 取消当前角色选中，关闭信息面板，回到无选中状态 | `main.gd._input` 中新增 KEY_ESCAPE 处理（调用 `unselect_character(null, true)`） |
| 自动镜头居中 | 选中角色时镜头平滑移动到角色附近（`Camera2D.position` 插值到角色位置） | `main.gd.select_character()` 中新增镜头移动 tween |

### 4.2 目标选择优化

| 改进项 | 详细方案 |
|--------|----------|
| 拖拽时目标高亮 | 当卡牌拖拽到有效目标上方时，目标角色高亮；拖拽到无效目标上时显示红框提示 |

### 4.3 拖拽优化

| 改进项 | 详细方案 |
|--------|----------|
| 无效释放弹回 | 卡牌拖拽到无效区域释放时，不是原地消失，而是沿拖拽路径反向飞回原位 + 缩放弹入动画（弹簧效果），然后正常消失 |

---

## 六、依赖项
- VFX 粒子效果使用 Godot 内置粒子系统，无需外部资源
- 屏幕震动使用 Camera2D 位置偏移
- 字体已存在：`Assets/Fonts/SourceHanSerifCN-Heavy-4.otf`
- 图标文件可选用：C:\Users\10932\Documents\5652\DestinyDawn\570+图标-v1.0.3
