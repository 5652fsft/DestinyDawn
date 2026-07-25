extends Node

static var _tex: Dictionary = {}

static func _ensure_tex():
	if _tex.is_empty():
		var ptg = load("res://Global/ParticleTextureGenerator.gd")
		_tex = ptg.generate_all()

static func _particle(tex_name: String, amount: int, lifetime: float,
		ramp: Array, spread: float, gravity: Vector2,
		vel: float, scale_min: float, scale_max: float, angular: float = 0.0,
		scale_pts: Array = []) -> GPUParticles2D:
	_ensure_tex()
	var p = GPUParticles2D.new()
	p.one_shot = true; p.fixed_fps = 0; p.interpolate = true
	p.z_index = 5; p.local_coords = false
	p.texture = _tex.get(tex_name) as Texture2D
	p.amount = amount; p.lifetime = lifetime

	var m = ParticleProcessMaterial.new()
	m.color = Color.WHITE
	m.color_ramp = _make_ramp_tex(ramp)
	m.spread = spread; m.gravity = Vector3(gravity.x, gravity.y, 0)
	m.initial_velocity_min = vel * 0.4; m.initial_velocity_max = vel
	m.scale_min = scale_min; m.scale_max = scale_max
	if angular != 0: m.angular_velocity_min = -angular; m.angular_velocity_max = angular
	if not scale_pts.is_empty(): m.scale_curve = _make_scale_curve(scale_pts)
	p.process_material = m; return p

static func _make_ramp_tex(colors: Array) -> GradientTexture1D:
	var g = Gradient.new()
	var off = PackedFloat32Array()
	var col = PackedColorArray()
	var step = 1.0 / max(colors.size() - 1, 1)
	for i in range(colors.size()):
		off.append(i * step)
		col.append(colors[i])
	g.offsets = off
	g.colors = col
	var gt = GradientTexture1D.new()
	gt.gradient = g
	return gt

static func _make_scale_curve(pts: Array) -> CurveTexture:
	var c = Curve.new()
	for i in range(pts.size()): c.add_point(Vector2(float(i) / max(pts.size() - 1, 1), pts[i]))
	var ct = CurveTexture.new(); ct.curve = c; return ct

static func _auto_free(p: GPUParticles2D):
	await p.get_tree().create_timer(p.lifetime + 0.2).timeout
	if is_instance_valid(p): p.queue_free()

static func _emit(p: GPUParticles2D, parent: Node, pos: Vector2):
	parent.add_child(p); p.global_position = pos; p.emitting = true; _auto_free(p)

# === 布洛妮娅 ===
static func bronya_shield(character: Node, target: Node):
	var p = _particle("circle", 6, 0.45,
		[Color(1,1,0.6,1.0), Color(0.8,0.7,0.2,0.85), Color(0.5,0.4,0.1,0)],
		360, Vector2(), 50, 0.3, 0.5, 30.0, [0.3, 1.2, 0.2])
	_emit(p, target, target.global_position)

# === 希儿 ===
static func seele_blink(character: Node):
	var p = _particle("diamond", 8, 0.3,
		[Color(0.8,0.4,1,1.0), Color(0.6,0.2,0.8,0.85), Color(0.4,0.1,0.5,0)],
		180, Vector2(), 250, 0.3, 0.7, 150.0, [1.0, 0.3, 0.0])
	_emit(p, character, character.global_position)

static func seele_strike(target: Node):
	var p = _particle("diamond", 8, 0.3,
		[Color(1,0.6,1,1.0), Color(0.7,0.2,0.9,0.85), Color(0.4,0.1,0.5,0)],
		90, Vector2(), 280, 0.3, 0.8, 180.0, [0.5, 1.2, 0.0])
	_emit(p, target, target.global_position)

# === 伊蕾娜 ===
static func elaina_starburst(target: Node):
	for i in 2:
		var p = _particle("star", 6 + i * 4, 0.35 + i * 0.1,
			[Color(0.8,0.6,1,1.0 - i*0.15), Color(0.6,0.3,0.9,0.8), Color(0.4,0.1,0.6,0)],
			360, Vector2(), 80 + i * 30, 0.3 + i * 0.1, 0.6 + i * 0.15, 40.0, [0.0, 1.2, 0.0])
		var m = p.process_material as ParticleProcessMaterial
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		m.emission_ring_radius = 30.0 + i * 35.0; m.emission_ring_inner_radius = 10.0 + i * 15.0
		_emit(p, target, target.global_position)

