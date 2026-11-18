shader_type spatial;
render_mode cull_disabled;
void fragment() {
    vec2 grid=fract(UV);
    float vertical=step(0.48,grid.x);
    float horizontal=step(0.48,grid.y);
    vec3 wine=vec3(0.34,0.085,0.063);
    vec3 cream=vec3(0.62,0.48,0.33);
    vec3 color=mix(wine,cream,0.33*(vertical+horizontal));
    color=mix(color,vec3(0.12,0.033,0.027),vertical*horizontal*0.55);
    float thin=max(1.0-step(0.035,abs(grid.x-0.23)),1.0-step(0.035,abs(grid.y-0.23)));
    ALBEDO=mix(color,vec3(0.75,0.64,0.46),thin*0.65);
    ROUGHNESS=0.95;
}
