# Roadmap

Zwei Stränge, die sich abwechseln: **Spielinhalt** (was Shardfall können soll)
und **Umbau** (was die Struktur tragen muss, damit der Inhalt bezahlbar bleibt).

**Seit Etappe 02 ist nichts mehr blockiert.** Das hat sich sofort ausgezahlt:
der erste NPC, fünf Waffen und ein Tag-Nacht-Zyklus sind seitdem
dazugekommen, ohne dass die Struktur dafür noch einmal angefasst werden musste.

Diese Datei ersetzt das frühere `Urgent_Shardfall_ToDos.md`.

Stand: 23.09.2026.

---

## Spielinhalt

### 1 · Gegenstände richtig ausrüsten, Waffen ändern Angriff und Haltung

**Stand: Waffen sind da, die Brücke zum Inventar fehlt.**

Erledigt:

- **Fünf Waffen** in `daten/waffen/`: Kurzschwert (Stich), Axt (Hieb),
  Zweihänder (schwerer Schwung), Speer (Stange), Holzschild. Jeder Waffenstil
  ist damit einmal belegt. Erzeugt mit `werkzeuge/waffen_erzeugen.gd`, Meshes
  aus Quadern passend zur Würfeloptik.
- **Waffenhaltung.** `character_visual.gd` dreht den Waffenhalter unter der
  Hand – Ruhehaltung, Deckung, Ausholen und Durchziehen je Stil, beidhändige
  Waffen mit zweiter Hand am Schaft, Schild vor der linken Körperhälfte. Die
  Posen sind gegen die Körperkästen gerechnet, keine Klinge fährt durch Kopf
  oder Brust.
- **Griff und Führung getrennt.** Der Speer ist zweihändig, lässt aber ein
  Schild daneben zu und wird dann einhändig geführt – mit Abschlägen auf
  Schaden, Tempo, Reichweite, Ausdauer und Wucht (`kann_einhaendig`,
  `erzwingt_zwei_haende()`, `einhand_fassung()`).
- Der Spieler startet mit **Speer und Holzschild** (`start_ausruestung` in
  `spieler.tscn`).

Es fehlt:

- **Inventar und Ausrüstung verbinden.** `inventar.gd` (`ItemDaten`) und
  `ausruestung.gd` (`WaffenDaten`) wissen nichts voneinander. Was im
  Inventar in die Haupthand gezogen wird, erscheint nicht in der Hand; was in
  der Hand ist, kommt nur aus `start_ausruestung`. Braucht eine Entscheidung,
  ob `ItemDaten` auf eine `WaffenDaten` verweist oder `WaffenDaten` von
  `ItemDaten` erbt.
- Waffenwechsel im Spiel (heute nur über den Inspektor).
- Rüstung – `daten/ruestung/` ist angelegt, aber leer, und `WaffenDaten.Slot`
  kennt `KOPF`, `BRUST`, `BEINE` bisher nur als Aufzählungswerte.

### 2 · NPCs

**Stand: feindlicher NPC steht, drei Verhaltensarten offen.**

| Art | Verhalten | Stand |
|---|---|---|
| feindlich | greift an, sobald er den Spieler sieht oder dieser zu nah kommt | **erledigt** – `ki/feindlich.gd` |
| neutral | greift an, wenn er angegriffen wurde | offen |
| passiv | rennt weg, wenn er angegriffen wurde | offen |
| freundlich | kann angesprochen werden | offen |

Erledigt:

- **`akteur.gd`** – gemeinsame Basisklasse von `Player` und `Npc`. `combat.gd`
  und `character_visual.gd` hängen nicht mehr an `Player`, sondern an diesem
  Vertrag.
- **`npc.tscn`** als Gegenstück zu `spieler.tscn`: dasselbe Rig, `Combat` mit
  `von_spieler_gesteuert = false`, Knoten `Ki`.
- **`npc.gd`** – Laufen, Stufensteigen, einfaches Schwimmen, Tod mit Umfallen,
  Liegenbleiben, Versinken und Aufräumen.
- **`ki/feindlich.gd`** – Erkennung über Radius und Sichtlinie, Verfolgen mit
  Gedächtnis, Angriff im Nahbereich, gewürfeltes Blocken mit Reaktionszeit.
