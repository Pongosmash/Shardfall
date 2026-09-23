extends VoxelGeneratorScript
class_name WorldGenerator

# --- Block-Indizes ---
# Die Werte stehen in spiel/welt/bloecke.gd und werden hier nur unter den
# alten Namen weitergereicht. Nicht loeschen: deko_layer.gd liest achtzehnmal
# WorldGenerator.GRAS_KURZ und Verwandte, und die Verwendungsstellen in dieser
# Datei bleiben so unangetastet. Konstante aus Konstante kostet nichts.
# Die Umbenennung AIR -> LUFT usw. ist ein eigener Commit.
const AIR          := Bloecke.LUFT
const WATER        := Bloecke.WASSER
const GRASS        := Bloecke.GRAS
const STONE        := Bloecke.STEIN
const DIRT         := Bloecke.ERDE
const GRAS_KURZ    := Bloecke.GRAS_KURZ
const GRAS_MITTEL  := Bloecke.GRAS_MITTEL
const GRAS_HOCH    := Bloecke.GRAS_HOCH
const GRAS_TROCKEN := Bloecke.GRAS_TROCKEN
const GRAS_BUSCH   := Bloecke.GRAS_BUSCH
const BLUME_ROT    := Bloecke.BLUME_ROT
const BLUME_GELB   := Bloecke.BLUME_GELB
const BLUME_LILA   := Bloecke.BLUME_LILA
const HOLZ_EICHE   := Bloecke.HOLZ_EICHE
const HOLZ_BUCHE   := Bloecke.HOLZ_BUCHE
const HOLZ_TANNE   := Bloecke.HOLZ_TANNE
const LAUB_EICHE   := Bloecke.LAUB_EICHE
const LAUB_BUCHE   := Bloecke.LAUB_BUCHE
const LAUB_TANNE   := Bloecke.LAUB_TANNE
const FELS         := Bloecke.FELS

# Deko darf von Strukturen überschrieben werden, Terrain nicht
const DEKO_MIN := Bloecke.PFLANZE_MIN
const DEKO_MAX := Bloecke.PFLANZE_MAX

# Maximale Ausdehnung einer Struktur – so weit über den Chunkrand hinaus
# muss nach Bäumen gesucht werden. Muss zur größten Krone passen!
const STRUKTUR_RAND  := 18
const STRUKTUR_HOEHE := 44

# Noise-Objekte müssen VOR den Exports stehen: die Setter unten
# greifen bereits beim Initialisieren der Exportwerte darauf zu.
var _detail_noise := FastNoiseLite.new()
var _biome_noise  := FastNoiseLite.new()
var _river_noise  := FastNoiseLite.new()
var _patch_noise  := FastNoiseLite.new()
var _wald_noise   := FastNoiseLite.new()

# --- Terrain ---
@export var base_height := 40
@export var detail_amplitude := 6.0
@export var mountain_amplitude := 130.0
@export var mountain_rarity := 2.8
@export var sea_level := 30
@export var stone_line := 105
@export var dirt_depth := 4
@export var grat_schaerfe := 0.55       # 0 = runde Kuppen, 1 = scharfe Grate

# kleiner = größere Landschaftsformen
@export var terrain_frequenz := 0.0022:
	set(v):
		terrain_frequenz = v
		if _detail_noise:
			_detail_noise.frequency = v

# kleiner = größere Biome
@export var biom_frequenz := 0.00025:
	set(v):
		biom_frequenz = v
		if _biome_noise:
			_biome_noise.frequency = v

# --- Flüsse ---
@export var rivers_enabled := true
@export var river_width := 0.035
@export var river_depth := 5.0
@export var river_frequenz := 0.0007:
	set(v):
		river_frequenz = v
		if _river_noise:
			_river_noise.frequency = v

# --- Deko ---
# AUS (Standard): Gras und Blumen kommen von deko_layer.gd als MultiMesh und
#   erscheinen nur im Umkreis des Spielers. Die Chunk-Meshes bleiben schlank.
# AN: alte Variante, die Deko steckt als Voxel in jedem Chunk.
# Niemals beides gleichzeitig – sonst stehen die Pflanzen doppelt da.
@export var deko_als_voxel := false
@export var wiesen_schwelle := 0.44      # ab wann überhaupt Wiese entsteht
@export var deko_dichte := 0.5           # Dichte innerhalb einer Wiese
@export var blumen_anteil := 0.10

