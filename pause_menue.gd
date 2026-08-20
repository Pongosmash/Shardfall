extends CanvasLayer
##
## Pausenmenue fuer Shardfall.
##
## Enthaelt: Fortsetzen | Optionen (Audio, Video, Tastenbelegung) | Verlassen
##
## Die gesamte Oberflaeche wird im Code gebaut. Grund: die Zeilen der
## Tastenbelegung muessen ohnehin zur Laufzeit aus dem InputMap erzeugt
## werden - und so musst du im Editor nur einen einzigen Node anlegen.
##
## Einbau:
##   1. In deiner Welt-/Hauptszene: Node hinzufuegen -> CanvasLayer
##   2. Umbenennen in "PauseMenue", dieses Skript anhaengen
##   3. Fertig. ESC oeffnet/schliesst das Menue.
##
## Voraussetzung: Autoload "Einstellungen" (einstellungen.gd) ist registriert.
##

# --- Aussehen (hier zentral anpassen) ------------------------------------
const FARBE_HINTERGRUND := Color(0.0, 0.0, 0.0, 0.62)
const FARBE_PANEL := Color(0.07, 0.08, 0.11, 0.97)
const FARBE_RAND := Color(0.26, 0.28, 0.35, 1.0)
const FARBE_AKZENT := Color(0.98, 0.78, 0.35, 1.0)
const FARBE_TEXT := Color(0.88, 0.89, 0.92, 1.0)

const BREITE_BESCHRIFTUNG := 240
const BREITE_PANEL_OPTIONEN := Vector2(760, 560)

# --- Verhalten -----------------------------------------------------------
## Soll das Menue den Spielbaum pausieren?
@export var spiel_pausieren := true
## Maus nach dem Schliessen wieder einfangen? (Fuer deine Kamerasteuerung)
@export var maus_wieder_einfangen := true

signal geoeffnet
signal geschlossen

# --- Interner Zustand ----------------------------------------------------
var _offen := false
var _warte_aktion := ""
var _warte_knopf: Button = null

# --- Node-Referenzen (im Code erzeugt) -----------------------------------
var _wurzel: Control
var _seite_haupt: Control
var _seite_optionen: Control
var _knopf_fortsetzen: Button
var _knopf_optionen_zurueck: Button
var _dialog_verlassen: ConfirmationDialog

var _regler_master: HSlider
var _regler_musik: HSlider
var _regler_sfx: HSlider

var _wahl_fenstermodus: OptionButton
var _schalter_vsync: CheckButton
var _wahl_fps: OptionButton
var _regler_aufloesung: HSlider
var _regler_sichtfeld: HSlider

var _regler_maus: HSlider
var _schalter_y: CheckButton
var _tasten_zeilen := {}   ## aktion -> Button

const FPS_WERTE := [0, 30, 60, 75, 120, 144, 240]


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_bauen()
	_wurzel.visible = false


# =========================================================================
#  Oeffnen / Schliessen
# =========================================================================

func oeffnen() -> void:
	if _offen:
		return
	_offen = true
	_werte_aus_einstellungen_uebernehmen()
	_wurzel.visible = true
	_seite_haupt.visible = true
	_seite_optionen.visible = false
	if spiel_pausieren:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_knopf_fortsetzen.grab_focus()
	geoeffnet.emit()


func schliessen() -> void:
	if not _offen:
		return
	_belegung_abbrechen()
	_offen = false
	_wurzel.visible = false
	if spiel_pausieren:
		get_tree().paused = false
	if maus_wieder_einfangen:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Einstellungen.speichern()
	geschlossen.emit()


func umschalten() -> void:
	if _offen:
		schliessen()
	else:
		oeffnen()


func ist_offen() -> bool:
	return _offen


# =========================================================================
#  Eingabe
# =========================================================================

