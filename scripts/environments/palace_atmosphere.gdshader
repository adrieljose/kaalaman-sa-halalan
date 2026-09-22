shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform float escalation = 0.0;
uniform float impact = 0.0;
uniform vec2 camera_offset = vec2(0.0);
uniform vec4 foliage = vec4(0.0);
uniform vec4 curtain = vec4(0.0);
uniform vec4 water = vec4(0.0);
uniform vec4 monitor = vec4(0.0);
uniform vec4 sky = vec4(0.0);
uniform vec4 lamp = vec4(0.0);
uniform vec4 papers = vec4(0.0);
uniform vec4 door = vec4(0.0);
uniform float door_open = 0.0;
float mask(vec2 p, vec4 r) {
 if (r.z <= 0.0) return 0.0;
 vec2 a = smoothstep(r.xy, r.xy + vec2(.012), p);
 vec2 b = 1.0 - smoothstep(r.xy + r.zw - vec2(.012), r.xy + r.zw, p);
 return a.x*a.y*b.x*b.y;
}
void fragment() {
 vec2 p = UV;
 // Only scenery moves. Floor and all UI/fighters remain at their authored positions.
 float depth = mix(.07, .13, smoothstep(.18,.48,p.y)) * (1.0-smoothstep(.50,.60,p.y));
 p += camera_offset * depth;
 p.x += mask(UV,sky)*sin(clock*.045)*.004;
 float wind = sin(clock*.83) + .35*sin(clock*1.31+2.0);
 p.x += mask(UV,foliage)*sin(clock*1.2+UV.y*31.0)*(.00065+escalation*.00055+impact*.001);
 p.x += max(mask(UV,curtain),mask(vec2(1.0-UV.x,UV.y),curtain))*wind*(.001+escalation*.001+impact*.002);
 p.y += mask(UV,water)*sin(UV.x*320.0+clock*4.0)*(.001+impact*.002);
 p.y += mask(UV,papers)*(sin(clock*1.5)*.0004+sin(clock*22.0)*impact*.003);
 p.x += mask(UV,lamp)*sin(clock*2.0)*impact*.0015;
 vec4 col = texture(TEXTURE,clamp(p,vec2(.001),vec2(.999)));
 float back = 1.0-smoothstep(.54,.82,UV.y);
 col.rgb *= mix(vec3(1.0),vec3(1.09,.78,.61),escalation*back*.52);
 col.rgb += vec3(.18,.09,.015)*mask(UV,water)*escalation;
 col.rgb += vec3(.07,.06,.025)*mask(UV,monitor)*(sin(clock*.8)*.12+impact*.8);
 col.rgb += vec3(.15,.10,.025)*mask(UV,lamp)*(.08*sin(clock*.7)+escalation*.7+impact*.15);
 col.rgb *= 1.0-mask(UV,door)*door_open*.38;
 col.rgb += vec3(.022,.012,.003)*sin(clock*.28)*back;
 COLOR = col;
}
