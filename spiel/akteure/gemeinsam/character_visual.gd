extends Node3D

# Cube-World-artiges Charaktermodell.
#
# - keine Beine, nur Füße
# - keine Arme, nur Hände
# - Torso in zwei Teilen: Hüfte (unten) + Brust (oben)
#   -> beugt sich beim Schleichen, dreht sich leicht beim Schlagen
# - Körper legt sich in Kurven
# - Laufzyklus läuft über die zurückgelegte STRECKE, nicht über die Zeit
#
# ANGRIFFE UND WAFFENHALTUNG:
# Der Körper dreht sich nicht in Gelenken – es gibt keine. Ein Schlag ist eine
# VERSCHIEBUNG des Handwürfels. Der WAFFENHALTER unter der Hand dreht sich
# dagegen sehr wohl: eine Klinge hat eine Richtung, und eine Klinge, die sich
# nur durch den Raum schiebt, sieht immer nach Stochern aus. Die Figur bleibt
# damit eine Würfelfigur, die Waffe wird trotzdem geführt.
#
# Drei Schichten, die aufeinanderliegen:
#
#   1. Laufzyklus       Hände schwingen mit der Strecke
#   2. Ruhehaltung      pro Waffenstil ein Versatz + eine Halterdrehung
#   3. Schlag           Versatz und Halterdrehung über den Schlagverlauf
#
# WARUM DIE HANDDREHUNG BEI ALLEN WAFFENSTILEN NULL IST:
# Der Halter hängt UNTER der Hand. Eine Handdrehung multipliziert sich also
# auf jede Halterdrehung drauf, und die Winkel in _stil_posen wären nicht
# mehr das, was man sieht. Diese Winkel sind gegen die Körperkästen gerechnet
# – das gilt nur bei ungedrehter Hand. Einzige Ausnahme ist FAUST: dort gibt
# es keine Waffe zu führen, und die Faust selbst darf kippen.
#
# Schicht 2 ist neu und der Grund, warum vorher alles verkrüppelt aussah: ohne
# sie steht der Halter auf rotation = 0, die Klinge zeigt waagerecht nach vorn
# aus der Hüfte, und genau so steht die Figur die meiste Zeit da.
#
# Timing kommt weiterhin ausschließlich aus Combat (schlag_marken(),
# angriff_fortschritt). WELCHE Waffe die Figur hält, kommt dagegen aus
# Ausruestung: aktive_waffe(), ist_zweihaendig(), nebenhand(). Combat kennt
# den Stil nur, soweit es ihn für den laufenden Schlag braucht – im Stand
# kann aktiver_stil() auf Faust zurückfallen, und dann gäbe es gar keine
# Ruhehaltung. Diese Datei fragt deshalb die Ausruestung, nicht Combat.
#
# Einzige Ausnahme vom Timing-Verbot: der NACHSCHWUNG nach dem Schlagende,
# siehe _schlag_fortschritt weiter unten. Er läuft nie während eines Schlages
# und kann das Trefferfenster deshalb nicht verschieben.
#
# Erwarteter Knotenbaum (dieses Skript liegt auf dem Wurzelknoten "Visual"):
#
# Visual (Node3D)                    <- dieses Skript
# └─ Neigung (Node3D)
#    ├─ Huefte (Node3D)
#    │  ├─ TorsoUnten (MeshInstance3D)
#    │  └─ Brust (Node3D)
#    │     ├─ TorsoOben (MeshInstance3D)
#    │     ├─ Kopf (Node3D)
#    │     │  └─ KopfMesh (MeshInstance3D)
#    │     ├─ HandLinks (Node3D)
#    │     │  ├─ HandLinksMesh (MeshInstance3D)
#    │     │  └─ HalterLinks (Node3D)      <- Waffenmodell, wird hier gedreht
#    │     └─ HandRechts (Node3D)
#    │        ├─ HandRechtsMesh (MeshInstance3D)
#    │        └─ HalterRechts (Node3D)     <- Waffenmodell, wird hier gedreht
#    ├─ FussLinks (Node3D)
#    │  └─ FussLinksMesh (MeshInstance3D)
#    └─ FussRechts (Node3D)
#       └─ FussRechtsMesh (MeshInstance3D)
#
# WICHTIG zur Arbeitsteilung am Halter: dieses Skript schreibt ausschließlich
# 'rotation' der beiden Halter, niemals position oder scale. ausruestung.gd
# darf also weiterhin halte_versatz / halte_drehung / halte_skalierung auf das
# MODELL unter dem Halter legen. Schreibt ausruestung.gd stattdessen auf den
# Halter selbst, zittern die Waffen – dann dort auf das Modell umstellen.
#
# Alle Größen und Ruhepositionen werden aus den Proportionswerten berechnet,
# die Meshes im Editor dürfen also beliebige Maße haben.

@export_group("Referenzen")
@export var player_path: NodePath = ^".."
## AUS lassen, solange spring_arm_camera.gd den Player dreht. Dieses Skript
## würde sonst zusätzlich drehen (Figur dreht sich doppelt) und das Free-Look
## auf Alt sofort wieder überschreiben.
## Nur einschalten, wenn die Zeile "player.rotation.y = lerp_angle(...)" in
## spring_arm_camera.gd entfernt wurde.
@export var dreht_selbst: bool = false
## Nur wirksam bei dreht_selbst = an:
## "Bewegung"  = in die Eingaberichtung (beim Rückwärtslaufen dreht sie sich um)
## "Kamera"    = immer starr in Kamerarichtung
## "Kamera im Kampf" = Bewegung, schnappt beim Blocken/Schlagen in Kamerarichtung
@export_enum("Bewegung", "Kamera", "Kamera im Kampf") var blick_modus: int = 2
## Im Kameramodus ohne Verzögerung drehen. Ein Lerp würde bei schnellen
## Mausbewegungen sichtbar hinterherhinken.
@export var kamera_hart: bool = true
## Gibt zweimal pro Sekunde Kamera-, Wunsch- und Modellwinkel aus
@export var blick_debug: bool = false

@export_group("Proportionen")
## Höhe des Hüft-Drehpunkts über den Füßen (= Unterkante unterer Torso).
## Abstand zur Fußoberkante = huefte_hoehe - fuss_groesse.y. Klein halten,
## sonst schwebt der Rumpf sichtbar über den Füßen.
@export var huefte_hoehe: float = 0.26
@export var torso_unten_groesse: Vector3 = Vector3(0.50, 0.38, 0.32)
@export var torso_oben_groesse: Vector3 = Vector3(0.56, 0.42, 0.34)
@export var kopf_groesse: Vector3 = Vector3(0.62, 0.60, 0.58)
@export var kopf_luecke: float = 0.04          # Schwebeabstand Brust -> Kopf
@export var hand_groesse: Vector3 = Vector3(0.19, 0.19, 0.19)
@export var fuss_groesse: Vector3 = Vector3(0.21, 0.18, 0.27)
@export var hand_abstand: float = 0.36         # seitlicher Abstand der Hände
@export var hand_hoehe: float = 0.20           # Höhe über dem Brust-Drehpunkt
@export var fuss_abstand: float = 0.15

@export_group("Farben")
## Aus, wenn du eigene Materialien direkt an den MeshInstance3D hängst
@export var farben_anwenden: bool = true
@export var farbe_kopf: Color = Color(0.92, 0.76, 0.60)
@export var farbe_torso_oben: Color = Color(0.30, 0.48, 0.68)
@export var farbe_torso_unten: Color = Color(0.24, 0.26, 0.34)
@export var farbe_hand: Color = Color(0.92, 0.76, 0.60)
@export var farbe_fuss: Color = Color(0.32, 0.22, 0.16)

@export_group("Laufen")
@export var schritt_frequenz: float = 4.0      # Bogenmaß pro zurückgelegtem Meter
@export var referenz_tempo: float = 6.0        # Tempo für volle Amplitude (= walk_speed)
@export var schritt_weite: float = 0.25        # Ausschlag der Füße vor/zurück
@export var fuss_hub: float = 0.14             # wie hoch die Füße angehoben werden
@export var hub_versatz: float = 0.8           # verschiebt den Abdruckpunkt
@export var fuss_kipp: float = 0.30
@export var hand_schwung: float = 0.16
@export var koerper_hub: float = 0.04          # vertikales Wippen
@export var lauf_torso_dreh: float = 5.0       # Grad Gegenrotation im Laufrhythmus
@export var lauf_blend: float = 12.0

@export_group("Drehen und Neigen")
@export var dreh_tempo: float = 18.0           # wie schnell er der Blickrichtung folgt
@export var kurven_faktor: float = 0.06        # Neigung pro rad/s Drehgeschwindigkeit
@export var kurven_max: float = 12.0           # Grad, harte Obergrenze
## Drehraten darüber werden gekappt – sonst kippt er bei jedem Mausruck voll weg
@export var kurven_rate_max: float = 4.0       # rad/s
## Tiefpass auf die Drehrate: kleine Werte = träger, kurze Rucke wirken nicht mehr
@export var kurven_glaettung: float = 6.0
@export var neigung_tempo: float = 9.0
## Grad Vorwärtsneigung beim normalen Laufen
@export var vorlage: float = 8.0
## Zusätzliche Grad beim Sprinten, kommt oben auf 'vorlage' drauf
@export var vorlage_sprint: float = 7.0
## Zuschlag auf Kurvenneigung und Obergrenze beim Sprinten (0.10 = 10 % mehr)
@export var sprint_neigung_bonus: float = 0.10

