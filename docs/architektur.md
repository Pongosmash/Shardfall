# Architektur

Wer redet mit wem, worüber, und warum so. Für die reine Ablage siehe
[dateien.md](dateien.md), für Namensregeln [konventionen.md](konventionen.md).

Stand: 20.08.2026, nach Etappe 01 des Umbaus (siehe [roadmap.md](roadmap.md)).

---

## 1. Was Shardfall technisch ist

Ein Voxel-Spiel in **Godot 4.6** mit Third-Person-Kamera. Die Welt besteht aus
Blöcken und wird zur Laufzeit aus Rauschfunktionen erzeugt – nichts davon liegt
als Datei vor. Charaktere sind Würfelfiguren ohne Skelett: keine Arme, keine
Beine, nur Hände und Füße, die als einzelne `Node3D` verschoben werden.

| Baustein | Wahl | Grund |
|---|---|---|
| Renderer | `gl_compatibility` | breite Hardwareunterstützung |
| Physik | Jolt Physics | stabiler bei vielen statischen Blöcken |
| Voxel | Addon `zylann.voxel` (GDExtension) | `VoxelTerrain` + `VoxelMesherBlocky` |
| Skriptsprache | GDScript | — |

Das Addon liegt mitversioniert in `addons/zylann.voxel/` (rund 101 MB, alle
Plattform-Binärdateien). Das ist Absicht: so ist ein frischer Klon sofort
lauffähig. **Fremdcode – nie verändern.**

---

## 2. Szenenbaum

Alles steckt in einer einzigen Szene: `szenen/main.tscn`. Das ist die größte
offene Baustelle, siehe Abschnitt 10.

```
Node3D                                  <- Wurzel, sollte "Welt" heißen
├─ VoxelTerrain                         generator + Blockbibliothek inline (!)
├─ DirectionalLight3D
├─ Player                    CharacterBody3D · spiel/akteure/spieler/player.gd
│  ├─ CollisionShapePlayer               Kapsel, wird beim Ducken skaliert
│  ├─ MeshInstancePlayer
│  ├─ Visual                 spiel/akteure/gemeinsam/character_visual.gd
│  │  └─ Neigung                         legt den Körper in Kurven
│  │     ├─ Huefte
│  │     │  ├─ TorsoUnten
│  │     │  └─ Brust                     dreht beim Schlagen, beugt beim Schleichen
│  │     │     ├─ TorsoOben
│  │     │     ├─ Kopf ─ KopfMesh
│  │     │     ├─ HandLinks  ─ HandLinksMesh,  HalterLinks   <- Waffe links
│  │     │     └─ HandRechts ─ HandRechtsMesh, HalterRechts  <- Waffe rechts
│  │     ├─ FussLinks  ─ FussLinksMesh
│  │     └─ FussRechts ─ FussRechtsMesh
│  ├─ SpringArmPivot         spiel/kamera/spring_arm_camera.gd
│  │  ├─ SpringArm3D ─ SpringPosition
│  │  └─ Camera3D            spiel/kamera/camera_follow.gd
│  │     └─ VoxelViewer                  bestimmt, welche Chunks geladen werden
│  ├─ Combat                 spiel/akteure/gemeinsam/combat.gd
│  ├─ Inventar               spiel/akteure/spieler/inventar.gd
│  └─ Ausruestung            spiel/akteure/gemeinsam/ausruestung.gd
├─ WorldEnvironment                      Himmel-Shader, Nebel
├─ CloudLayer                spiel/welt/cloud_layer.gd
├─ Underwater                spiel/welt/underwater.gd
├─ HUD                       spiel/ui/hud/hud.gd
├─ InventarUI                spiel/ui/inventar/inventar_ui.gd
├─ Karte                     spiel/ui/karte/karte.gd
├─ Trainingspuppe ─ Mesh     spiel/akteure/npc/trainingspuppe.gd
├─ DekoLayer                 spiel/welt/deko_layer.gd
└─ PauseMenue                spiel/ui/menue/pause_menue.gd
```

**Wichtig:** `HalterRechts` und `HalterLinks` sind leere `Node3D`. Dort hängt
`ausruestung.gd` die Waffenmodelle ein. Wer diese Knoten umbenennt, macht Waffen
unsichtbar – ohne Fehlermeldung, siehe Abschnitt 10.

---

## 3. Die vier Oberflächen bauen sich selbst

`hud.gd`, `inventar_ui.gd`, `karte.gd` und `pause_menue.gd` erzeugen ihre
gesamte Control-Hierarchie im Code. In der Szene steht jeweils nur ein einzelner
Knoten. Das ist bewusst so – die Kopfkommentare begründen es:

