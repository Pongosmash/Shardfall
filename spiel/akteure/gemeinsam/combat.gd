class_name Combat
extends Node

# Kampfkomponente des Spielers.
# Hängt als Kindknoten "Combat" unter dem Player.
# Kümmert sich um Leben, Ausdauer, Angriffe, Blocken und perfektes Blocken.
#
# WAFFEN:
# Findet beim Start selbst den Geschwisterknoten "Ausruestung". Ist er da,
# kommen Timing, Schaden, Reichweite, Trefferwinkel, Kombolänge und
# Blockwerte aus den WaffenDaten der ausgerüsteten Waffe. Fehlt er, greifen
# die Exportwerte unten – das alte Faustverhalten läuft dann unverändert.
#
# Combat ist die einzige Quelle der Wahrheit für Timing und Schaden.
# Die Optik liegt vollständig in character_visual.gd und liest von hier
# 'angriff_fortschritt', 'hand_links', aktiver_stil() und schlag_marken().
# Ein zweiter Timer für die Animation würde vom Kampf-Timing abdriften und
# Treffer und sichtbaren Schlag entkoppeln.

signal getroffen(menge: float)             # Schaden ist durchgekommen
signal geblockt(menge: float)              # normal geblockt
signal perfekt_geblockt()                  # Parry gelungen
signal deckung_gebrochen()                 # Ausdauer reichte nicht

@export_group("Steuerung")
## AN (Vorgabe): liest Input.is_action_pressed("attack"/"block") wie bisher -
## das ist der Spieler. AUS: _eingabe() liest KEINE Eingaben mehr, eine KI
## loest Schlag/Block stattdessen ueber ki_angreifen()/ki_blocken() aus. Ohne
## dieses Feld wuerden ALLE Combat-Instanzen (Spieler und jeder NPC) auf
## denselben Tastendruck reagieren - Input ist ein globaler Zustand, keiner
## pro Knoten.
@export var von_spieler_gesteuert: bool = true

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
@export var kosten_angriff: float = 12.0          # Rückfall ohne Waffe
@export var kosten_block: float = 20.0            # Rückfall ohne Waffe
@export var kosten_sprint: float = 10.0           # pro Sekunde, nur im Kampf

@export_group("Angriff (Rückfallwerte ohne Ausrüstung)")
@export var reichweite: float = 2.4
@export var trefferwinkel: float = 110.0          # Kegel vor dem Spieler (Grad)
@export var hoehen_toleranz: float = 2.0          # max. Höhenunterschied zum Ziel
@export var schaden: float = 9.0
@export var schaden_finisher: float = 16.0        # letzter Schlag der Kombo
@export var ausholen: float = 0.12                # Sekunden bis zum Trefferfenster
@export var treffer_dauer: float = 0.06           # Länge des Trefferfensters
@export var erholung: float = 0.20                # Sekunden danach
@export var max_kombo: int = 3

@export_group("Waffen")
## Der letzte Schlag der Kombo trifft härter. Faktor auf den Waffenschaden.
@export var finisher_faktor: float = 1.75
## Trefferkegel je nach Angriffsstil: Stiche treffen schmal, Schwünge breit.
@export var winkel_je_stil: bool = true
## Name des Geschwisterknotens, der beim Start gesucht wird.
@export var name_ausruestung: String = "Ausruestung"

@export_group("Blocken (Rückfallwerte ohne Ausrüstung)")
@export var block_reduktion: float = 0.75         # 0.75 = 75 % weniger Schaden
@export var block_winkel: float = 140.0           # nur Treffer von vorne
@export var block_tempo: float = 0.45             # Tempofaktor beim Blocken
@export var betaeubung_dauer: float = 0.7         # nach gebrochener Deckung

@export_group("Perfekter Block")
@export var parry_fenster: float = 0.25           # Sekunden nach dem Drücken
@export var parry_ausdauer_bonus: float = 15.0    # Belohnung fürs Timing
@export var schwachstelle_dauer: float = 2.0      # wie lange der Gegner offen ist
@export var crit_faktor: float = 2.5              # Rückfall ohne Waffe

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
var hand_links: bool = false                      # welche Hand gerade schlägt
var angriff_fortschritt: float = 0.0              # 0..1 über den ganzen Schlag