@export_group("Ducken")
@export var pose_tempo: float = 12.0
@export var duck_huefte_absenkung: float = 0.20
@export var duck_huefte: float = 16.0          # Grad, unterer Torso beugt sich
@export var duck_brust: float = 14.0           # Grad, oberer Torso zusätzlich
@export var duck_kopf_ausgleich: float = 0.7   # Kopf schaut trotzdem geradeaus

@export_group("Springen")
## Grundanhebung, sobald die Figur den Boden verlässt
@export var luft_fuss_hoch: float = 0.06
## Beim Steigen zusätzlich anziehen (Knie gibt es nicht, die Füße gehen hoch)
@export var sprung_fuss_anziehen: float = 0.16
## Ein Fuß nach vorne, einer nach hinten – gibt dem Absprung Dynamik
@export var sprung_fuss_spreizen: float = 0.15
## Zehen beim Steigen anheben (Bogenmaß)
@export var sprung_fuss_kipp: float = 0.45
## Beim Fallen strecken sich die Füße wieder nach unten
@export var fall_fuss_strecken: float = 0.12
## Zehen beim Fallen nach unten, bereit zum Landen (Bogenmaß)
@export var fall_fuss_kipp: float = -0.32
## Steig-/Fallgeschwindigkeit in m/s für den vollen Ausschlag
@export var sprung_referenz_tempo: float = 6.0
## Wie schnell zwischen Steig- und Fallpose geblendet wird
@export var sprung_blend: float = 14.0
@export var luft_hand_hoch: float = 0.05

@export_group("Schwimmen")
@export var schwimm_tempo: float = 4.0         # Zugfrequenz (zeitbasiert)
@export var schwimm_hand: float = 0.16
@export var schwimm_fuss: float = 0.12
@export var schwimm_neigung: float = 72.0      # Grad: 90 = ganz flach
@export var schwimm_tempo_blend: float = 4.0   # wie schnell die Figur kippt
@export var schwimm_absenkung: float = -0.42   # Körper sinkt beim Kippen etwas

@export_group("Kampf")
@export var kampf_tempo: float = 16.0
## Grundreichweite eines Schlages. Die Stiltabelle rechnet in Vielfachen
## davon – hier drehst du also die Wucht aller Angriffe gemeinsam.
## ACHTUNG: die Posen in _stil_posen sind auf 0.50 hin körperfrei gerechnet.
## Wer das hochdreht, schiebt die Hände weiter und kann sie wieder in Kopf
## oder Brust fahren. Dann dort gegenrechnen, nicht hier.
@export var schlag_reichweite: float = 0.50
@export var schlag_rueckzug: float = 0.35      # Anteil des Ausholens nach hinten
@export var schlag_drehung: float = 18.0       # Grad Rumpfdrehung beim Schlag
@export var huefte_gegen: float = 0.35         # Hüfte dreht dagegen
@export var block_hand_vorne: float = 0.26
@export var block_hand_hoch: float = 0.16
## Aus = alle Waffen schlagen wie Fäuste (zum Vergleichen beim Einstellen)
@export var stil_posen_nutzen: bool = true

@export_group("Waffenhaltung")
## Aus = Halter bleiben auf rotation 0 und es gibt keine Ruhehaltung.
## Das ist exakt der Zustand vor dieser Erweiterung – zum Vergleichen.
@export var waffen_posen_nutzen: bool = true
## Wie schnell die Halterdrehung der Zielhaltung folgt. Höher = knackiger,
## zu hoch = der Waffenwechsel schnappt sichtbar um.
@export var halter_tempo: float = 18.0
## Wie schnell die Ruhehaltung beim Waffenwechsel überblendet.
@export var haltung_tempo: float = 8.0
## Fortschritt pro Sekunde, mit dem der Nachschwung nach dem Schlagende
## weiterläuft. Combat hat den Schlag da bereits beendet – hier läuft nur noch
## die Optik aus, damit die Hand nicht im selben Frame zurückspringt.
@export var nachschwung_tempo: float = 3.2
## Gibt einmal pro Sekunde aus, welche Waffe erkannt wurde, welcher Stil
## daraus folgt und wie der Halter gerade steht. Erste Anlaufstelle, wenn
## die Haltung sich nicht ändert: steht dort "Faust", kommt die Waffe gar
## nicht an – dann liegt es an der Ausruestung, nicht an dieser Datei.
@export var haltung_debug: bool = false

@export_subgroup("Mit Schild")
## Wie weit ein einhändiger Schlag noch über die Körpermitte zieht, wenn in
## der Nebenhand ein Schild steckt. 1.0 = wie ohne Schild, 0 = gar nicht.
## Kleine Werte halten Klinge und Schildfläche auseinander.
@export_range(0.0, 1.0) var schild_schlag_breite: float = 0.35
## Dasselbe für den Gierwinkel des Halters. Betrifft nur die Drehung nach
## links, nach rechts bleibt der Schwung voll erhalten.
@export_range(0.0, 1.0) var schild_schlag_gieren: float = 0.40

var _player: Akteur = null

var _neigung: Node3D
var _huefte: Node3D
var _brust: Node3D
var _kopf: Node3D
var _hand_l: Node3D
var _hand_r: Node3D
var _halter_l: Node3D
var _halter_r: Node3D
var _fuss_l: Node3D
var _fuss_r: Node3D
var _m_torso_u: MeshInstance3D
var _m_torso_o: MeshInstance3D
var _m_kopf: MeshInstance3D
var _m_hand_l: MeshInstance3D
var _m_hand_r: MeshInstance3D
var _m_fuss_l: MeshInstance3D
var _m_fuss_r: MeshInstance3D

var _hand_ruhe_l: Vector3 = Vector3.ZERO
var _hand_ruhe_r: Vector3 = Vector3.ZERO
var _fuss_ruhe_l: Vector3 = Vector3.ZERO
var _fuss_ruhe_r: Vector3 = Vector3.ZERO

var _phase := 0.0                               # Laufphase (streckenbasiert)
var _schwimm_phase := 0.0                       # Zugphase (zeitbasiert)
var _zeit := 0.0
var _ziel_yaw := 0.0
var _letzter_yaw := 0.0                         # rotation.y des Vorframes
var _dreh_rate := 0.0                           # geglättete Drehgeschwindigkeit
var _debug_timer := 0.0
var _pitch := 0.0
var _roll := 0.0
var _lauf_gewicht := 0.0                        # 0 = steht, 1 = läuft
var _luft_blend := 0.0                          # 0 = am Boden, 1 = in der Luft
var _steig_blend := 0.0                         # +1 = steigt, -1 = fällt
var _wasser_blend := 0.0                        # 0 = an Land, 1 = im Wasser
var _neige_blend := 0.0                         # eigener, langsamerer Blend
var _duck_blend := 0.0                          # 0 = aufrecht, 1 = geduckt
var _sprint_blend := 0.0                        # 0 = geht, 1 = sprintet
var _block_blend := 0.0                         # 0 = offen, 1 = Deckung
var _angriff_blend := 0.0                       # 0 = kein Schlag, 1 = Schlag
var _schlag_links := false
var _ruhe_pos_y := 0.0

# Werte des laufenden Schlages. Werden beim Start übernommen und bis zum
# Ausblenden gehalten – Combat setzt seine Waffe am Schlagende auf null,
# die Rückholbewegung braucht die Pose aber noch.
var _schlag_stil: int = 0
var _schlag_m1: float = 0.30
var _schlag_m2: float = 0.48

# Eigener Fortschritt NUR für den Nachschwung. Während 'ist_am_angreifen' wird
# er hart aus Combat übernommen – dort und nur dort entsteht das Timing. Erst
# wenn Combat den Schlag beendet hat, läuft er selbst bis 1.0 weiter, damit die
# Hand den letzten Teil der Kurve noch abfährt statt zurückzuschnappen.
var _schlag_fortschritt := 1.0

# Geglättete Ruhehaltung. Beim Waffenwechsel wandern diese Werte auf die neue
# Zielhaltung, deshalb schnappt nichts um.
var _haltung_versatz: Vector3 = Vector3.ZERO    # Meter, Versatz der Waffenhand
var _haltung_schwung: float = 1.0               # Faktor auf den Handschwung
var _halter_akt_r: Vector3 = Vector3.ZERO       # Bogenmaß
var _halter_akt_l: Vector3 = Vector3.ZERO       # Bogenmaß
var _schild_blend := 0.0                        # 0 = kein Schild, 1 = Schild
var _waffen_blend := 0.0                        # 0 = bloße Fäuste, 1 = Waffe

var _stil_posen: Dictionary = {}
var _halter_gewarnt := false

# Die Ausruestung, nicht Combat, ist die Quelle für "was hält die Figur
# gerade". Combat weiß über den Stil nur, was es für den laufenden Schlag
# braucht – im Stand ist das unter Umständen gar nichts. Siehe _ruhe_waffe().
var _ausruestung: Ausruestung = null
var _haltung_debug_timer := 0.0
var _halter_erster_frame := true


