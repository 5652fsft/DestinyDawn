class_name CardArtGenerator
extends RefCounted

# 程序化生成卡牌 UI 纹理（撞色背景 / 六边形底纹）
# 生成结果按参数缓存，全局复用，无需外部美术资源

const CARD_W: int = 140
const CARD_H: int = 200
const CARD_RADIUS: float = 10.0

static var _bg_cache: Dictionary = {}
static var _pattern_cache: Dictionary = {}

# 整卡背景：上半 类型色->深灰 垂直渐变，下半纯色，split_y 处硬分割，四角圆角
# size 支持不同卡牌尺寸（战斗卡 140x200 / 构筑卡 125x183），纹理内容按尺寸逐像素生成
static func make_card_bg(top: Color, bottom_dark: Color, bottom: Color, split_y: float = 100.0, size: Vector2i = Vector2i(CARD_W, CARD_H)) -> ImageTexture:
	var key := "%s|%s|%s|%.1f|%d|%d" % [top.to_html(), bottom_dark.to_html(), bottom.to_html(), split_y, size.x, size.y]
	if _bg_cache.has(key):
		return _bg_cache[key]
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		var col: Color = top.lerp(bottom_dark, y / split_y) if y < split_y else bottom
		for x in size.x:
			var a: float = 1.0
			if x < CARD_RADIUS and y < CARD_RADIUS:
				a = _corner_alpha(x, y, CARD_RADIUS)
			elif x >= size.x - CARD_RADIUS and y < CARD_RADIUS:
				a = _corner_alpha(size.x - 1 - x, y, CARD_RADIUS)
			elif x < CARD_RADIUS and y >= size.y - CARD_RADIUS:
				a = _corner_alpha(x, size.y - 1 - y, CARD_RADIUS)
			elif x >= size.x - CARD_RADIUS and y >= size.y - CARD_RADIUS:
				a = _corner_alpha(size.x - 1 - x, size.y - 1 - y, CARD_RADIUS)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * a))
	var tex := ImageTexture.create_from_image(img)
	_bg_cache[key] = tex
	return tex

# 圆角 alpha：r-1px 内全透明，向外 1px 抗锯齿过渡
static func _corner_alpha(lx: float, ly: float, r: float) -> float:
	var d := Vector2(lx, ly).distance_to(Vector2(r, r))
	if d >= r:
		return 0.0
	if d <= r - 1.0:
		return 1.0
	return r - d

# 六边形网格暗纹（无缝平铺，呼应六边形战棋主题）
static func make_hex_pattern(color: Color, hex_radius: float = 16.0) -> ImageTexture:
	var key := "%s|%.1f" % [color.to_html(), hex_radius]
	if _pattern_cache.has(key):
		return _pattern_cache[key]
	var d := sqrt(3.0) * hex_radius
	var w := int(2.0 * (d * 0.5 + hex_radius * 0.866)) + 1
	var h := int(2.0 * (d * 0.866 + hex_radius)) + 1
	# 中心六边形 + 6 个邻居（邻居中心按纹理尺寸取模环绕）
	var centers: Array[Vector2] = [Vector2(w * 0.5, h * 0.5)]
	for k in 6:
		var ang := deg_to_rad(60.0 * k)
		centers.append(_wrap_point(Vector2(w * 0.5 + cos(ang) * d, h * 0.5 + sin(ang) * d), Vector2(w, h)))
	# 六边形顶点（相对中心，pointy-top：顶点在正上/正下）
	var verts: Array[Vector2] = []
	for k in 6:
		var ang := deg_to_rad(60.0 * k)
		verts.append(Vector2(sin(ang), cos(ang)) * hex_radius)
	var edge_w: float = 1.5
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var min_d := INF
			for c in centers:
				var rel := _wrap_point(Vector2(x, y) - c, Vector2(w, h))
				min_d = min(min_d, _point_hex_dist(rel, verts))
			var a: float = 0.0
			if min_d <= edge_w:
				a = clamp(1.0 - min_d / edge_w, 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * a))
	var tex := ImageTexture.create_from_image(img)
	_pattern_cache[key] = tex
	return tex

# 六边形网格底纹 + 从右下向左上渐隐 + 只在下半部分显示
# 右下角透明度最强，向左上角逐渐归零；同时纹路只覆盖下部 fade_height 比例，向上渐隐消失
# size 为完整卡面尺寸，tile 周期复用 make_hex_pattern 的小纹理，逐像素叠加渐隐系数
static func make_hex_pattern_faded(color: Color, hex_radius: float, size: Vector2i, fade_height: float = 0.5) -> ImageTexture:
	var key := "%s|%.1f|%d|%d|fade%.2f" % [color.to_html(), hex_radius, size.x, size.y, fade_height]
	if _pattern_cache.has(key):
		return _pattern_cache[key]
	var tile := make_hex_pattern(color, hex_radius)
	var tile_img := tile.get_image()
	var tw := tile_img.get_width()
	var th := tile_img.get_height()
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var tp: Color = tile_img.get_pixel(x % tw, y % th)
			# 从右下向左上渐隐：沿左上角(0,0)->右下角(w,h)对角线，右下角为 1，左上角为 0
			var f1: float = clamp((x + y) / float(size.x + size.y), 0.0, 1.0)
			# 垂直范围收缩：底部满值，向上在 fade_height 高度处渐隐到 0
			var f2: float = clamp((y - (1.0 - fade_height) * size.y) / (fade_height * size.y), 0.0, 1.0)
			var f: float = f1 * f2
			img.set_pixel(x, y, Color(tp.r, tp.g, tp.b, tp.a * f))
	var tex := ImageTexture.create_from_image(img)
	_pattern_cache[key] = tex
	return tex

# 坐标取模到 [0, size)（平铺环绕）
static func _wrap_point(p: Vector2, size: Vector2) -> Vector2:
	var x := fmod(p.x, size.x)
	var y := fmod(p.y, size.y)
	if x < 0.0:
		x += size.x
	if y < 0.0:
		y += size.y
	return Vector2(x, y)

# 点到六边形边缘的最短距离
static func _point_hex_dist(rel: Vector2, verts: Array[Vector2]) -> float:
	var min_d := INF
	for k in verts.size():
		min_d = min(min_d, _dist_to_segment(rel, verts[k], verts[(k + 1) % verts.size()]))
	return min_d

static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 <= 0.0:
		return p.distance_to(a)
	var t: float = clamp((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)
