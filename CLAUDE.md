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
szenen/main.tscn              30 Zeilen, instanziert nur noch
spiel/autoload/               einstellungen.gd
spiel/akteure/gemeinsam/      akteur.gd (Basisklasse), koerper.tscn (das Rig),
                              kampf, ausruestung, optik - Spieler UND NPC
spiel/akteure/spieler/        spieler.tscn, player.gd, inventar.gd
spiel/akteure/npc/            npc.tscn, npc.gd, ki/feindlich.gd, trainingspuppe.gd
spiel/kamera/                 spring_arm_camera.gd, camera_follow.gd
spiel/welt/                   welt.tscn, bloecke.gd, tageszeit.gd, deko,
                              wolken, unterwasser
spiel/welt/generator/         world_generator.gd
spiel/ui/                     ui.tscn + {hud,inventar,karte,menue}/
spiel/ressourcen/             Resource-KLASSEN (ItemDaten, WaffenDaten)
daten/                        Resource-INSTANZEN (.tres): waffen/ (6), welt/
assets/                       Meshes, Materialien, Shader
werkzeuge/                    EditorScripts, laufen nie im Spiel
addons/zylann.voxel/          Fremdcode, NIE verändern
```

Geordnet nach **Feature, nicht nach Dateityp**. Teilszenen liegen bei ihrem
System, nicht in `szenen/`. Neue Waffen, Items und NPC-Vorlagen kommen nach
`daten/`, nicht nach `spiel/ressourcen/`.

### Die sechs Szenen

```
main.tscn  ─ Spiel
             ├─ Welt      -> spiel/welt/welt.tscn   (inkl. Tageszeit)
             ├─ Player    -> spiel/akteure/spieler/spieler.tscn
             │             └─ Visual -> spiel/akteure/gemeinsam/koerper.tscn
             ├─ Trainingspuppe   (noch inline)
             ├─ UI        -> spiel/ui/ui.tscn
             └─ Npc       -> spiel/akteure/npc/npc.tscn
                           └─ Visual -> spiel/akteure/gemeinsam/koerper.tscn
