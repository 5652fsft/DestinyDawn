# Destiny Dawn — 项目概览

## 目录结构

```
destiny-dawn/
├ Assets/
│  ├ Fonts/                    # SourceHanSerifCN 字体文件
│  └ Sprites/
│     ├ Characters/            # 角色阵营贴图 (*_Blue.png / *_Red.png)
│     ├ Standee/               # 角色立绘 (240×144, *_Standee.png)
│     └ menubg.jpg             # 主菜单/UI 背景
├ Cards/
│  ├ CardData.gd               # CardData 资源类 + EffectType/TargetType/CardType 枚举
│  ├ CardDatabase.gd           # 所有卡牌注册 + get_card / get_all_card_ids
│  └ CardEffect.gd             # 卡牌效果执行器 (execute + 所有效果函数)
├ Characters/
│  ├ BaseCharacter.gd          # 角色基类 (CharacterBody2D)
│  ├ FloatingBar.gd/.tscn      # 血条/护盾/选中指示器
│  ├ Bronya/                   # 布洛妮娅
│  ├ Seele/                    # 希儿
│  ├ Elaina/                   # 伊蕾娜
│  ├ Firefly/                  # 流萤
│  └ SilverWolf/               # 银狼
├ Global/
│  ├ CharacterData.gd          # 角色数据字典 (单数据源)
│  ├ DeckManager.gd            # 卡组/手牌管理
│  ├ EnergySystem.gd           # 能量系统
│  ├ BuffManager.gd            # Buff 管理器
│  └ BuffDatabase.gd           # Buff 注册表
├ GlobalGameData.gd            # Autoload: 全局状态、编队、统计
├ Menus/
│  ├ MainMenu.tscn/.gd         # 主菜单 (LAN 创建/加入/设置/退出)
│  ├ TeamFormation.tscn/.gd    # 编队管理 (左列表右槽位)
│  ├ DeckBuilder.tscn/.gd      # 卡组构筑 (牌库+8卡槽)
│  └ Widgets/
│     ├ CharacterCard.tscn/.gd # 角色卡片 (立绘+翻转详情)
│     ├ DeckCardUI.tscn/.gd    # 卡牌卡片 (费用+名称+类型+描述)
│     ├ DeckCardWidget.tscn/.gd# 简化版卡牌组件
│     └ CharacterCard.tscn/.gd # 编队选人卡片
├ Scenes/
│  ├ scene.tscn                # 主战斗场景
│  ├ main.gd                   # 战斗主逻辑 (turn system, RPCs, spawning)
│  └ camera.gd                 # 摄像机 (拖拽+缩放)
├ Skills/
│  ├ BaseSkill.gd              # BaseSkill 资源类 (skill_name/description/cooldown/target_type)
│  └ SkillEffect.gd            # 技能效果分发器 (execute_active / get_passive_modifier)
├ UI/
│  ├ BattleResult.tscn/.gd     # 结算界面
│  ├ CardTheme.gd              # 卡牌共用样式常量
│  ├ CardUI.tscn/.gd           # 战斗手牌卡牌 UI
│  ├ CharacterInfoPanel.tscn/.gd # 角色详情面板
│  ├ HandPanel.tscn/.gd        # 手牌 Panel (扇形展示)
│  ├ SkillPanel.tscn/.gd       # 技能按钮面板
│  ├ Toast.tscn/.gd            # Toast 提示系统
│  └ PlayerInfoPanel.tscn/.gd  # 玩家信息面板
├ project.godot                # Godot 项目配置
└ docs/                        # 本文档
```

## Autoload (全局单例)

| 脚本 | 用途 |
|---|---|
| `GlobalGameData.gd` | 全局状态、编队、回合、战斗统计 |
| `Global/BuffDatabase.gd` | Buff ID 注册与元数据 |

## 运行方式

- **单机调试**: 打开 MainMenu.tscn 为主场景，点击"创建主机"进入战斗（默认双方都用默认编队/卡组）
- **LAN 联机**: 一台点"创建主机"，另一台输入 IP 点"加入"
- **主场景**: `project.godot` 中 `run/main_scene="res://Menus/MainMenu.tscn"`

## 技术栈

- Godot 4.x (GDScript 2.0)
- ENet 局域网联机 (MultiplayerAPI)
- 所有 UI 使用 Control 节点 + StyleBoxFlat 手写样式（无 .theme 文件）
- 网格系统：TileMapLayer (Ground + Highlight)
