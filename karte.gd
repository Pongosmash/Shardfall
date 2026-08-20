extends Node
class_name Karte

# Minikarte oben rechts und große Karte auf M – beide zeigen dasselbe
# 3D-Diorama der Welt, nur mit anderer Kameraeinstellung.
#
# Aufbau:
#   Ein gemeinsames World3D enthält das Miniaturgelände. Zwei SubViewports
#   teilen sich diese Welt und haben je eine eigene orthografische Kamera.
#   Dadurch wird das Gelände nur einmal gebaut und gespeichert.
#
# Das Gelände entsteht nicht aus den geladenen Chunks, sondern durch Abtasten
# derselben Noise-Funktionen (WorldGenerator.hoehe_bei). Das ist um
# Größenordnungen billiger als eine zweite Kamera auf die echte Welt und
# funktioniert auch für Gebiete, die gar nicht geladen sind.
#
# Darstellung: Das Gelände wird in Höhenstufen terrassiert. Jede Zelle bekommt
# eine waagerechte Deckfläche, zwischen unterschiedlich hohen Nachbarn stehen
# senkrechte Wände. Erst dadurch entstehen die abgetreppten Kanten, die eine
# Blockwelt-Karte ausmachen – eine glatt interpolierte Fläche sieht wie eine
# Landkarte aus, nicht wie ein Diorama.
#
# Es genügt ein einfacher Node in der Hauptszene.

@export_group("Referenzen")
@export var terrain: VoxelTerrain              # VoxelTerrain hier reinziehen
@export var ziel: Node3D                       # Player hier reinziehen

@export_group("Gelände")
## Sichtbarer Radius der Minikarte in Blöcken
@export var mini_radius: float = 110.0
## Maximaler Radius, der überhaupt aufgebaut und behalten wird
@export var gross_radius: float = 380.0
## Kantenlänge einer Geländekachel in Blöcken
@export var kachel_groesse: int = 64
## Kantenlänge einer Geländezelle. Größer = klobiger, aber schneller.
@export var schritt: int = 4
## Höhe einer Terrassenstufe in Blöcken. Der wichtigste Regler für den Look:
## klein = feine Treppen, groß = wenige markante Plateaus.
@export var hoehen_stufe: float = 3.0
## Überhöhung der Höhenunterschiede – macht Hügel und Berge lesbar
@export var hoehen_ueberhoehung: float = 1.7
## Kacheln pro Bild. Höher = schnellerer Aufbau, aber ruckeliger.
@export var kacheln_pro_frame: int = 3
@export var baeume_zeigen: bool = true
@export var baum_groesse: float = 4.0

@export_group("Ansicht")
## Kameraneigung. 90 = senkrecht von oben, kleiner = mehr Schrägsicht.
@export var neigung_grad: float = 55.0
## Norden bleibt oben. Aus = Karte dreht sich mit dem Spieler.
@export var norden_oben: bool = true

@export_group("Spielermarker")
@export var spieler_pfeil_groesse: float = 10.0
## Länge des Blickkegels in Blöcken
@export var spieler_kegel_laenge: float = 30.0
## Öffnungswinkel des Blickkegels in Grad
@export var spieler_kegel_winkel: float = 55.0
## Marker wächst beim Herauszoomen mit, damit er nicht verschwindet
@export var marker_mit_zoom: bool = true

@export_group("Minikarte")
@export var mini_groesse: Vector2i = Vector2i(230, 230)
@export var mini_rand: float = 18.0
@export var mini_zeigen: bool = true

@export_group("Große Karte")
@export var gross_viewport: Vector2i = Vector2i(900, 620)
@export var gross_zoom_start: float = 300.0
@export var gross_zoom_min: float = 60.0
@export var gross_zoom_max: float = 700.0

@export_group("Farben")
@export var farbe_wasser: Color = Color(0.18, 0.55, 0.86)
@export var farbe_ufer: Color = Color(0.90, 0.83, 0.52)
@export var farbe_gras: Color = Color(0.34, 0.78, 0.28)
@export var farbe_hochland: Color = Color(0.58, 0.74, 0.30)
@export var farbe_fels: Color = Color(0.60, 0.60, 0.64)
@export var farbe_schnee: Color = Color(0.95, 0.97, 1.0)
## Wie stark die senkrechten Wände gegenüber den Deckflächen abdunkeln
@export var wand_dunkler: float = 0.68
@export var farbe_baum_laub: Color = Color(0.16, 0.52, 0.20)
@export var farbe_baum_tanne: Color = Color(0.10, 0.34, 0.24)
@export var farbe_brett: Color = Color(0.30, 0.20, 0.12)
@export var farbe_hintergrund: Color = Color(0.10, 0.30, 0.52)
@export var farbe_spieler: Color = Color(1.0, 0.84, 0.24)
## Dunkle Umrandung – erst dadurch hebt sich der Pfeil von hellem Gelände ab
@export var farbe_spieler_rand: Color = Color(0.12, 0.09, 0.03)
@export var farbe_spieler_kegel: Color = Color(1.0, 0.92, 0.50)
@export var farbe_marker: Color = Color(0.95, 0.35, 0.30)