# === 流萤 ===
static func firefly_charge(character: Node, target: Node):
	var pm = character.get_tree().current_scene.get_node_or_null("ProjectileManager")
	if pm and pm.has_method("fire"): pm.fire(character.global_position + Vector2(0, -80), target, "fireball", 0.25)

static func firefly_impact(target: Node):
	var p = _particle("spark", 10, 0.35,
		[Color(1,1,0.3,1.0), Color(1,0.5,0,0.9), Color(1,0.2,0,0)],
		180, Vector2(), 300, 0.3, 0.7, 150.0, [0.5, 1.2, 0.2])
	var m = p.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; m.emission_sphere_radius = 50.0
	_emit(p, target, target.global_position)

# === 银狼 ===
static func silverwolf_hack(target: Node):
	var p = _particle("diamond", 10, 0.55,
		[Color(0.4,1,1,1.0), Color(0.1,0.6,0.9,0.85), Color(0.0,0.3,0.6,0)],
		360, Vector2(), 60, 0.3, 0.6, 70.0, [0.5, 1.1, 0.0])
	var m = p.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_radius = 65.0; m.emission_ring_inner_radius = 20.0
	_emit(p, target, target.global_position)

# === 芝士仓鼠 ===
static func hamster_surge(character: Node):
	var p = _particle("star", 8, 0.45,
		[Color(1,1,0.7,1.0), Color(1,0.9,0.2,0.85), Color(0.9,0.7,0.0,0)],
		45, Vector2(0, -70), 160, 0.3, 0.6, 100.0, [0.0, 1.2, 0.0])
	_emit(p, character, character.global_position)

# === Karrigan ===
static func karrigan_smoke(character: Node, cell_pos: Vector2):
	for i in 2:
		var p = _particle("smoke", 6 + i * 3, 0.6 + i * 0.15,
			[Color(0.5,0.5,0.55,0.35), Color(0.3,0.3,0.35,0.1)],
			360, Vector2(0, -5), 25 + i * 20, 1.0 + i * 0.5, 2.5 + i, 5.0)
		var m = p.process_material as ParticleProcessMaterial
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		m.emission_ring_radius = 20.0 + i * 35.0; m.emission_ring_inner_radius = 0.0
		_emit(p, character, cell_pos)

# === Zephyr ===
static func zephyr_sacrifice(character: Node):
	var p = _particle("circle_soft", 10, 0.5,
		[Color(1,0.2,0.1,1.0), Color(0.6,0.1,0.1,0.8), Color(0.2,0,0,0)],
		360, Vector2(), 100, 0.3, 0.6, 50.0, [0.3, 1.0, 0.0])
	var m = p.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_radius = 60.0; m.emission_ring_inner_radius = 10.0
	_emit(p, character, character.global_position)

# === M1DorG ===
static func m1dorg_away(character: Node):
	var p = _particle("diamond", 10, 0.35,
		[Color(0.5,0.7,1,1.0), Color(0.3,0.5,0.8,0.85), Color(0.2,0.3,0.5,0)],
		180, Vector2(), 200, 0.3, 0.6, 100.0, [1.0, 0.4, 0.0])
	var m = p.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; m.emission_sphere_radius = 55.0
	_emit(p, character, character.global_position)

# === Richardovo ===
static func richardovo_break(character: Node):
	var p = _particle("circle", 8, 0.4,
		[Color(1,1,0.6,1.0), Color(1,0.85,0.2,0.85), Color(0.8,0.6,0.0,0)],
		360, Vector2(), 100, 0.3, 0.7, 80.0, [0.0, 1.3, 0.0])
	var m = p.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_radius = 25.0; m.emission_ring_inner_radius = 8.0
	_emit(p, character, character.global_position)

	var burst = _particle("spark", 8, 0.35,
		[Color(1,1,0.5,1.0), Color(1,0.9,0.3,0.85), Color(0.9,0.7,0.1,0)],
		180, Vector2(), 260, 0.3, 0.6, 150.0, [0.5, 1.2, 0.0])
	var m2 = burst.process_material as ParticleProcessMaterial
	m2.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; m2.emission_sphere_radius = 45.0
	_emit(burst, character, character.global_position)

# === あんパン ===
static func anpan_bake(character: Node):
	var p = _particle("circle_soft", 8, 0.55,
		[Color(1,0.9,0.4,0.9), Color(0.9,0.7,0.2,0.75), Color(0.7,0.5,0.1,0)],
		45, Vector2(0, -60), 80, 0.3, 0.6, 20.0, [0.0, 1.0, 0.0])
	var m = p.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; m.emission_sphere_radius = 50.0
	_emit(p, character, character.global_position)
