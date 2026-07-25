extends Node

var _pool: Array[Node2D] = []

func fire(from_pos: Vector2, target: Node, preset: String = "magic_bolt",
		speed: float = 0.3, on_hit: Callable = Callable()) -> Node2D:
	var p = _get_or_create()
	get_tree().current_scene.add_child(p)
	p.global_position = from_pos
	_setup_visual(p, preset)

	var target_pos = target.global_position
	var dist = from_pos.distance_to(target_pos)
	var duration = dist / 2000.0 * speed * 10.0
	duration = clamp(duration, 0.15, 1.0)

	var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(p, "global_position", target_pos, duration)
	tween.parallel().tween_property(p, "scale", Vector2(0.8, 0.8), duration * 0.8).set_delay(duration * 0.2)
	tween.tween_callback(func():
		if target is Node and is_instance_valid(target):
			_play_impact(p, preset, target)
			if on_hit.is_valid():
				on_hit.call()
		_recycle(p)
	)
	return p

func fire_arc(from_pos: Vector2, target: Node, preset: String = "heal_orb",
		speed: float = 0.4, height: float = 200.0, on_hit: Callable = Callable()) -> Node2D:
	var p = _get_or_create()
	get_tree().current_scene.add_child(p)
	p.global_position = from_pos
	_setup_visual(p, preset)

	var start = from_pos
	var end = target.global_position
	var mid = (start + end) * 0.5 + Vector2(0, -height)
	var dist = start.distance_to(end)
	var duration = clamp(dist / 1500.0, 0.2, 0.8)

	var elapsed = 0.0
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	var steps = 30
	for i in range(1, steps + 1):
		var t = float(i) / steps
		var q = t
		var pos = _quadratic_bezier(start, mid, end, q)
		tween.tween_property(p, "global_position", pos, duration / steps)

	tween.tween_callback(func():
		if target is Node and is_instance_valid(target):
			_play_impact(p, preset, target)
			if on_hit.is_valid():
				on_hit.call()
		_recycle(p)
	)
	return p

func _get_or_create() -> Node2D:
	if _pool.size() > 0:
		var p = _pool.pop_back()
		p.visible = true
		p.scale = Vector2.ONE
		p.rotation = 0.0
		return p
	return Node2D.new()

func _recycle(p: Node2D):
	p.get_parent().remove_child(p)
	for c in p.get_children():
		p.remove_child(c)
		c.queue_free()
	p.visible = false
	_pool.append(p)

func _setup_visual(p: Node2D, preset: String):
	var sprite = Sprite2D.new()
	p.add_child(sprite)

	match preset:
		"bullet":
			sprite.texture = _tex("circle")
			sprite.self_modulate = Color(1.0, 0.9, 0.3)
			sprite.scale = Vector2(0.2, 0.2)
			sprite.z_index = 15

		"magic_bolt":
			sprite.texture = _tex("circle")
			sprite.self_modulate = Color(0.3, 0.6, 1.0)
			sprite.scale = Vector2(0.25, 0.25)
			sprite.z_index = 15
			_add_glow(p, Color(0.2, 0.5, 1.0, 0.25), 0.5)
			_add_trail(p, Color(0.2, 0.5, 1.0, 0.3), 4, 0.2, 10.0)

		"fireball":
			sprite.texture = _tex("circle")
			sprite.self_modulate = Color(1.0, 0.5, 0.1)
			sprite.scale = Vector2(0.25, 0.25)
			sprite.z_index = 15
			_add_glow(p, Color(1.0, 0.3, 0.0, 0.3), 0.6)
			_add_trail(p, Color(1.0, 0.4, 0.0, 0.35), 5, 0.25, 12.0)

		"ice_shard":
			sprite.texture = _tex("diamond")
			sprite.self_modulate = Color(0.4, 0.7, 1.0)
			sprite.scale = Vector2(0.25, 0.25)
			sprite.z_index = 15

		"dark_bolt":
			sprite.texture = _tex("diamond")
			sprite.self_modulate = Color(0.6, 0.2, 0.8)
			sprite.scale = Vector2(0.25, 0.25)
			sprite.z_index = 15
			_add_trail(p, Color(0.5, 0.1, 0.6, 0.3), 4, 0.2, 10.0)

		"arrow":
			sprite.texture = _tex("spark")
			sprite.self_modulate = Color(0.8, 0.7, 0.5)
			sprite.scale = Vector2(0.2, 0.15)
			sprite.z_index = 15

		"heal_orb":
			sprite.texture = _tex("circle")
			sprite.self_modulate = Color(0.2, 1.0, 0.4)
			sprite.scale = Vector2(0.25, 0.25)
			sprite.z_index = 15
			_add_glow(p, Color(0.0, 1.0, 0.3, 0.2), 0.5)

func _add_glow(parent: Node2D, color: Color, scale_factor: float):
	var glow = Sprite2D.new()
	glow.texture = _tex("circle_soft")
	glow.self_modulate = color
	glow.scale = Vector2(scale_factor, scale_factor)
	glow.z_index = 14
	parent.add_child(glow)

func _add_trail(parent: Node2D, color: Color, amount: int, lifetime: float, velocity: float):
	var trail = GPUParticles2D.new()
	trail.one_shot = false
	trail.emitting = true
	trail.amount = amount
	trail.lifetime = lifetime
	trail.z_index = 14
	trail.local_coords = true
	trail.texture = _tex("circle_soft")
	trail.process_material = _make_trail_mat(color, velocity)
	parent.add_child(trail)

func _make_trail_mat(color: Color, vel: float) -> ParticleProcessMaterial:
	var m = ParticleProcessMaterial.new()
	m.color = color
	m.direction = Vector3(0, 0, 0)
	m.spread = 30
	m.gravity = Vector3(0, 0, 0)
	m.initial_velocity_min = vel * 0.3
	m.initial_velocity_max = vel
	m.scale_min = 0.8
	m.scale_max = 2.0
	m.hue_variation_max = 0.05
	return m

func _play_impact(p: Node2D, preset: String, target: Node):
	var vfx = target.get_node_or_null("VFXManager") if target.has_node("VFXManager") else null
	if not vfx:
		vfx = get_tree().current_scene.get_node_or_null("VFXManager")
	if vfx and vfx.has_method("play"):
		match preset:
			"fireball": vfx.play_at(target.global_position, "explosion")
			"ice_shard": vfx.play_at(target.global_position, "hit")
			"dark_bolt": vfx.play_at(target.global_position, "debuff")
			_:
				vfx.play_at(target.global_position, "hit")

func _quadratic_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var q = 1.0 - t
	return q * q * a + 2.0 * q * t * b + t * t * c

static var _tex_cache: Dictionary = {}

static func _tex(name: String) -> Texture2D:
	if _tex_cache.is_empty():
		var ptg = load("res://Global/ParticleTextureGenerator.gd")
		_tex_cache = ptg.generate_all()
	return _tex_cache.get(name) as Texture2D