var offen: bool = false
var waypoints: Array = []                      # { "name": String, "pos": Vector3 }

var _gen: WorldGenerator = null

var _mini_vp: SubViewport
var _gross_vp: SubViewport
var _mini_kam: Camera3D
var _gross_kam: Camera3D
var _welt: Node3D

var _kacheln: Dictionary = {}                  # Vector2i -> { mesh, laub, tanne }
var _laub_mm: MultiMeshInstance3D
var _tanne_mm: MultiMeshInstance3D
var _brett: MeshInstance3D
var _spieler_marker: Node3D
var _pfeil: MeshInstance3D
var _marker_wurzel: Node3D
var _gelaende_material: StandardMaterial3D

var _baeume_dreckig: bool = false
var _warteschlange: Array = []
var _letzte_pruefung: Vector2 = Vector2(1e9, 1e9)

var _gross_zentrum: Vector2 = Vector2.ZERO
var _gross_zoom: float = 300.0
var _zieht: bool = false
var _zieh_start: Vector2 = Vector2.ZERO
var _zieh_zentrum: Vector2 = Vector2.ZERO
var _bewegt: float = 0.0

var _layer: CanvasLayer
var _mini_rahmen: PanelContainer
var _gross_wurzel: Control
var _gross_bild: TextureRect
var _name_feld: LineEdit
var _liste: VBoxContainer
var _info: Label


# ---------------------------------------------------------------- Aufbau

func _ready() -> void:
	if terrain == null or ziel == null:
		push_error("Karte: 'terrain' und 'ziel' müssen zugewiesen sein.")
		set_process(false)
		return

	_gen = terrain.generator as WorldGenerator
	if _gen == null or not _gen.has_method("baum_plan_bei"):
		push_error("Karte: world_generator.gd ist nicht aktuell – "
				+ "es fehlt 'baum_plan_bei'.")
		set_process(false)
		return

	_gross_zoom = gross_zoom_start
	_baue_viewports()
	_baue_welt()
	_baue_ui()
	print("Karte bereit – große Karte mit M.")


func _baue_viewports() -> void:
	# Beide Viewports teilen sich dieselbe World3D. Das Gelände hängt im
	# Mini-Viewport, die große Kamera sieht es trotzdem.
	var welt3d := World3D.new()

	_mini_vp = SubViewport.new()
	_mini_vp.size = mini_groesse
	_mini_vp.world_3d = welt3d
	_mini_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_mini_vp.transparent_bg = false
	add_child(_mini_vp)

	_gross_vp = SubViewport.new()
	_gross_vp.size = gross_viewport
	_gross_vp.world_3d = welt3d
	_gross_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_gross_vp.transparent_bg = false
	add_child(_gross_vp)

	_mini_kam = _neue_kamera(mini_radius * 2.0)
	_mini_kam.cull_mask = 1                     # keine Beschriftungen
	_mini_vp.add_child(_mini_kam)

	_gross_kam = _neue_kamera(_gross_zoom)
	_gross_kam.cull_mask = 1 | 2                # inklusive Beschriftungen
	_gross_vp.add_child(_gross_kam)


func _neue_kamera(groesse: float) -> Camera3D:
	var k := Camera3D.new()
	k.projection = Camera3D.PROJECTION_ORTHOGONAL
	k.size = groesse
	k.near = 1.0
	k.far = 4000.0
	return k


