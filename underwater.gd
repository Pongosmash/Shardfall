extends Node

@export var camera: Camera3D                       # deine Camera3D hier rein
@export var terrain: VoxelTerrain                  # VoxelTerrain hier rein
@export var world_env: WorldEnvironment
@export var water_voxel: int = 1
@export var uebergang: float = 8.0                 # Blendgeschwindigkeit

@export_group("Unterwasser")
@export var wasser_farbe: Color = Color(0.10, 0.34, 0.42)
@export var nebel_dichte: float = 0.09
@export var helligkeit: float = 0.75
@export var saettigung: float = 1.25

var _env: Environment
var _voxel_tool: VoxelTool = null
var _blend: float = 0.0

# Originalwerte, um sauber zurückblenden zu können
var _o_fog_enabled: bool
var _o_fog_color: Color
var _o_fog_density: float
var _o_adj_enabled: bool
var _o_brightness: float
var _o_saturation: float


func _ready() -> void:
	if camera == null or world_env == null or terrain == null:
		push_error("Underwater: 'camera', 'terrain' oder 'world_env' fehlt.")
		set_process(false)
		return

	_voxel_tool = terrain.get_voxel_tool()
	_voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE

	_env = world_env.environment
	_o_fog_enabled = _env.fog_enabled
	_o_fog_color = _env.fog_light_color
	_o_fog_density = _env.fog_density
	_o_adj_enabled = _env.adjustment_enabled
	_o_brightness = _env.adjustment_brightness
	_o_saturation = _env.adjustment_saturation


func _process(delta: float) -> void:
	# entscheidend ist die Kameraposition, nicht die des Spielers
	var p := camera.global_position
	var vp := Vector3i(floori(p.x), floori(p.y), floori(p.z))
	var drin: bool = _voxel_tool.get_voxel(vp) == water_voxel

	_blend = lerpf(_blend, 1.0 if drin else 0.0, 1.0 - exp(-uebergang * delta))

	if _blend < 0.005:
		_env.fog_enabled = _o_fog_enabled
		_env.fog_light_color = _o_fog_color
		_env.fog_density = _o_fog_density
		_env.adjustment_enabled = _o_adj_enabled
		_env.adjustment_brightness = _o_brightness
		_env.adjustment_saturation = _o_saturation
		return

	_env.fog_enabled = true
	_env.fog_light_color = _o_fog_color.lerp(wasser_farbe, _blend)
	_env.fog_density = lerpf(_o_fog_density, nebel_dichte, _blend)
	_env.adjustment_enabled = true
	_env.adjustment_brightness = lerpf(_o_brightness, helligkeit, _blend)
	_env.adjustment_saturation = lerpf(_o_saturation, saettigung, _blend)
