class_name Combat
extends Node

# Kampfkomponente des Spielers.
# Hängt als Kindknoten "Combat" unter dem Player.
# Kümmert sich um Leben, Ausdauer, Fausthiebe, Blocken und perfektes Blocken.

signal getroffen(menge: float)             # Schaden ist durchgekommen
signal geblockt(menge: float)              # normal geblockt
signal perfekt_geblockt()                  # Parry gelungen
signal deckung_gebrochen()                 # Ausdauer reichte nicht

@export_group("Leben")
@export var max_leben: float = 100.0
@export var tot_dauer: float = 2.0                # Sekunden bis zum Wiederbeleben

@export_group("Ausdauer")
@export var max_ausdauer: float = 100.0
@export var ausdauer_regen: float = 26.0          # pro Sekunde im Kampf
@export var regen_bonus_ausserhalb: float = 3.0   # Faktor außerhalb des Kampfes
@export var regen_pause: float = 0.5              # Pause nach jedem Verbrauch
@export var kampf_dauer: float = 6.0              # wie lange "im Kampf" nachwirkt
@export var erschoepft_schwelle: float = 0.25     # ab wieviel Anteil wieder handlungsfähig

@export_group("Kosten")
@export var kosten_angriff: float = 12.0
@export var kosten_block: float = 20.0            # pro geblocktem Treffer
@export var kosten_sprint: float = 10.0           # pro Sekunde, nur im Kampf

@export_group("Faustangriff")
@export var reichweite: float = 2.4
@export var trefferwinkel: float = 110.0          # Kegel vor dem Spieler (Grad)
@export var hoehen_toleranz: float = 2.0          # max. Höhenunterschied zum Ziel
@export var schaden: float = 9.0
@export var schaden_finisher: float = 16.0        # letzter Schlag der Kombo
@export var ausholen: float = 0.12                # Sekunden bis zum Trefferfenster
@export var treffer_dauer: float = 0.06           # Länge des Trefferfensters
@export var erholung: float = 0.20                # Sekunden danach
@export var max_kombo: int = 3

@export_group("Blocken")
@export var block_reduktion: float = 0.75         # 0.75 = 75 % weniger Schaden
@export var block_winkel: float = 140.0           # nur Treffer von vorne
@export var block_tempo: float = 0.45             # Tempofaktor beim Blocken
@export var betaeubung_dauer: float = 0.7         # nach gebrochener Deckung

@export_group("Perfekter Block")
@export var parry_fenster: float = 0.25           # Sekunden nach dem Drücken
@export var parry_ausdauer_bonus: float = 15.0    # Belohnung fürs Timing
@export var schwachstelle_dauer: float = 2.0      # wie lange der Gegner offen ist
@export var crit_faktor: float = 2.5              # Schadensfaktor auf offene Ziele

enum Phase { KEINE, AUSHOLEN, TREFFER, ERHOLUNG }

# Öffentlicher Zustand – wird von player.gd, character_visual.gd und hud.gd gelesen
var leben: float = 0.0
var ausdauer: float = 0.0
var ist_am_angreifen: bool = false
var ist_am_blocken: bool = false
var ist_erschoepft: bool = false
var ist_betaeubt: bool = false
var ist_tot: bool = false
var kombo_index: int = 0
var hand_links: bool = false                      # welche Faust gerade schlägt
var angriff_fortschritt: float = 0.0              # 0..1 über den ganzen Schlag

var _player = null                                # bewusst ohne Typ (Zyklus vermeiden)
var _phase: int = Phase.KEINE
var _phase_timer: float = 0.0
var _kombo_puffer: bool = false
var _regen_timer: float = 0.0
var _kampf_timer: float = 0.0
var _betaeubung_timer: float = 0.0
var _tot_timer: float = 0.0
var _block_seit: float = 999.0                    # Sekunden seit Blockbeginn
var _offen_timer: float = 0.0                     # eigene Schwachstelle
var _getroffen: Array = []


func _ready() -> void:
	_player = get_parent()
	if _player == null or not _player is CharacterBody3D:
		push_error("Combat: Elternknoten ist kein CharacterBody3D (Player)!")
		set_process(false)
		return

	if not InputMap.has_action("attack"):
		push_error("Combat: Eingabeaktion 'attack' fehlt (Projekteinstellungen -> Eingabezuordnung)")
	if not InputMap.has_action("block"):
		push_error("Combat: Eingabeaktion 'block' fehlt (Projekteinstellungen -> Eingabezuordnung)")

	leben = max_leben
	ausdauer = max_ausdauer


func _process(delta: float) -> void:
	if _player == null:
		return

	_timer_update(delta)

	if ist_tot:
		return

	_eingabe(delta)
	_angriff_update(delta)
	_regen_update(delta)


# ---------------------------------------------------------------- Abfragen

func im_kampf() -> bool:
	return _kampf_timer > 0.0


func darf_sprinten() -> bool:
	if ist_tot or ist_betaeubt:
		return false
	return not ist_erschoepft and not ist_am_blocken and not ist_am_angreifen