func _baue_welt() -> void:
	_welt = Node3D.new()
	_welt.name = "Kartenwelt"
	_mini_vp.add_child(_welt)

	var umgebung := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = farbe_hintergrund
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.82, 0.88)
	env.ambient_light_energy = 1.0
	umgebung.environment = env
	_welt.add_child(umgebung)

	# Streiflicht von schräg oben. Die Hauptarbeit machen aber die dunkleren
	# Wandfarben – Licht allein reicht bei flachen Deckflächen nicht.
	var licht := DirectionalLight3D.new()
	licht.rotation_degrees = Vector3(-52.0, 128.0, 0.0)
	licht.light_energy = 0.9
	licht.shadow_enabled = false
	_welt.add_child(licht)

	_gelaende_material = StandardMaterial3D.new()
	_gelaende_material.vertex_color_use_as_albedo = true
	_gelaende_material.roughness = 1.0
	_gelaende_material.metallic_specular = 0.0
	# Culling aus: Bei prozedural erzeugten Flächen ist die Umlaufrichtung
	# schnell verdreht, und dann verschwindet das ganze Gelände. Auf einer
	# Kartenansicht kostet doppelseitiges Zeichnen praktisch nichts.
	_gelaende_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Brett unter dem Gelände: gibt dem Ganzen den Diorama-Charakter
	_brett = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 20.0, 1.0)
	_brett.mesh = box
	var bm := StandardMaterial3D.new()
	bm.albedo_color = farbe_brett
	bm.roughness = 1.0
	_brett.material_override = bm
	_welt.add_child(_brett)

	_laub_mm = _baue_baum_multimesh(false)
	_tanne_mm = _baue_baum_multimesh(true)
	_baue_pfeil()

	_marker_wurzel = Node3D.new()
	_welt.add_child(_marker_wurzel)


# Laubbäume als runde Ballen, Tannen als Kegel – so bleiben sie auch bei
# wenigen Bildpunkten unterscheidbar.
func _baue_baum_multimesh(tanne: bool) -> MultiMeshInstance3D:
	var mesh: Mesh
	if tanne:
		var kegel := CylinderMesh.new()
		kegel.top_radius = 0.0
		kegel.bottom_radius = baum_groesse * 0.42
		kegel.height = baum_groesse * 1.5
		kegel.radial_segments = 6
		kegel.rings = 1
		mesh = kegel
	else:
		var kugel := SphereMesh.new()
		kugel.radius = baum_groesse * 0.5
		kugel.height = baum_groesse * 0.9
		kugel.radial_segments = 7
		kugel.rings = 4
		mesh = kugel

	var mat := StandardMaterial3D.new()
	mat.albedo_color = farbe_baum_tanne if tanne else farbe_baum_laub
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mesh.surface_set_material(0, mat)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 0

	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = gross_radius
	_welt.add_child(mi)
	return mi


# Positionsmarker des Spielers: Blickkegel, umrandeter Pfeil und ein
# pulsierender Ring. Alles ohne Tiefentest, damit nichts hinter einer
# Geländestufe verschwindet – auf einer Karte will man den eigenen Standort
# immer sehen, auch wenn er hinter einem Berg liegt.
func _baue_pfeil() -> void:
	_spieler_marker = Node3D.new()
	_welt.add_child(_spieler_marker)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Blickkegel zuerst – die späteren Dreiecke überschreiben ihn dort,
	# wo sie sich überlappen.
	var halb := deg_to_rad(clampf(spieler_kegel_winkel, 5.0, 170.0) * 0.5)
	var segmente := 12
	for i in segmente:
		var a0 := -halb + 2.0 * halb * float(i) / float(segmente)
		var a1 := -halb + 2.0 * halb * float(i + 1) / float(segmente)
		var p0 := Vector3(sin(a0), 0.0, -cos(a0)) * spieler_kegel_laenge
		var p1 := Vector3(sin(a1), 0.0, -cos(a1)) * spieler_kegel_laenge
		_tri(st, Vector3.ZERO, p1, p0, farbe_spieler_kegel)

	_pfeil_form(st, spieler_pfeil_groesse * 1.5, 0.15, farbe_spieler_rand)
	_pfeil_form(st, spieler_pfeil_groesse, 0.30, farbe_spieler)

	st.index()
	_pfeil = MeshInstance3D.new()
	_pfeil.mesh = st.commit()
	_pfeil.material_override = _marker_material()
	_spieler_marker.add_child(_pfeil)


func _marker_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	return mat


# Vierecksförmiger Pfeil, Spitze in -Z (Blickrichtung)
func _pfeil_form(st: SurfaceTool, g: float, y: float, farbe: Color) -> void:
	var spitze := Vector3(0.0, y, -g)
	var links := Vector3(-g * 0.62, y, g * 0.55)
	var kerbe := Vector3(0.0, y, g * 0.18)
	var rechts := Vector3(g * 0.62, y, g * 0.55)
	_tri(st, spitze, links, kerbe, farbe)
	_tri(st, spitze, kerbe, rechts, farbe)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		farbe: Color) -> void:
	for punkt in [a, b, c]:
		st.set_color(farbe)
		st.set_normal(Vector3.UP)
		st.add_vertex(punkt)


