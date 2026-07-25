class_name ParticleTextureGenerator
extends Node

const SIZE = 64

static func generate_all() -> Dictionary:
	return {
		"circle": _make_circle(),
		"circle_soft": _make_circle_soft(),
		"star": _make_star(),
		"diamond": _make_diamond(),
		"spark": _make_spark(),
		"smoke": _make_smoke(),
		"ring": _make_ring(),
	}

# 实心圆：内圈完全实心，边缘 1px 抗锯齿
static func _make_circle() -> ImageTexture:
	var img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var c = SIZE * 0.5
	var r2 = (SIZE * 0.47) * (SIZE * 0.47)
	var fade2 = (SIZE * 0.45) * (SIZE * 0.45)
	for x in SIZE:
		var dx = x - c
		var dx2 = dx * dx
		for y in SIZE:
			var dy = y - c
			var d2 = dx2 + dy * dy
			if d2 <= fade2:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
			elif d2 <= r2:
				var a = 1.0 - (sqrt(d2) - sqrt(fade2)) / (sqrt(r2) - sqrt(fade2))
				img.set_pixel(x, y, Color(1, 1, 1, a))
			else:
				img.set_pixel(x, y, Color(1, 1, 1, 0))
	return ImageTexture.create_from_image(img)

# 柔边圆
static func _make_circle_soft() -> ImageTexture:
	var img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var c = SIZE * 0.5
	var half = SIZE * 0.5
	var half2 = half * half
	for x in SIZE:
		var dx = x - c
		for y in SIZE:
			var dy = y - c
			var d2 = dx * dx + dy * dy
			var a = 1.0 - clamp(sqrt(d2) / half, 0.0, 1.0)
			a = a * a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

# 六芒星：距离比方法，硬边 + 1px 抗锯齿
static func _make_star() -> ImageTexture:
	var img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var c = Vector2(SIZE * 0.5, SIZE * 0.5)
	var outer = SIZE * 0.48
	var inner = SIZE * 0.18
	var pts = 6
	for x in SIZE:
		for y in SIZE:
			var v = Vector2(x, y) - c
			var dist = v.length()
			if dist < 0.5:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
				continue
			var angle = atan2(v.y, v.x) + PI * 0.5
			var sector = PI / pts
			var slot = fmod(angle, 2.0 * sector)
			if slot < 0: slot += 2.0 * sector
			if slot > sector: slot = 2.0 * sector - slot
			var r_edge = outer - (outer - inner) * (slot / sector)
			var diff = dist - r_edge
			var a = 1.0
			if diff > 0.5:
				a = 0.0
			elif diff > -0.5:
				a = 1.0 - (diff + 0.5)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

# 菱形
static func _make_diamond() -> ImageTexture:
	var img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var c = SIZE * 0.5
	var half = SIZE * 0.46
	for x in SIZE:
		for y in SIZE:
			var d = abs(x - c) + abs(y - c)
			var a = 1.0
			if d > half + 0.5:
				a = 0.0
			elif d > half - 0.5:
				a = 1.0 - (d - (half - 0.5))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

# 火花
static func _make_spark() -> ImageTexture:
	var img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var c = Vector2(SIZE * 0.5, SIZE * 0.5)
	var w = SIZE * 0.45
	var h = SIZE * 0.08
	for x in SIZE:
		for y in SIZE:
			var dx = (x - c.x) / w
			var dy = (y - c.y) / h
			var d2 = dx * dx + dy * dy
			if d2 > 1.0:
				img.set_pixel(x, y, Color(1, 1, 1, 0))
				continue
			var a = 1.0 - d2
			a = clamp(a * 1.5, 0.0, 1.0)
			if dx > 0.3:
				a *= 1.0 - (dx - 0.3) / 0.7 * 0.5
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

# 烟雾
static func _make_smoke() -> ImageTexture:
	var img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var c = SIZE * 0.5
	var half = SIZE * 0.5
	for x in SIZE:
		for y in SIZE:
			var d = Vector2(x, y).distance_to(Vector2(c, c)) / half
			var a = (1.0 - clamp(d, 0.0, 1.0))
			a = pow(a, 1.2) * 0.2
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

# 环
static func _make_ring() -> ImageTexture:
	var img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var c = SIZE * 0.5
	var outer = SIZE * 0.46
	var inner = SIZE * 0.36
	for x in SIZE:
		for y in SIZE:
			var d = Vector2(x, y).distance_to(Vector2(c, c))
			var a = 0.0
			if d >= inner and d <= outer:
				a = 1.0
				if d < inner + 1.0:
					a = d - inner
				elif d > outer - 1.0:
					a = outer - d
			img.set_pixel(x, y, Color(1, 1, 1, clamp(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
