# bloecke_namen.gd  ->  werkzeuge/bloecke_namen.gd
#
# Setzt die resource_name-Felder der Blockmodelle in daten/welt/bloecke.tres
# auf die Konstantennamen aus spiel/welt/bloecke.gd -- und prueft danach, ob
# beide Seiten noch zusammenpassen.
#
# Benennen und Pruefen sind bewusst ein Werkzeug: die Wahrheit ueber die
# Reihenfolge steht damit nur an einer Stelle. Zwei getrennte Werkzeuge
# haetten dieselbe Liste doppelt gefuehrt -- genau der Fehler, den Etappe 02
# beseitigen soll.
#
# Ausfuehren: im Editor Datei -> Ausfuehren (Strg+Umschalt+X). Laeuft NIE im
# Spiel.
#
# Ablauf:
#   1. SCHREIBEN = false lassen, ausfuehren, Ausgabe lesen
#   2. sieht es richtig aus: SCHREIBEN = true, nochmal ausfuehren
#   3. SCHREIBEN wieder auf false zuruecksetzen
#   4. git diff daten/welt/bloecke.tres -- es sollten genau ANZAHL
#      resource_name-Zeilen dazukommen, sonst nichts
#
# Danach bei jeder Aenderung an der Blockbibliothek erneut ausfuehren. Meldet
# es "in Ordnung", stimmt die Reihenfolge. Meldet es eine Abweichung, ist
# entweder ein Modell verrutscht oder eine Konstante nicht nachgezogen --
# beides bricht die Welt lautlos, wenn es unbemerkt bleibt.

@tool
extends EditorScript

const BIB_PFAD := "res://daten/welt/bloecke.tres"
const SKRIPT_PFAD := "res://spiel/welt/bloecke.gd"

## true schreibt die Namen und speichert die .tres. Zum Pruefen auf false.
const SCHREIBEN := false


func _run() -> void:
	print("--- bloecke_namen ---")

	var skript := load(SKRIPT_PFAD) as Script
	if skript == null:
		push_error("bloecke_namen: %s nicht ladbar." % SKRIPT_PFAD)
		return

	var konstanten: Dictionary = skript.get_script_constant_map()
	var namen: Array = konstanten.get("NAMEN", [])
	if namen.is_empty():
		push_error("bloecke_namen: NAMEN fehlt in bloecke.gd.")
		return

	# Selbsttest: NAMEN gegen die Konstanten desselben Skripts. Faengt den
	# Fall ab, dass jemand eine Konstante einfuegt und die Liste vergisst.
	var selbst_ok := true
	for i in namen.size():
		var n: String = namen[i]
		if not konstanten.has(n):
			push_error("bloecke_namen: NAMEN[%d] = \"%s\" -- Konstante existiert nicht." % [i, n])
			selbst_ok = false
		elif int(konstanten[n]) != i:
			push_error("bloecke_namen: %s hat Wert %d, steht aber an Position %d in NAMEN."
					% [n, int(konstanten[n]), i])
			selbst_ok = false
	if not selbst_ok:
		print("Abbruch: bloecke.gd ist in sich nicht schluessig.")
		return
	print("bloecke.gd in sich schluessig (%d Eintraege)." % namen.size())

	var bibliothek := load(BIB_PFAD) as Resource
	if bibliothek == null:
		push_error("bloecke_namen: %s nicht ladbar. Punkt 1 der Etappe schon erledigt?" % BIB_PFAD)
		return

	var modelle := _hole_modelle(bibliothek)
	if modelle.is_empty():
		push_error("bloecke_namen: keine Modelle gefunden. Weder models noch voxel_types belegt.")
		return

	if modelle.size() != namen.size():
		push_error("bloecke_namen: %d Modelle in der .tres, aber %d Konstanten. "
				% [modelle.size(), namen.size()]
				+ "Erst die Anzahl in Ordnung bringen, sonst ist jeder Vergleich sinnlos.")
		return

	var abweichungen := 0
	var gesetzt := 0

	for i in modelle.size():
		var modell: Resource = modelle[i]
		if modell == null:
			push_error("bloecke_namen: Modell %d (%s) ist leer." % [i, namen[i]])
			abweichungen += 1
			continue

		var ist_name := String(modell.resource_name)
		var soll_name: String = namen[i]

		if ist_name == soll_name:
			continue

		if ist_name.is_empty():
			if SCHREIBEN:
				modell.resource_name = soll_name
				gesetzt += 1
				print("  %2d gesetzt: %s" % [i, soll_name])
			else:
				print("  %2d wuerde gesetzt: %s" % [i, soll_name])
		else:
			# Ein abweichender, aber vorhandener Name ist der ernste Fall:
			# vermutlich ist ein Modell verrutscht. Nicht ueberschreiben --
			# das wuerde die Spur verwischen.
			push_error("bloecke_namen: Position %d heisst \"%s\", erwartet \"%s\". "
					% [i, ist_name, soll_name]
					+ "Modell verrutscht oder Konstante nicht nachgezogen -- von Hand klaeren.")
			abweichungen += 1

	if abweichungen > 0:
		print("%d Abweichung(en). Nichts gespeichert." % abweichungen)
		return

	if not SCHREIBEN:
		print("Pruefung ohne Schreiben beendet. Reihenfolge in Ordnung.")
		return

	if gesetzt == 0:
		print("Alle Namen standen bereits richtig. Nichts zu tun.")
		return

	var fehler := ResourceSaver.save(bibliothek, BIB_PFAD)
	if fehler != OK:
		push_error("bloecke_namen: Speichern fehlgeschlagen (Fehler %d)." % fehler)
		return

	print("%d Namen gesetzt und gespeichert." % gesetzt)
	print("SCHREIBEN jetzt wieder auf false stellen.")


## VoxelBlockyLibrary fuehrt die Modelle je nach Addon-Stand als models oder
## als voxel_types. Duck-typing statt fester Klasse -- das Addon ist
## Fremdcode und darf sich aendern, ohne dass dieses Werkzeug bricht.
func _hole_modelle(bibliothek: Resource) -> Array:
	for feld in ["models", "voxel_types"]:
		var wert = bibliothek.get(feld)
		if wert is Array and not (wert as Array).is_empty():
			print("Modelle gefunden im Feld \"%s\" (%d Stueck)." % [feld, (wert as Array).size()])
			return wert
	return []