# ---------------------------------------------------------------- Ablauf

func _process(_delta: float) -> void:
	if _gen == null:
		return

	var p := ziel.global_position
	var hier := Vector2(p.x, p.z)

	if hier.distance_to(_letzte_pruefung) > float(kachel_groesse) * 0.5:
		_letzte_pruefung = hier
		_plane_kacheln(hier)

	_arbeite_warteschlange()

	if _baeume_dreckig:
		_baeume_dreckig = false
		_schreibe_baeume()

	_setze_pfeil(p)
	_setze_kamera(_mini_kam, hier, mini_radius * 2.0)
	_setze_brett(hier)

	if offen:
		_setze_kamera(_gross_kam, _gross_zentrum, _gross_zoom)


# Höhe in Kartenkoordinaten
func _y(hoehe: float) -> float:
	return hoehe * hoehen_ueberhoehung


# Auf Terrassenstufen rasten. Wasser bleibt auf Meereshöhe.
func _stufe(hoehe: float) -> float:
	var s: float = maxf(hoehen_stufe, 0.5)
	return floor(hoehe / s) * s


func _setze_brett(zentrum: Vector2) -> void:
	# Nur so groß wie der sichtbare Bereich, sonst füllt es das halbe Bild
	var reichweite: float = gross_radius if offen else mini_radius
	var kante: float = reichweite * 2.0 + 30.0
	var box := _brett.mesh as BoxMesh
	box.size = Vector3(kante, 20.0, kante)
	# Oberkante knapp unter dem tiefsten Gelände
	var oben: float = _y(float(_gen.sea_level) - 6.0)
	_brett.global_position = Vector3(zentrum.x, oben - 10.0, zentrum.y)


func _setze_kamera(kam: Camera3D, zentrum: Vector2, groesse: float) -> void:
	var boden := _y(float(_gen.hoehe_bei(int(zentrum.x), int(zentrum.y))))
	var mitte := Vector3(zentrum.x, boden, zentrum.y)

	var yaw := 0.0
	if not norden_oben:
		yaw = ziel.global_rotation.y

	var pitch := deg_to_rad(clampf(neigung_grad, 15.0, 89.0))
	var rueck := Vector3(0.0, sin(pitch), cos(pitch)).normalized() * 1200.0
	kam.global_position = mitte + rueck.rotated(Vector3.UP, yaw)
	kam.look_at(mitte, Vector3.UP)
	kam.size = groesse


func _setze_pfeil(p: Vector3) -> void:
	var h := _y(_stufe(float(_gen.hoehe_bei(int(p.x), int(p.z)))))
	_spieler_marker.global_position = Vector3(p.x, h + 4.0, p.z)
	_spieler_marker.rotation.y = ziel.global_rotation.y

	# Beim Herauszoomen mitwachsen, sonst schrumpft der Marker auf wenige
	# Bildpunkte. Die Minikarte ist währenddessen verdeckt, es gibt also
	# keinen Konflikt zwischen den beiden Kameras.
	var skala := 1.0
	if marker_mit_zoom and offen:
		skala = clampf(_gross_zoom / (mini_radius * 2.0), 0.6, 3.0)
	_spieler_marker.scale = Vector3.ONE * skala


# ---------------------------------------------------------------- Kacheln

func _plane_kacheln(zentrum: Vector2) -> void:
	var reichweite: float = gross_radius if offen else mini_radius
	var k: int = kachel_groesse
	var n: int = int(ceil(reichweite / float(k))) + 1
	var mx: int = floori(zentrum.x / float(k))
	var mz: int = floori(zentrum.y / float(k))

	_warteschlange.clear()
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var key := Vector2i(mx + dx, mz + dz)
			if _kacheln.has(key):
				continue
			var mitte := Vector2((float(key.x) + 0.5) * float(k),
					(float(key.y) + 0.5) * float(k))
			if mitte.distance_to(zentrum) > reichweite + float(k):
				continue
			_warteschlange.append({"key": key, "d": mitte.distance_to(zentrum)})

	# Nahe Kacheln zuerst – die sieht man als Erstes
	_warteschlange.sort_custom(func(a, b): return a["d"] < b["d"])

	# Weit entfernte Kacheln freigeben
	var weg: Array = []
	for key in _kacheln:
		var mitte := Vector2((float(key.x) + 0.5) * float(k),
				(float(key.y) + 0.5) * float(k))
		if mitte.distance_to(zentrum) > gross_radius + float(k) * 2.0:
			weg.append(key)
	for key in weg:
		_kacheln[key]["mesh"].queue_free()
		_kacheln.erase(key)
		_baeume_dreckig = true