# --- Bäume ---
@export var baeume_aktiv := true
@export var baum_zelle := 10             # ein Baum je Zelle dieser Größe
@export var baum_dichte := 0.55          # Chance pro Zelle im Waldgebiet
@export var wald_schwelle := 0.46        # ab wann überhaupt Wald wächst
@export var tannen_ab := 72              # ab dieser Höhe wachsen Tannen
@export var buchen_anteil := 0.5         # Buche vs. Eiche im Tiefland
@export var anteil_2x2 := 0.30           # Chance auf einen 2x2-Stamm
@export var anteil_3x3 := 0.10           # Chance auf einen 3x3-Riesen
@export var max_hangneigung := 3         # max. Höhenunterschied unter dem Stamm
@export var wald_frequenz := 0.0012:
	set(v):
		wald_frequenz = v
		if _wald_noise:
			_wald_noise.frequency = v

# --- Steine ---
@export var steine_aktiv := true
@export var stein_zelle := 13
@export var stein_dichte := 0.35


func _init() -> void:
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail_noise.fractal_octaves = 5
	_detail_noise.fractal_lacunarity = 2.1
	_detail_noise.fractal_gain = 0.48
	_detail_noise.seed = 1
	_detail_noise.frequency = terrain_frequenz

	_biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_biome_noise.seed = 2
	_biome_noise.frequency = biom_frequenz

	_river_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_river_noise.seed = 3
	_river_noise.frequency = river_frequenz

	_patch_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_patch_noise.frequency = 0.03
	_patch_noise.seed = 4

	_wald_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_wald_noise.seed = 5
	_wald_noise.frequency = wald_frequenz


func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE


func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, _lod: int) -> void:
	out_buffer.fill(AIR, VoxelBuffer.CHANNEL_TYPE)
	var size := out_buffer.get_size()

	# Chunk komplett über allem Terrain samt Baumkronen? -> bleibt Luft
	var max_hoehe: int = base_height + int(detail_amplitude + mountain_amplitude) \
			+ STRUKTUR_HOEHE
	if origin.y > max_hoehe and origin.y > sea_level:
		return
	# Chunk komplett unter dem tiefsten Terrain? -> reiner Stein
	var min_hoehe: int = base_height - int(detail_amplitude + river_depth) - 2
	if origin.y + size.y <= min_hoehe:
		out_buffer.fill(STONE, VoxelBuffer.CHANNEL_TYPE)
		return

	for z in size.z:
		for x in size.x:
			var gx: int = origin.x + x
			var gz: int = origin.z + z
			var surface: int = _hoehe(gx, gz)

			for y in size.y:
				var gy: int = origin.y + y
				var v: int = AIR

				if gy > surface:
					if gy <= sea_level:
						v = WATER
				elif gy == surface:
					if surface >= stone_line:
						v = STONE
					elif surface <= sea_level:
						v = DIRT            # Ufer- und Flussboden
					else:
						v = GRASS
				elif gy > surface - dirt_depth:
					v = DIRT
				else:
					v = STONE

				if v != AIR:
					out_buffer.set_voxel(v, x, y, z, VoxelBuffer.CHANNEL_TYPE)

			# --- Gras und Blumen auf die Oberfläche ---
			# Nur in der alten Voxel-Variante. Sonst übernimmt deko_layer.gd.
			var plant_y: int = surface + 1
			if deko_als_voxel and surface > sea_level and surface < stone_line \
					and plant_y >= origin.y and plant_y < origin.y + size.y:
				var deko: int = _deko_fuer_spalte(gx, gz)
				if deko != AIR:
					out_buffer.set_voxel(deko, x, plant_y - origin.y, z,
							VoxelBuffer.CHANNEL_TYPE)

	_strukturen(out_buffer, origin, size)


# ---------------------------------------------------------------- Zugriff

# Öffentliche Zugänge für deko_layer.gd. Bewusst dünne Wrapper: Die Logik
# bleibt an einer Stelle, damit MultiMesh-Deko und Voxel-Deko nie
# auseinanderlaufen können.