## Faengt die Taste ab, waehrend auf eine neue Belegung gewartet wird.
func _input(ereignis: InputEvent) -> void:
	if _warte_aktion == "":
		return

	if ereignis is InputEventKey and ereignis.pressed and not ereignis.echo:
		if ereignis.keycode == KEY_ESCAPE:
			_belegung_abbrechen()
		else:
			var neu := InputEventKey.new()
			neu.physical_keycode = ereignis.physical_keycode if ereignis.physical_keycode != 0 else ereignis.keycode
			Einstellungen.setze_taste(_warte_aktion, neu)
			_belegung_beenden()
		get_viewport().set_input_as_handled()

	elif ereignis is InputEventMouseButton and ereignis.pressed:
		var neu_m := InputEventMouseButton.new()
		neu_m.button_index = ereignis.button_index
		Einstellungen.setze_taste(_warte_aktion, neu_m)
		_belegung_beenden()
		get_viewport().set_input_as_handled()

	elif ereignis is InputEventJoypadButton and ereignis.pressed:
		var neu_p := InputEventJoypadButton.new()
		neu_p.button_index = ereignis.button_index
		Einstellungen.setze_taste(_warte_aktion, neu_p)
		_belegung_beenden()
		get_viewport().set_input_as_handled()


func _unhandled_input(ereignis: InputEvent) -> void:
	if _warte_aktion != "":
		return
	if ereignis.is_action_pressed("ui_cancel"):
		if _offen:
			if _seite_optionen.visible:
				_optionen_schliessen()
			else:
				schliessen()
		else:
			oeffnen()
		get_viewport().set_input_as_handled()


# =========================================================================
#  Aufbau der Oberflaeche
# =========================================================================

func _ui_bauen() -> void:
	_wurzel = Control.new()
	_wurzel.name = "Wurzel"
	_wurzel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wurzel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_wurzel)

	var abdunkeln := ColorRect.new()
	abdunkeln.color = FARBE_HINTERGRUND
	abdunkeln.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	abdunkeln.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wurzel.add_child(abdunkeln)

	_seite_haupt_bauen()
	_seite_optionen_bauen()

	_dialog_verlassen = ConfirmationDialog.new()
	_dialog_verlassen.title = "Shardfall verlassen"
	_dialog_verlassen.dialog_text = "Spiel wirklich beenden?\nNicht gespeicherter Fortschritt geht verloren."
	_dialog_verlassen.ok_button_text = "Beenden"
	_dialog_verlassen.get_cancel_button().text = "Abbrechen"
	_dialog_verlassen.confirmed.connect(_spiel_beenden)
	_wurzel.add_child(_dialog_verlassen)


func _seite_haupt_bauen() -> void:
	_seite_haupt = _mittiges_panel(_wurzel)
	var inhalt := _seite_haupt.get_meta("inhalt") as VBoxContainer

	inhalt.add_child(_titel("SHARDFALL", 34))
	inhalt.add_child(_abstand(14))

	_knopf_fortsetzen = _knopf("Fortsetzen")
	_knopf_fortsetzen.pressed.connect(schliessen)
	inhalt.add_child(_knopf_fortsetzen)

	var k_opt := _knopf("Optionen")
	k_opt.pressed.connect(_optionen_oeffnen)
	inhalt.add_child(k_opt)

	inhalt.add_child(_abstand(10))

	var k_ende := _knopf("Spiel verlassen")
	k_ende.pressed.connect(func(): _dialog_verlassen.popup_centered())
	inhalt.add_child(k_ende)


func _seite_optionen_bauen() -> void:
	_seite_optionen = _mittiges_panel(_wurzel)
	var inhalt := _seite_optionen.get_meta("inhalt") as VBoxContainer
	inhalt.custom_minimum_size = BREITE_PANEL_OPTIONEN

	inhalt.add_child(_titel("Optionen", 26))
	inhalt.add_child(_abstand(8))

	var reiter := TabContainer.new()
	reiter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reiter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inhalt.add_child(reiter)

	reiter.add_child(_reiter_audio())
	reiter.add_child(_reiter_video())
	reiter.add_child(_reiter_steuerung())

	inhalt.add_child(_abstand(10))

	var leiste := HBoxContainer.new()
	leiste.add_theme_constant_override("separation", 12)
	inhalt.add_child(leiste)

	var k_std := _knopf("Standardwerte")
	k_std.custom_minimum_size = Vector2(200, 42)
	k_std.pressed.connect(func():
		Einstellungen.auf_standard_zuruecksetzen()
		_werte_aus_einstellungen_uebernehmen()
	)
	leiste.add_child(k_std)

	var fueller := Control.new()
	fueller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leiste.add_child(fueller)

	_knopf_optionen_zurueck = _knopf("Zurück")
	_knopf_optionen_zurueck.custom_minimum_size = Vector2(200, 42)
	_knopf_optionen_zurueck.pressed.connect(_optionen_schliessen)
	leiste.add_child(_knopf_optionen_zurueck)


