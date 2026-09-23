# Dateiverzeichnis

Was liegt wo und wofür. Für Zusammenhänge siehe [architektur.md](architektur.md).

Stand: 23.09.2026 · 28 Skripte · 9.752 Zeilen GDScript · 6 Szenen

---

## Grundriss

```
project.godot            Projektkonfiguration
icon.svg                 Anwendungssymbol
default_bus_layout.tres  Audiobusse

docs/                    diese Dokumentation
addons/zylann.voxel/     Fremdcode, nie verändern
szenen/                  main.tscn - nur noch Zusammenbau
spiel/                   aller eigene Spielcode, Teilszenen liegen beim System
daten/                   Resource-INSTANZEN (.tres)
assets/                  Meshes, Materialien, Shader
werkzeuge/               EditorScripts, laufen nie im Spiel
```

Die Trennung, die am häufigsten verrutscht:

- `spiel/ressourcen/` enthält die **Bauart** – `waffen_daten.gd` ist eine Klasse
- `daten/` enthält die **Exemplare** – `speer.tres` ist eine Waffe

Neue Waffen, Items, NPC-Vorlagen kommen nach `daten/`, nicht nach `spiel/`.

Teilszenen liegen **bei ihrem System**, nicht in `szenen/`: `koerper.tscn`
gehört zu den Akteuren, `welt.tscn` zur Welt. In `szenen/` steht nur, was
alles zusammensetzt.

---

## Szenen

| Datei | Zeilen | Inhalt |
|---|---:|---|
| `szenen/main.tscn` | 30 | Wurzelknoten `Spiel`. Instanziert Welt, Player, UI und einen NPC, dazu die Trainingspuppe. Sonst nichts. |
| `spiel/welt/welt.tscn` | 146 | `VoxelTerrain` (Gruppe `gelaende`), Licht, `WorldEnvironment` mit Himmel-Shader, Wolken, Unterwasser, Deko, Tageszeit |
| `spiel/akteure/spieler/spieler.tscn` | 75 | `Player` mit Kollisionskapsel, Körper, Federarmkamera, Combat, Ausruestung (Start: Speer + Holzschild), Inventar |
| `spiel/akteure/npc/npc.tscn` | 35 | `Npc` mit Kollisionskapsel, Körper, Combat (KI-gesteuert), Ausruestung (nur Faust) und feindlicher KI |
| `spiel/akteure/gemeinsam/koerper.tscn` | 72 | Das Würfel-Rig. **Für Spieler und NPCs dieselbe Datei.** Proportionen als Exportwerte in der Szene. |
| `spiel/ui/ui.tscn` | 20 | PauseMenue, Karte, InventarUI, HUD – vier Knoten, kein einziger Exportwert |

Vor Etappe 02 war das eine Datei mit 405 Zeilen und rund 50 Knoten.

---

## spiel/autoload/

| Datei | Zeilen | `class_name` | Aufgabe |
|---|---:|---|---|
| `einstellungen.gd` | 325 | — (Autoload `Einstellungen`) | Alle Spieleroptionen, speichert nach `user://einstellungen.cfg`, wendet sie auf `AudioServer`, `DisplayServer`, `Engine` und `InputMap` an. |

Registriert in `project.godot` unter `[autoload]` per UID. Von überall
erreichbar als `Einstellungen.maussensitivitaet` usw.

Wichtige Werte: `master_lautstaerke`, `musik_lautstaerke`, `sfx_lautstaerke`,
`fenstermodus`, `vsync`, `max_fps`, `aufloesung_3d`, `sichtfeld`,
`maussensitivitaet`, `y_invertieren`.

Wichtige Funktionen: `alles_anwenden()`, `belegbare_aktionen()`,
`setze_taste()`, `belegungs_text()`, `speichern()`, `laden()`,
`auf_standard_zuruecksetzen()`.

---

## spiel/akteure/gemeinsam/

Was Spieler **und** NPCs benutzen. Die Komponenten hängen als Kindknoten
unter einem Akteur, nicht unter dem Spieler speziell – deshalb liegen sie hier.

