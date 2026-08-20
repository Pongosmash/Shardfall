extends Resource
class_name ItemDaten

# Beschreibt einen Gegenstandstyp. Als .tres im Editor anlegen oder per Code
# erzeugen (siehe item_katalog.gd). Eine ItemDaten-Ressource beschreibt die ART
# des Gegenstands, nicht ein einzelnes Exemplar – die Menge steckt im Inventar.

enum Slot {
	KEINER,      # kein Ausrüstungsgegenstand (Material, Verbrauch, ...)
	KOPF,
	RUESTUNG,
	HAENDE,
	FUESSE,
	RING,
	AMULETT,
	HAUPTHAND,
	NEBENHAND,
}

enum Seltenheit { GEWOEHNLICH, UNGEWOEHNLICH, SELTEN, EPISCH, LEGENDAER }

const SELTENHEIT_FARBE := {
	Seltenheit.GEWOEHNLICH:  Color(0.80, 0.80, 0.80),
	Seltenheit.UNGEWOEHNLICH: Color(0.42, 0.80, 0.35),
	Seltenheit.SELTEN:       Color(0.30, 0.58, 0.92),
	Seltenheit.EPISCH:       Color(0.68, 0.40, 0.90),
	Seltenheit.LEGENDAER:    Color(0.95, 0.65, 0.20),
}

const SLOT_NAME := {
	Slot.KEINER: "—",
	Slot.KOPF: "Helm",
	Slot.RUESTUNG: "Rüstung",
	Slot.HAENDE: "Handschuhe",
	Slot.FUESSE: "Stiefel",
	Slot.RING: "Ring",
	Slot.AMULETT: "Amulett",
	Slot.HAUPTHAND: "Haupthand",
	Slot.NEBENHAND: "Nebenhand",
}

@export var id: StringName = &""
@export var anzeige_name: String = "Unbenannt"
@export_multiline var beschreibung: String = ""
@export var slot: Slot = Slot.KEINER
@export var seltenheit: Seltenheit = Seltenheit.GEWOEHNLICH
@export var stapelbar: bool = false
@export var max_stapel: int = 1
@export var icon: Texture2D
## Farbe, in der das Teil in der Charaktervorschau dargestellt wird
@export var modell_farbe: Color = Color(0.62, 0.62, 0.66)

@export_group("Boni")
@export var bonus_leben: float = 0.0
@export var bonus_ausdauer: float = 0.0
@export var bonus_schaden: float = 0.0
@export var bonus_ruestung: float = 0.0
@export var bonus_tempo: float = 0.0
@export var bonus_krit: float = 0.0


func farbe() -> Color:
	return SELTENHEIT_FARBE.get(seltenheit, Color.WHITE)


func slot_text() -> String:
	return SLOT_NAME.get(slot, "—")


func ist_ausruestung() -> bool:
	return slot != Slot.KEINER


# Alle Boni als Dictionary – erleichtert das Aufsummieren im Inventar.
func boni() -> Dictionary:
	return {
		"leben": bonus_leben,
		"ausdauer": bonus_ausdauer,
		"schaden": bonus_schaden,
		"ruestung": bonus_ruestung,
		"tempo": bonus_tempo,
		"krit": bonus_krit,
	}


# Kurzform für Tooltips und Listen
func kurz_text() -> String:
	var teile: PackedStringArray = []
	for schluessel in boni():
		var wert: float = boni()[schluessel]
		if absf(wert) > 0.001:
			teile.append("%s %+.0f" % [schluessel.capitalize(), wert])
	return ", ".join(teile)
