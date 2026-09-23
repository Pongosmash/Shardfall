# bloecke.gd  ->  spiel/welt/bloecke.gd
#
# Einzige Quelle der Blockindizes.
#
# Die Werte muessen der Reihenfolge im models-Array von
# daten/welt/bloecke.tres entsprechen. Ein Modell an falscher Stelle, und die
# ganze Welt besteht aus dem falschen Material -- ohne Fehlermeldung beim
# Start. Genau deshalb steht der Index jetzt nur noch hier und wird gegen die
# .tres geprueft, statt an zwei Stellen von Hand gepflegt zu werden.
#
# Einbau: keiner. Kein Autoload, kein Knoten in der Szene. class_name macht
# die Konstanten von ueberall erreichbar: Bloecke.GRAS.
#
# world_generator.gd behaelt seinen Konstantenblock, dessen Werte kommen aber
# von hier:
#
#     const GRASS := Bloecke.GRAS
#
# Das ist nicht nur Bequemlichkeit: deko_layer.gd liest achtzehnmal
# WorldGenerator.GRAS_KURZ und Verwandte. Wuerde der Block im Generator
# ersatzlos verschwinden, braeche der DekoLayer sofort. Konstante aus
# Konstante kostet zur Laufzeit nichts, und der Zahlenwert steht trotzdem
# nur einmal.
#
# Reihenfolge pruefen: werkzeuge/bloecke_namen.gd im Editor ausfuehren.

class_name Bloecke
extends RefCounted


# --------------------------------------------------------------------------
# Indizes
# --------------------------------------------------------------------------
# Die Reihenfolge ist nicht frei waehlbar. PFLANZE_MIN und PFLANZE_MAX weiter
# unten setzen voraus, dass die acht Pflanzen einen zusammenhaengenden Block
# bilden. Ein neuer Blocktyp gehoert ans Ende -- oder ans Ende seiner Gruppe,
# dann aber muessen die Grenzen mitwandern.

# Grundmasse
const LUFT   := 0
const WASSER := 1
const GRAS   := 2   # Bodenblock. Die Pflanze heisst GRAS_KURZ.
const STEIN  := 3
const ERDE   := 4

# Pflanzen -- stehen nur bei deko_als_voxel = true als Voxel in der Welt.
# Im Normalfall zeichnet deko_layer.gd sie als MultiMesh.
const GRAS_KURZ    := 5
const GRAS_MITTEL  := 6
const GRAS_HOCH    := 7
const GRAS_TROCKEN := 8
const GRAS_BUSCH   := 9
const BLUME_ROT    := 10
const BLUME_GELB   := 11
const BLUME_LILA   := 12

# Baeume
const HOLZ_EICHE := 13
const HOLZ_BUCHE := 14
const HOLZ_TANNE := 15
const LAUB_EICHE := 16
const LAUB_BUCHE := 17
const LAUB_TANNE := 18

# Gestein
const FELS := 19


# --------------------------------------------------------------------------
# Pflanzenbereich
# --------------------------------------------------------------------------
# Strukturen duerfen Deko ueberschreiben, Terrain nicht. Der Generator
# vergleicht dafuer in _setz() gegen diese beiden Grenzen -- inline, weil
# _setz fuer jeden einzelnen Laubvoxel laeuft und ein Funktionsaufruf dort
# messbar waere. Deshalb Konstanten und keine ist_pflanze()-Funktion.

const PFLANZE_MIN := GRAS_KURZ
const PFLANZE_MAX := BLUME_LILA


# --------------------------------------------------------------------------
# Pruefdaten
# --------------------------------------------------------------------------
# NAMEN[i] ist der Konstantenname zum Index i und muss dem resource_name des
# Modells an derselben Stelle in bloecke.tres entsprechen.
# werkzeuge/bloecke_namen.gd prueft beides gegeneinander -- und zusaetzlich,
# dass jeder Eintrag hier wirklich als Konstante mit genau diesem Wert
# existiert. NAMEN kann also nicht unbemerkt von den Konstanten abdriften.

const NAMEN := [
	"LUFT",
	"WASSER",
	"GRAS",
	"STEIN",
	"ERDE",
	"GRAS_KURZ",
	"GRAS_MITTEL",
	"GRAS_HOCH",
	"GRAS_TROCKEN",
	"GRAS_BUSCH",
	"BLUME_ROT",
	"BLUME_GELB",
	"BLUME_LILA",
	"HOLZ_EICHE",
	"HOLZ_BUCHE",
	"HOLZ_TANNE",
	"LAUB_EICHE",
	"LAUB_BUCHE",
	"LAUB_TANNE",
	"FELS",
]

const ANZAHL := 20


## Nur fuer Fehlermeldungen und Diagnose. Nie fuer Logik benutzen -- der
## Index ist die Wahrheit, der Name ist Beiwerk.
static func name_von(index: int) -> String:
	if index < 0 or index >= NAMEN.size():
		return "UNBEKANNT(%d)" % index
	return NAMEN[index]
