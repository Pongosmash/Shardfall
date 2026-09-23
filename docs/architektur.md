# Architektur

Wer redet mit wem, worüber, und warum so. Für die reine Ablage siehe
[dateien.md](dateien.md), für Namensregeln [konventionen.md](konventionen.md).

Stand: 23.09.2026 – Etappe 02 des Umbaus, dazu der erste NPC, fünf Waffen und
der Tag-Nacht-Zyklus (siehe [roadmap.md](roadmap.md)).

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

Kollisionsebenen: **1 = Gelände**, **2 = Akteure** (Spieler und NPC). Die
Sichtprüfung der KI und die Bodensuche der Trainingspuppe fragen nur Ebene 1 ab
und sehen deshalb durch Akteure hindurch.

---

## 2. Sechs Szenen statt einer

Seit Etappe 02 ist die Szene zerlegt. `szenen/main.tscn` ist nur noch
Zusammenbau – 30 Zeilen statt 405.

```
szenen/main.tscn                        30 Zeilen
└─ Spiel  (Node3D)
   ├─ Welt              instanz von  spiel/welt/welt.tscn
   ├─ Player            instanz von  spiel/akteure/spieler/spieler.tscn
   ├─ Trainingspuppe ─ Mesh          (noch inline, wird eigene Szene)
   ├─ UI                instanz von  spiel/ui/ui.tscn
   └─ Npc               instanz von  spiel/akteure/npc/npc.tscn
```

### spiel/welt/welt.tscn — 146 Zeilen

```
Welt  (Node3D)
├─ VoxelTerrain            Gruppe "gelaende"
│                          generator = VoxelGeneratorScript (world_generator.gd)
│                          mesher.library -> daten/welt/bloecke.tres
├─ DirectionalLight3D      Sonne UND Mond, gesteuert von Tageszeit
├─ WorldEnvironment        Himmel-Shader, Nebel, Ambientlicht
├─ CloudLayer              cloud_layer.gd    -> tageszeit
├─ Underwater              underwater.gd     -> terrain, world_env, tageszeit
├─ DekoLayer               deko_layer.gd     -> terrain
└─ Tageszeit               tageszeit.gd      -> licht, world_env
```

### spiel/akteure/spieler/spieler.tscn — 75 Zeilen

```
Player  (CharacterBody3D, collision_layer = 2)   player.gd  (extends Akteur)
├─ CollisionShapePlayer     Kapsel, wird beim Ducken skaliert
├─ MeshInstancePlayer       unsichtbar, nur Rückfall
├─ Visual                   instanz von koerper.tscn
├─ SpringArmPivot           spring_arm_camera.gd  -> player
│  ├─ SpringArm3D ─ SpringPosition
│  └─ Camera3D              camera_follow.gd      -> target, player
│     └─ VoxelViewer        bestimmt, welche Chunks geladen werden
├─ Combat                   combat.gd
├─ Ausruestung              ausruestung.gd        -> faust_daten,
│                                                    start_ausruestung = [Speer, Holzschild]
└─ Inventar                 inventar.gd
```

### spiel/akteure/npc/npc.tscn — 29 Zeilen

Das Gegenstück zum Spieler. Dasselbe Rig, dieselbe Kampfkomponente, statt
Kamera und Eingabe ein KI-Knoten.

```
Npc  (CharacterBody3D, collision_layer = 2)      npc.gd  (extends Akteur)
├─ CollisionShapeNpc        Kapsel r = 0.33, h = 1.7 – schrumpft nicht
├─ Visual                   instanz von koerper.tscn, y = -0.85
├─ Combat                   combat.gd   von_spieler_gesteuert = false
│                                       max_leben = 60, max_kombo = 1
└─ Ki                       ki/feindlich.gd
```

**Keine `Ausruestung`.** Der NPC kämpft deshalb mit den Faust-Rückfallwerten
aus `combat.gd`, und beim Start stehen zwei Warnungen in der Ausgabe – siehe
Abschnitt 11.

### spiel/akteure/gemeinsam/koerper.tscn — 72 Zeilen

**Der Kern von Etappe 02.** Das Würfel-Rig als eigene Szene, für Spieler und
NPCs dieselbe Datei.

```
Visual  (Node3D)                       character_visual.gd
└─ Neigung                             legt den Körper in Kurven
   ├─ Huefte
   │  ├─ TorsoUnten
   │  └─ Brust                         dreht beim Schlagen, beugt beim Schleichen
   │     ├─ TorsoOben
   │     ├─ Kopf ─ KopfMesh
   │     ├─ HandLinks  ─ HandLinksMesh,  HalterLinks   <- Waffe links
   │     └─ HandRechts ─ HandRechtsMesh, HalterRechts  <- Waffe rechts
   ├─ FussLinks  ─ FussLinksMesh
   └─ FussRechts ─ FussRechtsMesh
```

