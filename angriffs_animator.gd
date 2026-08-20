extends Node
class_name AngriffsAnimator
##
## Prozedurale Angriffsanimation für ein Pivot-Rig aus Node3D-Knoten
## (kein Skeleton3D). Passend zum Aufbau:
##
##   Visual -> Neigung -> Huefte -> Brust -> HandRechts -> HandRecht (Mesh)
##                                        -> HandLinks  -> HandLink  (Mesh)
##                                        -> Kopf
##
## Zuweisung der Pivots:
## Die Export-Felder unter "Rig" sind OPTIONAL. Bleiben sie leer, sucht die
## Komponente beim Start selbst nach Knoten mit den unter "Suche"
## eingetragenen Namen - auch INNERHALB instanzierter Unterszenen
## (find_child mit owned = false). Godot laesst Nodes aus einer instanzierten
## Szene naemlich nicht in ein Export-Feld der aeusseren Szene ziehen.
##
## Arbeitsweise:
## character_visual.gd schreibt jeden Frame den Lauf-/Idle-Zyklus in die
## Pivots. Dieser Animator laeuft danach (process_priority = 100) und
## multipliziert die Schlagdrehung OBEN DRAUF. Dadurch bleibt der Laufzyklus
## sichtbar, waehrend der Arm zuschlaegt, und niemand ueberschreibt den anderen.
##
## Laeuft dein Visual-Skript in _physics_process statt _process, stell
## 'im_physikschritt' auf true.
##
## Kosten: ein paar Quaternion-Multiplikationen pro Frame, und das nur
## solange ein Schlag laeuft. Danach schaltet sich der Node selbst ab.
##

## Der Schlag hat das Trefferfenster erreicht - jetzt Schaden pruefen.
signal treffer_fenster_offen(daten: WaffenDaten, hand_links: bool)
## Trefferfenster geschlossen, ab hier trifft nichts mehr.
signal treffer_fenster_zu
## Schlag komplett durch (inklusive Rueckholbewegung).
signal angriff_beendet

@export_group("Rig")
## Optional. Leer lassen, dann greift die Namenssuche unten.
@export var arm_rechts: Node3D
@export var arm_links: Node3D
@export var oberkoerper: Node3D
@export var kopf: Node3D

@export_group("Suche")
## Ab hier wird gesucht. Leer = Elternknoten (also der Spieler/NPC).
@export var such_wurzel: Node
@export var name_arm_rechts: String = "HandRechts"
@export var name_arm_links: String = "HandLinks"
@export var name_oberkoerper: String = "Brust"
@export var name_kopf: String = "Kopf"

@export_group("Feinjustierung")
## Gesamtstaerke der Schlagpose. 0 = aus, 1 = wie definiert.
@export_range(0.0, 2.0) var staerke: float = 1.0
## Wie stark der Kopf die Brustdrehung ausgleicht, damit der Blick
## am Ziel bleibt statt mitzuschwenken.
@export_range(0.0, 1.0) var kopf_ausgleich: float = 0.7
## Falls die Arme in die falsche Richtung schlagen: hier umdrehen.
@export var achse_x_invertieren: bool = false
@export var achse_y_invertieren: bool = false
@export var achse_z_invertieren: bool = false
## True, wenn character_visual.gd die Pivots in _physics_process setzt.
@export var im_physikschritt: bool = false

var _laeuft: bool = false
var _zeit: float = 0.0
var _daten: WaffenDaten = null
var _hand_links: bool = false
var _fenster_offen: bool = false

var _posen: Dictionary = {}


