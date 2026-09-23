## Tageszeit
## =========
## Besitzt die Uhrzeit und die Richtung von Sonne und Mond - die einzige
## Quelle dafuer im Spiel. 'licht' ist EIN DirectionalLight3D, das je nach
## Tagesanteil zwischen der Sonnen- und der Mondrichtung ueberblendet -
## nachts ist der Mond also die tatsaechliche Lichtquelle samt Schatten,
## nur deutlich schwaecher (siehe 'mond_staerke'). Schreibt jedes Bild die
## Rotation, Farbe, Staerke und den Schatten-Bias von 'licht',
## tagesanteil/daemmerungsanteil in den Himmel-Shader, sowie das
## Ambientlicht im WorldEnvironment.
##
## Schreibt NICHT die Nebelfarbe direkt - das bleibt allein Aufgabe von
## Underwater.gd, das ueber nebel_farbe() die aktuelle Tagesfarbe abfragt.
## Zwei Systeme, die denselben Wert schreiben, ueberschreiben sich sonst
## gegenseitig (derselbe Konflikt wie beim Waffenhalter).
##
## Einbau: als Node unter Welt, neben DirectionalLight3D und WorldEnvironment.
## Erwartet im Inspektor: 'licht' auf die DirectionalLight3D-Instanz,
## 'world_env' auf die WorldEnvironment-Instanz gezogen.
## Die Sonnenscheibe im Himmel-Shader folgt automatisch mit, wenn im
## WorldEnvironment -> Sky Material -> Sonne der Haken 'Sonne Folgt Licht'
## gesetzt ist - dafuer ist hier kein Code noetig.

class_name Tageszeit
extends Node

@export var licht: DirectionalLight3D
@export var world_env: WorldEnvironment

@export_group("Uhr")
@export var tageslaenge := 1200.0        # echte Sekunden pro Spieltag
@export var laeuft := true
## Die einzige Zustandsvariable. 0..24. Waehrend des Spielens ueber den
## Remote-Inspektor durchschiebbar, um die Bahn zu pruefen.
@export_range(0.0, 24.0) var stunde := 8.0

@export_group("Sonnenbahn")
## Wie hoch die Sonne mittags steigt. 90 = senkrecht (flache Schatten, sieht
## schlecht aus), 55-65 ist ein guter Bereich.
@export_range(20.0, 90.0) var mittagshoehe := 60.0
## Himmelsrichtung, um die die Bahn kippt. 0 = Sonne geht genau im Osten auf.
@export_range(-180.0, 180.0) var bahn_drehung := -20.0

@export_group("Licht")
## Wie breit das Band um den Horizont ist, in dem Staerke und Farbe zwischen
## Nacht und Tag ueberblenden. Wert ist der Sinus der Sonnenhoehe (0..1),
## nicht Grad. Groesser = laengere, weichere Daemmerung.
@export_range(0.02, 0.4) var daemmerung := 0.15
@export var sonne_staerke := 1.0
@export var mond_staerke := 0.12
@export var sonne_farbe_mittag := Color(1.0, 0.98, 0.92)
@export var sonne_farbe_horizont := Color(1.0, 0.62, 0.34)
@export var mond_farbe := Color(0.55, 0.65, 0.95)

@export_group("Schatten")
## Bei tiefstehender Sonne streift das Licht die Blockoberflaechen fast
## parallel - der normale Bias reicht dann nicht mehr und es entstehen
## Streifenmuster auf ebenem Boden. Bei flachem Einfall braucht es mehr Bias,
## bei steilem weniger (sonst loesen sich die Schatten vom Objekt).
@export var bias_flach := 0.3
@export var bias_steil := 0.05

@export_group("Umgebung")
@export var ambient_tag := 1.0
@export var ambient_nacht := 0.35
## Muss zur Horizontfarbe im Himmel-Shader passen (siehe dessen
## Kopfkommentar), sonst bleibt die Ladekante des Terrains am Horizont
## sichtbar. Bewusst eine eigene Kopie statt eines gemeinsamen Uniforms -
## Shader-Parameter und Environment-Felder sind zwei getrennte Ressourcen,
## die sich nicht teilen lassen (dasselbe Muster wie Bloecke.GRAS, das
## world_generator.gd unter altem Namen weiterreicht).
@export var nebel_farbe_tag := Color(0.72, 0.86, 0.9607843)
@export var nebel_farbe_nacht := Color(0.05, 0.06, 0.14)

var _himmel: ShaderMaterial
var _env: Environment
var _anteil_aktuell := 1.0


func _ready() -> void:
	if licht == null:
		push_error("Tageszeit: 'licht' fehlt - im Inspektor die " +
				"DirectionalLight3D hineinziehen.")
		set_process(false)
		return

	if world_env != null:
		_env = world_env.environment
		if _env != null and _env.sky != null:
			_himmel = _env.sky.sky_material as ShaderMaterial
	if _env == null:
		push_warning("Tageszeit: 'world_env' fehlt - Ambientlicht und " +
				"Himmelfarbe aendern sich nicht mit der Uhrzeit.")

	_anwenden()


func _process(delta: float) -> void:
	if laeuft:
		stunde = fmod(stunde + (delta / tageslaenge) * 24.0, 24.0)
	_anwenden()