func hoehe_bei(gx: int, gz: int) -> int:
	return _hoehe(gx, gz)


func deko_bei(gx: int, gz: int) -> int:
	return _deko_fuer_spalte(gx, gz)


# ---------------------------------------------------------------- Höhe

func _hoehe(gx: int, gz: int) -> int:
	var b: float = _biome_noise.get_noise_2d(gx, gz) * 0.5 + 0.5
	var bergigkeit: float = pow(b, mountain_rarity)
	var amp: float = detail_amplitude + bergigkeit * mountain_amplitude

	var n: float = _detail_noise.get_noise_2d(gx, gz)

	# In Bergregionen die Kuppen anheben -> Grate statt runder Hügel
	if grat_schaerfe > 0.0 and bergigkeit > 0.3:
		var scharf: float = pow(n * 0.5 + 0.5, 1.6) * 2.0 - 1.0
		var mix: float = smoothstep(0.3, 0.8, bergigkeit) * grat_schaerfe
		n = lerpf(n, scharf, mix)

	var h: float = float(base_height) + n * amp

	if rivers_enabled:
		var r: float = absf(_river_noise.get_noise_2d(gx, gz))
		var t: float = 1.0 - smoothstep(0.0, river_width, r)   # 1 = Flussmitte
		t *= 1.0 - bergigkeit                                  # keine Flüsse im Hochgebirge
		h -= t * river_depth

	return int(floor(h))


# ---------------------------------------------------------------- Deko

# Deterministischer Zufall – bleibt beim Nachladen gleich
func _hash01(x: int, z: int, salt: int) -> float:
	var h: int = x * 374761393 + z * 668265263 + salt * 1442695041
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0x7fffffff) / 2147483647.0


func _deko_fuer_spalte(gx: int, gz: int) -> int:
	var patch: float = _patch_noise.get_noise_2d(gx, gz) * 0.5 + 0.5
	if patch < wiesen_schwelle:
		return AIR                           # kahle Fläche

	var t: float = (patch - wiesen_schwelle) / maxf(0.001, 1.0 - wiesen_schwelle)
	if _hash01(gx, gz, 1) >= t * deko_dichte:
		return AIR

	if _hash01(gx, gz, 2) < blumen_anteil:
		var f: float = _hash01(gx, gz, 3)
		if f < 0.34: return BLUME_ROT
		elif f < 0.67: return BLUME_GELB
		else: return BLUME_LILA

	var g: float = _hash01(gx, gz, 4)
	if g < 0.34: return GRAS_KURZ
	elif g < 0.62: return GRAS_MITTEL
	elif g < 0.78: return GRAS_HOCH
	elif g < 0.90: return GRAS_BUSCH
	else: return GRAS_TROCKEN


# ---------------------------------------------------------------- Strukturen

# Setzt einen Voxel, sofern er im aktuellen Chunk liegt. Alles außerhalb
# wird verworfen – der Nachbarchunk stempelt denselben Baum noch einmal
# und behält dann seinen eigenen Teil.
func _setz(buf: VoxelBuffer, origin: Vector3i, size: Vector3i,
		gx: int, gy: int, gz: int, v: int, hart: bool = false) -> void:
	var lx: int = gx - origin.x
	var ly: int = gy - origin.y
	var lz: int = gz - origin.z
	if lx < 0 or ly < 0 or lz < 0 \
			or lx >= size.x or ly >= size.y or lz >= size.z:
		return
	if not hart:
		var cur: int = buf.get_voxel(lx, ly, lz, VoxelBuffer.CHANNEL_TYPE)
		# Laub verdrängt nur Luft und Gras, nicht Terrain oder Stämme
		if cur != AIR and (cur < DEKO_MIN or cur > DEKO_MAX):
			return
	buf.set_voxel(v, lx, ly, lz, VoxelBuffer.CHANNEL_TYPE)


