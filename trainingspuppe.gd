extends Node3D

# Testziel für das Kampfsystem.
# Stellt sich beim Start selbst vor den Spieler auf den Boden, nimmt Schaden,
# schlägt zurück und wird beim Parieren offen für einen kritischen Treffer.
#
# Aufbau: Node3D mit diesem Skript, darunter ein MeshInstance3D namens "Mesh".
# Die Position im Editor ist egal, sie wird beim Start überschrieben.

@export var max_leben: float = 60.0
@export var wieder_aufbauen_nach: float = 3.0

@export_group("Aufstellen")
@export var vor_dem_spieler: bool = true          # aus = bleibt, wo sie im Editor steht
@export var abstand_vorne: float = 6.0            # Blöcke vor dem Spieler
@export var such_hoehe: float = 40.0              # von wie weit oben gesucht wird
@export var such_distanz: float = 300.0           # wie weit nach unten gesucht wird
@export var terrain_maske: int = 1                # Kollisionsebene des Terrains

@export_group("Angriff")
@export var greift_an: bool = true
@export var angriffs_reichweite: float = 3.2
@export var angriffs_intervall: float = 2.0       # Pause zwischen den Schlägen
@export var telegraf: float = 0.6                 # Ausholzeit – Zeit zum Parieren
@export var angriffs_schaden: float = 12.0

@export_group("Diagnose")
@export var zeige_abstand: bool = true            # druckt jede Sekunde die Distanz

@export_group("Optik")
@export var mesh_ruhe_y: float = 0.9
@export var mesh_ausholen_y: float = 1.35         # hebt sich deutlich beim Ausholen
@export var mesh_offen_y: float = 0.45            # sackt ab, wenn offen
@export var optik_tempo: float = 12.0

enum Zustand { RUHE, AUSHOLEN, OFFEN, UMGEFALLEN }

var leben: float = 0.0

var _zustand: int = Zustand.RUHE
var _timer: float = 0.0
var _pause: float = 0.0
var _steht: bool = false
var _such_timer: float = 0.0
var _warnung_gezeigt: bool = false
var _melde_timer: float = 0.0
var _mesh: Node3D = null
var _spieler: Node3D = null


func _ready() -> void:
	add_to_group("damageable")
	leben = max_leben
	_pause = angriffs_intervall
	_steht = not vor_dem_spieler

	_mesh = get_node_or_null("Mesh") as Node3D
	if _mesh == null:
		push_warning("Trainingspuppe: Kindknoten 'Mesh' fehlt – du siehst nichts!")
	print("Trainingspuppe gestartet. Greift an: ", greift_an,
			"  Reichweite: ", angriffs_reichweite)


func _process(delta: float) -> void:
	# Solange die Puppe nicht steht, passiert sonst nichts. Es wird jedes Bild
	# neu versucht, weil das Terrain beim Start erst nachlädt.
	if not _steht:
		_aufstellen_vor_spieler(delta)
		return

	_optik(delta)
	_melde(delta)

	match _zustand:
		Zustand.RUHE:
			_ruhe(delta)
		Zustand.AUSHOLEN:
			_timer -= delta
			if _timer <= 0.0:
				_zuschlagen()
		Zustand.OFFEN:
			_timer -= delta
			if _timer <= 0.0:
				_zustand = Zustand.RUHE
				_pause = angriffs_intervall
		Zustand.UMGEFALLEN:
			_timer -= delta
			if _timer <= 0.0:
				_wieder_hinstellen()


# ---------------------------------------------------------------- Aufstellen

func _aufstellen_vor_spieler(delta: float) -> void:
	var spieler := _finde_spieler()
	if spieler == null:
		_meckern(delta, "Trainingspuppe: Kein Knoten in der Gruppe 'player' gefunden.")
		return

	var richtung := _blick_richtung(spieler)
	var ziel := spieler.global_position + richtung * abstand_vorne

	var space := get_world_3d().direct_space_state
	var von := Vector3(ziel.x, spieler.global_position.y + such_hoehe, ziel.z)
	var nach := von - Vector3(0.0, such_distanz, 0.0)

	var query := PhysicsRayQueryParameters3D.create(von, nach)
	query.collision_mask = terrain_maske
	var treffer := space.intersect_ray(query)

	if treffer.is_empty():
		_meckern(delta, "Trainingspuppe: Kein Boden getroffen. Stimmt 'Terrain Maske'?"
				+ " Aktuell: " + str(terrain_maske))
		return

	global_position = treffer.position + Vector3(0.0, 0.05, 0.0)
	_steht = true
	print("Trainingspuppe steht bei ", global_position)


func _meckern(delta: float, text: String) -> void:
	_such_timer += delta
	if _such_timer > 3.0 and not _warnung_gezeigt:
		_warnung_gezeigt = true
		push_warning(text)
		print(text)


