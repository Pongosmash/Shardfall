extends Node

# Baut das komplette HUD beim Start selbst auf: CanvasLayer, Balken,
# Treffer-Vignette und Meldungstext. Es genügt, dieses Skript an irgendeinen
# Knoten in der Hauptszene zu hängen – ein einfacher Node reicht.
#
# Bewusst OHNE Anker: Positionen werden jedes Bild aus der Fenstergröße
# berechnet, damit Godots Layout-System nichts überschreiben kann.

@export_group("Aufbau")
@export var alte_balken_entfernen: bool = true    # räumt Reste früherer Versuche weg
@export var balken_breite: float = 320.0
@export var leben_hoehe: float = 22.0
@export var ausdauer_hoehe: float = 12.0
@export var rand_unten: float = 44.0              # Abstand zum unteren Bildrand
@export var abstand: float = 6.0                  # Lücke zwischen den Balken
@export var innen_rand: float = 3.0               # Rahmenstärke

@export_group("Farben")
@export var farbe_hintergrund: Color = Color(0.10, 0.10, 0.10, 0.85)
@export var farbe_leben: Color = Color(0.78, 0.20, 0.16)
@export var farbe_ausdauer: Color = Color(0.36, 0.78, 0.24)
@export var farbe_erschoepft: Color = Color(0.85, 0.55, 0.15)

@export_group("Treffer-Vignette")
@export var blitz_dauer: float = 0.45             # wie lange der Rand nachglüht
@export var farbe_treffer: Color = Color(0.85, 0.08, 0.06)
@export var farbe_parry: Color = Color(1.0, 0.85, 0.35)
@export var farbe_block: Color = Color(0.75, 0.80, 0.90)
@export var dauerhaft_ab: float = 0.35            # ab diesem Lebensanteil dauerhaft
@export var dauerhaft_staerke: float = 0.55

@export_group("Meldungen")
@export var meldung_groesse: int = 44
@export var meldung_hoehe: float = 0.62           # Anteil der Bildhöhe

@export_group("Tempo")
@export var einblend_tempo: float = 6.0
@export var balken_tempo: float = 14.0

var _combat: Node = null
var _layer: CanvasLayer
var _vignette: ColorRect
var _leben_bg: ColorRect
var _leben_fill: ColorRect
var _ausdauer_bg: ColorRect
var _ausdauer_fill: ColorRect
var _label: Label

var _leben_voll: float = 0.0
var _ausdauer_voll: float = 0.0
var _alpha: float = 0.0
var _leben_anzeige: float = 1.0
var _ausdauer_anzeige: float = 1.0

var _blitz: float = 0.0
var _blitz_farbe: Color = Color.RED
var _meldung_timer: float = 0.0
var _meldung_dauer: float = 1.0

const VIGNETTE_SHADER := """
shader_type canvas_item;

uniform float staerke = 0.0;
uniform vec4 farbe : source_color = vec4(0.85, 0.08, 0.06, 1.0);

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.7, 1.0);
	float d = length(p);
	float v = smoothstep(0.30, 0.80, d);
	COLOR = vec4(farbe.rgb, v * staerke);
}
"""


func _ready() -> void:
	if alte_balken_entfernen:
		_raeume_auf()

	_layer = CanvasLayer.new()
	_layer.name = "HUDLayer"
	_layer.layer = 10
	add_child(_layer)

	_baue_vignette()
	_baue_balken()
	_baue_label()
	_positioniere()

	print("HUD bereit – Balken unten mittig.")


# ---------------------------------------------------------------- Aufräumen

# Sucht die ganze Szene nach von Hand gebauten Balken früherer Versuche ab und
# entfernt sie. Läuft vor dem Aufbau, kann also die eigenen nicht erwischen.
func _raeume_auf() -> void:
	var namen := ["LebenBg", "LebenFill", "AusdauerBg", "AusdauerFill"]
	var wurzel := get_tree().current_scene
	if wurzel == null:
		return

	var gefunden: Array = []
	_sammle(wurzel, namen, gefunden)

	for knoten in gefunden:
		# Nur die äußeren entfernen, Kinder gehen automatisch mit
		if knoten.get_parent() in gefunden:
			continue
		print("HUD: alten Balken entfernt -> ", knoten.get_path())
		knoten.queue_free()


func _sammle(knoten: Node, namen: Array, ergebnis: Array) -> void:
	if knoten is Control and knoten.name in namen:
		ergebnis.append(knoten)
	for kind in knoten.get_children():
		_sammle(kind, namen, ergebnis)


# ---------------------------------------------------------------- Aufbau

func _baue_vignette() -> void:
	_vignette = ColorRect.new()
	_vignette.name = "Vignette"
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color.WHITE

	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("staerke", 0.0)
	mat.set_shader_parameter("farbe", farbe_treffer)
	_vignette.material = mat

	_layer.add_child(_vignette)


func _baue_balken() -> void:
	_leben_bg = _neuer_rect("LebenBg", _layer, Vector2(balken_breite, leben_hoehe),
			farbe_hintergrund)
	_leben_fill = _neuer_rect("LebenFill", _leben_bg,
			Vector2(balken_breite - innen_rand * 2.0, leben_hoehe - innen_rand * 2.0),
			farbe_leben)
	_leben_fill.position = Vector2(innen_rand, innen_rand)

	_ausdauer_bg = _neuer_rect("AusdauerBg", _layer,
			Vector2(balken_breite, ausdauer_hoehe), farbe_hintergrund)
	_ausdauer_bg.modulate.a = 0.0
	_ausdauer_fill = _neuer_rect("AusdauerFill", _ausdauer_bg,
			Vector2(balken_breite - innen_rand * 2.0, ausdauer_hoehe - innen_rand * 2.0),
			farbe_ausdauer)
	_ausdauer_fill.position = Vector2(innen_rand, innen_rand)

	_leben_voll = _leben_fill.size.x
	_ausdauer_voll = _ausdauer_fill.size.x


