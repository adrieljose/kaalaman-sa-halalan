extends Control
## Chapter 4 scenery director. No combat state, global RNG, timers or global signals.
## All positions below are normalized to the backdrop, never to the fighter layer.
const ROOT := "res://assets/images/backgrounds/chapter4/"
const STAGES := [
 {"id":"01_front_courtyard","type":"outdoor","title":"FRONT COURTYARD","wind":true,"flag":Vector2(.77,.27),"lane":Vector3(.16,.73,.52),"roles":[0,2],"foliage":Vector4(.0,.0,.58,.19),"vehicle":true,"sound":"courtyard"},
 {"id":"02_ceremonial_terrace","type":"semi-outdoor","title":"CEREMONIAL TERRACE","wind":true,"flag":Vector2(.76,.25),"lane":Vector3(.18,.73,.52),"roles":[1,2],"foliage":Vector4(.0,.18,.18,.34),"curtain":Vector4(.85,.08,.13,.38),"sound":"garden"},
 {"id":"03_press_room","type":"indoor","title":"PALACE BRIEFING","wind":false,"lane":Vector3(.17,.77,.52),"roles":[3,4],"monitor":Vector4(.57,.18,.19,.16),"sound":"press"},
 {"id":"04_operations_courtyard","type":"outdoor / semi-outdoor","title":"EXECUTIVE OPERATIONS","wind":true,"flag":Vector2(.80,.26),"lane":Vector3(.16,.78,.52),"roles":[0,2],"foliage":Vector4(.69,.10,.30,.39),"vehicle":true,"sound":"operations"},
 {"id":"05_garden_pavilion","type":"semi-outdoor","title":"GARDEN PAVILION","wind":true,"lane":Vector3(.15,.79,.52),"roles":[1,5],"foliage":Vector4(.12,.16,.76,.30),"water":Vector4(.41,.41,.18,.08),"curtain":Vector4(.02,.08,.10,.35),"sound":"garden"},
 {"id":"06_directives_office","type":"indoor","title":"EXECUTIVE DIRECTIVES","wind":false,"lane":Vector3(.15,.32,.49),"roles":[0,1],"curtain":Vector4(.02,.1,.12,.32),"sound":"office"},
 {"id":"07_strategy_balcony","type":"semi-outdoor / evening","title":"STRATEGY BALCONY","wind":true,"lane":Vector3(.12,.28,.51),"roles":[0,1],"foliage":Vector4(.37,.25,.60,.24),"water":Vector4(.5,.42,.1,.06),"curtain":Vector4(.02,.09,.14,.37),"sound":"garden"},
 {"id":"08_signing_hall","type":"indoor","title":"EXECUTIVE SIGNING HALL","wind":false,"lane":Vector3(.72,.89,.50),"roles":[0,1],"curtain":Vector4(.05,.1,.15,.34),"sound":"office"},
 {"id":"09_grand_garden_hall","type":"hybrid","title":"GRAND GARDEN HALL","wind":true,"flag":Vector2(.76,.29),"lane":Vector3(.29,.68,.47),"roles":[0,2],"foliage":Vector4(.19,.18,.60,.27),"curtain":Vector4(.04,.09,.10,.38),"water":Vector4(.44,.41,.13,.07),"sound":"hall"},
]
var stage_index := -1
var spec: Dictionary = {}
var elapsed := 0.0
var phase_mix := 0.0
var phase_target := 0.0
var impact := 0.0
var reaction_cooldown := 0.0
var npc_cooldown := 0.0
var next_walker := 0.0
var next_vehicle := 0.0
var vehicle_progress := -1.0
var next_bird := 0.0
var bird_progress := -1.0
var reaction_count := 0
var npc_reaction_count := 0
var spawned_count := 0
var running := true
var actors: Array[Dictionary] = []
var sprites: Array[Texture2D] = []
var rng := RandomNumberGenerator.new()
var room: TextureRect
var ambience: AudioStreamPlayer
var material_fx: ShaderMaterial
var pointer := Vector2.ZERO
var draw_accumulator := 0.0
var next_door := 18.0
var door_time := 0.0