| Datei | Zeilen | `class_name` | Aufgabe |
|---|---:|---|---|
| `akteur.gd` | 50 | `Akteur` | Gemeinsame Basisklasse von `Player` und `Npc` (`extends CharacterBody3D`). Reine Schnittstelle: die Felder, die `combat.gd` und `character_visual.gd` am Elternknoten lesen, und die Schadensmethoden. |
| `koerper.tscn` | 72 | — | Das Würfel-Rig als eigene Szene: Neigung, Hüfte, Brust, Kopf, zwei Hände mit Waffenhaltern, zwei Füße. |
| `combat.gd` | 652 | `Combat` | Leben, Ausdauer, Angriffe, Blocken, perfektes Blocken. **Einzige Quelle für Timing und Schaden.** Liest Tasten oder wird von einer KI bedient. |
| `ausruestung.gd` | 297 | `Ausruestung` | Welche `WaffenDaten` in welchem Slot stecken; erzeugt und entfernt die Waffenmodelle an den Handhaltern; liefert beim einhändig geführten Speer die abgeschwächte Kopie. |
| `character_visual.gd` | 1261 | — | Würfelmodell: Laufzyklus, Neigung in Kurven, Ducken, Springen, Schwimmen, dazu Ruhehaltung und Schlagposen je Waffenstil samt Halterdrehung. Liest Timing aus `Combat` und die gehaltene Waffe aus `Ausruestung`. |

`Akteur` öffentlich: Felder `is_sprinting`, `is_sneaking`, `is_swimming`,
`is_climbing`, `wunsch_richtung`, `camera_pivot`, `combat`; Methoden
`take_damage()`, `schwachstelle_oeffnen()`, `ist_offen()`,
`schwachstelle_schliessen()`.

`Combat` öffentlich: `im_kampf()`, `darf_sprinten()`, `kampf_ausloesen()`,
`sprint_kosten()`, `aktive_waffe()`, `aktive_blockwaffe()`, `aktiver_stil()`,
`schlag_marken()`, `schwachstelle_oeffnen()`, `ist_offen()`,
`schwachstelle_schliessen()`, `schaden_erhalten()`, `ki_angreifen()`,
`ki_blocken(halten, delta)`. Schalter `von_spieler_gesteuert` (Vorgabe `true`):
aus = liest keine Tasten und belebt nicht automatisch wieder.

`Ausruestung` öffentlich: `ausruesten()`, `ablegen()`, `hole()`,
`aktive_waffe()`, `nebenhand()`, `fuehrt_beidhaendig()`,
`haende_wechseln_erlaubt()`, `block_waffe()`, `belegung()`, `ist_bereit()`.
`start_ausruestung` wird in Reihenfolge angelegt – bei einem Konflikt gewinnt
der spätere Eintrag.

`character_visual.gd` öffentlich: `baue_proportionen()`, `hole_gesamt_hoehe()`,
`hole_hand(links)`, `hole_halter(links)`. Exportgruppe *Waffenhaltung*:
`waffen_posen_nutzen`, `halter_tempo`, `haltung_tempo`, `nachschwung_tempo`,
`haltung_debug`, dazu `schild_schlag_breite` und `schild_schlag_gieren`.

---

## spiel/akteure/spieler/

| Datei | Zeilen | `class_name` | Aufgabe |
|---|---:|---|---|
| `spieler.tscn` | 75 | — | Der zusammengesetzte Spieler |
| `player.gd` | 542 | `Player` | `extends Akteur`. Bewegung, Springen, Ducken, Stufensteigen, Waten und Schwimmen, Kollisionskapsel. |
| `inventar.gd` | 273 | `Inventar` | Datenhaltung für Inventar und Ausrüstungsslots. Kennt keine Oberfläche – und keine `Ausruestung`, siehe [architektur.md](architektur.md) Abschnitt 11. |

`player.gd` öffentlicher Zustand zusätzlich zu `Akteur`: `is_wading`,
`is_submerged`, `stufen_versatz` (immer 0, nur noch für `camera_follow.gd`).
Methode: `respawn()`. Schadensmethoden erbt er von `Akteur`.

Registriert seine Gruppen in **`_enter_tree()`**, nicht in `_ready()` – sonst
kämen Deko und Wolken aus `welt.tscn` zu früh. Begründung in
[architektur.md](architektur.md) Abschnitt 4b.

Das Stufensteigen versetzt den Körper **nicht**, sondern fährt ihn über
`velocity.y` hoch – so bleibt die Kollision durchgehend gültig und nichts
steckt im Block fest.