func _init() -> void:
	# ---------------------------------------------------------------------
	# Bezugsrahmen: alles im Raum von "Brust", die Hand ruht bei
	# (±0.36, 0.20, 0), der Halter sitzt 0.12 davor.
	#
	#   +X = nach rechts    +Y = nach oben    -Z = nach vorne
	#
	# Die Körperteile, an denen man hängen bleibt:
	#
	#   Brustkasten   x ±0.28   y  0.00 .. 0.42   z ±0.17
	#   Kopf          x ±0.31   y  0.46 .. 1.06   z ±0.29
	#   Hüfte         x ±0.25   y -0.38 .. 0.00   z ±0.16
	#
	# Jede Pose unten ist gegen diese drei Kästen geprüft: Hand plus Klinge
	# müssen daran vorbeigehen. Ab dem Halter gemessen ist die Klinge beim
	# Kurzschwert 0.79 lang, beim Zweihänder 1.27, beim Speer 1.63.
	#
	# ---------------------------------------------------------------------
	# HALTERWINKEL, und warum sie so aussehen:
	#
	# Bei rotation 0 zeigt die Waffe nach -Z. Godots Vorgabereihenfolge ist
	# YXZ, also gilt:
	#
	#   Z (Rollen)  dreht die Waffe um ihre EIGENE Längsachse. Ändert die
	#               Richtung nicht, nur welche Kante vorangeht.
	#   X (Nicken)  richtet sie auf:  +72 = schräg hoch,  +95 = senkrecht,
	#               -40 = schräg runter.
	#   Y (Gieren)  schwenkt waagerecht:  negativ = nach rechts.
	#
	# Rollen ist kein Gestaltungsmittel, sondern eine Achsenkorrektur – es
	# gleicht aus, wie die Waffe im Mesh liegt:
	#
	#   Axt          120  – Kopf steht im Mesh in +Y ab und zeigte nach hinten
	#   Zweihänder    90  – Klinge ist im Mesh in Y dünn statt in X
	#   Kurzschwert    0  – Stoßwaffe, die Kante ist nicht führend
	#   Speer          0  – dito
	#
	# Für einen GIERSCHWUNG lässt sich der ideale Rollwinkel ausrechnen. Die
	# Bewegungsrichtung des Waffenkopfes ist dabei (-cos y, 0, sin y). Bildet
	# man das Skalarprodukt mit der dünnen Achse des Blattes, kürzt sich alles
	# bis auf -cos(z) – Nick- und Gierwinkel fallen vollständig heraus. Die
	# Schneide geht also genau bei z = 90 oder z = 270 voran; jeder Wert
	# dazwischen dreht sie anteilig auf die Flachseite, 180 stellt sie quer.
	#
	# Die Axt steht trotzdem auf 120 und nicht auf 90: bei 90 zeigt der Kopf
	# 50 Grad nach links und sieht falsch aus. 120 kostet 30 Grad Schräge beim
	# Schnitt und ist dafür sichtbar richtig herum. Beides zugleich gäbe es
	# nur mit einem geänderten Mesh.
	#
	# Beide Korrekturen gehören eigentlich ins Mesh (Axtkopf auf y = -0.10 und
	# Blatt in Z dünn, Zweihänderklinge als (0.04, 0.13, 1.10)). Solange die
	# Meshes so sind, stehen sie hier – dann muss nichts neu erzeugt werden.
	#
	# Damit die Schneide vorangeht, muss die dünne Achse der Klinge senkrecht
	# auf der Schwungebene stehen:
	#
	#   Zweihänder  schwingt senkrecht (Ebene Y/Z) -> nur X-Winkel ändern
	#   Axt         schwingt waagerecht (Ebene X/Z) -> nur Y-Winkel ändern
	#   Stich und Stange stoßen geradeaus -> alle Winkel klein
	#
	# Ein Gierwinkel wirkt umso weniger, je senkrechter die Waffe steht: bei
	# 80 Grad Nicken ist der waagerechte Anteil nur noch cos(80) = 0.17. Wer
	# eine aufrechte Waffe nach außen kippen will, muss also den NICKwinkel
	# senken, nicht den Gierwinkel erhöhen.
	#
	# ---------------------------------------------------------------------
	# Die vier Haltungen je Stil:
	#
	#   halter_ruhe      getragen, wenn nichts passiert
	#   halter_block     in Deckung  – legt sich über die Ruhehaltung
	#   halter_ausholen  Umkehrpunkt des Ausholens
	#   halter_treffer   Ende des Durchziehens
	#
	# ausholen_pos / treffer_pos sind Versätze auf die Ruhelage der HAND, in
	# Vielfachen von 'schlag_reichweite'. ausholen_rot / treffer_rot sind bei
	# allen Waffenstilen null – siehe Kopfkommentar der Datei.
	_stil_posen = {
		# Gerader Fausthieb, Hand zieht kurz zurück und schnellt zur Mitte.
		# Der einzige Stil, der die Hand selbst dreht: es gibt keine Waffe,
		# deren Ausrichtung dadurch verzogen würde.
		WaffenDaten.Stil.FAUST: {
			"beide_haende": false,
			"ruhe_pos": Vector3.ZERO,
			"ruhe_schwung": 1.0,
			"halter_ruhe": Vector3.ZERO,
			"halter_block": Vector3.ZERO,
			"halter_ausholen": Vector3.ZERO,
			"halter_treffer": Vector3.ZERO,
			"zweithand_versatz": Vector3.ZERO,
			"ausholen_pos": Vector3(0.10, 0.06, 0.30),
			"ausholen_rot": Vector3(14.0, 0.0, 0.0),
			"treffer_pos": Vector3(-0.32, 0.06, -1.00),
			"treffer_rot": Vector3(-20.0, 0.0, 0.0),
			"torso_yaw": 1.0,
			"torso_pitch": 0.0,
		},
		# Kurzschwert. Getragen rechts neben dem Körper, Hand auf x = 0.40 –
		# 12 cm neben dem Brustkasten (x ±0.28), die Handwürfel-Innenkante
		# bleibt 2.5 cm frei. Näher geht nicht, ohne dass die Hand im Torso
		# steckt.
		#
		# Der Kopf (x ±0.31) wird nicht über Abstand freigehalten, sondern
		# über die Neigung: bei 62 Grad Nicken statt 72 hat die Klinge genug
		# waagerechten Anteil, um nach außen wegzulaufen. Die Spitze steht
		# bei (0.66, 0.92, -0.36), und x wächst über die ganze Länge – sie
		# kann den Kopf also gar nicht kreuzen.
		#
		# In Deckung legt sich die Klinge quer vor den Körper: 55 Grad Nicken
		# plus 45 Grad Gieren nach links, Spitze bei (-0.07, 1.01, -0.70) –
		# vor der Brust, aber 40 cm vor dem Gesicht.
		WaffenDaten.Stil.STICH: {
			"beide_haende": false,
			"ruhe_pos": Vector3(0.04, 0.00, 0.02),
			"ruhe_schwung": 0.55,
			"halter_ruhe": Vector3(62.0, -45.0, 0.0),
			"halter_block": Vector3(55.0, 45.0, 0.0),
			"halter_ausholen": Vector3(25.0, -20.0, 0.0),
			"halter_treffer": Vector3(5.0, -6.0, 0.0),
			"zweithand_versatz": Vector3.ZERO,
			"ausholen_pos": Vector3(-0.10, 0.06, 0.46),
			"ausholen_rot": Vector3.ZERO,
			"treffer_pos": Vector3(-0.40, 0.06, -1.20),
			"treffer_rot": Vector3.ZERO,
			"torso_yaw": 1.1,
			"torso_pitch": 0.0,
		},
		# Axt. Zwei Dinge stecken hier drin.
		#
		# ROLLE 120: Der Axtkopf steht im Mesh bei (0, 0.10, -0.46), also in
		# +Y vom Stiel ab. Ohne Rolle wandert dieses +Y beim Aufrichten nach
		# hinten und der Kopf zeigt auf den Spieler. Bei 120 steht er auf
		# (-0.37, -0.20, -0.91) – nach vorn, rund 20 Grad nach links versetzt.
		#
		# Der Wert ist ein bewusster Kompromiss. Sauber schneidet die Axt nur
		# bei 90 oder 270: Bei einem Gierschwung ist die Bewegungsrichtung des
		# Kopfes (-cos y, 0, sin y), und das Skalarprodukt mit der dünnen
		# Achse des Blattes kürzt sich vollständig auf -cos(z). Nick- und
		# Gierwinkel fallen heraus, es zählt allein der Rollwinkel. Bei 90 ist
		# das Produkt null, die Schneide geht voran – der Kopf zeigt dann aber
		# 50 Grad nach links und sieht falsch aus. Bei 120 beträgt das Produkt
		# 0.5, das Blatt trifft also unter 30 Grad Schräge statt flächig.
		# Sichtbar besser, rechnerisch nicht ideal.
		#
		# Wer es genau haben will, ändert das Mesh: Axtkopf auf y = -0.10 und
		# das Blatt in Z statt in X dünn. Dann stimmt beides bei z = 0.
		#
		# SCHWUNG: Der Schlag läuft über den Gierwinkel, -70 (hinten rechts)
		# auf +55 (vorne links). Nicken bleibt flach.
		#
		# Hand auf x = 0.42, Kopf bei (0.50, 0.62, -0.34), Schneidenspitze bei
		# (0.48, 0.68, -0.50) – beides frei vom Kopf (x ±0.31).
		WaffenDaten.Stil.HIEB: {
			"beide_haende": false,
			"ruhe_pos": Vector3(0.06, 0.00, 0.04),
			"ruhe_schwung": 0.50,
			"halter_ruhe": Vector3(66.0, -40.0, 120.0),
			"halter_block": Vector3(50.0, 40.0, 120.0),
			"halter_ausholen": Vector3(30.0, -70.0, 120.0),
			"halter_treffer": Vector3(18.0, 55.0, 120.0),
			"zweithand_versatz": Vector3.ZERO,
			"ausholen_pos": Vector3(0.26, 0.30, 0.12),
			"ausholen_rot": Vector3.ZERO,
			"treffer_pos": Vector3(-0.64, 0.00, -0.88),
			"treffer_rot": Vector3.ZERO,
			"torso_yaw": 1.45,
			"torso_pitch": 0.0,
		},
		# Zweihänder, beidhändig, senkrechter Hieb von oben.
		#
		# ROLLE 90: Die Klinge ist im Mesh (0.13, 0.04, 1.10) – 13 cm breit in
		# X, 4 cm dünn in Y. Die Flachseiten zeigen damit nach oben und unten,
		# die Schneiden nach links und rechts. Bei einem SENKRECHTEN Hieb
		# bewegt sich die Klinge aber nach unten, also fällt die Flachseite
		# auf den Gegner. Die 90 Grad Rolle stellt die dünne Achse von Y auf
		# X – dann steht sie senkrecht auf der Schwungebene und die Schneide
		# geht voran.
		# (Die saubere Lösung wäre, die Klinge im Mesh als (0.04, 0.13, 1.10)
		# zu bauen; dann fiele die Rolle weg. Solange die Meshes so sind,
		# gleicht die Rolle es aus.)
		#
		# Getragen senkrecht rechts neben dem Körper, beide Hände am Griff:
		# die rechte bei (0.46, 0.16, 0.06), die linke folgt über
		# zweithand_versatz 20 cm tiefer am Schaft. Rollen um die Längsachse
		# ändert diesen Versatz nicht – (0,0,z) liegt auf der Rollachse.
		#
		# Das Ausholen ist der kritische Fall. Die Hand geht NACH VORNE und
		# hoch, nicht über den Kopf: bei (0.16, 0.62, -0.48) und 95 Grad
		# Nicken steht die Klinge senkrecht vor dem Gesicht und liegt auf
		# Kopfhöhe (y = 1.06) bei z = -0.56. Vorher waren es -0.36, und durch
		# die Rolle ragt die 13 cm breite Klinge jetzt nach vorn und hinten
		# statt zur Seite – 6.5 cm davon hätten die Stirn (z = -0.29)
		# gestreift. Deshalb steht die Hand 8 cm weiter vorn als zuvor.
		WaffenDaten.Stil.SCHWUNG_SCHWER: {
			"beide_haende": true,
			"ruhe_pos": Vector3(0.10, -0.04, 0.06),
			"ruhe_schwung": 0.25,
			"halter_ruhe": Vector3(78.0, -30.0, 90.0),
			"halter_block": Vector3(60.0, 30.0, 90.0),
			"halter_ausholen": Vector3(95.0, -10.0, 90.0),
			"halter_treffer": Vector3(-40.0, 0.0, 90.0),
			"zweithand_versatz": Vector3(0.0, 0.0, 0.20),
			"ausholen_pos": Vector3(-0.60, 0.92, -1.08),
			"ausholen_rot": Vector3.ZERO,
			"treffer_pos": Vector3(-0.64, -0.22, -1.22),
			"treffer_rot": Vector3.ZERO,
			"torso_yaw": 0.4,
			"torso_pitch": 1.2,
		},
		# Speer, beidhändig. Getragen fast senkrecht rechts neben dem Körper,
		# beide Hände am Schaft mit 30 cm Abstand. Das untere Ende steht bei
		# (0.46, -0.07, -0.04) und damit neben der Hüfte (x ±0.25), nicht
		# darin. Zum Stoß legt er sich waagerecht.
		WaffenDaten.Stil.STANGE: {
			"beide_haende": true,
			"ruhe_pos": Vector3(0.12, -0.02, 0.04),
			"ruhe_schwung": 0.30,
			"halter_ruhe": Vector3(80.0, -25.0, 0.0),
			"halter_block": Vector3(30.0, 55.0, 0.0),
			"halter_ausholen": Vector3(12.0, -10.0, 0.0),
			"halter_treffer": Vector3(4.0, -6.0, 0.0),
			"zweithand_versatz": Vector3(0.0, 0.0, 0.30),
			"ausholen_pos": Vector3(-0.56, 0.08, 0.48),
			"ausholen_rot": Vector3.ZERO,
			"treffer_pos": Vector3(-0.52, 0.04, -0.96),
			"treffer_rot": Vector3.ZERO,
			"torso_yaw": 0.6,
			"torso_pitch": 0.0,
		},
	}


