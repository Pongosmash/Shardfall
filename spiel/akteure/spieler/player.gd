class_name Player
extends Akteur

@export_group("Geschwindigkeit")
@export var walk_speed: float = 6.0
@export var sprint_speed: float = 10.0
@export var sneak_speed: float = 2.5

@export_group("Beschleunigung")
@export var ground_accel: float = 12.0
@export var ground_decel: float = 16.0
@export var air_control: float = 0.25

@export_group("Springen")
@export var jump_velocity: float = 8.0
@export var gravity: float = 20.0
@export var fall_multiplier: float = 1.4
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@export_group("Stufen")
# Automatisches Hochlaufen kleiner Absätze, ohne springen zu müssen.
# Der Körper wird dabei NICHT versetzt, sondern über velocity.y hochgefahren –
# dadurch bleibt die Kollision durchgehend gültig und nichts steckt im Block.
@export var stufen_hoehe: float = 1.05            # max. Absatz (1 Voxel + Puffer)
@export var stufen_min: float = 0.06              # darunter passiert nichts
# Muss größer sein als der Kapselradius, sonst hängt die runde Kapselunterseite
# beim Abwärtstest noch über der Blockkante und der Winkeltest verwirft alles.
@export var stufen_vorschau: float = 0.60
@export var stufen_tempo: float = 6.0             # Steiggeschwindigkeit in m/s
@export var stufen_puffer: float = 0.02           # Sicherheitsabstand
@export var stufen_max_winkel: float = 50.0       # steilere Flächen zählen nicht
@export var stufen_debug: bool = false            # gibt aus, woran es scheitert

@export_group("Ducken")
@export var duck_hoehe: float = 1.25              # Kapselhöhe beim Schleichen
@export var kapsel_tempo: float = 3.0             # Meter pro Sekunde beim Umformen

@export_group("Wasser")
@export var terrain: VoxelTerrain                 # VoxelTerrain hier reinziehen
@export var water_voxel: int = 1                  # Block-Index von Wasser
@export var swim_tiefe: float = 1.7               # ab dieser Wassersäule wird geschwommen
@export var wade_speed: float = 3.2               # Waten in flachem Wasser
@export var swim_speed: float = 4.0
@export var swim_accel: float = 6.0
@export var swim_up_speed: float = 3.5            # Auftauchen (Leertaste)
@export var swim_down_speed: float = 3.0          # Abtauchen (Sneak)
@export var water_gravity: float = 3.0            # Restsinken ohne Eingabe
@export var buoyancy: float = 6.0                 # Auftrieb an der Oberfläche
@export var water_drag: float = 4.0               # Bremsung im Wasser
@export var exit_jump_boost: float = 6.5          # Absprung aus dem Wasser ans Ufer
@export var schwimm_kapsel_hoehe: float = 1.00    # kompakte Hitbox in der Waagerechten
@export var schwimm_kapsel_neigen: bool = false   # Kapsel zusätzlich kippen
@export var schwimm_kapsel_winkel: float = 72.0   # Grad, passend zur Optik

@export_group("Referenzen")
@export var spawn_check_distance: float = 200.0

# Öffentlicher Zustand, den character_visual.gd und camera_follow.gd lesen.
# is_sprinting, is_sneaking, is_swimming, is_climbing, wunsch_richtung,
# camera_pivot und combat kommen jetzt von Akteur - gemeinsamer Vertrag mit
# einem spaeteren Npc, siehe akteur.gd.
var is_wading: bool = false        # flaches Wasser -> laufen, aber langsamer
var is_submerged: bool = false     # Kopf unter Wasser -> für Optik

# Bleibt aus Kompatibilität erhalten und ist jetzt immer 0.0: Das Stufensteigen
# läuft über echte Bewegung, es braucht keinen optischen Ausgleich mehr.
# Die Zeile in camera_follow.gd kann so stehen bleiben oder raus.
var stufen_versatz: float = 0.0

var _terrain_ready: bool = false
var _coyote_timer: float = 0.0
var _buffer_timer: float = 0.0
var _voxel_tool: VoxelTool = null
var _hoehe_normal: float = 1.70    # Kapselhöhe im Stehen (Bezugsgröße, bleibt fix)
var _shape_node: CollisionShape3D = null
var _kapsel: CapsuleShape3D = null
var _spawn_position: Vector3 = Vector3.ZERO