`inventar.gd` Slots in Anzeigereihenfolge: `kopf`, `amulett`, `ruestung`,
`haende`, `fuesse`, `ring1`, `ring2`, `haupthand`, `nebenhand`.
Öffentlich: `hole()`, `hole_ausruestung()`, `ist_leer()`, `passt()`,
`hinzufuegen()`, `entfernen()`, `tausche_plaetze()`, `ausruesten()`,
`ablegen()`, `tausche_ausruestung()`, `erster_freier_platz()`, `boni()`,
`grundwerte()`, `wende_boni_an()`.

---

## spiel/akteure/npc/

| Datei | Zeilen | `class_name` | Aufgabe |
|---|---:|---|---|
| `npc.tscn` | 35 | — | Der zusammengesetzte NPC, Gegenstück zu `spieler.tscn` |
| `npc.gd` | 300 | `Npc` | `extends Akteur`. Schwerkraft, Laufen nach `wunsch_richtung`, Stufensteigen und vereinfachtes Schwimmen (beides aus `player.gd` übernommen). Tod: umkippen, liegen, versinken, `queue_free`. |
| `ki/feindlich.gd` | 151 | — | Feindliche KI als Knoten `Ki`: erkennt den Spieler per Radius und Sichtlinie, verfolgt, dreht sich zu ihm, schlägt zu, blockt gelegentlich. Setzt nur `wunsch_richtung` und ruft `combat.ki_angreifen()` / `ki_blocken()`. |
| `trainingspuppe.gd` | 283 | — | Testziel. Stellt sich beim Start selbst vor den Spieler, nimmt Schaden, schlägt zurück, wird beim Parieren offen für einen kritischen Treffer. |

`npc.gd` Exportgruppen: *Gehen* (`gehtempo` 3.2, …), *Stufen* (wie
`player.gd`), *Wasser* (`terrain`, sonst Gruppe `gelaende`), *Tod*
(`fall_dauer`, `fall_winkel`, `liege_dauer` 4 s, `versink_dauer`,
`versink_tiefe`). Tritt in `_enter_tree()` der Gruppe `damageable` bei.

`ki/feindlich.gd` Exportgruppen: *Erkennung* (`erkennungs_radius` 12,
`verliert_bei` 16, `augenhoehe`, `sicht_maske` 1, `sicht_gedaechtnis` 2 s),
*Angriff* (`angriffs_abstand` 1.8, `dreh_tempo`), *Blocken* (`block_chance`
0.35, `block_reaktionszeit` 0.15, `block_dauer` 0.5). Erwartet einen
Geschwisterknoten `Combat` mit `von_spieler_gesteuert = false`.

Die Trainingspuppe hat noch keine eigene Szene – sie steht als loser `Node3D`
in `main.tscn`. Sie erbt nicht von `Akteur` und bringt ihre Schadensmethoden
selbst mit: `take_damage()`, `schwachstelle_oeffnen()`, `ist_offen()`,
`schwachstelle_schliessen()`.

Vorgesehen: `daten/npcs/*.tres` für NPC-Vorlagen, weitere Verhaltensarten
(neutral, passiv, freundlich) neben `feindlich.gd` in `ki/`.

---

## spiel/kamera/

| Datei | Zeilen | Aufgabe |
|---|---:|---|
| `spring_arm_camera.gd` | 75 | Federarm: Drehung, Zoom, Kollisionsausweichen. Spiegelt Maussensitivität und Y-Invertierung aus den Einstellungen zwischen, statt sie bei jedem Mausereignis neu abzufragen. |
| `camera_follow.gd` | 48 | Kamera folgt der Federarmspitze weich, Sichtfeld bekommt beim Sprinten einen Zuschlag. |

Beide sind `top_level`, hängen also nicht an der Transformation des Spielers.
Beide leben in `spieler.tscn` und können sich dort per `@export` verdrahten.

---

## spiel/welt/

