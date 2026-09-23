extends Node

## Feindliche KI (Roadmap-Verhaltensart 1 von 4): verfolgt den Spieler,
## sobald er in Reichweite UND SICHTBAR ist, greift an, sobald er nah genug
## steht, und blockt gelegentlich einen Angriff statt immer nur draufzuhalten.
##
## SICHTLINIE: ein Raycast von Kopfhoehe zu Kopfhoehe, nur die Gelaendeebene
## (collision_mask = 1) blockt - Spieler und andere Akteure liegen auf Ebene
## 2 und stoeren den Strahl nicht, ein Ausschluss ist deshalb nicht noetig.
## 'sicht_gedaechtnis' verhindert, dass ein kurzer Sichtverlust (ein
## einzelner Block im Weg) die Verfolgung sofort abbricht.
##
## BLOCKEN: wuerfelt bei Angriffsbeginn des Spielers (steigende Flanke von
## dessen combat.ist_am_angreifen), nicht bei jedem einzelnen Treffer einer
## Kombo. 'block_reaktionszeit' verzoegert den tatsaechlichen Block, damit es
## nicht wie ein perfekter Instant-Block wirkt. Nutzt combat.ki_blocken() -
## siehe dortigen Kommentar zu 'von_spieler_gesteuert', warum die KI nicht
## einfach Input simulieren darf.
##
## Erwartet: liegt als Kindknoten "Ki" unter einem Npc, der einen
## Geschwisterknoten "Combat" mit von_spieler_gesteuert = false hat.
##
## Bewusst WEGGELASSEN in dieser Fassung, spaeter nachruestbar:
##  - Patrouillieren oder eine Ruheposition ohne Spieler in der Naehe
##  - Ein Block ueber mehrere Kombo-Treffer hinweg dynamisch verlaengern

@export_group("Erkennung")
@export var erkennungs_radius: float = 12.0
@export var verliert_bei: float = 16.0        # Distanz, ab der die Verfolgung abbricht
@export var augenhoehe: float = 1.4
## Nur diese Kollisionsebene blockt die Sicht. Vorgabe 1 = Gelaende,
## passend zu terrain_maske in trainingspuppe.gd und Player.collision_layer=2.
@export var sicht_maske: int = 1
## Wie lange der NPC nach dem letzten Sichtkontakt noch weiterverfolgt.
@export var sicht_gedaechtnis: float = 2.0

@export_group("Angriff")
@export var angriffs_abstand: float = 1.8
@export var dreh_tempo: float = 6.0

@export_group("Blocken")
## Wahrscheinlichkeit, dass der NPC einen beginnenden Angriff ueberhaupt
## blockt, statt einfach weiterzukaempfen. Klein halten, sonst wirkt er
## unbesiegbar.
@export_range(0.0, 1.0) var block_chance: float = 0.35
## Verzoegerung, bevor der Block tatsaechlich einsetzt - simuliert
## Reaktionszeit statt eines perfekten Instant-Blocks.
@export var block_reaktionszeit: float = 0.15
@export var block_dauer: float = 0.5

var _npc: Akteur = null
var _spieler: Node3D = null
var _sicht_erinnerung: float = 0.0
var _block_timer: float = 0.0
var _spieler_griff_an_zuvor: bool = false


func _ready() -> void:
	_npc = get_parent() as Akteur
	if _npc == null:
		push_error("Ki (feindlich): Elternknoten ist kein Akteur.")
		set_process(false)


func _process(delta: float) -> void:
	if _npc.combat == null or _npc.combat.ist_tot:
		return

	var spieler := _finde_spieler()
	if spieler == null:
		_npc.wunsch_richtung = Vector3.ZERO
		_npc.combat.ki_blocken(false, delta)
		return

	var zu_spieler: Vector3 = spieler.global_position - _npc.global_position
	zu_spieler.y = 0.0
	var distanz: float = zu_spieler.length()

	var sichtbar: bool = distanz <= erkennungs_radius and _hat_sichtlinie(spieler)
	if sichtbar:
		_sicht_erinnerung = sicht_gedaechtnis
	else:
		_sicht_erinnerung = maxf(_sicht_erinnerung - delta, 0.0)

	var im_kampf: bool = _npc.combat.im_kampf()
	var verfolgt: bool = _sicht_erinnerung > 0.0 or (im_kampf and distanz <= verliert_bei)

	if not verfolgt:
		_npc.wunsch_richtung = Vector3.ZERO
		_npc.combat.ki_blocken(false, delta)
		return

	var richtung: Vector3 = zu_spieler / maxf(distanz, 0.001)

	# Immer zum Spieler drehen, auch im Angriffsabstand stehend - sonst zeigt
	# der Trefferkegel (Combat._blick_yaw() liest die Koerperdrehung) beim
	# Zuschlagen oder Blocken irgendwohin statt zum Ziel.
	var ziel_yaw: float = atan2(-richtung.x, -richtung.z)
	_npc.rotation.y = lerp_angle(_npc.rotation.y, ziel_yaw,
			1.0 - exp(-dreh_tempo * delta))

	if distanz > angriffs_abstand:
		_npc.wunsch_richtung = richtung
		_npc.combat.ki_blocken(false, delta)
		_block_timer = 0.0
		_spieler_griff_an_zuvor = false
		return

	_npc.wunsch_richtung = Vector3.ZERO
	_kampf_entscheiden(spieler, delta)


func _kampf_entscheiden(spieler: Node3D, delta: float) -> void:
	var spieler_akteur := spieler as Akteur
	var spieler_greift_an: bool = spieler_akteur != null and spieler_akteur.combat != null \
			and spieler_akteur.combat.ist_am_angreifen

	# Steigende Flanke: der Spieler hat GERADE ERST zu schlagen begonnen.
	# Nur dann neu wuerfeln, sonst wuerde eine mehrschlaegige Kombo denselben
	# Angriff mehrfach als "neuen" Angriff werten.
	if spieler_greift_an and not _spieler_griff_an_zuvor and _block_timer <= 0.0:
		if randf() < block_chance:
			_block_timer = block_reaktionszeit + block_dauer
	_spieler_griff_an_zuvor = spieler_greift_an

	if _block_timer > 0.0:
		_block_timer -= delta
		var haelt: bool = _block_timer <= block_dauer
		_npc.combat.ki_blocken(haelt, delta)
		return

	_npc.combat.ki_blocken(false, delta)
	_npc.combat.ki_angreifen()


## Leer = nichts im Weg = Sichtlinie frei.
func _hat_sichtlinie(spieler: Node3D) -> bool:
	var von: Vector3 = _npc.global_position + Vector3(0.0, augenhoehe, 0.0)
	var nach: Vector3 = spieler.global_position + Vector3(0.0, augenhoehe, 0.0)

	var space := _npc.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(von, nach)
	query.collision_mask = sicht_maske
	var treffer := space.intersect_ray(query)
	return treffer.is_empty()


func _finde_spieler() -> Node3D:
	if _spieler == null or not is_instance_valid(_spieler):
		_spieler = get_tree().get_first_node_in_group("player") as Node3D
	return _spieler