- **HUD** rechnet Positionen jedes Bild aus der Fenstergröße statt Godots
  Ankersystem zu benutzen, damit nichts das Layout überschreibt.
- **Pausenmenü** muss die Zeilen der Tastenbelegung ohnehin zur Laufzeit aus dem
  `InputMap` erzeugen.

Folge: Ein neues Fenster heißt Layoutcode schreiben, nicht eine Szene bauen.
Es gibt **kein gemeinsames `Theme`** – jede der vier Dateien führt ihre eigene
Farbpalette und eigene Fabrikfunktionen für Knöpfe, Panels und Regler. Das
zusammenzuführen ist Etappe 04.

---

## 4. Wie die Teile einander finden

Drei Mechanismen, in dieser Reihenfolge bevorzugt:

### a) `@export` – im Inspektor verdrahtet (bevorzugt)

| Knoten | Feld | zeigt auf |
|---|---|---|
| `Player` | `camera_pivot` | `SpringArmPivot` |
| `SpringArmPivot` | `player` | `Player` |
| `Camera3D` | `target`, `player` | `SpringPosition`, `Player` |
| `Karte` | `terrain`, `ziel` | `VoxelTerrain`, `Player` |
| `DekoLayer` | `terrain`, `ziel` | `VoxelTerrain`, `Player` |
| `Underwater` | `camera`, `terrain`, `world_env` | — |
| `CloudLayer` | `folge_ziel` | `Player` |
| `Visual` | `player_path` | `^".."` (Vorgabe) |

Bleibt ein Pflichtfeld leer, meldet `_ready()` das per `push_error` und schaltet
sich ab. Kein stiller Ausfall.

### b) Gruppen – für lose Beziehungen über die Szene hinweg

| Gruppe | wer tritt bei | wer fragt danach |
|---|---|---|
| `player` | `player.gd` | `hud.gd`, `inventar_ui.gd`, `trainingspuppe.gd` |
| `damageable` | `player.gd`, `trainingspuppe.gd` | `combat.gd` (Trefferprüfung) |
| `humanoid` | `player.gd` | noch niemand – für künftige NPC-Zielwahl |
| `inventar` | `inventar.gd` | noch niemand |

Ein Ziel in `damageable` muss `take_damage(menge, angreifer, richtung)` haben.
Das ist der einzige Vertrag, den das Kampfsystem an Gegner stellt – deshalb
reicht für einen neuen Gegner diese eine Methode.

### c) Namenssuche – der schwächste Weg

| Sucher | sucht | wie |
|---|---|---|
| `combat.gd` | `Ausruestung` | `find_child(name_ausruestung, true, false)` am Elternknoten |
| `player.gd` | `Combat` | `get_node_or_null("Combat")` |
| `hud.gd` | `Combat` | über Gruppe `player`, dann `get_node_or_null("Combat")` |
| `inventar_ui.gd` | `Inventar`, `Visual` | ebenso |
| `ausruestung.gd` | `HalterRechts`, `HalterLinks` | `find_child(..., owned = false)` |
| `character_visual.gd` | 16 feste Pfade | `"Neigung/Huefte/Brust/HandRechts"` usw. |

Das `owned = false` bei `ausruestung.gd` ist kein Versehen: es lässt die Suche
**in instanzierte Unterszenen hineingehen**. Godot erlaubt es nicht, einen Knoten
aus einer instanzierten Szene in ein Exportfeld der äußeren Szene zu ziehen –
deshalb der Umweg. Nach Etappe 02 (Körper wird eigene Szene) bleibt das nötig.

---

## 5. Signale

| Sender | Signal | Bedeutung |
|---|---|---|
| `Combat` | `getroffen(menge)` | Schaden ist durchgekommen |
| `Combat` | `geblockt(menge)` | normal geblockt |
| `Combat` | `perfekt_geblockt()` | Parry gelungen |
| `Combat` | `deckung_gebrochen()` | Ausdauer reichte zum Blocken nicht |
| `Ausruestung` | `ausruestung_geaendert(slot, daten)` | ein Slot hat gewechselt |
| `Ausruestung` | `waffe_gewechselt(daten)` | die aktive Waffe ist eine andere |
| `Inventar` | `geaendert` | ein Inventarplatz hat sich verändert |
| `Inventar` | `ausruestung_geaendert` | ein Ausrüstungsslot hat sich verändert |
| `Einstellungen` | `audio_geaendert` | Lautstärken |
| `Einstellungen` | `video_geaendert` | Fenstermodus, VSync, FPS, 3D-Skalierung |
| `Einstellungen` | `spiel_geaendert` | Sichtfeld, Maussensitivität, Y-Invertierung |
| `Einstellungen` | `tasten_geaendert` | Tastenbelegung |
| `PauseMenue` | `geoeffnet`, `geschlossen` | — |

