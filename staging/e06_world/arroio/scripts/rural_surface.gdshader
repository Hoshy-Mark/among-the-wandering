shader_type spatial;
render_mode cull_back;
uniform sampler2D detail_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 base_tint = vec4(1.0);
uniform float detail_mean = 0.5;
uniform float metalness = 0.0;
uniform float age_strength = 0.08;
varying vec3 local_position;
void vertex() { local_position=VERTEX; }
void fragment() {
    float detail=dot(texture(detail_texture,UV).rgb,vec3(.333333))/max(detail_mean,.05);
    float stain=exp(-max(local_position.y,0.0)*1.6)*age_strength;
    ALBEDO=COLOR.rgb*base_tint.rgb*mix(1.0,clamp(detail,.45,1.7),.72)*(1.0-stain);
    NORMAL_MAP=texture(normal_texture,UV).rgb;
    NORMAL_MAP_DEPTH=.45;
    ROUGHNESS=clamp(texture(roughness_texture,UV).g,.55,.97);
    METALLIC=metalness;
}
