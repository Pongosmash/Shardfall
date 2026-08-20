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

Diese Altnamen sind bewusst stehen geblieben und werden in Etappe 05
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
dazu (`verwundbar`, `humanoid` bleibt). Sie stehen in `player.gd`,
`trainingspuppe.gd` und `combat.gd`.

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
- `daten/` – Resource-**Instanzen** (`.tres`): `faust.tres`

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
- **Eine Quelle der Wahrheit.** `Combat` besitzt Timing und Schaden, die Optik
  liest nur. Kein zweiter Timer daneben.
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
