# Roadmap

Zwei Stränge, die sich abwechseln: **Spielinhalt** (was Shardfall können soll)
und **Umbau** (was die Struktur tragen muss, damit der Inhalt bezahlbar bleibt).

Die Reihenfolge ist nicht beliebig – zwei der vier Inhaltspunkte hängen an
Umbau-Etappe 02.

Diese Datei ersetzt das frühere `Urgent_Shardfall_ToDos.md`.

---

## Spielinhalt

### 1 · Gegenstände richtig ausrüsten, Waffen ändern Angriff und Haltung

**Stand: System steht, es fehlen die Waffen.**

Vorhanden und funktionsfähig:

- `spiel/ressourcen/waffen_daten.gd` mit `Griff` (Einhand, Zweihand, Schild,
  Leer) und `Stil` (Faust, Stich, Hieb, Schwung schwer, Stange)
- `spiel/akteure/gemeinsam/ausruestung.gd` hängt Waffenmodelle an
  `HalterRechts` / `HalterLinks`
- `combat.gd` zieht Timing, Schaden, Reichweite, Trefferwinkel, Kombolänge und
  Blockwerte aus den `WaffenDaten` der ausgerüsteten Waffe
- `character_visual.gd` wählt die Schlagpose über `Combat.aktiver_stil()` und
  legt die Kurve auf `Combat.schlag_marken()`

Es fehlt: **`.tres`-Dateien.** Bisher existiert genau eine Waffe,
`daten/waffen/faust.tres`. Ein Kurzschwert, eine Axt, ein Zweihänder und ein
Schild sind reine Ressourcenarbeit ohne Codeänderung.

Braucht keine Umbau-Etappe. Kann sofort losgehen.

### 2 · NPCs

**Stand: offen. Braucht Etappe 02.**

Vier Verhaltensarten:

| Art | Verhalten |
|---|---|
| feindlich | greift an, sobald er den Spieler sieht oder dieser zu nah kommt |
| neutral | greift an, wenn er angegriffen wurde |
| passiv | rennt weg, wenn er angegriffen wurde |
| freundlich | kann angesprochen werden |

Der Kampfvertrag steht bereits: Ein Ziel muss in der Gruppe `damageable` sein
und `take_damage(menge, angreifer, richtung)` haben. `trainingspuppe.gd` zeigt,
dass das reicht.

**Warum Etappe 02 zwingend vorher kommt:** Der Spielerkörper ist mit 15 Knoten
fest in `main.tscn` verdrahtet. Ohne `koerper.tscn` als eigene Szene wird das
Rig für jeden Gegnertyp von Hand kopiert, und jede spätere Änderung – neue
Waffenhalter, Rüstungsteile – muss an allen Kopien nachgezogen werden.

Landet in `spiel/akteure/npc/`, KI-Zustände in `spiel/akteure/npc/ki/`,
NPC-Vorlagen als `daten/npcs/*.tres`.

### 3 · Menü mit Optionen, Verlassen und Fortsetzen

**Stand: weitgehend erledigt.**

`spiel/ui/menue/pause_menue.gd` (633 Zeilen) und das Autoload
`spiel/autoload/einstellungen.gd` (325 Zeilen) liefern:

- Fortsetzen, Optionen, Spiel verlassen
- Reiter Audio: Master, Musik, SFX
- Reiter Video: Fenstermodus, VSync, FPS-Grenze, 3D-Auflösungsskalierung,
  Sichtfeld
- Reiter Steuerung: Tastenbelegung zur Laufzeit, Maussensitivität,
  Y-Invertierung
- Speichern nach `user://einstellungen.cfg`, Anwenden auf `AudioServer`,
  `DisplayServer`, `Engine` und `InputMap`

Zwei Restarbeiten, beide klein:

- **Die Tastenbelegung zeigt Engine-Namen.** `AKTIONS_NAMEN` in
  `einstellungen.gd` führt dreizehn deutsche Anzeigenamen (`vorwaerts`,
  `angriff`, `inventar`, …), von denen **keiner** im InputMap existiert – dort
  heißen die Aktionen `move_forward`, `attack`, `inventory`. Das Menü fällt auf
  automatisch erzeugte Namen zurück und zeigt "Move forward". Billigster Fix:
  `AKTIONS_NAMEN` auf die tatsächlichen Schlüssel umschreiben.
- **Springen ist nicht umbelegbar.** `player.gd` springt auf `ui_accept`, und
  `belegbare_aktionen()` überspringt alles mit `ui_`-Präfix. Fix: echte Aktion
  in `project.godot` anlegen, `player.gd` darauf umstellen.

Fehlt noch ganz: ein **Hauptmenü** beim Spielstart und ein **Spielstand**.

### 4 · Gebäude

**Stand: offen. Braucht Etappe 02.**

