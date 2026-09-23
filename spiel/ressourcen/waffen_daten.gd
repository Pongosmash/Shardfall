extends Resource
class_name WaffenDaten
##
## Beschreibt eine ausruestbare Waffe / einen Gegenstand.
##
## Eine .tres-Datei pro Waffe anlegen:
##   FileSystem -> Rechtsklick -> Neu -> Ressource -> "WaffenDaten"
##   -> speichern unter res://daten/waffen/kurzschwert.tres
##
## Kampf, Animation und Ausruestung lesen alle aus dieser einen Quelle.
## So aendert eine neue Waffe automatisch Reichweite, Timing, Haltung
## und Angriffsanimation, ohne dass Code angefasst werden muss.
##
enum Slot { HAND_RECHTS, HAND_LINKS, KOPF, BRUST, BEINE }
enum Griff { EINHAND, ZWEIHAND, SCHILD, LEER }
enum Stil { FAUST, STICH, HIEB, SCHWUNG_SCHWER, STANGE }
enum Schadensart { STUMPF, SCHNITT, STICH }
# --- Allgemein -----------------------------------------------------------
@export var anzeige_name := "Unbenannt"
@export_multiline var beschreibung := ""
@export var symbol: Texture2D
@export var slot: Slot = Slot.HAND_RECHTS
@export var griff: Griff = Griff.EINHAND
## Nur wirksam bei Griff = ZWEIHAND.
##
## An: die Waffe wird beidhaendig gefuehrt, solange die Nebenhand frei ist,
## laesst dort aber ein Schild zu und wird dann einhaendig gehalten.
## Aus: die Nebenhand bleibt zwingend leer (Zweihaender).
##
## Der Griff beschreibt weiterhin, WIE die Waffe gefuehrt wird - davon haengen
## Reichweite, Timing und Ausdauer ab. Dieses Feld beantwortet nur, ob die
## zweite Hand dafuer frei bleiben MUSS. Ein Speer ist zweihaendig gefuehrt
## und laesst trotzdem ein Schild zu, ein Zweihaender nicht.
@export var kann_einhaendig := false
# --- Darstellung ---------------------------------------------------------
## Leer lassen bei Faeusten (Griff = LEER).
@export var mesh: Mesh
@export var material_ueberschreiben: Material
## Versatz relativ zum Halter-Node am Handknochen.
@export var halte_versatz := Vector3.ZERO
## Drehung in Grad relativ zum Halter-Node.
##
## Achtung: character_visual.gd dreht den HALTER selbst, um die Waffe zu
## fuehren. Dieses Feld kommt zusaetzlich obendrauf und ist fuer den festen
## Sitz im Halter gedacht (schiefes Mesh gerade ruecken), nicht fuer die
## Haltung. Wer hier etwas eintraegt, verzieht alle berechneten Winkel in
## der Posentabelle mit.
@export var halte_drehung := Vector3.ZERO
@export var halte_skalierung := Vector3.ONE
@export var wirft_schatten := true
# --- Kampfwerte ----------------------------------------------------------
@export_group("Kampf")
@export var stil: Stil = Stil.FAUST
@export var schadensart: Schadensart = Schadensart.STUMPF
@export var schaden := 5.0
@export var kritisch_multiplikator := 2.5
## Reichweite in Metern ab Spielermitte.
@export var reichweite := 1.6
## Radius der Treffererkennung am Reichweitenende.
@export var treffer_radius := 0.55
## Rueckstoss, der dem Ziel mitgegeben wird.
@export var wucht := 3.0
@export_group("Timing")
## Gesamtdauer eines Schlages in Sekunden.
@export var angriff_dauer := 0.45
## Ab wann im Schlag (0-1) Schaden entsteht.
@export_range(0.0, 1.0) var treffer_start := 0.35
## Bis wann im Schlag (0-1) Schaden entsteht.
@export_range(0.0, 1.0) var treffer_ende := 0.6
## Pause nach dem Schlag, bevor neu angegriffen werden darf.
@export var nachziehzeit := 0.12
## Wie viele Schlaege die Kombo hat (wechselt Hand bzw. Richtung).
@export var kombo_schritte := 2
## Zeitfenster nach einem Schlag, in dem die Kombo weiterlaeuft.
@export var kombo_fenster := 0.55
@export_group("Ausdauer & Block")
@export var ausdauer_kosten := 8.0
@export var kann_blocken := true
## Anteil des Schadens, der beim Blocken durchkommt (0.5 = halber Schaden).
@export_range(0.0, 1.0) var block_durchlass := 0.4
@export var block_ausdauer_kosten := 6.0
# --- Einhaendige Fuehrung ------------------------------------------------
## Faktoren auf die Kampfwerte, solange eine Waffe mit kann_einhaendig nur mit
## einer Hand gefuehrt wird. Wirken nur dann - bei jeder anderen Waffe steht
## die ganze Gruppe wirkungslos herum.
##
## treffer_start und treffer_ende sind Anteile von angriff_dauer und brauchen
## deshalb KEINEN eigenen Faktor: wird der Schlag laenger, wandert das
## Trefferfenster automatisch mit, und schlag_marken() bleibt stimmig.
@export_group("Einhaendig gefuehrt")
## Kleiner als 1 = schwaecher.
@export_range(0.1, 1.0) var einhand_schaden := 0.65
## Groesser als 1 = langsamer. Streckt den ganzen Schlag.
@export_range(1.0, 3.0) var einhand_dauer := 1.35
## Groesser als 1 = laengere Pause zwischen den Schlaegen.
@export_range(1.0, 3.0) var einhand_nachziehzeit := 1.40
## Kleiner als 1 = kuerzer. Eine Hand haelt den Schaft nicht so weit vorn.
@export_range(0.1, 2.0) var einhand_reichweite := 0.85
## Groesser als 1 = anstrengender.
@export_range(1.0, 3.0) var einhand_ausdauer := 1.25
## Kleiner als 1 = weniger Rueckstoss.
@export_range(0.1, 1.0) var einhand_wucht := 0.70
@export_group("Klang")
@export var klang_schwung: AudioStream
@export var klang_treffer: AudioStream
## True, wenn die Waffe zweihaendig gefuehrt wird.
##
## Das ist eine Aussage ueber die Fuehrung, nicht darueber, ob die Nebenhand
## frei bleiben muss - dafuer gibt es erzwingt_zwei_haende(). Kampfwerte
## haengen an dieser Funktion, die Belegung der Slots an der anderen.
func ist_zweihaendig() -> bool:
	return griff == Griff.ZWEIHAND
