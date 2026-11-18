shader_type spatial;
uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paving_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float zone = 0.0;
uniform float lot_seed = 0.0;
uniform vec2 shade_center = vec2(-1000.0);
uniform int boundary_count = 0;
uniform vec2 boundary[32];
varying vec3 wp;
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise21(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);}
float seg(vec2 p,vec2 a,vec2 b){vec2 d=b-a;return length(p-a-d*clamp(dot(p-a,d)/max(dot(d,d),.001),0.0,1.0));}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
 vec2 p=wp.xz;float n=noise21(p*1.2+lot_seed);float shade=exp(-dot((p-shade_center)/vec2(3.8,3.3),(p-shade_center)/vec2(3.8,3.3)));
 vec3 grass=texture(grass_texture,p/4.5).rgb;float lum=dot(grass,vec3(.2126,.7152,.0722));grass=mix(grass,vec3(lum),.42)*vec3(.73,.79,.55);
 vec3 dirt=texture(dirt_texture,p/4.0).rgb*vec3(.72,.67,.55);vec3 organic=dirt*vec3(.65,.64,.53);
 vec3 base=mix(grass,dirt,.08+.24*noise21(p/3.2));base=mix(base,organic,shade*(.40+.35*n));
 float edge=1000.0;for(int i=0;i<32;i++){if(i>=boundary_count){break;}edge=min(edge,seg(p,boundary[i],boundary[(i+1)%max(boundary_count,1)]));}
 vec3 color=base;float mask=smoothstep(.01,.35+.75*n,edge);
 if(zone>.5 && zone<1.5){vec3 concrete=texture(paving_texture,p/1.7).rgb*vec3(.76,.75,.70);vec2 cell=fract((p+lot_seed)/vec2(1.18,1.55));float joint=1.0-smoothstep(.007,.025,min(min(cell.x,1.0-cell.x),min(cell.y,1.0-cell.y)));concrete=mix(concrete,dirt,joint*.52+(1.0-smoothstep(.05,.8,edge))*.25);color=mix(base,concrete,mask);}
 else if(zone>1.5 && zone<2.5){vec3 gravel=texture(gravel_texture,p/1.5).rgb*vec3(.83,.80,.72);color=mix(base,mix(gravel,dirt,.15+.2*n),smoothstep(.005,.12,edge));}
 else if(zone>2.5 && zone<3.5){color=mix(base,mix(dirt,texture(gravel_texture,p/1.8).rgb*.70,.20),mask);}
 else if(zone>3.5 && zone<4.5){color=mix(base,organic,mask*(.65+.2*n));}
 else if(zone>4.5){color=mix(base,organic,mask*.84);}
 ALBEDO=color*(.96+.04*noise21(p*8.0));ROUGHNESS=.97;
}