func _arbeite_warteschlange() -> void:
	var anzahl: int = mini(kacheln_pro_frame, _warteschlange.size())
	for i in anzahl:
		var eintrag = _warteschlange.pop_front()
		if not _kacheln.has(eintrag["key"]):
			_baue_kachel(eintrag["key"])


func _baue_kachel(key: Vector2i) -> void:
	var n: int = maxi(1, kachel_groesse / schritt)
	var bx: int = key.x * kachel_groesse
	var bz: int = key.y * kachel_groesse
	var breite: int = n + 1                    # eine Zelle Überhang für die Wände
	var meer := float(_gen.sea_level)

	# Höhe und Farbe je Zelle, gemessen in der Zellmitte.
	# Die Überhangspalte sorgt dafür, dass an Kachelgrenzen dieselben Wände
	# entstehen wie im Inneren – sonst klafft dort eine Lücke.
	var hoehen := PackedFloat32Array()
	var farben: Array = []
	hoehen.resize(breite * breite)
	farben.resize(breite * breite)

	for j in breite:
		for i in breite:
			var gx: int = bx + i * schritt + schritt / 2
			var gz: int = bz + j * schritt + schritt / 2
			var roh := float(_gen.hoehe_bei(gx, gz))
			var idx: int = j * breite + i
			if roh <= meer:
				hoehen[idx] = _y(meer)
				farben[idx] = farbe_wasser
			else:
				hoehen[idx] = _y(_stufe(roh))
				farben[idx] = _farbe_fuer(roh)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for j in n:
		for i in n:
			var idx: int = j * breite + i
			var y: float = hoehen[idx]
			var farbe: Color = farben[idx]

			var x0: float = float(bx + i * schritt)
			var x1: float = x0 + float(schritt)
			var z0: float = float(bz + j * schritt)
			var z1: float = z0 + float(schritt)

			# Deckfläche
			_quad(st,
					Vector3(x0, y, z0), Vector3(x1, y, z0),
					Vector3(x1, y, z1), Vector3(x0, y, z1),
					Vector3.UP, farbe)

			# Wand zum Nachbarn in +X
			var yx: float = hoehen[j * breite + i + 1]
			if absf(yx - y) > 0.01:
				var hoch: float = maxf(y, yx)
				var tief: float = minf(y, yx)
				var wf: Color = (farbe if y > yx else farben[j * breite + i + 1])
				_quad(st,
						Vector3(x1, tief, z0), Vector3(x1, hoch, z0),
						Vector3(x1, hoch, z1), Vector3(x1, tief, z1),
						Vector3.RIGHT, _dunkler(wf))

			# Wand zum Nachbarn in +Z
			var yz: float = hoehen[(j + 1) * breite + i]
			if absf(yz - y) > 0.01:
				var hoch2: float = maxf(y, yz)
				var tief2: float = minf(y, yz)
				var wf2: Color = (farbe if y > yz else farben[(j + 1) * breite + i])
				_quad(st,
						Vector3(x0, tief2, z1), Vector3(x0, hoch2, z1),
						Vector3(x1, hoch2, z1), Vector3(x1, tief2, z1),
						Vector3.BACK, _dunkler(wf2))

	st.index()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _gelaende_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_welt.add_child(mi)

	_kacheln[key] = _sammle_baeume(bx, bz)
	_kacheln[key]["mesh"] = mi
	_baeume_dreckig = true


# Zwei Dreiecke aus vier Eckpunkten, mit fester Farbe und Normale
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		normale: Vector3, farbe: Color) -> void:
	for punkt in [a, b, c, a, c, d]:
		st.set_color(farbe)
		st.set_normal(normale)
		st.add_vertex(punkt)


func _dunkler(f: Color) -> Color:
	return Color(f.r * wand_dunkler, f.g * wand_dunkler, f.b * wand_dunkler)


func _farbe_fuer(h: float) -> Color:
	var meer := float(_gen.sea_level)
	var stein := float(_gen.stone_line)

	if h <= meer + 2.0:
		return farbe_ufer
	if h >= stein + 22.0:
		return farbe_schnee
	if h >= stein:
		return farbe_fels

	# Zwischen Ufer und Steingrenze von Grün nach Hochland
	var t: float = clampf((h - meer) / maxf(stein - meer, 1.0), 0.0, 1.0)
	return farbe_gras.lerp(farbe_hochland, pow(t, 1.5))