Proportionen und Laufparameter stehen als überschriebene Exportwerte in der
Szene, nicht im Skript – ein NPC kann also andere Maße haben, ohne dass eine
Zeile Code anders läuft.

`HalterRechts` und `HalterLinks` sind leere `Node3D`, jeweils um `z = -0.12`
versetzt. Zwei Skripte greifen darauf zu, mit streng getrennten Rechten:

| wer | schreibt | wohin |
|---|---|---|
| `character_visual.gd` | nur `rotation` | auf den **Halter** – führt die Waffe |
| `ausruestung.gd` | `halte_versatz`, `halte_drehung`, `halte_skalierung` | auf das **Modell** unter dem Halter – fester Sitz |

Schreibt eines der beiden auf die Ebene des anderen, ziehen zwei Seiten am
selben Wert und die Waffe zittert. Wer die Halter umbenennt, macht Waffen
unsichtbar – ohne Fehlermeldung.

### spiel/ui/ui.tscn — 20 Zeilen

```
UI  (Node)
├─ PauseMenue    CanvasLayer   pause_menue.gd
├─ Karte         Node          karte.gd
├─ InventarUI    Node          inventar_ui.gd
└─ HUD           CanvasLayer   hud.gd
```

Vier Knoten ohne einen einzigen Exportwert – die Oberflächen bauen sich
vollständig selbst, siehe Abschnitt 3.

---

## 3. Die vier Oberflächen bauen sich selbst

`hud.gd`, `inventar_ui.gd`, `karte.gd` und `pause_menue.gd` erzeugen ihre
gesamte Control-Hierarchie im Code. In `ui.tscn` steht jeweils nur ein
einzelner Knoten. Das ist bewusst so – die Kopfkommentare begründen es:

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

Die Zerlegung in Szenen hat hier das meiste verändert: **Godot lässt keinen
`NodePath` über eine Szenengrenze hinweg zu.** Ein Knoten in `welt.tscn` kann
im Inspektor nicht auf den Spieler in `spieler.tscn` zeigen. Deshalb sind aus
Pflicht-Exports Rückfälle auf Gruppen geworden.

### a) `@export` – innerhalb einer Szene, weiterhin bevorzugt

| Szene | Knoten | Feld | zeigt auf |
|---|---|---|---|
| `spieler.tscn` | `Player` | `camera_pivot` | `SpringArmPivot` |
| `spieler.tscn` | `SpringArmPivot` | `player` | `Player` (`..`) |
| `spieler.tscn` | `Camera3D` | `target`, `player` | `SpringPosition`, `Player` |
| `spieler.tscn` | `Ausruestung` | `faust_daten` | `daten/waffen/faust.tres` |
| `spieler.tscn` | `Ausruestung` | `start_ausruestung` | `speer.tres`, `holzschild.tres` |
| `welt.tscn` | `Tageszeit` | `licht`, `world_env` | Geschwisterknoten |
| `welt.tscn` | `Underwater` | `terrain`, `world_env`, `tageszeit` | Geschwisterknoten |
| `welt.tscn` | `CloudLayer` | `tageszeit` | Geschwisterknoten |
| `welt.tscn` | `DekoLayer` | `terrain` | Geschwisterknoten |
| `koerper.tscn` | `Visual` | `player_path` | `^".."` (Vorgabe) |

`Tageszeit.licht` ist Pflicht (`push_error` + `set_process(false)`). Die
`tageszeit`-Felder an `Underwater` und `CloudLayer` sind optional – ohne sie
bleiben Nebel und Wolken einfach auf ihrer Tagfarbe stehen.

### b) Gruppen – über Szenengrenzen hinweg

| Gruppe | wer tritt bei | wer fragt danach |
|---|---|---|
| `player` | `player.gd` in `_enter_tree()` | `hud.gd`, `inventar_ui.gd`, `trainingspuppe.gd`, `karte.gd`, `deko_layer.gd`, `cloud_layer.gd`, `ki/feindlich.gd` |
| `gelaende` | `VoxelTerrain` per Szene (`groups=[…]`) | `player.gd`, `npc.gd`, `karte.gd` |
| `damageable` | `player.gd`, `npc.gd` (beide in `_enter_tree()`), `trainingspuppe.gd` | `combat.gd` (Trefferprüfung) |
| `humanoid` | `player.gd` | noch niemand – die KI sucht über `player` |
| `inventar` | `inventar.gd` | noch niemand |