# Komponente (kann null bleiben – dann greifen die Rückfallwerte)
var ausruestung: Ausruestung = null

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

# Werte des LAUFENDEN Schlages. Beim Start eingefroren, damit ein
# Waffenwechsel mitten im Schlag die Phasen nicht zerreißt.
var _waffe: WaffenDaten = null
var _dauer_ausholen: float = 0.12
var _dauer_treffer: float = 0.06
var _dauer_erholung: float = 0.20
var _reichweite_aktuell: float = 2.4
var _winkel_aktuell: float = 110.0
var _schaden_aktuell: float = 9.0
var _crit_aktuell: float = 2.5
var _kombo_max: int = 3


func _ready() -> void:
	_player = get_parent()
	if _player == null or not _player is Akteur:
		push_error("Combat: Elternknoten ist kein Akteur (Player oder NPC)!")
		set_process(false)
		return

	if not InputMap.has_action("attack"):
		push_error("Combat: Eingabeaktion 'attack' fehlt (Projekteinstellungen -> Eingabezuordnung)")
	if not InputMap.has_action("block"):
		push_error("Combat: Eingabeaktion 'block' fehlt (Projekteinstellungen -> Eingabezuordnung)")

	_komponenten_suchen()

	leben = max_leben
	ausdauer = max_ausdauer


# Sucht die Ausrüstung unter dem Player. owned = false, damit auch Knoten in
# instanzierten Unterszenen gefunden werden.
func _komponenten_suchen() -> void:
	var gefunden: Node = _player.find_child(name_ausruestung, true, false)
	if gefunden is Ausruestung:
		ausruestung = gefunden as Ausruestung
		ausruestung.waffe_gewechselt.connect(_auf_waffenwechsel)
	else:
		push_warning("Combat: Keine Ausrüstung ('%s') gefunden – Faust-Rückfallwerte aktiv."
				% name_ausruestung)


# Waffenwechsel bricht die laufende Kombo ab: Ein Zweihänder soll nicht
# mitten in einer Faustkombo weiterzählen.
func _auf_waffenwechsel(_daten: WaffenDaten) -> void:
	if _phase != Phase.KEINE:
		_beende_schlag()
	kombo_index = 0


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


## Die Waffe in der Schlaghand. Null, wenn keine Ausrüstung vorhanden ist.
func aktive_waffe() -> WaffenDaten:
	if ausruestung == null:
		return null
	return ausruestung.aktive_waffe()


## Womit gerade geblockt wird: Schild, Waffe oder null (kein Block möglich).
func aktive_blockwaffe() -> WaffenDaten:
	if ausruestung == null:
		return null
	return ausruestung.block_waffe()


## Angriffsstil des laufenden Schlages. Fällt auf FAUST zurück.
## character_visual.gd wählt darüber die Schlagpose.
func aktiver_stil() -> int:
	if _waffe != null:
		return _waffe.stil
	return WaffenDaten.Stil.FAUST


## Die zwei Marken im normierten Schlagverlauf (0..1):
##   x = Ende des Ausholens / Beginn des Trefferfensters
##   y = Ende des Trefferfensters / Beginn des Zurückholens
## Damit kann die Optik ihre Kurve exakt auf das Timing der Waffe legen,
## statt feste Werte zu raten.
func schlag_marken() -> Vector2:
	var gesamt: float = _dauer_ausholen + _dauer_treffer + _dauer_erholung
	if gesamt <= 0.0:
		return Vector2(0.30, 0.48)
	return Vector2(
		_dauer_ausholen / gesamt,
		(_dauer_ausholen + _dauer_treffer) / gesamt
	)


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
	if not von_spieler_gesteuert:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		ist_am_blocken = false
		_block_seit = 999.0
		return

	var moeglich: bool = not _player.is_swimming and not ist_betaeubt

	# --- Blocken (halten) ---
	# Ohne Ausrüstung immer erlaubt. Mit Ausrüstung nur, wenn Schild oder
	# Waffe blockfähig sind – ein Zweihänder mit kann_blocken = false
	# schaltet die Deckung damit komplett ab.
	var block_erlaubt: bool = ausruestung == null or aktive_blockwaffe() != null

	var will_blocken: bool = moeglich \
			and block_erlaubt \
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
	elif _phase == Phase.ERHOLUNG and kombo_index + 1 < _kombo_max:
		_kombo_puffer = true