func adapt_to_layout(design: Vector2) -> void:
	# Portrait puts the question above the arena and fighters at its extreme edges.
	# Keep the small rear-lane actors in the central gap, still far above their soles.
	var lane := Vector3(.40,.60,.65) if design.y > design.x else Vector3(.16,.34,.52)
	if spec.lane == lane: return
	spec.lane = lane
	for actor in actors:
		actor.x = clampf(actor.x,lane.x+.01,lane.y-.01)
		actor.y = lane.z

func setup(index: int, stage_override: Dictionary = {}, room_root: String = ROOT) -> void:
	stage_index = clampi(index,0,8)
	spec = STAGES[stage_index]
	spec = spec.duplicate(true)
	# Left rear walkway remains visible beside the question board on wide layouts.
	spec.lane = Vector3(.16,.34,.52)
	if spec.has("flag"): spec.flag = Vector2(.09,.45)
	if stage_index == 2: spec.monitor = Vector4(.318,.223,.061,.055)
	if stage_index == 4: spec.water = Vector4(.45,.30,.10,.04)
	if stage_index == 6: spec.water = Vector4(.46,.34,.08,.042)
	if stage_index == 8: spec.water = Vector4(.455,.386,.09,.057)
	var skies := {0:Vector4(.58,.01,.39,.16),1:Vector4(.02,.03,.17,.2),3:Vector4(.23,.0,.34,.16),4:Vector4(.20,.08,.56,.19),6:Vector4(.23,.01,.55,.23),8:Vector4(.24,.12,.53,.22)}
	spec.sky = skies.get(stage_index,Vector4.ZERO)
	var lamps := {1:Vector4(.45,.015,.10,.12),4:Vector4(.48,.08,.07,.14),5:Vector4(.23,.21,.1,.15),6:Vector4(.13,.19,.045,.12),7:Vector4(.02,.14,.09,.16),8:Vector4(.41,.0,.15,.18)}
	spec.lamp = lamps.get(stage_index,Vector4.ZERO)
	if stage_index in [5,6,7]: spec.papers = Vector4(.43,.34,.17,.045)
	if stage_index == 2: spec.door = Vector4(.90,.17,.055,.20)
	if stage_index == 5: spec.door = Vector4(.825,.14,.09,.25)
	# Optional data-only extension: legacy Chapter 4 settings stay unchanged.
	if not stage_override.is_empty(): spec = stage_override.duplicate(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	process_mode = Node.PROCESS_MODE_PAUSABLE
	clip_contents = true
	rng.randomize() # Isolated cosmetic RNG: cannot alter questions/damage/move selection.
	room = TextureRect.new()
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room.stretch_mode = TextureRect.STRETCH_SCALE
	room.texture = load(room_root+String(spec.id)+".png")
	material_fx = ShaderMaterial.new()
	material_fx.shader = preload("res://scripts/environments/palace_atmosphere.gdshader")
	for field in ["foliage","curtain","water","monitor","sky","lamp","papers","door"]:
		material_fx.set_shader_parameter(field,spec.get(field,Vector4.ZERO))
	room.material = material_fx
	add_child(room)
	# Drawing must be ABOVE the room, while the complete environment stays below fighters.
	room.show_behind_parent = true
	for i in range(6): sprites.append(load(ROOT+"npc_%d.png"%i))
	next_walker = rng.randf_range(3,8)
	next_vehicle = rng.randf_range(22,42)
	next_bird = rng.randf_range(12,30)
	next_door = rng.randf_range(20,40)
	_spawn_actor(true)
	ambience = AudioStreamPlayer.new()
	ambience.bus = "SFX"
	ambience.volume_db = -32.0
	ambience.stream = load("res://assets/audio/ambience/palace/"+String(spec.sound)+".ogg")
	if ambience.stream is AudioStreamOggVorbis: ambience.stream.loop = true
	add_child(ambience)
	ambience.play()

func escalate() -> void:
	if stage_index == 8:
		phase_target = 1.0
		# Existing walkers leave naturally; no new arrivals after the phase boundary.
		for actor in actors:
			actor.state = "leaving"
			actor.duration = 2.5

func stop() -> void:
	running = false
	actors.clear()
	vehicle_progress = -1.0
	bird_progress = -1.0
	if is_instance_valid(ambience): ambience.stop()
	set_process(false)
	queue_redraw()

func _exit_tree() -> void:
	stop()

func react(strength: float) -> bool:
	# Existing impact strengths vary 2..9; only strong events disturb the room.
	if not running or strength < 4.0 or reaction_cooldown > 0.0: return false
	reaction_cooldown = 2.8
	impact = minf(strength / 9.0,1.0)
	reaction_count += 1
	if npc_cooldown <= 0.0 and not actors.is_empty() and rng.randf() < .28:
		actors[0].react_time = 1.6
		npc_cooldown = rng.randf_range(12,18)
		npc_reaction_count += 1
	return true

func _spawn_actor(stationary: bool = false) -> void:
	if actors.size() >= 2 or phase_target > 0.0: return
	var lane: Vector3 = spec.lane
	var direction := 1.0 if rng.randf() < .5 else -1.0
	actors.append({"x":lerpf(lane.x,lane.y,.55) if stationary else (lane.x if direction>0 else lane.y),
		"y":lane.z,"direction":direction,"role":spec.roles[rng.randi_range(0,1)],
		"state":"waiting" if stationary else "walking","wait":rng.randf_range(8,20),
		"react_time":0.0,"age":0.0,"duration":rng.randf_range(9,15)})
	spawned_count += 1

func _process(delta: float) -> void:
	if not running: return
	elapsed += delta
	phase_mix = move_toward(phase_mix,phase_target,delta/4.0)
	impact = move_toward(impact,0.0,delta*1.4)
	reaction_cooldown = maxf(0.0,reaction_cooldown-delta)
	npc_cooldown = maxf(0.0,npc_cooldown-delta)
	if spec.has("door") and phase_target == 0.0:
		next_door -= delta
		if next_door <= 0.0:
			door_time = 3.0
			next_door = rng.randf_range(25,45)
		door_time = maxf(0.0,door_time-delta)
		material_fx.set_shader_parameter("door_open",sin(door_time/3.0*PI)*.8)
	next_walker -= delta
	if next_walker <= 0.0:
		_spawn_actor()
		next_walker = rng.randf_range(20,35)
	var lane: Vector3 = spec.lane
	for i in range(actors.size()-1,-1,-1):
		var a: Dictionary = actors[i]
		a.age += delta
		if a.react_time > 0.0:
			a.react_time = maxf(0.0,a.react_time-delta)
			continue
		if a.state == "waiting":
			a.wait -= delta
			if a.wait <= 0.0: a.state = "walking"
		else:
			a.x += a.direction*(lane.y-lane.x)*delta/a.duration
			if a.x < lane.x or a.x > lane.y: actors.remove_at(i)
	if bool(spec.get("vehicle",false)):
		next_vehicle -= delta
		if next_vehicle <= 0.0 and vehicle_progress < 0.0:
			vehicle_progress = 0.0
			next_vehicle = rng.randf_range(25,45)
		if vehicle_progress >= 0.0:
			vehicle_progress += delta/12.0
			if vehicle_progress > 1.0: vehicle_progress = -1.0
	if bool(spec.wind) and phase_target == 0.0:
		next_bird -= delta
		if next_bird <= 0.0 and bird_progress < 0.0:
			bird_progress = 0.0
			next_bird = rng.randf_range(25,45)
		if bird_progress >= 0.0:
			bird_progress += delta/9.0
			if bird_progress > 1.0: bird_progress = -1.0
	# Soft pointer-follow; bounded three image pixels, never the HUD or floor.
	var mouse := get_local_mouse_position()/size.max(Vector2.ONE)-Vector2(.5,.5)
	pointer = pointer.lerp(mouse.clamp(Vector2(-.5,-.5),Vector2(.5,.5))*4.0,1.0-exp(-delta*2.0))
	material_fx.set_shader_parameter("clock",elapsed)
	material_fx.set_shader_parameter("escalation",phase_mix)
	material_fx.set_shader_parameter("impact",impact)
	material_fx.set_shader_parameter("camera_offset",pointer/Vector2(768,512))
	# 30 Hz ambient draw budget; shader clock still follows the engine, not TIME (pause-safe).
	draw_accumulator += delta
	if draw_accumulator >= 1.0/30.0:
		draw_accumulator = 0.0
		queue_redraw()

func _draw() -> void:
	if spec.is_empty() or size.x<=0: return
	draw_set_transform(Vector2.ZERO,0.0,size/Vector2(768,512))
	var wind := sin(elapsed*.83)*(1.0+phase_mix)+impact*2.0
	# Small isolated, articulated NPCs; rear-lane depth adapts to the mobile HUD.
	for a in actors:
		var tex: Texture2D = sprites[a.role]
		if tex == null: continue
		var bob := 0.0
		var step := 0.0
		if a.state != "waiting" and a.react_time <= 0.0:
			step = sin(a.age*7.0)
			bob = absf(step)*.6
		var alpha: float = clampf(minf(a.age,absf(a.x-(spec.lane.x if a.direction<0 else spec.lane.y))*80.0),0.0,1.0)
		var tint := Color(.74,.75,.72,alpha*.88)
		var h := 23.0
		var w := h*tex.get_width()/tex.get_height()
		var p := Vector2(a.x*768-w/2,a.y*512-h+bob+ (2.0 if a.react_time>0 else 0.0))
		var ts := tex.get_size()
		draw_texture_rect_region(tex,Rect2(p,Vector2(w,h*.65)),Rect2(Vector2.ZERO,Vector2(ts.x,ts.y*.65)),tint)
		# Rare hand/prop adjustment while waiting: reporter camera, notes, folders.
		# Only enabled by the Congress data; legacy Palace actors are unchanged.
		if bool(spec.get("work_gestures",false)) and a.state == "waiting" and fmod(a.age,14.0)>11.0:
			var lift := sin((fmod(a.age,14.0)-11.0)/3.0*PI)*1.1
			draw_texture_rect_region(tex,Rect2(p+Vector2(w*.60,h*.28-lift),Vector2(w*.34,h*.28)),Rect2(Vector2(ts.x*.60,ts.y*.28),Vector2(ts.x*.34,ts.y*.28)),tint)
		for leg in range(2):
			draw_texture_rect_region(tex,Rect2(p+Vector2(leg*w*.5,h*.65+step*(1 if leg==0 else -1)),Vector2(w*.5,h*.35)),Rect2(Vector2(leg*ts.x*.5,ts.y*.65),Vector2(ts.x*.5,ts.y*.35)),tint)
	# One flag cloth made from short strips: white triangle, blue above red.
	if spec.has("flag"):
		var f: Vector2 = spec.flag*Vector2(768,512)
		draw_line(f,f+Vector2(0,61),Color("b9aa81"),2)
		for x in range(26):
			var y := sin(elapsed*2.0+x*.18)*x*.08*(1.0+phase_mix*.5)+wind*.4
			draw_rect(Rect2(f+Vector2(x,y),Vector2(1,7)),Color("365782"))
			draw_rect(Rect2(f+Vector2(x,y+7),Vector2(1,7)),Color("94535a"))
			if x<10: draw_line(f+Vector2(x,y+x*.7),f+Vector2(x,y+14-x*.7),Color("d9d2ad"),1)
		draw_circle(f+Vector2(3,7),1.4,Color("d4b66b"))
	if bird_progress >= 0:
		var b := Vector2(lerpf(120,690,bird_progress),80+sin(bird_progress*PI)*10)
		var flap := sin(elapsed*8.0)*2.0
		draw_polyline(PackedVector2Array([b+Vector2(-4,flap),b,b+Vector2(4,flap)]),Color(.3,.35,.37,.5),1)
	if vehicle_progress >= 0:
		var vehicle_lane: Vector3 = spec.get("vehicle_lane",Vector3(536.0/768,683.0/768,214.0/512))
		var v := Vector2(lerpf(vehicle_lane.x,vehicle_lane.y,vehicle_progress)*768,vehicle_lane.z*512)
		var a := sin(vehicle_progress*PI)*.55
		if bool(spec.get("cart",false)):
			draw_line(v+Vector2(-3,-11),v+Vector2(-3,7),Color(.47,.44,.36,a),2)
			draw_rect(Rect2(v+Vector2(0,4),Vector2(28,3)),Color(.33,.36,.36,a))
			for box in range(3):
				draw_rect(Rect2(v+Vector2(2+box*8,-6-box%2*4),Vector2(7,10+box%2*4)),Color(.49,.39,.27,a))
		else:
			draw_rect(Rect2(v,Vector2(28,7)),Color(.18,.23,.25,a))
			draw_rect(Rect2(v+Vector2(7,-5),Vector2(14,5)),Color(.28,.33,.34,a))
		for wheel in [5,22]: draw_circle(v+Vector2(wheel,7),2,Color(.13,.15,.16,a))
	# Fountain jets/droplets have a continuous flow, not a flashing basin texture.
	if spec.has("water"):
		var basin: Vector4 = spec.water
		var origin := Vector2((basin.x+basin.z*.5)*768,(basin.y+basin.w*.7)*512)
		for stream in range(3):
			for drop in range(7):
				var u := fmod(elapsed*.7+drop/7.0,1.0)
				var point := origin+Vector2((stream-1)*u*9,-sin(u*PI)*(12+impact*3))
				draw_rect(Rect2(point,Vector2(1,2)),Color(.73+phase_mix*.18,.82,.79-phase_mix*.28,.55))
	# Small moving monitor bars and camera tally lights only inside their real screen.
	if spec.has("monitor"):
		var r: Vector4 = spec.monitor
		var origin := Vector2(r.x*768,r.y*512)
		for line in range(3):
			draw_line(origin+Vector2(5,6+line*4),origin+Vector2(10+fmod(elapsed*.8+line*7,19),6+line*4),Color(.47,.70,.78,.6),1)
		draw_circle(origin+Vector2(4,2),1,Color(.8,.2,.12,.3+.3*maxf(0,sin(elapsed*1.4))))
	# Clock hand rotates in local office time; this never touches the game clock.
	if stage_index == 5:
		var c: Vector2 = spec.get("clock_position",Vector2(315.0/768,146.0/512))*Vector2(768,512)
		draw_circle(c,5,Color("ad9e79"))
		draw_line(c,c+Vector2(sin(elapsed*.105),-cos(elapsed*.105))*4,Color("3a3937"),1)
	# Limited paper/dust motes, behind combat and above the battle-floor boundary.
	if impact > .02 or phase_mix > .02:
		for i in range(8):
			var p := Vector2(190+fmod(i*61.0+elapsed*(3+phase_mix*5),380),185+fmod(i*19.0+elapsed*9,88))
			var a := maxf(impact*.24,phase_mix*.24)
			draw_rect(Rect2(p,Vector2(3,2) if phase_mix>.1 else Vector2(1,1)),Color(.94,.78,.44,a))
	# Soft lamp shimmer, never a flash across the question board.
	if stage_index >= 5:
		for x in [116,650]: draw_circle(Vector2(x,145),4,Color(1,.76,.35,.035+phase_mix*.055+impact*.035))
	draw_set_transform(Vector2.ZERO)