**Die Registrierung steht in `_enter_tree()`, nicht in `_ready()`.** Das ist
keine Stilfrage, sondern notwendig: Godot arbeitet den gesamten Baum mit
`_enter_tree` ab, **bevor** irgendein `_ready` läuft. Läge
`add_to_group("player")` in `_ready()`, wäre die Gruppe nur für Knoten gefüllt,
die im Szenenbaum **hinter** dem Spieler stehen. `deko_layer.gd` und
`cloud_layer.gd` liegen aber in `welt.tscn` und damit **davor** – sie kämen zu
früh und fänden nichts.

Ein Ziel in `damageable` muss `take_damage(menge, angreifer, richtung)` haben.
Das ist der einzige Vertrag, den das Kampfsystem an Gegner stellt. Wer von
`Akteur` erbt (Abschnitt 7), bringt die Methode schon mit.

`combat.gd` prüft **jedes** Mitglied von `damageable` außer dem eigenen Träger.
Es gibt keine Parteien: der NPC kann auch die Trainingspuppe treffen, wenn sie
im Weg steht.

### c) Rückfallkette – Export, dann Gruppe, dann Fehler

Das Muster ist überall gleich und bewusst in dieser Reihenfolge:

```gdscript
if ziel == null:
    ziel = get_tree().get_first_node_in_group("player") as Node3D
if ziel == null:
    push_error("…")
    set_process(false)
    return
```

Das Exportfeld bleibt als **Übersteuerung** erhalten, ist aber keine Pflicht
mehr. Wer im Inspektor etwas einträgt, gewinnt.

| Knoten | Feld | Rückfall |
|---|---|---|
| `Player` | `terrain` | Gruppe `gelaende` – nur `push_warning`, dann kein Schwimmen |
| `Npc` | `terrain` | Gruppe `gelaende` – ebenso |
| `Karte` | `ziel`, `terrain` | Gruppen `player`, `gelaende` |
| `DekoLayer` | `ziel` | Gruppe `player` |
| `CloudLayer` | `folge_ziel` | Gruppe `player` – nur `push_warning`, das Wolkenfeld bleibt sonst am Ursprung stehen |
| `Underwater` | `camera` | `get_viewport().get_camera_3d()` |

Der Unterwasser-Fall ist der interessanteste: die aktive Kamera zu fragen ist
**robuster** als ein fester Verweis – bei einem späteren Kamerawechsel zieht
der Effekt automatisch mit.

### d) Namenssuche – der schwächste Weg

| Sucher | sucht | wie |
|---|---|---|
| `combat.gd` | `Ausruestung` | `find_child(name_ausruestung, true, false)` am Elternknoten |
| `player.gd`, `npc.gd` | `Combat` | `get_node_or_null("Combat")` |
| `npc.gd` | `Visual`, erste `CollisionShape3D` | `get_node_or_null("Visual")`, Schleife über die Kinder |
| `ki/feindlich.gd` | seinen `Akteur` | `get_parent() as Akteur` |
| `hud.gd` | `Combat` | über Gruppe `player`, dann `get_node_or_null("Combat")` |
| `inventar_ui.gd` | `Inventar`, `Visual` | ebenso |
| `ausruestung.gd` | `HalterRechts`, `HalterLinks` | `find_child(..., owned = false)` |
| `character_visual.gd` | `Ausruestung` | `get_node_or_null`, dann `find_child` am Akteur |
| `character_visual.gd` | 18 feste Pfade | `"Neigung/Huefte/Brust/HandRechts/HalterRechts"` usw. |

Das `owned = false` bei `ausruestung.gd` ist kein Versehen: es lässt die Suche
**in instanzierte Unterszenen hineingehen**. Genau das braucht es, weil der
Körper eine eigene Szene ist – `HalterRechts` liegt in `koerper.tscn`, die
`Ausruestung` in `spieler.tscn`.

---

## 5. Signale

| Sender | Signal | Bedeutung |
|---|---|---|
| `Combat` | `getroffen(menge)` | Schaden ist durchgekommen |
| `Combat` | `geblockt(menge)` | normal geblockt |
| `Combat` | `perfekt_geblockt()` | Parry gelungen |
| `Combat` | `deckung_gebrochen()` | Ausdauer reichte zum Blocken nicht |
| `Ausruestung` | `ausruestung_geaendert(slot, daten)` | ein Slot hat gewechselt |
| `Ausruestung` | `waffe_gewechselt(daten)` | die aktive Waffe ist eine andere – feuert auch beim An- und Ablegen eines Schildes, weil sich damit die Führung des Speers ändert |
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

