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
szenen/       main.tscn
spiel/        aller eigene Spielcode
  autoload/     Einstellungen (Autoload)
  akteure/
    gemeinsam/  Kampf, Ausrüstung, Körperoptik - Spieler UND NPC
    spieler/    Spieler, Inventar
    npc/        Trainingspuppe, künftige NPCs
  kamera/       Federarm, Kameranachführung
  welt/         Weltgenerator, Deko, Wolken, Unterwasser
  ui/           HUD, Inventar, Karte, Pausenmenü
  ressourcen/   Resource-Klassen (ItemDaten, WaffenDaten)
daten/        Resource-Instanzen (.tres) - hier wächst der Spielinhalt
assets/       Meshes, Materialien, Shader
werkzeuge/    EditorScripts, laufen nie im Spiel
addons/       Fremdcode (zylann.voxel) - nie verändern
docs/         Dokumentation
```

Geordnet ist nach **Feature, nicht nach Dateityp**: kein `scripts/` neben
`scenes/`, sondern ein Ordner pro Spielsystem.

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
Gras und Blumen im Spielerumkreis · Bewegung mit Stufensteigen, Waten und
Schwimmen · Nahkampf mit Kombos, Blocken und Parry · Inventar mit Ausrüstung
und Drag and Drop · Minikarte und große Karte mit Erkundungsnebel und
Wegpunkten · Pausenmenü mit Audio-, Video- und Steuerungsoptionen.

Fehlt: NPCs · Gebäude · mehr als eine Waffe · Hauptmenü · Spielstand.

Siehe [docs/roadmap.md](docs/roadmap.md).