| Datei | Zeilen | `class_name` | Aufgabe |
|---|---:|---|---|
| `welt.tscn` | 146 | — | Gelände, Licht, Himmel, Wolken, Wasser, Deko, Tageszeit |
| `bloecke.gd` | 121 | `Bloecke` | **Einzige Quelle der Blockindizes.** Kein Autoload, kein Knoten – `class_name` genügt. |
| `generator/world_generator.gd` | 558 | `WorldGenerator` | Erzeugt das Terrain aus Rauschen: Höhe, Biome, Flüsse, Seen, Bäume (Eiche, Buche, Tanne), Steine. |
| `tageszeit.gd` | 194 | `Tageszeit` | **Einzige Quelle der Uhrzeit.** Steuert Richtung, Farbe, Stärke und Schattenbias des einen Lichts (Sonne tags, Mond nachts), schreibt Himmel-Shader und Ambientlicht. |
| `deko_layer.gd` | 343 | `DekoLayer` | Gras und Blumen als MultiMesh im Spielerumkreis, acht Draw Calls insgesamt. |
| `cloud_layer.gd` | 142 | `CloudLayer` | Wolkenfeld aus Quadern, folgt dem Spieler, treibt im Wind, dunkelt nachts ab. |
| `underwater.gd` | 84 | — | Blendet Unterwassernebel, Helligkeit und Sättigung ein, wenn die Kamera in einem Wasservoxel steckt. Holt sich die aktive Kamera selbst. **Einziger Schreiber der Nebelfarbe.** |

### tageszeit.gd

Exportgruppen: *Uhr* (`tageslaenge` 1200 s, `laeuft`, `stunde` 0..24, Start 8),
*Sonnenbahn* (`mittagshoehe` 60°, `bahn_drehung`), *Licht* (`daemmerung`,
`sonne_staerke`, `mond_staerke` 0.12, drei Lichtfarben), *Schatten*
(`bias_flach`, `bias_steil`), *Umgebung* (`ambient_tag`, `ambient_nacht`,
`nebel_farbe_tag`, `nebel_farbe_nacht`).

Öffentlich: `nebel_farbe()`, `tagesanteil_aktuell()`, `tagesanteil(hoehe)`,
`daemmerungsanteil(hoehe)`. Pflichtfeld `licht`; ohne `world_env` läuft sie mit
Warnung weiter, ändert dann aber weder Himmel noch Ambientlicht.

`CloudLayer` und `Underwater` haben je ein optionales Feld `tageszeit`. Ohne
Verweis bleiben Wolken und Nebel auf ihrer Tagfarbe.

### bloecke.gd

```gdscript
const LUFT   := 0     const GRAS_KURZ    := 5     const HOLZ_EICHE := 13
const WASSER := 1     const GRAS_MITTEL  := 6     const HOLZ_BUCHE := 14
const GRAS   := 2     const GRAS_HOCH    := 7     const HOLZ_TANNE := 15
const STEIN  := 3     const GRAS_TROCKEN := 8     const LAUB_EICHE := 16
const ERDE   := 4     const GRAS_BUSCH   := 9     const LAUB_BUCHE := 17
					  const BLUME_ROT    := 10    const LAUB_TANNE := 18
					  const BLUME_GELB   := 11
					  const BLUME_LILA   := 12    const FELS       := 19
```

Dazu `PFLANZE_MIN` / `PFLANZE_MAX` (Strukturen dürfen Deko überschreiben,
Terrain nicht), die Prüfliste `NAMEN[]`, `ANZAHL` und `name_von(index)` für
Fehlermeldungen.

**Diese Reihenfolge muss dem `models`-Array in `daten/welt/bloecke.tres`
entsprechen.** Geprüft wird das mit `werkzeuge/bloecke_namen.gd`.

`WorldGenerator` reicht die Werte unter den alten Namen weiter
(`const GRASS := Bloecke.GRAS`), weil `deko_layer.gd` achtzehnmal
`WorldGenerator.GRAS_KURZ` und Verwandte liest. Konstante aus Konstante kostet
zur Laufzeit nichts.

`WorldGenerator` öffentlich: `hoehe_bei(gx, gz)`, `deko_bei(gx, gz)`,
`baum_plan_bei(cx, cz)` – über diese drei Funktionen bedienen sich Karte und
DekoLayer, ohne Chunks zu laden.

`DekoLayer` öffentlich: `neu_aufbauen()`, `anzahl_pflanzen()`.

---

## spiel/ui/