# ---------------------------------------------------------------- KI-Eingabe

## Fuer KI-gesteuerte Akteure (von_spieler_gesteuert = false): loest einen
## Schlag aus, als haette jemand "attack" gedrueckt. Respektiert Ausdauer,
## Erschoepfung und laufende Kombo genauso wie ein echter Tastendruck - ruft
## intern dieselbe _starte_schlag()/_kombo_puffer-Logik.
func ki_angreifen() -> void:
	if von_spieler_gesteuert or ist_betaeubt or ist_tot or ist_am_blocken:
		return
	if _phase == Phase.KEINE:
		_starte_schlag(0)
	elif _phase == Phase.ERHOLUNG and kombo_index + 1 < _kombo_max:
		_kombo_puffer = true


## Fuer KI-gesteuerte Akteure: haelt oder loest die Blockhaltung, wie ein
## gehaltener Tastendruck. 'halten' pro Bild neu uebergeben, nicht einmalig.
func ki_blocken(halten: bool, delta: float) -> void:
	if von_spieler_gesteuert:
		return
	var moeglich: bool = not ist_betaeubt
	var block_erlaubt: bool = ausruestung == null or aktive_blockwaffe() != null
	var will_blocken: bool = halten and moeglich and block_erlaubt \
			and _phase == Phase.KEINE and not ist_erschoepft

	if will_blocken and not ist_am_blocken:
		_block_seit = 0.0
	elif will_blocken:
		_block_seit += delta
	else:
		_block_seit = 999.0

	ist_am_blocken = will_blocken
	if ist_am_blocken:
		_kampf_timer = kampf_dauer


# ---------------------------------------------------------------- Angriff

func _starte_schlag(index: int) -> void:
	var waffe: WaffenDaten = aktive_waffe()
	var kosten: float = waffe.ausdauer_kosten if waffe != null else kosten_angriff

	if ist_erschoepft or ausdauer < kosten:
		return

	_waffe = waffe
	_werte_uebernehmen(waffe)

	kombo_index = index

	# Nur Fäuste wechseln die Hand. Mit Waffe schlägt immer dieselbe Seite,
	# sonst würde das Schwert von einer leeren Hand geschwungen.
	if ausruestung == null or ausruestung.haende_wechseln_erlaubt():
		hand_links = not hand_links
	else:
		hand_links = false

	_phase = Phase.AUSHOLEN
	_phase_timer = _dauer_ausholen
	ist_am_angreifen = true
	_getroffen.clear()
	_verbrauche(kosten)


# Friert die Werte des Schlages ein. Ohne Waffe bleiben es die Exportwerte,
# das alte Faustverhalten also unverändert.
func _werte_uebernehmen(waffe: WaffenDaten) -> void:
	if waffe == null:
		_dauer_ausholen = ausholen
		_dauer_treffer = treffer_dauer
		_dauer_erholung = erholung
		_reichweite_aktuell = reichweite
		_winkel_aktuell = trefferwinkel
		_schaden_aktuell = schaden
		_crit_aktuell = crit_faktor
		_kombo_max = max_kombo
		return

	waffe.gepruefte_werte()

	# Phasenlängen direkt aus dem Waffen-Timing ableiten. Dadurch laufen
	# Pose und Trefferfenster garantiert synchron.
	var d: float = waffe.angriff_dauer
	_dauer_ausholen = d * waffe.treffer_start
	_dauer_treffer = d * (waffe.treffer_ende - waffe.treffer_start)
	_dauer_erholung = d * (1.0 - waffe.treffer_ende) + waffe.nachziehzeit

	_reichweite_aktuell = waffe.reichweite
	_winkel_aktuell = _stil_winkel(waffe.stil)
	_schaden_aktuell = waffe.schaden
	_crit_aktuell = waffe.kritisch_multiplikator
	_kombo_max = maxi(waffe.kombo_schritte, 1)


