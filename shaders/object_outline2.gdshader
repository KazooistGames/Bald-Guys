shader_type spatial;
render_mode unshaded;

// MIT License. Made by Leo Peltola
// Inspired by https://threejs.org/examples/webgl_postprocessing_pixel.html

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.3;
uniform float outline_width : hint_range(0.0, 10.0, 0.1) = 2.0; // Adjusted outline width range

varying mat4 model_view_matrix;

float getDepth(vec2 screen_uv, sampler2D depth_texture, mat4 inv_projection_matrix){
    // Credit: https://godotshaders.com/shader/depth-modulated-pixel-outline-in-screen-space/
    float raw_depth = texture(depth_texture, screen_uv)[0];
    vec3 normalized_device_coordinates = vec3(screen_uv * 2.0 - 1.0, raw_depth);
    vec4 view_space = inv_projection_matrix * vec4(normalized_device_coordinates, 1.0);    
    view_space.xyz /= view_space.w;    
    return -view_space.z;
}

vec3 getPos(float depth, mat4 mvm, mat4 ipm, vec2 suv, mat4 wm, mat4 icm){
    vec4 pos = inverse(mvm) * ipm * vec4((suv * 2.0 - 1.0), depth * 2.0 - 1.0, 1.0);
    pos.xyz /= (pos.w + 0.0001 * (1.0 - abs(sign(pos.w))));
    return (pos * icm).xyz + wm[3].xyz;
}

void vertex(){
    model_view_matrix = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
    vec4 clip_position = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
    vec3 clip_normal = mat3(PROJECTION_MATRIX) * (mat3(MODELVIEW_MATRIX) * NORMAL);
    
    vec2 offset = normalize(clip_normal.xy) / VIEWPORT_SIZE * clip_position.w * outline_width * 2.0;
    
    clip_position.xy += offset;
    
    POSITION = clip_position;
}

void fragment() {
    vec2 e = vec2(1.0 / VIEWPORT_SIZE.xy);

    float depth_diff = 0.0;
    float neg_depth_diff = 0.5;
    float depth = getDepth(SCREEN_UV, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
    float du = getDepth(SCREEN_UV + vec2(0.0, -1.0) * e * outline_width, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
    float dr = getDepth(SCREEN_UV + vec2(1.0, 0.0) * e * outline_width, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
    float dd = getDepth(SCREEN_UV + vec2(0.0, 1.0) * e * outline_width, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
    float dl = getDepth(SCREEN_UV + vec2(-1.0, 0.0) * e * outline_width, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
    depth_diff += clamp(du - depth, 0.0, 1.0);
    depth_diff += clamp(dd - depth, 0.0, 1.0);
    depth_diff += clamp(dr - depth, 0.0, 1.0);
    depth_diff += clamp(dl - depth, 0.0, 1.0);
    neg_depth_diff += depth - du;
    neg_depth_diff += depth - dd;
    neg_depth_diff += depth - dr;
    neg_depth_diff += depth - dl;
    neg_depth_diff = clamp(neg_depth_diff, 0.0, 1.0);
    neg_depth_diff = clamp(smoothstep(0.5, 0.5, neg_depth_diff) * 10.0, 0.0, 1.0);
    depth_diff = smoothstep(0.2, 0.3, depth_diff);

    vec3 original_color = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
    vec3 final = original_color * shadow_strength;
    ALBEDO = final;

    float alpha_mask = depth_diff;
    ALPHA = clamp((alpha_mask) * 5.0, 0.0, 1.0);
}
