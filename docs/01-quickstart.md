# Destiny Dawn 项目快速导览

**引擎**：Godot 4.7.1 | **玩法**：回合制六边形战棋 + 卡牌 3v3 | **网络**：ENet P2P

---

## 文件架构

```
destiny-dawn/
├── Global/              # 单例 + 工具
│   ├── GlobalGameData.gd   # 全局战斗状态（autoload）
│   ├── HexUtils.gd         # 六边形 BFS / 方向 / 半径常量
│   ├── AudioManager.gd     # 音效管理
│   ├── BuffManager.gd      # Buff 系统
│   ├── ButtonTheme.gd      # 按钮主题
│   ├── CharacterData.gd    # 角色基础数据
│   ├── FieldEffectManager.gd # 场地效果（烟雾等）
│   └── VFXManager.gd       # 粒子特效管理
├── Scenes/              # 主战斗场景 main.gd + camera.gd
├── Characters/          # 每个角色独立子目录（脚本 + tscn）
│   ├── BaseCharacter.gd    # 基类（class_name BaseCharacter）
│   └── Bronya/Seele/...    # 12 个角色
├── Cards/               # 卡牌数据 + 效果逻辑
│   ├── CardDatabase.gd     # 卡牌注册表
│   ├── CardEffect.gd       # 效果执行（static, 无 caster）
│   └── CardData.gd         # 效果/目标枚举
├── Skills/              # 技能效果
│   └── SkillEffect.gd      # 技能执行 + 被动修正
├── AI/                  # AI 控制器
│   └── AIController.gd     # 单机人机决策
├── UI/                  # 战斗界面组件
├── Menus/               # 主菜单/编队/卡组/设置
├── Effects/             # 浮动伤害数字
└── Assets/              # 贴图/音效/字体
```

## 核心机制

- **回合合并**：每个角色每回合可执行 1 次移动 + 1 次攻击/技能，顺序自由
- **卡牌独立**：卡牌由玩家释放，不消耗角色行动次数，无 caster 概念
- **AOE 阵营**：通过 `main.current_card_player_id` 判断，不使用 `GlobalGameData.is_host`
- **角色能量**：技能能量消耗定义在 `CharacterData.gd` 的 `skill_energy` 字段

## 新增角色/卡牌流程

见 `docs/02-creating-a-character.md` 和 `docs/03-creating-a-card.md`。