# --- Reiter: Audio -------------------------------------------------------

func _reiter_audio() -> Control:
	var seite := _reiter_seite("Audio")
	var box := seite.get_meta("box") as VBoxContainer

	_regler_master = _regler_zeile(box, "Gesamtlautstärke", 0.0, 1.0, 0.01,
		func(w: float):
			Einstellungen.master_lautstaerke = w
			Einstellungen._audio_anwenden()
	)
	_regler_musik = _regler_zeile(box, "Musik", 0.0, 1.0, 0.01,
		func(w: float):
			Einstellungen.musik_lautstaerke = w
			Einstellungen._audio_anwenden()
	)
	_regler_sfx = _regler_zeile(box, "Effekte", 0.0, 1.0, 0.01,
		func(w: float):
			Einstellungen.sfx_lautstaerke = w
			Einstellungen._audio_anwenden()
	)

	box.add_child(_abstand(12))
	box.add_child(_hinweis("Musik und Effekte brauchen die Audio-Busse \"Musik\" und \"SFX\"."))
	return seite


# --- Reiter: Video -------------------------------------------------------

func _reiter_video() -> Control:
	var seite := _reiter_seite("Video")
	var box := seite.get_meta("box") as VBoxContainer

	_wahl_fenstermodus = OptionButton.new()
	_wahl_fenstermodus.add_item("Fenster")
	_wahl_fenstermodus.add_item("Vollbild (randlos)")
	_wahl_fenstermodus.add_item("Vollbild (exklusiv)")
	_wahl_fenstermodus.item_selected.connect(func(idx: int):
		Einstellungen.fenstermodus = idx
		Einstellungen._video_anwenden()
	)
	_zeile(box, "Anzeigemodus", _wahl_fenstermodus)

	_schalter_vsync = CheckButton.new()
	_schalter_vsync.toggled.connect(func(an: bool):
		Einstellungen.vsync = an
		Einstellungen._video_anwenden()
	)
	_zeile(box, "V-Sync", _schalter_vsync)

	_wahl_fps = OptionButton.new()
	for w in FPS_WERTE:
		_wahl_fps.add_item("Unbegrenzt" if w == 0 else str(w))
	_wahl_fps.item_selected.connect(func(idx: int):
		Einstellungen.max_fps = FPS_WERTE[idx]
		Einstellungen._video_anwenden()
	)
	_zeile(box, "Bildratenbegrenzung", _wahl_fps)

	_regler_aufloesung = _regler_zeile(box, "3D-Auflösung", 0.5, 1.0, 0.05,
		func(w: float):
			Einstellungen.aufloesung_3d = w
			Einstellungen._video_anwenden(),
		true
	)

	_regler_sichtfeld = _regler_zeile(box, "Sichtfeld", 60.0, 110.0, 1.0,
		func(w: float):
			Einstellungen.sichtfeld = w
			Einstellungen.video_geaendert.emit(),
		false, "%d°"
	)

	box.add_child(_abstand(12))
	box.add_child(_hinweis("Eine 3D-Auflösung unter 100 % kostet Schärfe, bringt aber am meisten FPS."))
	return seite


# --- Reiter: Steuerung ---------------------------------------------------

func _reiter_steuerung() -> Control:
	var seite := _reiter_seite("Steuerung")
	var box := seite.get_meta("box") as VBoxContainer

	_regler_maus = _regler_zeile(box, "Maussensitivität", 0.0005, 0.01, 0.0005,
		func(w: float):
			Einstellungen.maussensitivitaet = w
			Einstellungen.spiel_geaendert.emit(),
		false, "%.4f"
	)

	_schalter_y = CheckButton.new()
	_schalter_y.toggled.connect(func(an: bool):
		Einstellungen.y_invertieren = an
		Einstellungen.spiel_geaendert.emit()
	)
	_zeile(box, "Y-Achse invertieren", _schalter_y)

	box.add_child(_abstand(10))
	box.add_child(_titel("Tastenbelegung", 18))
	box.add_child(_abstand(4))

	var rollen := ScrollContainer.new()
	rollen.custom_minimum_size = Vector2(0, 240)
	rollen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rollen.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(rollen)

	var liste := VBoxContainer.new()
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	liste.add_theme_constant_override("separation", 4)
	rollen.add_child(liste)

	for aktion in Einstellungen.belegbare_aktionen():
		liste.add_child(_tasten_zeile(aktion))

	if _tasten_zeilen.is_empty():
		liste.add_child(_hinweis("Keine belegbaren Aktionen gefunden. Lege sie unter Projekt -> Projekteinstellungen -> Eingabekarte an."))

	return seite


