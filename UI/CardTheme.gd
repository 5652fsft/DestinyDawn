# 卡牌共用样式数值
# 修改这些值会同时影响战斗卡牌和构筑界面卡牌

const CARD_BG = Color(0.16, 0.17, 0.22, 0.95)
const CARD_BORDER_RADIUS = 10

const COST_BG = Color(0.22, 0.25, 0.32, 0.9)
const COST_RADIUS = 14

const HOVER_SCALE = 1.35
const HOVER_MODULATE = Color(1, 1, 0.95)
const HOVER_SHADOW_SIZE = 16
const HOVER_SHADOW_COLOR = Color(0, 0, 0, 0.5)
const HOVER_SHADOW_OFFSET = Vector2(4, 4)
const HOVER_TWEEN_SEC = 0.12

const DECK_HOVER_SCALE = 1.08
const DECK_BASE_SCALE = 0.95

const DISABLED_ALPHA = 0.6

# 卡牌类型颜色（低饱和度统一）
const TYPE_BORDER = {
	0: Color(0.45, 0.2, 0.2, 0.8),    # ATTACK 暗红
	1: Color(0.2, 0.4, 0.25, 0.8),    # HEAL 暗绿
	2: Color(0.25, 0.28, 0.48, 0.8),  # BUFF 蓝紫
	3: Color(0.4, 0.2, 0.42, 0.8),    # DEBUFF 暗紫
	4: Color(0.5, 0.35, 0.18, 0.8),   # DISPLACE 暗橙
	5: Color(0.22, 0.35, 0.45, 0.8),  # SHIELD 钢蓝
	6: Color(0.45, 0.38, 0.2, 0.8),   # TACTICAL 暗金
}

const TYPE_COST_BG = {
	0: Color(0.4, 0.22, 0.22, 0.85),
	1: Color(0.22, 0.38, 0.25, 0.85),
	2: Color(0.28, 0.3, 0.5, 0.85),
	3: Color(0.38, 0.22, 0.42, 0.85),
	4: Color(0.48, 0.35, 0.2, 0.85),
	5: Color(0.25, 0.38, 0.48, 0.85),
	6: Color(0.42, 0.38, 0.22, 0.85),
}

const TYPE_TAG_COLOR = {
	0: Color(0.6, 0.3, 0.3, 0.9),
	1: Color(0.3, 0.55, 0.35, 0.9),
	2: Color(0.35, 0.4, 0.65, 0.9),
	3: Color(0.5, 0.3, 0.55, 0.9),
	4: Color(0.65, 0.48, 0.25, 0.9),
	5: Color(0.35, 0.5, 0.6, 0.9),
	6: Color(0.6, 0.52, 0.3, 0.9),
}

const TYPE_TAG_TEXT = {
	0: "ATTACK",
	1: "HEAL",
	2: "BUFF",
	3: "DEBUFF",
	4: "DISPLACE",
	5: "SHIELD",
	6: "TACTICAL",
}
