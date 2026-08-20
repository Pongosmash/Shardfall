extends Node3D
class_name DekoLayer

# Rendert Gras und Blumen NUR im Umkreis des Spielers, als MultiMesh statt als
# Voxel. Vorteile gegenüber der Blockvariante:
#
# - acht Draw Calls insgesamt statt Geometrie in jedem Chunk-Mesh
# - die Sichtweite der Deko ist unabhängig von der des Terrains
# - Chunks müssen nicht neu gebaut werden, wenn sich die Dichte ändert
# - am Rand schrumpfen die Pflanzen in den Boden, statt aufzupoppen
#
# Die Platzierung stammt aus derselben Funktion wie vorher
# (WorldGenerator.deko_bei), das Ergebnis ist also identisch und
# deterministisch – nur eben zur Laufzeit abgetastet.
#
# Voraussetzung: In world_generator.gd muss 'deko_als_voxel' AUS sein,
# sonst stehen die Pflanzen doppelt da.

@export_group("Referenzen")
@export var terrain: VoxelTerrain              # VoxelTerrain hier reinziehen
@export var ziel: Node3D                       # Player hier reinziehen
@export var mesh_verzeichnis: String = "res://assets/meshes/plants/"
@export var material_verzeichnis: String = "res://assets/materials/plants/"

@export_group("Sichtbarkeit")
## Radius in Blöcken, in dem Deko dargestellt wird
@export var radius: float = 48.0
## Auf den letzten Metern schrumpfen die Pflanzen in den Boden statt aufzupoppen
@export var uebergang: float = 12.0
## Ab dieser Bewegung des Spielers wird neu aufgebaut
@export var nachlade_abstand: float = 8.0

@export_group("Leistung")
## Spalten pro Bild beim Aufbau. Kleiner = weichere Verteilung, längerer Aufbau.
@export var spalten_pro_frame: int = 900
## Pflanzen werfen keine Schatten – das ist der größte einzelne Gewinn
@export var schatten: bool = false
## Zufällige 90-Grad-Drehung. Bleibt aufs Pixelraster ausgerichtet.
@export var zufalls_drehung: bool = true

@export_group("Diagnose")
## Schreibt nach dem ersten Aufbau eine Zusammenfassung in die Ausgabe
@export var debug: bool = true
## Ersetzt die Pflanzenmaterialien durch grelles Magenta – zeigt, ob das
## Problem bei der Platzierung liegt oder beim Material und Shader.
@export var debug_ersatzmaterial: bool = false

# Block-Index -> Materialien je Surface.
# Blumen haben zwei Surfaces: 0 = Stiel und Blätter, 1 = Blüte.
const MATERIALIEN := {
	WorldGenerator.GRAS_KURZ:    ["gras_kurz"],
	WorldGenerator.GRAS_MITTEL:  ["gras_mittel"],
	WorldGenerator.GRAS_HOCH:    ["gras_hoch"],
	WorldGenerator.GRAS_TROCKEN: ["gras_trocken"],
	WorldGenerator.GRAS_BUSCH:   ["gras_busch"],
	WorldGenerator.BLUME_ROT:    ["stiel", "bluete_rot"],
	WorldGenerator.BLUME_GELB:   ["stiel", "bluete_gelb"],
	WorldGenerator.BLUME_LILA:   ["stiel", "bluete_lila"],
}

# Block-Index -> Dateiname des Meshes
const DATEI := {
	WorldGenerator.GRAS_KURZ: "gras_kurz",
	WorldGenerator.GRAS_MITTEL: "gras_mittel",
	WorldGenerator.GRAS_HOCH: "gras_hoch",
	WorldGenerator.GRAS_TROCKEN: "gras_trocken",
	WorldGenerator.GRAS_BUSCH: "gras_busch",
	WorldGenerator.BLUME_ROT: "blume_rot",
	WorldGenerator.BLUME_GELB: "blume_gelb",
	WorldGenerator.BLUME_LILA: "blume_lila",
}

var _generator: WorldGenerator = null
var _instanzen: Dictionary = {}                # block_index -> MultiMeshInstance3D
var _bau: Dictionary = {}                      # block_index -> Array[Transform3D]

var _bau_laeuft: bool = false
var _bau_index: int = 0
var _bau_seite: int = 0
var _bau_min: Vector2i = Vector2i.ZERO
var _bau_zentrum: Vector2 = Vector2.ZERO
var _letztes_zentrum: Vector2 = Vector2(1e9, 1e9)
var _erster_bau: bool = true
var _mit_deko: int = 0
var _verworfen_hoehe: int = 0


