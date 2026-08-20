extends Node
##
## Autoload-Singleton "Einstellungen"
##
## Haelt alle Spieleroptionen, speichert sie nach user://einstellungen.cfg
## und wendet sie auf AudioServer, DisplayServer, Engine und InputMap an.
##
## Registrierung: Projekt -> Projekteinstellungen -> Autoload
##   Pfad: res://autoload/einstellungen.gd   Name: Einstellungen
##
## Andere Skripte lesen einfach z.B. Einstellungen.maussensitivitaet
## oder verbinden sich mit den Signalen unten.
##

const PFAD := "user://einstellungen.cfg"

signal audio_geaendert
signal video_geaendert
signal spiel_geaendert   ## Sichtfeld / Maussensitivitaet / Y-Invertierung
signal tasten_geaendert

enum Fenstermodus { FENSTER, RANDLOS, EXKLUSIV }

## Anzeigenamen fuer belegbare Aktionen.
## Aktionen, die es im InputMap nicht gibt, werden uebersprungen.
## Aktionen, die hier fehlen, aber im InputMap existieren, werden
## automatisch hinten angehaengt (mit ihrem Rohnamen).
## -> Passe die Schluessel an deine echten Aktionsnamen an.
const AKTIONS_NAMEN := {
	"vorwaerts": "Vorwärts",
	"rueckwaerts": "Rückwärts",
	"links": "Links",
	"rechts": "Rechts",
	"springen": "Springen",
	"sprinten": "Sprinten",
	"schleichen": "Schleichen",
	"ducken": "Ducken",
	"frei_umsehen": "Frei umsehen",
	"angriff": "Angriff",
	"blocken": "Blocken",
	"interagieren": "Interagieren",
	"inventar": "Inventar",
}

# --- Audio (linear, 0.0 - 1.0) -------------------------------------------
var master_lautstaerke := 1.0
var musik_lautstaerke := 0.8
var sfx_lautstaerke := 1.0

# --- Video ---------------------------------------------------------------
var fenstermodus: int = Fenstermodus.FENSTER
var vsync := true
var max_fps := 0            ## 0 = unbegrenzt
var aufloesung_3d := 1.0    ## 0.5 - 1.0, skaliert nur das 3D-Bild
var sichtfeld := 75.0       ## Grad, wird per Signal an die Kamera gemeldet

# --- Spiel / Steuerung ---------------------------------------------------
var maussensitivitaet := 0.0025
var y_invertieren := false

## Merkt sich die im Editor gesetzte Belegung, damit "Zurücksetzen" geht.
var _standard_ereignisse := {}


func _ready() -> void:
	# Muss auch waehrend get_tree().paused == true weiterlaufen.
	process_mode = Node.PROCESS_MODE_ALWAYS

	for aktion in InputMap.get_actions():
		_standard_ereignisse[String(aktion)] = InputMap.action_get_events(aktion)

	laden()
	alles_anwenden()


# =========================================================================
#  Anwenden
# =========================================================================

func alles_anwenden() -> void:
	_audio_anwenden()
	_video_anwenden()
	spiel_geaendert.emit()


func _audio_anwenden() -> void:
	_bus_setzen("Master", master_lautstaerke)
	_bus_setzen("Musik", musik_lautstaerke)
	_bus_setzen("SFX", sfx_lautstaerke)
	audio_geaendert.emit()


func _bus_setzen(bus_name: String, wert: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		# Bus existiert nicht -> still ignorieren, damit das Spiel laeuft.
		return
	wert = clampf(wert, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, wert <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(wert, 0.0001)))


func _video_anwenden() -> void:
	match fenstermodus:
		Fenstermodus.FENSTER:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		Fenstermodus.RANDLOS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		Fenstermodus.EXKLUSIV:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)

	Engine.max_fps = max_fps

	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = clampf(aufloesung_3d, 0.25, 1.0)

	video_geaendert.emit()


# =========================================================================
#  Tastenbelegung
# =========================================================================

## Liefert alle Aktionen, die im Menue belegbar sein sollen.
func belegbare_aktionen() -> Array:
	var liste := []
	for aktion in AKTIONS_NAMEN.keys():
		if InputMap.has_action(aktion):
			liste.append(String(aktion))
	for aktion in InputMap.get_actions():
		var s := String(aktion)
		if s.begins_with("ui_"):
			continue
		if not liste.has(s):
			liste.append(s)
	return liste


func anzeige_name(aktion: String) -> String:
	if AKTIONS_NAMEN.has(aktion):
		return AKTIONS_NAMEN[aktion]
	return aktion.replace("_", " ").capitalize()


## Ersetzt die Tastatur-/Maus-Belegung einer Aktion. Gamepad bleibt erhalten.
func setze_taste(aktion: String, ereignis: InputEvent) -> void:
	if not InputMap.has_action(aktion) or ereignis == null:
		return
	for e in InputMap.action_get_events(aktion):
		if e is InputEventKey or e is InputEventMouseButton:
			InputMap.action_erase_event(aktion, e)
	InputMap.action_add_event(aktion, ereignis)
	tasten_geaendert.emit()


func taste_zuruecksetzen(aktion: String) -> void:
	if not _standard_ereignisse.has(aktion):
		return
	InputMap.action_erase_events(aktion)
	for e in _standard_ereignisse[aktion]:
		InputMap.action_add_event(aktion, e)
	tasten_geaendert.emit()


