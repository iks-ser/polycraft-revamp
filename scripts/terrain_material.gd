# Creates a procedural low-poly terrain material with grass/rock/flower tinting.
# Uses vertex colors or a triplanar-ish approach for simple low-poly style.

extends Node

static func create_terrain_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = "TerrainMaterial"
	mat.vertex_color_is_srgb = true
	# Low-poly flat shading look
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_FLAT
	mat.roughness = 0.85
	mat.vertex_color_use_as_albedo = true
	return mat
