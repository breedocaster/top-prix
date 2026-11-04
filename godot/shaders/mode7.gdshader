// Mode 7-style perspective floor. Each pixel below the horizon is projected onto the ground plane
// (affine per scanline, like the SNES PPU with HDMA) and sampled from the painted track texture,
// falling back to a procedural ground pattern outside it.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D track_tex : filter_nearest, repeat_disable;
uniform vec2 tex_origin;
uniform vec2 tex_size = vec2(1024.0);
uniform vec2 cam_pos;
uniform float cam_ang;
uniform float cam_h = 40.0;
uniform float horizon = 70.0;
uniform float focal = 128.0;
uniform vec2 view_size = vec2(256.0, 224.0);
uniform vec4 ground_a : source_color = vec4(0.25, 0.55, 0.25, 1.0);
uniform vec4 ground_b : source_color = vec4(0.22, 0.48, 0.22, 1.0);
uniform vec4 ground_c : source_color = vec4(0.4, 0.65, 0.3, 1.0);
uniform int ground_kind = 0;
uniform vec4 fog_col : source_color = vec4(0.7, 0.85, 0.95, 1.0);
uniform float fog_far = 1100.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

vec3 ground(vec2 w) {
	vec3 a = ground_a.rgb;
	vec3 b = ground_b.rgb;
	vec3 c = ground_c.rgb;
	vec3 col;
	if (ground_kind == 0) {          // mown stadium grass
		col = mod(floor((w.x + w.y) / 64.0), 2.0) < 1.0 ? a : b;
	} else if (ground_kind == 2) {   // desert ripples
		col = sin(w.y * 0.07 + sin(w.x * 0.018) * 3.0) > 0.35 ? b : a;
	} else if (ground_kind == 3) {   // snow drifts
		col = hash(floor(w / 96.0)) > 0.7 ? b : a;
	} else {                         // patchy country / swamp / mountain
		col = hash(floor(w / 80.0)) > 0.5 ? a : b;
	}
	if (hash(floor(w / 4.0)) > 0.94) col = c;
	return col;
}

void fragment() {
	vec2 px = floor(UV * view_size) + 0.5;
	if (px.y <= horizon) {
		COLOR = vec4(0.0);
	} else {
		float dy = px.y - horizon;
		float z = cam_h * focal / dy;
		float lat = (px.x - view_size.x * 0.5) * z / focal;
		vec2 fwd = vec2(cos(cam_ang), sin(cam_ang));
		vec2 rgt = vec2(-fwd.y, fwd.x);
		vec2 w = cam_pos + fwd * z + rgt * lat;
		vec3 col = ground(w);
		vec2 t = (w - tex_origin) / tex_size;
		if (t.x >= 0.0 && t.y >= 0.0 && t.x < 1.0 && t.y < 1.0) {
			vec4 tc = texture(track_tex, t);
			col = mix(col, tc.rgb, tc.a);
		}
		float f = clamp((z - fog_far * 0.3) / (fog_far * 0.7), 0.0, 1.0);
		f = floor(f * 5.0) / 5.0;
		col = mix(col, fog_col.rgb, f * 0.75);
		// snap to the SNES 15-bit color space
		col = floor(col * 31.0 + 0.5) / 31.0;
		COLOR = vec4(col, 1.0);
	}
}
