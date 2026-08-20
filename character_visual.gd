extends Node3D

# Cube-World-artiges Charaktermodell.
#
# - keine Beine, nur Füße
# - keine Arme, nur Hände
# - Torso in zwei Teilen: Hüfte (unten) + Brust (oben)
#   -> beugt sich beim Schleichen, dreht sich leicht beim Schlagen
# - Körper legt sich in Kurven
# - Laufzyklus läuft über die zurückgelegte STRECKE, nicht über die Zeit
#
# Erwarteter Knotenbaum (dieses Skript liegt auf dem Wurzelknoten "Visual"):
#
# Visual (Node3D)                    <- dieses Skript
# └─ Neigung (Node3D)
#    ├─ Huefte (Node3D)
#    │  ├─ TorsoUnten (MeshInstance3D)
#    │  └─ Brust (Node3D)
#    │     ├─ TorsoOben (MeshInstance3D)
#    │     ├─ Kopf (Node3D)
#    │     │  └─ KopfMesh (MeshInstance3D)
#    │     ├─ HandLinks (Node3D)
#    │     │  └─ HandLinksMesh (MeshInstance3D)
#    │     └─ HandRechts (Node3D)
#    │        └─ HandRechtsMesh (MeshInstance3D)
#    ├─ FussLinks (Node3D)
#    │  └─ FussLinksMesh (MeshInstance3D)
#    └─ FussRechts (Node3D)
#       └─ FussRechtsMesh (MeshInstance3D)
#
# Alle Größen und Ruhepositionen werden aus den Proportionswerten berechnet,
# die Meshes im Editor dürfen also beliebige Maße haben.

@export_group("Referenzen")
@export var player_path: NodePath = ^".."
## AUS lassen, solange spring_arm_camera.gd den Player dreht. Dieses Skript
## würde sonst zusätzlich drehen (Figur dreht sich doppelt) und das Free-Look
## auf Alt sofort wieder überschreiben.
## Nur einschalten, wenn die Zeile "player.rotation.y = lerp_angle(...)" in
## spring_arm_camera.gd entfernt wurde.
@export var dreht_selbst: bool = false
## Nur wirksam bei dreht_selbst = an:
## "Bewegung"  = in die Eingaberichtung (beim Rückwärtslaufen dreht sie sich um)
## "Kamera"    = immer starr in Kamerarichtung
## "Kamera im Kampf" = Bewegung, schnappt beim Blocken/Schlagen in Kamerarichtung
@export_enum("Bewegung", "Kamera", "Kamera im Kampf") var blick_modus: int = 2
## Im Kameramodus ohne Verzögerung drehen. Ein Lerp würde bei schnellen
## Mausbewegungen sichtbar hinterherhinken.
@export var kamera_hart: bool = true
## Gibt zweimal pro Sekunde Kamera-, Wunsch- und Modellwinkel aus
@export var blick_debug: bool = false

@export_group("Proportionen")
## Höhe des Hüft-Drehpunkts über den Füßen (= Unterkante unterer Torso).
## Abstand zur Fußoberkante = huefte_hoehe - fuss_groesse.y. Klein halten,
## sonst schwebt der Rumpf sichtbar über den Füßen.
@export var huefte_hoehe: float = 0.26
@export var torso_unten_groesse: Vector3 = Vector3(0.50, 0.38, 0.32)
@export var torso_oben_groesse: Vector3 = Vector3(0.56, 0.42, 0.34)
@export var kopf_groesse: Vector3 = Vector3(0.62, 0.60, 0.58)
@export var kopf_luecke: float = 0.04          # Schwebeabstand Brust -> Kopf
@export var hand_groesse: Vector3 = Vector3(0.19, 0.19, 0.19)
@export var fuss_groesse: Vector3 = Vector3(0.21, 0.18, 0.27)
@export var hand_abstand: float = 0.36         # seitlicher Abstand der Hände
@export var hand_hoehe: float = 0.20           # Höhe über dem Brust-Drehpunkt
@export var fuss_abstand: float = 0.15

