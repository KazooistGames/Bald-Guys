shader_type spatial;

uniform sampler2D screen_texture : source_color, hint_screen_texture, filter_nearest;

uniform vec4 x_rails = vec4(0.2, 0.4, 0.6, 0.8);
uniform vec4 y_rails = vec4(0.45, 0.35, 0.55, 0.45);
uniform vec4 speeds = vec4(0.5, -1.0, 2.0, -2.0);
uniform vec4 offsets = vec4(0.0, 0.5, 0.0, 0.5);

uniform float track_thickness = 0.005;
uniform float tail_length = 0.05;

uniform float phase_period = 1.0;


int comet_phase(int index){
	float speed = abs(speeds[index]);
	float period = (phase_period / speed);
	float offset = offsets[index] * phase_period;
	int cycle = int( (TIME + offset) / period);
	return cycle % 2;
}

int comet_cycle(int index){
	float speed = abs(speeds[index]);
	float period = (phase_period / speed);
	float offset = offsets[index] * phase_period;
	return int( (TIME + offset) / period);
}


float phase_progress(int index){
	float speed = abs(speeds[index]);
	float period = (phase_period / speed);
	float offset = offsets[index] * phase_period;
	return sign(speeds[index]) * mod(TIME + offset, period) / period;
}


float tail_position(int index, int phase){
	
	float offset, span;
	
	if(phase > 0){
		
		if(speeds[index] < 0.0){
			span = 1.0 - x_rails[index];
		}else{
			span = x_rails[index];
		}
		return x_rails[index] - phase_progress(index) * span;
	} else{

		if(speeds[index] < 0.0){
			offset = 1.0;
			span = 1.0 - y_rails[index];
		}else{
			offset = 0.0;
			span = y_rails[index];
		}
		return offset + phase_progress(index) * span;
	}
}


float track_position(int index, int phase){
	
	if(phase > 0){
		return y_rails[index];
	}else{
		return x_rails[index];
	}
}


bool energized(vec2 uv){

	for(int index = 0; index < 4; index++){	
		int phase = comet_phase(index);
		float UV_track = uv.x;
		float UV_trail = uv.y;
		
		if(phase > 0){
			UV_track = uv.y;
			UV_trail = uv.x;
		}
		bool on_track = abs(UV_track - track_position(index, phase)) <= track_thickness;
		bool on_tail = abs(UV_trail - tail_position(index, phase)) <= tail_length/2.0;
	
		if (on_track && on_tail){
			return true;
		}
	}
	return false;
}


void fragment() {
	
	vec3 sample_color = texture(screen_texture, SCREEN_UV).rgb;

	if (energized(UV)){
		sample_color.r = 0.0;		
	}
	ALBEDO = sample_color;
}


