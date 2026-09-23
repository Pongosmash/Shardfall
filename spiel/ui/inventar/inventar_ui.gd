extends Node

# Baut die komplette Inventaroberfläche beim Start selbst auf – gleiche
# Bauweise wie hud.gd, es genügt ein einfacher Node in der Hauptszene.
#
# Aufteilung von links nach rechts:
#   1) Grundwerte (oben) und Item-Boni (unten)
#   2) Charaktervorschau mit Ausrüstungsslots links und rechts daneben
#   3) Inventarraster mit Suche und Filter
#
# Öffnen und schließen über die Eingabeaktion "inventory" (I), ESC schließt.

@export_group("Fenster")
@export var breite: float = 1000.0
@export var hoehe: float = 580.0
@export var spalten: int = 8              # Inventarplätze je Reihe
@export var feld_groesse: float = 52.0
@export var einblend_tempo: float = 16.0

@export_group("Farben")
@export var farbe_hintergrund: Color = Color(0.0, 0.0, 0.0, 0.55)
@export var farbe_fenster: Color = Color(0.10, 0.11, 0.13, 0.96)
@export var farbe_feld: Color = Color(0.17, 0.18, 0.21, 1.0)
@export var farbe_feld_hover: Color = Color(0.26, 0.28, 0.33, 1.0)
@export var farbe_feld_ziel: Color = Color(0.24, 0.42, 0.30, 1.0)
@export var farbe_panel: Color = Color(0.13, 0.14, 0.17, 1.0)
@export var farbe_text: Color = Color(0.88, 0.89, 0.92)
@export var farbe_text_schwach: Color = Color(0.58, 0.60, 0.66)
@export var farbe_bonus: Color = Color(0.45, 0.82, 0.42)
@export var farbe_malus: Color = Color(0.86, 0.42, 0.36)

@export_group("Vorschau")
@export var vorschau_groesse: Vector2 = Vector2(230.0, 330.0)
@export var vorschau_dreh_tempo: float = 0.01
@export var vorschau_auto_dreh: float = 0.25   # Bogenmaß pro Sekunde

var offen: bool = false

var _inventar: Inventar = null
var _spieler = null

var _layer: CanvasLayer
var _dunkel: ColorRect
var _fenster: PanelContainer
var _alpha: float = 0.0

var _felder: Array = []                   # SlotFeld je Inventarplatz
var _slot_felder: Dictionary = {}         # schluessel -> SlotFeld
var _grund_box: VBoxContainer
var _bonus_box: VBoxContainer
var _suche: LineEdit
var _filter: OptionButton
var _tooltip: PanelContainer
var _tooltip_text: RichTextLabel

var _viewport: SubViewport
var _figur: Node3D
var _figur_teile: Dictionary = {}         # name -> MeshInstance3D
var _zieht_vorschau: bool = false

const WERT_TITEL := {
	"leben": "Leben", "ausdauer": "Ausdauer", "schaden": "Schaden",
	"ruestung": "Rüstung", "tempo": "Tempo", "krit": "Krit-Chance",
}


# ---------------------------------------------------------------- Slotfeld