# Haltung der Schildhand. Kein Stil-Eintrag, weil aktiver_stil() die HAUPThand
# beschreibt – ein Schild in der Nebenhand hat damit nichts zu tun.
#
# X ist negativ, damit das Schild zur Körpermitte wandert statt nach außen: es
# soll ja etwas decken. Gespiegelt landet die linke Hand bei x = -0.28, das
# Schild (0.52 breit) deckt damit die linke Körperhälfte von vorne ab.
const SCHILD_RUHE_POS := Vector3(-0.08, 0.02, -0.18)
const SCHILD_RUHE_HALTER := Vector3(-8.0, -18.0, 0.0)
# In Deckung steht die Schildfläche flach nach vorn – bei rotation 0 zeigt
# ihre Normale nach -Z, also genügen ein paar Grad Gieren zur Mitte hin.
const SCHILD_BLOCK_HALTER := Vector3(0.0, -6.0, 0.0)
const SCHILD_BLOCK_VORNE := 0.16
const SCHILD_SCHWUNG := 0.15

# Versatz des Halters unter der Hand, aus koerper.tscn. Wird gebraucht, um die
# zweite Hand auf den Schaft zu setzen.
const HALTER_VERSATZ := Vector3(0.0, 0.0, -0.12)


func _ready() -> void:
	_player = get_node_or_null(player_path) as Akteur

	_neigung = get_node_or_null(^"Neigung") as Node3D
	_huefte = get_node_or_null(^"Neigung/Huefte") as Node3D
	_brust = get_node_or_null(^"Neigung/Huefte/Brust") as Node3D
	_kopf = get_node_or_null(^"Neigung/Huefte/Brust/Kopf") as Node3D
	_hand_l = get_node_or_null(^"Neigung/Huefte/Brust/HandLinks") as Node3D
	_hand_r = get_node_or_null(^"Neigung/Huefte/Brust/HandRechts") as Node3D
	_halter_l = get_node_or_null(^"Neigung/Huefte/Brust/HandLinks/HalterLinks") as Node3D
	_halter_r = get_node_or_null(^"Neigung/Huefte/Brust/HandRechts/HalterRechts") as Node3D
	_fuss_l = get_node_or_null(^"Neigung/FussLinks") as Node3D
	_fuss_r = get_node_or_null(^"Neigung/FussRechts") as Node3D

	_m_torso_u = get_node_or_null(^"Neigung/Huefte/TorsoUnten") as MeshInstance3D
	_m_torso_o = get_node_or_null(^"Neigung/Huefte/Brust/TorsoOben") as MeshInstance3D
	_m_kopf = get_node_or_null(^"Neigung/Huefte/Brust/Kopf/KopfMesh") as MeshInstance3D
	_m_hand_l = get_node_or_null(^"Neigung/Huefte/Brust/HandLinks/HandLinksMesh") as MeshInstance3D
	_m_hand_r = get_node_or_null(^"Neigung/Huefte/Brust/HandRechts/HandRechtsMesh") as MeshInstance3D
	_m_fuss_l = get_node_or_null(^"Neigung/FussLinks/FussLinksMesh") as MeshInstance3D
	_m_fuss_r = get_node_or_null(^"Neigung/FussRechts/FussRechtsMesh") as MeshInstance3D

	var fehlt: Array[String] = []
	for eintrag in [
		["Neigung", _neigung], ["Huefte", _huefte], ["Brust", _brust],
		["Kopf", _kopf], ["HandLinks", _hand_l], ["HandRechts", _hand_r],
		["FussLinks", _fuss_l], ["FussRechts", _fuss_r],
		["TorsoUnten", _m_torso_u], ["TorsoOben", _m_torso_o],
		["KopfMesh", _m_kopf], ["HandLinksMesh", _m_hand_l],
		["HandRechtsMesh", _m_hand_r], ["FussLinksMesh", _m_fuss_l],
		["FussRechtsMesh", _m_fuss_r],
	]:
		if eintrag[1] == null:
			fehlt.append(str(eintrag[0]))

	if not fehlt.is_empty():
		push_error("CharacterVisual: fehlende Knoten -> " + ", ".join(fehlt))
		set_process(false)
		return

	# Die Halter sind optional: ein NPC ohne Waffen braucht sie nicht. Fehlen
	# sie, entfällt nur die Waffenausrichtung, alles andere läuft weiter.
	if (_halter_l == null or _halter_r == null) and not _halter_gewarnt:
		_halter_gewarnt = true
		push_warning("CharacterVisual: HalterLinks/HalterRechts fehlen – "
				+ "Waffen werden nicht ausgerichtet.")

	if _player == null:
		push_error("CharacterVisual: Akteur nicht gefunden (player_path prüfen)")
		set_process(false)
		return

	_ruhe_pos_y = position.y
	_ziel_yaw = global_rotation.y
	_letzter_yaw = global_rotation.y

	# Ausruestung liegt als Geschwister neben "Visual" unter dem Akteur.
	# Kein Pflichtfeld: eine Figur ohne Ausruestung läuft weiter, sie hält
	# dann eben nichts.
	_ausruestung = _player.get_node_or_null(^"Ausruestung") as Ausruestung
	if _ausruestung == null:
		_ausruestung = _player.find_child("Ausruestung", true, false) as Ausruestung
	if _ausruestung == null:
		push_warning("CharacterVisual: keine Ausruestung gefunden – "
				+ "Waffenhaltung bleibt auf Faust.")

	baue_proportionen()


