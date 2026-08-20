
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec3 farbe_unten : source_color;
uniform vec3 farbe_oben : source_color;
uniform float wind_staerke = 0.10;
uniform float wind_tempo = 1.4;
uniform vec2 wind_richtung = vec2(1.0, 0.35);
uniform float variation = 0.16;
uniform float pixel = 0.1;          // Rastergroesse fuer den Wind
uniform int farb_stufen = 4;        // Anzahl der Farbbaender

varying float v_h;
varying float v_var;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	vec3 welt = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_h = UV.y;                                   // 0 = Wurzel, 1 = Spitze

	vec2 dir = normalize(wind_richtung);
	// Phase pro Block, nicht pro Vertex -> die Pflanze bewegt sich als Ganzes
	float phase = dot(floor(welt.xz), dir) * 0.55 + TIME * wind_tempo;
	float sway = sin(phase) + 0.45 * sin(phase * 2.3 + 1.7);

	float versatz = sway * wind_staerke * pow(v_h, 1.7);
	versatz = floor(versatz / pixel + 0.5) * pixel;   // aufs Pixelraster rasten
	VERTEX.xz += dir * versatz;

	// Helligkeit pro Pflanze, ebenfalls in Stufen
	float r = floor(hash12(floor(welt.xz)) * 3.0) / 2.0;
	v_var = 1.0 + (r - 0.5) * 2.0 * variation;
}

void fragment() {
	float n = max(1.0, float(farb_stufen) - 1.0);
	float stufe = clamp(floor(v_h * float(farb_stufen)) / n, 0.0, 1.0);
	ALBEDO = mix(farbe_unten, farbe_oben, stufe) * v_var;
	ROUGHNESS = 1.0;
}
