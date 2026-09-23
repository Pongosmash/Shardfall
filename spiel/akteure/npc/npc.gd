class_name Npc
extends Akteur

## Einfachste Bewegung fuer NPCs: Schwerkraft + Laufen zum Ziel, das die KI in
## 'wunsch_richtung' vorgibt (geerbt von Akteur), dasselbe Stufensteigen wie
## player.gd und einfaches Schwimmen (siehe dortige Kommentare fuer die
## Herleitung).
##
## SCHWIMMEN IST VEREINFACHT: der NPC steuert nicht aktiv rauf oder runter -
## er verhaelt sich immer wie player.gd OHNE gedrueckte Taste.
##
## TOD: friert die Bewegung ein, kippt die Optik um (Visual-Kindknoten),
## bleibt 'liege_dauer' Sekunden liegen, versinkt dann ueber 'versink_dauer'
## im Boden (Kollision wird dabei abgeschaltet) und loescht sich danach
## selbst - sonst sammeln sich Leichen an und kosten dauerhaft Rechenzeit.
## Combat.gd belebt NPCs anders als den Spieler NICHT automatisch wieder
## (siehe dortiges 'von_spieler_gesteuert').

@export_group("Gehen")
@export var gehtempo: float = 3.2
@export var bodenbeschleunigung: float = 10.0
@export var bodenbremse: float = 14.0
@export var schwerkraft: float = 20.0

@export_group("Stufen")
## Identische Bedeutung wie in player.gd - siehe dort fuer die Herleitung.
@export var stufen_hoehe: float = 1.05
@export var stufen_min: float = 0.06
@export var stufen_vorschau: float = 0.60
@export var stufen_tempo: float = 6.0
@export var stufen_puffer: float = 0.02
@export var stufen_max_winkel: float = 50.0

@export_group("Wasser")
@export var terrain: VoxelTerrain                 # optional, sonst Gruppe "gelaende"
@export var water_voxel: int = 1
@export var swim_tiefe: float = 1.7
@export var wade_speed: float = 2.4
@export var swim_speed: float = 2.8
@export var swim_accel: float = 6.0
@export var water_gravity: float = 3.0
@export var buoyancy: float = 6.0
@export var water_drag: float = 4.0

@export_group("Tod")
@export var fall_dauer: float = 0.25
@export var fall_winkel: float = -80.0
@export var liege_dauer: float = 4.0       # Sekunden, die die Leiche sichtbar liegen bleibt
@export var versink_dauer: float = 1.5     # wie lange das Versinken dauert
@export var versink_tiefe: float = 2.0     # Meter, die dabei nach unten gefahren werden

var is_wading: bool = false
var is_submerged: bool = false

var _visual: Node3D = null
var _collision: CollisionShape3D = null
var _ist_gefallen: bool = false
var _tot_zeit: float = 0.0
var _versinkt: bool = false
var _voxel_tool: VoxelTool = null

var _tempo_vor_move: float = 0.0
var _pos_vor_move: Vector3 = Vector3.ZERO
var _stufen_ziel_y: float = 0.0


func _enter_tree() -> void:
	# Gruppen hier statt in _ready(), aus demselben Grund wie bei player.gd:
	# der Baum wird komplett mit _enter_tree abgearbeitet, bevor irgendein
	# _ready laeuft.
	add_to_group("damageable")


func _ready() -> void:
	combat = get_node_or_null("Combat") as Combat
	if combat == null:
		push_warning("Npc (%s): Kindknoten 'Combat' fehlt – kein Kampfsystem aktiv."
				% name)

	_visual = get_node_or_null("Visual") as Node3D
	if _visual == null:
		push_warning("Npc (%s): Kindknoten 'Visual' fehlt – kein Umfallen beim Tod."
				% name)

	for kind in get_children():
		if kind is CollisionShape3D:
			_collision = kind
			break
	if _collision == null:
		push_warning("Npc (%s): keine CollisionShape3D gefunden – die Leiche"
				% name + " bleibt beim Versinken blockierend stehen.")

	if terrain == null:
		terrain = get_tree().get_first_node_in_group("gelaende") as VoxelTerrain
	if terrain:
		_voxel_tool = terrain.get_voxel_tool()
		_voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE
	else:
		push_warning("Npc (%s): kein Gelaende in der Gruppe 'gelaende' – kein Schwimmen."
				% name)


func _physics_process(delta: float) -> void:
	if combat != null and combat.ist_tot:
		_tot_process(delta)
		return

	_update_water_state()

	if is_swimming:
		is_climbing = false
		_swim(delta)
	else:
		_apply_gravity(delta)
		_handle_movement(delta)
		# Zuletzt, weil es velocity.y überschreiben darf
		_stufe_steigen(delta)

	_tempo_vor_move = Vector2(velocity.x, velocity.z).length()
	_pos_vor_move = global_position

	move_and_slide()
	_stufe_pruefen(delta)


