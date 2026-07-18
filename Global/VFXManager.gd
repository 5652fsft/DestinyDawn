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
	p.z_index = 50
	return p

func _material(color: Color, dir: float = 0.0, spread: float = 180.0,
		gravity: Vector2 = Vector2.ZERO, init_vel: float = 100.0) -> ParticleProcessMaterial:
	var m = ParticleProcessMaterial.new()
	m.color = color
	m.direction = Vector3(cos(deg_to_rad(dir)), sin(deg_to_rad(dir)), 0)
	m.spread = spread
	m.gravity = Vector3(gravity.x, gravity.y, 0)
	m.initial_velocity_min = init_vel * 0.5
	m.initial_velocity_max = init_vel
	m.scale_min = 1.0
	m.scale_max = 2.5
	m.hue_variation_min = 0.0
	m.hue_variation_max = 0.05
	return m

func _make_hit() -> GPUParticles2D:
	var p = _base()
	p.amount = 16
	p.lifetime = 0.35
	p.process_material = _material(PRESET_COLORS.hit, 270, 180, Vector2(0, 0), 200)
	return p

func _make_heal() -> GPUParticles2D:
	var p = _base()
	p.amount = 20
	p.lifetime = 0.5
	p.process_material = _material(PRESET_COLORS.heal, 270, 30, Vector2(0, -80), 120)
	return p

func _make_shield() -> GPUParticles2D:
	var p = _base()
	p.amount = 12
	p.lifetime = 0.45
	var m = _material(PRESET_COLORS.shield, 0, 360, Vector2(), 80)
	m.scale_min = 0.6
	m.scale_max = 1.5
	p.process_material = m
	return p

func _make_buff() -> GPUParticles2D:
	var p = _base()
	p.amount = 16
	p.lifetime = 0.5
	p.process_material = _material(PRESET_COLORS.buff, 0, 360, Vector2(0, -60), 130)
	return p

func _make_debuff() -> GPUParticles2D:
	var p = _base()
	p.amount = 14
	p.lifetime = 0.55
	var m = _material(PRESET_COLORS.debuff, 0, 360, Vector2(), 100)
	m.angular_velocity_min = -4.0
	m.angular_velocity_max = 4.0
	p.process_material = m
	return p

func _make_entrance() -> GPUParticles2D:
	var p = _base()
	p.amount = 24
	p.lifetime = 0.45
	p.process_material = _material(PRESET_COLORS.entrance, 270, 45, Vector2(0, -100), 160)
	return p

func _make_explosion() -> GPUParticles2D:
	var p = _base()
	p.amount = 30
	p.lifetime = 0.45
	var m = ParticleProcessMaterial.new()
	m.color = Color(1.0, 0.5, 0.1)
	m.color_ramp = Gradient.new()
	m.color_ramp.colors = [Color(1,1,0.5), Color(1,0.5,0), Color(1,0.2,0.1)]
	m.direction = Vector3(0, -1, 0)
	m.spread = 180
	m.initial_velocity_min = 150
	m.initial_velocity_max = 350
	m.scale_min = 1.0
	m.scale_max = 3.0
	m.hue_variation_min = 0.0
	m.hue_variation_max = 0.15
	p.process_material = m
	return p

func _auto_free(p: GPUParticles2D):
	await get_tree().create_timer(p.lifetime + 0.1).timeout
	if is_instance_valid(p):
		p.queue_free()
