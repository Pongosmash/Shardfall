# Konventionen

Beschlossen am 20.08.2026. Gilt für allen neuen Code.

---

## Sprache: durchgehend Deutsch

Sämtliche Kommentare, Inspektor-Exportnamen und der Großteil der Bezeichner
waren bereits deutsch. Deutsch kostet sieben Dateiumbenennungen, Englisch hätte
rund 5.000 Zeilen Kommentare bedeutet.

| Ebene | Regel | Beispiel |
|---|---|---|
| Dateien und Ordner | deutsch, `snake_case`, keine Umlaute, kein ß | `ausruestung.gd`, `werkzeuge/` |
| `class_name` | deutsch, `PascalCase` | `Kampf`, `Spieler`, `WaffenDaten` |
| Knoten in Szenen | deutsch, `PascalCase` | `HalterRechts`, `Ausruestung` |
| Variablen und Funktionen | deutsch, `snake_case` | `lauf_tempo`, `schaden_erhalten()` |
| Private Mitglieder | Unterstrich voran | `_kombo_index`, `_beende_schlag()` |
| Signale | deutsch, Partizip Perfekt | `getroffen`, `geblockt`, `geaendert` |
| Gruppen | deutsch, klein | `spieler`, `verwundbar` |
| Konstanten | `GROSS_MIT_UNTERSTRICH` | `HOLZ_EICHE`, `FARBE_PANEL` |
| Godot-API | bleibt englisch | `_ready()`, `velocity`, `@export` |

Umlaute werden in Bezeichnern umschrieben: `ae`, `oe`, `ue`, `ss`. In
Kommentaren, Anzeigetexten und dieser Dokumentation stehen sie normal.

### Noch nicht umbenannt

Diese Altnamen sind bewusst stehen geblieben und werden in Etappe 05b
geschlossen umgestellt:

```
player.gd            -> spieler.gd          class_name Player     -> Spieler
combat.gd            -> kampf.gd            class_name Combat     -> Kampf
character_visual.gd  -> koerper_visual.gd
camera_follow.gd     -> kamera_folgt.gd
spring_arm_camera.gd -> kamera_arm.gd
world_generator.gd   -> welt_generator.gd   class_name WorldGenerator -> WeltGenerator
underwater.gd        -> unterwasser.gd
cloud_layer.gd       -> wolken.gd           class_name CloudLayer -> Wolken
deko_layer.gd                               class_name DekoLayer  -> Deko
assets/materials/    -> assets/materialien/
assets/meshes/       -> assets/netze/  (oder meshes belassen)
.../plants/          -> .../pflanzen/
```

Die englischen Gruppennamen `damageable` und `humanoid` gehören ebenfalls
dazu (`verwundbar`, `humanoid` bleibt). Sie stehen in `player.gd`, `npc.gd`,
`trainingspuppe.gd` und `combat.gd`. Die seit Etappe 02 dazugekommene Gruppe
`gelaende` ist bereits deutsch.

Neu hinzugekommene Dateien halten sich schon an die Regel: `akteur.gd`,
`npc.gd`, `ki/feindlich.gd`, `tageszeit.gd`, `waffen_erzeugen.gd`. Englisch
sind darin nur die Felder, die `Akteur` aus `player.gd` übernommen hat
(`is_sprinting`, `is_swimming`, …) – sie ziehen in Etappe 05b mit um, weil
`character_visual.gd` und `camera_follow.gd` sie lesen. Ebenso die aus
`player.gd` kopierten Wasserfelder in `npc.gd` (`water_voxel`, `swim_speed`, …).

Dazu kommen die Blockkonstanten: `spiel/welt/bloecke.gd` heißt schon richtig
(`LUFT`, `WASSER`, `GRAS`, `STEIN`, `ERDE`), aber `world_generator.gd` reicht
sie noch unter den alten Namen weiter:

```gdscript
const AIR   := Bloecke.LUFT
const WATER := Bloecke.WASSER
const GRASS := Bloecke.GRAS
```

