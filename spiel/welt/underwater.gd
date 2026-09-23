extends Node

@export var camera: Camera3D                       # deine Camera3D hier rein
@export var terrain: VoxelTerrain                  # VoxelTerrain hier rein
@export var world_env: WorldEnvironment
## Optional. Liefert die aktuelle Nebelfarbe zur Tageszeit statt einer
## eingefrorenen Kopie von _ready(). Ohne gesetzte Referenz faellt der
## Effekt auf die Farbe zurueck, die beim Start im Environment stand -
## funktioniert weiterhin, zieht aber nicht mit der Uhrzeit mit.
@export var tageszeit: Tageszeit
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

# Originalwerte, um sauber zurueckblenden zu koennen. _o_fog_color ist nur
# noch der Rueckfall ohne 'tageszeit' - normalerweise liefert
# tageszeit.nebel_farbe() den aktuellen Wert, siehe _process().
var _o_fog_enabled: bool
var _o_fog_color: Color
var _o_fog_density: float
var _o_adj_enabled: bool
var _o_brightness: float
var _o_saturation: float


func _ready() -> void:
	# Rueckfall auf die aktive Kamera: seit der Spieler eine eigene Szene ist,
	# kann 'camera' im Inspektor nicht mehr gesetzt werden - Godot laesst
	# keinen NodePath ueber eine Szenengrenze hinweg zu. Die aktive Kamera zu
	# fragen ist ohnehin robuster als ein fester Verweis: bei einem spaeteren
	# Kamerawechsel zieht der Unterwassereffekt automatisch mit.
	if camera == null:
		camera = get_viewport().get_camera_3d()
	if camera == null or world_env == null or terrain == null:
		push_error("Underwater: 'terrain', 'world_env' fehlt oder es ist keine Kamera aktiv.")
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

	var basis_farbe: Color = tageszeit.nebel_farbe() if tageszeit != null else _o_fog_color

	if _blend < 0.005:
		_env.fog_enabled = _o_fog_enabled
		_env.fog_light_color = basis_farbe
		_env.fog_density = _o_fog_density
		_env.adjustment_enabled = _o_adj_enabled
		_env.adjustment_brightness = _o_brightness
		_env.adjustment_saturation = _o_saturation
		return

	_env.fog_enabled = true
	_env.fog_light_color = basis_farbe.lerp(wasser_farbe, _blend)
	_env.fog_density = lerpf(_o_fog_density, nebel_dichte, _blend)
	_env.adjustment_enabled = true
	_env.adjustment_brightness = lerpf(_o_brightness, helligkeit, _blend)
	_env.adjustment_saturation = lerpf(_o_saturation, saettigung, _blend)
