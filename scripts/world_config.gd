# World configuration: size, seed, noise parameters, chunk settings.
extends Resource

class_name WorldConfig

@export var world_seed: String = "PolyCraft"
@export var world_size: int = 256          # blocks per side
@export var world_height: int = 64         # max terrain height
@export var sea_level: int = 32
@export var chunk_size: int = 16           # blocks per chunk side

# Noise parameters
@export var base_frequency: float = 0.008
@export var elevation_octaves: int = 3
@export var elevation_lacunarity: float = 2.0
@export var elevation_gain: float = 0.5

@export var moisture_frequency: float = 0.025
@export var moisture_octaves: int = 4
@export var moisture_lacunarity: float = 2.0
@export var moisture_gain: float = 0.5

@export var temperature_frequency: float = 0.02
@export var temperature_octaves: int = 4
@export var temperature_lacunarity: float = 2.0
@export var temperature_gain: float = 0.5

# Detail noise for micro-variation on terrain
@export var detail_frequency: float = 0.12
@export var detail_octaves: int = 3
@export var detail_lacunarity: float = 2.0
@export var detail_gain: float = 0.45

# Scatter noise (determines where objects land)
@export var scatter_frequency: float = 0.08
@export var scatter_octaves: int = 2

# Vegetation
@export var tree_scale_min: float = 1.5
@export var tree_scale_max: float = 2.6
@export var bush_scale_min: float = 0.6
@export var bush_scale_max: float = 1.2