`Tageszeit` sendet **kein** Signal. Die Uhrzeit ändert sich jedes Bild, die
Abnehmer fragen per Funktion (`nebel_farbe()`, `tagesanteil_aktuell()`) –
siehe Abschnitt 8.

---

## 6. Datenfluss Kampf: eine Quelle für Timing, eine für die Waffe

Das sauberste Stück Architektur im Projekt und die Vorlage für alles Weitere.

```
   daten/waffen/*.tres  (WaffenDaten)
            │
            ▼
      Ausruestung ───────── waffe_gewechselt ─────────┐
       │  besitzt: WAS gehalten wird                  │
       │                                              ▼
       │  aktive_waffe()   (ggf. Einhand-Kopie)     Combat
       ├──────────────────────────────────────────► besitzt: Timing + Schaden
       │                                            kein zweiter Timer daneben!
       │  aktive_waffe()                              │
       │  fuehrt_beidhaendig()                        │ angriff_fortschritt
       │  nebenhand()                                 │ schlag_marken()
       ▼                                              │ hand_links
   character_visual.gd ◄──────────────────────────────┘
   Ruhehaltung, Schlagpose, Halterdrehung
   rechnet nie eigenes Timing (Ausnahme: Nachschwung)
       │
       ▼
   HalterRechts/-Links  (rotation)  ─►  Modell von ausruestung.gd
```

Die Arbeitsteilung hat sich geschärft: **`Combat` besitzt Timing und Schaden,
`Ausruestung` besitzt die Frage, was die Figur hält.** `character_visual.gd`
fragt für Haltung und Schlagstil die Ausrüstung, nicht `Combat.aktiver_stil()`.
Der Grund steht im Kopfkommentar: im Stand fällt `aktiver_stil()` auf Faust
zurück, und dann gäbe es gar keine Ruhehaltung – genau daran ist der erste
Anlauf gescheitert. `aktiver_stil()` bleibt nur als Rückfall.

`schlag_marken()` liefert `Vector2(x, y)` im normierten Schlagverlauf 0..1:
`x` = Ende des Ausholens / Beginn des Trefferfensters, `y` = Ende des
Trefferfensters. Die Optik legt ihre Kurve exakt darauf.

**Diese Trennung nicht aufweichen.** Ein zweiter Timer in der Animation würde
vom Kampf-Timing abdriften und sichtbaren Schlag von echtem Treffer entkoppeln.

**Einzige Ausnahme: der Nachschwung.** Sobald `Combat` den Schlag beendet und
`angriff_fortschritt` zurückgesetzt hat, lässt `character_visual.gd` den
Fortschritt mit `nachschwung_tempo` selbst bis 1.0 auslaufen – sonst schnappt
die Hand im selben Bild in die Ruhelage zurück. Das läuft nie während eines
Schlages und kann das Trefferfenster nicht verschieben.

### Drei Schichten der Haltung

`character_visual.gd` legt drei Dinge übereinander:

1. **Laufzyklus** – Hände schwingen mit der zurückgelegten Strecke
2. **Ruhehaltung** – pro Waffenstil ein Handversatz und eine Halterdrehung
3. **Schlag** – Versatz und Halterdrehung über den Schlagverlauf

Die Posen stehen in `_stil_posen`, je Stil mit `ruhe_pos`, `ruhe_schwung`,
`halter_ruhe`, `halter_block`, `halter_ausholen`, `halter_treffer`,
`zweithand_versatz` und den Schlagversätzen. Alle Winkel sind gegen die
Körperkästen von Brust, Kopf und Hüfte gerechnet, damit keine Klinge durch den
Körper fährt – das gilt nur bei **ungedrehter Hand**. Deshalb ist die
Handdrehung bei allen Waffenstilen null, außer bei `FAUST`.

Die Rollwinkel (Axt 120°, Zweihänder 90°) sind Achsenkorrekturen für die
Meshes, keine Gestaltung. Die Herleitung steht ausführlich im Kommentar über
`_stil_posen`; die saubere Lösung wäre, die Meshes in `waffen_erzeugen.gd`
anders zu bauen.

Mit `waffen_posen_nutzen = false` lässt sich die ganze Schicht 2 abschalten,
`haltung_debug = true` gibt einmal pro Sekunde aus, welche Waffe erkannt wurde.

### Griff und Führung sind zwei Fragen

`WaffenDaten` trennt seit dem Speer zwei Dinge, die vorher eins waren:

| Funktion | Frage | wer fragt |
|---|---|---|
| `ist_zweihaendig()` | Wird die Waffe zweihändig **geführt**? Davon hängen Schaden, Timing, Ausdauer ab. | `combat.gd`, `character_visual.gd` |
| `erzwingt_zwei_haende()` | Muss die Nebenhand **frei bleiben**? | `ausruestung.gd` beim Ausrüsten |

