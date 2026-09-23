# Shardfall

Ein Voxel-Rollenspiel in Godot 4.6. Blockwelt, die zur Laufzeit aus
Rauschfunktionen entsteht, Third-Person-Kamera, Nahkampf mit Kombos und
perfektem Blocken, Inventar mit Ausrüstung, Karte mit Erkundungsnebel.

Charaktere sind Würfelfiguren ohne Skelett – keine Arme, keine Beine, nur Hände
und Füße, die als einzelne Knoten verschoben werden.

---

## Starten

Voraussetzung: **Godot 4.6** (Standardversion, keine .NET-Variante).

```
Godot_v4.6-stable_win64.exe --path . 
```

Oder das Projekt im Godot-Projektmanager öffnen und F5 drücken.
Startszene ist `szenen/main.tscn`.

Das Voxel-Addon liegt mitversioniert in `addons/zylann.voxel/` – ein frischer
Klon ist ohne weitere Installation lauffähig. Die GDExtension bringt
Binärdateien für Windows, Linux, macOS, Android und iOS mit.

### Kopflos prüfen, ohne den Editor zu öffnen

```
Godot_v4.6-stable_win64.exe --headless --path . --import
```

Importiert alle Ressourcen und registriert die Skriptklassen neu. Beendet mit
Code 0, wenn nichts kaputt ist – nützlich nach dem Verschieben von Dateien.

```
Godot_v4.6-stable_win64.exe --headless --path . --quit-after 180
```

Startet die Hauptszene für 180 Bilder. Meldet sich HUD, Karte, Deko und
Trainingspuppe in der Ausgabe, läuft das Spiel. Die Fehler
`keyboard_get_keycode_from_physical: Not supported by this display server`
sind normal und treten nur kopflos auf – der Dummy-Displayserver hat keine
Tastatur, und das Pausenmenü fragt beim Bau seiner Tastenzeilen danach.
Zwei Warnungen "keine Ausruestung gefunden" stammen vom NPC, der noch ohne
Ausrüstung kämpft.

---

## Steuerung

| Taste | Wirkung |
|---|---|
| W A S D | Bewegen |
| Leertaste | Springen |
| Shift | Sprinten |
| Strg | Schleichen und Ducken |
| Alt | Frei umsehen, ohne die Figur zu drehen |
| Maus | Kamera drehen |
| Mausrad | Zoom |
| Maus links | Angreifen |
| Maus rechts | Blocken – kurz vor dem Treffer für einen Parry |
| I | Inventar |
| M | Karte |
| ESC | Pausenmenü, schließt auch Inventar und Karte |

Belegung änderbar unter Pausenmenü → Optionen → Steuerung.

---

## Aufbau

```
szenen/       main.tscn - setzt nur zusammen, 30 Zeilen
spiel/        aller eigene Spielcode, Teilszenen liegen beim System
  autoload/     Einstellungen (Autoload)
  akteure/
    gemeinsam/  Akteur (Basisklasse), koerper.tscn (das Rig), Kampf,
                Ausrüstung, Körperoptik - was Spieler UND NPC benutzen
    spieler/    spieler.tscn, Bewegung, Inventar
    npc/        npc.tscn, NPC-Bewegung, ki/ (Verhalten), Trainingspuppe
  kamera/       Federarm, Kameranachführung
  welt/         welt.tscn, Blockindizes, Weltgenerator, Tageszeit, Deko,
                Wolken, Wasser
  ui/           ui.tscn + HUD, Inventar, Karte, Pausenmenü
  ressourcen/   Resource-Klassen (ItemDaten, WaffenDaten)
daten/        Resource-Instanzen (.tres) - Waffen, Blockbibliothek
assets/       Meshes, Materialien, Shader
werkzeuge/    EditorScripts (Pflanzen, Waffen, Blockprüfung), nie im Spiel
addons/       Fremdcode (zylann.voxel) - nie verändern
docs/         Dokumentation
```

Geordnet ist nach **Feature, nicht nach Dateityp**: kein `scripts/` neben
`scenes/`, sondern ein Ordner pro Spielsystem. Teilszenen liegen bei ihrem
System, nicht in `szenen/`.

Das Spiel besteht aus sechs Szenen, die einander instanzieren:

```
main.tscn ─ Spiel
            ├─ Welt      -> spiel/welt/welt.tscn
            ├─ Player    -> spiel/akteure/spieler/spieler.tscn
            │             └─ Visual -> spiel/akteure/gemeinsam/koerper.tscn
            ├─ Trainingspuppe
            ├─ UI        -> spiel/ui/ui.tscn
            └─ Npc       -> spiel/akteure/npc/npc.tscn
                          └─ Visual -> spiel/akteure/gemeinsam/koerper.tscn
```

`koerper.tscn` ist das Würfel-Rig – Spieler und NPCs benutzen dieselbe Datei,
und beide erben von derselben Basisklasse `Akteur`.

---

## Dokumentation

| Datei | Inhalt |
|---|---|
| [docs/architektur.md](docs/architektur.md) | Szenenbaum, Signale, Gruppen, Datenfluss, bekannte Schwachstellen |
| [docs/dateien.md](docs/dateien.md) | Datei für Datei: was liegt wo, wofür, welche öffentliche Schnittstelle |
| [docs/konventionen.md](docs/konventionen.md) | Namensregeln, Codestil, Git |
| [docs/roadmap.md](docs/roadmap.md) | Was als Nächstes kommt und in welcher Reihenfolge |
| [CLAUDE.md](CLAUDE.md) | Arbeitsanweisungen für Claude Code |

---

## Stand

Spielbar: Weltgenerierung mit Biomen, Flüssen und Seen · Bäume und Steine ·
Gras und Blumen im Spielerumkreis · Tag-Nacht-Zyklus mit Sonne, Mond und
Sternen · Bewegung mit Stufensteigen, Waten und Schwimmen · Nahkampf mit
Kombos, Blocken und Parry · fünf Waffen mit eigener Haltung und Schlagpose,
Speer wahlweise mit Schild · ein feindlicher NPC, der verfolgt, zuschlägt und
blockt · Inventar mit Ausrüstungsslots und Drag and Drop · Minikarte und große
Karte mit Erkundungsnebel und Wegpunkten · Pausenmenü mit Audio-, Video- und
Steuerungsoptionen.

Fehlt: Inventar und Waffen verbinden · weitere NPC-Arten (neutral, passiv,
freundlich) · Gebäude · Hauptmenü · Spielstand.

Der Umbau der Struktur ist bis Etappe 02 durch: die Szene ist zerlegt, das
Charakter-Rig ist wiederverwendbar, und die Blockindizes stehen nur noch an
einer Stelle. Damit ist nichts mehr blockiert – der NPC war der erste
Inhalt, der davon profitiert hat.

Siehe [docs/roadmap.md](docs/roadmap.md).