```

`Player` und `Npc` erben beide von `Akteur` (`extends CharacterBody3D`).
`combat.gd` und `character_visual.gd` verlangen einen `Akteur` als
Elternknoten, keinen `Player`.

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
`meshes/`, `plants/`, Gruppen `damageable` und `humanoid`, die Weiterreichung
`AIR`/`WATER`/`GRASS` in `world_generator.gd`) werden in Etappe 05b geschlossen
umgestellt – nicht nebenbei mitumbenennen.

---

## Fallstricke

Diese zehn Dinge beißen zu, wenn man sie nicht weiß.

**1 · `Bloecke` ist die einzige Quelle der Blockindizes.**
`spiel/welt/bloecke.gd`, `class_name Bloecke`, kein Autoload nötig. Die
Reihenfolge muss dem `models`-Array in `daten/welt/bloecke.tres` entsprechen.
Neuer Blocktyp: Modell **ans Ende** der `.tres`, Konstante in `bloecke.gd`,
Eintrag in `NAMEN[]`, `ANZAHL` erhöhen, dann `werkzeuge/bloecke_namen.gd`
ausführen. Achtung: das Werkzeug ist noch nicht scharf, in der `.tres` steht
noch kein `resource_name`.

**2 · `world_generator.gd` behält seinen Konstantenblock mit Absicht.**
`const GRASS := Bloecke.GRAS` ist keine Redundanz – `deko_layer.gd` liest
achtzehnmal `WorldGenerator.GRAS_KURZ` und Verwandte. Nicht "aufräumen".

**3 · Godot kann keinen `NodePath` über eine Szenengrenze.** Deshalb finden
`terrain`, `ziel`, `folge_ziel` und `camera` ihr Gegenüber über Gruppen
(`player`, `gelaende`) beziehungsweise `get_viewport().get_camera_3d()`. Das
Exportfeld bleibt jeweils als Übersteuerung. Muster: Export → Gruppe →
`push_error` + `set_process(false)`.

**4 · Gruppen in `_enter_tree()` betreten, nicht in `_ready()`.** Godot
arbeitet den ganzen Baum mit `_enter_tree` ab, **bevor** irgendein `_ready`
läuft. In `_ready()` wäre die Gruppe `player` für alles leer, was im Baum vor
dem Spieler steht – und `welt.tscn` steht davor.

**5 · `Combat` besitzt Timing und Schaden, `Ausruestung` die Waffe.**
`character_visual.gd` liest `schlag_marken()`, `angriff_fortschritt` und
`hand_links` aus `Combat` und rechnet **nie** eigenes Timing – einzige
Ausnahme ist der Nachschwung nach Schlagende. Welche Waffe gehalten wird,
fragt es die `Ausruestung` (`aktive_waffe()`, `fuehrt_beidhaendig()`,
`nebenhand()`), nicht `Combat.aktiver_stil()` – das fällt im Stand auf Faust
zurück. Ein zweiter Timer würde abdriften und sichtbaren Schlag von echtem
Treffer entkoppeln.

**6 · Am Waffenhalter schreiben zwei Skripte, jedes auf seine Ebene.**
`character_visual.gd` schreibt nur `rotation` von `HalterRechts`/`HalterLinks`,
`ausruestung.gd` nur `halte_versatz`/`-drehung`/`-skalierung` auf das Modell
darunter. Über Kreuz schreiben lässt die Waffe zittern. Dasselbe Prinzip bei
der Nebelfarbe: nur `underwater.gd` schreibt sie, `Tageszeit.nebel_farbe()`
wird gefragt.

**7 · `ist_zweihaendig()` ist nicht `erzwingt_zwei_haende()`.** Das Erste
beschreibt die Führung (Kampfwerte), das Zweite, ob die Nebenhand frei bleiben
muss (Ausrüsten). Der Speer ist zweihändig, erlaubt aber ein Schild. Wer in
`ausruestung.gd` die beiden verwechselt, lässt Speer oder Schild lautlos
verschwinden.

**8 · `Input` ist global – KI-Kampf nur über `von_spieler_gesteuert`.** Jede
`Combat`-Instanz mit `von_spieler_gesteuert = true` reagiert auf die Maus.
NPCs brauchen `false` und werden über `ki_angreifen()` / `ki_blocken()`
bedient. Mit `false` gibt es auch keine automatische Wiederbelebung.

**9 · Knotennamen stehen als Zeichenketten im Code.** `"Combat"`, `"Inventar"`,
`"Ausruestung"`, `"Visual"`, `"HalterRechts"`, `"HalterLinks"` und 18 feste
Pfade in `character_visual.gd`. Umbenennen bricht das Spiel erst zur
Laufzeit, oft nur sichtbar als "die Waffe fehlt".

**10 · Pfade als Zeichenketten, die Godot nicht mitzieht.** `deko_layer.gd`
(`mesh_verzeichnis`, `material_verzeichnis`), `make_plants.gd` (`MESH_DIR`,
`MAT_DIR`, `SHADER_PATH`) und `waffen_erzeugen.gd` (`MESH_DIR`, `MAT_PFAD`,
`WAFFEN_DIR`). Beim Verschieben von `assets/` oder `daten/` von Hand
nachziehen.

Dazu zwei Dinge, die kein Fallstrick sind, aber überraschen:

- **`deko_als_voxel`** schaltet zwei sich ausschließende Wege. Standard ist
  `false` (MultiMesh im Spielerumkreis). Niemals beides, sonst stehen die
  Pflanzen doppelt da.
- **Ein neuer Gegner braucht nur zwei Dinge:** Gruppe `damageable` und
  `take_damage(menge, angreifer, richtung)`. Wer von `Akteur` erbt, hat die
  Methode schon. Vorlage für einen echten NPC ist `npc.tscn` (Körper, Kampf,
  KI), für ein bloßes Testziel `trainingspuppe.gd`.
- **Inventar und Ausrüstung sind nicht verbunden.** `inventar.gd` kennt
  `ItemDaten`, `ausruestung.gd` kennt `WaffenDaten`. Was der Spieler hält,
  kommt nur aus `start_ausruestung` in `spieler.tscn`.

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

Startet die Hauptszene. Erwartete Meldungen: acht `[Deko] geladen`-Zeilen,
Trainingspuppe, Karte, HUD, Inventar, `HUD ist mit dem Kampfsystem verbunden`,
`[Deko] gesetzte Pflanzen: ~1650`. **Neun** Fehler
`keyboard_get_keycode_from_physical: Not supported by this display server` sind
erwartet und harmlos – der Dummy-Displayserver hat keine Tastatur, das
Pausenmenü fragt beim Bau seiner Tastenzeilen danach. Alles andere ist ein
echter Fehler – auch jede Warnung.

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
- `@export` innerhalb einer Szene, Gruppe darüber hinaus. Fehlende
  Pflichtreferenz mit `push_error` melden und `set_process(false)` – kein
  stiller Ausfall.
- Nach `.godot/` nichts committen, das Verzeichnis ist gitignoriert.

---

## Woran gerade gearbeitet wird

Etappen 00, 01, 02 und die Dokumentation sind erledigt, **nichts ist mehr
blockiert**. Seitdem dazugekommen: Basisklasse `Akteur`, ein feindlicher NPC
mit KI, fünf Waffen mit eigener Haltung, Tag-Nacht-Zyklus. Alles davon liegt
auf dem Zweig `umbau/struktur`, noch nicht auf `main`.

Als Nächstes naheliegend:

- Inventar und Ausrüstung verbinden
- dem NPC eine Waffe in `start_ausruestung` geben (bisher nur Faust)
- weitere KI-Arten (neutral, passiv, freundlich) in `spiel/akteure/npc/ki/`

Offene Restarbeit aus Etappe 02: `werkzeuge/bloecke_namen.gd` einmal mit
`SCHREIBEN = true` ausführen, damit die Reihenfolgeprüfung der Blöcke scharf
wird. Details in [docs/roadmap.md](docs/roadmap.md).
