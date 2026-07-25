extends Node

const PRESET_COLORS = {
	hit = Color(1.0, 0.3, 0.1),
	heal = Color(0.2, 1.0, 0.3),
	shield = Color(0.3, 0.6, 1.0),
	buff = Color(1.0, 0.9, 0.2),
	debuff = Color(0.6, 0.2, 0.8),
	entrance = Color(1.0, 0.85, 0.3),
	explosion = Color(1.0, 0.5, 0.1),
}

static var _textures: Dictionary = {}
static var _textures_loaded: bool = false

static func _ensure_textures():
	if _textures_loaded:
		return
	_textures_loaded = true
	var ptg = load("res://Global/ParticleTextureGenerator.gd")
	_textures = ptg.generate_all()

static func _get_tex(name: String) -> Texture2D:
	_ensure_textures()
	return _textures.get(name) as Texture2D

func play(target: Node, preset: String, attach: bool = true) -> GPUParticles2D:
	var p = _create(preset)
	if not p:
		return null
	if attach and target:
		target.add_child(p)
		p.global_position = target.global_position
	else:
		var scene = get_tree().current_scene
		if scene: scene.add_child(p)
		if target: p.global_position = target.global_position
	p.emitting = true
	_auto_free(p)
	return p

func play_at(pos: Vector2, preset: String) -> GPUParticles2D:
	var p = _create(preset)
	if not p: return null
	var scene = get_tree().current_scene
	if scene: scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	_auto_free(p)
	return p

func _create(preset: String) -> GPUParticles2D:
	match preset:
		"hit": return _make_hit()
		"heal": return _make_heal()
		"shield": return _make_shield()
		"buff": return _make_buff()
		"debuff": return _make_debuff()
		"entrance": return _make_entrance()
		"explosion": return _make_explosion()
		_: return null

func _base() -> GPUParticles2D:
	var p = GPUParticles2D.new()
	p.one_shot = true
	p.fixed_fps = 0
	p.interpolate = true
	p.z_index = 5
	p.local_coords = false
	return p

func _ramp_texture(colors: Array) -> GradientTexture1D:
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

static func _scale_curve(pts: Array) -> CurveTexture:
	var c = Curve.new()
	for i in range(pts.size()): c.add_point(Vector2(float(i) / max(pts.size() - 1, 1), pts[i]))
	var ct = CurveTexture.new(); ct.curve = c; return ct

func _make_material(ramp_colors: Array, spread: float, gravity: Vector2,
		vel: float, scale_min: float, scale_max: float, angular: float = 0.0,
		scale_pts: Array = []) -> ParticleProcessMaterial:
	var m = ParticleProcessMaterial.new()
	m.color = Color.WHITE
	m.color_ramp = _ramp_texture(ramp_colors)
	m.spread = spread
	m.gravity = Vector3(gravity.x, gravity.y, 0)
	m.initial_velocity_min = vel * 0.4
	m.initial_velocity_max = vel
	m.scale_min = scale_min
	m.scale_max = scale_max
	if angular != 0: m.angular_velocity_min = -angular; m.angular_velocity_max = angular
	if not scale_pts.is_empty(): m.scale_curve = _scale_curve(scale_pts)
	return m

func _set_sphere(m: ParticleProcessMaterial, radius: float): m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; m.emission_sphere_radius = radius
func _set_ring(m: ParticleProcessMaterial, radius: float, inner: float): m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING; m.emission_ring_radius = radius; m.emission_ring_inner_radius = inner

func _make_hit() -> GPUParticles2D:
	var p = _base(); p.texture = _get_tex("spark"); p.amount = 10; p.lifetime = 0.35
	var m = _make_material([Color(1,1,0.6,1.0), Color(1,0.5,0.1,0.8), Color(1,0.15,0.05,0)], 180, Vector2(), 300, 0.3, 0.6, 150.0, [0.5, 1.0, 0.2])
	p.process_material = m; _set_sphere(m, 55.0); return p

func _make_heal() -> GPUParticles2D:
	var p = _base(); p.texture = _get_tex("circle"); p.amount = 8; p.lifetime = 0.5
	var m = _make_material([Color(0.6,1,0.6,1.0), Color(0.0,1.0,0.3,0.8), Color(0.0,0.8,0.2,0)], 20, Vector2(0, -50), 120, 0.3, 0.5, 20.0, [0.3, 1.0, 0.0])
	p.process_material = m; _set_sphere(m, 50.0); return p

func _make_shield() -> GPUParticles2D:
	var p = _base(); p.texture = _get_tex("circle"); p.amount = 8; p.lifetime = 0.45
	var m = _make_material([Color(0.6,0.8,1,1.0), Color(0.3,0.6,1.0,0.8), Color(0.2,0.4,0.8,0)], 360, Vector2(), 60, 0.3, 0.6, 40.0, [0.5, 1.2, 0.2])
	p.process_material = m; _set_ring(m, 75.0, 10.0); return p

func _make_buff() -> GPUParticles2D:
	var p = _base(); p.texture = _get_tex("star"); p.amount = 10; p.lifetime = 0.5
	var m = _make_material([Color(1,1,0.8,1.0), Color(1.0,0.9,0.2,0.8), Color(0.9,0.7,0.0,0)], 360, Vector2(0, -40), 120, 0.3, 0.6, 80.0, [0.2, 1.2, 0.0])
	p.process_material = m; _set_sphere(m, 55.0); return p

func _make_debuff() -> GPUParticles2D:
	var p = _base(); p.texture = _get_tex("diamond"); p.amount = 8; p.lifetime = 0.5
	var m = _make_material([Color(0.8,0.4,1,1.0), Color(0.6,0.2,0.8,0.8), Color(0.4,0.1,0.6,0)], 360, Vector2(0, 30), 80, 0.3, 0.6, 60.0, [1.0, 0.5, 0.0])
	p.process_material = m; _set_sphere(m, 65.0); return p

func _make_entrance() -> GPUParticles2D:
	var p = _base(); p.texture = _get_tex("star"); p.amount = 12; p.lifetime = 0.4
	var m = _make_material([Color(1,1,0.7,1.0), Color(1.0,0.85,0.3,0.8), Color(0.9,0.7,0.1,0)], 40, Vector2(0, -70), 180, 0.3, 0.8, 40.0, [0.0, 1.3, 0.0])
	p.process_material = m; _set_ring(m, 75.0, 8.0); return p

func _make_explosion() -> GPUParticles2D:
	var p = _base(); p.texture = _get_tex("spark"); p.amount = 15; p.lifetime = 0.4
	var m = _make_material([Color(1,1,0.5,1.0), Color(1,0.5,0,0.9), Color(1,0.2,0.1,0)], 180, Vector2(), 400, 0.4, 0.8, 150.0, [0.3, 1.2, 0.2])
	p.process_material = m; _set_sphere(m, 60.0); return p

func _auto_free(p: GPUParticles2D):
	await get_tree().create_timer(p.lifetime + 0.2).timeout
	if is_instance_valid(p): p.queue_free()