var _tempo_vor_move: float = 0.0
var _pos_vor_move: Vector3 = Vector3.ZERO
var _stufen_ziel_y: float = 0.0


## Gruppen bewusst hier und nicht in _ready(): Godot arbeitet den gesamten
## Baum mit _enter_tree ab, BEVOR irgendein _ready laeuft. In _ready waere die
## Gruppe nur fuer Knoten gefuellt, die im Szenenbaum hinter dem Spieler
## stehen - deko_layer.gd, cloud_layer.gd und karte.gd liegen inzwischen in
## welt.tscn und ui.tscn und kaemen zu frueh.
## "damageable" = kann Schaden nehmen, "humanoid" = Ziel fuer Orks.
func _enter_tree() -> void:
	add_to_group("damageable")
	add_to_group("humanoid")
	add_to_group("player")


func _ready() -> void:
	_spawn_position = global_position

	combat = get_node_or_null("Combat") as Combat
	if combat == null:
		push_warning("Player: Kindknoten 'Combat' fehlt – kein Kampfsystem aktiv.")

	if camera_pivot == null:
		push_error("Player: Feld 'camera_pivot' ist nicht zugewiesen!")
		set_physics_process(false)
		return

	_shape_node = $CollisionShapePlayer as CollisionShape3D
	if _shape_node:
		# eigene Kopie der Form, damit andere Knoten sie nicht mitverändern
		_kapsel = _shape_node.shape.duplicate() as CapsuleShape3D
		_shape_node.shape = _kapsel
	if _kapsel:
		_hoehe_normal = _kapsel.height
		if stufen_vorschau < _kapsel.radius * 1.6:
			push_warning("Player: 'stufen_vorschau' ist kleiner als der Kapselradius"
					+ " – Stufen werden womöglich nicht erkannt.")
	else:
		push_warning("Player: CollisionShapePlayer hat keine CapsuleShape3D – kein Ducken.")

	# Rueckfall auf die Gruppe: seit Spieler und Gelaende eigene Szenen sind,
	# kann 'terrain' im Inspektor nicht mehr gesetzt werden - Godot laesst
	# keinen NodePath ueber eine Szenengrenze hinweg zu. Das VoxelTerrain
	# muss dafuer in der Gruppe 'gelaende' sein. Das Exportfeld bleibt als
	# Uebersteuerung erhalten.
	if terrain == null:
		terrain = get_tree().get_first_node_in_group("gelaende") as VoxelTerrain
	if terrain:
		_voxel_tool = terrain.get_voxel_tool()
		_voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE
	else:
		push_warning("Player: kein Gelaende in der Gruppe 'gelaende' – kein Schwimmen.")

	# Ab hier verwaltet das Pausenmenü den Mauszustand: Es fängt die Maus beim
	# Schließen wieder ein und gibt sie beim Öffnen frei. Der Player hört
	# deshalb NICHT mehr selbst auf "ui_cancel" – sonst würden beide Seiten am
	# selben Mausmodus drehen und man landet in vertauschten Zuständen.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not _terrain_ready:
		if _has_ground_below():
			_terrain_ready = true
		else:
			velocity = Vector3.ZERO
			return

	_update_water_state()
	_update_timers(delta)

	if is_swimming:
		is_climbing = false
		_swim(delta)
	else:
		_apply_gravity(delta)
		_handle_jump()
		_handle_movement(delta)
		# Zuletzt, weil es velocity.y überschreiben darf
		_stufe_steigen(delta)

	_update_kapsel(delta)

	# Zustand sichern, bevor move_and_slide() ihn überschreibt
	_tempo_vor_move = Vector2(velocity.x, velocity.z).length()
	_pos_vor_move = global_position

	move_and_slide()
	_stufe_pruefen(delta)


# ---------------------------------------------------------------- Stufen

# Fährt den Körper mit fester Geschwindigkeit auf die erkannte Stufenhöhe.
# Bewusst über velocity statt über global_position: move_and_slide() löst so
# jeden Frame die Kollision korrekt auf, es kann nichts in einen Block rutschen.
# Nach oben gerichtete Geschwindigkeit schaltet außerdem das Floor-Snapping ab,
# das uns sonst sofort wieder auf die untere Ebene ziehen würde.
func _stufe_steigen(delta: float) -> void:
	if not is_climbing:
		return

	# Ein echter Sprung hat Vorrang und bricht das Steigen ab
	if velocity.y > stufen_tempo + 0.1:
		is_climbing = false
		return

	var rest := _stufen_ziel_y - global_position.y
	if rest <= 0.01:
		is_climbing = false
		return

	# Nie über das Ziel hinausschießen
	velocity.y = minf(stufen_tempo, rest / maxf(delta, 0.0001))

	# Während des Steigens gelten wir weiter als bodennah: volle Steuerung,
	# Coyote-Zeit bleibt offen, kein Luftmodus.
	_coyote_timer = coyote_time