@export_group("Farben")
## Aus, wenn du eigene Materialien direkt an den MeshInstance3D hängst
@export var farben_anwenden: bool = true
@export var farbe_kopf: Color = Color(0.92, 0.76, 0.60)
@export var farbe_torso_oben: Color = Color(0.30, 0.48, 0.68)
@export var farbe_torso_unten: Color = Color(0.24, 0.26, 0.34)
@export var farbe_hand: Color = Color(0.92, 0.76, 0.60)
@export var farbe_fuss: Color = Color(0.32, 0.22, 0.16)

@export_group("Laufen")
@export var schritt_frequenz: float = 4.0      # Bogenmaß pro zurückgelegtem Meter
@export var referenz_tempo: float = 6.0        # Tempo für volle Amplitude (= walk_speed)
@export var schritt_weite: float = 0.25        # Ausschlag der Füße vor/zurück
@export var fuss_hub: float = 0.14             # wie hoch die Füße angehoben werden
@export var hub_versatz: float = 0.8           # verschiebt den Abdruckpunkt
@export var fuss_kipp: float = 0.30
@export var hand_schwung: float = 0.16
@export var koerper_hub: float = 0.04          # vertikales Wippen
@export var lauf_torso_dreh: float = 5.0       # Grad Gegenrotation im Laufrhythmus
@export var lauf_blend: float = 12.0

@export_group("Drehen und Neigen")
@export var dreh_tempo: float = 18.0           # wie schnell er der Blickrichtung folgt
@export var kurven_faktor: float = 0.06        # Neigung pro rad/s Drehgeschwindigkeit
@export var kurven_max: float = 12.0           # Grad, harte Obergrenze
## Drehraten darüber werden gekappt – sonst kippt er bei jedem Mausruck voll weg
@export var kurven_rate_max: float = 4.0       # rad/s
## Tiefpass auf die Drehrate: kleine Werte = träger, kurze Rucke wirken nicht mehr
@export var kurven_glaettung: float = 6.0
@export var neigung_tempo: float = 9.0
## Grad Vorwärtsneigung beim normalen Laufen
@export var vorlage: float = 8.0
## Zusätzliche Grad beim Sprinten, kommt oben auf 'vorlage' drauf
@export var vorlage_sprint: float = 7.0
## Zuschlag auf Kurvenneigung und Obergrenze beim Sprinten (0.10 = 10 % mehr)
@export var sprint_neigung_bonus: float = 0.10

@export_group("Ducken")
@export var pose_tempo: float = 12.0
@export var duck_huefte_absenkung: float = 0.20
@export var duck_huefte: float = 16.0          # Grad, unterer Torso beugt sich
@export var duck_brust: float = 14.0           # Grad, oberer Torso zusätzlich
@export var duck_kopf_ausgleich: float = 0.7   # Kopf schaut trotzdem geradeaus

@export_group("Springen")
## Grundanhebung, sobald die Figur den Boden verlässt
@export var luft_fuss_hoch: float = 0.06
## Beim Steigen zusätzlich anziehen (Knie gibt es nicht, die Füße gehen hoch)
@export var sprung_fuss_anziehen: float = 0.16
## Ein Fuß nach vorne, einer nach hinten – gibt dem Absprung Dynamik
@export var sprung_fuss_spreizen: float = 0.15
## Zehen beim Steigen anheben (Bogenmaß)
@export var sprung_fuss_kipp: float = 0.45
## Beim Fallen strecken sich die Füße wieder nach unten
@export var fall_fuss_strecken: float = 0.12
## Zehen beim Fallen nach unten, bereit zum Landen (Bogenmaß)
@export var fall_fuss_kipp: float = -0.32
## Steig-/Fallgeschwindigkeit in m/s für den vollen Ausschlag
@export var sprung_referenz_tempo: float = 6.0
## Wie schnell zwischen Steig- und Fallpose geblendet wird
@export var sprung_blend: float = 14.0
@export var luft_hand_hoch: float = 0.05

