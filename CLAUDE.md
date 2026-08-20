# CLAUDE.md

Arbeitsanweisungen für Claude Code in diesem Projekt.
Ausführlich: [docs/architektur.md](docs/architektur.md) ·
[docs/dateien.md](docs/dateien.md) · [docs/konventionen.md](docs/konventionen.md) ·
[docs/roadmap.md](docs/roadmap.md)

---

## Was das ist

Shardfall, ein Voxel-Rollenspiel in Godot 4.6 (GL Compatibility, Jolt Physics,
Addon `zylann.voxel`). Welt entsteht zur Laufzeit aus Rauschen. Charaktere sind
Würfelfiguren **ohne Skeleton3D** – Hände und Füße sind einzelne `Node3D`, ein
Schlag ist eine Verschiebung, keine Gelenkdrehung.

Solo-Projekt, Sprache Deutsch, auch im Code.

---

## Wo was liegt

```
szenen/main.tscn              die einzige Szene, ~50 Knoten
spiel/autoload/               Einstellungen
spiel/akteure/gemeinsam/      kampf, ausruestung, koerperoptik - Spieler UND NPC
spiel/akteure/spieler/        player.gd, inventar.gd
spiel/akteure/npc/            trainingspuppe.gd
spiel/kamera/                 spring_arm_camera.gd, camera_follow.gd
spiel/welt/                   deko_layer, cloud_layer, underwater
spiel/welt/generator/         world_generator.gd
spiel/ui/{hud,inventar,karte,menue}/
spiel/ressourcen/             Resource-KLASSEN (Code)
daten/                        Resource-INSTANZEN (.tres)
assets/                       Meshes, Materialien, Shader
werkzeuge/                    EditorScripts, laufen nie im Spiel
addons/zylann.voxel/          Fremdcode, NIE verändern
```

Geordnet nach **Feature, nicht nach Dateityp**. Neue Waffen, Items und
NPC-Vorlagen kommen nach `daten/`, nicht nach `spiel/ressourcen/`.

---

## Benennung: durchgehend Deutsch

| Ebene | Regel |
|---|---|
| Dateien, Ordner | deutsch, `snake_case`, keine Umlaute (`ae`, `oe`, `ue`, `ss`) |
| `class_name`, Knoten | deutsch, `PascalCase` |
| Variablen, Funktionen | deutsch, `snake_case` |
| Signale | deutsch, Partizip Perfekt: `getroffen`, `geaendert` |
| Gruppen | deutsch, klein |
| Godot-API | bleibt englisch: `_ready()`, `velocity`, `@export` |

**Neuer Code deutsch, alter Code unangetastet.** Die verbliebenen englischen
Altnamen (`player.gd`, `combat.gd`, `world_generator.gd`, `camera_follow.gd`,
`spring_arm_camera.gd`, `underwater.gd`, `cloud_layer.gd`, Ordner `materials/`,
`meshes/`, `plants/`, Gruppen `damageable` und `humanoid`) werden in Etappe 05
geschlossen umgestellt – nicht nebenbei mitumbenennen.

---

## Fallstricke

Diese sechs Dinge beißen zu, wenn man sie nicht weiß.

**1 · Blockindizes stehen doppelt.** Als Konstanten in `world_generator.gd`
(`AIR 0` … `FELS 19`) **und** als Array-Reihenfolge in der `VoxelBlockyLibrary`,
die inline in `main.tscn` steckt. Ein neuer Blocktyp muss an beiden Stellen
eingetragen werden, sonst besteht die Welt aus dem falschen Material – ohne
Fehlermeldung.

**2 · `Combat` besitzt Timing und Schaden, sonst niemand.**
`character_visual.gd` liest `aktiver_stil()`, `schlag_marken()`,
`angriff_fortschritt` und `hand_links` – und rechnet **nie** eigenes Timing. Ein
zweiter Timer würde abdriften und sichtbaren Schlag von echtem Treffer
entkoppeln.

**3 · Knotennamen stehen als Zeichenketten im Code.** `"Combat"`, `"Inventar"`,
`"Ausruestung"`, `"Visual"`, `"HalterRechts"`, `"HalterLinks"` und 16 feste
Pfade in `character_visual.gd`. Umbenennen bricht das Spiel erst zur Laufzeit,
oft nur sichtbar als "die Waffe fehlt".

**4 · Pfade als Zeichenketten, die Godot nicht mitzieht.** `deko_layer.gd`
(`mesh_verzeichnis`, `material_verzeichnis`) und `make_plants.gd` (`MESH_DIR`,
`MAT_DIR`, `SHADER_PATH`). Beim Verschieben von `assets/` von Hand nachziehen.

**5 · `deko_als_voxel` schaltet zwei sich ausschließende Wege.** Standard ist
`false` (MultiMesh im Spielerumkreis). Niemals beides gleichzeitig, sonst
stehen die Pflanzen doppelt da.

**6 · Ein neuer Gegner braucht nur zwei Dinge:** Gruppe `damageable` und die
Methode `take_damage(menge, angreifer, richtung)`. `trainingspuppe.gd` ist die
Vorlage.

---

## Prüfen statt behaupten

Godot liegt unter `OneDrive/Desktop/Programming/Godot_v4.6-stable_win64.exe`.

```bash
Godot_v4.6-stable_win64.exe --headless --path . --import
```

Importiert alles und registriert die Skriptklassen neu. Exitcode 0 = heil.
Nach jedem Verschieben oder Umbenennen von Dateien ausführen.

```bash
Godot_v4.6-stable_win64.exe --headless --path . --quit-after 180
```

Startet die Hauptszene. Melden sich HUD, Karte, Deko und Trainingspuppe, läuft
das Spiel. **Neun** Fehler `keyboard_get_keycode_from_physical: Not supported by
this display server` sind erwartet und harmlos – der Dummy-Displayserver hat
keine Tastatur. Alles andere ist ein echter Fehler.

Nach dem Verschieben von Dateien zusätzlich prüfen, dass jeder `res://`-Pfad
noch auflöst und die UIDs zu den `.uid`-Dateien passen.

---

## Arbeitsweise

- Godot schließen, bevor Dateien verschoben werden.
- Verschieben und Umbenennen mit `git mv`, damit die Historie erhalten bleibt.
- Größere Umbauten auf einem eigenen Zweig, `main` bleibt der Rückfallpunkt.
- Commit-Nachrichten deutsch, Umlaute umschreiben (Windows-Konsole), nach der
  Betreffzeile erklären **warum**.
- Kopfkommentar in jeder neuen Datei: wofür, wie einbauen, welche Knoten
  erwartet.
- `@export` statt `find_child`, wo es geht. Fehlende Pflichtreferenz mit
  `push_error` melden und `set_process(false)` – kein stiller Ausfall.
- Nach `.godot/` nichts committen, das Verzeichnis ist gitignoriert.

---

## Woran gerade gearbeitet wird

Umbau der Struktur, Etappen 00 und 01 sind erledigt. **Etappe 02 (Szene
zerlegen) ist der Flaschenhals** – NPCs und Gebäude aus der Roadmap hängen
daran. Details in [docs/roadmap.md](docs/roadmap.md).