# Setzt alle Meshgrößen und Ruhepositionen aus den Export-Werten.
# Kann jederzeit erneut gerufen werden, wenn du Proportionen änderst.
func baue_proportionen() -> void:
	_huefte.position = Vector3(0.0, huefte_hoehe, 0.0)
	_setze_box(_m_torso_u, torso_unten_groesse,
			Vector3(0.0, torso_unten_groesse.y * 0.5, 0.0), farbe_torso_unten)

	_brust.position = Vector3(0.0, torso_unten_groesse.y, 0.0)
	_setze_box(_m_torso_o, torso_oben_groesse,
			Vector3(0.0, torso_oben_groesse.y * 0.5, 0.0), farbe_torso_oben)

	_kopf.position = Vector3(0.0, torso_oben_groesse.y + kopf_luecke, 0.0)
	_setze_box(_m_kopf, kopf_groesse, Vector3(0.0, kopf_groesse.y * 0.5, 0.0), farbe_kopf)

	_hand_ruhe_l = Vector3(-hand_abstand, hand_hoehe, 0.0)
	_hand_ruhe_r = Vector3(hand_abstand, hand_hoehe, 0.0)
	_hand_l.position = _hand_ruhe_l
	_hand_r.position = _hand_ruhe_r
	_setze_box(_m_hand_l, hand_groesse, Vector3.ZERO, farbe_hand)
	_setze_box(_m_hand_r, hand_groesse, Vector3.ZERO, farbe_hand)

	_fuss_ruhe_l = Vector3(-fuss_abstand, fuss_groesse.y * 0.5, 0.0)
	_fuss_ruhe_r = Vector3(fuss_abstand, fuss_groesse.y * 0.5, 0.0)
	_fuss_l.position = _fuss_ruhe_l
	_fuss_r.position = _fuss_ruhe_r
	_setze_box(_m_fuss_l, fuss_groesse, Vector3.ZERO, farbe_fuss)
	_setze_box(_m_fuss_r, fuss_groesse, Vector3.ZERO, farbe_fuss)


# Gesamthöhe der Figur in Metern – Bezugsgröße für Kapsel und Kamera.
func hole_gesamt_hoehe() -> float:
	return huefte_hoehe + torso_unten_groesse.y + torso_oben_groesse.y \
			+ kopf_luecke + kopf_groesse.y


# Hand-Drehpunkt, an den später Waffen gehängt werden.
func hole_hand(links: bool) -> Node3D:
	return _hand_l if links else _hand_r


# Waffenhalter unter der Hand. ausruestung.gd findet sie zwar selbst über
# find_child, aber wer sie hier abfragt, bekommt sie ohne Namenssuche.
func hole_halter(links: bool) -> Node3D:
	return _halter_l if links else _halter_r


