@tool
extends EditorScript

const MESH_DIR    := "res://assets/meshes/plants/"
const MAT_DIR     := "res://assets/materials/plants/"
const SHADER_PATH := "res://assets/materials/plants/plant_wind.gdshader"

# Kantenlänge eines "Pixels" in Blockeinheiten (0.1 = 10 Pixel pro Block)
const PIXEL := 0.1

# --- Farben: unten (Wurzel/Schatten) und oben (Spitze/Licht) ---
const MATERIALS := {
	"gras_kurz":    [Color(0.22, 0.42, 0.14), Color(0.50, 0.78, 0.28)],
	"gras_mittel":  [Color(0.19, 0.38, 0.12), Color(0.44, 0.72, 0.24)],
	"gras_hoch":    [Color(0.15, 0.31, 0.10), Color(0.38, 0.65, 0.21)],
	"gras_trocken": [Color(0.38, 0.32, 0.13), Color(0.82, 0.74, 0.38)],
	"gras_busch":   [Color(0.16, 0.36, 0.18), Color(0.40, 0.70, 0.42)],
	"stiel":        [Color(0.20, 0.40, 0.15), Color(0.34, 0.58, 0.24)],
	"bluete_rot":   [Color(0.58, 0.12, 0.16), Color(0.92, 0.28, 0.28)],
	"bluete_gelb":  [Color(0.72, 0.55, 0.10), Color(1.00, 0.88, 0.30)],
	"bluete_lila":  [Color(0.40, 0.18, 0.54), Color(0.72, 0.44, 0.88)],
}

# Wie stark sich das Material im Wind bewegt
const WIND_FAKTOR := {
	"gras_kurz": 0.7, "gras_mittel": 1.0, "gras_hoch": 1.4,
	"gras_trocken": 1.2, "gras_busch": 0.9,
	"stiel": 0.8, "bluete_rot": 0.8, "bluete_gelb": 0.8, "bluete_lila": 0.8,
}

const SHADER_CODE := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec3 farbe_unten : source_color;
uniform vec3 farbe_oben : source_color;
uniform float wind_staerke = 0.10;
uniform float wind_tempo = 1.4;
uniform vec2 wind_richtung = vec2(1.0, 0.35);
uniform float variation = 0.16;
uniform float pixel = 0.1;          // Rastergroesse fuer den Wind
uniform int farb_stufen = 4;        // Anzahl der Farbbaender

varying float v_h;
varying float v_var;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	vec3 welt = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_h = UV.y;                                   // 0 = Wurzel, 1 = Spitze

	vec2 dir = normalize(wind_richtung);
	// Phase pro Block, nicht pro Vertex -> die Pflanze bewegt sich als Ganzes
	float phase = dot(floor(welt.xz), dir) * 0.55 + TIME * wind_tempo;
	float sway = sin(phase) + 0.45 * sin(phase * 2.3 + 1.7);

	float versatz = sway * wind_staerke * pow(v_h, 1.7);
	versatz = floor(versatz / pixel + 0.5) * pixel;   // aufs Pixelraster rasten
	VERTEX.xz += dir * versatz;

	// Helligkeit pro Pflanze, ebenfalls in Stufen
	float r = floor(hash12(floor(welt.xz)) * 3.0) / 2.0;
	v_var = 1.0 + (r - 0.5) * 2.0 * variation;
}

