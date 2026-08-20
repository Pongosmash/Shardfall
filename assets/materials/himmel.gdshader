shader_type sky;

// Stilisierter Himmel im Pixel-Look. Der Verlauf wird in Bänder gerastert
// statt weich zu blenden, passend zu Gras, Blumen und Voxelterrain.
//
// Bewusst OHNE jedes Rauschen: Dithering macht bei so großen Flächen und
// wenigen Stufen den ganzen Himmel körnig. Gegen die konzentrischen Ringe
// laufen die Bandgrenzen stattdessen wellig statt kreisrund – die Flächen
// bleiben dabei sauber einfarbig.
//
// Die Horizontfarbe muss mit der Nebelfarbe im WorldEnvironment
// übereinstimmen, sonst bleibt die Ladekante des Terrains sichtbar.

group_uniforms Farben;
uniform vec3 farbe_zenit : source_color = vec3(0.20, 0.45, 0.82);
uniform vec3 farbe_horizont : source_color = vec3(0.72, 0.86, 0.96);
uniform vec3 farbe_boden : source_color = vec3(0.38, 0.42, 0.40);

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


// Wert auf feste Stufen rasten.
// Die Welle verschiebt die Schwelle abhängig von der Himmelsrichtung, wodurch
// jede Bandgrenze zu einer weichen Schlangenlinie wird statt zu einem Ring.
float stufen(float wert, vec3 dir) {
	float n = max(1.0, float(baender) - 1.0);
	float breite = 1.0 / float(baender);

	float winkel = atan(dir.x, dir.z);
	float welle = (sin(winkel * wellen_frequenz) * 0.6
			+ sin(winkel * wellen_frequenz * 2.3 + 1.3) * 0.4) * band_wellen * breite;

	return clamp(floor((wert + welle) * float(baender)) / n, 0.0, 1.0);
}

void sky() {
	float h = EYEDIR.y;
	vec3 col;

	if (h >= 0.0) {
		float t = pow(clamp(h, 0.0, 1.0), 1.0 / horizont_schaerfe);
		col = mix(farbe_horizont, farbe_zenit, stufen(t, EYEDIR));
	} else {
		// Unterhalb des Horizonts in Richtung Bodenfarbe auslaufen
		float u = clamp(-h * boden_breite, 0.0, 1.0);
		col = mix(farbe_horizont, farbe_boden, stufen(u, EYEDIR));
	}

	if (sonne_zeigen) {
		vec3 zur_sonne = normalize(sonnen_richtung);
		if (sonne_folgt_licht && LIGHT0_ENABLED) {
			// LIGHT0_DIRECTION ist die Richtung, in die das Licht fällt –
			// die Sonne steht also entgegengesetzt.
			zur_sonne = sonne_umkehren ? LIGHT0_DIRECTION : -LIGHT0_DIRECTION;
		}

		float d = distance(EYEDIR, zur_sonne);

		// Schein: breiter Hof, in dieselben Bänder gerastert
		float schein = 1.0 - clamp(d / max(schein_weite, 0.001), 0.0, 1.0);
		col = mix(col, schein_farbe, stufen(schein, EYEDIR) * schein_staerke);

		// Scheibe: harte Kante, damit sie wie ein gezeichnetes Objekt wirkt
		float scheibe = 1.0 - smoothstep(sonnen_groesse,
				sonnen_groesse + sonnen_rand, d);
		col = mix(col, sonnen_farbe, scheibe);
	}

	COLOR = col;
}