func _process(delta: float) -> void:
	if _player == null:
		return

	_zeit += delta
	var w: float = 1.0 - exp(-pose_tempo * delta)
	var kw: float = 1.0 - exp(-kampf_tempo * delta)
	var hw: float = 1.0 - exp(-haltung_tempo * delta)
	var lw: float = 1.0 - exp(-halter_tempo * delta)
	var schwimmt: bool = _player.is_swimming
	var kampf: Combat = _player.combat

	var v: Vector3 = _player.velocity
	var hor: Vector3 = Vector3(v.x, 0.0, v.z)
	var tempo: float = hor.length()
	var tempo_n: float = clampf(tempo / maxf(referenz_tempo, 0.01), 0.0, 1.3)

	# ---------------------------------------------------------- Zustandsblends
	_wasser_blend = lerpf(_wasser_blend, 1.0 if schwimmt else 0.0, w)

	# Körperneigung im Wasser bewusst NICHT an is_on_floor() gekoppelt: Wer auf
	# dem Grund eines tiefen Sees ankommt, soll weiter waagerecht schwimmen.
	_neige_blend = lerpf(_neige_blend, 1.0 if schwimmt else 0.0,
			1.0 - exp(-schwimm_tempo_blend * delta))

	var duck_ziel: float = 1.0 if (_player.is_sneaking and not schwimmt) else 0.0
	_duck_blend = lerpf(_duck_blend, duck_ziel, w)

	var sprint_ziel: float = 1.0 if (_player.is_sprinting and not schwimmt) else 0.0
	_sprint_blend = lerpf(_sprint_blend, sprint_ziel, w)

	var luft_ziel: float = 0.0
	if not _player.is_on_floor() and not schwimmt and not _player.is_climbing:
		luft_ziel = 1.0
	_luft_blend = lerpf(_luft_blend, luft_ziel, w)

	# ---------------------------------------------------------- Blickrichtung
	# WICHTIG: Grundlage ist die Eingaberichtung, nicht velocity. Die
	# Geschwindigkeit hinkt durch ground_accel spürbar hinterher und zieht beim
	# Kameraschwenk einen weiten Bogen – das Modell würde dabei sichtbar in eine
	# andere Richtung schauen als die Kamera.
	var wunsch: Vector3 = _player.wunsch_richtung
	var kamera_yaw: float = 0.0
	if _player.camera_pivot != null:
		kamera_yaw = _player.camera_pivot.global_rotation.y

	var kampf_aktiv: bool = kampf != null \
			and (kampf.ist_am_blocken or kampf.ist_am_angreifen)

	var hart: bool = false
	match blick_modus:
		1:                                       # immer Kamera
			_ziel_yaw = kamera_yaw
			hart = kamera_hart
		2:                                       # Kamera nur im Kampf
			if kampf_aktiv:
				_ziel_yaw = kamera_yaw
				hart = kamera_hart
			elif wunsch.length_squared() > 0.01:
				_ziel_yaw = atan2(-wunsch.x, -wunsch.z)
		_:                                       # Eingaberichtung
			if wunsch.length_squared() > 0.01:
				_ziel_yaw = atan2(-wunsch.x, -wunsch.z)

	# Bewusst global_rotation statt rotation: Der Player-Knoten wird von
	# spring_arm_camera.gd selbst gedreht. Eine lokale Drehung würde sich zu
	# dessen Drehung addieren – die Figur würde sich doppelt so weit drehen.
	if dreht_selbst:
		if hart:
			global_rotation.y = _ziel_yaw
		else:
			global_rotation.y = lerp_angle(global_rotation.y, _ziel_yaw,
					1.0 - exp(-dreh_tempo * delta))

	# Drehrate aus der tatsächlichen Weltausrichtung messen, nicht aus der
	# eigenen Vorgabe. Dreht ein anderes Skript den Player (dreht_selbst = aus),
	# bleibt die lokale rotation.y konstant 0 – lokal messen ergäbe also nie
	# eine Kurvenneigung.
	var welt_yaw: float = global_rotation.y
	var roh_rate: float = angle_difference(_letzter_yaw, welt_yaw) \
			/ maxf(delta, 0.0001)
	_letzter_yaw = welt_yaw

	if blick_debug:
		_debug_timer -= delta
		if _debug_timer <= 0.0:
			_debug_timer = 0.5
			var wunsch_grad: float = 999.0
			if wunsch.length_squared() > 0.01:
				wunsch_grad = rad_to_deg(atan2(-wunsch.x, -wunsch.z))
			print("[Blick] Kamera %.1f | Wunsch %.1f | Modell %.1f" % [
					rad_to_deg(kamera_yaw), wunsch_grad, rad_to_deg(welt_yaw)])

	# Rate kappen und tiefpassfiltern: ein kurzer Mausruck erzeugt sonst sofort
	# die volle Kurvenneigung, obwohl die Figur gar keine Kurve läuft.
	var grenz_rate: float = maxf(kurven_rate_max, 0.01)
	_dreh_rate = lerpf(_dreh_rate, clampf(roh_rate, -grenz_rate, grenz_rate),
			1.0 - exp(-kurven_glaettung * delta))

	position.y = _ruhe_pos_y

	# ------------------------------------------------- Kurvenneigung + Vorlage
	# Beim Sprinten legt sie sich etwas stärker in die Kurve – Faktor wirkt auf
	# Ausschlag UND Obergrenze, sonst würde der Clamp den Bonus wegschneiden.
	var sprint_faktor: float = 1.0 + sprint_neigung_bonus * _sprint_blend
	var grenze: float = deg_to_rad(kurven_max) * sprint_faktor
	var flach: float = clampf(tempo_n, 0.0, 1.0) * (1.0 - _neige_blend)
	var ziel_roll: float = clampf(_dreh_rate * kurven_faktor * sprint_faktor,
			-grenze, grenze) * flach
	# Vorlage: Grundwert beim Laufen, beim Sprinten kommt vorlage_sprint dazu
	var ziel_pitch: float = -deg_to_rad(vorlage + vorlage_sprint * _sprint_blend) * flach
	var nf: float = 1.0 - exp(-neigung_tempo * delta)
	_roll = lerpf(_roll, ziel_roll, nf)
	_pitch = lerpf(_pitch, ziel_pitch, nf)

	# Schwimmneigung kommt ungefiltert dazu, sie hat ihren eigenen Blend
	var schwimm_kipp: float = deg_to_rad(schwimm_neigung) * _neige_blend
	_neigung.rotation = Vector3(_pitch - schwimm_kipp, 0.0, _roll)

	# ------------------------------------------------ Laufphase über Strecke
	var am_boden: bool = _player.is_on_floor() or _player.is_climbing
	var laufend: bool = am_boden and tempo > 0.15 and not schwimmt
	_lauf_gewicht = lerpf(_lauf_gewicht, 1.0 if laufend else 0.0,
			1.0 - exp(-lauf_blend * delta))
	if laufend:
		_phase = fposmod(_phase + tempo * delta * schritt_frequenz, TAU)
	_schwimm_phase += schwimm_tempo * delta

	_neigung.position.y = -absf(sin(_phase)) * koerper_hub * _lauf_gewicht \
			+ schwimm_absenkung * _neige_blend

	# ---------------------------------------------------------- Kampfzustände
	var blockt: bool = kampf != null and kampf.ist_am_blocken
	_block_blend = lerpf(_block_blend, 1.0 if blockt else 0.0, kw)

	# Der Schlag blendet hart ein (damit er knackig wirkt) und weich aus.
	# Stil und Marken werden dabei mitgenommen: Combat setzt seine Waffe am
	# Schlagende auf null, das Zurückholen braucht die Pose aber noch.
	if kampf != null and kampf.ist_am_angreifen:
		_angriff_blend = 1.0
		_schlag_links = kampf.hand_links
		# Timing kommt hier und nur hier her.
		_schlag_fortschritt = kampf.angriff_fortschritt
		if stil_posen_nutzen:
			# Dieselbe Quelle wie die Ruhehaltung, sonst könnten Schlagpose
			# und Ruhepose auseinanderlaufen. Combat bleibt der Rückfall –
			# es besitzt weiterhin Timing und Schaden, nur nicht die Frage,
			# welche Waffe in der Hand steckt.
			var schlag_waffe: WaffenDaten = _ruhe_waffe()
			_schlag_stil = schlag_waffe.stil if schlag_waffe != null \
					else kampf.aktiver_stil()
			var marken: Vector2 = kampf.schlag_marken()
			_schlag_m1 = marken.x
			_schlag_m2 = marken.y
		else:
			_schlag_stil = WaffenDaten.Stil.FAUST
			_schlag_m1 = 0.30
			_schlag_m2 = 0.48
	else:
		# Nachschwung. Combat hat den Schlag beendet und angriff_fortschritt
		# zurückgesetzt – würde man weiter von dort lesen, stünde die Hand im
		# selben Frame wieder in Ruhelage. Das war das sichtbare Zucken am
		# Schlagende. Hier läuft nur die Optik aus, das Trefferfenster ist
		# längst vorbei.
		_schlag_fortschritt = minf(_schlag_fortschritt
				+ delta * nachschwung_tempo, 1.0)
		_angriff_blend = lerpf(_angriff_blend, 0.0, kw)

	var kurve: float = 0.0
	if _angriff_blend > 0.001:
		kurve = _schlag_kurve(_schlag_fortschritt, _schlag_m1, _schlag_m2) \
				* _angriff_blend

	var pose: Dictionary = _stil_posen.get(_schlag_stil,
			_stil_posen[WaffenDaten.Stil.FAUST])

	# ------------------------------------------------------ Torso: zwei Teile
	# Negative Werte um X beugen nach vorne (positiv würde nach hinten kippen).
	var huefte_pitch: float = -deg_to_rad(duck_huefte) * _duck_blend
	var brust_pitch: float = -deg_to_rad(duck_brust) * _duck_blend

	# Beidhändige Stile drehen den Rumpf kaum, dafür kippt er nach vorne –
	# ein Zweihänder wird aus dem Rücken geschlagen, nicht aus der Schulter.
	brust_pitch += -deg_to_rad(schlag_drehung) * kurve * float(pose["torso_pitch"])

	var seite: float = -1.0 if _schlag_links else 1.0
	if bool(pose["beide_haende"]):
		seite = 1.0
	var schlag_yaw: float = deg_to_rad(schlag_drehung) * kurve * seite \
			* float(pose["torso_yaw"])
	var lauf_yaw: float = sin(_phase) * deg_to_rad(lauf_torso_dreh) \
			* _lauf_gewicht * clampf(tempo_n, 0.0, 1.0)

	var brust_yaw: float = schlag_yaw - lauf_yaw
	var huefte_yaw: float = -schlag_yaw * huefte_gegen + lauf_yaw * 0.5

	_huefte.position.y = huefte_hoehe - duck_huefte_absenkung * _duck_blend
	_huefte.rotation = Vector3(huefte_pitch, huefte_yaw, 0.0)
	_brust.rotation = Vector3(brust_pitch, brust_yaw, 0.0)

	# ------------------------------------------------------------------- Kopf
	# Gleicht die Rumpfneigung teilweise aus, damit der Blick nach vorne bleibt.
	_kopf.rotation = Vector3(
			-(_pitch + huefte_pitch + brust_pitch) * duck_kopf_ausgleich
					+ schwimm_kipp * 0.55,
			-(brust_yaw + huefte_yaw) * 0.5,
			-_roll * duck_kopf_ausgleich)

	# ------------------------------------------------------------------ Füße
	var gew: float = _lauf_gewicht * clampf(tempo_n, 0.0, 1.3)
	var amp: float = schritt_weite * gew
	var hub: float = fuss_hub * gew
	var fuss_wasser: float = sin(_schwimm_phase * 1.5) * schwimm_fuss * _wasser_blend

	# Sprungpose: In der Luft fällt der Laufzyklus weg (gew geht gegen 0), also
	# braucht es eine eigene Haltung. Beim Steigen ziehen die Füße an und
	# spreizen sich, beim Fallen strecken sie sich zur Landung nach unten.
	var steig_ziel: float = clampf(
			_player.velocity.y / maxf(sprung_referenz_tempo, 0.01), -1.0, 1.0)
	_steig_blend = lerpf(_steig_blend, steig_ziel, 1.0 - exp(-sprung_blend * delta))
	var steigt: float = maxf(_steig_blend, 0.0)
	var faellt: float = maxf(-_steig_blend, 0.0)

	var luft_y: float = _luft_blend * (luft_fuss_hoch
			+ sprung_fuss_anziehen * steigt
			- fall_fuss_strecken * faellt)
	var luft_kipp: float = _luft_blend * (sprung_fuss_kipp * steigt
			+ fall_fuss_kipp * faellt)
	var spreiz: float = _luft_blend * sprung_fuss_spreizen * steigt

	# Vorne ist -Z: der rechte Fuß bekommt das negative Vorzeichen und geht damit
	# beim Absprung nach vorne. Für den umgekehrten Fall die beiden tauschen.
	_setze_fuss(_fuss_l, _fuss_ruhe_l, _phase, amp, hub, gew, fuss_wasser,
			luft_y, spreiz, luft_kipp)
	_setze_fuss(_fuss_r, _fuss_ruhe_r, _phase + PI, amp, hub, gew, -fuss_wasser,
			luft_y, -spreiz, luft_kipp)

	# ------------------------------------------------------- Ruhehaltung
	# Was die Figur GERADE HÄLT, weiß die Ausruestung – nicht Combat. Combat
	# kennt den Stil nur, soweit es ihn für den laufenden Schlag braucht; im
	# Stand kann aktiver_stil() deshalb auf Faust zurückfallen, und dann gäbe
	# es überhaupt keine Ruhehaltung. Genau daran ist der erste Anlauf
	# gescheitert.
	var ruhe_waffe: WaffenDaten = _ruhe_waffe()
	var ruhe_stil: int = WaffenDaten.Stil.FAUST
	var zweihand: bool = false
	var zwang_zweihand: bool = false
	if ruhe_waffe != null:
		ruhe_stil = ruhe_waffe.stil
		zweihand = ruhe_waffe.ist_zweihaendig()
		zwang_zweihand = ruhe_waffe.erzwingt_zwei_haende()
	var ruhe_pose: Dictionary = _stil_posen.get(ruhe_stil,
			_stil_posen[WaffenDaten.Stil.FAUST])

	# Im Wasser hält niemand eine Waffe im Anschlag – die Haltung fährt raus.
	var land: float = 1.0 - _wasser_blend
	_haltung_versatz = _haltung_versatz.lerp(
			(ruhe_pose["ruhe_pos"] as Vector3) * land, hw)
	_haltung_schwung = lerpf(_haltung_schwung,
			lerpf(1.0, float(ruhe_pose["ruhe_schwung"]), land), hw)

	var schild: bool = _nebenhand_ist_schild()
	_schild_blend = lerpf(_schild_blend, (1.0 if schild else 0.0) * land, hw)

	# Steckt überhaupt eine Waffe in der Haupthand? Nur dafür bekommt die
	# Deckung eine andere Handhaltung – Fäuste decken mit dem Unterarm, eine
	# Waffe wird quer vor den Körper geführt.
	var waffe_da: float = 1.0 if ruhe_waffe != null else 0.0
	_waffen_blend = lerpf(_waffen_blend, waffe_da * land, hw)

	# Beidhändig oder nicht – drei Fälle, in dieser Reihenfolge:
	#
	#   1. erzwingt_zwei_haende()  bindend. Ein Zweihänder lässt sich nicht
	#      einhändig führen, und ausruesten() hält die linke Hand für ihn frei.
	#   2. zweihändiger Griff mit kann_einhaendig, Nebenhand frei -> beidhändig.
	#      Der Speer greift zu, wenn nichts im Weg ist.
	#   3. Nebenhand belegt -> einhändig, auch wenn der Griff ZWEIHAND sagt.
	#
	# "beide_haende" in der Stiltabelle ist nur die Bevorzugung des Stils und
	# greift ebenfalls nur bei freier Nebenhand. Der Griff der Waffe gewinnt,
	# wenn beide etwas sagen.
	var nebenhand_frei: bool = _nebenhand() == null
	var beidhaendig: bool = false
	if zwang_zweihand:
		beidhaendig = true
	elif nebenhand_frei and (zweihand or bool(ruhe_pose["beide_haende"])):
		beidhaendig = true
	beidhaendig = beidhaendig and land > 0.5

	# Wie stark der Schlag wegen des Schildes eingeschnürt wird. Beidhändig
	# geführte Waffen sind nie betroffen – dort ist die Nebenhand ja am Schaft.
	var schild_eng: float = 0.0 if beidhaendig else _schild_blend

	if haltung_debug:
		_haltung_debug_timer -= delta
		if _haltung_debug_timer <= 0.0:
			_haltung_debug_timer = 1.0
			var wname: String = "keine (Faust)"
			if ruhe_waffe != null:
				wname = ruhe_waffe.anzeige_name
			print("[Haltung] %s | Stil %d | zweihand %s | Schild %s | Halter %s"
					% [wname, ruhe_stil, str(beidhaendig), str(schild),
					str((_halter_akt_r * 57.2958).round())])

	# ----------------------------------------------------------------- Hände
	var h_amp_r: float = hand_schwung * gew * _haltung_schwung
	var h_amp_l: float = hand_schwung * gew
	if beidhaendig:
		h_amp_l = h_amp_r
	else:
		h_amp_l = lerpf(h_amp_l, hand_schwung * gew * SCHILD_SCHWUNG, _schild_blend)

	var atmen: float = sin(_zeit * 2.2) * 0.012 * (1.0 - _lauf_gewicht) \
			* (1.0 - _wasser_blend)
	var hoch: float = atmen + luft_hand_hoch * _luft_blend
	var hand_wasser: float = sin(_schwimm_phase) * schwimm_hand * _wasser_blend

	var ziel_l: Vector3 = _hand_ruhe_l \
			+ Vector3(0.0, hoch, sin(_phase) * h_amp_l + hand_wasser)
	var ziel_r: Vector3 = _hand_ruhe_r \
			+ Vector3(0.0, hoch, -sin(_phase) * h_amp_r - hand_wasser)

	# Ruhehaltung der Waffenhand. Die leere Hand bekommt sie NICHT gespiegelt –
	# sie hält ja nichts. Genau das sah vorher falsch aus.
	ziel_r += _haltung_versatz
	ziel_l += _spiegel(SCHILD_RUHE_POS) * _schild_blend

	var dreh_l: Vector3 = Vector3.ZERO
	var dreh_r: Vector3 = Vector3.ZERO

	# Deckung legt sich darüber: beide Hände hoch und vor den Körper.
	# Mit Schild geht die Schildhand weiter vor – sie ist die Deckung.
	if _block_blend > 0.001:
		# Mit Schild deckt die Schildhand allein – die Waffenhand rührt sich
		# nicht. Ohne Schild deckt sie mit, und dann rückt sie mit Waffe
		# weiter zur Mitte und höher als mit bloßen Fäusten: die Klinge liegt
		# quer vor Brust und Gesicht, dafür muss der Griff mittig stehen.
		var block_waffenhand: float = _block_blend * (1.0 - _schild_blend)
		if block_waffenhand > 0.001:
			var einwaerts_r: float = hand_abstand * (0.30 + 0.28 * _waffen_blend)
			var hoch_r: float = block_hand_hoch + 0.08 * _waffen_blend
			var vorne_r: float = block_hand_vorne + 0.06 * _waffen_blend
			ziel_r = ziel_r.lerp(_hand_ruhe_r + Vector3(-einwaerts_r,
					hoch_r, -vorne_r), block_waffenhand)

		# Die Schildhand geht weiter vor als die Faust – sie IST die Deckung.
		var vorne_l: float = block_hand_vorne + SCHILD_BLOCK_VORNE * _schild_blend
		var einwaerts_l: float = hand_abstand * (0.30 + 0.22 * _schild_blend)
		ziel_l = ziel_l.lerp(_hand_ruhe_l + Vector3(einwaerts_l,
				block_hand_hoch, -vorne_l), _block_blend)

	# Schlag hat Vorrang. Die Pose kommt aus der Stiltabelle und ist ein
	# Versatz auf die Ruhelage – bei kurve = 0 also exakt null, damit der
	# Übergang zwischen Ausholen und Zuschlagen stetig bleibt.
	if absf(kurve) > 0.001:
		var pos_o: Vector3
		var rot_o: Vector3
		if kurve < 0.0:
			var a: float = clampf(-kurve / maxf(schlag_rueckzug, 0.001), 0.0, 1.0)
			pos_o = (pose["ausholen_pos"] as Vector3) * schlag_reichweite * a
			rot_o = (pose["ausholen_rot"] as Vector3) * a
		else:
			pos_o = (pose["treffer_pos"] as Vector3) * schlag_reichweite * kurve
			rot_o = (pose["treffer_rot"] as Vector3) * kurve

		# Mit Schild bleibt der Schlag auf der rechten Körperhälfte. Nur der
		# Anteil nach links wird gekürzt, nach rechts bleibt alles wie gehabt.
		# Ohne das zieht der Axthieb quer durch die Schildfläche: das Blatt
		# steht am Trefferpunkt bei x = -0.42, das Schild reicht von -0.54
		# bis -0.02.
		if schild_eng > 0.001 and pos_o.x < 0.0:
			pos_o.x *= lerpf(1.0, schild_schlag_breite, schild_eng)

		if bool(pose["beide_haende"]):
			ziel_r += pos_o
			dreh_r = _grad(rot_o)
		elif _schlag_links:
			ziel_l += _spiegel(pos_o)
			dreh_l = _grad(_spiegel_dreh(rot_o))
		else:
			ziel_r += pos_o
			dreh_r = _grad(rot_o)

	# ------------------------------------------------------- Halterausrichtung
	# Absolute Zielausrichtung über den ganzen Schlagverlauf, stetig von der
	# Ruhehaltung über das Ausholen zum Treffer und zurück. Anders als bei den
	# Handversätzen wird hier NICHT addiert – eine Klinge hat eine Richtung,
	# keine Summe von Richtungen.
	var halter_ziel_r: Vector3 = _halter_ziel(ruhe_pose, pose,
			_schlag_fortschritt)

	# Deckung legt sich über die Ruhehaltung, aber nur ohne Schild – mit
	# Schild bleibt die Waffe stehen, wo sie ist. Der Schlag hat außerdem
	# Vorrang: ohne den Faktor (1 - _angriff_blend) bliebe die Klinge beim
	# Angriff aus der Deckung heraus quer stehen, weil 'block' und 'attack'
	# gleichzeitig gedrückt sein können.
	var block_anteil: float = _block_blend * (1.0 - _angriff_blend) \
			* (1.0 - _schild_blend)
	if block_anteil > 0.001:
		halter_ziel_r = halter_ziel_r.lerp(
				ruhe_pose["halter_block"] as Vector3, block_anteil)

	# Dieselbe Schranke wie beim Handversatz, hier für die Drehung: positives
	# Gieren dreht die Waffe nach links, also zum Schild hin. Nur dieser
	# Anteil wird gekürzt.
	if schild_eng > 0.001 and halter_ziel_r.y > 0.0:
		halter_ziel_r.y *= lerpf(1.0, schild_schlag_gieren, schild_eng)

	halter_ziel_r *= land
	if not waffen_posen_nutzen:
		halter_ziel_r = Vector3.ZERO

	var halter_ziel_l: Vector3 = SCHILD_RUHE_HALTER.lerp(
			SCHILD_BLOCK_HALTER, _block_blend) * _schild_blend
	if beidhaendig:
		# Zweite Hand am selben Schaft: sie übernimmt die Ausrichtung der
		# Waffenhand, sonst stünde der Halter der leeren Hand quer dazu.
		halter_ziel_l = halter_ziel_r
	if not waffen_posen_nutzen:
		halter_ziel_l = Vector3.ZERO

	# Im ersten Frame hart setzen. Sonst lerpt die Axt beim Spielstart sichtbar
	# von 0 auf ihre 180 Grad Rolle – die Waffe würde sich einmal um sich
	# selbst drehen, bevor sie richtig liegt.
	if _halter_erster_frame:
		_halter_erster_frame = false
		_halter_akt_r = _grad(halter_ziel_r)
		_halter_akt_l = _grad(halter_ziel_l)
	else:
		_halter_akt_r = _halter_akt_r.lerp(_grad(halter_ziel_r), lw)
		_halter_akt_l = _halter_akt_l.lerp(_grad(halter_ziel_l), lw)

	# ------------------------------------------------- Zweite Hand am Schaft
	# Statt die Pose zu spiegeln (dann fuchtelt die linke Hand 72 cm neben dem
	# Zweihänder her) wird sie an einen Punkt AUF der Waffe gesetzt: Halter der
	# rechten Hand, dann 'zweithand_versatz' entlang des Schafts, alles in der
	# gedrehten Halterbasis. Beide Hände liegen damit sichtbar an derselben
	# Stange, auch mitten im Schwung.
	if beidhaendig:
		dreh_l = dreh_r
		var basis: Basis = Basis.from_euler(dreh_r) * Basis.from_euler(_halter_akt_r)
		ziel_l = ziel_r + basis * (ruhe_pose["zweithand_versatz"] as Vector3)

	_hand_l.position = ziel_l
	_hand_r.position = ziel_r
	_hand_l.rotation = dreh_l
	_hand_r.rotation = dreh_r

	# Nur rotation, niemals position oder scale – die gehören ausruestung.gd
	# beziehungsweise dem Modell darunter.
	if _halter_r != null:
		_halter_r.rotation = _halter_akt_r
	if _halter_l != null:
		_halter_l.rotation = _halter_akt_l


