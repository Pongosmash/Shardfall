extends Node
class_name Inventar

# Datenhaltung für Inventar und Ausrüstung.
# Hängt als Kindknoten "Inventar" unter dem Player – genau wie "Combat".
# Kennt keine Oberfläche: inventar_ui.gd liest hier und reagiert auf die Signale.

signal geaendert                      # ein Inventarplatz hat sich verändert
signal ausruestung_geaendert          # ein Ausrüstungsslot hat sich verändert

# Reihenfolge bestimmt die Anzeige in der Oberfläche
const SLOTS := ["kopf", "amulett", "ruestung", "haende", "fuesse",
		"ring1", "ring2", "haupthand", "nebenhand"]

const SLOT_TITEL := {
	"kopf": "Helm", "amulett": "Amulett", "ruestung": "Rüstung",
	"haende": "Handschuhe", "fuesse": "Stiefel",
	"ring1": "Ring I", "ring2": "Ring II",
	"haupthand": "Haupthand", "nebenhand": "Nebenhand",
}

@export var plaetze_anzahl: int = 40
## Füllt das Inventar beim Start mit Testitems aus item_katalog.gd
@export var start_items_geben: bool = true

# Je Eintrag entweder null oder { "daten": ItemDaten, "menge": int }
var plaetze: Array = []
var ausruestung: Dictionary = {}

var _player = null                    # bewusst ohne Typ (Zyklus vermeiden)


func _ready() -> void:
	_player = get_parent()
	add_to_group("inventar")

	plaetze.resize(plaetze_anzahl)
	for i in plaetze_anzahl:
		plaetze[i] = null
	for schluessel in SLOTS:
		ausruestung[schluessel] = null

	if start_items_geben:
		for eintrag in ItemKatalog.start_items():
			hinzufuegen(eintrag[0], eintrag[1])


# ---------------------------------------------------------------- Abfragen

func hole(index: int):
	if index < 0 or index >= plaetze.size():
		return null
	return plaetze[index]


func hole_ausruestung(schluessel: String):
	return ausruestung.get(schluessel, null)


func ist_leer(index: int) -> bool:
	return hole(index) == null


# Passt der Gegenstand in diesen Ausrüstungsslot?
func passt(daten: ItemDaten, schluessel: String) -> bool:
	if daten == null:
		return false
	match schluessel:
		"kopf": return daten.slot == ItemDaten.Slot.KOPF
		"ruestung": return daten.slot == ItemDaten.Slot.RUESTUNG
		"haende": return daten.slot == ItemDaten.Slot.HAENDE
		"fuesse": return daten.slot == ItemDaten.Slot.FUESSE
		"amulett": return daten.slot == ItemDaten.Slot.AMULETT
		"ring1", "ring2": return daten.slot == ItemDaten.Slot.RING
		"haupthand": return daten.slot == ItemDaten.Slot.HAUPTHAND
		"nebenhand": return daten.slot == ItemDaten.Slot.NEBENHAND
	return false


# ---------------------------------------------------------------- Ablegen

# Gibt zurück, wieviel NICHT untergebracht werden konnte.
func hinzufuegen(daten: ItemDaten, menge: int = 1) -> int:
	if daten == null or menge <= 0:
		return menge

	var rest := menge

	# Erst auf vorhandene Stapel verteilen
	if daten.stapelbar:
		for i in plaetze.size():
			if rest <= 0:
				break
			var e = plaetze[i]
			if e == null or e["daten"].id != daten.id:
				continue
			var platz_frei: int = daten.max_stapel - e["menge"]
			if platz_frei <= 0:
				continue
			var nimm: int = mini(platz_frei, rest)
			e["menge"] += nimm
			rest -= nimm

	# Dann freie Plätze belegen
	for i in plaetze.size():
		if rest <= 0:
			break
		if plaetze[i] != null:
			continue
		var nimm: int = mini(daten.max_stapel if daten.stapelbar else 1, rest)
		plaetze[i] = {"daten": daten, "menge": nimm}
		rest -= nimm

	if rest < menge:
		geaendert.emit()
	return rest


func entfernen(index: int, menge: int = 1) -> void:
	var e = hole(index)
	if e == null:
		return
	e["menge"] -= menge
	if e["menge"] <= 0:
		plaetze[index] = null
	geaendert.emit()


# ---------------------------------------------------------------- Verschieben

