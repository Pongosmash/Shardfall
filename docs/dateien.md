# Dateiverzeichnis

Was liegt wo und wofür. Für Zusammenhänge siehe [architektur.md](architektur.md).

Stand: 20.08.2026 · 21 Skripte · 7.620 Zeilen GDScript

---

## Grundriss

```
project.godot            Projektkonfiguration
icon.svg                 Anwendungssymbol
default_bus_layout.tres  Audiobusse

docs/                    diese Dokumentation
addons/zylann.voxel/     Fremdcode, nie verändern
szenen/                  main.tscn
spiel/                   aller eigene Spielcode
daten/                   Resource-INSTANZEN (.tres)
assets/                  Meshes, Materialien, Shader
werkzeuge/               EditorScripts, laufen nie im Spiel
```

Die Trennung, die am häufigsten verrutscht:

- `spiel/ressourcen/` enthält die **Bauart** – `waffen_daten.gd` ist eine Klasse
- `daten/` enthält die **Exemplare** – `faust.tres` ist eine Waffe

Neue Waffen, Items, NPC-Vorlagen kommen nach `daten/`, nicht nach `spiel/`.

---

## szenen/

| Datei | Zeilen | Inhalt |
|---|---:|---|
| `main.tscn` | 405 | **Die** Szene. ~50 Knoten, davon ~200 Zeilen inline `VoxelBlockyLibrary`. Wird in Etappe 02 zerlegt. |

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

Was Spieler **und** NPCs benutzen. Alle drei hängen als Kindknoten unter einem
Akteur, nicht unter dem Spieler speziell – deshalb liegen sie hier.

| Datei | Zeilen | `class_name` | Aufgabe |
|---|---:|---|---|
| `combat.gd` | 596 | `Combat` | Leben, Ausdauer, Angriffe, Blocken, perfektes Blocken. **Einzige Quelle für Timing und Schaden.** |
| `ausruestung.gd` | 233 | `Ausruestung` | Welche `WaffenDaten` in welchem Slot stecken; erzeugt und entfernt die Waffenmodelle an den Handhaltern. |
| `character_visual.gd` | 698 | — | Würfelmodell: Laufzyklus über die zurückgelegte Strecke, Neigung in Kurven, Ducken, Springen, Schwimmen, Schlagposen. Liest Timing aus `Combat`, rechnet nie eigenes. |

`Combat` öffentlich: `im_kampf()`, `darf_sprinten()`, `kampf_ausloesen()`,
`sprint_kosten()`, `aktive_waffe()`, `aktive_blockwaffe()`, `aktiver_stil()`,
`schlag_marken()`, `schwachstelle_oeffnen()`, `ist_offen()`,
`schwachstelle_schliessen()`, `schaden_erhalten()`.

`Ausruestung` öffentlich: `ausruesten()`, `ablegen()`, `hole()`,
`aktive_waffe()`, `nebenhand()`, `haende_wechseln_erlaubt()`, `block_waffe()`,
`belegung()`, `ist_bereit()`.

`character_visual.gd` öffentlich: `baue_proportionen()`, `hole_gesamt_hoehe()`,
`hole_hand(links)`.

---

## spiel/akteure/spieler/

| Datei | Zeilen | `class_name` | Aufgabe |
|---|---:|---|---|
| `player.gd` | 558 | `Player` | Bewegung, Springen, Ducken, Stufensteigen, Waten und Schwimmen, Kollisionskapsel. |
| `inventar.gd` | 273 | `Inventar` | Datenhaltung für Inventar und Ausrüstungsslots. Kennt keine Oberfläche. |

`player.gd` öffentlicher Zustand, den andere lesen: `is_sprinting`,
`is_sneaking`, `is_wading`, `is_swimming`, `is_submerged`, `is_climbing`.
Methoden: `take_damage()`, `schwachstelle_oeffnen()`, `ist_offen()`,
`schwachstelle_schliessen()`, `respawn()`.

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

| Datei | Zeilen | Aufgabe |
|---|---:|---|
| `trainingspuppe.gd` | 283 | Testziel. Stellt sich beim Start selbst vor den Spieler, nimmt Schaden, schlägt zurück, wird beim Parieren offen für einen kritischen Treffer. |

Bisher der einzige Bewohner. Hier landen die NPCs aus der Roadmap.
Öffentlich: `take_damage()`, `schwachstelle_oeffnen()`, `ist_offen()`,
`schwachstelle_schliessen()`.

---

## spiel/kamera/

| Datei | Zeilen | Aufgabe |
|---|---:|---|
| `spring_arm_camera.gd` | 75 | Federarm: Drehung, Zoom, Kollisionsausweichen. Spiegelt Maussensitivität und Y-Invertierung aus den Einstellungen zwischen, statt sie bei jedem Mausereignis neu abzufragen. |
| `camera_follow.gd` | 48 | Kamera folgt der Federarmspitze weich, Sichtfeld bekommt beim Sprinten einen Zuschlag. |

