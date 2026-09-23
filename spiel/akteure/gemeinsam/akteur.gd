class_name Akteur
extends CharacterBody3D

## Gemeinsame Basis fuer alles, was combat.gd und character_visual.gd an
## ihrem Elternknoten erwarten - Spieler UND NPCs. Beide Skripte lasen bisher
## Player direkt (per as-Cast bzw. Typannotation), was jeden Nicht-Player als
## Elternknoten ablehnte oder zur Laufzeit abstuerzte, sobald eine hier
## deklarierte Eigenschaft fehlte (z.B. is_swimming). Diese Klasse ist der
## Vertrag, den beide Seiten stattdessen einhalten.
##
## Player und ein spaeterer Npc erben davon und setzen die Felder selbst -
## Player aus echter Physik/Eingabe, Npc aus seiner KI. Kein Feld hier bekommt
## von sich aus einen Sinn zugewiesen; es ist reine Schnittstelle.

@export var camera_pivot: Node3D

var is_sprinting: bool = false
var is_sneaking: bool = false
var is_swimming: bool = false
var is_climbing: bool = false

## Eingaberichtung dieses Frames, bereits um die Kamera/KI-Blickrichtung
## gedreht; Vector3.ZERO ohne Bewegungswunsch. character_visual.gd richtet
## das Modell danach aus.
var wunsch_richtung: Vector3 = Vector3.ZERO

## Kampfkomponente (Kindknoten "Combat"); kann null bleiben.
var combat: Combat = null


## Wird von Gegnern und von combat.gd aufgerufen.
func take_damage(menge: float, angreifer: Node = null,
		richtung: Vector3 = Vector3.ZERO) -> void:
	if combat:
		combat.schaden_erhalten(menge, angreifer, richtung)


## Ein Gegner hat perfekt geblockt -> dieser Akteur ist kurz offen.
func schwachstelle_oeffnen(dauer: float) -> void:
	if combat:
		combat.schwachstelle_oeffnen(dauer)


func ist_offen() -> bool:
	return combat != null and combat.ist_offen()


func schwachstelle_schliessen() -> void:
	if combat:
		combat.schwachstelle_schliessen()
