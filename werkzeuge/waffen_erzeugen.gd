@tool
extends EditorScript

# werkzeuge/waffen_erzeugen.gd
#
# Erzeugt fuenf Waffen als Mesh und als WaffenDaten-Ressource. Gegenstueck zu
# make_plants.gd: die Meshes entstehen aus Quadern im Code, nicht aus einer
# Modellierdatei - passend zur Wuerfeloptik der Figuren.
#
# Ausfuehren: im Editor Datei -> Ausfuehren (Strg+Umschalt+X), dieses Skript
# waehlen. Laeuft nie im Spiel.
#
# Legt an:
#   assets/materials/waffen_material.tres   ein Material fuer alle Waffen
#   assets/meshes/waffen/*.res              fuenf Meshes
#   daten/waffen/*.tres                     fuenf WaffenDaten
#
# UEBERSCHREIBEN steht auf false: vorhandene Dateien bleiben unangetastet und
# werden nur gemeldet. Wer eine Waffe im Inspektor nachjustiert hat, verliert
# sie also nicht beim zweiten Lauf.
#
# Alle fuenf Stil-Werte sind einmal belegt (FAUST hat schon faust.tres), damit
# die Posentabelle in character_visual.gd vollstaendig durchgetestet wird.
#
# Achtung Wickelrichtung: Godot nimmt bei Dreiecken die im Uhrzeigersinn
# gewickelte Seite als Vorderseite. Sollten die Waffen von aussen hohl
# aussehen, in _quader() die Reihenfolge der beiden Dreiecke umdrehen.


const SCHREIBEN := true
const UEBERSCHREIBEN := false

const MESH_DIR := "res://assets/meshes/waffen/"
const MAT_PFAD := "res://assets/materials/waffen_material.tres"
const WAFFEN_DIR := "res://daten/waffen/"

# Farben stecken als Vertexfarbe im Mesh, ein Material reicht fuer alles.
const STAHL := Color(0.74, 0.77, 0.82)
const EISEN := Color(0.36, 0.38, 0.42)
const HOLZ := Color(0.42, 0.29, 0.17)
const LEDER := Color(0.25, 0.18, 0.13)


# --------------------------------------------------------------------------
# Ablauf
# --------------------------------------------------------------------------

func _run() -> void:
	_verzeichnis_sichern(MESH_DIR)
	_verzeichnis_sichern(WAFFEN_DIR)

	var material := _material_bauen()
	if material == null:
		push_error("[Waffen] Material fehlgeschlagen, Abbruch.")
		return

	var gebaut := 0
	var uebersprungen := 0

	for eintrag in _tabelle():
		var mesh := _mesh_bauen(eintrag["quader"], material)
		var mesh_pfad: String = MESH_DIR + eintrag["datei"] + ".res"
		if _speichern(mesh, mesh_pfad):
			pass
		else:
			uebersprungen += 1

		var waffe := _waffe_bauen(eintrag, mesh_pfad)
		var waffen_pfad: String = WAFFEN_DIR + eintrag["datei"] + ".tres"
		if _speichern(waffe, waffen_pfad):
			gebaut += 1
		else:
			uebersprungen += 1

	print("[Waffen] fertig: %d geschrieben, %d uebersprungen" % [gebaut, uebersprungen])
	if not SCHREIBEN:
		print("[Waffen] SCHREIBEN steht auf false - es wurde nichts angelegt.")
	print("[Waffen] Danach einmal Projekt -> Ressourcen neu importieren, damit")
	print("         die .tres im Dateisystem auftauchen.")


# --------------------------------------------------------------------------
# Die Waffentabelle
# --------------------------------------------------------------------------
#
# reichweite/treffer_radius in Metern, angriff_dauer/nachziehzeit in Sekunden.
# treffer_start und treffer_ende sind Anteile von angriff_dauer (0..1) - genau
# das, was schlag_marken() an character_visual.gd weiterreicht.

