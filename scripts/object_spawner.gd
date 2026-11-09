extends Node

class_name ObjectSpawner

var generator: WorldGenerator
var config: WorldConfig

# Asset paths
const TREE_ASSET := "res://assets/models/deciduous_tree.glb"
const PINE_ASSET := "res://assets/models/pine_tree.glb"
const BUSH_ASSET := "res://assets/models/bush_mushroom.glb"
const ROCK_ASSET := "res://assets/models/rock_large.glb"

var _rng: RandomNumberGenerator

func _init(gen: WorldGenerator, cfg: WorldConfig) -> void:
	generator = gen
	config = cfg
	_rng = RandomNumberGenerator.new()
	_rng.seed = generator.rng.seed ^ 0xDEADBEEF

# Place all objects for a given chunk into the provided parent node.
# chunk_origin: world (x, y) of the chunk's bottom-left corner.
func populate_chunk(parent: Node3D, chunk_origin: Vector2, chunk_size: int) -> void:
	var cx := int(chunk_origin.x)
	var cy := int(chunk_origin.y)

	for offset_y in range(chunk_size):
		for offset_x in range(chunk_size):
			var wx := cx + offset_x
			var wy := cy + offset_y
			var biome := generator.get_biome(wx, wy)
			var tree_dens := BiomeSystem.tree_density(biome)
			var bush_dens := BiomeSystem.bush_density(biome)

			var sp := generator.scatter_prob(wx, wy)
			var r := _rng.randf_range(0.0, 1.0)

			# Trees - only in forests, tundra, plains
			if (biome == BiomeSystem.Type.FOREST or 
				biome == BiomeSystem.Type.TUNDRA or 
				biome == BiomeSystem.Type.PLAINS) and sp < tree_dens:
				_maybe_place_tree(parent, wx, wy, biome)

			# Bushes - in most biomes except deserts
			if biome != BiomeSystem.Type.DESERT and sp > tree_dens and r < bush_dens:
				_maybe_place_bush(parent, wx, wy, biome)

			# Rocks - in mountains
			if biome == BiomeSystem.Type.MOUNTAIN and sp < 0.3:
				_maybe_place_rock(parent, wx, wy)

func _maybe_place_tree(parent: Node3D, wx: int, wy: int, biome: int) -> void:
	var r := _rng.randf_range(0.0, 1.0)
	if r > 0.6:
		return

	var asset := TREE_ASSET
	if biome == BiomeSystem.Type.TUNDRA:
		asset = PINE_ASSET
	elif biome == BiomeSystem.Type.FOREST:
		if _rng.randf() < 0.4:
			asset = PINE_ASSET

	var inst: Node3D = _instantiate(parent, asset)
	if inst == null:
		return

	var h := generator.get_height(wx, wy)
	
	# Simple slope check: skip if neighbors are significantly different in height
	var h_east := generator.get_height(wx + 1, wy)
	var h_north := generator.get_height(wx, wy + 1)
	if abs(h - h_east) > 0.05 or abs(h - h_north) > 0.05:
		return

	var world_y := h * float(config.world_height)
	var scale := _rng.randf_range(config.tree_scale_min, config.tree_scale_max)

	# Offset slightly up to prevent sinking too deep
	inst.position = Vector3(float(wx), world_y + 0.1, float(wy))
	inst.scale = Vector3(scale, scale, scale)
	inst.rotation_degrees.y = _rng.randf_range(0.0, 360.0)

func _maybe_place_bush(parent: Node3D, wx: int, wy: int, _biome: int) -> void:
	var r := _rng.randf_range(0.0, 1.0)
	if r > 0.5:
		return

	var inst: Node3D = _instantiate(parent, BUSH_ASSET)
	if inst == null:
		return

	var h := generator.get_height(wx, wy)
	var world_y := h * float(config.world_height)
	var scale := _rng.randf_range(config.bush_scale_min, config.bush_scale_max)

	inst.position = Vector3(float(wx), world_y, float(wy))
	inst.scale = Vector3(scale, scale, scale)
	inst.rotation_degrees.y = _rng.randf_range(0.0, 360.0)

func _maybe_place_rock(parent: Node3D, wx: int, wy: int) -> void:
	var r := _rng.randf_range(0.0, 1.0)
	if r > 0.4:
		return

	var inst: Node3D = _instantiate(parent, ROCK_ASSET)
	if inst == null:
		return

	var h := generator.get_height(wx, wy)
	var world_y := h * float(config.world_height)
	var scale := _rng.randf_range(0.6, 1.2)

	inst.position = Vector3(float(wx), world_y, float(wy))
	inst.scale = Vector3(scale, scale, scale)
	inst.rotation_degrees.y = _rng.randf_range(0.0, 360.0)

func _instantiate(parent: Node3D, asset_path: String) -> Node3D:
	var packed: PackedScene = load(asset_path) as PackedScene
	if packed == null:
		push_error("Failed to load asset: " + asset_path)
		return null
	var inst: Node3D = packed.instantiate() as Node3D
	_apply_material_colors(inst)
	parent.add_child(inst)
	return inst

func _apply_material_colors(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.material_override == null:
			var mat := StandardMaterial3D.new()
			mat.vertex_color_use_as_albedo = true
			mat.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL
			mat.roughness = 0.85
			mi.material_override = mat
		elif mi.material_override is StandardMaterial3D:
			(mi.material_override as StandardMaterial3D).vertex_color_use_as_albedo = true
	for child in node.get_children():
		_apply_material_colors(child)

static func _hash_xy(x: int, y: int) -> int:
	var h := 2166136261
	h ^= x
	h *= 16777619
	h ^= y
	h *= 16777619
	return h
