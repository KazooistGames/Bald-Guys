shader_type spatial;
render_mode cull_front, unshaded;

uniform sampler2D OBJECT_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float outline_multiplier = 0.4;
uniform float outline_width = 1.0;


void vertex() {
	vec4 clip_position = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 clip_normal = mat3(PROJECTION_MATRIX) * (mat3(MODELVIEW_MATRIX) * NORMAL);
	
	vec2 offset = normalize(clip_normal.xy) / VIEWPORT_SIZE * clip_position.w * outline_width * 2.0;
	
	clip_position.xy += offset;
	
	POSITION = clip_position;
}

void fragment() {
	vec3 original = texture(OBJECT_TEXTURE, SCREEN_UV).rgb;
	ALBEDO = original.rgb * outline_multiplier;
	//if (original.a < 1.0) {
		//ALPHA = original.a;
	//}
}