func alle_tasten_zuruecksetzen() -> void:
	for aktion in belegbare_aktionen():
		taste_zuruecksetzen(aktion)


## Lesbarer Text der aktuellen Belegung, z.B. "Leertaste" oder "Maus Links".
func belegungs_text(aktion: String) -> String:
	if not InputMap.has_action(aktion):
		return "-"
	for e in InputMap.action_get_events(aktion):
		var t := ereignis_text(e)
		if t != "":
			return t
	return "-"


func ereignis_text(ereignis: InputEvent) -> String:
	if ereignis is InputEventKey:
		var k := ereignis as InputEventKey
		if k.physical_keycode != 0:
			var kc := DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
			if kc != 0:
				return OS.get_keycode_string(kc)
			return OS.get_keycode_string(k.physical_keycode)
		return OS.get_keycode_string(k.keycode)

	if ereignis is InputEventMouseButton:
		match (ereignis as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "Maus Links"
			MOUSE_BUTTON_RIGHT: return "Maus Rechts"
			MOUSE_BUTTON_MIDDLE: return "Maus Mitte"
			MOUSE_BUTTON_WHEEL_UP: return "Mausrad hoch"
			MOUSE_BUTTON_WHEEL_DOWN: return "Mausrad runter"
			_: return "Maus %d" % (ereignis as InputEventMouseButton).button_index

	if ereignis is InputEventJoypadButton:
		return "Gamepad %d" % (ereignis as InputEventJoypadButton).button_index

	return ""


# =========================================================================
#  Speichern / Laden
# =========================================================================

func speichern() -> void:
	var cfg := ConfigFile.new()

	cfg.set_value("audio", "master", master_lautstaerke)
	cfg.set_value("audio", "musik", musik_lautstaerke)
	cfg.set_value("audio", "sfx", sfx_lautstaerke)

	cfg.set_value("video", "fenstermodus", fenstermodus)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "max_fps", max_fps)
	cfg.set_value("video", "aufloesung_3d", aufloesung_3d)
	cfg.set_value("video", "sichtfeld", sichtfeld)

	cfg.set_value("spiel", "maussensitivitaet", maussensitivitaet)
	cfg.set_value("spiel", "y_invertieren", y_invertieren)

	for aktion in belegbare_aktionen():
		var texte := PackedStringArray()
		for e in InputMap.action_get_events(aktion):
			var t := _ereignis_zu_text(e)
			if t != "":
				texte.append(t)
		cfg.set_value("tasten", aktion, texte)

	var fehler := cfg.save(PFAD)
	if fehler != OK:
		push_warning("Einstellungen konnten nicht gespeichert werden (Fehler %d)." % fehler)


func laden() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PFAD) != OK:
		return   # Erster Start -> Standardwerte behalten.

	master_lautstaerke = cfg.get_value("audio", "master", master_lautstaerke)
	musik_lautstaerke = cfg.get_value("audio", "musik", musik_lautstaerke)
	sfx_lautstaerke = cfg.get_value("audio", "sfx", sfx_lautstaerke)

	fenstermodus = cfg.get_value("video", "fenstermodus", fenstermodus)
	vsync = cfg.get_value("video", "vsync", vsync)
	max_fps = cfg.get_value("video", "max_fps", max_fps)
	aufloesung_3d = cfg.get_value("video", "aufloesung_3d", aufloesung_3d)
	sichtfeld = cfg.get_value("video", "sichtfeld", sichtfeld)

	maussensitivitaet = cfg.get_value("spiel", "maussensitivitaet", maussensitivitaet)
	y_invertieren = cfg.get_value("spiel", "y_invertieren", y_invertieren)

	if cfg.has_section("tasten"):
		for aktion in cfg.get_section_keys("tasten"):
			if not InputMap.has_action(aktion):
				continue
			var texte: PackedStringArray = cfg.get_value("tasten", aktion, PackedStringArray())
			if texte.is_empty():
				continue
			InputMap.action_erase_events(aktion)
			for t in texte:
				var e := _text_zu_ereignis(t)
				if e != null:
					InputMap.action_add_event(aktion, e)
		tasten_geaendert.emit()


func auf_standard_zuruecksetzen() -> void:
	master_lautstaerke = 1.0
	musik_lautstaerke = 0.8
	sfx_lautstaerke = 1.0
	fenstermodus = Fenstermodus.FENSTER
	vsync = true
	max_fps = 0
	aufloesung_3d = 1.0
	sichtfeld = 75.0
	maussensitivitaet = 0.0025
	y_invertieren = false
	alle_tasten_zuruecksetzen()
	alles_anwenden()
	speichern()


# --- Serialisierung ------------------------------------------------------

func _ereignis_zu_text(e: InputEvent) -> String:
	if e is InputEventKey:
		var k := e as InputEventKey
		var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
		return "taste:%d" % code
	if e is InputEventMouseButton:
		return "maus:%d" % (e as InputEventMouseButton).button_index
	if e is InputEventJoypadButton:
		return "pad:%d" % (e as InputEventJoypadButton).button_index
	return ""


func _text_zu_ereignis(text: String) -> InputEvent:
	var teile := text.split(":")
	if teile.size() != 2:
		return null
	var wert := int(teile[1])
	match teile[0]:
		"taste":
			var k := InputEventKey.new()
			k.physical_keycode = wert
			return k
		"maus":
			var m := InputEventMouseButton.new()
			m.button_index = wert
			return m
		"pad":
			var p := InputEventJoypadButton.new()
			p.button_index = wert
			return p
	return null