func _tasten_zeile(aktion: String) -> Control:
	var reihe := HBoxContainer.new()
	reihe.add_theme_constant_override("separation", 10)

	var name_label := Label.new()
	name_label.text = Einstellungen.anzeige_name(aktion)
	name_label.custom_minimum_size = Vector2(BREITE_BESCHRIFTUNG, 0)
	name_label.add_theme_color_override("font_color", FARBE_TEXT)
	reihe.add_child(name_label)

	var knopf := Button.new()
	knopf.text = Einstellungen.belegungs_text(aktion)
	knopf.custom_minimum_size = Vector2(180, 34)
	knopf.pressed.connect(func(): _belegung_starten(aktion, knopf))
	reihe.add_child(knopf)
	_tasten_zeilen[aktion] = knopf

	var zurueck := Button.new()
	zurueck.text = "↺"
	zurueck.custom_minimum_size = Vector2(40, 34)
	zurueck.tooltip_text = "Auf Standard zurücksetzen"
	zurueck.pressed.connect(func():
		Einstellungen.taste_zuruecksetzen(aktion)
		knopf.text = Einstellungen.belegungs_text(aktion)
	)
	reihe.add_child(zurueck)

	return reihe


func _belegung_starten(aktion: String, knopf: Button) -> void:
	if _warte_aktion != "":
		_belegung_abbrechen()
	_warte_aktion = aktion
	_warte_knopf = knopf
	knopf.text = "Taste drücken … (ESC = Abbruch)"
	knopf.add_theme_color_override("font_color", FARBE_AKZENT)


func _belegung_beenden() -> void:
	if _warte_knopf:
		_warte_knopf.remove_theme_color_override("font_color")
		_warte_knopf.text = Einstellungen.belegungs_text(_warte_aktion)
	_warte_aktion = ""
	_warte_knopf = null


func _belegung_abbrechen() -> void:
	if _warte_aktion == "":
		return
	_belegung_beenden()


# =========================================================================
#  Seitenwechsel
# =========================================================================

func _optionen_oeffnen() -> void:
	_seite_haupt.visible = false
	_seite_optionen.visible = true
	_werte_aus_einstellungen_uebernehmen()
	_knopf_optionen_zurueck.grab_focus()


func _optionen_schliessen() -> void:
	_belegung_abbrechen()
	Einstellungen.speichern()
	_seite_optionen.visible = false
	_seite_haupt.visible = true
	_knopf_fortsetzen.grab_focus()


func _spiel_beenden() -> void:
	Einstellungen.speichern()
	get_tree().quit()


func _werte_aus_einstellungen_uebernehmen() -> void:
	if _regler_master:
		_regler_master.set_value_no_signal(Einstellungen.master_lautstaerke)
		_regler_musik.set_value_no_signal(Einstellungen.musik_lautstaerke)
		_regler_sfx.set_value_no_signal(Einstellungen.sfx_lautstaerke)
	if _wahl_fenstermodus:
		_wahl_fenstermodus.selected = Einstellungen.fenstermodus
		_schalter_vsync.set_pressed_no_signal(Einstellungen.vsync)
		var idx := FPS_WERTE.find(Einstellungen.max_fps)
		_wahl_fps.selected = idx if idx >= 0 else 0
		_regler_aufloesung.set_value_no_signal(Einstellungen.aufloesung_3d)
		_regler_sichtfeld.set_value_no_signal(Einstellungen.sichtfeld)
	if _regler_maus:
		_regler_maus.set_value_no_signal(Einstellungen.maussensitivitaet)
		_schalter_y.set_pressed_no_signal(Einstellungen.y_invertieren)
	for aktion in _tasten_zeilen.keys():
		(_tasten_zeilen[aktion] as Button).text = Einstellungen.belegungs_text(aktion)
	# Reglerbeschriftungen aktualisieren
	for r in [_regler_master, _regler_musik, _regler_sfx, _regler_aufloesung, _regler_sichtfeld, _regler_maus]:
		if r and r.has_meta("wert_label"):
			(r.get_meta("wert_label") as Label).text = _wert_text(r)


