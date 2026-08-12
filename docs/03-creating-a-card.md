# 创建新卡牌 — 完整流程

| 步骤 | 文件 | 操作 |
|------|------|------|
| A | `Cards/CardDatabase.gd` | `_register_cards()` 添加 `_create_card()` |
| B | `Cards/CardEffect.gd` | 实现效果逻辑（如需新效果类型） |
| C | `Scenes/main.gd` | 目标选择/高亮逻辑（如需新目标类型） |
| D | `Cards/CardData.gd` | 添加枚举值（如需新类型） |
| E | `Menus/DeckBuilder.gd` | 更新 `TYPE_NAMES`（如需新卡牌类型） |

---

## A) 注册卡牌 — `CardDatabase.gd`

```gdscript
_create_card("card_new_id", "显示名称", CardData.CardType.ATTACK, 2,
	CardData.TargetType.ENEMY_SINGLE, "描述文本",
	CardData.EffectType.DAMAGE, 25, 1, 0)
```

### 参数顺序

`id, name, type, cost, target_type, desc, effect_type, effect_value, duration=1, radius=0`

各参数含义见 `CardData.gd` 对应枚举。`radius` 仅用于 AOE 效果。

### 描述格式规范

- **介词**：恢复→**为**，造成/施加→**为我方施加，对我方造成，对敌方造成，对敌方施加**
- **后缀效果**统一用 `，效果为`，避用冒号
- **术语**：用"移动范围"非"移动力"，"造成伤害/恢复生命值"非"治疗"，"持续X回合"

### 目标类型

`NONE(0)` 无目标 / `ALLY_SINGLE(1)` 单体友方 / `ENEMY_SINGLE(2)` 单体敌方 / `ALLY_ALL(3)` 全体友方 / `ENEMY_ALL(4)` 全体敌方 / `CELL(5)` 地面格子 / `ALL_CHARACTERS(6)` 所有角色

---

## B) 效果类型与实现 — `CardEffect.gd`

| EffectType | 参数 | 说明 |
|---|---|---|
| DAMAGE / HEAL | value | 单体伤害/治疗 |
| SHIELD | value | 护盾 |
| BUFF_ATTACK / BUFF_DEFENSE | value, duration | 增益 |
| DEBUFF_ATTACK / DEBUFF_MOVE | value, duration | 减益 |
| EXTRA_MOVE | value, duration | 额外移动 |
| DRAW_CARD | value | 抽牌 |
| CLEANSE | — | 移除减益 |
| AOE_DAMAGE / AOE_HEAL | value | 全阵营范围效果 |
| CHAIN_DAMAGE | value | 连锁跳跃 |
| DAMAGE_OVER_TIME / HEAL_OVER_TIME | value, duration | 持续伤害/治疗 |
| MARK | percentage, duration | 标记 |
| TELEPORT / SWAP / LINEAR_AOE | value | 位移（无 caster） |

> 所有效果函数签名 `static func _execute_xxx(card, target, main)` — **无 caster 参数**。卡牌由玩家直接释放到目标，位移效果也以 `target` 为操作对象，不使用 `main.selected_character`。

### AOE 阵营判定

通过 `main.current_card_player_id` 判断。Host 方卡牌 → AOE_DAMAGE 影响敌方 / AOE_HEAL 影响友方。**不使用 `GlobalGameData.is_host`**。

### 添加新效果类型

1. `CardData.gd` 的 `enum EffectType` 添加值
2. `CardEffect.execute()` 的 `match` 添加分支
3. 实现 `static func _execute_xxx(card, target, main)`

---

## C) 添加新卡牌类型

`CardData.gd` 的 `enum CardType` 添加值，`DeckBuilder.gd` 的 `TYPE_NAMES` 添加映射。

## D) 添加新目标类型

`CardData.gd` 的 `enum TargetType` 添加值，`main.gd` 的 `_is_valid_target()` 和 `highlight_targets()` 添加处理逻辑。

## 检查清单

- [ ] `CardDatabase.gd`: `_create_card()` 调用
- [ ] （如需要） `CardData.gd`: 新枚举值
- [ ] （如需要） `CardEffect.gd`: match 分支 + 实现
- [ ] （如需要） `main.gd`: 目标选择/高亮
- [ ] （如需要） `DeckBuilder.gd`: TYPE_NAMES

---

## E) 卡面图生成（SD WebUI）

卡面图路径 `Assets/Sprites/Cards/{card_id}.png`（文件名 = 卡牌 id，`CardUIBase._load_card_image` 按此加载）。**必须为透明背景 PNG**（卡面区域下方有白色六边形底纹，透明处透出）。

### 生成管线（一次配置，可复用）

1. **工具**：SD WebUI（`C:\Users\10932\Documents\5652\sd-webui-aki-v4.10`），模型 `minimax_h3_fl2va_pruned_int8_convrot.safetensors`，API 端口 7860。
2. **提示词**：34 张卡的 prompt 模板在 `C:\Users\10932\AppData\Local\Temp\opencode\card_prompts.json`（非项目内，重生成可参照）。统一风格 = "动漫角色施展对应魔法/元素 + 深色背景 + 居中构图"；负面词禁 text/watermark/logo/multiple characters/complex background。
3. **生成参数**：1024×576，steps 28，cfg 5.5，sampler `dpmpp_2m`。
4. **抠图（透明化）**：模型输出 RGB（无 alpha），用 rembg 批处理：
   - venv: `sd-webui-aki-v4.10\venv\Scripts\python.exe`（已装 rembg[cpu]）
   - 抠图模型 `bria-rmbg-2.0.onnx` 放 `C:\Users\10932\.u2net\`（国内网络从 hf-mirror 下载 RMBG-1.4/2.0 的 `onnx/model.onnx`）
   - 批处理脚本模式：`new_session('bria-rmbg')` + `remove(img, session=s)`
5. **替换**：透明 PNG 覆盖 `Assets/Sprites/Cards/{id}.png`，Godot 自动重新导入（运行时会重建 `.import` 缓存）。

### 注意

- 生成图主体**略偏左/尺寸小**属正常（抠图后居中裁剪可缓解）；构图严重不符才需重生成（固定 seed 微调 prompt）。
- 卡面显示区 120×67（横向条幅），生成图 1024×576 比例匹配。
- minimax 为角色模型：纯元素类 prompt（火球/盾牌）易画出角色持物，可接受；如需纯物品图标需更强约束（`icon, emblem, no people`）或换模型。
