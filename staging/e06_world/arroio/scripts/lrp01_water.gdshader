shader_type spatial;
render_mode cull_disabled;
uniform sampler2D shore_depth : filter_linear, repeat_disable;
uniform vec2 depth_origin = vec2(225.0,-240.0);
uniform vec2 depth_size = vec2(250.0,180.0);
varying vec3 world_position;
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise21(vec2 p) {
	vec2 i=floor(p);
	vec2 f=fract(p);
	vec2 u=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),u.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),u.x),u.y);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p=world_position.xz;
	float a=sin(p.x*1.8+p.y*.6+TIME*.65);
	float b=cos(p.y*2.3-p.x*.45+TIME*.47);
	float ripple=(a+b)*.5;
	float wave_visibility=1.0-smoothstep(.4,1.8,length(fwidth(p)));
	ripple*=wave_visibility;
	float broad=noise21(p*.055)+noise21(p*.13)*.25;
	float depth=texture(shore_depth,(p-depth_origin)/depth_size).r;
	vec3 shallow=vec3(.24,.29,.21);
	vec3 deep=vec3(.11,.20,.18);
	ALBEDO=mix(shallow,deep,smoothstep(0.0,.8,depth))+(broad-.6)*.014+ripple*.002;
	NORMAL_MAP=normalize(vec3(a*.012*wave_visibility,b*.012*wave_visibility,1.0))*.5+.5;
	ROUGHNESS=.48+ripple*.012;
	METALLIC=.08;
	SPECULAR=.65;
	ALPHA=1.0;
}