Das war Absicht, damit Etappe 02 klein bleibt – die Verwendungsstellen im
Generator blieben so unangetastet. Beim Umbenennen fällt die Weiterreichung
für diese fünf weg; die übrigen fünfzehn Namen sind ohnehin schon identisch
und bleiben als Weiterreichung stehen, solange `deko_layer.gd` sie über
`WorldGenerator.` liest.

Bis dahin gilt: **neuer Code deutsch, alter Code unangetastet.** Nicht
nebenbei mitumbenennen – sonst ist bei einem Fehler nicht mehr zuzuordnen,
woran es lag.

---

## Ordnung: nach Feature, nicht nach Dateityp

Kein `scripts/` neben `scenes/`. Stattdessen ein Ordner pro Spielsystem, in dem
Szene, Skript und Kleinteile beieinanderliegen. Beim Arbeiten denkt man in
"ich mache was am Inventar", nicht in "ich öffne eine Szenendatei".

Zwei Ordner werden regelmäßig verwechselt:

- `spiel/ressourcen/` – Resource-**Klassen** (Code): `waffen_daten.gd`
- `daten/` – Resource-**Instanzen** (`.tres`): `speer.tres`

Neue Waffen, Items und NPC-Vorlagen gehören nach `daten/`.

---

## Code

- **Kopfkommentar in jeder Datei.** Wofür ist das da, wie wird es eingebaut,
  welche Knoten erwartet es. Das ist im Projekt bereits durchgehend so und der
  Grund, warum man sich darin zurechtfindet.
- **Tabs zum Einrücken**, wie Godot es vorgibt.
- **`@export` statt Namenssuche**, wo es geht. `find_child("…")` und
  `get_node_or_null("…")` sind der Rückfall, nicht die erste Wahl.
- **Fehlende Pflichtreferenzen melden.** `push_error` und dann
  `set_process(false)` – kein stiller Ausfall.
- **`@export` innerhalb einer Szene, Gruppe darüber hinaus.** Godot lässt
  keinen `NodePath` über eine Szenengrenze zu. Muster: Export → Gruppe →
  `push_error`, siehe [architektur.md](architektur.md) Abschnitt 4c.
- **Gruppen in `_enter_tree()` betreten**, nicht in `_ready()`.
- **Eine Quelle der Wahrheit.** `Combat` besitzt Timing und Schaden,
  `Ausruestung` die gehaltene Waffe, `Tageszeit` die Uhrzeit. Alle anderen
  lesen nur. Kein zweiter Timer daneben.
- **Ein Wert, ein Schreiber.** Schreiben zwei Systeme jedes Bild auf dieselbe
  Eigenschaft, gewinnt zufällig eines und das Ergebnis flackert. Deshalb
  schreibt `character_visual.gd` nur die Drehung des Waffenhalters und
  `ausruestung.gd` nur das Modell darunter, und deshalb setzt `Tageszeit` die
  Nebelfarbe nicht selbst, sondern `underwater.gd` fragt sie ab.
- **Keine Eingabe simulieren.** `Input` ist global. Eine KI bedient
  Komponenten über eigene Methoden (`ki_angreifen()`), nie über
  `Input.action_press()`.
- **Kommentare begründen, sie beschreiben nicht.** Nicht "setzt die Höhe",
  sondern warum diese Höhe.

---

## Git

- Deutsche Commit-Nachrichten, Betreffzeile im Imperativ oder als Aussage,
  danach Leerzeile und Erklärung **warum**.
- Umlaute in Commit-Nachrichten umschreiben (`ae`, `oe`, `ue`) – die Konsole
  unter Windows stellt sie sonst falsch dar.
- Verschieben und Umbenennen immer mit `git mv`, damit die Historie der Datei
  erhalten bleibt.
- Größere Umbauten auf einem eigenen Zweig, `main` bleibt der Rückfallpunkt.