# Tiefste und höchste Bodenhöhe unter einer dick x dick großen Grundfläche
func _boden_spanne(gx: int, gz: int, dick: int) -> Vector2i:
	var versatz: int = int(float(dick - 1) * 0.5)
	var start_x: int = gx - versatz
	var start_z: int = gz - versatz
	var tief: int = 1000000
	var hoch: int = -1000000
	for dz in dick:
		for dx in dick:
			var h: int = _hoehe(start_x + dx, start_z + dz)
			tief = mini(tief, h)
			hoch = maxi(hoch, h)
	return Vector2i(tief, hoch)


# Stamm beliebiger Dicke, zentriert um (gx, gz).
# Jede Spalte reicht bis zu ihrem eigenen Boden hinunter, damit an
# Hängen keine Ecke in der Luft hängt.
func _stamm(buf: VoxelBuffer, origin: Vector3i, size: Vector3i,
		gx: int, boden: int, gz: int, hoehe: int, dick: int, holz: int) -> void:
	var start_x: int = gx - (dick - 1) / 2
	var start_z: int = gz - (dick - 1) / 2
	var oben: int = boden + hoehe

	for dz in dick:
		for dx in dick:
			var sx: int = start_x + dx
			var sz: int = start_z + dz
			# ab der Oberfläche dieser Spalte aufwärts füllen
			var von: int = mini(_hoehe(sx, sz), boden)
			for y in range(von, oben + 1):
				_setz(buf, origin, size, sx, y, sz, holz, true)


func _strukturen(buf: VoxelBuffer, origin: Vector3i, size: Vector3i) -> void:
	if baeume_aktiv:
		_zellen(buf, origin, size, baum_zelle, true)
	if steine_aktiv:
		_zellen(buf, origin, size, stein_zelle, false)


func _zellen(buf: VoxelBuffer, origin: Vector3i, size: Vector3i,
		zelle: int, ist_baum: bool) -> void:
	var cx0: int = floori(float(origin.x - STRUKTUR_RAND) / float(zelle))
	var cx1: int = floori(float(origin.x + size.x + STRUKTUR_RAND) / float(zelle))
	var cz0: int = floori(float(origin.z - STRUKTUR_RAND) / float(zelle))
	var cz1: int = floori(float(origin.z + size.z + STRUKTUR_RAND) / float(zelle))

	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			if ist_baum:
				_vielleicht_baum(buf, origin, size, cx, cz)
			else:
				_vielleicht_stein(buf, origin, size, cx, cz)


# Entscheidet, OB und WO in dieser Zelle ein Baum steht – ohne ihn zu setzen.
# karte.gd fragt dieselbe Funktion ab, damit die Karte exakt die Bäume zeigt,
# die auch in der Welt stehen. Einzige Quelle der Wahrheit.
func baum_plan_bei(cx: int, cz: int) -> Dictionary:
	return _baum_plan(cx, cz)


func _baum_plan(cx: int, cz: int) -> Dictionary:
	if not baeume_aktiv:
		return {"da": false}

	# Großflächiges Noise entscheidet, wo überhaupt Wald steht
	var wald: float = _wald_noise.get_noise_2d(
			float(cx * baum_zelle), float(cz * baum_zelle)) * 0.5 + 0.5
	if wald < wald_schwelle:
		return {"da": false}
	var t: float = (wald - wald_schwelle) / maxf(0.001, 1.0 - wald_schwelle)
	if _hash01(cx, cz, 21) >= t * baum_dichte:
		return {"da": false}

	# Position innerhalb der Zelle -> kein sichtbares Raster
	var gx: int = cx * baum_zelle + int(_hash01(cx, cz, 22) * float(baum_zelle))
	var gz: int = cz * baum_zelle + int(_hash01(cx, cz, 23) * float(baum_zelle))

	# Stammdicke würfeln – dicke Bäume werden auch entsprechend größer
	var w: float = _hash01(cx, cz, 28)
	var dick: int = 1
	if w < anteil_3x3:
		dick = 3
	elif w < anteil_3x3 + anteil_2x2:
		dick = 2

	# Gelände unter der gesamten Stammfläche prüfen.
	# Zu steil? Erst kleineren Stamm versuchen, sonst gar keinen Baum.
	var spanne := _boden_spanne(gx, gz, dick)
	while dick > 1 and spanne.y - spanne.x > max_hangneigung:
		dick -= 1
		spanne = _boden_spanne(gx, gz, dick)
	if spanne.y - spanne.x > max_hangneigung:
		return {"da": false}

	var boden: int = spanne.x                  # tiefster Punkt = Stammfuß
	if boden <= sea_level or boden >= stone_line:
		return {"da": false}

	# 0 = Eiche, 1 = Buche, 2 = Tanne
	var art: int = 0
	if boden >= tannen_ab:
		art = 2
	elif _hash01(cx, cz, 24) < buchen_anteil:
		art = 1

	return {"da": true, "x": gx, "z": gz, "boden": boden,
			"dick": dick, "art": art}