func _tabelle() -> Array:
	return [
		{
			"datei": "kurzschwert",
			"name": "Kurzschwert",
			"beschreibung": "Schnell, kurz, verzeiht wenig Abstand.",
			"slot": WaffenDaten.Slot.HAND_RECHTS,
			"griff": WaffenDaten.Griff.EINHAND,
			"stil": WaffenDaten.Stil.STICH,
			"schadensart": WaffenDaten.Schadensart.STICH,
			"schaden": 14.0,
			"kritisch_multiplikator": 2.8,
			"reichweite": 1.9,
			"treffer_radius": 0.55,
			"wucht": 2.0,
			"angriff_dauer": 0.42,
			"treffer_start": 0.34,
			"treffer_ende": 0.60,
			"nachziehzeit": 0.12,
			"kombo_schritte": 3,
			"kombo_fenster": 0.45,
			"ausdauer_kosten": 8.0,
			"kann_blocken": true,
			"block_durchlass": 0.35,
			"block_ausdauer_kosten": 10.0,
			"quader": [
				[Vector3(0, 0, 0.14), Vector3(0.07, 0.07, 0.05), EISEN],
				[Vector3(0, 0, 0.06), Vector3(0.055, 0.055, 0.16), LEDER],
				[Vector3(0, 0, -0.03), Vector3(0.24, 0.06, 0.06), EISEN],
				[Vector3(0, 0, -0.38), Vector3(0.035, 0.09, 0.70), STAHL],   # Klinge
				[Vector3(0, 0, -0.76), Vector3(0.03, 0.05, 0.06), STAHL],    # Spitze
			],
		},
		{
			"datei": "axt",
			"name": "Axt",
			"beschreibung": "Traeger als ein Schwert, dafuer reisst sie Deckung auf.",
			"slot": WaffenDaten.Slot.HAND_RECHTS,
			"griff": WaffenDaten.Griff.EINHAND,
			"stil": WaffenDaten.Stil.HIEB,
			"schadensart": WaffenDaten.Schadensart.SCHNITT,
			"schaden": 20.0,
			"kritisch_multiplikator": 2.5,
			"reichweite": 1.8,
			"treffer_radius": 0.60,
			"wucht": 4.5,
			"angriff_dauer": 0.55,
			"treffer_start": 0.40,
			"treffer_ende": 0.65,
			"nachziehzeit": 0.20,
			"kombo_schritte": 3,
			"kombo_fenster": 0.40,
			"ausdauer_kosten": 12.0,
			"kann_blocken": true,
			"block_durchlass": 0.40,
			"block_ausdauer_kosten": 12.0,
			"quader": [
				[Vector3(0, 0, -0.20), Vector3(0.06, 0.06, 0.70), HOLZ],
				[Vector3(0, 0.10, -0.46), Vector3(0.09, 0.22, 0.14), EISEN],
				[Vector3(0, 0.10, -0.56), Vector3(0.05, 0.30, 0.07), STAHL],
			],
		},
		{
			"datei": "zweihaender",
			"name": "Zweihaender",
			"beschreibung": "Langsam und teuer, trifft dafuer alles vor sich.",
			"slot": WaffenDaten.Slot.HAND_RECHTS,
			"griff": WaffenDaten.Griff.ZWEIHAND,
			"stil": WaffenDaten.Stil.SCHWUNG_SCHWER,
			"schadensart": WaffenDaten.Schadensart.SCHNITT,
			"schaden": 34.0,
			"kritisch_multiplikator": 2.2,
			"reichweite": 2.6,
			"treffer_radius": 0.80,
			"wucht": 8.0,
			"angriff_dauer": 0.85,
			"treffer_start": 0.45,
			"treffer_ende": 0.75,
			"nachziehzeit": 0.45,
			"kombo_schritte": 2,
			"kombo_fenster": 0.50,
			"ausdauer_kosten": 22.0,
			"kann_blocken": true,
			"block_durchlass": 0.30,
			"block_ausdauer_kosten": 14.0,
			"quader": [
				[Vector3(0, 0, 0.24), Vector3(0.09, 0.09, 0.07), EISEN],
				[Vector3(0, 0, 0.12), Vector3(0.06, 0.06, 0.28), LEDER],
				[Vector3(0, 0, -0.04), Vector3(0.36, 0.07, 0.07), EISEN],
				[Vector3(0, 0, -0.62), Vector3(0.04, 0.13, 1.10), STAHL],    # Klinge
				[Vector3(0, 0, -1.22), Vector3(0.035, 0.07, 0.10), STAHL],   # Spitze
			],
		},
		{
			"datei": "speer",
			"name": "Speer",
			"beschreibung": "Haelt auf Abstand. Wenig Schaden, viel Reichweite.",
			"slot": WaffenDaten.Slot.HAND_RECHTS,
			"griff": WaffenDaten.Griff.ZWEIHAND,
			"stil": WaffenDaten.Stil.STANGE,
			"schadensart": WaffenDaten.Schadensart.STICH,
			"schaden": 18.0,
			"kritisch_multiplikator": 2.6,
			"reichweite": 3.1,
			"treffer_radius": 0.45,
			"wucht": 3.0,
			"angriff_dauer": 0.50,
			"treffer_start": 0.30,
			"treffer_ende": 0.50,
			"nachziehzeit": 0.18,
			"kombo_schritte": 2,
			"kombo_fenster": 0.40,
			"ausdauer_kosten": 11.0,
			"kann_blocken": true,
			"block_durchlass": 0.50,
			"block_ausdauer_kosten": 12.0,
			"quader": [
				[Vector3(0, 0, -0.55), Vector3(0.05, 0.05, 1.60), HOLZ],
				[Vector3(0, 0, -1.28), Vector3(0.065, 0.065, 0.10), LEDER],
				[Vector3(0, 0, -1.46), Vector3(0.035, 0.07, 0.28), STAHL],
				[Vector3(0, 0, -1.63), Vector3(0.035, 0.025, 0.08), STAHL],
			],
		},
		{
			"datei": "holzschild",
			"name": "Holzschild",
			"beschreibung": "Schluckt fast alles, kostet dafuer die Nebenhand.",
			"slot": WaffenDaten.Slot.HAND_LINKS,
			"griff": WaffenDaten.Griff.SCHILD,
			"stil": WaffenDaten.Stil.FAUST,
			"schadensart": WaffenDaten.Schadensart.STUMPF,
			"schaden": 6.0,
			"kritisch_multiplikator": 1.5,
			"reichweite": 1.4,
			"treffer_radius": 0.50,
			"wucht": 3.5,
			"angriff_dauer": 0.60,
			"treffer_start": 0.40,
			"treffer_ende": 0.60,
			"nachziehzeit": 0.30,
			"kombo_schritte": 1,
			"kombo_fenster": 0.30,
			"ausdauer_kosten": 6.0,
			"kann_blocken": true,
			"block_durchlass": 0.10,
			"block_ausdauer_kosten": 5.0,
			"quader": [
				[Vector3(0, 0, -0.06), Vector3(0.52, 0.68, 0.07), HOLZ],
				[Vector3(0, 0.36, -0.06), Vector3(0.54, 0.05, 0.09), EISEN],
				[Vector3(0, -0.36, -0.06), Vector3(0.54, 0.05, 0.09), EISEN],
				[Vector3(0, 0, -0.13), Vector3(0.14, 0.14, 0.08), EISEN],
			],
		},
	]


