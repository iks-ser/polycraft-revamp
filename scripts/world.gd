# Main world scene controller with dynamic chunk loading and player movement.
extends Node3D

@export var world_config: WorldConfig = WorldConfig.new()

var generator: WorldGenerator
var spawner: ObjectSpawner
var player: CharacterBody3D

var chunk_size: int = 16
var render_distance: int = 5
var active_chunks: Dictionary = {}
var last_player_chunk: Vector2i = Vector2i(-999, -999)
var chunk_queue: Array = []
var max_concurrent_chunks: int = 5

func _ready() -> void:
	generator = WorldGenerator.new(world_config)
	spawner = ObjectSpawner.new(generator, world_config)
	_setup_environment()
	_setup_player()
	
	if player != null:
		var p_pos := player.global_transform.origin
		var cx := floori(p_pos.x / float(chunk_size))
		var cz := floori(p_pos.z / float(chunk_size))
		last_player_chunk = Vector2i(cx, cz)
		
		# Immediately generate initial 3x3 chunks around player so they don't fall
		for cz_off in range(-1, 2):
			for cx_off in range(-1, 2):
				var target_cx = cx + cx_off
				var target_cz = cz + cz_off
				var chunk_node := _create_chunk(target_cx, target_cz)
				var key := "%d,%d" % [target_cx, target_cz]
				active_chunks[key] = chunk_node
				add_child(chunk_node)
	
	_update_chunks()

func _process(_delta: float) -> void:
	if player != null:
		var p_pos := player.global_transform.origin
		var cx := floori(p_pos.x / float(chunk_size))
		var cz := floori(p_pos.z / float(chunk_size))
		var p_chunk := Vector2i(cx, cz)
		
		if p_chunk != last_player_chunk:
			last_player_chunk = p_chunk
			_update_chunks()
	
	_process_chunk_queue()

func _update_chunks() -> void:
	var center_cx := last_player_chunk.x
	var center_cz := last_player_chunk.y
	var new_active: Dictionary = {}
	
	for cz in range(center_cz - render_distance, center_cz + render_distance + 1):
		for cx in range(center_cx - render_distance, center_cx + render_distance + 1):
			var key := "%d,%d" % [cx, cz]
			if active_chunks.has(key):
				new_active[key] = active_chunks[key]
				active_chunks.erase(key)
			else:
				if not _is_chunk_queued(cx, cz):
					chunk_queue.append(Vector2i(cx, cz))
				
	for key in active_chunks.keys():
		var chunk_node: Node3D = active_chunks[key]
		chunk_node.queue_free()
		
	active_chunks = new_active

func _process_chunk_queue() -> void:
	if chunk_queue.size() == 0:
		return
	
	# Process up to 3 chunks per frame so chunks load smoothly as player moves
	for i in range(min(3, chunk_queue.size())):
		var chunk_to_load: Vector2i = chunk_queue[0] as Vector2i
		chunk_queue.remove_at(0)
		
		var cx: int = chunk_to_load.x
		var cz: int = chunk_to_load.y
		
		var key := "%d,%d" % [cx, cz]
		if not active_chunks.has(key):
			var chunk_node := _create_chunk(cx, cz)
			active_chunks[key] = chunk_node
			add_child(chunk_node)

func _is_chunk_queued(cx: int, cz: int) -> bool:
	for queued in chunk_queue:
		if queued.x == cx and queued.y == cz:
			return true
	return false

func _create_chunk(cx: int, cz: int) -> Node3D:
	var chunk_node := Node3D.new()
	chunk_node.name = "Chunk_%d_%d" % [cx, cz]
	var origin_x := float(cx * chunk_size)
	var origin_z := float(cz * chunk_size)
	
	var mesh := _generate_chunk_mesh(cx, cz)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "TerrainMesh"
	chunk_node.add_child(mi)
	
	# Add collision for Jolt Physics
	var col_shape := mesh.create_trimesh_shape()
	if col_shape != null:
		var static_body := StaticBody3D.new()
		static_body.name = "TerrainBody"
		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = col_shape
		static_body.add_child(collision_shape)
		chunk_node.add_child(static_body)
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 0.9
	mat.vertex_color_use_as_albedo = true
	mi.material_override = mat
	
	spawner.populate_chunk(chunk_node, Vector2(origin_x, origin_z), chunk_size)
	return chunk_node

func _generate_chunk_mesh(cx: int, cz: int) -> ArrayMesh:
	var cs := chunk_size
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()

	for z in range(cs):
		for x in range(cs):
			var wx := cx * cs + x
			var wz := cz * cs + z
			var p00 := _get_world_pos(wx, wz)
			var p10 := _get_world_pos(wx + 1, wz)
			var p01 := _get_world_pos(wx, wz + 1)
			var p11 := _get_world_pos(wx + 1, wz + 1)

			_add_triangle(verts, normals, colors, uvs, p00, p10, p01)
			_add_triangle(verts, normals, colors, uvs, p10, p11, p01)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _get_world_pos(x: int, z: int) -> Vector3:
	var h := generator.get_height(x, z)
	return Vector3(float(x), h * float(world_config.world_height), float(z))

func _add_triangle(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, uvs: PackedVector2Array, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	var n := (p2 - p1).cross(p3 - p1).normalized()
	verts.append_array([p1, p2, p3])
	normals.append_array([n, n, n])
	
	var avg_pos := (p1 + p2 + p3) / 3.0
	var biome := generator.get_biome(int(avg_pos.x), int(avg_pos.z))
	var grass := BiomeSystem.grass_color(biome)
	var flower := BiomeSystem.flower_color(biome)
	var flower_mix := 0.0
	if biome == BiomeSystem.Type.PLAINS or biome == BiomeSystem.Type.FOREST:
		if generator.scatter_prob(int(avg_pos.x), int(avg_pos.z)) > 0.7:
			flower_mix = 0.4
	var col := grass.lerp(flower, flower_mix)
	
	var avg_h := avg_pos.y / float(world_config.world_height)
	if avg_h > 0.75: col = col.lerp(Color(0.55, 0.52, 0.48), 0.5)
	elif avg_h < 0.3: col = col.lerp(Color(0.2, 0.4, 0.2), 0.2)
		
	colors.append_array([col, col, col])
	uvs.append_array([Vector2(p1.x, p1.z) * 0.1, Vector2(p2.x, p2.z) * 0.1, Vector2(p3.x, p3.z) * 0.1])

func _setup_environment() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = ProceduralSkyMaterial.new()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 45, 0)
	sun.shadow_enabled = true
	add_child(sun)

func _setup_player() -> void:
	player = get_node_or_null("Player") as CharacterBody3D
	if player == null:
		var player_scene: PackedScene = load("res://scenes/player.tscn") as PackedScene
		if player_scene != null:
			player = player_scene.instantiate() as CharacterBody3D
			add_child(player)
	
	if player != null:
		var cx := float(world_config.world_size) * 0.5
		var cz := float(world_config.world_size) * 0.5
		var h := generator.get_height(int(cx), int(cz)) * float(world_config.world_height)
		player.global_transform.origin = Vector3(cx, h + 5.0, cz)
