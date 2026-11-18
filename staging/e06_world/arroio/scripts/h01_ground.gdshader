shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paving_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float zone = 0.0;
uniform int boundary_count = 0;
uniform vec2 boundary[32];
varying vec3 world_position;
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise21(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);}
float segment_distance(vec2 p,vec2 a,vec2 b){vec2 d=b-a;return length(p-a-d*clamp(dot(p-a,d)/max(dot(d,d),.001),0.0,1.0));}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
	vec2 p=world_position.xz;
	float n=noise21(p*1.2);
	float shade=max(exp(-dot((p-vec2(36,180))/vec2(4.2,3.4),(p-vec2(36,180))/vec2(4.2,3.4))),exp(-dot((p-vec2(39,170))/vec2(2.7,3.0),(p-vec2(39,170))/vec2(2.7,3.0))));
	vec3 grass=texture(grass_texture,p/4.5).rgb;
	float lum=dot(grass,vec3(.2126,.7152,.0722));
	grass=mix(grass,vec3(lum),.43)*vec3(.72,.79,.53);
	vec3 dirt=texture(dirt_texture,p/4.0).rgb*vec3(.73,.68,.56);
	vec3 organic=dirt*vec3(.67,.64,.54);
	vec3 base=mix(grass,dirt,.08+.18*noise21(p/3.7));
	base=mix(base,organic,shade*(.55+.3*noise21(p*1.5)));
	float edge=1000.0;
	for(int i=0;i<32;i++){if(i>=boundary_count){break;}edge=min(edge,segment_distance(p,boundary[i],boundary[(i+1)%max(boundary_count,1)]));}
	vec3 color=base;
	if(zone>.5 && zone<1.5){
		vec3 concrete=texture(paving_texture,p/1.7).rgb*vec3(.76,.75,.70);
		vec2 cell=fract((p-vec2(25.1633,148.8933))/vec2(1.18,1.55));
		float joint=1.0-smoothstep(.008,.024,min(min(cell.x,1.0-cell.x),min(cell.y,1.0-cell.y)));
		float edge_wear=(1.0-smoothstep(.05,.8,edge))*(.3+.7*n);
		float worn=smoothstep(.48,.85,noise21(p*1.05+17.0))*.22;
		concrete=mix(concrete,dirt,clamp(joint*.58+edge_wear*.4+worn,0.0,.8));
		float mask=smoothstep(.02,.38+.28*n,edge);
		color=mix(base,concrete,mask);
	}else if(zone>1.5 && zone<2.5){
		vec3 gravel=texture(gravel_texture,p/1.5).rgb*vec3(.84,.81,.73);
		float rim=1.0-smoothstep(.06,.32,edge);
		gravel=mix(gravel,dirt,.13+.25*rim*n);
		color=mix(base,gravel,smoothstep(.005,.16,edge));
	}else if(zone>2.5){
		float mask=smoothstep(.02,.5+.7*noise21(p*1.4),edge);
		vec3 service=mix(dirt,organic,.2+.22*n);
		float contact=exp(-dot((p-vec2(30,166))/vec2(1.8,1.0),(p-vec2(30,166))/vec2(1.8,1.0)));
		service*=1.0-contact*.12;
		color=mix(base,service,mask);
	}
	ALBEDO=color*(.96+.04*noise21(p*8.0));
	ROUGHNESS=.96;
}
