shader_type spatial;
render_mode cull_back;

uniform int cell_amount = 10;
uniform vec2 cell_period = vec2(10., 10.);
uniform float cell_size = 0.5;

uniform float waviness = 0.025;
uniform float glow = 0.5;
uniform float transparency = 0.025;

uniform float base_freq = 1.3;
uniform	float glow_freq = 3.1;

uniform vec3 color = vec3(0.0, 1.0, 1.0);

uniform float emission_magnitude = 3.0;

vec2 modulo(vec2 divident, vec2 divisor){
	vec2 positiveDivident = mod(divident, divisor) + divisor;
	return mod(positiveDivident, divisor);
}

vec2 random(vec2 value){
	value = vec2( dot(value, vec2(127.1,311.7) ),
				  dot(value, vec2(269.5,183.3) ) );
	return -1.0 + 2.0 * fract(sin(value ) * 43758.5453123);
}

float seamless_noise(vec2 uv, vec2 _period) {
	uv = uv * float(cell_amount);
	vec2 cellsMinimum = floor(uv);
	vec2 cellsMaximum = ceil(uv);
	vec2 uv_fract = fract(uv);
	
	cellsMinimum = modulo(cellsMinimum, _period);
	cellsMaximum = modulo(cellsMaximum, _period);
	
	vec2 blur = smoothstep(0.0, 1.0, uv_fract);
	
	vec2 lowerLeftDirection = random(vec2(cellsMinimum.x, cellsMinimum.y));
	vec2 lowerRightDirection = random(vec2(cellsMaximum.x, cellsMinimum.y));
	vec2 upperLeftDirection = random(vec2(cellsMinimum.x, cellsMaximum.y));
	vec2 upperRightDirection = random(vec2(cellsMaximum.x, cellsMaximum.y));
	
	vec2 fraction = fract(uv);
	
	return mix( mix( dot( lowerLeftDirection, fraction - vec2(0, 0) ),
                     dot( lowerRightDirection, fraction - vec2(1, 0) ), blur.x),
                mix( dot( upperLeftDirection, fraction - vec2(0, 1) ),
                     dot( upperRightDirection, fraction - vec2(1, 1) ), blur.x), blur.y) * 0.8 + 0.5;
}

void vertex(){
	float shift = seamless_noise(UV, cell_period) / 9.0;
	float positional_offset = (VERTEX.z + VERTEX.y) * 13.0;
	VERTEX.x += waviness * sin(TIME * 11.0 + positional_offset);
	VERTEX.x += sign(VERTEX.x) * shift;
	
	positional_offset = (VERTEX.x + VERTEX.z) * 13.0;
	VERTEX.y += waviness * sin(TIME * 13.0 + positional_offset);
	VERTEX.y += sign(VERTEX.y) * shift;
	
	positional_offset = (VERTEX.x + VERTEX.y) * 13.0;
	VERTEX.z += waviness * sin(TIME * 7.0 + positional_offset);
	VERTEX.z += sign(VERTEX.z) * shift;	

}

void fragment(){
	float noise = seamless_noise(UV, cell_period);
	ALBEDO = color;
	EMISSION = color * emission_magnitude;
	float phasic = smoothstep(1.0 - cell_size, 1.0, noise) * abs(cos(TIME * glow_freq)) * glow;
	float baseline = abs(cos(TIME * base_freq)) * transparency;
	ALPHA = phasic + baseline;
}