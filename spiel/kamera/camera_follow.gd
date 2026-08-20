extends Camera3D

@export var target: Node3D          # -> SpringPosition
@export var lerp_power: float = 12.0

# Wird beim Start und bei jeder Änderung aus dem Optionsmenü überschrieben.
# Der Wert im Inspektor dient nur noch als Rückfall, falls das Autoload fehlt.
@export var base_fov: float = 75.0
# Wie viel Grad beim Sprinten obendrauf kommen. Das bleibt relativ zum
# eingestellten Sichtfeld – wer 100° fährt, bekommt beim Sprint 105°.
@export var sprint_zuschlag: float = 5.0

@export var player: Player

var _sprint_fov: float = 80.0


func _ready() -> void:
	if target == null:
		push_error("Camera3D: Feld 'target' ist nicht zugewiesen!")
		set_process(false)
		return

	top_level = true
	global_transform = target.global_transform

	Einstellungen.video_geaendert.connect(_sichtfeld_uebernehmen)
	_sichtfeld_uebernehmen()
	fov = base_fov      # ohne Anfangs-Lerp direkt auf den Zielwert


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-lerp_power * delta)
	# Kein Stufen-Ausgleich mehr nötig: Der Player fährt Stufen jetzt echt über
	# velocity.y hoch (rund 0.17 s pro Block), die Kamera zieht dabei ohnehin
	# über lerp_power weich nach.
	global_position = global_position.lerp(target.global_position, weight)
	global_basis = target.global_basis

	var want_fov := _sprint_fov if (player and player.is_sprinting) else base_fov
	fov = lerpf(fov, want_fov, 1.0 - exp(-6.0 * delta))


# Holt das Sichtfeld aus dem Optionsmenü. Der Sprint-Wert hängt daran, damit
# die Beschleunigungs-Optik bei jeder Einstellung gleich stark wirkt.
func _sichtfeld_uebernehmen() -> void:
	base_fov = Einstellungen.sichtfeld
	_sprint_fov = base_fov + sprint_zuschlag