func _vielleicht_baum(buf: VoxelBuffer, origin: Vector3i, size: Vector3i,
		cx: int, cz: int) -> void:
	var plan := _baum_plan(cx, cz)
	if not plan["da"]:
		return

	var boden: int = plan["boden"]
	if origin.y > boden + STRUKTUR_HOEHE or origin.y + size.y <= boden:
		return

	var gx: int = plan["x"]
	var gz: int = plan["z"]
	var dick: int = plan["dick"]

	match int(plan["art"]):
		2: _tanne(buf, origin, size, gx, boden, gz, cx, cz, dick)
		1: _buche(buf, origin, size, gx, boden, gz, cx, cz, dick)
		_: _eiche(buf, origin, size, gx, boden, gz, cx, cz, dick)


# Tanne: schlank, kegelförmig, in Etagen abgestuft
func _tanne(buf: VoxelBuffer, origin: Vector3i, size: Vector3i,
		gx: int, boden: int, gz: int, cx: int, cz: int, dick: int) -> void:
	var gross: float = 1.0 + float(dick - 1) * 0.85
	var hoehe: int = int(float(9 + int(_hash01(cx, cz, 25) * 6.0)) * gross)
	_stamm(buf, origin, size, gx, boden, gz, hoehe, dick, HOLZ_TANNE)

	var spitze: int = boden + hoehe
	var start: int = boden + 2
	var basis_r: float = 3.2 * gross

	for y in range(start, spitze + 2):
		var t: float = float(y - start) / float(maxi(1, spitze + 1 - start))
		var r: float = lerpf(basis_r, 0.4, t)
		# alle drei Blöcke springt der Radius zurück -> Astetagen
		var stufe: int = (spitze - y) % 3
		if stufe == 1:
			r *= 0.80
		elif stufe == 2:
			r *= 0.62

		var ri: int = int(ceil(r))
		for dz in range(-ri, ri + 1):
			for dx in range(-ri, ri + 1):
				var d: float = sqrt(float(dx * dx + dz * dz))
				if d > r:
					continue
				if d > r - 0.7 and _hash01(gx + dx, gz + dz, 30 + y) < 0.28:
					continue
				_setz(buf, origin, size, gx + dx, y, gz + dz, LAUB_TANNE)

	_setz(buf, origin, size, gx, spitze + 2, gz, LAUB_TANNE)


# Buche: hoher glatter Stamm, kompakte ovale Krone weit oben
func _buche(buf: VoxelBuffer, origin: Vector3i, size: Vector3i,
		gx: int, boden: int, gz: int, cx: int, cz: int, dick: int) -> void:
	var gross: float = 1.0 + float(dick - 1) * 0.85
	var stamm: int = int(float(7 + int(_hash01(cx, cz, 25) * 4.0)) * gross)
	_stamm(buf, origin, size, gx, boden, gz, stamm, dick, HOLZ_BUCHE)

	var mitte: int = boden + stamm + 1
	var rxz: float = (3.0 + _hash01(cx, cz, 26) * 1.5) * gross
	var ry: float = (2.6 + _hash01(cx, cz, 27) * 1.2) * gross
	_krone(buf, origin, size, gx, mitte, gz, rxz, ry, rxz, LAUB_BUCHE, 40)