# Alle Bäume, deren Stamm in dieser Kachel steht
func _sammle_baeume(bx: int, bz: int) -> Dictionary:
	var laub: Array = []
	var tannen: Array = []
	if not baeume_zeigen:
		return {"laub": laub, "tanne": tannen}

	var zelle: int = maxi(1, _gen.baum_zelle)
	var c0x: int = floori(float(bx) / float(zelle))
	var c1x: int = floori(float(bx + kachel_groesse) / float(zelle))
	var c0z: int = floori(float(bz) / float(zelle))
	var c1z: int = floori(float(bz + kachel_groesse) / float(zelle))

	for cz in range(c0z, c1z + 1):
		for cx in range(c0x, c1x + 1):
			var plan: Dictionary = _gen.baum_plan_bei(cx, cz)
			if not plan["da"]:
				continue
			var gx: int = plan["x"]
			var gz: int = plan["z"]
			# Jede Kachel nimmt nur ihre eigenen Bäume, sonst doppelt
			if gx < bx or gx >= bx + kachel_groesse:
				continue
			if gz < bz or gz >= bz + kachel_groesse:
				continue

			var gross: float = 1.0 + float(int(plan["dick"]) - 1) * 0.45
			var basis := Basis().scaled(Vector3(gross, gross, gross))
			# Auf der Terrassenhöhe absetzen, nicht auf der echten Höhe –
			# sonst schweben oder versinken die Bäume.
			var boden := _y(_stufe(float(plan["boden"])))
			var t := Transform3D(basis,
					Vector3(float(gx), boden + baum_groesse * 0.45 * gross, float(gz)))

			if int(plan["art"]) == 2:
				tannen.append(t)
			else:
				laub.append(t)

	return {"laub": laub, "tanne": tannen}


func _schreibe_baeume() -> void:
	var laub: Array = []
	var tannen: Array = []
	for key in _kacheln:
		laub.append_array(_kacheln[key]["laub"])
		tannen.append_array(_kacheln[key]["tanne"])

	_fuelle(_laub_mm, laub)
	_fuelle(_tanne_mm, tannen)


func _fuelle(mi: MultiMeshInstance3D, liste: Array) -> void:
	var mm: MultiMesh = mi.multimesh
	mm.instance_count = liste.size()
	for i in liste.size():
		mm.set_instance_transform(i, liste[i])


# ---------------------------------------------------------------- Wegpunkte

func setze_wegpunkt(pos: Vector3, bezeichnung: String = "") -> void:
	if bezeichnung.strip_edges() == "":
		bezeichnung = "Marker %d" % (waypoints.size() + 1)
	waypoints.append({"name": bezeichnung, "pos": pos})
	_zeichne_marker()
	_zeichne_liste()


func loesche_wegpunkt(index: int) -> void:
	if index < 0 or index >= waypoints.size():
		return
	waypoints.remove_at(index)
	_zeichne_marker()
	_zeichne_liste()


func _zeichne_marker() -> void:
	for kind in _marker_wurzel.get_children():
		kind.queue_free()

	for wp in waypoints:
		var pos: Vector3 = wp["pos"]

		var stab := MeshInstance3D.new()
		var zyl := CylinderMesh.new()
		zyl.top_radius = 0.9
		zyl.bottom_radius = 0.9
		zyl.height = 14.0
		zyl.radial_segments = 6
		stab.mesh = zyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = farbe_marker
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		stab.material_override = mat
		stab.position = pos + Vector3(0.0, 7.0, 0.0)
		_marker_wurzel.add_child(stab)

		# Beschriftung nur auf der großen Karte: eigene Sichtbarkeitsebene,
		# die Minikarten-Kamera filtert sie über cull_mask weg.
		var text := Label3D.new()
		text.text = str(wp["name"])
		text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		text.no_depth_test = true
		text.fixed_size = true
		text.pixel_size = 0.0016
		text.modulate = Color.WHITE
		text.outline_size = 10
		text.layers = 2
		text.position = pos + Vector3(0.0, 18.0, 0.0)
		_marker_wurzel.add_child(text)


# ---------------------------------------------------------------- Oberfläche

func _baue_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "KartenLayer"
	_layer.layer = 15
	add_child(_layer)

	_baue_minikarte()
	_baue_grosse_karte()