@export_group("Schwimmen")
@export var schwimm_tempo: float = 4.0         # Zugfrequenz (zeitbasiert)
@export var schwimm_hand: float = 0.16
@export var schwimm_fuss: float = 0.12
@export var schwimm_neigung: float = 72.0      # Grad: 90 = ganz flach
@export var schwimm_tempo_blend: float = 4.0   # wie schnell die Figur kippt
@export var schwimm_absenkung: float = -0.42   # Körper sinkt beim Kippen etwas

@export_group("Kampf")
@export var kampf_tempo: float = 16.0
@export var schlag_reichweite: float = 0.50    # wie weit die Faust vorschnellt
@export var schlag_rueckzug: float = 0.35      # Anteil des Ausholens nach hinten
@export var schlag_drehung: float = 18.0       # Grad Rumpfdrehung beim Schlag
@export var huefte_gegen: float = 0.35         # Hüfte dreht dagegen
@export var block_hand_vorne: float = 0.26
@export var block_hand_hoch: float = 0.16

var _player: Player = null

var _neigung: Node3D
var _huefte: Node3D
var _brust: Node3D
var _kopf: Node3D
var _hand_l: Node3D
var _hand_r: Node3D
var _fuss_l: Node3D
var _fuss_r: Node3D
var _m_torso_u: MeshInstance3D
var _m_torso_o: MeshInstance3D
var _m_kopf: MeshInstance3D
var _m_hand_l: MeshInstance3D
var _m_hand_r: MeshInstance3D
var _m_fuss_l: MeshInstance3D
var _m_fuss_r: MeshInstance3D

var _hand_ruhe_l: Vector3 = Vector3.ZERO
var _hand_ruhe_r: Vector3 = Vector3.ZERO
var _fuss_ruhe_l: Vector3 = Vector3.ZERO
var _fuss_ruhe_r: Vector3 = Vector3.ZERO

var _phase := 0.0                               # Laufphase (streckenbasiert)
var _schwimm_phase := 0.0                       # Zugphase (zeitbasiert)
var _zeit := 0.0
var _ziel_yaw := 0.0
var _letzter_yaw := 0.0                         # rotation.y des Vorframes
var _dreh_rate := 0.0                           # geglättete Drehgeschwindigkeit
var _debug_timer := 0.0
var _pitch := 0.0
var _roll := 0.0
var _lauf_gewicht := 0.0                        # 0 = steht, 1 = läuft
var _luft_blend := 0.0                          # 0 = am Boden, 1 = in der Luft
var _steig_blend := 0.0                         # +1 = steigt, -1 = fällt
var _wasser_blend := 0.0                        # 0 = an Land, 1 = im Wasser
var _neige_blend := 0.0                         # eigener, langsamerer Blend
var _duck_blend := 0.0                          # 0 = aufrecht, 1 = geduckt
var _sprint_blend := 0.0                        # 0 = geht, 1 = sprintet
var _block_blend := 0.0                         # 0 = offen, 1 = Deckung
var _angriff_blend := 0.0                       # 0 = kein Schlag, 1 = Schlag
var _schlag_links := false
var _ruhe_pos_y := 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Player

	_neigung = get_node_or_null(^"Neigung") as Node3D
	_huefte = get_node_or_null(^"Neigung/Huefte") as Node3D
	_brust = get_node_or_null(^"Neigung/Huefte/Brust") as Node3D
	_kopf = get_node_or_null(^"Neigung/Huefte/Brust/Kopf") as Node3D
	_hand_l = get_node_or_null(^"Neigung/Huefte/Brust/HandLinks") as Node3D
	_hand_r = get_node_or_null(^"Neigung/Huefte/Brust/HandRechts") as Node3D
	_fuss_l = get_node_or_null(^"Neigung/FussLinks") as Node3D
	_fuss_r = get_node_or_null(^"Neigung/FussRechts") as Node3D

	_m_torso_u = get_node_or_null(^"Neigung/Huefte/TorsoUnten") as MeshInstance3D
	_m_torso_o = get_node_or_null(^"Neigung/Huefte/Brust/TorsoOben") as MeshInstance3D
	_m_kopf = get_node_or_null(^"Neigung/Huefte/Brust/Kopf/KopfMesh") as MeshInstance3D
	_m_hand_l = get_node_or_null(^"Neigung/Huefte/Brust/HandLinks/HandLinksMesh") as MeshInstance3D
	_m_hand_r = get_node_or_null(^"Neigung/Huefte/Brust/HandRechts/HandRechtsMesh") as MeshInstance3D
	_m_fuss_l = get_node_or_null(^"Neigung/FussLinks/FussLinksMesh") as MeshInstance3D
	_m_fuss_r = get_node_or_null(^"Neigung/FussRechts/FussRechtsMesh") as MeshInstance3D

	var fehlt: Array[String] = []
	for eintrag in [
		["Neigung", _neigung], ["Huefte", _huefte], ["Brust", _brust],
		["Kopf", _kopf], ["HandLinks", _hand_l], ["HandRechts", _hand_r],
		["FussLinks", _fuss_l], ["FussRechts", _fuss_r],
		["TorsoUnten", _m_torso_u], ["TorsoOben", _m_torso_o],
		["KopfMesh", _m_kopf], ["HandLinksMesh", _m_hand_l],
		["HandRechtsMesh", _m_hand_r], ["FussLinksMesh", _m_fuss_l],
		["FussRechtsMesh", _m_fuss_r],
	]:
		if eintrag[1] == null:
			fehlt.append(str(eintrag[0]))

	if not fehlt.is_empty():
		push_error("CharacterVisual: fehlende Knoten -> " + ", ".join(fehlt))
		set_process(false)
		return

	if _player == null:
		push_error("CharacterVisual: Player nicht gefunden (player_path prüfen)")
		set_process(false)
		return

	_ruhe_pos_y = position.y
	_ziel_yaw = global_rotation.y
	_letzter_yaw = global_rotation.y
	baue_proportionen()