# Eiche: kurzer Stamm, Äste, breite unregelmäßige Krone
func _eiche(buf: VoxelBuffer, origin: Vector3i, size: Vector3i,
		gx: int, boden: int, gz: int, cx: int, cz: int, dick: int) -> void:
	var gross: float = 1.0 + float(dick - 1) * 0.85
	var stamm: int = int(float(4 + int(_hash01(cx, cz, 25) * 3.0)) * gross)
	_stamm(buf, origin, size, gx, boden, gz, stamm, dick, HOLZ_EICHE)

	# Äste schräg nach außen – dicke Bäume bekommen mehr und längere
	var aeste: int = 2 + dick
	var laenge: int = 1 + dick
	for a in aeste:
		var w: float = TAU * (float(a) + _hash01(cx, cz, 50 + a)) / float(aeste)
		for s in laenge:
			_setz(buf, origin, size,
					gx + int(round(cos(w) * float(s + 1))),
					boden + stamm - 1 + s,
					gz + int(round(sin(w) * float(s + 1))),
					HOLZ_EICHE, true)

	var mitte: int = boden + stamm + 1
	var rxz: float = (3.6 + _hash01(cx, cz, 26) * 1.2) * gross
	var ry: float = (2.0 + _hash01(cx, cz, 27) * 0.8) * gross
	_krone(buf, origin, size, gx, mitte, gz, rxz, ry, rxz, LAUB_EICHE, 55)

	# versetzte Nebenballen brechen die Kugelform auf
	for a in 3:
		var w: float = TAU * (float(a) + _hash01(cx, cz, 60 + a)) / 3.0
		var ox: int = int(round(cos(w) * rxz * 0.55))
		var oz: int = int(round(sin(w) * rxz * 0.55))
		var oy: int = int(round((_hash01(cx, cz, 63 + a) - 0.4) * 2.0 * gross))
		_krone(buf, origin, size, gx + ox, mitte + oy, gz + oz,
				rxz * 0.6, ry * 0.7, rxz * 0.6, LAUB_EICHE, 70 + a)


func _krone(buf: VoxelBuffer, origin: Vector3i, size: Vector3i,
		mx: int, my: int, mz: int, rx: float, ry: float, rz: float,
		laub: int, salt: int) -> void:
	var ix: int = int(ceil(rx))
	var iy: int = int(ceil(ry))
	var iz: int = int(ceil(rz))
	for dy in range(-iy, iy + 1):
		for dz in range(-iz, iz + 1):
			for dx in range(-ix, ix + 1):
				var d: float = pow(float(dx) / rx, 2.0) \
						+ pow(float(dy) / ry, 2.0) \
						+ pow(float(dz) / rz, 2.0)
				if d > 1.0:
					continue
				if d > 0.55 and _hash01(mx + dx, mz + dz, salt + dy) < 0.3:
					continue
				_setz(buf, origin, size, mx + dx, my + dy, mz + dz, laub)


func _vielleicht_stein(buf: VoxelBuffer, origin: Vector3i, size: Vector3i,
		cx: int, cz: int) -> void:
	if _hash01(cx, cz, 41) >= stein_dichte:
		return

	var gx: int = cx * stein_zelle + int(_hash01(cx, cz, 42) * float(stein_zelle))
	var gz: int = cz * stein_zelle + int(_hash01(cx, cz, 43) * float(stein_zelle))
	var boden: int = _hoehe(gx, gz)

	if boden <= sea_level:
		return
	if origin.y > boden + 6 or origin.y + size.y <= boden - 2:
		return

	# unregelmäßiges Ellipsoid, halb im Boden versenkt
	var rx: float = 1.0 + _hash01(cx, cz, 44) * 2.2
	var ry: float = 0.8 + _hash01(cx, cz, 45) * 1.6
	var rz: float = 1.0 + _hash01(cx, cz, 46) * 2.2
	var mitte: int = boden + int(ry * 0.4)

	var ix: int = int(ceil(rx))
	var iy: int = int(ceil(ry))
	var iz: int = int(ceil(rz))
	for dy in range(-iy - 1, iy + 1):
		for dz in range(-iz, iz + 1):
			for dx in range(-ix, ix + 1):
				var d: float = pow(float(dx) / rx, 2.0) \
						+ pow(float(dy) / ry, 2.0) \
						+ pow(float(dz) / rz, 2.0)
				if d > 1.0:
					continue
				if d > 0.62 and _hash01(gx + dx, gz + dz, 47 + dy) < 0.3:
					continue
				_setz(buf, origin, size, gx + dx, mitte + dy, gz + dz, FELS, true)
