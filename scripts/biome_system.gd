# Biome definitions and classification.
# Biomes are determined from a point's temperature and moisture noise values.
# This keeps the rules simple, deterministic, and easy to extend.

class_name BiomeSystem

enum Type {
	PLAINS,          # grass, flowers, few trees
	FOREST,          # dense trees, lots of bushes
	SWAMP,           # wet, sparse trees, mushrooms
	DESERT,          # dry, sand, cacti-like
	TUNDRA,          # cold, sparse vegetation
	MOUNTAIN,        # rocky, high elevation
}

static func biome_name(t: Type) -> String:
	return Type.keys()[t]

# Temperature noise: 0..1 (0 = cold, 1 = hot)
# Moisture noise: 0..1 (0 = dry, 1 = wet)
# Elevation: 0..1 (0 = low, 1 = high)
static func classify(temp: float, moisture: float, elevation: float) -> Type:
	if elevation > 0.72:
		return Type.MOUNTAIN
	if temp < 0.28:
		if moisture > 0.5:
			return Type.SWAMP
		return Type.TUNDRA
	if temp > 0.62:
		if moisture < 0.35:
			return Type.DESERT
		return Type.PLAINS
	# temperate band
	if moisture > 0.55:
		return Type.FOREST
	if moisture > 0.35:
		return Type.PLAINS
	return Type.DESERT

static func tree_density(t: Type) -> float:
	match t:
		Type.FOREST: return 0.65
		Type.SWAMP:   return 0.35
		Type.PLAINS:  return 0.12
		Type.TUNDRA:  return 0.05
		Type.DESERT:  return 0.01
		Type.MOUNTAIN: return 0.08
	return 0.08

static func bush_density(t: Type) -> float:
	match t:
		Type.FOREST: return 0.30
		Type.SWAMP:   return 0.25
		Type.PLAINS:  return 0.20
		Type.TUNDRA:  return 0.10
		Type.DESERT:  return 0.03
		Type.MOUNTAIN: return 0.10
	return 0.15

static func grass_color(t: Type) -> Color:
	match t:
		Type.FOREST:   return Color(0.18, 0.38, 0.10)
		Type.SWAMP:    return Color(0.22, 0.30, 0.10)
		Type.PLAINS:   return Color(0.32, 0.45, 0.14)
		Type.TUNDRA:   return Color(0.35, 0.38, 0.22)
		Type.DESERT:   return Color(0.42, 0.38, 0.18)
		Type.MOUNTAIN: return Color(0.30, 0.30, 0.26)
	return Color(0.3, 0.4, 0.15)

static func flower_color(t: Type) -> Color:
	match t:
		Type.PLAINS:   return Color(0.85, 0.72, 0.35)
		Type.FOREST:   return Color(0.78, 0.45, 0.60)
		Type.SWAMP:    return Color(0.65, 0.55, 0.75)
		Type.TUNDRA:   return Color(0.85, 0.85, 0.70)
		Type.DESERT:   return Color(0.90, 0.60, 0.30)
		Type.MOUNTAIN: return Color(0.70, 0.65, 0.80)
	return Color(0.8, 0.6, 0.4)
