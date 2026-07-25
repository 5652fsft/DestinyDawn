# Destiny Dawn 项目 — AI快速导览

**引擎**：Godot 4.7.1 | **玩法**：回合制六边形战棋 + 卡牌对战 | **网络**：ENet P2P

## 核心定位

回合制战棋 + 卡牌策略，LAN联机 / 单机人机（AI），使用 `MultiplayerAPI`。

## 核心机制

- **回合**：每个角色每回合可执行 1 次移动 + 1 次行动（攻击/技能），顺序自由
- **卡牌**：卡牌由玩家释放，不消耗角色行动次数

## 文档导航

| 文档 | 说明 |
|------|------|
| `02-creating-a-character.md` | 角色数据/脚本/技能/AI 注册 |
| `03-creating-a-card.md` | 卡牌注册/效果/描述规范 |
| `04-creating-ui.md` | 按钮/面板/字体规范 |
| `05-rpc-conventions.md` | RPC 模式/AI 模式短路规则 |
| `06-data-format-reference.md` | 角色/Buff 数据字段速查 |
| `08-ai-mode.md` | AI 策略分支注册 |
| `09-audio-system.md` | 音效添加与调用 |