# Zielausrichtung des Waffenhalters in Grad, über den gesamten Schlagverlauf.
# ruhe = Haltung der ausgerüsteten Waffe, schlag = Pose des laufenden Schlages.
#
# Absichtlich stückweise zwischen ABSOLUTEN Haltungen interpoliert statt
# Versätze zu addieren: an der Grenze zwischen Ausholen und Durchziehen wäre
# eine Summe unstetig, die Klinge würde dort umspringen.
func _halter_ziel(ruhe: Dictionary, schlag: Dictionary, f: float) -> Vector3:
	var h_ruhe: Vector3 = ruhe["halter_ruhe"]
	if _angriff_blend <= 0.001:
		return h_ruhe

	var h_aus: Vector3 = schlag["halter_ausholen"]
	var h_tref: Vector3 = schlag["halter_treffer"]
	var ziel: Vector3

	if f < _schlag_m1:
		var a: float = f / maxf(_schlag_m1, 0.001)
		ziel = h_ruhe.lerp(h_aus, 1.0 - pow(1.0 - a, 2.0))
	elif f < _schlag_m2:
		# Durchziehen: hart beschleunigen. Das ist der Teil, den man sieht.
		var b: float = (f - _schlag_m1) / maxf(_schlag_m2 - _schlag_m1, 0.001)
		ziel = h_aus.lerp(h_tref, 1.0 - pow(1.0 - b, 3.0))
	else:
		var c: float = (f - _schlag_m2) / maxf(1.0 - _schlag_m2, 0.001)
		ziel = h_tref.lerp(h_ruhe, c * c * (3.0 - 2.0 * c))

	return h_ruhe.lerp(ziel, _angriff_blend)