# Ein einzelnes Feld. Trägt die komplette Drag-and-Drop-Logik.
class SlotFeld extends Panel:
	var ui                                 # Rückverweis auf inventar_ui
	var index: int = -1                    # >= 0 -> Inventarplatz
	var schluessel: String = ""            # != "" -> Ausrüstungsslot
	var eintrag = null

	var _farbe: ColorRect
	var _kuerzel: Label
	var _menge: Label
	var _titel: Label

	func _bauen(ui_ref, groesse: float, titel: String = "") -> void:
		ui = ui_ref
		custom_minimum_size = Vector2(groesse, groesse)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_setze_stil(ui.farbe_feld)

		_farbe = ColorRect.new()
		_farbe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_farbe.anchor_right = 1.0
		_farbe.anchor_bottom = 1.0
		_farbe.offset_left = 6.0
		_farbe.offset_top = 6.0
		_farbe.offset_right = -6.0
		_farbe.offset_bottom = -6.0
		_farbe.color = Color.TRANSPARENT
		add_child(_farbe)

		_kuerzel = Label.new()
		_kuerzel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_kuerzel.anchor_right = 1.0
		_kuerzel.anchor_bottom = 1.0
		_kuerzel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_kuerzel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_kuerzel.add_theme_font_size_override("font_size", 15)
		_kuerzel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_kuerzel.add_theme_constant_override("outline_size", 4)
		add_child(_kuerzel)

		_menge = Label.new()
		_menge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menge.anchor_left = 0.0
		_menge.anchor_top = 0.0
		_menge.anchor_right = 1.0
		_menge.anchor_bottom = 1.0
		_menge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_menge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_menge.add_theme_font_size_override("font_size", 12)
		_menge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_menge.add_theme_constant_override("outline_size", 4)
		add_child(_menge)

		if titel != "":
			_titel = Label.new()
			_titel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_titel.text = titel
			_titel.anchor_right = 1.0
			_titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_titel.offset_top = -16.0
			_titel.add_theme_font_size_override("font_size", 10)
			_titel.add_theme_color_override("font_color", ui.farbe_text_schwach)
			add_child(_titel)

		mouse_entered.connect(_auf_hover.bind(true))
		mouse_exited.connect(_auf_hover.bind(false))

	func _setze_stil(farbe: Color) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = farbe
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0, 0, 0, 0.5)
		add_theme_stylebox_override("panel", sb)

	func aktualisiere(neu) -> void:
		eintrag = neu
		if eintrag == null:
			_farbe.color = Color.TRANSPARENT
			_kuerzel.text = ""
			_menge.text = ""
			return
		var daten: ItemDaten = eintrag["daten"]
		_farbe.color = daten.modell_farbe
		_kuerzel.text = daten.anzeige_name.substr(0, 2)
		_kuerzel.add_theme_color_override("font_color", daten.farbe())
		_menge.text = str(eintrag["menge"]) if eintrag["menge"] > 1 else ""

	func _auf_hover(drin: bool) -> void:
		_setze_stil(ui.farbe_feld_hover if drin else ui.farbe_feld)
		if drin and eintrag != null:
			ui.zeige_tooltip(eintrag["daten"], global_position + Vector2(size.x, 0.0))
		elif not drin:
			ui.verstecke_tooltip()

	# --- Drag and Drop ---

	func _get_drag_data(_at: Vector2) -> Variant:
		if eintrag == null:
			return null
		ui.verstecke_tooltip()

		var vorschau := Panel.new()
		vorschau.custom_minimum_size = Vector2(size.x, size.y)
		vorschau.size = size
		var sb := StyleBoxFlat.new()
		sb.bg_color = eintrag["daten"].modell_farbe
		sb.set_corner_radius_all(4)
		vorschau.add_theme_stylebox_override("panel", sb)
		var umbruch := Control.new()
		umbruch.add_child(vorschau)
		vorschau.position = -size * 0.5
		set_drag_preview(umbruch)

		return {"von_index": index, "von_slot": schluessel}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		if typeof(data) != TYPE_DICTIONARY:
			return false
		var erlaubt: bool = ui.darf_ablegen(data, self)
		_setze_stil(ui.farbe_feld_ziel if erlaubt else ui.farbe_feld_hover)
		return erlaubt

	func _drop_data(_at: Vector2, data: Variant) -> void:
		_setze_stil(ui.farbe_feld)
		ui.lege_ab(data, self)


# ---------------------------------------------------------------- Aufbau

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "InventarLayer"
	_layer.layer = 20
	add_child(_layer)

	_baue_fenster()
	_baue_vorschau()
	_layer.visible = false
	set_process(true)


