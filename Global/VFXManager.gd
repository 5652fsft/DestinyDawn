extends Node

const PRESET_COLORS = {
	hit = Color(1.0, 0.3, 0.1),
	heal = Color(0.2, 1.0, 0.3),
	shield = Color(0.3, 0.6, 1.0),
	buff = Color(1.0, 0.9, 0.2),
	debuff = Color(0.6, 0.2, 0.8),
	entrance = Color(1.0, 0.85, 0.3),
}

func play(target: Node, preset: String, attach: bool = true) -> GPUParticles2D:
	var p = _create(preset)
	if not p:
		return null
	if attach and target:
		target.add_child(p)
		p.global_position = target.global_position
	else:
		get_tree().current_scene.add_child(p)
		if target:
			p.global_position = target.global_position
	p.emitting = true
	_auto_free(p)
	return p

func play_at(pos: Vector2, preset: String) -> GPUParticles2D:
	var p = _create(preset)
	if not p:
		return null
	get_tree().current_scene.add_child(p)
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
	p.z_index = 100
	p.local_coords = false
	return p

func _ramp_gradient(colors: Array) -> Gradient:
	var g = Gradient.new()
	g.offsets = []
	g.colors = colors
	var step = 1.0 / max(colors.size() - 1, 1)
	for i in range(colors.size()):
		g.offsets.append(i * step)
	return g

func _make_material(color: Color, ramp_colors: Array, dir: float, spread: float,
		gravity: Vector2, vel: float, scale_min: float, scale_max: float,
		angular: float = 0.0) -> ParticleProcessMaterial:
	var m = ParticleProcessMaterial.new()
	m.color = color
	m.color_ramp = _ramp_gradient(ramp_colors)
	m.direction = Vector3(cos(deg_to_rad(dir)), sin(deg_to_rad(dir)), 0)
	m.spread = spread
	m.gravity = Vector3(gravity.x, gravity.y, 0)
	m.initial_velocity_min = vel * 0.5
	m.initial_velocity_max = vel
	m.scale_min = scale_min
	m.scale_max = scale_max
	if angular != 0:
		m.angular_velocity_min = -angular
		m.angular_velocity_max = angular
	m.hue_variation_min = 0.0
	m.hue_variation_max = 0.05
	return m

func _make_hit() -> GPUParticles2D:
	var p = _base()
	p.amount = 24
	p.lifetime = 0.4
	p.process_material = _make_material(
		PRESET_COLORS.hit,
		[Color(1,1,0.6), Color(1,0.5,0.1), Color(1,0.15,0.05)],
		270, 180, Vector2(0, 0), 300, 1.5, 4.0)
	return p

func _make_heal() -> GPUParticles2D:
	var p = _base()
	p.amount = 20
	p.lifetime = 0.5
	p.process_material = _make_material(
		PRESET_COLORS.heal,
		[Color(0.6,1,0.6), Color(0.0,1.0,0.3), Color(0.0,0.8,0.2)],
		270, 30, Vector2(0, -80), 150, 1.5, 3.5)
	return p

func _make_shield() -> GPUParticles2D:
	var p = _base()
	p.amount = 16
	p.lifetime = 0.45
	p.process_material = _make_material(
		PRESET_COLORS.shield,
		[Color(0.6,0.8,1), Color(0.3,0.6,1.0), Color(0.2,0.4,0.8)],
		0, 360, Vector2(), 100, 1.0, 3.0)
	return p

func _make_buff() -> GPUParticles2D:
	var p = _base()
	p.amount = 20
	p.lifetime = 0.5
	p.process_material = _make_material(
		PRESET_COLORS.buff,
		[Color(1,1,0.8), Color(1.0,0.9,0.2), Color(0.9,0.7,0.0)],
		0, 360, Vector2(0, -60), 160, 1.5, 4.0)
	return p

func _make_debuff() -> GPUParticles2D:
	var p = _base()
	p.amount = 18
	p.lifetime = 0.55
	p.process_material = _make_material(
		PRESET_COLORS.debuff,
		[Color(0.8,0.4,1), Color(0.6,0.2,0.8), Color(0.4,0.1,0.6)],
		0, 360, Vector2(), 120, 1.5, 3.5, 5.0)
	return p

func _make_entrance() -> GPUParticles2D:
	var p = _base()
	p.amount = 28
	p.lifetime = 0.45
	p.process_material = _make_material(
		PRESET_COLORS.entrance,
		[Color(1,1,0.7), Color(1.0,0.85,0.3), Color(0.9,0.7,0.1)],
		270, 45, Vector2(0, -120), 200, 1.5, 4.0)
	return p

func _make_explosion() -> GPUParticles2D:
	var p = _base()
	p.amount = 35
	p.lifetime = 0.5
	p.process_material = _make_material(
		Color(1.0, 0.5, 0.1),
		[Color(1,1,0.5), Color(1,0.5,0), Color(1,0.2,0.1)],
		270, 180, Vector2(0, 0), 400, 2.0, 5.0)
	return p

func _auto_free(p: GPUParticles2D):
	await get_tree().create_timer(p.lifetime + 0.15).timeout
	if is_instance_valid(p):
		p.queue_free()