| Datei | Zeilen | `class_name` | Aufgabe |
|---|---:|---|---|
| `ui.tscn` | 20 | — | Die vier Oberflächenknoten |
| `karte/karte.gd` | 1177 | `Karte` | Minikarte oben rechts und große Karte auf M. Ein gemeinsames `World3D` mit Miniaturgelände, zwei `SubViewport` mit eigener orthografischer Kamera. Erkundung, Wegpunkte. |
| `inventar/inventar_ui.gd` | 822 | — | Inventarfenster: Grundwerte, Item-Boni, Charaktervorschau mit Ausrüstungsslots, Raster mit Suche und Filter, Drag and Drop. |
| `menue/pause_menue.gd` | 633 | — | Fortsetzen, Optionen (Audio, Video, Tastenbelegung), Verlassen. |
| `hud/hud.gd` | 306 | — | Lebens- und Ausdauerbalken, Treffer-Vignette, Meldungstext. Positionen jedes Bild aus der Fenstergröße gerechnet. |

`Karte` öffentlich: `umschalten()`, `oeffnen()`, `schliessen()`,
`setze_wegpunkt()`, `loesche_wegpunkt()`, `alles_aufdecken()`,
`erkundung_zuruecksetzen()`.

`inventar_ui.gd` öffentlich: `umschalten()`, `oeffnen()`, `schliessen()`,
`zeige_tooltip()`, `verstecke_tooltip()`, `darf_ablegen()`, `lege_ab()`.
Enthält die eingebettete Klasse `SlotFeld` – wird in Etappe 04 herausgelöst.
Enthält außerdem noch zwei `print`-Aufrufe aus der Fehlersuche zu Etappe 02.

`pause_menue.gd` öffentlich: `oeffnen()`, `schliessen()`, `umschalten()`,
`ist_offen()`.

---

## spiel/ressourcen/

Resource-**Klassen**. Hier steht die Bauart, nicht der Inhalt.

| Datei | Zeilen | `class_name` | Aufgabe |
|---|---:|---|---|
| `waffen_daten.gd` | 155 | `WaffenDaten` | Beschreibt eine ausrüstbare Waffe. Kampf, Animation und Ausrüstung lesen alle hieraus. |
| `item_daten.gd` | 93 | `ItemDaten` | Beschreibt einen Gegenstandstyp – die Art, nicht das Exemplar. Menge steckt im Inventar. |
| `item_katalog.gd` | 80 | `ItemKatalog` | Erzeugt Testitems per Code, solange es noch keine `.tres` gibt. |

`WaffenDaten` Enums:
`Slot { HAND_RECHTS, HAND_LINKS, KOPF, BRUST, BEINE }`,
`Griff { EINHAND, ZWEIHAND, SCHILD, LEER }`,
`Stil { FAUST, STICH, HIEB, SCHWUNG_SCHWER, STANGE }`,
`Schadensart { STUMPF, SCHNITT, STICH }`.

Felder in Gruppen: Allgemein (`anzeige_name`, `beschreibung`, `symbol`, `slot`,
`griff`, `kann_einhaendig`) · Darstellung (`mesh`, `material_ueberschreiben`,
`halte_versatz`, `halte_drehung`, `halte_skalierung`, `wirft_schatten`) · Kampf
(`stil`, `schadensart`, `schaden`, `kritisch_multiplikator`, `reichweite`,
`treffer_radius`, `wucht`) · Timing (`angriff_dauer`, `treffer_start`,
`treffer_ende`, `nachziehzeit`, `kombo_schritte`, `kombo_fenster`) ·
Ausdauer und Block (`ausdauer_kosten`, `kann_blocken`, `block_durchlass`,
`block_ausdauer_kosten`) · Einhändig geführt (`einhand_schaden`,
`einhand_dauer`, `einhand_nachziehzeit`, `einhand_reichweite`,
`einhand_ausdauer`, `einhand_wucht` – Faktoren, wirken nur bei `kann_einhaendig`)
· Klang (`klang_schwung`, `klang_treffer`).

Funktionen: `ist_zweihaendig()` (Führung – davon hängen Kampfwerte ab),
`erzwingt_zwei_haende()` (muss die Nebenhand frei bleiben – das fragt die
Ausrüstung), `einhand_fassung()` (Kopie mit Abschlägen, nicht pro Bild rufen),
`hat_modell()`, `gepruefte_werte()`.

`halte_drehung` ist nur für den festen Sitz im Halter gedacht, nicht für die
Haltung – `character_visual.gd` dreht den Halter selbst, ein Wert hier verzieht
alle Posen mit.