func _apply_gravity(delta: float) -> void:
	if is_on_floor() or is_climbing:
		return
	velocity.y -= schwerkraft * delta


func _handle_movement(delta: float) -> void:
	var ziel: Vector3 = wunsch_richtung * gehtempo
	if is_wading:
		ziel = wunsch_richtung * minf(gehtempo, wade_speed)

	var bewegt_sich: bool = wunsch_richtung.length_squared() > 0.01
	var rate: float = bodenbeschleunigung if bewegt_sich else bodenbremse
	var gewicht: float = 1.0 - exp(-rate * delta)
	velocity.x = lerpf(velocity.x, ziel.x, gewicht)
	velocity.z = lerpf(velocity.z, ziel.z, gewicht)


# ---------------------------------------------------------------- Stufen

func _stufe_steigen(delta: float) -> void:
	if not is_climbing:
		return

	var rest := _stufen_ziel_y - global_position.y
	if rest <= 0.01:
		is_climbing = false
		return

	velocity.y = minf(stufen_tempo, rest / maxf(delta, 0.0001))


func _stufe_pruefen(delta: float) -> void:
	if is_swimming or is_climbing:
		return
	if not is_on_floor():
		return

	var richtung := wunsch_richtung
	if richtung.length_squared() < 0.01:
		return
	richtung = richtung.normalized()

	if _tempo_vor_move < 0.15:
		return

	var erwartet := _tempo_vor_move * delta
	var erreicht := Vector2(global_position.x - _pos_vor_move.x,
			global_position.z - _pos_vor_move.z).length()
	var blockiert := is_on_wall() or (erwartet > 0.0001 and erreicht < erwartet * 0.6)
	if not blockiert:
		return

	var start := global_transform

	var hoch := Vector3.UP * (stufen_hoehe + stufen_puffer)
	if test_move(start, hoch):
		return

	var oben := start
	oben.origin += hoch
	var vor := richtung * stufen_vorschau
	if test_move(oben, vor):
		return

	var vorne := oben
	vorne.origin += vor
	var treffer := KinematicCollision3D.new()
	var runter := Vector3.DOWN * (stufen_hoehe + stufen_puffer * 2.0)
	if not test_move(vorne, runter, treffer):
		return

	var winkel := rad_to_deg(treffer.get_normal().angle_to(Vector3.UP))
	if winkel > stufen_max_winkel:
		return

	var ziel_y := vorne.origin.y + treffer.get_travel().y
	var diff := ziel_y - start.origin.y
	if diff < stufen_min or diff > stufen_hoehe:
		return

	_stufen_ziel_y = ziel_y + stufen_puffer
	is_climbing = true


# ---------------------------------------------------------------- Wasser

func _update_water_state() -> void:
	is_wading = false
	is_swimming = false
	is_submerged = false
	if _voxel_tool == null:
		return

	var half := 0.85    # halbe Kapselhoehe, grob - der NPC schrumpft nicht
	var fuss_y := global_position.y - half

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
	var direction := wunsch_richtung
	var target := direction * swim_speed
	var weight := 1.0 - exp(-swim_accel * delta)
	velocity.x = lerpf(velocity.x, target.x, weight)
	velocity.z = lerpf(velocity.z, target.z, weight)

	var ziel_y := -water_gravity
	if not is_submerged:
		ziel_y = buoyancy * 0.15
	velocity.y = lerpf(velocity.y, ziel_y, 1.0 - exp(-water_drag * delta))

	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0


# ---------------------------------------------------------------- Tod

func _tot_process(delta: float) -> void:
	_sterben_optik()

	if _versinkt:
		return    # der Tween unten haelt die Position, keine Physik mehr noetig

	_tot_zeit += delta
	if _tot_zeit >= liege_dauer:
		_versinken_starten()
		return

	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= schwerkraft * delta
	move_and_slide()


func _sterben_optik() -> void:
	if _ist_gefallen or _visual == null:
		return
	_ist_gefallen = true
	var t := create_tween()
	t.tween_property(_visual, "rotation:x", deg_to_rad(fall_winkel), fall_dauer)


func _versinken_starten() -> void:
	_versinkt = true
	velocity = Vector3.ZERO
	if _collision != null:
		_collision.disabled = true

	var ziel_y: float = global_position.y - versink_tiefe
	var t := create_tween()
	t.tween_property(self, "global_position:y", ziel_y, versink_dauer)
	t.finished.connect(queue_free)