# Setzt alle Meshgrößen und Ruhepositionen aus den Export-Werten.
# Kann jederzeit erneut gerufen werden, wenn du Proportionen änderst.
func baue_proportionen() -> void:
	_huefte.position = Vector3(0.0, huefte_hoehe, 0.0)
	_setze_box(_m_torso_u, torso_unten_groesse,
			Vector3(0.0, torso_unten_groesse.y * 0.5, 0.0), farbe_torso_unten)

	_brust.position = Vector3(0.0, torso_unten_groesse.y, 0.0)
	_setze_box(_m_torso_o, torso_oben_groesse,
			Vector3(0.0, torso_oben_groesse.y * 0.5, 0.0), farbe_torso_oben)

	_kopf.position = Vector3(0.0, torso_oben_groesse.y + kopf_luecke, 0.0)
	_setze_box(_m_kopf, kopf_groesse, Vector3(0.0, kopf_groesse.y * 0.5, 0.0), farbe_kopf)

	_hand_ruhe_l = Vector3(-hand_abstand, hand_hoehe, 0.0)
	_hand_ruhe_r = Vector3(hand_abstand, hand_hoehe, 0.0)
	_hand_l.position = _hand_ruhe_l
	_hand_r.position = _hand_ruhe_r
	_setze_box(_m_hand_l, hand_groesse, Vector3.ZERO, farbe_hand)
	_setze_box(_m_hand_r, hand_groesse, Vector3.ZERO, farbe_hand)

	_fuss_ruhe_l = Vector3(-fuss_abstand, fuss_groesse.y * 0.5, 0.0)
	_fuss_ruhe_r = Vector3(fuss_abstand, fuss_groesse.y * 0.5, 0.0)
	_fuss_l.position = _fuss_ruhe_l
	_fuss_r.position = _fuss_ruhe_r
	_setze_box(_m_fuss_l, fuss_groesse, Vector3.ZERO, farbe_fuss)
	_setze_box(_m_fuss_r, fuss_groesse, Vector3.ZERO, farbe_fuss)


