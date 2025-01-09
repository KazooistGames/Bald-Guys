shader_type spatial;

uniform float swirl_speed = 0.0;
uniform int swirl_arms = 12;
uniform float swirl_size = 9.0;

float swirl(vec2 uv, float size, int arms)
{
	float angle = atan(-uv.y + 0.5, uv.x - 0.5) ;
	float len = length(uv - vec2(0.5, 0.5));
	
	return sin(len * size + angle * float(arms) + TIME * swirl_speed);
}

void fragment()
{
	float swirl = swirl(UV, swirl_size, swirl_arms);
	vec3 sample_color = vec3(0.0, 0.5, 1.0);
	ALBEDO = sample_color;
	ALPHA = smoothstep(0.0, 1.0, swirl) * 0.25;
	
}