# Läuft direkt nach move_and_slide(). Wenn wir gegen eine Kante gelaufen sind,
# prüfen drei Formtests (hoch -> vor -> runter), ob dahinter ein begehbarer
# Absatz von höchstens stufen_hoehe liegt. Gesetzt wird nur das Ziel – das
# Hochfahren erledigt _stufe_steigen() über die folgenden Frames.
func _stufe_pruefen(delta: float) -> void:
	if is_swimming or is_climbing or _kapsel == null:
		return
	if _coyote_timer <= 0.0:        # nur vom Boden aus (Coyote-Zeit inklusive)
		return
	if velocity.y > 1.0:            # im Aufstieg eines Sprungs nicht eingreifen
		return

	# Richtung aus dem Bewegungswunsch, NICHT aus velocity: move_and_slide()
	# hat die Geschwindigkeit an der Wand gerade auf null gebremst.
	var richtung := wunsch_richtung
	if richtung.length_squared() < 0.01:
		return
	richtung = richtung.normalized()

	if _tempo_vor_move < 0.15:
		return

	# Sind wir wirklich blockiert? Entweder meldet Godot eine Wand, oder wir
	# haben deutlich weniger Strecke geschafft als geplant.
	var erwartet := _tempo_vor_move * delta
	var erreicht := Vector2(global_position.x - _pos_vor_move.x,
			global_position.z - _pos_vor_move.z).length()
	var blockiert := is_on_wall() or (erwartet > 0.0001 and erreicht < erwartet * 0.6)
	if not blockiert:
		return

	var start := global_transform

	# 1) Ist über uns Platz?
	var hoch := Vector3.UP * (stufen_hoehe + stufen_puffer)
	if test_move(start, hoch):
		_stufe_log("kein Platz nach oben")
		return

	# 2) Ist in Laufrichtung Platz, wenn wir angehoben sind?
	var oben := start
	oben.origin += hoch
	var vor := richtung * stufen_vorschau
	if test_move(oben, vor):
		_stufe_log("Hindernis ist höher als eine Stufe")
		return

	# 3) Wo ist dort der Boden?
	var vorne := oben
	vorne.origin += vor
	var treffer := KinematicCollision3D.new()
	var runter := Vector3.DOWN * (stufen_hoehe + stufen_puffer * 2.0)
	if not test_move(vorne, runter, treffer):
		_stufe_log("kein Boden dahinter – das ist eine Kante, keine Stufe")
		return

	# 4) Ist die Fläche begehbar?
	var winkel := rad_to_deg(treffer.get_normal().angle_to(Vector3.UP))
	if winkel > stufen_max_winkel:
		_stufe_log("Fläche zu steil (%.1f Grad)" % winkel)
		return

	# 5) Höhendifferenz prüfen
	var ziel_y := vorne.origin.y + treffer.get_travel().y
	var diff := ziel_y - start.origin.y
	if diff < stufen_min or diff > stufen_hoehe:
		_stufe_log("Höhe passt nicht (%.2f m)" % diff)
		return

	# 6) Steigen anmelden – die Bewegung selbst macht _stufe_steigen()
	_stufen_ziel_y = ziel_y + stufen_puffer
	is_climbing = true
	_stufe_log("Stufe erkannt (%.2f m), steige hoch" % diff)


func _stufe_log(text: String) -> void:
	if stufen_debug:
		print("[Stufe] ", text)


# ---------------------------------------------------------------- Kampf

# take_damage(), schwachstelle_oeffnen(), ist_offen(), schwachstelle_schliessen()
# kommen jetzt von Akteur - identische Logik, jetzt fuer Player UND Npc.


# Nach dem Tod: zurück an den Startpunkt, Bodenprüfung läuft neu.
func respawn() -> void:
	velocity = Vector3.ZERO
	global_position = _spawn_position
	_terrain_ready = false
	is_climbing = false
	wunsch_richtung = Vector3.ZERO
	if _kapsel:
		_kapsel.height = _hoehe_normal
	if _shape_node:
		_shape_node.position.y = 0.0
		_shape_node.rotation.x = 0.0


