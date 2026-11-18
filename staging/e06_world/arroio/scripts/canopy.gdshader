shader_type spatial;
render_mode cull_disabled;
uniform bool target_active = false;
uniform vec3 target_position;
uniform vec3 view_direction = vec3(-0.5,-0.7,-0.5);
varying vec3 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    ALBEDO=COLOR.rgb;
    ROUGHNESS=0.95;
    float opacity=1.0;
    if (target_active) {
        vec3 delta=world_position-target_position;
        float depth=dot(delta,view_direction);
        float lateral=length(delta-view_direction*depth);
        if (depth<0.0) { opacity=mix(0.12,1.0,smoothstep(1.0,2.4,lateral)); }
    }
    // Stable stippled transparency keeps leaf depth correct in dense forests.
    float threshold=fract(52.9829189*fract(dot(floor(FRAGCOORD.xy),vec2(0.06711056,0.00583715))));
    ALPHA=opacity;
    ALPHA_SCISSOR_THRESHOLD=max(0.001,threshold);
}
