shader_type canvas_item;

uniform float corner_radius = 16.0;

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 uv = UV * size;
	
	// Calculate distance from corners
	float dist = 0.0;
	
	// Top-left corner
	if (uv.x < corner_radius && uv.y < corner_radius) {
		vec2 corner = vec2(corner_radius, corner_radius);
		dist = distance(uv, corner);
		if (dist > corner_radius) {
			discard;
		}
	}
	// Top-right corner
	else if (uv.x > size.x - corner_radius && uv.y < corner_radius) {
		vec2 corner = vec2(size.x - corner_radius, corner_radius);
		dist = distance(uv, corner);
		if (dist > corner_radius) {
			discard;
		}
	}
	// Bottom-left corner
	else if (uv.x < corner_radius && uv.y > size.y - corner_radius) {
		vec2 corner = vec2(corner_radius, size.y - corner_radius);
		dist = distance(uv, corner);
		if (dist > corner_radius) {
			discard;
		}
	}
	// Bottom-right corner
	else if (uv.x > size.x - corner_radius && uv.y > size.y - corner_radius) {
		vec2 corner = vec2(size.x - corner_radius, size.y - corner_radius);
		dist = distance(uv, corner);
		if (dist > corner_radius) {
			discard;
		}
	}
	
	COLOR = texture(TEXTURE, UV);
}