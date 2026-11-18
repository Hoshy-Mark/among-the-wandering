shader_type spatial;
uniform vec4 tint : source_color = vec4(0.5,0.5,0.5,1.0);
uniform bool plaid = false;
uniform bool use_texture = false;
uniform sampler2D fabric_texture : source_color,filter_linear_mipmap,repeat_enable;
void fragment() {
    vec3 color=tint.rgb;
    if (plaid) {
        vec2 grid=fract(UV);
        float a=step(0.48,grid.x);
        float b=step(0.48,grid.y);
        color=mix(color,vec3(0.55,0.43,0.30),0.30*(a+b));
        color=mix(color,color*0.40,a*b*0.55);
        float thin=max(1.0-step(0.030,abs(grid.x-0.23)),1.0-step(0.030,abs(grid.y-0.23)));
        color=mix(color,vec3(0.67,0.56,0.40),thin*0.65);
    }
    if (use_texture) { color *= texture(fabric_texture,UV).rgb; }
    ALBEDO=color;
    ROUGHNESS=0.96;
}