# --------------------------------------------------------------------------
# WaffenDaten zusammensetzen
# --------------------------------------------------------------------------
#
# Alle Felder stehen hier als echte Zuweisung, nicht als set("name", wert).
# Absicht: ein falscher Feldname bricht schon beim Parsen des Skripts mit
# Zeilenangabe ab, statt still ins Leere zu laufen.

func _waffe_bauen(d: Dictionary, mesh_pfad: String) -> WaffenDaten:
	var w := WaffenDaten.new()

	w.anzeige_name = d["name"]
	w.beschreibung = d["beschreibung"]
	w.slot = d["slot"]
	w.griff = d["griff"]

	w.mesh = load(mesh_pfad)

	w.stil = d["stil"]
	w.schadensart = d["schadensart"]
	w.schaden = d["schaden"]
	w.kritisch_multiplikator = d["kritisch_multiplikator"]
	w.reichweite = d["reichweite"]
	w.treffer_radius = d["treffer_radius"]
	w.wucht = d["wucht"]

	w.angriff_dauer = d["angriff_dauer"]
	w.treffer_start = d["treffer_start"]
	w.treffer_ende = d["treffer_ende"]
	w.nachziehzeit = d["nachziehzeit"]
	w.kombo_schritte = d["kombo_schritte"]
	w.kombo_fenster = d["kombo_fenster"]

	w.ausdauer_kosten = d["ausdauer_kosten"]
	w.kann_blocken = d["kann_blocken"]
	w.block_durchlass = d["block_durchlass"]
	w.block_ausdauer_kosten = d["block_ausdauer_kosten"]

	w.resource_name = d["name"]
	return w


