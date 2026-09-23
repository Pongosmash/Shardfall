extends Node3D
class_name CloudLayer

@export var anzahl := 34                        # Anzahl Wolken
@export var ballen_pro_wolke := 12              # Quader pro Wolke -> Zerklüftung
@export var hoehe := 120.0
@export var hoehen_variation := 20.0
@export var radius := 450.0                     # halbe Ausdehnung des Wolkenfelds
@export var wolken_breite := 26.0               # mittlere Ausdehnung einer Wolke
@export var wind := Vector3(3.0, 0.0, 1.2)      # Blöcke pro Sekunde
@export var wolken_farbe := Color(0.96, 0.97, 1.0)
## Optional. Ohne gesetzte Referenz bleiben die Wolken bei 'wolken_farbe' -
## faellt also nicht auf, solange kein Tag-Nacht-Zyklus existiert, dimmt
## aber auch nicht ab, sobald einer da ist.
@export var tageszeit: Tageszeit
@export var wolken_farbe_nacht := Color(0.22, 0.25, 0.32)
@export var folge_ziel: Node3D                  # Player hier reinziehen
@export var seed_wert := 0                      # 0 = jedes Mal anders

@export_group("Form")
## Wie stark sich die Wolke zur Mitte hin aufwölbt. 0 = flache Scheibe.
@export var bauchigkeit := 1.0
## Dicke der Ballen im Verhältnis zu ihrer Breite. Höher = pummeliger.
@export var ballen_dicke := 0.42
## Wie stark die Ballen zum Rand hin schrumpfen (kleiner = kompaktere Wolke)
@export var rand_abfall := 0.45
## 1.0 = kreisrund von oben, höhere Werte ziehen die Wolken in die Länge
@export var streckung_max := 1.35

var _multi: MultiMeshInstance3D
var _material: StandardMaterial3D
var _zentren: PackedVector3Array = []           # eine Position pro Wolke
var _offsets: PackedVector3Array = []           # Ballen relativ zum Wolkenzentrum
var _basen: Array[Basis] = []                   # Drehung + Größe pro Ballen


func _ready() -> void:
	# Rueckfall auf die Gruppe: seit der Spieler eine eigene Szene ist, kann
	# 'folge_ziel' im Inspektor nicht mehr gesetzt werden - Godot laesst keinen
	# NodePath ueber eine Szenengrenze hinweg zu. Kein push_error: ohne Ziel
	# bleibt das Wolkenfeld um den Ursprung stehen, statt mitzuwandern. Das
	# faellt erst nach ein paar hundert Bloecken auf - deshalb die Warnung.
	if folge_ziel == null:
		folge_ziel = get_tree().get_first_node_in_group("player") as Node3D
	if folge_ziel == null:
		push_warning("CloudLayer: kein Spieler gefunden, das Wolkenfeld bleibt am Ursprung stehen.")

	var rng := RandomNumberGenerator.new()
	if seed_wert != 0:
		rng.seed = seed_wert
	else:
		rng.randomize()

	_material = StandardMaterial3D.new()
	_material.albedo_color = wolken_farbe
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_material.roughness = 1.0

	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = _material

	var gesamt: int = anzahl * ballen_pro_wolke
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = gesamt

	for c in anzahl:
		_zentren.append(Vector3(
			rng.randf_range(-radius, radius),
			hoehe + rng.randf_range(-hoehen_variation, hoehen_variation),
			rng.randf_range(-radius, radius)))

		# jede Wolke hat ihre eigene Grundgröße und Streckung
		var groesse: float = wolken_breite * rng.randf_range(0.6, 1.6)
		var streckung := Vector3(
			rng.randf_range(1.0, streckung_max), 1.0,
			rng.randf_range(1.0 / streckung_max, 1.0))

		for b in ballen_pro_wolke:
			# Ballen liegen in einer flachen Ellipse um das Zentrum
			var w: float = rng.randf() * TAU
			var r: float = sqrt(rng.randf())            # gleichmäßig in der Fläche

			# Kern: Ballen nahe der Mitte sitzen höher und sind dicker, außen
			# liegende flachen ab. Das ergibt eine gewölbte Kuppel statt einer
			# gleichmäßig dünnen Scheibe.
			var woelbung: float = (1.0 - r * r) * bauchigkeit * groesse * 0.30
			var off := Vector3(
				cos(w) * r * groesse * streckung.x,
				woelbung + rng.randf_range(-0.06, 0.10) * groesse,
				sin(w) * r * groesse * streckung.z)
			_offsets.append(off)

			# außen liegende Ballen sind kleiner -> ausgefranste Ränder
			var abfall: float = lerp(1.0, rand_abfall, r)
			# ... und flacher, damit die Wolke unten glatt bleibt und oben bauscht
			var dicke: float = ballen_dicke * lerp(1.0, 0.45, r)
			var s := Vector3(
				groesse * rng.randf_range(0.45, 0.85) * abfall * streckung.x,
				groesse * rng.randf_range(dicke * 0.8, dicke * 1.2) * abfall,
				groesse * rng.randf_range(0.45, 0.80) * abfall * streckung.z)
			_basen.append(Basis(Vector3.UP, rng.randf() * TAU).scaled(s))

	_multi = MultiMeshInstance3D.new()
	_multi.multimesh = mm
	_multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_multi.extra_cull_margin = radius
	add_child(_multi)
	_schreibe_transforms()


func _process(delta: float) -> void:
	var zentrum := Vector3.ZERO
	if folge_ziel:
		zentrum = folge_ziel.global_position

	for c in _zentren.size():
		var p: Vector3 = _zentren[c] + wind * delta
		# am Rand des Felds auf die Gegenseite umsetzen -> unendliches Feld
		if p.x - zentrum.x >  radius: p.x -= radius * 2.0
		if p.x - zentrum.x < -radius: p.x += radius * 2.0
		if p.z - zentrum.z >  radius: p.z -= radius * 2.0
		if p.z - zentrum.z < -radius: p.z += radius * 2.0
		_zentren[c] = p

	_schreibe_transforms()

	if tageszeit != null:
		_material.albedo_color = wolken_farbe_nacht.lerp(
				wolken_farbe, tageszeit.tagesanteil_aktuell())


func _schreibe_transforms() -> void:
	var i := 0
	for c in _zentren.size():
		var zentrum: Vector3 = _zentren[c]
		for b in ballen_pro_wolke:
			_multi.multimesh.set_instance_transform(
					i, Transform3D(_basen[i], zentrum + _offsets[i]))
			i += 1