# Wird von Gegnern aufgerufen, wenn sie den Spieler ins Visier nehmen.
func kampf_ausloesen() -> void:
	_kampf_timer = kampf_dauer


# Sprint verbraucht nur im Kampf Ausdauer.
func sprint_kosten(delta: float) -> void:
	if not im_kampf():
		return
	_verbrauche(kosten_sprint * delta, false)


# ---------------------------------------------------------------- Schwachstelle

# Wird aufgerufen, wenn ein Gegner den Angriff des Spielers perfekt blockt.
func schwachstelle_oeffnen(dauer: float) -> void:
	_offen_timer = maxf(_offen_timer, dauer)
	ist_betaeubt = true
	_betaeubung_timer = maxf(_betaeubung_timer, dauer)
	ist_am_blocken = false
	_beende_schlag()


func ist_offen() -> bool:
	return _offen_timer > 0.0


func schwachstelle_schliessen() -> void:
	_offen_timer = 0.0


# ---------------------------------------------------------------- Eingabe

func _eingabe(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		ist_am_blocken = false
		_block_seit = 999.0
		return

	var moeglich: bool = not _player.is_swimming and not ist_betaeubt

	# --- Blocken (halten) ---
	var will_blocken: bool = moeglich \
			and Input.is_action_pressed("block") \
			and _phase == Phase.KEINE \
			and not ist_erschoepft

	if will_blocken and not ist_am_blocken:
		_block_seit = 0.0                 # frisch gedrückt -> Parry-Fenster offen
	elif will_blocken:
		_block_seit += delta
	else:
		_block_seit = 999.0

	ist_am_blocken = will_blocken
	if ist_am_blocken:
		_kampf_timer = kampf_dauer

	# --- Angreifen ---
	if not moeglich or ist_am_blocken:
		return
	if not Input.is_action_just_pressed("attack"):
		return

	if _phase == Phase.KEINE:
		_starte_schlag(0)
	elif _phase == Phase.ERHOLUNG and kombo_index + 1 < max_kombo:
		_kombo_puffer = true


# ---------------------------------------------------------------- Angriff

func _starte_schlag(index: int) -> void:
	if ist_erschoepft or ausdauer < kosten_angriff:
		return

	kombo_index = index
	hand_links = not hand_links        # jeder Schlag wechselt die Faust
	_phase = Phase.AUSHOLEN
	_phase_timer = ausholen
	ist_am_angreifen = true
	_getroffen.clear()
	_verbrauche(kosten_angriff)


func _angriff_update(delta: float) -> void:
	if _phase == Phase.KEINE:
		angriff_fortschritt = 0.0
		return

	_phase_timer -= delta

	match _phase:
		Phase.AUSHOLEN:
			if _phase_timer <= 0.0:
				_phase = Phase.TREFFER
				_phase_timer = treffer_dauer
		Phase.TREFFER:
			_treffer_pruefen()
			if _phase_timer <= 0.0:
				_phase = Phase.ERHOLUNG
				_phase_timer = erholung
		Phase.ERHOLUNG:
			if _phase_timer <= 0.0:
				if _kombo_puffer and kombo_index + 1 < max_kombo:
					_kombo_puffer = false
					_starte_schlag(kombo_index + 1)
				else:
					_beende_schlag()

	angriff_fortschritt = _fortschritt()


func _beende_schlag() -> void:
	_phase = Phase.KEINE
	_phase_timer = 0.0
	_kombo_puffer = false
	ist_am_angreifen = false
	kombo_index = 0
	angriff_fortschritt = 0.0


func _fortschritt() -> float:
	var gesamt: float = ausholen + treffer_dauer + erholung
	if gesamt <= 0.0:
		return 0.0
	var v: float = 0.0
	match _phase:
		Phase.AUSHOLEN:
			v = ausholen - _phase_timer
		Phase.TREFFER:
			v = ausholen + (treffer_dauer - _phase_timer)
		Phase.ERHOLUNG:
			v = ausholen + treffer_dauer + (erholung - _phase_timer)
	return clampf(v / gesamt, 0.0, 1.0)


func _treffer_pruefen() -> void:
	var blick: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, _blick_yaw())
	var grenze: float = cos(deg_to_rad(trefferwinkel * 0.5))
	var basis: float = schaden
	if kombo_index >= max_kombo - 1:
		basis = schaden_finisher

	for ziel in get_tree().get_nodes_in_group("damageable"):
		if ziel == _player or ziel in _getroffen:
			continue
		if not ziel is Node3D:
			continue
		if not ziel.has_method("take_damage"):
			continue

		var zu_ziel: Vector3 = ziel.global_position - _player.global_position
		if absf(zu_ziel.y) > hoehen_toleranz:
			continue
		zu_ziel.y = 0.0
		var dist: float = zu_ziel.length()
		if dist > reichweite:
			continue
		if dist > 0.01 and blick.dot(zu_ziel / dist) < grenze:
			continue

		_getroffen.append(ziel)
		_kampf_timer = kampf_dauer

		# --- Schwachstelle ausnutzen? ---
		var menge: float = basis
		var kritisch: bool = ziel.has_method("ist_offen") and ziel.ist_offen()
		if kritisch:
			menge = basis * crit_faktor

		var richtung: Vector3 = blick if dist <= 0.01 else zu_ziel / dist
		ziel.take_damage(menge, _player, richtung)

		if kritisch and ziel.has_method("schwachstelle_schliessen"):
			ziel.schwachstelle_schliessen()