# Schlagkurve über den gesamten Schlag: 0 = Beginn, 1 = Ende.
# Rückgabe: negativ = ausholen, 1.0 = volle Streckung, am Ende zurück auf 0.
#
# m1 und m2 kommen aus Combat.schlag_marken() und liegen genau auf Anfang und
# Ende des Trefferfensters der Waffe. Dadurch landet der sichtbare Treffer
# immer dort, wo auch der Schaden entsteht – egal wie eine Waffe getimt ist.
#
# Die drei Abschnitte haben unterschiedliche Zeitkurven. Linear interpoliert
# wirken Ausholen, Treffer und Rückzug gleich schnell, und das liest das Auge
# als Zucken statt als Schlag.
func _schlag_kurve(f: float, m1: float, m2: float) -> float:
	if f < m1:
		# Ausholen: zügig zurück, dann stehen bleiben. Diese kurze Ruhe ist
		# die Anspannung, die den Schlag danach überhaupt lesbar macht.
		var a: float = f / maxf(m1, 0.001)
		return lerpf(0.0, -schlag_rueckzug, 1.0 - pow(1.0 - a, 2.0))
	elif f < m2:
		# Durchziehen: sofort volle Beschleunigung, am Ende auslaufen.
		var b: float = (f - m1) / maxf(m2 - m1, 0.001)
		return lerpf(-schlag_rueckzug, 1.0, 1.0 - pow(1.0 - b, 3.0))
	# Nachschwung: gleichmäßig zurück in die Ruhelage, kein Zurückschnappen.
	var c: float = (f - m2) / maxf(1.0 - m2, 0.001)
	return lerpf(1.0, 0.0, c * c * (3.0 - 2.0 * c))


# Die Waffe, deren Haltung im Stand gilt. Null bedeutet "bloße Fäuste".
#
# Bewusst über Ausruestung und nicht über Combat: aktive_waffe() liefert die
# Faust-Ressource als Rückfall, und die hat kein Modell. Eine Waffe ohne Mesh
# ist optisch keine Waffe – sie bekommt deshalb auch keine Ruhehaltung, egal
# was in ihrem 'stil' steht. Damit stimmt die Haltung automatisch für
# faust.tres, ohne dass irgendwo auf Stil.FAUST geprüft wird.
func _ruhe_waffe() -> WaffenDaten:
	if _ausruestung == null or not waffen_posen_nutzen or not stil_posen_nutzen:
		return null
	if not _ausruestung.ist_bereit():
		return null
	var w: WaffenDaten = _ausruestung.aktive_waffe()
	if w == null or not w.hat_modell():
		return null
	return w


# Was in der Nebenhand steckt, oder null. Ein Modell ohne Mesh zählt nicht –
# es ist optisch nichts da, also ist die Hand für die Haltung frei.
func _nebenhand() -> WaffenDaten:
	if _ausruestung == null or not waffen_posen_nutzen:
		return null
	var n: WaffenDaten = _ausruestung.nebenhand()
	if n == null or not n.hat_modell():
		return null
	return n


# Steckt in der Nebenhand ein Schild? aktiver_stil() beschreibt die Haupthand
# und weiß davon nichts, deshalb geht die Frage direkt an die Ausruestung.
func _nebenhand_ist_schild() -> bool:
	var n: WaffenDaten = _nebenhand()
	if n == null:
		return false
	return n.griff == WaffenDaten.Griff.SCHILD


# Spiegelt einen Versatz auf die linke Körperseite: X ist die einzige Achse,
# die sich umdreht, vor und hoch bleiben vor und hoch.
func _spiegel(v: Vector3) -> Vector3:
	return Vector3(-v.x, v.y, v.z)


# Bei Drehungen kehren sich Gieren und Rollen um, Nicken nicht.
func _spiegel_dreh(v: Vector3) -> Vector3:
	return Vector3(v.x, -v.y, -v.z)


func _grad(v: Vector3) -> Vector3:
	return Vector3(deg_to_rad(v.x), deg_to_rad(v.y), deg_to_rad(v.z))


func _setze_fuss(knoten: Node3D, ruhe: Vector3, phase: float, amp: float,
		hub: float, gew: float, wasser: float,
		luft_y: float, luft_z: float, luft_kipp: float) -> void:
	var z: float = -sin(phase) * amp + wasser + luft_z
	var y: float = maxf(0.0, sin(phase + hub_versatz)) * hub + luft_y
	knoten.position = Vector3(ruhe.x, ruhe.y + y, ruhe.z + z)
	# Positive Werte um X heben die Zehen an, negative senken sie.
	knoten.rotation.x = cos(phase) * fuss_kipp * gew + luft_kipp


func _setze_box(mi: MeshInstance3D, groesse: Vector3, lokal: Vector3,
		farbe: Color) -> void:
	if mi == null:
		return

	# Immer eine eigene Kopie: duplizierte Knoten teilen sich sonst dieselbe
	# Mesh-Ressource und würden sich gegenseitig umformen.
	var box: BoxMesh = mi.mesh as BoxMesh
	box = BoxMesh.new() if box == null else box.duplicate() as BoxMesh
	box.size = groesse
	mi.mesh = box
	mi.position = lokal

	if farben_anwenden:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = farbe
		mat.roughness = 1.0
		mat.metallic_specular = 0.0
		mi.material_override = mat