Landet als `spiel/welt/generator/gebaeude.gd`, aufgerufen aus
`_strukturen()` im Weltgenerator – dort, wo heute schon Bäume und Steine
gesetzt werden.

**Warum Etappe 02 zwingend vorher kommt:** Gebäude brauchen neue Blocktypen
(Planken, Ziegel, Glas, Türen). Die Blockindizes existieren doppelt – als
Konstanten in `world_generator.gd` und als Array-Reihenfolge in der
`VoxelBlockyLibrary`, die inline in `main.tscn` steckt. Ein Block an falscher
Stelle eingefügt, und die ganze Welt besteht aus dem falschen Material, ohne
Fehlermeldung beim Start.

---

## Umbau der Struktur

Vollständige Begründung jeder Etappe:
https://claude.ai/code/artifact/3a91d0bc-689d-43f8-8e58-c50fbe6a3cc9

| Etappe | Inhalt | Stand |
|---|---|---|
| 00 | Aufräumen, Editor-Reste, `.gitignore` | **erledigt** – `73953f1` |
| 01 | Ordner nach Feature, Dateien verschieben | **erledigt** – `4390b9e` |
| 02 | Szene zerlegen | offen – **der Flaschenhals** |
| 03 | Kopplung entschärfen | offen |
| 04 | Oberflächen zusammenführen | offen |
| 05 | Dokumentieren und benennen | teilweise |

### Etappe 02 – Szene zerlegen

Der wichtigste Einzelschritt. Aus einer Datei mit 50 Knoten werden vier Szenen,
die einander instanzieren.

- Blockbibliothek aus `main.tscn` nach `daten/welt/bloecke.tres` herauslösen
- `spiel/welt/bloecke.gd` als **einzige** Quelle der Blockindizes anlegen,
  `world_generator.gd` darauf umstellen, Reihenfolge gegen die `.tres` prüfen
- Spielerkörper als `koerper.tscn` speichern
  (Rechtsklick → "Verzweigung als Szene speichern")
- `spieler.tscn`, `welt.tscn`, `ui.tscn` abtrennen, `main.tscn` instanziert nur
  noch – aus 405 Zeilen werden rund 40
- Wurzelknoten `Node3D` → `Welt` umbenennen

Nebeneffekt: `main.tscn` wird wieder diffbar, Git zeigt endlich sinnvoll an,
was sich geändert hat.

### Etappe 03 – Kopplung entschärfen

- Knotennamen, die im Code stehen, als Konstanten an eine Stelle:
  `const KNOTEN_KAMPF := ^"Kampf"`
- Wo eine Teilszene den Knoten mitbringt: `@export` statt `find_child`
- Fehlende Pflichtknoten durchgehend mit `push_error` melden
- Gruppen dokumentieren – sie sind die Schnittstelle für die NPCs

### Etappe 04 – Oberflächen zusammenführen

- `spiel/ui/stil/palette.gd` – alle Farben aus den vier UI-Dateien an eine Stelle
- `spiel/ui/stil/bausteine.gd` – `knopf()`, `regler_zeile()`, `panel()`,
  `titel()` einmal statt viermal. `pause_menue.gd` hat die besten Vorlagen.
- Danach die großen Dateien an den vorhandenen Abschnittskommentaren trennen:
  `karte.gd` → Gelände / Erkundung / Oberfläche,
  `inventar_ui.gd` → `slot_feld.gd` herauslösen

### Etappe 05 – Dokumentieren und benennen

Dokumentation ist erledigt: `README.md`, `CLAUDE.md`, `docs/architektur.md`,
`docs/dateien.md`, `docs/konventionen.md` und diese Datei.

Offen: die sieben englischen Dateinamen und die Ordner `materials/`, `meshes/`,
`plants/` umbenennen, in einem eigenen Commit. Liste in
[konventionen.md](konventionen.md).

---

## Bewusst nicht auf der Liste

- **Git-Historie säubern.** Die 44 MB stammen aus einer einmal versehentlich
  eingecheckten 7,5-MB-DLL. Der Blob liegt bereits auf GitHub – Umschreiben
  bräuchte einen Force-Push und würde jeden vorhandenen Klon entwerten.
- **Addons auf Git LFS.** Gleiche Kosten. Mitversioniert bleibt das Projekt aus
  einem einzigen Klon lauffähig, und das ist mehr wert als 101 MB.
- **Tests (GUT, gdUnit4).** Sinnvoll für `world_generator.gd` und `combat.gd` –
  aber erst, wenn die Struktur steht.
- **Oberflächen auf `.tscn` umbauen.** Der Layoutcode funktioniert und die
  Kopfkommentare begründen die Entscheidung nachvollziehbar. Ein gemeinsames
  Theme (Etappe 04) löst das eigentliche Problem, ein Umbau auf Szenen wäre ein
  Neuschreiben.
