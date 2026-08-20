extends Node3D

@export var player: Node3D
@export_range(-90.0, 0.0, 0.1, "radians_as_degrees") var min_vertical_angle: float = -PI/2
@export_range(0.0, 90.0, 0.1, "radians_as_degrees") var max_vertical_angle: float = PI/4
@export var min_zoom: float = 1.0
@export var max_zoom: float = 10.0
@export var zoom_step: float = 1.0
@export var turn_speed: float = 12.0

@onready var spring_arm: SpringArm3D = $SpringArm3D

var _offset: Vector3

# Aus dem Optionsmenü gespiegelt. Bewusst zwischengespeichert statt bei jedem
# Mausereignis neu abgefragt: InputEventMouseMotion feuert bei 144 Hz und
# hoher Abtastrate mehrere hundert Mal pro Sekunde.
var _sensi: float = 0.005
var _y_faktor: float = 1.0


func _ready() -> void:
	if player == null:
		push_error("SpringArmPivot: Feld 'player' ist nicht zugewiesen!")
		set_process(false)
		set_process_unhandled_input(false)
		return

	_offset = position          # lokale Verschiebung merken, SOLANGE sie noch gilt
	top_level = true            # ab jetzt: Drehung des Players wird ignoriert
	global_position = player.global_position + _offset
	set_zoom(spring_arm.spring_length)

	Einstellungen.spiel_geaendert.connect(_steuerung_uebernehmen)
	_steuerung_uebernehmen()


func _process(delta: float) -> void:
	# Pivot klebt an der Spielerposition, übernimmt aber nicht dessen Drehung
	global_position = player.global_position + _offset

	# Bei gedrücktem Alt: nur umsehen, Spieler nicht drehen
	if Input.is_action_pressed("free_look"):
		return

	# Spieler dreht sich weich in die Blickrichtung
	var weight := 1.0 - exp(-turn_speed * delta)
	player.rotation.y = lerp_angle(player.rotation.y, rotation.y, weight)


func _unhandled_input(event: InputEvent) -> void:
	# Sobald die Maus frei ist (Pausenmenü, Inventar), wird nicht gedreht.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * _sensi
		rotation.y = wrapf(rotation.y, 0.0, TAU)
		rotation.x -= event.relative.y * _sensi * _y_faktor
		rotation.x = clamp(rotation.x, min_vertical_angle, max_vertical_angle)

	if event.is_action_pressed("wheel_up"):
		set_zoom(spring_arm.spring_length - zoom_step)
	if event.is_action_pressed("wheel_down"):
		set_zoom(spring_arm.spring_length + zoom_step)


func set_zoom(value: float) -> void:
	spring_arm.spring_length = clamp(value, min_zoom, max_zoom)


# Holt Sensitivität und Y-Invertierung aus dem Optionsmenü.
func _steuerung_uebernehmen() -> void:
	_sensi = Einstellungen.maussensitivitaet
	_y_faktor = -1.0 if Einstellungen.y_invertieren else 1.0