func _ready() -> void:
	# Unabhängig davon, wo der Knoten in der Szene hängt: Die Transforms werden
	# in Weltkoordinaten gerechnet. Ohne top_level würde ein Elternknoten mit
	# eigener Position (etwa der Player) alles verschieben.
	top_level = true
	global_transform = Transform3D.IDENTITY

	if terrain == null:
		push_error("DekoLayer: Feld 'terrain' ist nicht zugewiesen!")
		set_process(false)
		return
	if ziel == null:
		push_error("DekoLayer: Feld 'ziel' ist nicht zugewiesen!")
		set_process(false)
		return

	_generator = terrain.generator as WorldGenerator
	if _generator == null:
		push_error("DekoLayer: Der VoxelTerrain-Generator ist kein WorldGenerator "
				+ "(Generator im VoxelTerrain-Inspector prüfen).")
		set_process(false)
		return
	if not _generator.has_method("deko_bei"):
		push_error("DekoLayer: world_generator.gd ist nicht aktuell – "
				+ "es fehlen 'deko_bei' und 'hoehe_bei'.")
		set_process(false)
		return
	if _generator.get("deko_als_voxel") == true:
		push_warning("DekoLayer: 'deko_als_voxel' ist im Generator noch AN – "
				+ "die Pflanzen stehen jetzt doppelt.")

	_baue_instanzen()

	if _instanzen.is_empty():
		push_error("DekoLayer: Keine einzige Pflanzenmesh geladen. "
				+ "Pfad prüfen: " + mesh_verzeichnis)
		set_process(false)


# Legt je Pflanzentyp genau eine MultiMeshInstance3D an.
func _baue_instanzen() -> void:
	for index in DATEI:
		var pfad: String = mesh_verzeichnis + str(DATEI[index]) + ".res"
		if not ResourceLoader.exists(pfad):
			push_error("DekoLayer: Datei fehlt -> " + pfad)
			continue

		var quelle := load(pfad) as ArrayMesh
		if quelle == null:
			push_error("DekoLayer: Datei ist keine ArrayMesh -> " + pfad)
			continue
		if quelle.get_surface_count() == 0:
			push_error("DekoLayer: Mesh hat keine Surfaces -> " + pfad)
			continue

		var mesh := _kopiere_mesh(quelle, index)

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = 0

		var mi := MultiMeshInstance3D.new()
		mi.name = "Deko_" + str(DATEI[index])
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if schatten \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Ohne Rand würde die Instanz weggecullt, sobald ihr Ursprung außerhalb
		# des Sichtkegels liegt – alle Pflanzen wären dann auf einmal weg.
		mi.extra_cull_margin = radius + uebergang
		add_child(mi)
		_instanzen[index] = mi

		if debug:
			print("[Deko] geladen: %s (%d Surfaces)"
					% [DATEI[index], mesh.get_surface_count()])


# Surfaces einzeln übernehmen statt duplicate(): ArrayMesh.duplicate() verliert
# je nach Godot-Version die Surface-Daten und liefert ein leeres Mesh.
func _kopiere_mesh(quelle: ArrayMesh, index: int) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var mats: Array = MATERIALIEN.get(index, [])

	for s in quelle.get_surface_count():
		mesh.add_surface_from_arrays(quelle.surface_get_primitive_type(s),
				quelle.surface_get_arrays(s))

		var mat: Material = null
		if debug_ersatzmaterial:
			var ersatz := StandardMaterial3D.new()
			ersatz.albedo_color = Color(1.0, 0.0, 0.8)
			ersatz.cull_mode = BaseMaterial3D.CULL_DISABLED
			ersatz.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat = ersatz
		elif s < mats.size():
			var mp: String = material_verzeichnis + str(mats[s]) + ".tres"
			if ResourceLoader.exists(mp):
				mat = load(mp) as Material
			else:
				push_warning("DekoLayer: Material fehlt -> " + mp)

		# Ohne Material wäre die Fläche weiß – lieber ein sichtbares
		# Ersatzmaterial als gar nichts.
		if mat == null:
			var fallback := StandardMaterial3D.new()
			fallback.albedo_color = Color(0.35, 0.62, 0.22)
			fallback.cull_mode = BaseMaterial3D.CULL_DISABLED
			fallback.roughness = 1.0
			mat = fallback

		mesh.surface_set_material(s, mat)

	return mesh


func _process(_delta: float) -> void:
	if _generator == null:
		return

	if _bau_laeuft:
		_bau_schritt()
		return

	var p := ziel.global_position
	var jetzt := Vector2(p.x, p.z)
	if jetzt.distance_to(_letztes_zentrum) >= nachlade_abstand:
		_starte_bau(jetzt)