Ein Speer (`griff = ZWEIHAND`, `kann_einhaendig = true`) lässt ein Schild
daneben zu und wird dann einhändig geführt; ein Zweihänder nicht.
`Ausruestung.fuehrt_beidhaendig()` sagt, wie es **gerade** ist.

Wird eine solche Waffe einhändig geführt, gibt `Ausruestung.aktive_waffe()`
eine **Kopie** mit den Abschlägen aus der Gruppe *Einhändig geführt* zurück
(`einhand_schaden`, `einhand_dauer`, …). `combat.gd` merkt davon nichts – es
liest wie immer `schaden` und `angriff_dauer`. Die Kopie wird zwischengespeichert,
weil `aktive_waffe()` jedes Bild gerufen wird. Für Inventar und Oberfläche gilt
weiterhin `hole()` mit den Originalwerten.

**Fallstrick:** Wer in `ausruestung.gd` wieder `ist_zweihaendig()` statt
`erzwingt_zwei_haende()` einsetzt, macht Speer und Schild gleichzeitig
unmöglich – lautlos, je nach Reihenfolge in `start_ausruestung` verschwindet
das eine oder das andere.

Eine neue Waffe ändert Reichweite, Timing, Haltung und Animation, ohne dass
Code angefasst wird – `WaffenDaten.stil` wählt die Pose
(`FAUST`, `STICH`, `HIEB`, `SCHWUNG_SCHWER`, `STANGE`). Alle fünf Stile sind
inzwischen mit je einer Waffe belegt.

---

## 7. Akteure: ein Vertrag für Spieler und NPC

`combat.gd` und `character_visual.gd` hingen früher direkt an `Player` – per
`as Player`-Cast beziehungsweise Typannotation. Jeder andere Elternknoten wurde
abgelehnt oder stürzte ab, sobald eine Eigenschaft wie `is_swimming` fehlte.

Seitdem gibt es `spiel/akteure/gemeinsam/akteur.gd`:

```
                 Akteur  (extends CharacterBody3D)
                 is_sprinting, is_sneaking, is_swimming, is_climbing
                 wunsch_richtung, camera_pivot, combat
                 take_damage(), schwachstelle_oeffnen(),
                 ist_offen(), schwachstelle_schliessen()
                        │
          ┌─────────────┴──────────────┐
          ▼                            ▼
       Player                         Npc
  Felder aus Physik + Eingabe    Felder aus der KI
```

`Akteur` ist **reine Schnittstelle** – kein Feld bekommt dort einen Sinn
zugewiesen. `combat.gd` verlangt seit dem Umbau einen `Akteur` als
Elternknoten, `character_visual.gd` ebenso.

### Wer steuert: Eingabe oder KI

`Input` ist ein globaler Zustand, keiner pro Knoten. Ohne Vorkehrung würde
**jede** `Combat`-Instanz auf die linke Maustaste zuschlagen – der NPC also
gleichzeitig mit dem Spieler. Deshalb:

| `Combat.von_spieler_gesteuert` | liest `Input` | Schlag und Block über | Wiederbelebung |
|---|---|---|---|
| `true` (Vorgabe) | ja | Tasten | nach `tot_dauer` automatisch |
| `false` | **nein** | `ki_angreifen()`, `ki_blocken(halten, delta)` | keine – der NPC bleibt tot |

`ki_angreifen()` und `ki_blocken()` laufen durch dieselbe Logik wie ein
Tastendruck und respektieren Ausdauer, Erschöpfung, Betäubung und Kombo.
Die KI darf **keine** Eingaben simulieren.

### Die feindliche KI

`spiel/akteure/npc/ki/feindlich.gd`, ein `Node` namens `Ki` unter dem NPC. Die
erste von vier Verhaltensarten aus der Roadmap.

```
  Spieler weiter als erkennungs_radius (12)       -> steht
  Spieler nah UND Sichtlinie frei                 -> verfolgt
     Sichtlinie kurz weg                          -> verfolgt noch sicht_gedaechtnis (2 s)
     im Kampf, Abstand <= verliert_bei (16)       -> verfolgt weiter
  Abstand <= angriffs_abstand (1.8)               -> bleibt stehen, dreht sich zum Spieler
     Spieler beginnt zu schlagen                  -> würfelt block_chance (35 %)
        Treffer                                   -> blockt nach block_reaktionszeit
        kein Treffer                              -> schlägt zu
```

- **Sichtlinie:** Raycast von Kopfhöhe zu Kopfhöhe, `collision_mask = 1` – nur
  Gelände blockt.