# Richtung, in die Schläge und die Blockzone zeigen.
# Bewusst die Ausrichtung der FIGUR, nicht die der Kamera: Bei Free-Look (Alt)
# soll man sich umsehen können, ohne dass Treffer- und Blockkegel mitwandern.
func _blick_yaw() -> float:
	if _player != null:
		return _player.global_rotation.y
	return 0.0


# ---------------------------------------------------------------- Schaden

# richtung = normalisierter Vektor vom Angreifer zum Spieler
func schaden_erhalten(menge: float, angreifer: Node = null,
		richtung: Vector3 = Vector3.ZERO) -> void:
	if ist_tot:
		return

	_kampf_timer = kampf_dauer

	# --- Perfekter Block: kein Schaden, Gegner wird geöffnet ---
	if ist_am_blocken and _von_vorne(richtung) and _block_seit <= parry_fenster:
		_parry(angreifer)
		return

	var final: float = menge

	if ist_am_blocken and _von_vorne(richtung):
		if ausdauer >= kosten_block:
			_verbrauche(kosten_block)
			final = menge * (1.0 - block_reduktion)
			geblockt.emit(final)
		else:
			# Deckung gebrochen
			_verbrauche(ausdauer)
			ist_am_blocken = false
			_betaeuben()
			final = menge * 0.5
			deckung_gebrochen.emit()
	else:
		getroffen.emit(menge)

	leben = maxf(leben - final, 0.0)
	if leben <= 0.0:
		_sterben()


func _parry(angreifer: Node) -> void:
	ausdauer = clampf(ausdauer + parry_ausdauer_bonus, 0.0, max_ausdauer)
	_block_seit = 999.0        # nicht zweimal im selben Blockdruck parieren
	perfekt_geblockt.emit()
	if angreifer != null and angreifer.has_method("schwachstelle_oeffnen"):
		angreifer.schwachstelle_oeffnen(schwachstelle_dauer)
		print("Perfekter Block! Gegner ist offen – jetzt zuschlagen.")
	else:
		print("Perfekter Block!")


func _von_vorne(richtung: Vector3) -> bool:
	if richtung.length_squared() < 0.001:
		return true
	var blick: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, _blick_yaw())
	var flach: Vector3 = Vector3(richtung.x, 0.0, richtung.z).normalized()
	return blick.dot(-flach) >= cos(deg_to_rad(block_winkel * 0.5))


func _betaeuben() -> void:
	ist_betaeubt = true
	_betaeubung_timer = betaeubung_dauer
	_beende_schlag()


func _sterben() -> void:
	ist_tot = true
	ist_am_blocken = false
	ist_betaeubt = false
	_offen_timer = 0.0
	_beende_schlag()
	_tot_timer = tot_dauer
	print("Spieler gestorben – Wiederbelebung in ", tot_dauer, " s")


func _wiederbeleben() -> void:
	ist_tot = false
	ist_erschoepft = false
	leben = max_leben
	ausdauer = max_ausdauer
	_kampf_timer = 0.0
	if _player.has_method("respawn"):
		_player.respawn()


# ---------------------------------------------------------------- Ausdauer

func _verbrauche(menge: float, kampf_ausloesen_dabei: bool = true) -> void:
	ausdauer = clampf(ausdauer - menge, 0.0, max_ausdauer)
	_regen_timer = regen_pause
	if kampf_ausloesen_dabei:
		_kampf_timer = kampf_dauer
	if ausdauer <= 0.0:
		ist_erschoepft = true
		ist_am_blocken = false


func _regen_update(delta: float) -> void:
	if _regen_timer > 0.0:
		_regen_timer -= delta
		return

	var rate: float = ausdauer_regen
	if not im_kampf():
		rate *= regen_bonus_ausserhalb

	ausdauer = clampf(ausdauer + rate * delta, 0.0, max_ausdauer)

	if ist_erschoepft and ausdauer >= max_ausdauer * erschoepft_schwelle:
		ist_erschoepft = false


func _timer_update(delta: float) -> void:
	_kampf_timer = maxf(_kampf_timer - delta, 0.0)
	_offen_timer = maxf(_offen_timer - delta, 0.0)

	if _betaeubung_timer > 0.0:
		_betaeubung_timer -= delta
		if _betaeubung_timer <= 0.0:
			ist_betaeubt = false

	if ist_tot:
		_tot_timer -= delta
		if _tot_timer <= 0.0:
			_wiederbeleben()