Beide sind `top_level`, hängen also nicht an der Transformation des Spielers.

---

## spiel/welt/

| Datei | Zeilen | `class_name` | Aufgabe |
|---|---:|---|---|
| `generator/world_generator.gd` | 553 | `WorldGenerator` | Erzeugt das Terrain aus Rauschen: Höhe, Biome, Flüsse, Seen, Bäume (Eiche, Buche, Tanne), Steine. |
| `deko_layer.gd` | 336 | `DekoLayer` | Gras und Blumen als MultiMesh im Spielerumkreis, acht Draw Calls insgesamt. |
| `cloud_layer.gd` | 122 | `CloudLayer` | Wolkenfeld aus Quadern, folgt dem Spieler, treibt im Wind. |
| `underwater.gd` | 68 | — | Blendet Unterwassernebel, Helligkeit und Sättigung ein, wenn die Kamera in einem Wasservoxel steckt. |

`WorldGenerator` öffentlich: `hoehe_bei(gx, gz)`, `deko_bei(gx, gz)`,
`baum_plan_bei(cx, cz)` – über diese drei Funktionen bedienen sich Karte und
DekoLayer, ohne Chunks zu laden.

Blockindizes als Konstanten: `AIR 0`, `WATER 1`, `GRASS 2`, `STONE 3`,
`DIRT 4`, `GRAS_KURZ 5`, `GRAS_MITTEL 6`, `GRAS_HOCH 7`, `GRAS_TROCKEN 8`,
`GRAS_BUSCH 9`, `BLUME_ROT 10`, `BLUME_GELB 11`, `BLUME_LILA 12`,
`HOLZ_EICHE 13`, `HOLZ_BUCHE 14`, `HOLZ_TANNE 15`, `LAUB_EICHE 16`,
`LAUB_BUCHE 17`, `LAUB_TANNE 18`, `FELS 19`.
**Diese Reihenfolge muss der Blockbibliothek in `main.tscn` entsprechen.**

`DekoLayer` öffentlich: `neu_aufbauen()`, `anzahl_pflanzen()`.

---

## spiel/ui/

| Datei | Zeilen | `class_name` | Aufgabe |
|---|---:|---|---|
| `karte/karte.gd` | 1166 | `Karte` | Minikarte oben rechts und große Karte auf M. Ein gemeinsames `World3D` mit Miniaturgelände, zwei `SubViewport` mit eigener orthografischer Kamera. Erkundung, Wegpunkte. |
| `inventar/inventar_ui.gd` | 817 | — | Inventarfenster: Grundwerte, Item-Boni, Charaktervorschau mit Ausrüstungsslots, Raster mit Suche und Filter, Drag and Drop. |
| `menue/pause_menue.gd` | 633 | — | Fortsetzen, Optionen (Audio, Video, Tastenbelegung), Verlassen. |
| `hud/hud.gd` | 306 | — | Lebens- und Ausdauerbalken, Treffer-Vignette, Meldungstext. Positionen jedes Bild aus der Fenstergröße gerechnet. |

`Karte` öffentlich: `umschalten()`, `oeffnen()`, `schliessen()`,
`setze_wegpunkt()`, `loesche_wegpunkt()`, `alles_aufdecken()`,
`erkundung_zuruecksetzen()`.

`inventar_ui.gd` öffentlich: `umschalten()`, `oeffnen()`, `schliessen()`,
`zeige_tooltip()`, `verstecke_tooltip()`, `darf_ablegen()`, `lege_ab()`.
Enthält die eingebettete Klasse `SlotFeld` – wird in Etappe 04 herausgelöst.

`pause_menue.gd` öffentlich: `oeffnen()`, `schliessen()`, `umschalten()`,
`ist_offen()`.

---

## spiel/ressourcen/

Resource-**Klassen**. Hier steht die Bauart, nicht der Inhalt.

| Datei | Zeilen | `class_name` | Aufgabe |
|---|---:|---|---|
| `waffen_daten.gd` | 93 | `WaffenDaten` | Beschreibt eine ausrüstbare Waffe. Kampf, Animation und Ausrüstung lesen alle hieraus. |
| `item_daten.gd` | 93 | `ItemDaten` | Beschreibt einen Gegenstandstyp – die Art, nicht das Exemplar. Menge steckt im Inventar. |
| `item_katalog.gd` | 80 | `ItemKatalog` | Erzeugt Testitems per Code, solange es noch keine `.tres` gibt. |

`WaffenDaten` Enums:
`Slot { HAND_RECHTS, HAND_LINKS, KOPF, BRUST, BEINE }`,
`Griff { EINHAND, ZWEIHAND, SCHILD, LEER }`,
`Stil { FAUST, STICH, HIEB, SCHWUNG_SCHWER, STANGE }`,
`Schadensart { STUMPF, SCHNITT, STICH }`.

