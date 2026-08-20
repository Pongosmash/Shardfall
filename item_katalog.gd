extends Node
class_name ItemKatalog

# Erzeugt Items per Code. Gedacht als Startpunkt, solange es noch keine
# .tres-Dateien gibt: So siehst du das Inventar sofort gefüllt.
#
# Später legst du Items als Ressourcen im Editor an (Rechtsklick im
# Dateisystem -> Neue Ressource -> ItemDaten) und lädst sie mit
# load("res://items/eisenhelm.tres"). Der Rest des Systems bleibt gleich.

static func _mach(id: String, anzeige: String, slot: int, selten: int,
		farbe: Color, boni: Dictionary, beschreibung: String = "") -> ItemDaten:
	var it := ItemDaten.new()
	it.id = StringName(id)
	it.anzeige_name = anzeige
	it.slot = slot
	it.seltenheit = selten
	it.modell_farbe = farbe
	it.beschreibung = beschreibung
	it.bonus_leben = boni.get("leben", 0.0)
	it.bonus_ausdauer = boni.get("ausdauer", 0.0)
	it.bonus_schaden = boni.get("schaden", 0.0)
	it.bonus_ruestung = boni.get("ruestung", 0.0)
	it.bonus_tempo = boni.get("tempo", 0.0)
	it.bonus_krit = boni.get("krit", 0.0)
	return it


static func _stapel(id: String, anzeige: String, farbe: Color,
		beschreibung: String) -> ItemDaten:
	var it := _mach(id, anzeige, ItemDaten.Slot.KEINER,
			ItemDaten.Seltenheit.GEWOEHNLICH, farbe, {}, beschreibung)
	it.stapelbar = true
	it.max_stapel = 99
	return it


# Liste von [ItemDaten, Menge] für den Start
static func start_items() -> Array:
	var s := ItemDaten.Slot
	var r := ItemDaten.Seltenheit
	return [
		[_mach("lederkappe", "Lederkappe", s.KOPF, r.GEWOEHNLICH,
				Color(0.45, 0.31, 0.19), {"ruestung": 2.0, "leben": 5.0},
				"Abgewetzt, aber besser als nichts."), 1],
		[_mach("eisenhelm", "Eisenhelm", s.KOPF, r.UNGEWOEHNLICH,
				Color(0.62, 0.65, 0.70), {"ruestung": 6.0, "tempo": -0.1},
				"Schwer, aber zuverlässig."), 1],
		[_mach("lederwams", "Lederwams", s.RUESTUNG, r.GEWOEHNLICH,
				Color(0.40, 0.27, 0.17), {"ruestung": 4.0, "leben": 10.0}), 1],
		[_mach("kettenhemd", "Kettenhemd", s.RUESTUNG, r.SELTEN,
				Color(0.55, 0.58, 0.64), {"ruestung": 12.0, "leben": 20.0,
				"tempo": -0.2}, "Ringe aus kaltgeschmiedetem Eisen."), 1],
		[_mach("handschuhe", "Grobe Handschuhe", s.HAENDE, r.GEWOEHNLICH,
				Color(0.38, 0.26, 0.16), {"ruestung": 2.0, "schaden": 1.0}), 1],
		[_mach("faustwickel", "Faustwickel", s.HAENDE, r.UNGEWOEHNLICH,
				Color(0.78, 0.74, 0.62), {"schaden": 3.0, "krit": 0.03},
				"Fester Griff, härterer Schlag."), 1],
		[_mach("wanderstiefel", "Wanderstiefel", s.FUESSE, r.GEWOEHNLICH,
				Color(0.32, 0.22, 0.15), {"ruestung": 2.0, "tempo": 0.3}), 1],
		[_mach("ring_kraft", "Ring der Kraft", s.RING, r.SELTEN,
				Color(0.85, 0.70, 0.28), {"schaden": 4.0}), 1],
		[_mach("ring_zaeh", "Ring der Zähigkeit", s.RING, r.UNGEWOEHNLICH,
				Color(0.70, 0.72, 0.78), {"leben": 15.0, "ausdauer": 10.0}), 1],
		[_mach("amulett_wind", "Amulett des Windes", s.AMULETT, r.EPISCH,
				Color(0.55, 0.80, 0.88), {"tempo": 0.8, "ausdauer": 20.0},
				"Leicht wie ein Windstoß."), 1],
		[_mach("dolch", "Rostiger Dolch", s.HAUPTHAND, r.GEWOEHNLICH,
				Color(0.58, 0.52, 0.44), {"schaden": 6.0, "krit": 0.05}), 1],
		[_mach("kurzschwert", "Kurzschwert", s.HAUPTHAND, r.UNGEWOEHNLICH,
				Color(0.72, 0.75, 0.80), {"schaden": 10.0}), 1],
		[_mach("holzschild", "Holzschild", s.NEBENHAND, r.GEWOEHNLICH,
				Color(0.44, 0.30, 0.18), {"ruestung": 5.0, "tempo": -0.2}), 1],
		[_stapel("lederfetzen", "Lederfetzen", Color(0.45, 0.31, 0.19),
				"Handwerksmaterial."), 12],
		[_stapel("eisenerz", "Eisenerz", Color(0.50, 0.48, 0.46),
				"Handwerksmaterial."), 7],
		[_stapel("beere", "Waldbeere", Color(0.70, 0.18, 0.28),
				"Sieht essbar aus."), 23],
	]