func _anwenden() -> void:
	var sonnen_dir := _sonnen_richtung(stunde)
	var mond_dir := _sonnen_richtung(stunde + 12.0)

	# Der Ueberblendfaktor richtet sich nach der REINEN Tagbahn, nicht nach
	# der schon gemischten Lichtrichtung weiter unten - sonst wuerde sich
	# der Uebergang mit sich selbst als Eingabe beeinflussen.
	var sonnenhoehe_tag: float = -sonnen_dir.y
	_anteil_aktuell = tagesanteil(sonnenhoehe_tag)
	var daemmer: float = daemmerungsanteil(sonnenhoehe_tag)

	# Tags scheint die Sonne, nachts der Mond - fliessend ueberblendet, damit
	# kein Sprung entsteht, wenn das fuehrende Gestirn wechselt. Ein einziges
	# DirectionalLight3D reicht deshalb fuer beide, siehe Begruendung in
	# docs/tageszeit_plan.md Abschnitt 4 (kein zweites Licht wegen der
	# Shadow-Map-Kosten).
	var richtung: Vector3 = sonnen_dir.lerp(mond_dir, 1.0 - _anteil_aktuell).normalized()
	licht.look_at_from_position(Vector3.ZERO, richtung, Vector3.UP)

	var sonnenhoehe: float = -richtung.y
	licht.light_energy = lerpf(mond_staerke, sonne_staerke, _anteil_aktuell)
	licht.shadow_bias = lerpf(bias_flach, bias_steil, absf(sonnenhoehe))

	# Innerhalb des Tages zusaetzlich horizontnah roeten, unabhaengig von der
	# Daemmerungsblende - sonst bleibt der Mittag beim Auf-/Untergang farblos.
	var hoehenfarbe: float = clampf(sonnenhoehe_tag / sin(deg_to_rad(30.0)), 0.0, 1.0)
	var tagesfarbe: Color = sonne_farbe_horizont.lerp(sonne_farbe_mittag, hoehenfarbe)
	licht.light_color = mond_farbe.lerp(tagesfarbe, _anteil_aktuell)

	if _himmel != null:
		_himmel.set_shader_parameter("tagesanteil", _anteil_aktuell)
		_himmel.set_shader_parameter("daemmerungsanteil", daemmer)
		# Eigene, um 12 Stunden versetzte Bahn fuer den Mond - NICHT dieselbe
		# Richtung wie das Licht, das ueberblendet ja oben schon zum Mond hin.
		# '-' weil 'mond_richtung' im Shader als "Richtung ZUM Gestirn"
		# erwartet wird, '_sonnen_richtung()' hier aber die Schein-Richtung
		# liefert (siehe deren eigener Kommentar).
		_himmel.set_shader_parameter("mond_richtung", -mond_dir)
		# Sternenhimmel dreht sich einmal pro Spieltag mit - rein optisch,
		# hat keinen Einfluss auf Licht oder Schatten.
		_himmel.set_shader_parameter("sterne_winkel", (stunde / 24.0) * TAU)

	if _env != null:
		_env.ambient_light_energy = lerpf(ambient_nacht, ambient_tag, _anteil_aktuell)


## Die Nebelfarbe zur aktuellen Tageszeit. Nur zum Auslesen - Underwater.gd
## fragt das jedes Bild ab, statt eine eigene, eingefrorene Kopie zu halten.
func nebel_farbe() -> Color:
	return nebel_farbe_nacht.lerp(nebel_farbe_tag, _anteil_aktuell)


## Der zuletzt berechnete Tagesanteil (0 = Nacht, 1 = Tag). Fuer Abnehmer,
## die selbst keine Sonnenhoehe berechnen koennen, z.B. CloudLayer.
func tagesanteil_aktuell() -> float:
	return _anteil_aktuell


## 0 = Nacht, 1 = Tag, weicher Uebergang um den Horizont (Breite: daemmerung).
## Oeffentlich, weil Ambientlicht und Nebel denselben Wert brauchen - eine
## Stelle besitzt die Definition, alle anderen fragen.
func tagesanteil(sonnenhoehe: float) -> float:
	return smoothstep(-daemmerung, daemmerung, sonnenhoehe)


## 0 abseits von Auf-/Untergang, Spitze bei 1 genau am Horizont. Eigene,
## dreieckige Kurve statt tagesanteil() - das Gluehen soll kurz aufleuchten
## und wieder verschwinden, nicht mit der Helligkeit monoton mitsteigen.
func daemmerungsanteil(sonnenhoehe: float) -> float:
	var breite: float = daemmerung * 3.0
	return clampf(1.0 - absf(sonnenhoehe) / breite, 0.0, 1.0)


## Richtung, in die das Licht SCHEINT (vom Gestirn weg, nach unten).
## t = 0 bei Aufgang (6 Uhr), t = 1 bei Untergang (18 Uhr). Fuer Stunden
## ausserhalb von 6..18 wird dieselbe Formel einfach weitergerechnet - kein
## Sonderfall fuer die Nacht noetig. Der Grund: azimut waechst linear in t
## und steckt nur in sin()/cos(), die sind periodisch; und
## sin(t * PI) bei (t+1) kehrt exakt das Vorzeichen um. Fuer den Mond wird
## trotzdem separat der um 12 Stunden versetzte Wert gebraucht (siehe
## '_anwenden') - die rohe Richtung hier steht nachts unterm Horizont,
## das ist fuers Licht richtig, aber kein sichtbarer Mondpunkt.
func _sonnen_richtung(std: float) -> Vector3:
	var t: float = (std - 6.0) / 12.0
	var hoehe: float = sin(t * PI) * deg_to_rad(mittagshoehe)
	var azimut: float = lerpf(-PI * 0.5, PI * 0.5, t) + deg_to_rad(bahn_drehung)
	return Vector3(
		-cos(hoehe) * sin(azimut),
		-sin(hoehe),
		-cos(hoehe) * cos(azimut)
	).normalized()