# Der Trefferkegel gehört zum Angriffsstil: Ein Stich erwischt genau das,
# worauf man zielt, ein schwerer Schwung räumt die halbe Umgebung ab.
func _stil_winkel(stil: int) -> float:
	if not winkel_je_stil:
		return trefferwinkel
	match stil:
		WaffenDaten.Stil.STICH:
			return 60.0
		WaffenDaten.Stil.HIEB:
			return 130.0
		WaffenDaten.Stil.SCHWUNG_SCHWER:
			return 150.0
		WaffenDaten.Stil.STANGE:
			return 50.0
	return trefferwinkel      # FAUST und alles Unbekannte


func _angriff_update(delta: float) -> void:
	if _phase == Phase.KEINE:
		angriff_fortschritt = 0.0
		return

	_phase_timer -= delta

	match _phase:
		Phase.AUSHOLEN:
			if _phase_timer <= 0.0:
				_phase = Phase.TREFFER
				_phase_timer = _dauer_treffer
		Phase.TREFFER:
			_treffer_pruefen()
			if _phase_timer <= 0.0:
				_phase = Phase.ERHOLUNG
				_phase_timer = _dauer_erholung
		Phase.ERHOLUNG:
			if _phase_timer <= 0.0:
				if _kombo_puffer and kombo_index + 1 < _kombo_max:
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
	_waffe = null


func _fortschritt() -> float:
	var gesamt: float = _dauer_ausholen + _dauer_treffer + _dauer_erholung
	if gesamt <= 0.0:
		return 0.0
	var v: float = 0.0
	match _phase:
		Phase.AUSHOLEN:
			v = _dauer_ausholen - _phase_timer
		Phase.TREFFER:
			v = _dauer_ausholen + (_dauer_treffer - _phase_timer)
		Phase.ERHOLUNG:
			v = _dauer_ausholen + _dauer_treffer + (_dauer_erholung - _phase_timer)
	return clampf(v / gesamt, 0.0, 1.0)


func _treffer_pruefen() -> void:
	var blick: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, _blick_yaw())
	var grenze: float = cos(deg_to_rad(_winkel_aktuell * 0.5))

	var basis: float = _schaden_aktuell
	if kombo_index >= _kombo_max - 1:
		basis = schaden_finisher if _waffe == null else _schaden_aktuell * finisher_faktor

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
		if dist > _reichweite_aktuell:
			continue
		if dist > 0.01 and blick.dot(zu_ziel / dist) < grenze:
			continue

		_getroffen.append(ziel)
		_kampf_timer = kampf_dauer

		# --- Schwachstelle ausnutzen? ---
		var menge: float = basis
		var kritisch: bool = ziel.has_method("ist_offen") and ziel.ist_offen()
		if kritisch:
			menge = basis * _crit_aktuell

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
		var schild: WaffenDaten = aktive_blockwaffe()
		var kosten: float = schild.block_ausdauer_kosten if schild != null else kosten_block
		var durchlass: float = schild.block_durchlass if schild != null else (1.0 - block_reduktion)

		if ausdauer >= kosten:
			_verbrauche(kosten)
			final = menge * durchlass
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
	# Die Meldung sagte bisher immer "Spieler", auch wenn ein NPC gestorben
	# ist - das hat beim Testen fuer Verwirrung gesorgt.
	if von_spieler_gesteuert:
		print("Spieler gestorben – Wiederbelebung in ", tot_dauer, " s")
	else:
		print(_player.name, " gestorben.")


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

	# Nur der Spieler wird automatisch wiederbelebt. Ein besiegter NPC bleibt
	# liegen - fuer ihn gibt es (noch) keine automatische Wiederbelebung,
	# sonst steht er nach 2 Sekunden einfach wieder auf und laeuft weiter.
	if ist_tot and von_spieler_gesteuert:
		_tot_timer -= delta
		if _tot_timer <= 0.0:
			_wiederbeleben()