func _init() -> void:
	# Werte in Grad. Ausgelegt auf einen Arm OHNE Ellbogen, der im Ruhezustand
	# nach unten haengt: X dreht ihn vor/zurueck, Z seitlich weg vom Koerper,
	# Y ist die Drehung des Oberkoerpers um die Hochachse.
	_posen = {
		WaffenDaten.Stil.FAUST: {
			"beide_arme": false,
			"ausholen": {"arm": Vector3(28, 0, -10), "koerper": Vector3(0, 16, 0)},
			"treffer":  {"arm": Vector3(-95, 0, 0), "koerper": Vector3(0, -20, 0)},
		},
		WaffenDaten.Stil.STICH: {
			"beide_arme": false,
			"ausholen": {"arm": Vector3(34, 0, -6), "koerper": Vector3(0, 26, 0)},
			"treffer":  {"arm": Vector3(-86, 0, 0), "koerper": Vector3(0, -30, 0)},
		},
		WaffenDaten.Stil.HIEB: {
			"beide_arme": false,
			"ausholen": {"arm": Vector3(12, 0, -74), "koerper": Vector3(0, 28, 0)},
			"treffer":  {"arm": Vector3(-72, 0, 26), "koerper": Vector3(0, -34, 0)},
		},
		WaffenDaten.Stil.SCHWUNG_SCHWER: {
			"beide_arme": true,
			"ausholen": {"arm": Vector3(148, 0, -12), "koerper": Vector3(-18, 0, 0)},
			"treffer":  {"arm": Vector3(-80, 0, 0), "koerper": Vector3(28, 0, 0)},
		},
		WaffenDaten.Stil.STANGE: {
			"beide_arme": true,
			"ausholen": {"arm": Vector3(36, 0, -6), "koerper": Vector3(0, 18, 0)},
			"treffer":  {"arm": Vector3(-70, 0, 0), "koerper": Vector3(0, -24, 0)},
		},
	}


func _ready() -> void:
	# Nach dem Visual-Skript laufen, damit unsere Pose obenauf liegt.
	process_priority = 100
	process_physics_priority = 100

	var wurzel: Node = such_wurzel if such_wurzel != null else get_parent()

	if arm_rechts == null:
		arm_rechts = _suchen(wurzel, name_arm_rechts)
	if arm_links == null:
		arm_links = _suchen(wurzel, name_arm_links)
	if oberkoerper == null:
		oberkoerper = _suchen(wurzel, name_oberkoerper)
	if kopf == null:
		kopf = _suchen(wurzel, name_kopf)

	set_process(false)
	set_physics_process(false)

	if arm_rechts == null:
		push_error("AngriffsAnimator (%s): Kein rechter Armpivot gefunden."
				% get_path()
				+ " Erwartet: ein Node3D namens '%s' unter '%s'," % [name_arm_rechts, wurzel.name]
				+ " oder das Feld 'arm_rechts' zuweisen. Komponente deaktiviert.")
		return

	if arm_links == null:
		push_warning("AngriffsAnimator: Kein linker Armpivot ('%s') gefunden."
				% name_arm_links + " Linke Schlaege und beidhaendige Stile"
				+ " animieren nur den rechten Arm.")


## Sucht rekursiv nach Namen. owned = false ist entscheidend: nur so werden
## auch Knoten INNERHALB instanzierter Unterszenen gefunden.
func _suchen(wurzel: Node, knoten_name: String) -> Node3D:
	if wurzel == null or knoten_name.is_empty():
		return null
	var treffer: Node = wurzel.find_child(knoten_name, true, false)
	if treffer == null:
		return null
	if treffer is Node3D:
		return treffer as Node3D
	push_warning("AngriffsAnimator: '%s' gefunden, ist aber kein Node3D." % knoten_name)
	return null


# =========================================================================
#  Steuerung
# =========================================================================

## Startet einen Schlag. Gibt false zurueck, wenn gerade schon einer laeuft.
func angriff_starten(daten: WaffenDaten, hand_links: bool = false) -> bool:
	if _laeuft or daten == null or arm_rechts == null:
		return false
	daten.gepruefte_werte()
	_daten = daten
	_hand_links = hand_links and arm_links != null
	_zeit = 0.0
	_fenster_offen = false
	_laeuft = true
	_aktiv_setzen(true)
	return true


## Bricht den laufenden Schlag ab (Treffer kassiert, Betaeubung, Schwimmen).
func abbrechen() -> void:
	if not _laeuft:
		return
	if _fenster_offen:
		_fenster_offen = false
		treffer_fenster_zu.emit()
	_laeuft = false
	_daten = null
	_aktiv_setzen(false)


func laeuft() -> bool:
	return _laeuft


## Fortschritt des aktuellen Schlages, 0.0 - 1.0.
func fortschritt() -> float:
	if not _laeuft or _daten == null:
		return 0.0
	return clampf(_zeit / _daten.angriff_dauer, 0.0, 1.0)