func _baue_fenster() -> void:
	_dunkel = ColorRect.new()
	_dunkel.color = farbe_hintergrund
	_dunkel.anchor_right = 1.0
	_dunkel.anchor_bottom = 1.0
	_dunkel.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_dunkel)

	_fenster = PanelContainer.new()
	_fenster.custom_minimum_size = Vector2(breite, hoehe)
	_fenster.anchor_left = 0.5
	_fenster.anchor_top = 0.5
	_fenster.anchor_right = 0.5
	_fenster.anchor_bottom = 0.5
	_fenster.offset_left = -breite * 0.5
	_fenster.offset_top = -hoehe * 0.5
	_fenster.offset_right = breite * 0.5
	_fenster.offset_bottom = hoehe * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = farbe_fenster
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_top = 14
	sb.content_margin_right = 14
	sb.content_margin_bottom = 14
	_fenster.add_theme_stylebox_override("panel", sb)
	_layer.add_child(_fenster)

	var reihe := HBoxContainer.new()
	reihe.add_theme_constant_override("separation", 14)
	_fenster.add_child(reihe)

	reihe.add_child(_baue_werte_spalte())
	reihe.add_child(_baue_charakter_spalte())
	reihe.add_child(_baue_inventar_spalte())

	_baue_tooltip()


func _baue_werte_spalte() -> Control:
	var spalte := VBoxContainer.new()
	spalte.custom_minimum_size.x = 190.0
	spalte.add_theme_constant_override("separation", 12)

	var oben := _neues_panel("Grundwerte")
	_grund_box = oben[1]
	spalte.add_child(oben[0])

	var unten := _neues_panel("Boni durch Ausrüstung")
	_bonus_box = unten[1]
	spalte.add_child(unten[0])
	return spalte


# Gibt [Panel, VBox für Inhalt] zurück
func _neues_panel(titel: String) -> Array:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = farbe_panel
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_top = 8
	sb.content_margin_right = 10
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)

	var kopf := Label.new()
	kopf.text = titel
	kopf.add_theme_font_size_override("font_size", 13)
	kopf.add_theme_color_override("font_color", farbe_text_schwach)
	box.add_child(kopf)
	box.add_child(HSeparator.new())

	return [panel, box]


func _baue_charakter_spalte() -> Control:
	var spalte := VBoxContainer.new()
	spalte.add_theme_constant_override("separation", 8)

	var kopf := Label.new()
	kopf.text = "Ausrüstung"
	kopf.add_theme_font_size_override("font_size", 13)
	kopf.add_theme_color_override("font_color", farbe_text_schwach)
	spalte.add_child(kopf)

	var mitte := HBoxContainer.new()
	mitte.add_theme_constant_override("separation", 10)
	spalte.add_child(mitte)

	# links: Rüstungsteile
	var links := VBoxContainer.new()
	links.add_theme_constant_override("separation", 20)
	for schluessel in ["kopf", "ruestung", "haende", "fuesse"]:
		links.add_child(_neuer_ausruestungs_slot(schluessel))
	mitte.add_child(links)

	# Mitte: 3D-Vorschau
	var behaelter := SubViewportContainer.new()
	behaelter.name = "VorschauBehaelter"
	behaelter.stretch = true
	behaelter.custom_minimum_size = vorschau_groesse
	behaelter.mouse_filter = Control.MOUSE_FILTER_STOP
	behaelter.gui_input.connect(_auf_vorschau_eingabe)
	mitte.add_child(behaelter)

	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(vorschau_groesse)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	behaelter.add_child(_viewport)

	# rechts: Schmuck und Waffen
	var rechts := VBoxContainer.new()
	rechts.add_theme_constant_override("separation", 20)
	for schluessel in ["amulett", "ring1", "ring2", "haupthand", "nebenhand"]:
		rechts.add_child(_neuer_ausruestungs_slot(schluessel))
	mitte.add_child(rechts)

	var hinweis := Label.new()
	hinweis.text = "Ziehen zum Anlegen · Vorschau drehen mit Linksklick"
	hinweis.add_theme_font_size_override("font_size", 10)
	hinweis.add_theme_color_override("font_color", farbe_text_schwach)
	spalte.add_child(hinweis)
	return spalte


func _neuer_ausruestungs_slot(schluessel: String) -> Control:
	var feld := SlotFeld.new()
	feld._bauen(self, feld_groesse, Inventar.SLOT_TITEL.get(schluessel, schluessel))
	feld.schluessel = schluessel
	_slot_felder[schluessel] = feld
	return feld


