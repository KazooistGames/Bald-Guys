shader_type spatial;
render_mode cull_front, unshaded;

uniform sampler2D OBJECT_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform sampler2D screen_texture : source_color, hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : source_color, hint_depth_texture, filter_nearest;

uniform float outline_multiplier = 0.3;
uniform float outline_width = 2.0;

float get_depth(vec2 screen_uv, mat4 inv_projection_matrix) {
	float depth = texture(depth_texture, screen_uv).r;
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
	vec4 view = inv_projection_matrix * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

void vertex() {
	vec4 clip_position = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 clip_normal = mat3(PROJECTION_MATRIX) * (mat3(MODELVIEW_MATRIX) * NORMAL);
	vec2 offset = normalize(clip_normal.xy) / VIEWPORT_SIZE * clip_position.w * outline_width * 2.0;	
	clip_position.xy += offset;	
	POSITION = clip_position;
}

void fragment() {
	float depth = get_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec2 texel_size = 1.0 / VIEWPORT_SIZE.xy;
	
	float depth_diff = 0.0;
	float depth_diff_reversed = 0.0;
	float nearest_depth = depth;
	vec2 nearest_uv = SCREEN_UV;
	
	vec2 uvs[4];
	uvs[0] = vec2(SCREEN_UV.x, min(1.0 - 0.001, SCREEN_UV.y + texel_size.y * outline_width));
	uvs[1] = vec2(SCREEN_UV.x, max(0.0, SCREEN_UV.y - texel_size.y * outline_width));
	uvs[2] = vec2(min(1.0 - 0.001, SCREEN_UV.x + texel_size.x * outline_width), SCREEN_UV.y);
	uvs[3] = vec2(max(0.0, SCREEN_UV.x - texel_size.x * outline_width), SCREEN_UV.y);
	for (int i = 0; i < 4; i++) {
		float d = get_depth(uvs[i], INV_PROJECTION_MATRIX);
		depth_diff += depth - d;
		depth_diff_reversed += d - depth;
		
		if (d < nearest_depth) {
			nearest_depth = d;
			nearest_uv = uvs[i];
		}
	}
	
	vec3 nearest = texture(screen_texture, nearest_uv).rgb;
	ALBEDO = nearest.rgb * outline_multiplier;
	//if (original.a < 1.0) {
		//ALPHA = original.a;
	//}
}