- **Blocken:** gewürfelt wird nur an der **steigenden Flanke** von
  `ist_am_angreifen` des Spielers, nicht pro Kombotreffer.
- **Drehen:** die KI dreht den NPC-Körper auch im Stand zum Spieler, weil der
  Trefferkegel in `combat.gd` die Körperdrehung liest.
- Bewusst weggelassen: Patrouille, Ruheposition, Block über eine ganze Kombo.

### Bewegung und Tod des NPC

`npc.gd` bewegt nach `wunsch_richtung`: Schwerkraft, Gehen, Stufensteigen und
Schwimmen. Stufensteigen und Wassererkennung sind aus `player.gd`
**übernommen, nicht geteilt** – siehe Abschnitt 11. Schwimmen ist vereinfacht:
der NPC verhält sich wie der Spieler ohne gedrückte Taste.

Beim Tod kippt `Visual` um (`fall_winkel`), der Körper bleibt `liege_dauer`
Sekunden liegen, versinkt dann mit abgeschalteter Kollision und löscht sich
per `queue_free` – sonst sammeln sich Leichen an.

---

## 8. Datenfluss Welt

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
  Geometrie in jedem Chunk. Im Probelauf: 1.658 Pflanzen bei Radius 80.
- **`true`:** alte Variante, Deko steckt als Voxel in den Chunks.

**Niemals beides gleichzeitig** – sonst stehen die Pflanzen doppelt da.

### Blockindizes: seit Etappe 02 eine Quelle

Früher standen die Indizes doppelt – als Konstanten im Generator und als
Array-Reihenfolge in der Szene. Das ist aufgelöst:

```
spiel/welt/bloecke.gd        class_name Bloecke   <- DIE Quelle
        │                    LUFT 0 … FELS 19
        │                    PFLANZE_MIN / PFLANZE_MAX
        │                    NAMEN[] + ANZAHL     <- Prüfdaten
        │
        ├─ world_generator.gd  const GRASS := Bloecke.GRAS  (Weiterreichung)
        │        │
        │        └─ deko_layer.gd liest 18x WorldGenerator.GRAS_KURZ & Co.
        │
        └─ werkzeuge/bloecke_namen.gd  prüft gegen
                    │
                    ▼
           daten/welt/bloecke.tres     20 VoxelBlockyModel in fester Reihenfolge
```

`Bloecke` ist **kein Autoload und kein Knoten** – `class_name` genügt, die
Konstanten sind überall als `Bloecke.GRAS` erreichbar.

Warum `world_generator.gd` seinen Konstantenblock behält, statt ihn zu
löschen: `deko_layer.gd` liest achtzehnmal `WorldGenerator.GRAS_KURZ` und
Verwandte. Konstante aus Konstante kostet zur Laufzeit nichts, und der
Zahlenwert steht trotzdem nur noch einmal. Die Umbenennung `AIR` → `LUFT` an
den Verwendungsstellen ist ein eigener Commit.

`PFLANZE_MIN`/`PFLANZE_MAX` sind Konstanten und keine `ist_pflanze()`-Funktion,
weil `_setz()` für **jeden einzelnen Laubvoxel** läuft – ein Funktionsaufruf
wäre dort messbar.

**Das Werkzeug ist noch nicht scharf.** `werkzeuge/bloecke_namen.gd` schreibt
die Konstantennamen als `resource_name` in die Modelle und prüft danach beide
Seiten gegeneinander. Es ist aber noch nicht mit `SCHREIBEN = true` gelaufen –
in `bloecke.tres` steht bisher **kein einziger** `resource_name`. Solange das
so ist, kann das Werkzeug ein verrutschtes Modell nicht erkennen. Siehe
Abschnitt 11.

### Licht und Tageszeit: ein Besitzer, viele Leser

`spiel/welt/tageszeit.gd` (`class_name Tageszeit`) besitzt die Uhrzeit. Ein
Spieltag dauert `tageslaenge` = 1200 echte Sekunden, Start um `stunde` = 8.

```
                          Tageszeit
                  stunde 0..24  ->  Sonnenrichtung
                                    Mondrichtung (12 h versetzt)
                                    tagesanteil  0 Nacht .. 1 Tag
                                    daemmerungsanteil  Spitze am Horizont
                              │
   ┌──────────────────┬───────┴──────────┬──────────────────────┐
   │ schreibt         │ schreibt         │ schreibt             │ wird gefragt
   ▼                  ▼                  ▼                      ▼
DirectionalLight3D  himmel.gdshader    Environment         nebel_farbe()     <- Underwater
Richtung, Farbe,    tagesanteil,       ambient_light_      tagesanteil_      <- CloudLayer
Stärke, Schatten-   daemmerungsanteil, energy              aktuell()
bias                mond_richtung,
                    sterne_winkel
```