# ---------------------------------------------------------------- Kollisionsform

# Kapsel schrumpft beim Ducken und beim Schwimmen.
# Die Füße bleiben dabei immer auf derselben Höhe: Sie sitzen konstruktionsbedingt
# bei global_position.y - _hoehe_normal * 0.5, egal wie hoch die Kapsel gerade ist.
func _update_kapsel(delta: float) -> void:
	if _kapsel == null or _shape_node == null:
		return

	var ziel: float = _hoehe_normal
	if is_swimming:
		ziel = schwimm_kapsel_hoehe
	elif is_sneaking and (is_on_floor() or is_climbing):
		ziel = duck_hoehe

	# Eine Kapsel kann nie kürzer sein als ihr Durchmesser
	ziel = maxf(ziel, _kapsel.radius * 2.0 + 0.01)

	# Aufstehen nur, wenn oben Platz ist
	if ziel > _kapsel.height and not _kopf_frei(ziel):
		ziel = _kapsel.height

	_kapsel.height = move_toward(_kapsel.height, ziel, kapsel_tempo * delta)
	_shape_node.position.y = (_kapsel.height - _hoehe_normal) * 0.5

	# Optionales Kippen in der Waagerechten
	var ziel_winkel: float = 0.0
	if is_swimming and schwimm_kapsel_neigen:
		ziel_winkel = -deg_to_rad(schwimm_kapsel_winkel)
	_shape_node.rotation.x = lerpf(_shape_node.rotation.x, ziel_winkel,
			1.0 - exp(-6.0 * delta))


func _kopf_frei(ziel_hoehe: float) -> bool:
	var fuss := global_position.y - _hoehe_normal * 0.5
	var oben := fuss + ziel_hoehe + 0.1
	if oben <= global_position.y:
		return true

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position,
			Vector3(global_position.x, oben, global_position.z))
	query.exclude = [get_rid()]
	query.collision_mask = collision_mask
	return space.intersect_ray(query).is_empty()


# ---------------------------------------------------------------- Wasser

func _update_water_state() -> void:
	is_wading = false
	is_swimming = false
	is_submerged = false
	if _voxel_tool == null:
		return

	# Bewusst _hoehe_normal statt der aktuellen Kapselhöhe: Sonst würde die
	# schrumpfende Kapsel den Messpunkt verschieben und Schwimmen flackern lassen.
	var half := _hoehe_normal * 0.5
	var fuss_y := global_position.y - half

	# Wassersäule über den Füßen messen (max. 6 Blöcke hoch).
	# Entscheidend ist die Tiefe des Gewässers, nicht die Körperposition –
	# sonst würde man aufhören zu schwimmen, sobald man den Grund berührt.
	var tiefe := 0.0
	for i in 7:
		if _ist_wasser(Vector3(global_position.x, fuss_y + 0.3 + float(i),
				global_position.z)):
			tiefe = 0.3 + float(i) + 1.0
		else:
			break

	if tiefe <= 0.0:
		return

	is_submerged = _ist_wasser(global_position + Vector3(0.0, half - 0.25, 0.0))

	if tiefe >= swim_tiefe:
		is_swimming = true
	else:
		is_wading = true


func _ist_wasser(welt_pos: Vector3) -> bool:
	var p := Vector3i(floori(welt_pos.x), floori(welt_pos.y), floori(welt_pos.z))
	return _voxel_tool.get_voxel(p) == water_voxel