- **KI-Schnittstelle in `combat.gd`:** `ki_angreifen()` und `ki_blocken()`
  statt simulierter Tasten – `Input` ist global und hätte sonst jeden NPC
  mitschlagen lassen.

Nächste Schritte, grob nach Nutzen:

1. **Neutral und passiv** als weitere Skripte in `ki/`. Beide brauchen dasselbe
   Signal "wurde angegriffen" – `Combat.getroffen` gibt es schon.
2. **Dem NPC eine Waffe geben.** `npc.tscn` hat eine `Ausruestung`, aber nur
   mit `faust_daten`. Eine Waffe in `start_ausruestung` reicht, Haltung und
   Schlagpose kommen dann von selbst.
3. **NPC-Vorlagen** als `daten/npcs/*.tres`: Leben, Tempo, Ausrüstung,
   Verhaltensart, Proportionen. Dann ist ein Ork eine Datei, keine Szene.
4. **Bewegungscode teilen.** `npc.gd` hat Stufensteigen und Wassererkennung
   aus `player.gd` kopiert. Spätestens beim zweiten NPC-Typ in eine gemeinsame
   Komponente unter `akteure/gemeinsam/` ziehen.
5. **Parteien.** `combat.gd` trifft alles in `damageable` außer sich selbst –
   NPCs untereinander und die Trainingspuppe eingeschlossen. Für mehrere
   NPCs braucht es eine Freund-Feind-Unterscheidung.
6. Die Trainingspuppe wird `trainingspuppe.tscn` – sie ist der letzte Knoten,
   der noch lose in `main.tscn` steht.

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
Beides ist jetzt einfacher: `main.tscn` ist mit 30 Zeilen so klein, dass eine
zweite Einstiegsszene daneben keine Doppelpflege bedeutet. Ein Spielstand
müsste inzwischen auch die Uhrzeit (`Tageszeit.stunde`) mitnehmen.

### 4 · Gebäude

**Stand: offen, aber der Weg ist frei.**

Landet als `spiel/welt/generator/gebaeude.gd`, aufgerufen aus `_strukturen()`
im Weltgenerator – dort, wo heute schon Bäume und Steine gesetzt werden.

Neue Blocktypen (Planken, Ziegel, Glas, Türen) sind seit Etappe 02 kein Risiko
mehr. Der Ablauf:

1. Modell in `daten/welt/bloecke.tres` **ans Ende** des `models`-Arrays hängen
2. Konstante in `spiel/welt/bloecke.gd` ergänzen, Eintrag in `NAMEN[]`,
   `ANZAHL` erhöhen
3. `werkzeuge/bloecke_namen.gd` ausführen – meldet es "in Ordnung", stimmt die
   Reihenfolge

Vorher standen die Indizes doppelt und ein verrutschtes Modell ließ die ganze
Welt aus dem falschen Material bestehen, ohne Fehlermeldung.

**Voraussetzung:** `bloecke_namen.gd` muss einmal mit `SCHREIBEN = true`
gelaufen sein, sonst ist die Prüfung nicht scharf – siehe unten.

### 5 · Tag und Nacht

**Stand: erledigt.**

`spiel/welt/tageszeit.gd` besitzt die Uhrzeit (ein Spieltag = 20 Minuten) und
steuert ein einziges Licht, das tags die Sonne und nachts der Mond ist. Der
Himmel-Shader bekam Nachtfarben, Dämmerungsglühen, eine Mondscheibe mit
Kratern und einen drehenden Sternenhimmel; Wolken dunkeln ab, und der Nebel
zieht über `underwater.gd` mit. Details in
[architektur.md](architektur.md) Abschnitt 8.

Denkbar, aber nicht geplant: NPC-Verhalten nach Tageszeit, Fackeln und andere
Punktlichter, Schlafen.

---

## Umbau der Struktur

Vollständige Begründung jeder Etappe:
https://claude.ai/code/artifact/3a91d0bc-689d-43f8-8e58-c50fbe6a3cc9

| Etappe | Inhalt | Stand |
|---|---|---|
| 00 | Aufräumen, Editor-Reste, `.gitignore` | **erledigt** – `73953f1` |
| 01 | Ordner nach Feature, Dateien verschieben | **erledigt** – `4390b9e` |
| 05a | Dokumentation | **erledigt** – `faafbd4` |
| 02 | Szene zerlegen | **erledigt** – bis auf eine Restarbeit |
| 03 | Kopplung entschärfen | teilweise erledigt |
| 04 | Oberflächen zusammenführen | offen |
| 05b | Umbenennen | offen |