# Gesamthöhe der Figur in Metern – Bezugsgröße für Kapsel und Kamera.
func hole_gesamt_hoehe() -> float:
	return huefte_hoehe + torso_unten_groesse.y + torso_oben_groesse.y \
			+ kopf_luecke + kopf_groesse.y


# Hand-Drehpunkt, an den später Waffen gehängt werden.
func hole_hand(links: bool) -> Node3D:
	return _hand_l if links else _hand_r


func _process(delta: float) -> void:
	if _player == null:
		return

	_zeit += delta
	var w: float = 1.0 - exp(-pose_tempo * delta)
	var kw: float = 1.0 - exp(-kampf_tempo * delta)
	var schwimmt: bool = _player.is_swimming
	var kampf: Combat = _player.combat

	var v: Vector3 = _player.velocity
	var hor: Vector3 = Vector3(v.x, 0.0, v.z)
	var tempo: float = hor.length()
	var tempo_n: float = clampf(tempo / maxf(referenz_tempo, 0.01), 0.0, 1.3)

	# ---------------------------------------------------------- Zustandsblends
	_wasser_blend = lerpf(_wasser_blend, 1.0 if schwimmt else 0.0, w)

	# Körperneigung im Wasser bewusst NICHT an is_on_floor() gekoppelt: Wer auf
	# dem Grund eines tiefen Sees ankommt, soll weiter waagerecht schwimmen.
	_neige_blend = lerpf(_neige_blend, 1.0 if schwimmt else 0.0,
			1.0 - exp(-schwimm_tempo_blend * delta))

	var duck_ziel: float = 1.0 if (_player.is_sneaking and not schwimmt) else 0.0
	_duck_blend = lerpf(_duck_blend, duck_ziel, w)

	var sprint_ziel: float = 1.0 if (_player.is_sprinting and not schwimmt) else 0.0
	_sprint_blend = lerpf(_sprint_blend, sprint_ziel, w)

	var luft_ziel: float = 0.0
	if not _player.is_on_floor() and not schwimmt and not _player.is_climbing:
		luft_ziel = 1.0
	_luft_blend = lerpf(_luft_blend, luft_ziel, w)

	# ---------------------------------------------------------- Blickrichtung
	# WICHTIG: Grundlage ist die Eingaberichtung, nicht velocity. Die
	# Geschwindigkeit hinkt durch ground_accel spürbar hinterher und zieht beim
	# Kameraschwenk einen weiten Bogen – das Modell würde dabei sichtbar in eine
	# andere Richtung schauen als die Kamera.
	var wunsch: Vector3 = _player.wunsch_richtung
	var kamera_yaw: float = 0.0
	if _player.camera_pivot != null:
		kamera_yaw = _player.camera_pivot.global_rotation.y

	var kampf_aktiv: bool = kampf != null \
			and (kampf.ist_am_blocken or kampf.ist_am_angreifen)

	var hart: bool = false
	match blick_modus:
		1:                                       # immer Kamera
			_ziel_yaw = kamera_yaw
			hart = kamera_hart
		2:                                       # Kamera nur im Kampf
			if kampf_aktiv:
				_ziel_yaw = kamera_yaw
				hart = kamera_hart
			elif wunsch.length_squared() > 0.01:
				_ziel_yaw = atan2(-wunsch.x, -wunsch.z)
		_:                                       # Eingaberichtung
			if wunsch.length_squared() > 0.01:
				_ziel_yaw = atan2(-wunsch.x, -wunsch.z)

	# Bewusst global_rotation statt rotation: Der Player-Knoten wird von
	# spring_arm_camera.gd selbst gedreht. Eine lokale Drehung würde sich zu
	# dessen Drehung addieren – die Figur würde sich doppelt so weit drehen.
	if dreht_selbst:
		if hart:
			global_rotation.y = _ziel_yaw
		else:
			global_rotation.y = lerp_angle(global_rotation.y, _ziel_yaw,
					1.0 - exp(-dreh_tempo * delta))

	# Drehrate aus der tatsächlichen Weltausrichtung messen, nicht aus der
	# eigenen Vorgabe. Dreht ein anderes Skript den Player (dreht_selbst = aus),
	# bleibt die lokale rotation.y konstant 0 – lokal messen ergäbe also nie
	# eine Kurvenneigung.
	var welt_yaw: float = global_rotation.y
	var roh_rate: float = angle_difference(_letzter_yaw, welt_yaw) \
			/ maxf(delta, 0.0001)
	_letzter_yaw = welt_yaw

	if blick_debug:
		_debug_timer -= delta
		if _debug_timer <= 0.0:
			_debug_timer = 0.5
			var wunsch_grad: float = 999.0
			if wunsch.length_squared() > 0.01:
				wunsch_grad = rad_to_deg(atan2(-wunsch.x, -wunsch.z))
			print("[Blick] Kamera %.1f | Wunsch %.1f | Modell %.1f" % [
					rad_to_deg(kamera_yaw), wunsch_grad, rad_to_deg(welt_yaw)])

	# Rate kappen und tiefpassfiltern: ein kurzer Mausruck erzeugt sonst sofort
	# die volle Kurvenneigung, obwohl die Figur gar keine Kurve läuft.
	var grenz_rate: float = maxf(kurven_rate_max, 0.01)
	_dreh_rate = lerpf(_dreh_rate, clampf(roh_rate, -grenz_rate, grenz_rate),
			1.0 - exp(-kurven_glaettung * delta))

	position.y = _ruhe_pos_y

	# ------------------------------------------------- Kurvenneigung + Vorlage
	# Beim Sprinten legt sie sich etwas stärker in die Kurve – Faktor wirkt auf
	# Ausschlag UND Obergrenze, sonst würde der Clamp den Bonus wegschneiden.
	var sprint_faktor: float = 1.0 + sprint_neigung_bonus * _sprint_blend
	var grenze: float = deg_to_rad(kurven_max) * sprint_faktor
	var flach: float = clampf(tempo_n, 0.0, 1.0) * (1.0 - _neige_blend)
	var ziel_roll: float = clampf(_dreh_rate * kurven_faktor * sprint_faktor,
			-grenze, grenze) * flach
	# Vorlage: Grundwert beim Laufen, beim Sprinten kommt vorlage_sprint dazu
	var ziel_pitch: float = -deg_to_rad(vorlage + vorlage_sprint * _sprint_blend) * flach
	var nf: float = 1.0 - exp(-neigung_tempo * delta)
	_roll = lerpf(_roll, ziel_roll, nf)
	_pitch = lerpf(_pitch, ziel_pitch, nf)

	# Schwimmneigung kommt ungefiltert dazu, sie hat ihren eigenen Blend
	var schwimm_kipp: float = deg_to_rad(schwimm_neigung) * _neige_blend
	_neigung.rotation = Vector3(_pitch - schwimm_kipp, 0.0, _roll)

	# ------------------------------------------------ Laufphase über Strecke
	var am_boden: bool = _player.is_on_floor() or _player.is_climbing
	var laufend: bool = am_boden and tempo > 0.15 and not schwimmt
	_lauf_gewicht = lerpf(_lauf_gewicht, 1.0 if laufend else 0.0,
			1.0 - exp(-lauf_blend * delta))
	if laufend:
		_phase = fposmod(_phase + tempo * delta * schritt_frequenz, TAU)
	_schwimm_phase += schwimm_tempo * delta

	_neigung.position.y = -absf(sin(_phase)) * koerper_hub * _lauf_gewicht \
			+ schwimm_absenkung * _neige_blend

	# ---------------------------------------------------------- Kampfzustände
	var blockt: bool = kampf != null and kampf.ist_am_blocken
	_block_blend = lerpf(_block_blend, 1.0 if blockt else 0.0, kw)

	# Der Schlag blendet hart ein (damit er knackig wirkt) und weich aus.
	if kampf != null and kampf.ist_am_angreifen:
		_angriff_blend = 1.0
		_schlag_links = kampf.hand_links
	else:
		_angriff_blend = lerpf(_angriff_blend, 0.0, kw)

	var kurve: float = 0.0
	if _angriff_blend > 0.001 and kampf != null:
		kurve = _schlag_kurve(kampf.angriff_fortschritt) * _angriff_blend

	# ------------------------------------------------------ Torso: zwei Teile
	# Negative Werte um X beugen nach vorne (positiv würde nach hinten kippen).
	var huefte_pitch: float = -deg_to_rad(duck_huefte) * _duck_blend
	var brust_pitch: float = -deg_to_rad(duck_brust) * _duck_blend

	var seite: float = -1.0 if _schlag_links else 1.0
	var schlag_yaw: float = deg_to_rad(schlag_drehung) * kurve * seite
	var lauf_yaw: float = sin(_phase) * deg_to_rad(lauf_torso_dreh) \
			* _lauf_gewicht * clampf(tempo_n, 0.0, 1.0)

	var brust_yaw: float = schlag_yaw - lauf_yaw
	var huefte_yaw: float = -schlag_yaw * huefte_gegen + lauf_yaw * 0.5

	_huefte.position.y = huefte_hoehe - duck_huefte_absenkung * _duck_blend
	_huefte.rotation = Vector3(huefte_pitch, huefte_yaw, 0.0)
	_brust.rotation = Vector3(brust_pitch, brust_yaw, 0.0)

	# ------------------------------------------------------------------- Kopf
	# Gleicht die Rumpfneigung teilweise aus, damit der Blick nach vorne bleibt.
	_kopf.rotation = Vector3(
			-(_pitch + huefte_pitch + brust_pitch) * duck_kopf_ausgleich
					+ schwimm_kipp * 0.55,
			-(brust_yaw + huefte_yaw) * 0.5,
			-_roll * duck_kopf_ausgleich)

	# ------------------------------------------------------------------ Füße
	var gew: float = _lauf_gewicht * clampf(tempo_n, 0.0, 1.3)
	var amp: float = schritt_weite * gew
	var hub: float = fuss_hub * gew
	var fuss_wasser: float = sin(_schwimm_phase * 1.5) * schwimm_fuss * _wasser_blend

	# Sprungpose: In der Luft fällt der Laufzyklus weg (gew geht gegen 0), also
	# braucht es eine eigene Haltung. Beim Steigen ziehen die Füße an und
	# spreizen sich, beim Fallen strecken sie sich zur Landung nach unten.
	var steig_ziel: float = clampf(
			_player.velocity.y / maxf(sprung_referenz_tempo, 0.01), -1.0, 1.0)
	_steig_blend = lerpf(_steig_blend, steig_ziel, 1.0 - exp(-sprung_blend * delta))
	var steigt: float = maxf(_steig_blend, 0.0)
	var faellt: float = maxf(-_steig_blend, 0.0)

	var luft_y: float = _luft_blend * (luft_fuss_hoch
			+ sprung_fuss_anziehen * steigt
			- fall_fuss_strecken * faellt)
	var luft_kipp: float = _luft_blend * (sprung_fuss_kipp * steigt
			+ fall_fuss_kipp * faellt)
	var spreiz: float = _luft_blend * sprung_fuss_spreizen * steigt

	# Vorne ist -Z: der rechte Fuß bekommt das negative Vorzeichen und geht damit
	# beim Absprung nach vorne. Für den umgekehrten Fall die beiden tauschen.
	_setze_fuss(_fuss_l, _fuss_ruhe_l, _phase, amp, hub, gew, fuss_wasser,
			luft_y, spreiz, luft_kipp)
	_setze_fuss(_fuss_r, _fuss_ruhe_r, _phase + PI, amp, hub, gew, -fuss_wasser,
			luft_y, -spreiz, luft_kipp)

	# ----------------------------------------------------------------- Hände
	var h_amp: float = hand_schwung * gew
	var atmen: float = sin(_zeit * 2.2) * 0.012 * (1.0 - _lauf_gewicht) \
			* (1.0 - _wasser_blend)
	var hoch: float = atmen + luft_hand_hoch * _luft_blend
	var hand_wasser: float = sin(_schwimm_phase) * schwimm_hand * _wasser_blend

	var ziel_l: Vector3 = _hand_ruhe_l \
			+ Vector3(0.0, hoch, sin(_phase) * h_amp + hand_wasser)
	var ziel_r: Vector3 = _hand_ruhe_r \
			+ Vector3(0.0, hoch, -sin(_phase) * h_amp - hand_wasser)

	# Deckung legt sich darüber: beide Hände hoch und vor den Körper
	if _block_blend > 0.001:
		ziel_l = ziel_l.lerp(_hand_ruhe_l + Vector3(hand_abstand * 0.30,
				block_hand_hoch, -block_hand_vorne), _block_blend)
		ziel_r = ziel_r.lerp(_hand_ruhe_r + Vector3(-hand_abstand * 0.30,
				block_hand_hoch, -block_hand_vorne), _block_blend)

	# Schlag hat Vorrang, die Fäuste wechseln sich über kampf.hand_links ab
	if absf(kurve) > 0.001:
		var stoss := Vector3(0.0, 0.03 * kurve, -schlag_reichweite * kurve)
		var mitte := hand_abstand * 0.45 * maxf(kurve, 0.0)
		if _schlag_links:
			ziel_l += stoss + Vector3(mitte, 0.0, 0.0)
			_hand_l.rotation.x = -maxf(kurve, 0.0) * 0.35
			_hand_r.rotation.x = 0.0
		else:
			ziel_r += stoss + Vector3(-mitte, 0.0, 0.0)
			_hand_r.rotation.x = -maxf(kurve, 0.0) * 0.35
			_hand_l.rotation.x = 0.0
	else:
		_hand_l.rotation.x = 0.0
		_hand_r.rotation.x = 0.0

	_hand_l.position = ziel_l
	_hand_r.position = ziel_r


