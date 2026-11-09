# Generates terrain heightmap, biomes, and object placements.
# Uses overlapping noise maps for height, then classifies biomes from
# temperature + moisture + elevation, then scatters trees/bushes/rocks.

extends Node

class_name WorldGenerator

var config: WorldConfig
var rng: RandomNumberGenerator

# Noise caches
var _elev_noise: FastNoiseLite
var _moist_noise: FastNoiseLite
var _temp_noise: FastNoiseLite
var _scatter_noise: FastNoiseLite

# Heightmap cache: dict keyed by "x,y" -> float (0..1)
var _height_cache: Dictionary = {}

func _init(cfg: WorldConfig) -> void:
    config = cfg
    rng = RandomNumberGenerator.new()
    rng.seed = _hash_seed(cfg.world_seed)
    _build_noise()

func _hash_seed(s: String) -> int:
    var h: int = 2166136261
    for i in range(s.length()):
        h ^= s.unicode_at(i)
        h *= 16777619
    if h == 0:
        h = 1
    return h

func _build_noise() -> void:
    var base_seed: int = rng.seed
    _elev_noise = _make_noise(base_seed, FastNoiseLite.TYPE_PERLIN, config.base_frequency,
        config.elevation_octaves, config.elevation_lacunarity, config.elevation_gain)
    _moist_noise = _make_noise(base_seed ^ 0x9E3779B9, FastNoiseLite.TYPE_PERLIN, config.moisture_frequency,
        config.moisture_octaves, config.moisture_lacunarity, config.moisture_gain)
    _temp_noise = _make_noise(base_seed ^ 0x85EBCA77, FastNoiseLite.TYPE_PERLIN, config.temperature_frequency,
        config.temperature_octaves, config.temperature_lacunarity, config.temperature_gain)
    _scatter_noise = _make_noise(base_seed ^ 0xC2B2AE3D, FastNoiseLite.TYPE_PERLIN, config.scatter_frequency,
        config.scatter_octaves, 2.0, 0.5)

static func _make_noise(p_seed: int, noise_type: FastNoiseLite.NoiseType, frequency: float,
        octaves: int, lacunarity: float, gain: float) -> FastNoiseLite:
    var n := FastNoiseLite.new()
    n.seed = p_seed
    n.noise_type = noise_type
    n.frequency = frequency
    n.fractal_octaves = octaves
    n.fractal_lacunarity = lacunarity
    n.fractal_gain = gain
    return n

# Returns height value 0..1 for a world coordinate.
# Uses overlapping noise maps: base elevation + moisture ridges + detail.
func get_height(x: int, y: int) -> float:
    var key := "%d,%d" % [x, y]
    if _height_cache.has(key):
        return _height_cache[key]

    var fx := float(x)
    var fy := float(y)

    var base := (_elev_noise.get_noise_2d(fx, fy) + 1.0) * 0.5
    # Flatten/Smooth terrain curve to create rolling plains/plateaus
    base = pow(base, 1.3)
    
    # Add moisture-driven ridges for more varied terrain
    var moist := (_moist_noise.get_noise_2d(fx * 0.7, fy * 0.7) + 1.0) * 0.5
    # Combine: base dominates, moisture adds variation
    var combined := base * 0.85 + moist * 0.15

    # Detail noise for micro-variation
    var detail := (_scatter_noise.get_noise_2d(fx * 2.0, fy * 2.0) + 1.0) * 0.5
    combined += detail * 0.06

    # Clamp
    if combined < 0.0:
        combined = 0.0
    elif combined > 1.0:
        combined = 1.0

    _height_cache[key] = combined
    return combined

func get_biome(x: int, y: int) -> int:
    var fx := float(x)
    var fy := float(y)
    var temp := (_temp_noise.get_noise_2d(fx, fy) + 1.0) * 0.5
    var moist := (_moist_noise.get_noise_2d(fx, fy) + 1.0) * 0.5
    var elev := get_height(x, y)
    return BiomeSystem.classify(temp, moist, elev)

func get_temperature(x: int, y: int) -> float:
    return (_temp_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5

func get_moisture(x: int, y: int) -> float:
    return (_moist_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5

# Scatter check: uses scatter noise to decide if an object should be placed.
# Returns a probability 0..1 for the given cell.
func scatter_prob(x: int, y: int) -> float:
    return (_scatter_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5

# Clear height cache (useful when seed changes)
func clear_cache() -> void:
    _height_cache.clear()
    _build_noise()
