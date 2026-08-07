@tool
class_name WorldGenerator
extends VoxelGeneratorScript

const CHANNEL := VoxelBuffer.CHANNEL_TYPE

const AIR := 0
const WATER := 1
const GRASS := 2
const STONE := 3
const DIRT := 4

@export var base_height: int = 32
@export var sea_level: int = 30
@export var flat_amplitude: float = 4.0
@export var mountain_amplitude: float = 60.0
@export_range(1.0, 6.0, 0.1) var mountain_rarity: float = 3.0
@export var stone_line: int = 55
@export var dirt_depth: int = 4
@export_range(0.0, 0.15, 0.005) var river_width: float = 0.04
@export var river_depth: int = 3
@export_range(0.0, 1.0, 0.05) var river_mountain_fade: float = 1.0

@export var world_seed: int = 1337:
	set(value):
		world_seed = value
		_setup_noise()

var _detail: FastNoiseLite
var _biome: FastNoiseLite
var _river: FastNoiseLite


func _init() -> void:
	_setup_noise()


func _setup_noise() -> void:
	_detail = FastNoiseLite.new()
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.seed = world_seed
	_detail.frequency = 0.006
	_detail.fractal_octaves = 4

	_biome = FastNoiseLite.new()
	_biome.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_biome.seed = world_seed + 100
	_biome.frequency = 0.0008
	_biome.fractal_octaves = 2
	
	_river = FastNoiseLite.new()
	_river.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_river.seed = world_seed + 200
	_river.frequency = 0.0015
	_river.fractal_octaves = 2


func _get_used_channels_mask() -> int:
	return 1 << CHANNEL


# Berechnet die Geländehöhe einer einzelnen Säule
func _get_height(gx: int, gz: int) -> int:
	var t := (_biome.get_noise_2d(gx, gz) + 1.0) * 0.5
	var mountain_factor := pow(t, mountain_rarity)
	var amp := lerpf(flat_amplitude, mountain_amplitude, mountain_factor)
	var h := float(base_height) + _detail.get_noise_2d(gx, gz) * amp

	# Flusslauf: kleiner Betrag = nahe an der Flussmitte
	var r := absf(_river.get_noise_2d(gx, gz))
	if r < river_width:
		var s := 1.0 - (r / river_width)   # 0 am Ufer, 1 in der Mitte
		s = s * s * (3.0 - 2.0 * s)        # Smoothstep: weiche Böschung

		# Im Gebirge abschwächen, damit keine Schluchten entstehen
		s *= 1.0 - (mountain_factor * river_mountain_fade)

		h = lerpf(h, float(sea_level - river_depth), s)

	return int(h)


func _generate_block(out_buffer: VoxelBuffer, origin_in_voxels: Vector3i, lod: int) -> void:
	var size := out_buffer.get_size()

	# Komplett über allem: nur Luft
	var max_possible := base_height + int(mountain_amplitude)
	if origin_in_voxels.y > max_possible and origin_in_voxels.y > sea_level:
		out_buffer.fill(AIR, CHANNEL)
		return

	# Komplett unter allem: nur Stein
	var min_possible := base_height - int(mountain_amplitude) - dirt_depth
	if origin_in_voxels.y + size.y < min_possible:
		out_buffer.fill(STONE, CHANNEL)
		return

	for x in size.x:
		for z in size.z:
			var gx := origin_in_voxels.x + x
			var gz := origin_in_voxels.z + z

			var h := _get_height(gx, gz)

			# Welcher Block liegt ganz oben?
			var surface := GRASS
			if h <= sea_level:
				surface = DIRT
			elif h > stone_line + int(_detail.get_noise_2d(gx * 3.0, gz * 3.0) * 6.0):
				surface = STONE

			for y in size.y:
				var gy := origin_in_voxels.y + y
				var v := AIR

				if gy > h:
					if gy <= sea_level:
						v = WATER
				elif gy == h:
					v = surface
				elif gy > h - dirt_depth:
					v = STONE if surface == STONE else DIRT
				else:
					v = STONE

				out_buffer.set_voxel(v, x, y, z, CHANNEL)