# =========================================================================
#  Kleine UI-Bausteine
# =========================================================================

func _mittiges_panel(eltern: Node) -> Control:
	var mitte := CenterContainer.new()
	mitte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mitte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eltern.add_child(mitte)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_stil())
	mitte.add_child(panel)

	var rand := MarginContainer.new()
	rand.add_theme_constant_override("margin_left", 28)
	rand.add_theme_constant_override("margin_right", 28)
	rand.add_theme_constant_override("margin_top", 24)
	rand.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(rand)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(360, 0)
	rand.add_child(box)

	mitte.set_meta("inhalt", box)
	return mitte


func _panel_stil() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = FARBE_PANEL
	s.border_color = FARBE_RAND
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	return s


func _reiter_seite(titel: String) -> Control:
	var rand := MarginContainer.new()
	rand.name = titel
	rand.add_theme_constant_override("margin_left", 18)
	rand.add_theme_constant_override("margin_right", 18)
	rand.add_theme_constant_override("margin_top", 16)
	rand.add_theme_constant_override("margin_bottom", 16)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rand.add_child(box)

	rand.set_meta("box", box)
	return rand


func _titel(text: String, groesse: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", FARBE_AKZENT)
	return l


func _hinweis(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(FARBE_TEXT, 0.55))
	return l


func _abstand(hoehe: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, hoehe)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _knopf(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 46)
	b.add_theme_font_size_override("font_size", 18)
	return b


func _zeile(eltern: VBoxContainer, beschriftung: String, steuerung: Control) -> void:
	var reihe := HBoxContainer.new()
	reihe.add_theme_constant_override("separation", 12)

	var l := Label.new()
	l.text = beschriftung
	l.custom_minimum_size = Vector2(BREITE_BESCHRIFTUNG, 0)
	l.add_theme_color_override("font_color", FARBE_TEXT)
	reihe.add_child(l)

	steuerung.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reihe.add_child(steuerung)

	eltern.add_child(reihe)


## Erzeugt eine Zeile mit Schieberegler und Wertanzeige.
func _regler_zeile(eltern: VBoxContainer, beschriftung: String, minimum: float,
		maximum: float, schritt: float, rueckruf: Callable,
		als_prozent := true, format := "") -> HSlider:
	var reihe := HBoxContainer.new()
	reihe.add_theme_constant_override("separation", 12)

	var l := Label.new()
	l.text = beschriftung
	l.custom_minimum_size = Vector2(BREITE_BESCHRIFTUNG, 0)
	l.add_theme_color_override("font_color", FARBE_TEXT)
	reihe.add_child(l)

	var regler := HSlider.new()
	regler.min_value = minimum
	regler.max_value = maximum
	regler.step = schritt
	regler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regler.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reihe.add_child(regler)

	var wert_label := Label.new()
	wert_label.custom_minimum_size = Vector2(80, 0)
	wert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wert_label.add_theme_color_override("font_color", FARBE_AKZENT)
	reihe.add_child(wert_label)

	regler.set_meta("wert_label", wert_label)
	regler.set_meta("prozent", als_prozent or (format == "" and maximum <= 1.0))
	regler.set_meta("format", format)

	regler.value_changed.connect(func(w: float):
		wert_label.text = _wert_text(regler)
		rueckruf.call(w)
	)

	eltern.add_child(reihe)
	wert_label.text = _wert_text(regler)
	return regler


func _wert_text(regler: HSlider) -> String:
	var format: String = regler.get_meta("format", "")
	if format != "":
		return format % regler.value
	if bool(regler.get_meta("prozent", false)):
		return "%d %%" % roundi(regler.value * 100.0)
	return str(regler.value)