func tausche_plaetze(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= plaetze.size() or b >= plaetze.size():
		return

	var ea = plaetze[a]
	var eb = plaetze[b]

	# Gleiche stapelbare Ware? Dann zusammenschütten statt tauschen.
	if ea != null and eb != null and ea["daten"].stapelbar \
			and ea["daten"].id == eb["daten"].id:
		var platz_frei: int = eb["daten"].max_stapel - eb["menge"]
		var nimm: int = mini(platz_frei, ea["menge"])
		if nimm > 0:
			eb["menge"] += nimm
			ea["menge"] -= nimm
			if ea["menge"] <= 0:
				plaetze[a] = null
			geaendert.emit()
			return

	plaetze[a] = eb
	plaetze[b] = ea
	geaendert.emit()


# Inventarplatz -> Ausrüstungsslot. Was dort lag, wandert auf den Platz zurück.
func ausruesten(index: int, schluessel: String) -> bool:
	var e = hole(index)
	if e == null or not passt(e["daten"], schluessel):
		return false

	var vorher = ausruestung.get(schluessel, null)
	ausruestung[schluessel] = e
	plaetze[index] = vorher

	geaendert.emit()
	ausruestung_geaendert.emit()
	return true


# Ausrüstungsslot -> Inventarplatz. Ziel -1 = erster freier Platz.
func ablegen(schluessel: String, ziel_index: int = -1) -> bool:
	var e = ausruestung.get(schluessel, null)
	if e == null:
		return false

	if ziel_index < 0:
		ziel_index = erster_freier_platz()
		if ziel_index < 0:
			return false                       # Inventar voll

	var im_weg = hole(ziel_index)
	# Liegt dort etwas, das nicht in den Slot passt, brechen wir ab –
	# sonst hätte man ein Item ohne gültigen Platz in der Hand.
	if im_weg != null and not passt(im_weg["daten"], schluessel):
		var frei := erster_freier_platz()
		if frei < 0:
			return false
		plaetze[frei] = e
		ausruestung[schluessel] = null
	else:
		plaetze[ziel_index] = e
		ausruestung[schluessel] = im_weg

	geaendert.emit()
	ausruestung_geaendert.emit()
	return true


# Direkt zwischen zwei Ausrüstungsslots (z. B. Ring I <-> Ring II)
func tausche_ausruestung(a: String, b: String) -> bool:
	if a == b:
		return false
	var ea = ausruestung.get(a, null)
	var eb = ausruestung.get(b, null)
	if ea != null and not passt(ea["daten"], b):
		return false
	if eb != null and not passt(eb["daten"], a):
		return false
	ausruestung[a] = eb
	ausruestung[b] = ea
	ausruestung_geaendert.emit()
	return true


func erster_freier_platz() -> int:
	for i in plaetze.size():
		if plaetze[i] == null:
			return i
	return -1


# ---------------------------------------------------------------- Werte

# Summe aller Boni der angelegten Ausrüstung
func boni() -> Dictionary:
	var summe := {"leben": 0.0, "ausdauer": 0.0, "schaden": 0.0,
			"ruestung": 0.0, "tempo": 0.0, "krit": 0.0}
	for schluessel in SLOTS:
		var e = ausruestung.get(schluessel, null)
		if e == null:
			continue
		for k in summe:
			summe[k] += e["daten"].boni()[k]
	return summe


# Grundwerte der Figur, ohne Ausrüstung
func grundwerte() -> Dictionary:
	var werte := {"leben": 100.0, "ausdauer": 100.0, "schaden": 9.0,
			"ruestung": 0.0, "tempo": 6.0, "krit": 0.0}
	if _player == null:
		return werte

	var kampf = _player.get_node_or_null("Combat")
	if kampf != null:
		werte["leben"] = kampf.max_leben
		werte["ausdauer"] = kampf.max_ausdauer
		werte["schaden"] = kampf.schaden
	if "walk_speed" in _player:
		werte["tempo"] = _player.walk_speed
	return werte


# Wird von der Oberfläche nach jeder Änderung gerufen und schreibt die Boni
# in die Systeme zurück. Bewusst nur Tempo und Schaden – Leben und Ausdauer
# würden sonst mitten im Kampf springen.
func wende_boni_an() -> void:
	if _player == null:
		return
	var b := boni()
	var grund := grundwerte()

	if "walk_speed" in _player:
		# Sprint- und Schleichtempo skalieren mit, damit das Verhältnis bleibt
		var faktor: float = (grund["tempo"] + b["tempo"]) / maxf(grund["tempo"], 0.01)
		_player.set_meta("tempo_faktor", faktor)

	var kampf = _player.get_node_or_null("Combat")
	if kampf != null:
		kampf.set_meta("bonus_schaden", b["schaden"])
		kampf.set_meta("bonus_ruestung", b["ruestung"])
		kampf.set_meta("bonus_krit", b["krit"])