func _baue_inventar_spalte() -> Control:
	var spalte := VBoxContainer.new()
	spalte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spalte.add_theme_constant_override("separation", 8)

	var kopf := HBoxContainer.new()
	kopf.add_theme_constant_override("separation", 8)
	spalte.add_child(kopf)

	_suche = LineEdit.new()
	_suche.placeholder_text = "Suchen …"
	_suche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_suche.text_changed.connect(func(_t): _wende_filter_an())
	kopf.add_child(_suche)

	_filter = OptionButton.new()
	_filter.add_item("Alle")
	_filter.add_item("Rüstung")
	_filter.add_item("Schmuck")
	_filter.add_item("Waffen")
	_filter.add_item("Sonstiges")
	_filter.item_selected.connect(func(_i): _wende_filter_an())
	kopf.add_child(_filter)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	spalte.add_child(scroll)

	var raster := GridContainer.new()
	raster.columns = spalten
	raster.add_theme_constant_override("h_separation", 6)
	raster.add_theme_constant_override("v_separation", 6)
	raster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(raster)

	_felder.clear()
	for i in 40:
		var feld := SlotFeld.new()
		feld._bauen(self, feld_groesse)
		feld.index = i
		raster.add_child(feld)
		_felder.append(feld)

	return spalte


func _baue_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.custom_minimum_size = Vector2(230.0, 0.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.97)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 8
	sb.content_margin_top = 6
	sb.content_margin_right = 8
	sb.content_margin_bottom = 6
	_tooltip.add_theme_stylebox_override("panel", sb)
	_tooltip.visible = false

	_tooltip_text = RichTextLabel.new()
	_tooltip_text.bbcode_enabled = true
	_tooltip_text.fit_content = true
	_tooltip_text.custom_minimum_size = Vector2(214.0, 0.0)
	_tooltip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(_tooltip_text)
	_layer.add_child(_tooltip)


# ---------------------------------------------------------------- Vorschau

func _baue_vorschau() -> void:
	var welt := Node3D.new()
	_viewport.add_child(welt)

	var umgebung := WorldEnvironment.new()
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.65)
	env.ambient_light_energy = 1.0
	umgebung.environment = env
	welt.add_child(umgebung)

	var licht := DirectionalLight3D.new()
	licht.rotation_degrees = Vector3(-35.0, 145.0, 0.0)
	licht.light_energy = 1.1
	welt.add_child(licht)

	var kamera := Camera3D.new()
	kamera.projection = Camera3D.PROJECTION_ORTHOGONAL
	kamera.size = 2.3
	kamera.position = Vector3(0.0, 0.95, 3.0)
	kamera.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
	welt.add_child(kamera)

	_figur = Node3D.new()
	welt.add_child(_figur)
	_baue_figur()


