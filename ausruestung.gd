extends Node
class_name Ausruestung
##
## Ausruestungs-Komponente. Als Kindknoten an Spieler und NPCs haengen.
##
## Aufgaben:
##  - haelt, welche WaffenDaten in welchem Slot stecken
##  - erzeugt/entfernt die Waffenmodelle an den Handhaltern
##  - liefert dem Kampfsystem die aktive Waffe (Faust als Rueckfall)
##
## Zuweisung der Halter:
## Die Export-Felder unten sind OPTIONAL. Bleiben sie leer, sucht die
## Komponente beim Start selbst nach Knoten mit den unter "Suche"
## eingetragenen Namen - und zwar auch INNERHALB instanzierter Unterszenen
## (find_child mit owned = false). Genau das braucht man hier, weil Godot
## Nodes aus einer instanzierten Szene nicht in ein Export-Feld der
## aeusseren Szene ziehen laesst.
##
## Szenenaufbau (Pivot-Rig ohne Skeleton3D):
##   Player
##   └ Visual -> Neigung -> Huefte -> Brust
##        ├ HandRechts -> HalterRechts (Node3D)  <- Waffe landet hier
##        └ HandLinks  -> HalterLinks  (Node3D)
##   └ Ausruestung   <- dieses Skript
##
## Performance: Modelle werden nur beim Wechsel erzeugt, nie pro Frame.
## Diese Datei hat weder _process noch _physics_process.
##

signal ausruestung_geaendert(slot: int, daten: WaffenDaten)
signal waffe_gewechselt(daten: WaffenDaten)

@export_group("Halter")
## Optional. Leer lassen, dann greift die Namenssuche unten.
@export var halter_rechts: Node3D
@export var halter_links: Node3D

@export_group("Suche")
## Ab hier wird gesucht. Leer = Elternknoten (also der Spieler/NPC).
@export var such_wurzel: Node
@export var name_halter_rechts: String = "HalterRechts"
@export var name_halter_links: String = "HalterLinks"

@export_group("Inhalt")
## Wird benutzt, wenn die rechte Hand leer ist. Griff = LEER, Stil = FAUST.
@export var faust_daten: WaffenDaten
## Startausruestung, direkt beim Spielstart angelegt.
@export var start_ausruestung: Array[WaffenDaten] = []

var _slots: Dictionary = {}        ## Slot -> WaffenDaten
var _modelle: Dictionary = {}      ## Slot -> MeshInstance3D
var _bereit: bool = false


func _ready() -> void:
	var wurzel: Node = such_wurzel if such_wurzel != null else get_parent()

	if halter_rechts == null:
		halter_rechts = _suchen(wurzel, name_halter_rechts)
	if halter_links == null:
		halter_links = _suchen(wurzel, name_halter_links)

	if halter_rechts == null:
		push_error("Ausruestung (%s): Kein Halter rechts gefunden."
				% get_path()
				+ " Erwartet: ein Node3D namens '%s' unter '%s'," % [name_halter_rechts, wurzel.name]
				+ " oder das Feld 'halter_rechts' zuweisen. Komponente deaktiviert.")
		return

	if halter_links == null:
		push_warning("Ausruestung: Kein Halter links ('%s') gefunden."
				% name_halter_links + " Nebenhand/Schild wird nicht angezeigt.")

	_bereit = true

	for daten in start_ausruestung:
		if daten != null:
			ausruesten(daten)


## Sucht rekursiv nach Namen. owned = false ist entscheidend: nur so werden
## auch Knoten INNERHALB instanzierter Unterszenen gefunden.
func _suchen(wurzel: Node, knoten_name: String) -> Node3D:
	if wurzel == null or knoten_name.is_empty():
		return null
	var treffer: Node = wurzel.find_child(knoten_name, true, false)
	if treffer == null:
		return null
	if treffer is Node3D:
		return treffer as Node3D
	push_warning("Ausruestung: '%s' gefunden, ist aber kein Node3D." % knoten_name)
	return null


# =========================================================================
#  Oeffentliche Schnittstelle
# =========================================================================