# Schlagkurve über den gesamten Schlag: 0 = Beginn, 1 = Ende.
# Rückgabe: negativ = ausholen, 1.0 = volle Streckung.
# Der Treffer landet bei rund 0.32 – genau im schnellen Teil der Bewegung.
func _schlag_kurve(f: float) -> float:
	if f < 0.30:
		return lerpf(0.0, -schlag_rueckzug, f / 0.30)
	elif f < 0.48:
		return lerpf(-schlag_rueckzug, 1.0, (f - 0.30) / 0.18)
	return lerpf(1.0, 0.12, (f - 0.48) / 0.52)


func _setze_fuss(knoten: Node3D, ruhe: Vector3, phase: float, amp: float,
		hub: float, gew: float, wasser: float,
		luft_y: float, luft_z: float, luft_kipp: float) -> void:
	var z: float = -sin(phase) * amp + wasser + luft_z
	var y: float = maxf(0.0, sin(phase + hub_versatz)) * hub + luft_y
	knoten.position = Vector3(ruhe.x, ruhe.y + y, ruhe.z + z)
	# Positive Werte um X heben die Zehen an, negative senken sie.
	knoten.rotation.x = cos(phase) * fuss_kipp * gew + luft_kipp


func _setze_box(mi: MeshInstance3D, groesse: Vector3, lokal: Vector3,
		farbe: Color) -> void:
	if mi == null:
		return

	# Immer eine eigene Kopie: duplizierte Knoten teilen sich sonst dieselbe
	# Mesh-Ressource und würden sich gegenseitig umformen.
	var box: BoxMesh = mi.mesh as BoxMesh
	box = BoxMesh.new() if box == null else box.duplicate() as BoxMesh
	box.size = groesse
	mi.mesh = box
	mi.position = lokal

	if farben_anwenden:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = farbe
		mat.roughness = 1.0
		mat.metallic_specular = 0.0
		mi.material_override = mat