# Statische Nachbildung der Spielfigur. Proportionen werden vom echten
# Visual-Knoten übernommen, damit die Vorschau mitzieht, wenn du dort etwas
# änderst. Fehlt er, greifen die Standardwerte.
func _baue_figur() -> void:
	var v = null
	var spieler := get_tree().get_first_node_in_group("player")
	if spieler != null:
		v = spieler.get_node_or_null("Visual")

	var huefte_h: float = _hole(v, "huefte_hoehe", 0.26)
	var t_unten: Vector3 = _hole(v, "torso_unten_groesse", Vector3(0.54, 0.44, 0.34))
	var t_oben: Vector3 = _hole(v, "torso_oben_groesse", Vector3(0.60, 0.46, 0.36))
	var kopf: Vector3 = _hole(v, "kopf_groesse", Vector3(0.52, 0.50, 0.49))
	var luecke: float = _hole(v, "kopf_luecke", 0.04)
	var hand: Vector3 = _hole(v, "hand_groesse", Vector3(0.19, 0.19, 0.19))
	var fuss: Vector3 = _hole(v, "fuss_groesse", Vector3(0.21, 0.18, 0.27))
	var hand_ab: float = _hole(v, "hand_abstand", 0.40)
	var hand_h: float = _hole(v, "hand_hoehe", 0.22)
	var fuss_ab: float = _hole(v, "fuss_abstand", 0.15)

	var y_unten := huefte_h + t_unten.y * 0.5
	var y_oben := huefte_h + t_unten.y + t_oben.y * 0.5
	var y_kopf := huefte_h + t_unten.y + t_oben.y + luecke + kopf.y * 0.5
	var y_hand := huefte_h + t_unten.y + hand_h

	_teil("torso_unten", t_unten, Vector3(0.0, y_unten, 0.0),
			Color(0.24, 0.26, 0.34))
	_teil("torso_oben", t_oben, Vector3(0.0, y_oben, 0.0), Color(0.30, 0.48, 0.68))
	_teil("kopf", kopf, Vector3(0.0, y_kopf, 0.0), Color(0.92, 0.76, 0.60))
	_teil("hand_l", hand, Vector3(-hand_ab, y_hand, 0.0), Color(0.92, 0.76, 0.60))
	_teil("hand_r", hand, Vector3(hand_ab, y_hand, 0.0), Color(0.92, 0.76, 0.60))
	_teil("fuss_l", fuss, Vector3(-fuss_ab, fuss.y * 0.5, 0.0), Color(0.32, 0.22, 0.16))
	_teil("fuss_r", fuss, Vector3(fuss_ab, fuss.y * 0.5, 0.0), Color(0.32, 0.22, 0.16))

	# Überzüge für angelegte Ausrüstung – minimal größer, damit sie außen liegen
	_ueberzug("helm", kopf * 1.06, Vector3(0.0, y_kopf, 0.0))
	_ueberzug("brust", t_oben * 1.08, Vector3(0.0, y_oben, 0.0))
	_ueberzug("gurt", t_unten * 1.08, Vector3(0.0, y_unten, 0.0))
	_ueberzug("hs_l", hand * 1.14, Vector3(-hand_ab, y_hand, 0.0))
	_ueberzug("hs_r", hand * 1.14, Vector3(hand_ab, y_hand, 0.0))
	_ueberzug("st_l", fuss * 1.12, Vector3(-fuss_ab, fuss.y * 0.5, 0.0))
	_ueberzug("st_r", fuss * 1.12, Vector3(fuss_ab, fuss.y * 0.5, 0.0))

	# Waffen als schlanke Quader in den Händen
	_ueberzug("waffe_r", Vector3(0.08, 0.62, 0.08),
			Vector3(hand_ab, y_hand + 0.22, 0.0))
	_ueberzug("waffe_l", Vector3(0.34, 0.44, 0.08),
			Vector3(-hand_ab - 0.06, y_hand + 0.10, 0.0))


func _hole(knoten, feld: String, standard):
	if knoten == null:
		return standard
	var wert = knoten.get(feld)
	return standard if wert == null else wert


