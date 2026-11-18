shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float surface_kind = 0.0;
uniform float surface_strength = 0.94;
uniform float underlay_kind = 0.0;
uniform sampler2D paving_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float garden_wear = 0.0;
uniform float wear_edge_m = 2.0;
uniform float terrain_variation = 1.0;
uniform float parcel_tone = 0.0;
uniform int boundary_count = 0;
uniform vec2 boundary[32];
varying vec3 world_position;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453);
}
float noise21(vec2 p) {
	vec2 i=floor(p);
	vec2 f=fract(p);
	vec2 u=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1.0,0.0)),u.x),mix(hash21(i+vec2(0.0,1.0)),hash21(i+vec2(1.0,1.0)),u.x),u.y);
}
void vertex() {
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
vec3 sample_surface(float kind, vec2 p, vec3 dirt) {
    if (kind>3.5) { return mix(texture(paving_texture,p/2.0).rgb,dirt,0.45)*vec3(0.82,0.80,0.72); }
    if (kind>2.5) { return dirt*vec3(0.59,0.54,0.43); }
    if (kind>1.5) { return texture(gravel_texture,p/2.4).rgb*vec3(0.81,0.79,0.72); }
    return dirt*vec3(0.86,0.84,0.76);
}
void fragment() {
	vec2 p=world_position.xz;
	vec3 grass=texture(grass_texture,p/4.5).rgb;
	vec3 dirt=texture(dirt_texture,p/5.0).rgb;
	float macro=noise21(p/24.0);
	float edge=10000.0;
	for (int i=0;i<32;i++) {
		if (i>=boundary_count) { break; }
		vec2 a=boundary[i];
		vec2 b=boundary[(i+1)%max(boundary_count,1)];
		vec2 ab=b-a;
		float t=clamp(dot(p-a,ab)/max(dot(ab,ab),0.001),0.0,1.0);
		edge=min(edge,length(p-a-t*ab));
	}
	float wear=0.025+0.075*macro+garden_wear*smoothstep(0.0,wear_edge_m,edge);
	ALBEDO=mix(grass,dirt,wear)*mix(0.88,1.0,noise21(p/22.0))*vec3(0.82,0.85,0.76);
	if (terrain_variation > 0.5) {
		// Blend existing textures in world space at different rotations and scales.
		vec2 warped=p+vec2(noise21(p/31.0),noise21(p/29.0+17.0))*12.0;
		float blend=noise21(p/9.0);
		vec3 second_grass=texture(grass_texture,vec2(-p.y,p.x)/3.1+vec2(0.37,0.71)).rgb;
		grass=mix(grass,second_grass,0.35+blend*0.3);
		float luminance=dot(grass,vec3(0.2126,0.7152,0.0722));
		grass=mix(grass,vec3(luminance),0.43);
		float moisture=noise21(warped/48.0);
		float dry=smoothstep(0.2,0.85,noise21(warped/16.0));
		vec3 green_tone=mix(vec3(0.72,0.79,0.52),vec3(0.64,0.76,0.53),moisture);
		vec3 straw_tone=vec3(0.89,0.82,0.60);
		grass*=mix(green_tone,straw_tone,dry*0.3);
		float bare=smoothstep(0.3,0.9,noise21(warped/14.0+71.0))*0.16;
		float patch_wear=clamp(0.04+dry*0.08+bare+garden_wear*smoothstep(0.0,wear_edge_m,edge),0.0,0.92);
		dirt=mix(dirt,vec3(dot(dirt,vec3(0.333))),0.2)*vec3(0.88,0.84,0.72);
		ALBEDO=mix(grass,dirt,patch_wear)*(0.94+parcel_tone+0.06*noise21(p/35.0));
	}
	if (surface_kind > 0.5) {
		vec3 surface_color=sample_surface(surface_kind,p,dirt);
		float regrowth=mix(0.63,1.0,smoothstep(0.25,0.8,noise21(p/4.0)));
		if (underlay_kind>0.5) { ALBEDO=mix(ALBEDO,sample_surface(underlay_kind,p,dirt),0.82*regrowth); }
		ALBEDO=mix(ALBEDO,surface_color,smoothstep(0.0,0.55,edge)*surface_strength*regrowth);
	}
	ROUGHNESS=0.95;
}