# ---------------------------------------------------------------- Aufbau

func _starte_bau(zentrum: Vector2) -> void:
	_bau_zentrum = zentrum
	_bau_seite = int(radius * 2.0) + 1
	_bau_min = Vector2i(int(floor(zentrum.x - radius)),
			int(floor(zentrum.y - radius)))
	_bau_index = 0
	_bau_laeuft = true
	_mit_deko = 0
	_verworfen_hoehe = 0

	_bau.clear()
	for index in DATEI:
		_bau[index] = []


# Arbeitet ein Kontingent an Spalten ab. Die alten Instanzen bleiben so lange
# stehen, bis alles fertig ist – dadurch flackert nichts.
func _bau_schritt() -> void:
	var gesamt: int = _bau_seite * _bau_seite
	var ende: int = mini(_bau_index + spalten_pro_frame, gesamt)
	var r2: float = radius * radius

	while _bau_index < ende:
		var lx: int = _bau_index % _bau_seite
		var lz: int = _bau_index / _bau_seite
		_bau_index += 1

		var gx: int = _bau_min.x + lx
		var gz: int = _bau_min.y + lz

		var dx: float = float(gx) + 0.5 - _bau_zentrum.x
		var dz: float = float(gz) + 0.5 - _bau_zentrum.y
		var d2: float = dx * dx + dz * dz
		if d2 > r2:
			continue

		var deko: int = _generator.deko_bei(gx, gz)
		if deko == WorldGenerator.AIR:
			continue
		_mit_deko += 1

		var boden: int = _generator.hoehe_bei(gx, gz)
		if boden <= _generator.sea_level or boden >= _generator.stone_line:
			_verworfen_hoehe += 1
			continue

		# Am Rand kleiner werden lassen statt hart aufzupoppen
		var d: float = sqrt(d2)
		var s: float = clampf((radius - d) / maxf(uebergang, 0.001), 0.0, 1.0)
		if s < 0.06:
			continue

		var basis := Basis()
		if zufalls_drehung:
			var k: int = int(_hash01(gx, gz, 91) * 4.0) % 4
			basis = Basis(Vector3.UP, PI * 0.5 * float(k))
		basis = basis.scaled(Vector3(s, s, s))

		# Der Ursprung der Pflanzenmeshes liegt in der Blockecke, gedreht wird
		# aber um die Blockmitte – daher der Rückversatz.
		var mitte := Vector3(float(gx) + 0.5, float(boden + 1), float(gz) + 0.5)
		var t := Transform3D(basis, mitte - basis * Vector3(0.5, 0.0, 0.5))

		if not _bau.has(deko):
			continue                       # unbekannter Deko-Index
		_bau[deko].append(t)

	if _bau_index >= gesamt:
		_uebernehmen()


func _uebernehmen() -> void:
	var summe := 0
	for index in _instanzen:
		var liste: Array = _bau.get(index, [])
		var mm: MultiMesh = _instanzen[index].multimesh
		mm.instance_count = liste.size()
		for i in liste.size():
			mm.set_instance_transform(i, liste[i])
		summe += liste.size()

	_bau.clear()
	_bau_laeuft = false
	_letztes_zentrum = _bau_zentrum

	if debug and (_erster_bau or summe == 0):
		_erster_bau = false
		print("[Deko] Zentrum %s | Spalten mit Deko: %d | wegen Höhe verworfen: %d"
				% [str(_bau_zentrum), _mit_deko, _verworfen_hoehe])
		print("[Deko] gesetzte Pflanzen: %d" % summe)
		if summe == 0:
			print("[Deko] Nichts gesetzt. Steht der Spieler zwischen "
					+ "sea_level (%d) und stone_line (%d)?"
					% [_generator.sea_level, _generator.stone_line])


# Gleiche Formel wie im Generator, damit die Drehung reproduzierbar ist
func _hash01(x: int, z: int, salt: int) -> float:
	var h: int = x * 374761393 + z * 668265263 + salt * 1442695041
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0x7fffffff) / 2147483647.0


# ---------------------------------------------------------------- Werkzeug

# Erzwingt einen Neuaufbau, z. B. nach dem Respawn oder wenn du Dichtewerte
# im Generator zur Laufzeit änderst.
func neu_aufbauen() -> void:
	_letztes_zentrum = Vector2(1e9, 1e9)


func anzahl_pflanzen() -> int:
	var summe := 0
	for index in _instanzen:
		summe += _instanzen[index].multimesh.instance_count
	return summe