func _teil(schluessel: String, groesse: Vector3, pos: Vector3,
		farbe: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = groesse
	mi.mesh = box
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = farbe
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mi.material_override = mat
	_figur.add_child(mi)
	_figur_teile[schluessel] = mi
	return mi


func _ueberzug(schluessel: String, groesse: Vector3, pos: Vector3) -> void:
	var mi := _teil(schluessel, groesse, pos, Color.WHITE)
	mi.visible = false


func _auf_vorschau_eingabe(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_zieht_vorschau = event.pressed
	elif event is InputEventMouseMotion and _zieht_vorschau:
		_figur.rotation.y -= event.relative.x * vorschau_dreh_tempo


# ---------------------------------------------------------------- Ablauf

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		umschalten()
		get_viewport().set_input_as_handled()
	elif offen and event.is_action_pressed("ui_cancel"):
		schliessen()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _inventar == null:
		_suche_inventar()

	_alpha = lerpf(_alpha, 1.0 if offen else 0.0,
			1.0 - exp(-einblend_tempo * delta))
	if _alpha < 0.01 and not offen:
		_layer.visible = false
	_dunkel.modulate.a = _alpha
	_fenster.modulate.a = _alpha

	if offen and not _zieht_vorschau and _figur != null:
		_figur.rotation.y += vorschau_auto_dreh * delta

	if offen and _tooltip.visible:
		_tooltip.position = _tooltip.position.lerp(
				get_viewport().get_mouse_position() + Vector2(18.0, 12.0), 0.5)


func _suche_inventar() -> void:
	_spieler = get_tree().get_first_node_in_group("player")
	if _spieler == null:
		return
	var knoten: Node = _spieler.get_node_or_null("Inventar")
	print("Spieler: ", _spieler, " | Name: ", _spieler.name,
			" | Klasse: ", _spieler.get_class(),
			" | Kinder: ", _spieler.get_children())
	print("Gruppe player: ", get_tree().get_nodes_in_group("player"))
	_inventar = knoten as Inventar
	if _inventar == null:
		push_warning("InventarUI: Kindknoten 'Inventar' am Player fehlt.")
		return
	_inventar.geaendert.connect(_zeichne)
	_inventar.ausruestung_geaendert.connect(_zeichne)
	_zeichne()
	print("Inventar bereit – Öffnen mit I.")


func umschalten() -> void:
	if offen:
		schliessen()
	else:
		oeffnen()


func oeffnen() -> void:
	if _inventar == null:
		return
	offen = true
	_layer.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_zeichne()


func schliessen() -> void:
	offen = false
	verstecke_tooltip()
	_zieht_vorschau = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------- Zeichnen

func _zeichne() -> void:
	if _inventar == null:
		return

	for feld in _felder:
		feld.aktualisiere(_inventar.hole(feld.index))
	for schluessel in _slot_felder:
		_slot_felder[schluessel].aktualisiere(_inventar.hole_ausruestung(schluessel))

	_zeichne_werte()
	_zeichne_figur()
	_wende_filter_an()
	_inventar.wende_boni_an()


func _zeichne_werte() -> void:
	var grund := _inventar.grundwerte()
	var bonus := _inventar.boni()

	_leere(_grund_box)
	_leere(_bonus_box)

	for schluessel in WERT_TITEL:
		_wert_zeile(_grund_box, WERT_TITEL[schluessel],
				_formatiere(schluessel, grund[schluessel]), farbe_text)
		var b: float = bonus[schluessel]
		var farbe := farbe_text_schwach
		if b > 0.001:
			farbe = farbe_bonus
		elif b < -0.001:
			farbe = farbe_malus
		var text := "—" if absf(b) < 0.001 else \
				("+" if b > 0.0 else "") + _formatiere(schluessel, b)
		_wert_zeile(_bonus_box, WERT_TITEL[schluessel], text, farbe)


func _formatiere(schluessel: String, wert: float) -> String:
	if schluessel == "krit":
		return "%.0f %%" % (wert * 100.0)
	if schluessel == "tempo":
		return "%.1f" % wert
	return "%.0f" % wert


func _wert_zeile(box: VBoxContainer, titel: String, wert: String,
		farbe: Color) -> void:
	var reihe := HBoxContainer.new()
	var l := Label.new()
	l.text = titel
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", farbe_text_schwach)
	reihe.add_child(l)

	var r := Label.new()
	r.text = wert
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_theme_font_size_override("font_size", 12)
	r.add_theme_color_override("font_color", farbe)
	reihe.add_child(r)
	box.add_child(reihe)


func _leere(box: Node) -> void:
	# Kopfzeile und Trennlinie stehen lassen, alles darunter neu aufbauen
	var kinder := box.get_children()
	for i in range(2, kinder.size()):
		kinder[i].queue_free()


func _zeichne_figur() -> void:
	var zuordnung := {
		"kopf": "helm", "ruestung": "brust", "fuesse": "st_l",
		"haende": "hs_l", "haupthand": "waffe_r", "nebenhand": "waffe_l",
	}
	# alles erst ausblenden
	for schluessel in ["helm", "brust", "gurt", "hs_l", "hs_r", "st_l", "st_r",
			"waffe_l", "waffe_r"]:
		_figur_teile[schluessel].visible = false

	for slot in zuordnung:
		var e = _inventar.hole_ausruestung(slot)
		if e == null:
			continue
		var farbe: Color = e["daten"].modell_farbe
		match slot:
			"haende":
				_faerbe("hs_l", farbe)
				_faerbe("hs_r", farbe)
			"fuesse":
				_faerbe("st_l", farbe)
				_faerbe("st_r", farbe)
			"ruestung":
				_faerbe("brust", farbe)
				_faerbe("gurt", farbe)
			_:
				_faerbe(zuordnung[slot], farbe)


func _faerbe(schluessel: String, farbe: Color) -> void:
	var mi: MeshInstance3D = _figur_teile[schluessel]
	mi.visible = true
	var mat := mi.material_override as StandardMaterial3D
	mat.albedo_color = farbe


func _wende_filter_an() -> void:
	var text := _suche.text.strip_edges().to_lower()
	var modus := _filter.selected

	for feld in _felder:
		var e = feld.eintrag
		var sichtbar := true

		if e != null:
			var daten: ItemDaten = e["daten"]
			if text != "" and not daten.anzeige_name.to_lower().contains(text):
				sichtbar = false
			if sichtbar and modus > 0:
				sichtbar = _passt_filter(daten.slot, modus)
		elif text != "" or modus > 0:
			sichtbar = false            # leere Felder bei aktivem Filter ausblenden

		feld.modulate.a = 1.0 if sichtbar else 0.18
		feld.mouse_filter = Control.MOUSE_FILTER_STOP if sichtbar \
				else Control.MOUSE_FILTER_IGNORE


func _passt_filter(slot: int, modus: int) -> bool:
	var s := ItemDaten.Slot
	match modus:
		1: return slot in [s.KOPF, s.RUESTUNG, s.HAENDE, s.FUESSE]
		2: return slot in [s.RING, s.AMULETT]
		3: return slot in [s.HAUPTHAND, s.NEBENHAND]
		4: return slot == s.KEINER
	return true


# ---------------------------------------------------------------- Tooltip

func zeige_tooltip(daten: ItemDaten, _pos: Vector2) -> void:
	if not offen:
		return
	var t := "[b][color=#%s]%s[/color][/b]\n" % [daten.farbe().to_html(false),
			daten.anzeige_name]
	t += "[color=#8a8d95]%s[/color]\n" % daten.slot_text()
	for schluessel in daten.boni():
		var wert: float = daten.boni()[schluessel]
		if absf(wert) < 0.001:
			continue
		var farbe := "#73d16b" if wert > 0.0 else "#db6b5c"
		t += "[color=%s]%s %s[/color]\n" % [farbe, WERT_TITEL.get(schluessel,
				schluessel), ("+" if wert > 0.0 else "") + _formatiere(schluessel, wert)]
	if daten.beschreibung != "":
		t += "\n[i][color=#7d8089]%s[/color][/i]" % daten.beschreibung

	_tooltip_text.text = t
	_tooltip.visible = true
	_tooltip.position = get_viewport().get_mouse_position() + Vector2(18.0, 12.0)


func verstecke_tooltip() -> void:
	if _tooltip != null:
		_tooltip.visible = false


# ---------------------------------------------------------------- Drag and Drop

func darf_ablegen(data: Dictionary, ziel: SlotFeld) -> bool:
	if _inventar == null:
		return false

	var von_slot: String = data.get("von_slot", "")
	var von_index: int = data.get("von_index", -1)

	# Herkunft ermitteln
	var e = null
	if von_slot != "":
		e = _inventar.hole_ausruestung(von_slot)
	else:
		e = _inventar.hole(von_index)
	if e == null:
		return false

	if ziel.schluessel != "":
		return _inventar.passt(e["daten"], ziel.schluessel)
	return true                      # ins Inventar darf alles


func lege_ab(data: Dictionary, ziel: SlotFeld) -> void:
	if _inventar == null:
		return

	var von_slot: String = data.get("von_slot", "")
	var von_index: int = data.get("von_index", -1)

	if von_slot != "" and ziel.schluessel != "":
		_inventar.tausche_ausruestung(von_slot, ziel.schluessel)
	elif von_slot != "":
		_inventar.ablegen(von_slot, ziel.index)
	elif ziel.schluessel != "":
		_inventar.ausruesten(von_index, ziel.schluessel)
	else:
		_inventar.tausche_plaetze(von_index, ziel.index)