func _blick_richtung(spieler: Node3D) -> Vector3:
	# Bevorzugt die Kamerarichtung, sonst die Ausrichtung des Körpers.
	var yaw: float = spieler.global_rotation.y
	var pivot = spieler.get("camera_pivot")
	if pivot != null and pivot is Node3D:
		yaw = (pivot as Node3D).global_rotation.y
	return Vector3.FORWARD.rotated(Vector3.UP, yaw)


# ---------------------------------------------------------------- Diagnose

func _melde(delta: float) -> void:
	if not zeige_abstand:
		return
	_melde_timer -= delta
	if _melde_timer > 0.0:
		return
	_melde_timer = 1.0
	var d := _abstand_zum_spieler()
	if d < 12.0:
		print("Abstand zum Spieler: ", snappedf(d, 0.1),
				"  (Angriff ab ", angriffs_reichweite, ")")


# ---------------------------------------------------------------- Angriff

func _ruhe(delta: float) -> void:
	if not greift_an:
		return
	_pause -= delta
	if _pause > 0.0:
		return
	if _abstand_zum_spieler() > angriffs_reichweite:
		return

	_zustand = Zustand.AUSHOLEN
	_timer = telegraf
	print(">>> Puppe holt aus! Jetzt Rechtsklick zum Parieren.")


func _zuschlagen() -> void:
	_zustand = Zustand.RUHE
	_pause = angriffs_intervall

	var spieler := _finde_spieler()
	if spieler == null or _abstand_zum_spieler() > angriffs_reichweite:
		print("Puppe schlägt ins Leere.")
		return
	if not spieler.has_method("take_damage"):
		push_warning("Trainingspuppe: Spieler hat keine Methode take_damage()!")
		return

	var richtung: Vector3 = spieler.global_position - global_position
	richtung.y = 0.0
	richtung = richtung.normalized()
	spieler.take_damage(angriffs_schaden, self, richtung)
	print("Puppe trifft für ", angriffs_schaden)


func _abstand_zum_spieler() -> float:
	var spieler := _finde_spieler()
	if spieler == null:
		return 9999.0
	var d: Vector3 = spieler.global_position - global_position
	d.y = 0.0
	return d.length()


func _finde_spieler() -> Node3D:
	if _spieler == null or not is_instance_valid(_spieler):
		_spieler = get_tree().get_first_node_in_group("player") as Node3D
	return _spieler


# ---------------------------------------------------------------- Schaden

func take_damage(menge: float, _angreifer: Node = null,
		richtung: Vector3 = Vector3.ZERO) -> void:
	if _zustand == Zustand.UMGEFALLEN:
		return

	if _zustand == Zustand.OFFEN:
		print("KRITISCHER TREFFER: -", menge)
	else:
		print("Puppe getroffen: -", menge, "  Leben: ", maxf(leben - menge, 0.0))

	leben = maxf(leben - menge, 0.0)
	_zucken(richtung)

	if leben <= 0.0:
		_umfallen()


func _zucken(richtung: Vector3) -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(1.18, 0.86, 1.18), 0.05)
	t.tween_property(self, "scale", Vector3.ONE, 0.14)

	if richtung.length_squared() > 0.001:
		var start := position
		var weg := position + Vector3(richtung.x, 0.0, richtung.z).normalized() * 0.18
		var t2 := create_tween()
		t2.tween_property(self, "position", weg, 0.05)
		t2.tween_property(self, "position", start, 0.18)


# ---------------------------------------------------------------- Schwachstelle

# Wird vom Spieler aufgerufen, wenn er den Schlag perfekt geblockt hat.
func schwachstelle_oeffnen(dauer: float) -> void:
	if _zustand == Zustand.UMGEFALLEN:
		return
	_zustand = Zustand.OFFEN
	_timer = dauer
	print("Puppe ist offen für ", dauer, " s")


func ist_offen() -> bool:
	return _zustand == Zustand.OFFEN


func schwachstelle_schliessen() -> void:
	if _zustand == Zustand.OFFEN:
		_zustand = Zustand.RUHE
		_pause = angriffs_intervall


# ---------------------------------------------------------------- Zustand

func _umfallen() -> void:
	_zustand = Zustand.UMGEFALLEN
	_timer = wieder_aufbauen_nach
	print("Puppe umgeworfen – steht in ", wieder_aufbauen_nach, " s wieder.")
	var t := create_tween()
	t.tween_property(self, "rotation:x", deg_to_rad(-80.0), 0.25)


func _wieder_hinstellen() -> void:
	_zustand = Zustand.RUHE
	_pause = angriffs_intervall
	leben = max_leben
	var t := create_tween()
	t.tween_property(self, "rotation:x", 0.0, 0.25)


func _optik(delta: float) -> void:
	if _mesh == null:
		return
	var ziel := mesh_ruhe_y
	match _zustand:
		Zustand.AUSHOLEN:
			ziel = mesh_ausholen_y
		Zustand.OFFEN:
			ziel = mesh_offen_y
	_mesh.position.y = lerpf(_mesh.position.y, ziel, 1.0 - exp(-optik_tempo * delta))
