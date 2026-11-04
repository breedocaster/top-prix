// SNES-style palette swap for indexed vehicle sprites. Sprites drawn with modulate
// Color(0, 1, 0, (row + 128) / 255) are looked up in the palette LUT (row = team colour,
// column = material * 8 + shade level); everything else draws normally.
shader_type canvas_item;

uniform sampler2D palette : filter_nearest;
varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (vcol.g > 0.99 && vcol.r < 0.01 && vcol.b < 0.01 && vcol.a > 0.49) {
		if (t.a < 0.5) discard;
		int m = int(floor(t.r * 255.0 / 10.0 + 0.5));
		int l = int(floor(t.g * 255.0 / 30.0 + 0.5));
		int row = int(floor(vcol.a * 255.0 + 0.5)) - 128;
		COLOR = texelFetch(palette, ivec2(m * 8 + l, row), 0);
	} else {
		COLOR = t * vcol;
	}
}
