shader_type spatial;

uniform sampler2D screen_texture : source_color, hint_screen_texture, filter_nearest;

uniform float track_thickness = 0.001;
uniform float tail_length = 0.05;

uniform float phase_scalar = 1.0;

int comet_cycle(float offset, float period){
	return int( (TIME + offset) / period);
}

int comet_phase(float offset, float period){
	int cycle = comet_cycle(offset, period);
	return cycle % 2;
}


float phase_progress(float offset, float period){
	return mod(TIME + offset, period) / period;
}


float tail_position(vec2 rails, int phase, float progress, float speed){
	
	float offset, span;
	
	if(phase > 0){
		
		if(speed < 0.0){
			span = rails.x - 1.0;
		}else{
			span = rails.x;
		}
		return rails.x -progress * span;
	} else{

		if(speed < 0.0){
			offset = 1.0;
			span = rails.y - 1.0;
		}else{
			offset = 0.0;
			span = rails.y;
		}
		return offset + progress * span;
	}
}


float track_position(vec2 rails, int phase){
	
	if(phase > 0){
		return rails.y;
	}else{
		return rails.x;
	}
}


bool energized(vec2 uv, vec4 x_rails, vec4 y_rails, vec4 speeds, vec4 offsets){

	for(int index = 0; index < 4; index++){	
		vec2 rails = vec2(x_rails[index], y_rails[index]);
		float speed = speeds[index];
		float offset = offsets[index];
		float period = phase_scalar / speed;
		int phase = comet_phase(offset, period);
		float progress = phase_progress(offset, period);
		
		float UV_track = uv.x;
		float UV_trail = uv.y;
		
		if(phase > 0){
			UV_track = uv.y;
			UV_trail = uv.x;
		}
		bool on_track = abs(UV_track - track_position(rails, phase)) <= track_thickness;
		bool on_tail = abs(UV_trail - tail_position(rails, phase, progress, speed)) <= tail_length/2.0;
	
		if (on_track && on_tail){
			return true;
		}
	}
	return false;
}


void fragment() {
	
	vec3 sample_color = texture(screen_texture, SCREEN_UV).rgb;
	
	vec4 x_rails = vec4(0.2, 0.4, 0.6, 0.8);
	vec4 y_rails = vec4(0.45, 0.35, 0.55, 0.45);
	vec4 speeds = vec4(0.75, -1.5, 2.0, -2.0);
	vec4 offsets = vec4(0.0, 0.5, 0.0, 0.5);

	if (energized(UV, x_rails, y_rails, speeds, offsets)){
		sample_color.r = 0.0;		
	}
	ALBEDO = sample_color;
}


