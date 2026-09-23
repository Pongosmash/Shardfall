shader_type sky;

// Stilisierter Himmel im Pixel-Look. Der Verlauf wird in Bänder gerastert
// statt weich zu blenden, passend zu Gras, Blumen und Voxelterrain.
//
// Bewusst OHNE Rauschen im Verlauf: Dithering macht bei so großen Flächen
// und wenigen Stufen den ganzen Himmel körnig. Gegen die konzentrischen
// Ringe laufen die Bandgrenzen stattdessen wellig statt kreisrund. Die
// Sterne weiter unten sind ein bewusst separater, rasterartiger Effekt -
// keine Ausnahme von dieser Regel, sondern ein eigenes Element im selben
// Pixel-Look.
//
// Der Mondschein nutzt bewusst NICHT 'stufen()': bei einem kleinen, hellen
// Objekt am dunklen Nachthimmel macht dieselbe Bänderung wie am Taghimmel
// sichtbare Ringe/Strahlen um den Mond - dort stoert das, waehrend es beim
// Tagesverlauf gewuenscht ist.
//
// Die Horizontfarbe muss mit der Nebelfarbe im WorldEnvironment
// übereinstimmen, sonst bleibt die Ladekante des Terrains sichtbar.
//
// tagesanteil, daemmerungsanteil, mond_richtung und sterne_winkel kommen
// von Tageszeit.gd, einmal pro Bild gesetzt - siehe deren Kopfkommentar.
// Der Shader rechnet selbst keine Uhr.
//
// Sonne und Mond sind ZWEI getrennte Scheiben mit zwei getrennten
// Richtungen - nicht dieselbe Scheibe, die nur die Farbe wechselt. Das
// Licht selbst (DirectionalLight3D, siehe Tageszeit.gd) ueberblendet
// zwischen beiden Richtungen und ist nachts tatsaechlich die Mond-Richtung -
// dieser Shader zeichnet hier nur, was am Himmel zu SEHEN ist.
//
// Der Sonnenschein/die Sonnenscheibe werden am Ende zusaetzlich mit
// 'tagesanteil' ausgeblendet: 'sonne_folgt_licht' zeigt sonst nachts auf
// LIGHT0_DIRECTION, die Tageszeit.gd dann zum Mond hin ueberblendet - ohne
// das Fading wuerde der Sonnenblock seine gebaenderten Ringe ueber dem Mond
// zeichnen und die Krater zudecken.

group_uniforms Farben;
uniform vec3 farbe_zenit : source_color = vec3(0.20, 0.45, 0.82);
uniform vec3 farbe_horizont : source_color = vec3(0.72, 0.86, 0.96);
uniform vec3 farbe_boden : source_color = vec3(0.38, 0.42, 0.40);

group_uniforms Nacht;
uniform vec3 farbe_zenit_nacht : source_color = vec3(0.02, 0.03, 0.09);
uniform vec3 farbe_horizont_nacht : source_color = vec3(0.05, 0.06, 0.14);
uniform vec3 farbe_boden_nacht : source_color = vec3(0.02, 0.02, 0.03);
// Farbe des Gluehens am Horizont waehrend Auf- und Untergang.
uniform vec3 farbe_daemmerung : source_color = vec3(0.88, 0.42, 0.22);
// 0 = Nacht, 1 = Tag. Von Tageszeit.gd gesetzt.
uniform float tagesanteil : hint_range(0.0, 1.0) = 1.0;
// 0 abseits von Auf-/Untergang, Spitze bei 1 genau am Horizont. Von
// Tageszeit.gd gesetzt.
uniform float daemmerungsanteil : hint_range(0.0, 1.0) = 0.0;