func _baue_minikarte() -> void:
	_mini_rahmen = PanelContainer.new()
	_mini_rahmen.anchor_left = 1.0
	_mini_rahmen.anchor_right = 1.0
	_mini_rahmen.offset_left = -float(mini_groesse.x) - mini_rand - 8.0
	_mini_rahmen.offset_top = mini_rand
	_mini_rahmen.offset_right = -mini_rand
	_mini_rahmen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_rahmen.visible = mini_zeigen

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.9)
	sb.set_corner_radius_all(6)
	sb.border_color = Color(0.0, 0.0, 0.0, 0.6)
	sb.set_border_width_all(2)
	sb.content_margin_left = 4
	sb.content_margin_top = 4
	sb.content_margin_right = 4
	sb.content_margin_bottom = 4
	_mini_rahmen.add_theme_stylebox_override("panel", sb)
	_layer.add_child(_mini_rahmen)

	var bild := TextureRect.new()
	bild.texture = _mini_vp.get_texture()
	bild.custom_minimum_size = Vector2(mini_groesse)
	bild.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_rahmen.add_child(bild)

	var norden := Label.new()
	norden.text = "N"
	norden.mouse_filter = Control.MOUSE_FILTER_IGNORE
	norden.anchor_right = 1.0
	norden.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	norden.offset_top = 6.0
	norden.add_theme_font_size_override("font_size", 13)
	norden.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	norden.add_theme_constant_override("outline_size", 5)
	bild.add_child(norden)


func _baue_grosse_karte() -> void:
	_gross_wurzel = Control.new()
	_gross_wurzel.anchor_right = 1.0
	_gross_wurzel.anchor_bottom = 1.0
	_gross_wurzel.visible = false
	_layer.add_child(_gross_wurzel)

	var dunkel := ColorRect.new()
	dunkel.color = Color(0.0, 0.0, 0.0, 0.55)
	dunkel.anchor_right = 1.0
	dunkel.anchor_bottom = 1.0
	_gross_wurzel.add_child(dunkel)

	var fenster := PanelContainer.new()
	fenster.anchor_left = 0.5
	fenster.anchor_top = 0.5
	fenster.anchor_right = 0.5
	fenster.anchor_bottom = 0.5
	var b: float = float(gross_viewport.x) + 260.0
	var h: float = float(gross_viewport.y) + 90.0
	fenster.offset_left = -b * 0.5
	fenster.offset_top = -h * 0.5
	fenster.offset_right = b * 0.5
	fenster.offset_bottom = h * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.13, 0.97)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_top = 12
	sb.content_margin_right = 14
	sb.content_margin_bottom = 12
	fenster.add_theme_stylebox_override("panel", sb)
	_gross_wurzel.add_child(fenster)

	var spalten := VBoxContainer.new()
	spalten.add_theme_constant_override("separation", 8)
	fenster.add_child(spalten)

	var kopf := HBoxContainer.new()
	kopf.add_theme_constant_override("separation", 8)
	spalten.add_child(kopf)

	_name_feld = LineEdit.new()
	_name_feld.placeholder_text = "Name für den nächsten Marker …"
	_name_feld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(_name_feld)

	var zentrieren := Button.new()
	zentrieren.text = "Auf Spieler zentrieren"
	zentrieren.pressed.connect(_zentriere_auf_spieler)
	kopf.add_child(zentrieren)

	var reihe := HBoxContainer.new()
	reihe.add_theme_constant_override("separation", 12)
	reihe.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spalten.add_child(reihe)

	_gross_bild = TextureRect.new()
	_gross_bild.texture = _gross_vp.get_texture()
	_gross_bild.custom_minimum_size = Vector2(gross_viewport)
	_gross_bild.mouse_filter = Control.MOUSE_FILTER_STOP
	_gross_bild.gui_input.connect(_auf_karten_eingabe)
	reihe.add_child(_gross_bild)

	var rechts := VBoxContainer.new()
	rechts.custom_minimum_size.x = 230.0
	rechts.add_theme_constant_override("separation", 4)
	reihe.add_child(rechts)

	var titel := Label.new()
	titel.text = "Marker"
	titel.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))
	rechts.add_child(titel)
	rechts.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rechts.add_child(scroll)

	_liste = VBoxContainer.new()
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_liste)

	_info = Label.new()
	_info.text = "Linksklick setzt einen Marker · Ziehen verschiebt · Mausrad zoomt"
	_info.add_theme_font_size_override("font_size", 11)
	_info.add_theme_color_override("font_color", Color(0.55, 0.57, 0.63))
	spalten.add_child(_info)


