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

# --- Darstellung ---------------------------------------------------------
## Leer lassen bei Faeusten (Griff = LEER).
@export var mesh: Mesh
@export var material_ueberschreiben: Material
## Versatz relativ zum Halter-Node am Handknochen.
@export var halte_versatz := Vector3.ZERO
## Drehung in Grad relativ zum Halter-Node.
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

@export_group("Klang")
@export var klang_schwung: AudioStream
@export var klang_treffer: AudioStream


## True, wenn beide Haende gebunden sind.
func ist_zweihaendig() -> bool:
	return griff == Griff.ZWEIHAND


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
