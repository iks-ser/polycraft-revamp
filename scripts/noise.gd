extends Node

# Wraps Godot's FastNoiseLite with seed support (text seeds via hashing).
# Provides multiple octaves and a stable API for terrain/biome noise.

var _seed_hash: int = 0

func _init(seed_value: Variant = null) -> void:
    if seed_value != null:
        set_seed(seed_value)

func set_seed(seed_value: Variant) -> void:
    _seed_hash = _hash_seed(seed_value)

func _hash_seed(seed_value: Variant) -> int:
    var s: String = str(seed_value)
    var h: int = 2166136261
    for i in range(s.length()):
        h ^= s[i].unicode_at(i)
        h *= 16777619
    # Ensure non-zero
    if h == 0:
        h = 1
    return h

func get_seed() -> int:
    return _seed_hash

# Returns a FastNoiseLite configured for the given parameters.
static func make_noise(seed: int, noise_type: int = 2, frequency: float = 0.05,
        octaves: int = 4, lacunarity: float = 2.0, gain: float = 0.5,
        seed_octaves: int = 1) -> FastNoiseLite:
    var n := FastNoiseLite.new()
    n.seed = seed
    n.noise_type = noise_type
    n.frequency = frequency
    n.octaves = octaves
    n.lacunarity = lacunarity
    n.gain = gain
    n.seed_octaves = seed_octaves
    return n

# Sample 2D noise at world coordinates, returns 0..1
func sample2d(n: FastNoiseLite, x: float, y: float) -> float:
    return (n.get_noise_2d(x, y) + 1.0) * 0.5

# Sample 3D noise
func sample3d(n: FastNoiseLite, x: float, y: float, z: float) -> float:
    return (n.get_noise_3d(x, y, z) + 1.0) * 0.5