## True, wenn die Nebenhand zwingend frei bleiben muss.
##
## Das ist die Frage, die ausruestung.gd stellen muss. Wer dort wieder
## ist_zweihaendig() einsetzt, macht Speer und Schild gleichzeitig unmoeglich
## - und zwar lautlos: je nach Reihenfolge in start_ausruestung verschwindet
## das eine oder das andere.
func erzwingt_zwei_haende() -> bool:
	return ist_zweihaendig() and not kann_einhaendig
## Kopie dieser Waffe mit den Einhand-Abschlaegen.
##
## Wird von ausruestung.gd erzeugt und dort zwischengespeichert - nicht pro
## Bild aufrufen, duplicate() legt jedes Mal eine neue Ressource an.
##
## Bewusst eine KOPIE und keine Umrechnung an Ort und Stelle: die Originalwerte
## muessen erhalten bleiben, sonst waere der Speer nach einmal Schild anlegen
## und wieder ablegen dauerhaft geschwaecht. Das Mesh wird geteilt, nicht
## kopiert - duplicate() ohne Argument geht nicht in Unterressourcen hinein.
func einhand_fassung() -> WaffenDaten:
	var k: WaffenDaten = duplicate() as WaffenDaten
	k.schaden *= einhand_schaden
	k.wucht *= einhand_wucht
	k.reichweite *= einhand_reichweite
	k.angriff_dauer *= einhand_dauer
	k.nachziehzeit *= einhand_nachziehzeit
	k.ausdauer_kosten *= einhand_ausdauer
	return k
## True, wenn ueberhaupt ein Modell gezeigt werden soll.
func hat_modell() -> bool:
	return mesh != null and griff != Griff.LEER
## Sicherheitspruefung, damit fehlerhafte .tres-Dateien nicht das
## Kampfsystem blockieren.
func gepruefte_werte() -> void:
	angriff_dauer = maxf(angriff_dauer, 0.05)
	treffer_start = clampf(treffer_start, 0.0, 0.95)
	treffer_ende = clampf(treffer_ende, treffer_start + 0.05, 1.0)
	kombo_schritte = maxi(kombo_schritte, 1)
	# kann_einhaendig ist bei jedem anderen Griff bedeutungslos. Nicht still
	# zuruecksetzen, sondern melden: ein gesetztes Haekchen an einer
	# Einhandwaffe ist ein Hinweis darauf, dass jemand den Griff vergessen hat.
	if kann_einhaendig and griff != Griff.ZWEIHAND:
		push_warning("WaffenDaten '%s': kann_einhaendig ist gesetzt, "
				% anzeige_name
				+ "wirkt aber nur bei Griff = ZWEIHAND. Griff pruefen.")
