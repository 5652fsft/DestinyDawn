# 卡牌共用样式数值
# 修改这些值会同时影响战斗卡牌和构筑界面卡牌

const CARD_BG = Color(0.16, 0.17, 0.22, 0.95)
const CARD_BORDER_RADIUS = 10

const COST_BG = Color(0.22, 0.25, 0.32, 0.9)
const COST_RADIUS = 14

const HOVER_SCALE = 1.2
const HOVER_MODULATE = Color(1, 1, 0.95)
const HOVER_SHADOW_SIZE = 16
const HOVER_SHADOW_COLOR = Color(0, 0, 0, 0.5)
const HOVER_SHADOW_OFFSET = Vector2(4, 4)
const HOVER_TWEEN_SEC = 0.12

const DECK_HOVER_SCALE = 1.04
const DECK_BASE_SCALE = 0.95

# 灰化明度系数（保持透明度不变，仅降低明度）
const DISABLED_ALPHA = 0.6
# 战斗卡牌灰化：透明度恒为 1，只降明度
const DISABLED_MODULATE = Color(0.6, 0.6, 0.65, 1.0)

# === 上下撞色背景 ===
# 上半：类型色(顶部) -> 深灰(分割线) 垂直渐变；下半：统一高级灰白（与类型色无关）
const TYPE_GRAD_TOP = {
	0: Color(0.42, 0.17, 0.17, 1),    # ATTACK 暗红
	1: Color(0.16, 0.34, 0.21, 1),    # HEAL 暗绿
	2: Color(0.2, 0.23, 0.42, 1),     # BUFF 蓝紫
	3: Color(0.34, 0.16, 0.36, 1),    # DEBUFF 暗紫
	4: Color(0.45, 0.3, 0.14, 1),     # DISPLACE 暗橙
	5: Color(0.16, 0.29, 0.39, 1),    # SHIELD 钢蓝
	6: Color(0.38, 0.33, 0.16, 1),    # TACTICAL 暗金
}
const GRAD_BOTTOM_DARK = Color(0.3, 0.31, 0.37, 1)
const BOTTOM_COLOR = Color(0.87, 0.87, 0.9, 1)
const SPLIT_Y = 100.0
# 构筑界面卡牌（125x183）：分割线以卡名位置为基准（88-4，同战斗卡 104-4 的规则）
const DECK_SPLIT_Y = 84.0

# === 卡面底纹（配合透明背景卡图） ===
const PATTERN_COLOR = Color(1, 1, 1, 0.07)
const PATTERN_DARK_COLOR = Color(0, 0, 0, 0.05)
const PATTERN_HEX_RADIUS = 16.0

# === 选中态样式（青色高亮框） ===
const SELECT_BORDER_COLOR = Color(0.3, 0.95, 1.0, 1)

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
	0: Color(0.9, 0.6, 0.6, 0.95),   # ATTACK 亮红
	1: Color(0.6, 0.9, 0.65, 0.95),  # HEAL 亮绿
	2: Color(0.65, 0.7, 0.95, 0.95), # BUFF 亮蓝紫
	3: Color(0.85, 0.6, 0.9, 0.95),  # DEBUFF 亮紫
	4: Color(0.95, 0.78, 0.5, 0.95), # DISPLACE 亮橙
	5: Color(0.65, 0.85, 0.95, 0.95),# SHIELD 亮蓝
	6: Color(0.92, 0.85, 0.58, 0.95),# TACTICAL 亮金
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