`gepruefte_werte()` fängt fehlerhafte `.tres` ab, damit sie das Kampfsystem
nicht blockieren, und warnt, wenn `kann_einhaendig` an einer Waffe ohne
`Griff = ZWEIHAND` gesetzt ist.

`ItemDaten` Enums:
`Slot { KEINER, KOPF, RUESTUNG, HAENDE, FUESSE, RING, AMULETT, HAUPTHAND, NEBENHAND }`,
`Seltenheit { GEWOEHNLICH, UNGEWOEHNLICH, SELTEN, EPISCH, LEGENDAER }`.
Boni: `bonus_leben`, `bonus_ausdauer`, `bonus_schaden`, `bonus_ruestung`,
`bonus_tempo`, `bonus_krit`.

---

## daten/

Resource-**Instanzen**. Hier wächst der Spielinhalt.

| Pfad | Griff | Stil | Schaden | Reichweite | Dauer |
|---|---|---|---:|---:|---:|
| `waffen/faust.tres` | LEER | FAUST | — | — | — |
| `waffen/kurzschwert.tres` | EINHAND | STICH | 14 | 1.9 | 0.42 |
| `waffen/axt.tres` | EINHAND | HIEB | 20 | 1.8 | 0.55 |
| `waffen/zweihaender.tres` | ZWEIHAND | SCHWUNG_SCHWER | 34 | 2.6 | 0.85 |
| `waffen/speer.tres` | ZWEIHAND, `kann_einhaendig` | STANGE | 18 | 3.1 | 0.50 |
| `waffen/holzschild.tres` | SCHILD, Slot `HAND_LINKS` | — | 6 | 1.4 | 0.60 |

`faust.tres` ist die Rückfallwaffe bei leerer Hand. Die übrigen fünf erzeugt
`werkzeuge/waffen_erzeugen.gd`, jeder Waffenstil ist damit einmal belegt. Der
Spieler startet mit Speer und Holzschild.

| Pfad | Zeilen | Inhalt |
|---|---:|---|
| `daten/welt/bloecke.tres` | 151 | Die `VoxelBlockyLibrary`: 20 Blockmodelle in fester Reihenfolge. Seit Etappe 02 aus `main.tscn` herausgelöst. |

Vorgesehen, noch leer: `daten/ruestung/` (liegt als leerer Ordner da, Git
versioniert ihn nicht), `daten/items/`, `daten/npcs/`.

Neue Waffe anlegen: entweder einen Eintrag in `_tabelle()` von
`werkzeuge/waffen_erzeugen.gd` ergänzen (dann entsteht das Mesh gleich mit),
oder von Hand: Rechtsklick im Dateisystem → Neue Ressource → `WaffenDaten` →
speichern unter `daten/waffen/<name>.tres`.

Neuen Blocktyp anlegen: Modell in `bloecke.tres` **ans Ende** hängen, Konstante
in `spiel/welt/bloecke.gd` und Eintrag in `NAMEN[]` ergänzen, `ANZAHL` erhöhen,
dann `werkzeuge/bloecke_namen.gd` ausführen.

---

## assets/

| Pfad | Inhalt |
|---|---|
| `assets/materials/himmel.gdshader` | Himmel-Shader: Tag- und Nachtverlauf in Bändern, Dämmerungsglühen, Sonnen- und Mondscheibe mit Kratern, drehender Sternenhimmel. Wird von `Tageszeit` gesteuert. |
| `assets/materials/voxel_solid.tres` | Terrainmaterial, `vertex_color_use_as_albedo` |
| `assets/materials/waffen_material.tres` | Ein Material für alle Waffen, Farben stecken als Vertexfarbe im Mesh |
| `assets/materials/plant_material.tres` | Basismaterial für Pflanzen, beidseitig sichtbar |
| `assets/materials/plants/*.tres` | neun Pflanzenmaterialien, alle auf `plant_wind.gdshader` |
| `assets/materials/plants/plant_wind.gdshader` | Windbewegung im Vertexshader |
| `assets/meshes/plants/*.res` | acht Pflanzenmeshes, mit `make_plants.gd` erzeugt |
| `assets/meshes/waffen/*.res` | fünf Waffenmeshes aus Quadern, mit `waffen_erzeugen.gd` erzeugt |