## Legt einen Gegenstand an. Der Ziel-Slot kommt aus den WaffenDaten.
func ausruesten(daten: WaffenDaten) -> void:
	if not _bereit or daten == null:
		return
	daten.gepruefte_werte()

	var ziel: int = daten.slot

	# Zweihaendige Waffen belegen beide Haende.
	if ziel == WaffenDaten.Slot.HAND_RECHTS and daten.ist_zweihaendig():
		ablegen(WaffenDaten.Slot.HAND_LINKS)
	elif ziel == WaffenDaten.Slot.HAND_LINKS:
		var rechts: WaffenDaten = hole(WaffenDaten.Slot.HAND_RECHTS)
		if rechts != null and rechts.ist_zweihaendig():
			ablegen(WaffenDaten.Slot.HAND_RECHTS)

	ablegen(ziel)
	_slots[ziel] = daten
	_modell_erzeugen(ziel, daten)

	ausruestung_geaendert.emit(ziel, daten)
	if ziel == WaffenDaten.Slot.HAND_RECHTS or ziel == WaffenDaten.Slot.HAND_LINKS:
		waffe_gewechselt.emit(aktive_waffe())


func ablegen(slot: int) -> WaffenDaten:
	var alt: WaffenDaten = _slots.get(slot, null)
	if _modelle.has(slot):
		var m: Node = _modelle[slot]
		if is_instance_valid(m):
			m.queue_free()
		_modelle.erase(slot)
	if _slots.has(slot):
		_slots.erase(slot)
		ausruestung_geaendert.emit(slot, null)
		if slot == WaffenDaten.Slot.HAND_RECHTS or slot == WaffenDaten.Slot.HAND_LINKS:
			waffe_gewechselt.emit(aktive_waffe())
	return alt


func hole(slot: int) -> WaffenDaten:
	return _slots.get(slot, null)


## Die Waffe, mit der gerade zugeschlagen wird. Nie null, solange
## 'faust_daten' zugewiesen ist.
func aktive_waffe() -> WaffenDaten:
	var w: WaffenDaten = _slots.get(WaffenDaten.Slot.HAND_RECHTS, null)
	if w != null:
		return w
	return faust_daten


func nebenhand() -> WaffenDaten:
	return _slots.get(WaffenDaten.Slot.HAND_LINKS, null)


## True, wenn die Kombo die Haende abwechseln darf (nur bei Faeusten -
## bei Waffen schlaegt immer dieselbe Seite).
func haende_wechseln_erlaubt() -> bool:
	var w: WaffenDaten = aktive_waffe()
	if w == null:
		return true
	if w.ist_zweihaendig():
		return false
	return w.griff == WaffenDaten.Griff.LEER


## Blockwaffe: Schild in der Nebenhand, sonst die aktive Waffe.
func block_waffe() -> WaffenDaten:
	var n: WaffenDaten = nebenhand()
	if n != null and n.griff == WaffenDaten.Griff.SCHILD:
		return n
	var w: WaffenDaten = aktive_waffe()
	if w != null and w.kann_blocken:
		return w
	return null


## Alle belegten Slots als Kopie (nur lesen).
func belegung() -> Dictionary:
	return _slots.duplicate()


func ist_bereit() -> bool:
	return _bereit


# =========================================================================
#  Modellverwaltung
# =========================================================================

func _modell_erzeugen(slot: int, daten: WaffenDaten) -> void:
	if not daten.hat_modell():
		return

	var halter: Node3D = _halter_fuer(slot)
	if halter == null:
		return

	var mi := MeshInstance3D.new()
	mi.name = "Waffe_" + daten.anzeige_name.validate_node_name()
	mi.mesh = daten.mesh

	if daten.material_ueberschreiben != null:
		mi.material_override = daten.material_ueberschreiben

	mi.position = daten.halte_versatz
	mi.rotation = Vector3(
		deg_to_rad(daten.halte_drehung.x),
		deg_to_rad(daten.halte_drehung.y),
		deg_to_rad(daten.halte_drehung.z)
	)
	mi.scale = daten.halte_skalierung
	mi.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON if daten.wirft_schatten
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)

	halter.add_child(mi)
	_modelle[slot] = mi


func _halter_fuer(slot: int) -> Node3D:
	match slot:
		WaffenDaten.Slot.HAND_RECHTS:
			return halter_rechts
		WaffenDaten.Slot.HAND_LINKS:
			return halter_links
	# Ruestungsslots zeigen (noch) kein eigenes Modell.
	return null