group_uniforms Verlauf;
// Anzahl der Farbstufen von Horizont bis Zenit. Klein = grafischer.
// Ab etwa 30 wirkt der Verlauf praktisch stufenlos.
uniform int baender : hint_range(2, 40) = 22;
// Verbiegt die Bandgrenzen, damit sie keine perfekten Ringe bilden.
// 0 = saubere Kreise, 1 = deutlich wellig.
uniform float band_wellen : hint_range(0.0, 2.0) = 0.55;
// Wie unruhig die Welle verläuft. Höher = mehr Schlangenlinien pro Umdrehung.
uniform float wellen_frequenz : hint_range(1.0, 12.0) = 3.0;
// Höher = das helle Horizontband bleibt länger und wird schmaler
uniform float horizont_schaerfe : hint_range(0.5, 4.0) = 1.8;
// Wie weit der Verlauf unter den Horizont reicht
uniform float boden_breite : hint_range(0.5, 8.0) = 3.0;
// Wie weich die Bandgrenzen ineinander uebergehen. 0 = harter Schnitt,
// 0.5 = praktisch glatter Verlauf ohne sichtbare Baender mehr.
uniform float kantenweichheit : hint_range(0.0, 0.5) = 0.18;

group_uniforms Sonne;
uniform bool sonne_zeigen = true;
// AN: Die Sonne steht dort, wo dein DirectionalLight3D hinzeigt.
// AUS: feste Richtung aus 'sonnen_richtung'.
uniform bool sonne_folgt_licht = false;
// Wenn die Sonne bei aktivem Licht auf der Gegenseite steht: hier umschalten.
uniform bool sonne_umkehren = false;
// Feste Sonnenposition. Y > 0 heißt über dem Horizont.
uniform vec3 sonnen_richtung = vec3(0.45, 0.50, 0.74);
uniform vec3 sonnen_farbe : source_color = vec3(1.0, 0.97, 0.86);
uniform float sonnen_groesse : hint_range(0.0, 0.5) = 0.12;
uniform float sonnen_rand : hint_range(0.0, 0.2) = 0.012;
// Weicher Schein um die Sonne, ebenfalls gestuft
uniform vec3 schein_farbe : source_color = vec3(1.0, 0.90, 0.68);
uniform float schein_weite : hint_range(0.0, 2.0) = 0.60;
uniform float schein_staerke : hint_range(0.0, 1.0) = 0.35;

group_uniforms Mond;
// Eigene Richtung, "Richtung ZUM Mond" (dieselbe Konvention wie
// 'sonnen_richtung' oben - Y > 0 heisst ueber dem Horizont). Wird jedes
// Bild von Tageszeit.gd gesetzt, um 12 Stunden versetzt zur Sonne.
uniform vec3 mond_richtung = vec3(-0.45, -0.50, -0.74);
uniform vec3 mond_farbe : source_color = vec3(0.85, 0.87, 0.92);
uniform float mond_groesse : hint_range(0.0, 0.5) = 0.05;
// Eigener, kleiner Schein-Radius statt 'schein_weite' (das ist fuer die
// Sonne breit ausgelegt) - beim Mond soll der Hof knapp anliegen.
uniform float mond_schein_weite : hint_range(0.0, 0.5) = 0.10;
uniform float mond_schein_staerke : hint_range(0.0, 1.0) = 0.12;
// Wie stark die Krater die Mondfarbe abdunkeln. 0 = keine Krater sichtbar.
uniform float krater_staerke : hint_range(0.0, 1.0) = 0.45;

group_uniforms Sterne;
uniform bool sterne_zeigen = true;
// Schwellwert 0..1. Hoeher = weniger Sterne. ~0.997 ergibt ein duennes Feld.
uniform float sterne_dichte : hint_range(0.9, 0.999) = 0.997;
uniform float sterne_helligkeit : hint_range(0.0, 2.0) = 1.0;
uniform vec3 sterne_farbe : source_color = vec3(1.0, 1.0, 0.95);
// Rastergroesse auf der Himmelskugel. Hoeher = kleinere, dichtere Zellen.
uniform float sterne_raster : hint_range(50.0, 500.0) = 220.0;
// Voller Sternenhimmel dreht sich einmal pro Spieltag um die Y-Achse - von
// Tageszeit.gd gesetzt, gleicher Drehsinn wie die Sonnenbahn. Keine echte
// Sternkarte, nur eine simulierte scheinbare Drehung.
uniform float sterne_winkel : hint_range(0.0, 6.2832) = 0.0;