func _neuer_rect(knoten_name: String, eltern: Node, groesse: Vector2,
		farbe: Color) -> ColorRect:
	var r := ColorRect.new()
	r.name = knoten_name
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.0
	r.anchor_top = 0.0
	r.anchor_right = 0.0
	r.anchor_bottom = 0.0
	r.size = groesse
	r.color = farbe
	eltern.add_child(r)
	return r


func _baue_label() -> void:
	_label = Label.new()
	_label.name = "Meldung"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", meldung_groesse)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 6)
	_label.modulate.a = 0.0
	_layer.add_child(_label)


func _positioniere() -> void:
	var vp := get_viewport().get_visible_rect().size

	_vignette.position = Vector2.ZERO
	_vignette.size = vp

	var x := (vp.x - balken_breite) * 0.5
	var aus_y := vp.y - rand_unten - ausdauer_hoehe
	var leb_y := aus_y - abstand - leben_hoehe
	_ausdauer_bg.position = Vector2(x, aus_y)
	_leben_bg.position = Vector2(x, leb_y)

	_label.position = Vector2(0.0, vp.y * meldung_hoehe)
	_label.size = Vector2(vp.x, float(meldung_groesse) * 1.4)


# ---------------------------------------------------------------- Ablauf

func _process(delta: float) -> void:
	_positioniere()
	_vignette_update(delta)
	_meldung_update(delta)

	if _combat == null:
		_suche_combat()
		return

	var w := 1.0 - exp(-balken_tempo * delta)

	var leben_anteil: float = clampf(_combat.leben / _combat.max_leben, 0.0, 1.0)
	_leben_anzeige = lerpf(_leben_anzeige, leben_anteil, w)
	_leben_fill.size.x = _leben_voll * _leben_anzeige

	var aus_anteil: float = clampf(_combat.ausdauer / _combat.max_ausdauer, 0.0, 1.0)
	_ausdauer_anzeige = lerpf(_ausdauer_anzeige, aus_anteil, w)
	_ausdauer_fill.size.x = _ausdauer_voll * _ausdauer_anzeige
	_ausdauer_fill.color = farbe_erschoepft if _combat.ist_erschoepft else farbe_ausdauer

	var sichtbar: bool = _combat.im_kampf() or aus_anteil < 0.995
	_alpha = lerpf(_alpha, 1.0 if sichtbar else 0.0,
			1.0 - exp(-einblend_tempo * delta))
	_ausdauer_bg.modulate.a = _alpha


func _vignette_update(delta: float) -> void:
	if _blitz > 0.0:
		_blitz = maxf(_blitz - delta / blitz_dauer, 0.0)

	# Bei wenig Leben glimmt der Rand dauerhaft rot
	var dauerhaft := 0.0
	if _combat != null:
		var anteil: float = _combat.leben / _combat.max_leben
		if anteil < dauerhaft_ab:
			dauerhaft = (1.0 - anteil / dauerhaft_ab) * dauerhaft_staerke

	var farbe := _blitz_farbe if _blitz > 0.0 else farbe_treffer
	var staerke := maxf(_blitz, dauerhaft)

	var mat := _vignette.material as ShaderMaterial
	mat.set_shader_parameter("staerke", staerke)
	mat.set_shader_parameter("farbe", farbe)


func _meldung_update(delta: float) -> void:
	if _meldung_timer <= 0.0:
		return
	_meldung_timer -= delta
	var t: float = clampf(_meldung_timer / _meldung_dauer, 0.0, 1.0)
	_label.modulate.a = t
	_label.position.y = get_viewport().get_visible_rect().size.y * meldung_hoehe \
			- (1.0 - t) * 24.0


func _zeige(text: String, farbe: Color, dauer: float) -> void:
	_label.text = text
	_label.add_theme_color_override("font_color", farbe)
	_meldung_dauer = dauer
	_meldung_timer = dauer
	_label.modulate.a = 1.0


func _blitzen(farbe: Color, staerke: float) -> void:
	_blitz_farbe = farbe
	_blitz = staerke


# ---------------------------------------------------------------- Signale

func _suche_combat() -> void:
	var spieler := get_tree().get_first_node_in_group("player")
	if spieler == null:
		return
	_combat = spieler.get_node_or_null("Combat")
	if _combat == null:
		return

	_combat.getroffen.connect(_auf_treffer)
	_combat.geblockt.connect(_auf_block)
	_combat.perfekt_geblockt.connect(_auf_parry)
	_combat.deckung_gebrochen.connect(_auf_bruch)
	print("HUD ist mit dem Kampfsystem verbunden.")


func _auf_treffer(_menge: float) -> void:
	_blitzen(farbe_treffer, 1.0)


func _auf_block(_menge: float) -> void:
	_blitzen(farbe_block, 0.5)
	_zeige("Geblockt", farbe_block, 0.5)


func _auf_parry() -> void:
	_blitzen(farbe_parry, 1.0)
	_zeige("PERFEKT!", farbe_parry, 1.0)


func _auf_bruch() -> void:
	_blitzen(farbe_treffer, 1.0)
	_zeige("Deckung gebrochen!", farbe_erschoepft, 0.9)