- **Ein Licht für Sonne und Mond.** `licht` blendet zwischen Sonnen- und
  Mondrichtung über – nachts ist der Mond die echte Lichtquelle samt Schatten,
  nur mit `mond_staerke` = 0.12. Ein zweites `DirectionalLight3D` hätte eine
  zweite Shadow-Map gekostet.
- **Der Himmel zeichnet nur.** Der Shader rechnet keine Uhr; Sonne und Mond
  sind zwei getrennte Scheiben mit eigener Richtung, dazu Krater, Sterne, die
  sich einmal pro Tag drehen, und ein Glühen am Horizont bei Auf- und
  Untergang. Die Sonnenscheibe folgt dem Licht über `sonne_folgt_licht` und
  wird nachts mit `tagesanteil` ausgeblendet, sonst lägen ihre Ringe über dem
  Mond.
- **Die Nebelfarbe schreibt nur `Underwater`.** `Tageszeit` liefert sie über
  `nebel_farbe()`, `underwater.gd` legt sie jedes Bild als Basis unter den
  Unterwassereffekt. Würden beide schreiben, überschrieben sie sich
  gegenseitig – derselbe Konflikt wie am Waffenhalter (Abschnitt 2).
- **Wolken** dunkeln über `tagesanteil_aktuell()` auf `wolken_farbe_nacht` ab.

`nebel_farbe_tag` in `Tageszeit` muss zur Horizontfarbe im Himmel-Shader
passen, sonst bleibt die Ladekante des Terrains am Horizont sichtbar. Das ist
bewusst eine Kopie: Shader-Parameter und Environment-Felder sind zwei getrennte
Ressourcen.

Zum Prüfen: `stunde` im Remote-Inspektor während des Spiels durchschieben,
`laeuft = false` hält die Uhr an.

---

## 9. Speicherstände

| Datei | Inhalt | verwaltet von |
|---|---|---|
| `user://einstellungen.cfg` | Audio, Video, Sichtfeld, Maus, Tastenbelegung | `einstellungen.gd` |
| `user://karte_entdeckt.dat` | Set der entdeckten Kartenkacheln | `karte.gd` |

Die Karte trennt zwei Begriffe streng:

- **entdeckt** – dauerhaftes Wissen, wächst nur, wird gespeichert
- **gebaut** – Geometrie im Speicher, wird nach Budget wieder freigegeben

Freigegebene Kacheln verlieren das Wissen nicht, sie werden bei Bedarf neu
aufgebaut. `alles_aufdecken()` und `erkundung_zuruecksetzen()` sind zum Testen da.

Es gibt **noch keinen Spielstand** – Spielerposition, Inventar, Ausrüstung und
Uhrzeit überleben das Beenden nicht.

---

## 10. Eingabe

Belegung aus `project.godot`:

| Aktion | Taste | benutzt von |
|---|---|---|
| `move_forward` / `move_back` / `move_left` / `move_right` | W A S D | `player.gd` (`Input.get_vector`) |
| `sprint` | Shift | `player.gd`, `camera_follow.gd` (Sichtfeld-Zuschlag) |
| `sneak` | Strg | `player.gd`, `character_visual.gd` |
| `free_look` | Alt | `spring_arm_camera.gd` |
| `attack` | Maus links | `combat.gd` – nur bei `von_spieler_gesteuert` |
| `block` | Maus rechts | `combat.gd` – ebenso |
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

## 11. Bekannte Schwachstellen

Kein Wunschzettel, sondern Dinge, die beim Weiterbauen konkret zubeißen.
Sortiert nach Auswirkung.

### waffen_erzeugen.gd überschreibt beim nächsten Lauf
[werkzeuge/waffen_erzeugen.gd](../werkzeuge/waffen_erzeugen.gd) steht auf
`SCHREIBEN := true` **und** `UEBERSCHREIBEN := true`. Der Kopfkommentar sagt
dagegen, `UEBERSCHREIBEN` stehe auf `false`. Wer das Werkzeug noch einmal
ausführt, setzt alle fünf Waffen und Meshes auf die Tabellenwerte zurück – im
Inspektor Nachjustiertes ist dann weg. Nach dem Erzeugen beide Schalter auf
`false` stellen.