Die Blattnamen (`materials`, `meshes`, `plants`) werden in Etappe 05b deutsch.

**Achtung:** `deko_layer.gd` lädt diese Verzeichnisse über die Exportfelder
`mesh_verzeichnis` und `material_verzeichnis` als **Zeichenkette**. Wer die
Ordner verschiebt, muss dort nachziehen – Godot merkt das nicht.

---

## werkzeuge/

EditorScripts. Laufen **nie** im Spiel, im Editor über Datei → Ausführen
(Strg+Umschalt+X).

| Datei | Zeilen | Aufgabe |
|---|---:|---|
| `bloecke_namen.gd` | 146 | Setzt die `resource_name`-Felder der Blockmodelle in `bloecke.tres` auf die Konstantennamen aus `bloecke.gd` und prüft danach beide Seiten gegeneinander. |
| `make_plants.gd` | 264 | Erzeugt die Pflanzenmeshes und -materialien aus Farbtabellen. |
| `waffen_erzeugen.gd` | 377 | Erzeugt fünf Waffen als Quader-Mesh **und** als `WaffenDaten`, dazu das gemeinsame Waffenmaterial. |

`bloecke_namen.gd` prüft dreierlei: dass `NAMEN[]` in sich zu den Konstanten
passt, dass die Anzahl stimmt, und dass kein Modell verrutscht ist. Ein
abweichender, aber vorhandener Name wird **nicht** überschrieben – das würde
die Spur verwischen. Der Schalter `SCHREIBEN` steht standardmäßig auf `false`.

**Noch nicht ausgeführt:** in `bloecke.tres` steht bisher kein einziger
`resource_name`, die Prüfung ist also noch nicht scharf.

`waffen_erzeugen.gd` hat zwei Schalter: `SCHREIBEN` (`true`) und
`UEBERSCHREIBEN` (`false`). Ein erneuter Lauf legt also nur an, was noch
fehlt – neue Einträge in `_tabelle()` –, und lässt vorhandene, im Inspektor
nachjustierte Waffen in Ruhe. Wer eine Waffe bewusst aus der Tabelle neu
erzeugen will, löscht vorher ihre `.tres` und `.res`. Die Meshes sind so gebaut, dass `character_visual.gd` für
Axt und Zweihänder eine Rollkorrektur braucht; die Kommentare dort sagen, wie
die Quader stattdessen liegen müssten.

`make_plants.gd` führt Pfade als Konstanten `MESH_DIR`, `MAT_DIR`,
`SHADER_PATH`, `waffen_erzeugen.gd` ebenso `MESH_DIR`, `MAT_PFAD`,
`WAFFEN_DIR` – dieselbe Falle wie bei `deko_layer.gd`.

---

## Größenverteilung

```
character_visual.gd 1261  ████████████████████
karte.gd            1177  ███████████████████
inventar_ui.gd       822  █████████████
combat.gd            652  ██████████
pause_menue.gd       633  ██████████
world_generator.gd   558  █████████
player.gd            542  █████████
waffen_erzeugen.gd   377  ██████
deko_layer.gd        343  █████
einstellungen.gd     325  █████
hud.gd               306  █████
npc.gd               300  █████
ausruestung.gd       297  █████
trainingspuppe.gd    283  ████
inventar.gd          273  ████
make_plants.gd       264  ████
tageszeit.gd         194  ███
waffen_daten.gd      155  ██
feindlich.gd         151  ██
bloecke_namen.gd     146  ██
cloud_layer.gd       142  ██
bloecke.gd           121  ██
item_daten.gd         93  █
underwater.gd         84  █
item_katalog.gd       80  █
spring_arm_camera.gd  75  █
akteur.gd             50  █
camera_follow.gd      48  █
```

`character_visual.gd` hat sich mit der Waffenhaltung fast verdoppelt und ist
jetzt die größte Datei – gut ein Drittel davon sind Kommentare, die die
Posenwinkel gegen die Körperkästen herleiten. Die fünf größten Dateien tragen
knapp die Hälfte des Codes. Die interne Gliederung ist mit Abschnittskommentaren
sauber gezogen – die Schnittkanten für eine Aufteilung sind also schon
eingezeichnet. Siehe Etappe 04 in [roadmap.md](roadmap.md).