### Etappe 02 – Szene zerlegen · erledigt

Aus einer Datei mit 405 Zeilen und rund 50 Knoten sind fünf Szenen geworden,
mit dem NPC inzwischen sechs:

| Szene | Zeilen | Inhalt |
|---|---:|---|
| `szenen/main.tscn` | 30 | Wurzelknoten `Spiel`, instanziert nur noch |
| `spiel/welt/welt.tscn` | 146 | Gelände, Licht, Himmel, Wolken, Wasser, Deko, Tageszeit |
| `spiel/akteure/spieler/spieler.tscn` | 75 | Spieler mit Kamera und Komponenten |
| `spiel/akteure/npc/npc.tscn` | 35 | NPC mit Kampf und KI – nach Etappe 02 dazugekommen |
| `spiel/akteure/gemeinsam/koerper.tscn` | 72 | **Das Rig – für Spieler und NPC dieselbe Datei** |
| `spiel/ui/ui.tscn` | 20 | Die vier Oberflächen |

Dazu:

- Blockbibliothek nach `daten/welt/bloecke.tres` herausgelöst
- `spiel/welt/bloecke.gd` (`class_name Bloecke`) als einzige Quelle der Indizes,
  mit deutschen Namen (`LUFT`, `WASSER`, `GRAS`, `STEIN`, `ERDE`)
- `world_generator.gd` reicht sie unter den alten Namen weiter, weil
  `deko_layer.gd` achtzehnmal `WorldGenerator.GRAS_KURZ` und Verwandte liest
- `werkzeuge/bloecke_namen.gd` prüft Konstanten gegen die `.tres`
- Wurzelknoten `Node3D` → `Spiel`
- Neue Gruppe `gelaende` für das `VoxelTerrain`

**Der eigentliche Gewinn steckt in einem Nebeneffekt:** Godot lässt keinen
`NodePath` über eine Szenengrenze hinweg zu. Aus Pflicht-Exports sind
Rückfälle auf Gruppen geworden – `terrain`, `ziel`, `folge_ziel` und `camera`
suchen sich ihr Gegenüber jetzt selbst, das Exportfeld bleibt als
Übersteuerung. Das ist lockerer gekoppelt als vorher und war der Grund, das
überhaupt anzufassen.

Dabei aufgefallen und behoben: Die Gruppenregistrierung des Spielers musste von
`_ready()` nach `_enter_tree()` wandern. Godot arbeitet den gesamten Baum mit
`_enter_tree` ab, bevor irgendein `_ready` läuft – in `_ready()` wäre die
Gruppe `player` für `deko_layer.gd` und `cloud_layer.gd` aus `welt.tscn` noch
leer gewesen. `npc.gd` macht es für `damageable` genauso.

**Restarbeit:** `werkzeuge/bloecke_namen.gd` ist noch nicht mit
`SCHREIBEN = true` gelaufen. In `daten/welt/bloecke.tres` steht kein einziger
`resource_name`, die Reihenfolgeprüfung ist damit noch nicht scharf. Ablauf
steht im Kopfkommentar des Werkzeugs – zwei Minuten Arbeit, danach ist die
Fußangel endgültig zu.

Etappe 02 und alles, was danach kam (NPC, Waffen, Tageszeit), ist in
**einem** gemeinsamen Commit auf `umbau/struktur` gelandet, noch nicht auf
`main`.

### Etappe 03 – Kopplung entschärfen · teilweise

Schon erledigt:

- Gruppen sind dokumentiert und werden aktiv genutzt (`player`, `gelaende`,
  `damageable`, `humanoid`, `inventar`)
- Fehlende Referenzen melden sich durchgehend mit `push_error` oder
  `push_warning` und schalten sich ab
- `combat.gd` und `character_visual.gd` hängen an der Basisklasse `Akteur`
  statt an `Player` – der größte Kopplungspunkt zwischen Spieler und
  Gemeinsamem ist damit weg

Offen:

- Knotennamen, die im Code stehen, als Konstanten an eine Stelle:
  `const KNOTEN_KAMPF := ^"Kampf"`. Betrifft `"Combat"`, `"Inventar"`,
  `"Ausruestung"`, `"Visual"`, `"HalterRechts"`, `"HalterLinks"` und die 18
  festen Pfade in `character_visual.gd`. Mit `npc.gd` ist ein weiterer Leser
  von `"Combat"` und `"Visual"` dazugekommen.

### Etappe 04 – Oberflächen zusammenführen

- `spiel/ui/stil/palette.gd` – alle Farben aus den vier UI-Dateien an eine Stelle
- `spiel/ui/stil/bausteine.gd` – `knopf()`, `regler_zeile()`, `panel()`,
  `titel()` einmal statt viermal. `pause_menue.gd` hat die besten Vorlagen.
- Danach die großen Dateien an den vorhandenen Abschnittskommentaren trennen:
  `karte.gd` → Gelände / Erkundung / Oberfläche,
  `inventar_ui.gd` → `slot_feld.gd` herauslösen

`character_visual.gd` ist mit 1.261 Zeilen inzwischen die größte Datei. Die
Posentabelle `_stil_posen` samt ihrer Herleitung wäre ein naheliegender
Kandidat zum Herauslösen – etwa als `waffen_posen.gd` – gehört aber nicht zu
dieser Etappe, sondern kommt, wenn die Datei beim Arbeiten stört.

### Etappe 05b – Umbenennen

Die sieben englischen Dateinamen und die Ordner `materials/`, `meshes/`,
`plants/` umbenennen, in einem eigenen Commit. Liste in
[konventionen.md](konventionen.md).

Dazu die Verwendungsstellen der Blockkonstanten: `world_generator.gd` benutzt
noch `AIR`, `WATER`, `GRASS`, `STONE`, `DIRT`, während `Bloecke` schon `LUFT`,
`WASSER`, `GRAS`, `STEIN`, `ERDE` heißt. Die Weiterreichung war Absicht, damit
Etappe 02 klein bleibt – jetzt kann sie fallen.

---

## Kleinkram, der zwischendurch mitgeht

- **Debug-Ausgaben entfernen.** `inventar_ui.gd` hat zwei `print`-Aufrufe aus
  der Fehlersuche zu Etappe 02, die bei jedem Start feuern.
- **Toten Verweis in `tageszeit.gd` reparieren.** Der Kommentar in Zeile 118
  verweist auf `docs/tageszeit_plan.md`, die es nicht gibt. Auf
  `docs/architektur.md` Abschnitt 8 umbiegen.
- **Generatorparameter aufräumen.** Der `VoxelGeneratorScript`-Unterknoten in
  `welt.tscn` listet alle 31 Exportwerte als `null`. Harmlos, aber Rauschen im
  Diff – verschwindet, sobald man die Werte einmal im Inspektor anfasst.
- **Waffenmeshes gerade bauen.** Axt und Zweihänder brauchen in
  `character_visual.gd` eine Rollkorrektur (120° bzw. 90°), weil die Quader im
  Mesh quer liegen. Die Kommentare dort nennen die richtigen Maße; danach
  fallen die Korrekturen weg und die Axt schneidet sauber statt unter 30°.

---

## Bewusst nicht auf der Liste

- **Git-Historie säubern.** Die 44 MB stammen aus einer einmal versehentlich
  eingecheckten 7,5-MB-DLL. Der Blob liegt bereits auf GitHub – Umschreiben
  bräuchte einen Force-Push und würde jeden vorhandenen Klon entwerten.
- **Addons auf Git LFS.** Gleiche Kosten. Mitversioniert bleibt das Projekt aus
  einem einzigen Klon lauffähig, und das ist mehr wert als 101 MB.
- **Tests (GUT, gdUnit4).** Sinnvoll für `world_generator.gd` und `combat.gd` –
  aber erst, wenn die Struktur steht. Mit KI und Einhand-Umrechnung hat
  `combat.gd` inzwischen genug Verzweigungen, dass es näher rückt.
- **Oberflächen auf `.tscn` umbauen.** Der Layoutcode funktioniert und die
  Kopfkommentare begründen die Entscheidung nachvollziehbar. Ein gemeinsames
  Theme (Etappe 04) löst das eigentliche Problem, ein Umbau auf Szenen wäre ein
  Neuschreiben.