func _swim(delta: float) -> void:
	is_sprinting = false
	is_sneaking = false

	var input_dir := Input.get_vector("move_left", "move_right",
			"move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0.0, input_dir.y) \
			.rotated(Vector3.UP, _bewegungs_yaw())
	wunsch_richtung = Vector3.ZERO      # im Wasser keine Stufenprüfung

	var target := direction * swim_speed
	var weight := 1.0 - exp(-swim_accel * delta)
	velocity.x = lerpf(velocity.x, target.x, weight)
	velocity.z = lerpf(velocity.z, target.z, weight)

	var ziel_y := 0.0
	if Input.is_action_pressed("ui_accept"):
		# an der Oberfläche wird der Sprung zum Absprung ans Ufer
		if not is_submerged and is_on_wall():
			velocity.y = exit_jump_boost
			return
		ziel_y = swim_up_speed
	elif Input.is_action_pressed("sneak"):
		ziel_y = -swim_down_speed
	else:
		# ohne Eingabe: leicht sinken, an der Oberfläche aber auftreiben
		ziel_y = -water_gravity
		if not is_submerged:
			ziel_y = buoyancy * 0.15

	velocity.y = lerpf(velocity.y, ziel_y, 1.0 - exp(-water_drag * delta))

	# auf dem Grund nicht weiter nach unten drücken – aber weiter schwimmen,
	# nicht stehen. Die Optik bleibt waagerecht (siehe character_visual.gd).
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0


# ---------------------------------------------------------------- Land

func _update_timers(delta: float) -> void:
	if is_on_floor() or is_swimming:
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta

	if Input.is_action_just_pressed("ui_accept"):
		_buffer_timer = jump_buffer_time
	else:
		_buffer_timer -= delta


func _apply_gravity(delta: float) -> void:
	if is_on_floor() or is_climbing:
		return
	var g := gravity * fall_multiplier if velocity.y < 0.0 else gravity
	velocity.y -= g * delta


func _handle_jump() -> void:
	if combat and (combat.ist_betaeubt or combat.ist_tot):
		return
	if _buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_buffer_timer = 0.0
		_coyote_timer = 0.0
		is_climbing = false        # Sprung bricht das Stufensteigen ab


# Blickwinkel, an dem die Laufrichtung hängt. Bei Free-Look (Alt) bleibt sie an
# der eigenen Ausrichtung kleben, damit man beim Umsehen weiter geradeaus rennt.
func _bewegungs_yaw() -> float:
	if Input.is_action_pressed("free_look"):
		return global_rotation.y
	return camera_pivot.global_rotation.y


func _handle_movement(delta: float) -> void:
	# Bei freier Maus (Inventar, Karte, Pausenmenü) keine Bewegungseingabe
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		wunsch_richtung = Vector3.ZERO
		is_sneaking = false
		is_sprinting = false
		var bremse := 1.0 - exp(-ground_decel * delta)
		velocity.x = lerpf(velocity.x, 0.0, bremse)
		velocity.z = lerpf(velocity.z, 0.0, bremse)
		return

	var input_dir := Input.get_vector("move_left", "move_right",
			"move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0.0, input_dir.y) \
			.rotated(Vector3.UP, _bewegungs_yaw())
	var moving := direction.length() > 0.1

	is_sneaking = Input.is_action_pressed("sneak")

	# Geduckt bleiben, solange über uns kein Platz zum Aufstehen ist
	if not is_sneaking and _kapsel and _kapsel.height < _hoehe_normal - 0.02 \
			and not _kopf_frei(_hoehe_normal):
		is_sneaking = true

	is_sprinting = false

	var speed := walk_speed
	if is_sneaking:
		speed = sneak_speed
	elif Input.is_action_pressed("sprint") and moving \
			and (combat == null or combat.darf_sprinten()):
		speed = sprint_speed
		is_sprinting = true

	# Waten bremst und verhindert Sprinten
	if is_wading:
		speed = minf(speed, wade_speed)
		is_sprinting = false

	# --- Kampf wirkt auf die Bewegung ---
	if combat:
		if is_sprinting:
			combat.sprint_kosten(delta)
		if combat.ist_am_blocken:
			speed = minf(speed, walk_speed * combat.block_tempo)
		if combat.ist_betaeubt or combat.ist_tot:
			speed = 0.0
			moving = false

	# Bewegungswunsch für die Stufenprüfung merken
	wunsch_richtung = direction.normalized() if moving else Vector3.ZERO

	var target := direction * speed
	var rate := ground_accel if moving else ground_decel
	# Beim Stufensteigen volle Kontrolle behalten, nicht auf Luftsteuerung fallen
	if not is_on_floor() and not is_climbing:
		rate *= air_control

	var weight := 1.0 - exp(-rate * delta)
	velocity.x = lerpf(velocity.x, target.x, weight)
	velocity.z = lerpf(velocity.z, target.z, weight)


func _has_ground_below() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position
	var to := global_position - Vector3(0.0, spawn_check_distance, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = collision_mask
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false

	global_position.y = hit.position.y + _hoehe_normal * 0.5 + 0.05
	return true