void fragment() {
	float n = max(1.0, float(farb_stufen) - 1.0);
	float stufe = clamp(floor(v_h * float(farb_stufen)) / n, 0.0, 1.0);
	ALBEDO = mix(farbe_unten, farbe_oben, stufe) * v_var;
	ROUGHNESS = 1.0;
}
"""


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(MESH_DIR)
	DirAccess.make_dir_recursive_absolute(MAT_DIR)

	# --- Shader ---
	var sh := Shader.new()
	sh.code = SHADER_CODE
	ResourceSaver.save(sh, SHADER_PATH)
	sh.take_over_path(SHADER_PATH)
	print("OK ", SHADER_PATH)

	# --- Materialien (gleiche Pfade wie bisher) ---
	for mat_name in MATERIALS:
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("farbe_unten", MATERIALS[mat_name][0])
		mat.set_shader_parameter("farbe_oben", MATERIALS[mat_name][1])
		mat.set_shader_parameter("wind_staerke", 0.10 * float(WIND_FAKTOR[mat_name]))
		mat.set_shader_parameter("wind_tempo", 1.4)
		mat.set_shader_parameter("wind_richtung", Vector2(1.0, 0.35))
		mat.set_shader_parameter("variation", 0.16)
		mat.set_shader_parameter("pixel", PIXEL)
		mat.set_shader_parameter("farb_stufen", 4)
		var mpath: String = MAT_DIR + str(mat_name) + ".tres"
		ResourceSaver.save(mat, mpath)
		print("OK ", mpath)

	# --- Meshes ---
	var defs := [
		{ "name": "gras_kurz",    "typ": "gras", "halme": 8, "reihen": 3,
		  "breit": 2, "bend": 1, "rand": 0.10 },
		{ "name": "gras_mittel",  "typ": "gras", "halme": 9, "reihen": 5,
		  "breit": 2, "bend": 2, "rand": 0.10 },
		{ "name": "gras_hoch",    "typ": "gras", "halme": 8, "reihen": 8,
		  "breit": 2, "bend": 3, "rand": 0.10 },
		{ "name": "gras_trocken", "typ": "gras", "halme": 7, "reihen": 4,
		  "breit": 1, "bend": 3, "rand": 0.10 },
		{ "name": "gras_busch",   "typ": "gras", "halme": 12, "reihen": 6,
		  "breit": 2, "bend": 1, "rand": 0.10 },

		{ "name": "blume_rot",  "typ": "blume", "stiel": 5, "muster": [3, 5, 5, 3] },
		{ "name": "blume_gelb", "typ": "blume", "stiel": 4, "muster": [3, 5, 3] },
		{ "name": "blume_lila", "typ": "blume", "stiel": 6, "muster": [1, 3, 3] },
	]

	for d in defs:
		var mesh: ArrayMesh = null
		if d["typ"] == "gras":
			mesh = _mache_gras(d)
		else:
			mesh = _mache_blume(d)
		var path: String = MESH_DIR + str(d["name"]) + ".res"
		var err := ResourceSaver.save(mesh, path)
		print("OK " if err == OK else "FEHLER ", path,
				"  (Surfaces: ", mesh.get_surface_count(), ")")


# ---------------------------------------------------------------- Gras

func _mache_gras(d: Dictionary) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(d["name"])

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var anzahl: int = int(d["halme"])
	var rand: float = float(d["rand"])

	# Fußpunkte per Jitter-Grid: füllt die Blockfläche gleichmäßig,
	# sieht aber zufällig aus (reiner Zufall würde klumpen)
	var n: int = int(ceil(sqrt(float(anzahl))))
	var zelle: float = (1.0 - 2.0 * rand) / float(n)
	var punkte: Array[Vector2] = []
	for gz in n:
		for gx in n:
			punkte.append(Vector2(
				rand + (float(gx) + rng.randf()) * zelle,
				rand + (float(gz) + rng.randf()) * zelle))

	for i in range(punkte.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2 = punkte[i]
		punkte[i] = punkte[j]
		punkte[j] = tmp
	punkte.resize(mini(anzahl, punkte.size()))

	for p in punkte:
		# Fußpunkt aufs Pixelraster rasten
		var fuss := Vector3(_raster(p.x), 0.0, _raster(p.y))
		var reihen: int = maxi(2, int(d["reihen"]) + rng.randi_range(-1, 1))
		var bend: int = int(d["bend"]) * (1 if rng.randf() < 0.5 else -1)
		_halm(st, fuss, rng.randf() * TAU, reihen, int(d["breit"]), bend)

	st.index()
	return st.commit()


# ---------------------------------------------------------------- Blume

func _mache_blume(d: Dictionary) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(d["name"])
	var fuss := Vector3(0.5, 0.0, 0.5)
	var stiel: int = int(d["stiel"])
	var mesh: ArrayMesh = null

	# --- Surface 0: Stängel plus zwei kleine Blätter ---
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_halm(st, fuss, rng.randf() * TAU, stiel, 1, 1)
	for i in 2:
		var blatt_fuss := fuss + Vector3(0.0, PIXEL * float(1 + i), 0.0)
		_halm(st, blatt_fuss, rng.randf() * TAU, 2, 1, 2 if i == 0 else -2)
	st.index()
	mesh = st.commit(mesh)

	# --- Surface 1: Blüte ---
	var stb := SurfaceTool.new()
	stb.begin(Mesh.PRIMITIVE_TRIANGLES)
	_bluete(stb, fuss + Vector3(0.0, PIXEL * float(stiel), 0.0), d["muster"])
	stb.index()
	mesh = stb.commit(mesh)

	return mesh


# ---------------------------------------------------------------- Bausteine

func _raster(w: float) -> float:
	return round(w / PIXEL) * PIXEL


# Ein Halm aus gestapelten Pixelreihen. Jede Reihe ist ein eigenes Quad
# mit einheitlichem UV.y -> sie bewegt sich im Wind als starrer Pixel
# und bekommt eine einzige, flache Farbe.
func _halm(st: SurfaceTool, fuss: Vector3, winkel: float,
		reihen: int, breit_px: int, bend_px: int) -> void:
	var perp := Vector3(cos(winkel), 0.0, sin(winkel))
	var teiler: int = maxi(1, reihen - 1)

	for i in reihen:
		var t: float = (float(i) + 0.5) / float(reihen)
		# verjüngt sich stufenweise nach oben
		var w: int = breit_px - int(round(float(breit_px - 1)
				* float(i) / float(teiler)))
		# Krümmung, ebenfalls in ganzen Pixeln
		var off: int = int(round(float(bend_px) * t * t))
		var unten := fuss + Vector3(0.0, float(i) * PIXEL, 0.0) \
				+ perp * (float(off) * PIXEL)
		_pixel_quad(st, unten, perp, w, t)


# Blüte: zwei gekreuzte Pixelmuster, damit sie aus jeder Richtung gleich wirkt
func _bluete(st: SurfaceTool, basis: Vector3, muster: Array) -> void:
	for ebene in 2:
		var w: float = PI * 0.5 * float(ebene)
		var perp := Vector3(cos(w), 0.0, sin(w))
		for i in muster.size():
			var t: float = 0.55 + 0.45 * (float(i) + 0.5) / float(muster.size())
			var unten := basis + Vector3(0.0, float(i) * PIXEL, 0.0)
			_pixel_quad(st, unten, perp, int(muster[i]), t)


# Ein einzelnes Pixel-Quad, beidseitig sichtbar.
# 'unten' ist die untere Mitte, 'perp' die Breitenachse.
func _pixel_quad(st: SurfaceTool, unten: Vector3, perp: Vector3,
		breite_px: int, t: float) -> void:
	var halb: float = float(breite_px) * PIXEL * 0.5
	var hoch := Vector3(0.0, PIXEL * 1.02, 0.0)     # minimal überlappen
	var a := unten - perp * halb
	var b := unten + perp * halb
	var pts := [a, b, b + hoch, a + hoch]

	for idx in [0, 1, 2, 0, 2, 3]:          # Vorderseite
		_add(st, pts[idx], t)
	for idx in [0, 2, 1, 0, 3, 2]:          # Rückseite
		_add(st, pts[idx], t)


func _add(st: SurfaceTool, p: Vector3, t: float) -> void:
	st.set_color(Color.WHITE)
	st.set_normal(Vector3.UP)               # flach = gleichmäßige Beleuchtung
	st.set_uv(Vector2(0.0, t))              # einheitlich pro Pixel
	st.add_vertex(p)