// Wert auf feste Stufen rasten, mit weichem Uebergang an jeder Bandgrenze.
// Die Welle verschiebt die Schwelle abhängig von der Himmelsrichtung, wodurch
// jede Bandgrenze zu einer weichen Schlangenlinie wird statt zu einem Ring.
float stufen(float wert, vec3 dir) {
	float n = max(1.0, float(baender) - 1.0);
	float breite = 1.0 / float(baender);

	float winkel = atan(dir.x, dir.z);
	float welle = (sin(winkel * wellen_frequenz) * 0.6
			+ sin(winkel * wellen_frequenz * 2.3 + 1.3) * 0.4) * band_wellen * breite;

	float skaliert = clamp(wert + welle, 0.0, 1.0) * float(baender);
	float basis = floor(skaliert);
	float f = fract(skaliert);
	// weicher Uebergang um jede Bandgrenze statt hartem floor() - die Mitte
	// jedes Bandes bleibt trotzdem flach, nur der Rand wird verwischt.
	float kante = smoothstep(0.5 - kantenweichheit, 0.5 + kantenweichheit, f);
	return clamp((basis + kante) / n, 0.0, 1.0);
}

// Pseudozufallswert 0..1 aus einer Richtung. Feste Rasterzellen auf der
// Himmelskugel statt Bildschirmpixeln - sonst wandern die Sterne beim
// Umschauen mit der Kamera statt am Himmel festzustehen.
float hash13(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Dreht eine Richtung um die Y-Achse - simuliert die scheinbare Drehung des
// Sternenhimmels ueber die Nacht.
vec3 drehen_y(vec3 dir, float winkel) {
	float s = sin(winkel);
	float c = cos(winkel);
	return vec3(dir.x * c - dir.z * s, dir.y, dir.x * s + dir.z * c);
}

// Drei feste Krater in lokalen Mondkoordinaten (Ursprung = Mondmitte,
// Einheit = 'mond_groesse'). Fest statt zufaellig, damit der Mond bei
// jedem Bild gleich aussieht statt zu flackern.
float krater_muster(vec2 uv) {
	float k = 0.0;
	k = max(k, smoothstep(0.34, 0.20, distance(uv, vec2(-0.38, 0.28))));
	k = max(k, smoothstep(0.28, 0.16, distance(uv, vec2(0.32, -0.08))));
	k = max(k, smoothstep(0.22, 0.12, distance(uv, vec2(-0.10, -0.42))));
	return k;
}

void sky() {
	// Tag/Nacht-Basisfarben mischen, das Horizontband zusaetzlich beim
	// Auf-/Untergang roeten. Zenit und Boden bleiben davon unberuehrt -
	// das Gluehen gehoert an den Horizont, nicht in den ganzen Himmel.
	vec3 zenit = mix(farbe_zenit_nacht, farbe_zenit, tagesanteil);
	vec3 horizont = mix(farbe_horizont_nacht, farbe_horizont, tagesanteil);
	horizont = mix(horizont, farbe_daemmerung, daemmerungsanteil);
	vec3 boden = mix(farbe_boden_nacht, farbe_boden, tagesanteil);

	float h = EYEDIR.y;
	vec3 col;

	if (h >= 0.0) {
		float t = pow(clamp(h, 0.0, 1.0), 1.0 / horizont_schaerfe);
		col = mix(horizont, zenit, stufen(t, EYEDIR));
	} else {
		// Unterhalb des Horizonts in Richtung Bodenfarbe auslaufen
		float u = clamp(-h * boden_breite, 0.0, 1.0);
		col = mix(horizont, boden, stufen(u, EYEDIR));
	}

	// Sterne: nur oberhalb des Horizonts, nur nachts (ueber tagesanteil
	// ausgeblendet), bevor Sonne/Mond obendrauf gezeichnet werden. Die
	// Blickrichtung wird vorher um 'sterne_winkel' gedreht, damit das ganze
	// Feld ueber die Nacht scheinbar mitwandert.
	if (sterne_zeigen && h > 0.0) {
		vec3 sterne_dir = drehen_y(EYEDIR, sterne_winkel);
		vec3 zelle = floor(sterne_dir * sterne_raster);
		float zufall = hash13(zelle);
		float stern = step(sterne_dichte, zufall) * sterne_helligkeit;
		stern *= (1.0 - tagesanteil);
		col += sterne_farbe * stern;
	}

	// Mond: eigene Scheibe, eigene Richtung, um 12 Stunden versetzt zur
	// Sonne (siehe Tageszeit.gd) - blendet ein, sobald die Sonne weg ist.
	if (sonne_zeigen) {
		vec3 mond_achse = normalize(mond_richtung);
		float dm = distance(EYEDIR, mond_achse);
		float nachtanteil = 1.0 - tagesanteil;

		// Weicher, ungebaenderter Hof - kein stufen() hier, siehe Kopfkommentar.
		float mond_schein = 1.0 - smoothstep(0.0, max(mond_schein_weite, 0.001), dm);
		col = mix(col, mond_farbe, mond_schein * mond_schein_staerke * nachtanteil);

		// Lokale 2D-Koordinaten auf der Mondscheibe fuer die Krater. 'rechts'
		// und 'oben' stehen senkrecht zur Blickachse zum Mond; die Projektion
		// ist fuer eine so kleine Scheibe (wenige Grad) genau genug, ohne
		// eine echte sphaerische Abbildung zu brauchen.
		vec3 mond_rechts = normalize(cross(vec3(0.0, 1.0, 0.0), mond_achse));
		vec3 mond_oben = cross(mond_achse, mond_rechts);
		vec2 mond_uv = vec2(dot(EYEDIR, mond_rechts), dot(EYEDIR, mond_oben))
				/ max(mond_groesse, 0.001);

		float krater = krater_muster(mond_uv) * krater_staerke;
		vec3 mond_farbe_mit_kratern = mond_farbe * (1.0 - krater);

		float mond_scheibe = 1.0 - smoothstep(mond_groesse,
				mond_groesse + sonnen_rand, dm);
		col = mix(col, mond_farbe_mit_kratern, mond_scheibe * nachtanteil);
	}

	if (sonne_zeigen) {
		vec3 zur_sonne = normalize(sonnen_richtung);
		if (sonne_folgt_licht && LIGHT0_ENABLED) {
			// LIGHT0_DIRECTION ist die Richtung, in die das Licht fällt –
			// die Sonne steht also entgegengesetzt.
			zur_sonne = sonne_umkehren ? LIGHT0_DIRECTION : -LIGHT0_DIRECTION;
		}

		float d = distance(EYEDIR, zur_sonne);

		// '* tagesanteil': ohne das faerbt der Sonnenschein-Ring auch nachts
		// mit hinein, weil 'sonne_folgt_licht' auf LIGHT0_DIRECTION zeigt -
		// und die ueberblendet Tageszeit.gd nachts zum Mond hin. Ohne Fade
		// zeichnet der Sonnenblock seine gebaenderten Ringe also genau ueber
		// dem Mond und deckt anschliessend mit der Sonnenscheibe die Krater
		// zu.
		float schein = 1.0 - clamp(d / max(schein_weite, 0.001), 0.0, 1.0);
		col = mix(col, schein_farbe, stufen(schein, EYEDIR) * schein_staerke * tagesanteil);

		float scheibe = 1.0 - smoothstep(sonnen_groesse,
				sonnen_groesse + sonnen_rand, d);
		col = mix(col, sonnen_farbe, scheibe * tagesanteil);
	}

	COLOR = col;
}