func _aktiv_setzen(an: bool) -> void:
	if im_physikschritt:
		set_physics_process(an)
		set_process(false)
	else:
		set_process(an)
		set_physics_process(false)


# =========================================================================
#  Ablauf
# =========================================================================

func _process(delta: float) -> void:
	_schritt(delta)


func _physics_process(delta: float) -> void:
	_schritt(delta)


func _schritt(delta: float) -> void:
	if not _laeuft or _daten == null:
		_aktiv_setzen(false)
		return

	_zeit += delta
	var t: float = clampf(_zeit / _daten.angriff_dauer, 0.0, 1.0)

	_pose_anwenden(t)

	if not _fenster_offen and t >= _daten.treffer_start and t < _daten.treffer_ende:
		_fenster_offen = true
		treffer_fenster_offen.emit(_daten, _hand_links)
	elif _fenster_offen and t >= _daten.treffer_ende:
		_fenster_offen = false
		treffer_fenster_zu.emit()

	if t >= 1.0:
		_laeuft = false
		_daten = null
		_aktiv_setzen(false)
		angriff_beendet.emit()


func _pose_anwenden(t: float) -> void:
	var stil_daten: Dictionary = _posen.get(_daten.stil, _posen[WaffenDaten.Stil.FAUST])
	var p_ausholen: Dictionary = stil_daten["ausholen"]
	var p_treffer: Dictionary = stil_daten["treffer"]
	var beide: bool = stil_daten["beide_arme"] and arm_links != null

	var ts: float = _daten.treffer_start
	var te: float = _daten.treffer_ende

	var von: Dictionary
	var nach: Dictionary
	var f: float = 0.0

	if t < ts:
		# Ausholen: weich raus
		von = _ruhe()
		nach = p_ausholen
		f = ease(t / maxf(ts, 0.001), 0.45)
	elif t < te:
		# Schlag: schnell rein
		von = p_ausholen
		nach = p_treffer
		f = ease((t - ts) / maxf(te - ts, 0.001), 2.4)
	else:
		# Zurueckholen
		von = p_treffer
		nach = _ruhe()
		f = ease((t - te) / maxf(1.0 - te, 0.001), 0.6)

	var arm: Vector3 = (von["arm"] as Vector3).lerp(nach["arm"], f)
	var koerper: Vector3 = (von["koerper"] as Vector3).lerp(nach["koerper"], f)

	# Nur Faeuste wechseln die Hand; Waffen sitzen rechts.
	var links: bool = _hand_links and not beide

	if beide:
		_pivot_drehen(arm_rechts, arm, false)
		_pivot_drehen(arm_links, arm, true)
	elif links:
		_pivot_drehen(arm_links, arm, true)
	else:
		_pivot_drehen(arm_rechts, arm, false)

	if oberkoerper:
		_pivot_drehen(oberkoerper, koerper, links)
		# Kopf haengt unter der Brust und wuerde die Drehung voll mitmachen.
		# Wir drehen ihn anteilig zurueck, damit der Blick am Ziel bleibt.
		if kopf and kopf_ausgleich > 0.0:
			_pivot_drehen(kopf, -koerper * kopf_ausgleich, links)


func _ruhe() -> Dictionary:
	return {"arm": Vector3.ZERO, "koerper": Vector3.ZERO}


## Multipliziert eine Zusatzdrehung auf die bereits gesetzte Pivot-Drehung.
## Ueber 'quaternion' statt 'rotation', damit eine eventuelle Skalierung des
## Knotens unangetastet bleibt.
func _pivot_drehen(knoten: Node3D, grad: Vector3, spiegeln: bool) -> void:
	if knoten == null:
		return

	var g: Vector3 = grad
	if spiegeln:
		g = Vector3(g.x, -g.y, -g.z)
	if achse_x_invertieren:
		g.x = -g.x
	if achse_y_invertieren:
		g.y = -g.y
	if achse_z_invertieren:
		g.z = -g.z

	g *= staerke
	if g.is_zero_approx():
		return

	var zusatz := Quaternion.from_euler(Vector3(
		deg_to_rad(g.x), deg_to_rad(g.y), deg_to_rad(g.z)
	))
	knoten.quaternion = knoten.quaternion * zusatz
