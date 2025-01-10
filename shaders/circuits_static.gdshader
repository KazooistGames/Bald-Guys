shader_type spatial;

render_mode unshaded, shadows_disabled;

uniform sampler2D screen_texture : source_color, hint_screen_texture, filter_nearest;

uniform float track_thickness = 0.001;
uniform float tail_length = 0.1;

uniform float phase_scalar = 1.0;



int comet_cycle(float period, float offset){
	return int( (TIME + offset) / period);
}

int comet_phase(float period, float offset){
	int cycle = comet_cycle(period, offset);
	return cycle % 2;
}

float phase_progress(float period, float offset){
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

bool tail_in_bounds(float uv_position, float start, float end, float speed, int phase){
	
	bool past_start = true;
	bool before_end = true;
	
	if(speed < 0.0){
		past_start = uv_position >= start;
		if(phase == 0){
			past_start = uv_position >= start;
			before_end = uv_position >= end;
		}
	}else{
		if(phase == 0){
			past_start = uv_position >= start;
			before_end = uv_position <= end;
		}else{
			past_start = uv_position <= start;
		}
	}	
	return past_start && before_end;
}

bool energized(vec2 uv, vec4 x_rails, vec4 y_rails, vec4 speeds, float offset){

	for(int index = 0; index < 4; index++){	
		vec2 rails = vec2(x_rails[index], y_rails[index]);
		float speed = speeds[index];
		float period = phase_scalar / abs(speed);
		int phase = comet_phase(period, offset);
		float progress = phase_progress(period, offset);
		
		float UV_track = uv.x;
		float UV_tail = uv.y;
		float tail_start = 0.0;	
		float tail_end = uv.x;	
		if(phase > 0){
			UV_track = uv.y;
			UV_tail = uv.x;
			tail_start = uv.y;
			tail_end = 1.0;
		}
		
		float track_pos = track_position(rails, phase);
		float tail_pos = tail_position(rails, phase, progress, speed);
		bool on_track = abs(UV_track - track_pos) <= track_thickness;
		float parabola = max(1.0-pow(2.0*progress-1.0, 2), 0.1);
		bool on_tail = abs(UV_tail - tail_pos) <= tail_length * parabola / 2.0;
		
		bool in_bounds = tail_in_bounds(UV_tail, tail_start, tail_end, speed, phase);
	
		if (on_track && on_tail && in_bounds){
			return true;
		}
	}
	return false;
}

vec4 random_vec4(float zero, float span, int seed){
	
	float float_seed = float(seed);
	vec4 return_val;
	return_val.x = zero + sin(float_seed * 43758.82309) * span;
	return_val.y = zero + sin(float_seed * 72191.32920) * span;
	return_val.z = zero + sin(float_seed * 342.09871) * span;
	return_val.w = zero + sin(float_seed * 8790.43229) * span;
	return return_val;
}


void fragment() {
	
	vec3 sample_color = texture(screen_texture, SCREEN_UV).rgb;
	
	float reseed_interval = 8.0 * phase_scalar;
	float seed_phase = TIME;
	int seed = int(seed_phase / reseed_interval);
	
	vec4 x_rails = random_vec4(0.5, 0.35, seed);
	vec4 y_rails = random_vec4(0.5, 0.35, seed);
	vec4 speeds = vec4(1.0, 1.5, -1.0, -1.5);

	float fade = abs(sin(seed_phase));

	if (energized(UV, x_rails, y_rails, speeds, 0)){
		sample_color.r = fade;		
		EMISSION = sample_color;
	}
	else if(energized(UV, x_rails, y_rails, speeds/2.0, 0.0))
	{
		sample_color.r = fade;	
		EMISSION = sample_color;
	}
	else if(energized(UV, x_rails, y_rails, speeds*2.0, 0.0))
	{
		sample_color.r = fade;	
		EMISSION = sample_color;
	}
	ALBEDO = sample_color;
}