Felder in Gruppen: Allgemein (`anzeige_name`, `beschreibung`, `symbol`, `slot`,
`griff`) · Darstellung (`mesh`, `material_ueberschreiben`, `halte_versatz`,
`halte_drehung`, `halte_skalierung`, `wirft_schatten`) · Kampf (`stil`,
`schadensart`, `schaden`, `kritisch_multiplikator`, `reichweite`,
`treffer_radius`, `wucht`) · Timing (`angriff_dauer`, `treffer_start`,
`treffer_ende`, `nachziehzeit`, `kombo_schritte`, `kombo_fenster`) ·
Ausdauer und Block (`ausdauer_kosten`, `kann_blocken`, `block_durchlass`,
`block_ausdauer_kosten`) · Klang (`klang_schwung`, `klang_treffer`).

`gepruefte_werte()` fängt fehlerhafte `.tres` ab, damit sie das Kampfsystem
nicht blockieren.

`ItemDaten` Enums:
`Slot { KEINER, KOPF, RUESTUNG, HAENDE, FUESSE, RING, AMULETT, HAUPTHAND, NEBENHAND }`,
`Seltenheit { GEWOEHNLICH, UNGEWOEHNLICH, SELTEN, EPISCH, LEGENDAER }`.
Boni: `bonus_leben`, `bonus_ausdauer`, `bonus_schaden`, `bonus_ruestung`,
`bonus_tempo`, `bonus_krit`.

---

## daten/

Resource-**Instanzen**. Hier wächst der Spielinhalt.

| Pfad | Inhalt |
|---|---|
| `daten/waffen/faust.tres` | Rückfallwaffe, `Griff = LEER`, `Stil = FAUST`. Die derzeit **einzige** Waffe. |

Vorgesehen, noch leer: `daten/items/`, `daten/npcs/`, `daten/welt/`.

Neue Waffe anlegen: Rechtsklick im Dateisystem → Neue Ressource →
`WaffenDaten` → speichern unter `daten/waffen/<name>.tres`.

---

## assets/

| Pfad | Inhalt |
|---|---|
| `assets/materials/himmel.gdshader` | Himmel-Shader für das `WorldEnvironment` |
| `assets/materials/voxel_solid.tres` | Terrainmaterial, `vertex_color_use_as_albedo` |
| `assets/materials/plant_material.tres` | Basismaterial für Pflanzen, beidseitig sichtbar |
| `assets/materials/plants/*.tres` | neun Pflanzenmaterialien, alle auf `plant_wind.gdshader` |
| `assets/materials/plants/plant_wind.gdshader` | Windbewegung im Vertexshader |
| `assets/meshes/plants/*.res` | acht Pflanzenmeshes, mit `make_plants.gd` erzeugt |

Die Blattnamen (`materials`, `meshes`, `plants`) werden in Etappe 05 deutsch.

**Achtung:** `deko_layer.gd` lädt diese Verzeichnisse über die Exportfelder
`mesh_verzeichnis` und `material_verzeichnis` als **Zeichenkette**. Wer die
Ordner verschiebt, muss dort nachziehen – Godot merkt das nicht.

---

## werkzeuge/

| Datei | Zeilen | Aufgabe |
|---|---:|---|
| `make_plants.gd` | 264 | `@tool EditorScript`. Erzeugt die Pflanzenmeshes und -materialien aus Farbtabellen. Läuft **nie** im Spiel – im Editor über "Datei → Ausführen". |

Pfade stehen als Konstanten `MESH_DIR`, `MAT_DIR`, `SHADER_PATH` – dieselbe
Falle wie bei `deko_layer.gd`.

---

## Größenverteilung

Fünf Dateien tragen zwei Drittel des Codes:

```
karte.gd            1166  ████████████████████
inventar_ui.gd       817  ██████████████
character_visual.gd  698  ████████████
pause_menue.gd       633  ███████████
combat.gd            596  ██████████
player.gd            558  █████████
world_generator.gd   553  █████████
deko_layer.gd        336  ██████
einstellungen.gd     325  █████
hud.gd               306  █████
trainingspuppe.gd    283  █████
inventar.gd          273  ████
make_plants.gd       264  ████
ausruestung.gd       233  ████
cloud_layer.gd       122  ██
item_daten.gd         93  █
waffen_daten.gd       93  █
item_katalog.gd       80  █
spring_arm_camera.gd  75  █
underwater.gd         68  █
camera_follow.gd      48  █
```

Die interne Gliederung dieser Dateien ist mit Abschnittskommentaren sauber
gezogen – die Schnittkanten für eine Aufteilung sind also schon eingezeichnet.
Siehe Etappe 04 in [roadmap.md](roadmap.md).