`Combat` verbindet sich beim Start selbst auf `Ausruestung.waffe_gewechselt`
und bricht dabei eine laufende Kombo ab – ein Zweihänder soll nicht mitten in
einer Faustkombo weiterzählen.

---

## 6. Datenfluss Kampf: eine Quelle, drei Leser

Das ist das sauberste Stück Architektur im Projekt und die Vorlage für alles
Weitere.

```
   daten/waffen/*.tres  (WaffenDaten)
            │
            ▼
      Ausruestung ────── waffe_gewechselt ──────┐
            │                                   │
   aktive_waffe()                               ▼
            │                                Combat
            ▼                        einzige Quelle für Timing
   HalterRechts/-Links               und Schaden - kein zweiter
   bekommt das Modell                Timer daneben!
                                          │
                     aktiver_stil() ──────┤────── angriff_fortschritt
                     schlag_marken() ─────┤────── hand_links
                                          ▼
                                  character_visual.gd
                                  liest nur, rechnet nie
                                  eigenes Timing
```

`schlag_marken()` liefert `Vector2(x, y)` im normierten Schlagverlauf 0..1:
`x` = Ende des Ausholens / Beginn des Trefferfensters, `y` = Ende des
Trefferfensters. Die Optik legt ihre Kurve exakt darauf.

**Diese Trennung nicht aufweichen.** Ein zweiter Timer in der Animation würde
vom Kampf-Timing abdriften und sichtbaren Schlag von echtem Treffer entkoppeln.

Eine neue Waffe ändert Reichweite, Timing, Haltung und Animation, ohne dass
Code angefasst wird – `WaffenDaten.stil` wählt die Schlagpose
(`FAUST`, `STICH`, `HIEB`, `SCHWUNG_SCHWER`, `STANGE`).

---

## 7. Datenfluss Welt

```
        WorldGenerator (VoxelGeneratorScript)
        Rauschen -> Höhe, Biom, Flüsse, Bäume, Steine
                 │
     ┌───────────┼────────────────────┬──────────────────┐
     ▼           ▼                    ▼                  ▼
VoxelTerrain  hoehe_bei(x,z)    deko_bei(x,z)    baum_plan_bei(cx,cz)
_generate_       │                    │                  │
block()          ▼                    ▼                  ▼
              Karte               DekoLayer            Karte
        (Miniaturgelände)    (Gras/Blumen als      (Bäume auf
                              MultiMesh im          der Karte)
                              Spielerumkreis)
```

Der Kniff: **Karte und Deko laden keine Chunks.** Sie tasten dieselben
Rauschfunktionen erneut ab. Das ist um Größenordnungen billiger als eine zweite
Kamera auf die echte Welt und funktioniert auch für Gebiete, die gar nicht
geladen sind.

Beide holen sich den Generator über `terrain.generator as WorldGenerator` und
prüfen mit `has_method("deko_bei")`, ob die Version zusammenpasst.

### Deko: zwei sich ausschließende Wege

`WorldGenerator.deko_als_voxel` schaltet um:

- **`false` (Standard):** Gras und Blumen kommen von `deko_layer.gd` als
  MultiMesh, nur im Umkreis des Spielers. Acht Draw Calls insgesamt statt
  Geometrie in jedem Chunk.
- **`true`:** alte Variante, Deko steckt als Voxel in den Chunks.

**Niemals beides gleichzeitig** – sonst stehen die Pflanzen doppelt da.

### Blockindizes – die gefährlichste Stelle im Projekt

Die Indizes existieren **doppelt**:

1. als Konstanten in `spiel/welt/generator/world_generator.gd`
   (`AIR = 0`, `WATER = 1`, `GRASS = 2` … `FELS = 19`)
2. als **Reihenfolge** im `models`-Array der `VoxelBlockyLibrary`,
   die inline in `szenen/main.tscn` steckt

Ein Block an falscher Stelle eingefügt, und die ganze Welt besteht aus dem
falschen Material – ohne Fehler beim Start. Beim Hinzufügen eines Blocktyps
**immer beide Stellen prüfen.** Etappe 02 löst das auf.

---

## 8. Speicherstände

| Datei | Inhalt | verwaltet von |
|---|---|---|
| `user://einstellungen.cfg` | Audio, Video, Sichtfeld, Maus, Tastenbelegung | `einstellungen.gd` |
| `user://karte_entdeckt.dat` | Set der entdeckten Kartenkacheln | `karte.gd` |

Die Karte trennt zwei Begriffe streng:

- **entdeckt** – dauerhaftes Wissen, wächst nur, wird gespeichert
- **gebaut** – Geometrie im Speicher, wird nach Budget wieder freigegeben

Freigegebene Kacheln verlieren das Wissen nicht, sie werden bei Bedarf neu
aufgebaut. `alles_aufdecken()` und `erkundung_zuruecksetzen()` sind zum Testen da.

Es gibt **noch keinen Spielstand** – Spielerposition, Inventar und Ausrüstung
überleben das Beenden nicht.

---

## 9. Eingabe

Belegung aus `project.godot`:

| Aktion | Taste | benutzt von |
|---|---|---|
| `move_forward` / `move_back` / `move_left` / `move_right` | W A S D | `player.gd` (`Input.get_vector`) |
| `sprint` | Shift | `player.gd`, `camera_follow.gd` (Sichtfeld-Zuschlag) |
| `sneak` | Strg | `player.gd`, `character_visual.gd` |
| `free_look` | Alt | `spring_arm_camera.gd` |
| `attack` | Maus links | `combat.gd` |
| `block` | Maus rechts | `combat.gd` |
| `inventory` | I | `inventar_ui.gd` |
| `map` | M | `karte.gd` |
| `wheel_up` / `wheel_down` | Mausrad | `spring_arm_camera.gd` (Zoom) |

Nicht in `project.godot`, sondern Godot-Vorgaben:

| Aktion | Taste | benutzt von |
|---|---|---|
| `ui_accept` | Leertaste | **Springen** in `player.gd` |
| `ui_cancel` | ESC | Pausenmenü öffnen, Inventar und Karte schließen |

ESC ist bewusst nur an einer Stelle ausgewertet: `player.gd` fasst `ui_cancel`
absichtlich nicht mehr an, sonst würden zwei Seiten daran ziehen.

---

## 10. Bekannte Schwachstellen

Kein Wunschzettel, sondern Dinge, die beim Weiterbauen konkret zubeißen.

### Eine Szene für alles
`szenen/main.tscn` hat rund 50 Knoten und keine einzige Teilszene. Der
Spielerkörper (15 Knoten) existiert genau einmal, fest verdrahtet. Ein NPC
hieße: von Hand nachbauen, pro Gegnertyp. → Etappe 02.

### Blockbibliothek inline
Rund 200 der 405 Zeilen von `main.tscn` sind 20 Blockmodelle mit Materialien.
Zusammen mit der doppelten Index-Definition (Abschnitt 7) die größte Fußangel
für neue Blocktypen. → Etappe 02.

### Die Tastenbelegung zeigt Engine-Namen
`einstellungen.gd` führt in `AKTIONS_NAMEN` dreizehn deutsche Anzeigenamen
(`vorwaerts`, `springen`, `angriff`, `inventar`, …). **Keiner dieser
Aktionsnamen existiert im InputMap** – dort heißen sie `move_forward`,
`attack`, `inventory`. `belegbare_aktionen()` fällt deshalb auf seine
Notlösung zurück und listet alle Nicht-`ui_`-Aktionen mit automatisch
erzeugtem Namen. Im Menü steht also "Move forward" statt "Vorwärts", und die
dreizehn deutschen Namen sind toter Code.

Zwei Wege: entweder die Aktionen in `project.godot` deutsch umbenennen (passt
zur Namenskonvention, bricht aber alle `is_action`-Aufrufe), oder
`AKTIONS_NAMEN` auf die tatsächlichen Schlüssel umschreiben. Das Zweite ist
billiger.

### Springen ist nicht umbelegbar
`player.gd` springt auf `ui_accept`. `belegbare_aktionen()` überspringt alles,
was mit `ui_` beginnt – Springen taucht im Menü also gar nicht auf. Abhilfe:
eine echte Aktion in `project.godot` anlegen und `player.gd` darauf umstellen.

### Vier Oberflächen, vier Designsysteme
Rund 2.900 Zeilen Layoutcode, jede Datei mit eigener Palette und eigenen
Fabrikfunktionen. `Color(0.88, 0.89, 0.92)` steht wortgleich in zwei Dateien.
→ Etappe 04.

### Fest getippte Knotennamen
`"Combat"`, `"Inventar"`, `"Ausruestung"`, `"Visual"`, `"HalterRechts"` und die
16 Pfade in `character_visual.gd` stehen als Zeichenketten im Code. Umbenennen
bricht das Spiel erst zur Laufzeit, oft nur sichtbar als "die Waffe fehlt".
→ Etappe 03.

### Kein Spielstand
Nur Einstellungen und Kartenerkundung überleben. Position, Inventar und
Ausrüstung nicht.