# --------------------------------------------------------------------------
# Mesh und Material
# --------------------------------------------------------------------------

func _material_bauen() -> StandardMaterial3D:
	if ResourceLoader.exists(MAT_PFAD):
		return load(MAT_PFAD) as StandardMaterial3D

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.55
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

	if _speichern(mat, MAT_PFAD):
		return load(MAT_PFAD) as StandardMaterial3D
	return mat


func _mesh_bauen(quader: Array, material: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in quader:
		_quader(st, q[0], q[1], q[2])
	st.index()
	st.set_material(material)
	return st.commit()


# Ein achsenparalleler Quader, sechs Flaechen einzeln, damit die Normalen hart
# bleiben und die Kanten scharf aussehen. Ecken im Uhrzeigersinn von aussen.
func _quader(st: SurfaceTool, mitte: Vector3, groesse: Vector3, farbe: Color) -> void:
	var h := groesse * 0.5

	var flaechen := [
		[Vector3(0, 0, 1), Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, -1, 1), Vector3(-1, -1, 1)],
		[Vector3(0, 0, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, -1), Vector3(1, -1, -1)],
		[Vector3(1, 0, 0), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1)],
		[Vector3(-1, 0, 0), Vector3(-1, 1, -1), Vector3(-1, 1, 1), Vector3(-1, -1, 1), Vector3(-1, -1, -1)],
		[Vector3(0, 1, 0), Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)],
		[Vector3(0, -1, 0), Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(-1, -1, -1)],
	]

	for f in flaechen:
		var n: Vector3 = f[0]
		var a := mitte + (f[1] as Vector3) * h
		var b := mitte + (f[2] as Vector3) * h
		var c := mitte + (f[3] as Vector3) * h
		var d := mitte + (f[4] as Vector3) * h
		_dreieck(st, n, farbe, a, b, c)
		_dreieck(st, n, farbe, a, c, d)


func _dreieck(st: SurfaceTool, n: Vector3, farbe: Color, a: Vector3, b: Vector3, c: Vector3) -> void:
	for p in [a, b, c]:
		st.set_normal(n)
		st.set_color(farbe)
		st.add_vertex(p)


# --------------------------------------------------------------------------
# Dateien
# --------------------------------------------------------------------------

func _verzeichnis_sichern(pfad: String) -> void:
	if DirAccess.dir_exists_absolute(pfad):
		return
	var fehler := DirAccess.make_dir_recursive_absolute(pfad)
	if fehler != OK:
		push_error("[Waffen] Verzeichnis %s nicht anlegbar (Fehler %d)" % [pfad, fehler])
	else:
		print("[Waffen] Verzeichnis angelegt: ", pfad)


func _speichern(res: Resource, pfad: String) -> bool:
	if not SCHREIBEN:
		print("[Waffen] (Probelauf) wuerde schreiben: ", pfad)
		return false

	if ResourceLoader.exists(pfad) and not UEBERSCHREIBEN:
		print("[Waffen] vorhanden, bleibt: ", pfad)
		return false

	var fehler := ResourceSaver.save(res, pfad)
	if fehler != OK:
		push_error("[Waffen] %s nicht speicherbar (Fehler %d)" % [pfad, fehler])
		return false

	print("[Waffen] geschrieben: ", pfad)
	return true