### Inventar und Ausrüstung sind zwei getrennte Welten
`inventar.gd` verwaltet `ItemDaten` in Slots mit Zeichenkettenschlüsseln
(`haupthand`, `nebenhand`, …), `ausruestung.gd` verwaltet `WaffenDaten` in
`WaffenDaten.Slot`. **Keine der beiden Seiten kennt die andere** – weder
`inventar.gd` noch `inventar_ui.gd` erwähnt `Ausruestung` oder `WaffenDaten`.
Was der Spieler in der Hand hält, kommt allein aus `start_ausruestung` in
`spieler.tscn`; ein Schwert, das man im Inventar in die Haupthand zieht,
erscheint nicht in der Hand. Das ist die größte offene Lücke im
Ausrüstungssystem.

### Der NPC hat keine Ausrüstung
`npc.tscn` hat keinen `Ausruestung`-Knoten. Folge: der NPC kämpft mit den
Faust-Rückfallwerten aus `combat.gd`, hält keine Waffe, und jeder Start
schreibt zwei Warnungen:

```
WARNING: CharacterVisual: keine Ausruestung gefunden – Waffenhaltung bleibt auf Faust.
WARNING: Combat: Keine Ausrüstung ('Ausruestung') gefunden – Faust-Rückfallwerte aktiv.
```

Abhilfe: `Ausruestung` mit `faust_daten` (und gern einer Waffe in
`start_ausruestung`) in `npc.tscn` einhängen – dann verschwinden beide
Warnungen.

### Bewegungscode steht doppelt
`npc.gd` enthält Stufensteigen (`_stufe_steigen`, `_stufe_pruefen`) und
Wassererkennung (`_update_water_state`, `_ist_wasser`) als Kopie aus
`player.gd`, samt gleichnamiger Exportwerte. Ein Fehler, der in einer Datei
behoben wird, bleibt in der anderen. Kandidat für eine gemeinsame Komponente
unter `akteure/gemeinsam/`, sobald ein zweiter NPC-Typ kommt.

### Debug-Ausgaben in inventar_ui.gd
[inventar_ui.gd:580](../spiel/ui/inventar/inventar_ui.gd) enthält zwei
`print`-Aufrufe aus der Fehlersuche zu Etappe 02:

```gdscript
print("Spieler: ", _spieler, " | Name: ", _spieler.name, …)
print("Gruppe player: ", get_tree().get_nodes_in_group("player"))
```

Beide feuern bei jedem Start und stehen im Probelauf in der Ausgabe. Können
ersatzlos raus.

### Die Reihenfolgeprüfung der Blöcke ist noch nicht scharf
`werkzeuge/bloecke_namen.gd` ist geschrieben, aber noch nicht mit
`SCHREIBEN = true` ausgeführt – in `daten/welt/bloecke.tres` steht kein
`resource_name`. Bis das nachgeholt ist, kann das Werkzeug ein verrutschtes
Modell nicht erkennen, und die alte Fußangel besteht faktisch weiter. Ablauf
steht im Kopfkommentar des Werkzeugs.

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
`"Combat"`, `"Inventar"`, `"Ausruestung"`, `"Visual"`, `"HalterRechts"`,
`"HalterLinks"` und die 18 Pfade in `character_visual.gd` stehen als
Zeichenketten im Code – inzwischen auch in `npc.gd`. Umbenennen bricht das
Spiel erst zur Laufzeit, oft nur sichtbar als "die Waffe fehlt".
→ Etappe 03.

### Verweis auf ein fehlendes Dokument
[tageszeit.gd:118](../spiel/welt/tageszeit.gd) begründet das einzelne Licht mit
"docs/tageszeit_plan.md Abschnitt 4". Diese Datei gibt es im Repo nicht. Die
Begründung steht jetzt in Abschnitt 8 hier – den Kommentar darauf umbiegen
oder den Plan nachreichen.

### Die Trainingspuppe ist noch inline
Sie steht als loser `Node3D` mit `BoxMesh` direkt in `main.tscn`, während alles
andere eine eigene Szene hat. Mit `npc.tscn` gibt es jetzt eine Vorlage; sie
wird `spiel/akteure/npc/trainingspuppe.tscn`.

### Generatorparameter stehen als `null` in welt.tscn
Der `VoxelGeneratorScript`-Unterknoten listet alle 31 Exportwerte als
`base_height = null`, `sea_level = null` und so weiter. Das ist harmlos –
Godot fällt auf die Vorgaben im Skript zurück, der Probelauf erzeugt korrektes
Gelände –, aber es ist Rauschen im Diff und verwirrt beim Lesen. Verschwindet,
sobald man die Werte einmal im Inspektor anfasst.

### Kein Spielstand
Nur Einstellungen und Kartenerkundung überleben. Position, Inventar,
Ausrüstung und Uhrzeit nicht.
