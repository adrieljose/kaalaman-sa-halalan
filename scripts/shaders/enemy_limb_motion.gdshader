shader_type canvas_item;
render_mode unshaded;
// Small continuous deformations supplement the authored attack/hit frames.
// No cut-out seams: shoulders, arms, knees and ankles have separate envelopes.
uniform vec4 body = vec4(0.0,0.0,1.0,1.0);
uniform float motion_time = 0.0;
uniform float action = 0.0; // idle 0, attack 1, hit 2, walk 3
uniform float progress = 0.0;
uniform float intensity = 1.0;
uniform vec3 joint_pose = vec3(0.0);
uniform bool choreographed = false;
varying vec4 tint;
void vertex() { tint=COLOR; }
float bell(float v, float center, float width) {
 return 1.0-smoothstep(0.0,1.0,abs(v-center)/width);
}
void fragment() {
 vec2 q=(UV-body.xy)/max(body.zw,vec2(.001));
 float beat=sin(motion_time*3.0);
 float p=clamp(progress,0.0,1.0);
 // Slow anticipation, quick extension, then a softer recovery.
 float strike=smoothstep(.18,.48,p)*(1.0-smoothstep(.60,1.0,p));
 float walking=step(2.5,action);
 float attacking=step(.5,action)*(1.0-step(1.5,action));
 float hurting=step(1.5,action)*(1.0-step(2.5,action));
 float gait=sin(motion_time*10.0);
 float active=attacking*strike+hurting*strike*.6;
 // Authored frames carry the main swing. Add only a few pixels of movement.
 float arm_wave=(choreographed ? 0.0 : beat*.002)+attacking*strike*.009-hurting*strike*.012+walking*gait*.012;
 float left_arm=bell(q.x,.25,.22)*bell(q.y,.46,.19);
 float right_arm=bell(q.x,.74,.21)*bell(q.y,.49,.19);
 float left_leg=bell(q.x,.40,.13)*bell(q.y,.81,.14);
 float right_leg=bell(q.x,.62,.13)*bell(q.y,.81,.14);
 // Fade at the soles so the stance remains on the configured ground line.
 float planted=1.0-smoothstep(.92,.985,q.y);
 vec2 offset=vec2(0.0);
 offset.x=arm_wave*(left_arm-right_arm*.65);
 offset.y=arm_wave*.45*(left_arm+right_arm);
 offset.x+=(left_leg-right_leg)*(walking*gait*.020+active*.014)*planted;
 offset.y+=(left_leg+right_leg)*(active*.009+walking*abs(gait)*.008)*planted;
 // Local joint rotation approximation: displacement grows away from the
 // shoulder/hip pivot, not from the canvas centre. Blended masks keep seams
 // closed on coats and dresses; soles remain fixed.
 float shoulder=clamp(joint_pose.x,-1.0,1.0)*.09;
 float reach=clamp(joint_pose.z,-1.0,1.0)*.10;
 offset+=vec2(-(q.y-.32),q.x-.27)*shoulder*left_arm;
 offset+=vec2(-(q.y-.46),q.x-.25)*reach*left_arm;
 offset+=vec2(-(q.y-.33),q.x-.72)*(-shoulder*.5)*right_arm;
 float brace=clamp(joint_pose.y,-1.0,1.0);
 offset.x+=(left_leg-right_leg)*brace*.016*planted;
 offset.y+=(left_leg+right_leg)*abs(brace)*.008*planted;
 offset.x+=bell(q.y,.42,.33)*bell(q.x,.5,.4)*shoulder*.06*planted;
 vec2 sample_uv=UV-offset*body.zw*intensity;
 COLOR = tint*texture(TEXTURE,sample_uv);
}