func _zeichne_liste() -> void:
	if _liste == null:
		return
	for kind in _liste.get_children():
		kind.queue_free()

	for i in waypoints.size():
		var reihe := HBoxContainer.new()
		var l := Label.new()
		var pos: Vector3 = waypoints[i]["pos"]
		l.text = "%s  (%d, %d)" % [waypoints[i]["name"], int(pos.x), int(pos.z)]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 12)
		reihe.add_child(l)

		var weg := Button.new()
		weg.text = "×"
		weg.pressed.connect(loesche_wegpunkt.bind(i))
		reihe.add_child(weg)
		_liste.add_child(reihe)


# ---------------------------------------------------------------- Eingabe

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		umschalten()
		get_viewport().set_input_as_handled()
	elif offen and event.is_action_pressed("ui_cancel"):
		schliessen()
		get_viewport().set_input_as_handled()


func umschalten() -> void:
	if offen:
		schliessen()
	else:
		oeffnen()


func oeffnen() -> void:
	offen = true
	_gross_wurzel.visible = true
	_gross_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_zentriere_auf_spieler()
	_letzte_pruefung = Vector2(1e9, 1e9)         # Umkreis auf gross_radius erweitern
	_zeichne_liste()


func schliessen() -> void:
	offen = false
	_gross_wurzel.visible = false
	_gross_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_zieht = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _zentriere_auf_spieler() -> void:
	var p := ziel.global_position
	_gross_zentrum = Vector2(p.x, p.z)


func _auf_karten_eingabe(event: InputEvent) -> void:
	# Bewusst explizit casten: GDScript verengt den Typ nach einem
	# is-Vergleich nicht, event.position wäre sonst ein Variant.
	if event is InputEventMouseButton:
		var taste := event as InputEventMouseButton
		if taste.button_index == MOUSE_BUTTON_WHEEL_UP and taste.pressed:
			_gross_zoom = clampf(_gross_zoom * 0.85, gross_zoom_min, gross_zoom_max)
		elif taste.button_index == MOUSE_BUTTON_WHEEL_DOWN and taste.pressed:
			_gross_zoom = clampf(_gross_zoom / 0.85, gross_zoom_min, gross_zoom_max)
		elif taste.button_index == MOUSE_BUTTON_LEFT:
			if taste.pressed:
				_zieht = true
				_zieh_start = taste.position
				_zieh_zentrum = _gross_zentrum
				_bewegt = 0.0
			else:
				_zieht = false
				# Kurzer Klick ohne Verschieben = Marker setzen
				if _bewegt < 5.0:
					var welt := _welt_von_bild(taste.position)
					setze_wegpunkt(welt, _name_feld.text)
					_name_feld.text = ""

	elif event is InputEventMouseMotion and _zieht:
		var bewegung := event as InputEventMouseMotion
		_bewegt += bewegung.relative.length()
		# Bildpunkte in Weltmeter: die Kamera zeigt _gross_zoom Meter Höhe
		var meter_pro_pixel: float = _gross_zoom / float(gross_viewport.y)
		var versatz: Vector2 = (bewegung.position - _zieh_start) * meter_pro_pixel
		# Schrägsicht staucht die Tiefe – beim Ziehen mit ausgleichen
		var stauchung: float = maxf(sin(deg_to_rad(neigung_grad)), 0.2)
		_gross_zentrum = _zieh_zentrum - Vector2(versatz.x, versatz.y / stauchung)


# Bildpunkt in der Kartenanzeige -> Weltposition
func _welt_von_bild(lokal: Vector2) -> Vector3:
	var skala := Vector2(_gross_vp.size) / _gross_bild.size
	var vp_pos := lokal * skala

	var von := _gross_kam.project_ray_origin(vp_pos)
	var richtung := _gross_kam.project_ray_normal(vp_pos)

	# Schnitt mit einer waagerechten Ebene auf Höhe der Kartenmitte.
	# Auf Hängen weicht das ein paar Meter ab – für Marker völlig ausreichend.
	var ebene := _y(float(_gen.hoehe_bei(int(_gross_zentrum.x),
			int(_gross_zentrum.y))))
	if absf(richtung.y) < 0.0001:
		return Vector3(_gross_zentrum.x, ebene, _gross_zentrum.y)

	var t: float = (ebene - von.y) / richtung.y
	var treffer := von + richtung * t

	var h := float(_gen.hoehe_bei(int(round(treffer.x)), int(round(treffer.z))))
	return Vector3(treffer.x, _y(_stufe(h)), treffer.z)
