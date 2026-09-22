extends Node
## Animation-only: this module never reads or writes combat HP/damage formulas.
const FX = preload("res://scripts/battle/chapter3_combat_fx.gd")
const IDS := {
	"male": ["ballot_bolt","peoples_volley","peoples_kick","ballot_breaker","bayanihan_strike"],
	"female": ["civic_spark","ballot_barrage","ballot_flurry","voters_vault","peoples_voice"]}
const TITLES := {
	"male": ["Ballot Bolt","People's Volley","People's Kick","Ballot Breaker","Bayanihan Strike"],
	"female": ["Civic Spark","Ballot Barrage","Ballot Flurry","Voter's Vault","People's Voice"]}
const TIMING := {
	"male": [[.12,.32,.18,.12,.32],[.27,.40,.26,.20,.38],[.20,.36,.28,.18,.38],[.25,.34,.28,.17,.36],[.32,.32,.30,.25,.40]],
	"female": [[.10,.28,.16,.10,.28],[.18,.30,.25,.16,.30],[.20,.26,.22,.15,.30],[.23,.48,.24,.22,.32],[.28,.28,.25,.21,.32]]}
var battle: Node
var rng := RandomNumberGenerator.new()
var bags := {"male": [], "female": []}
var history := {"male": -1,"female": -1}
var forced_index := -1 # Test seam; never set by gameplay.
var selected := -1
var who_key := "male"
var attack_id := ""
var stage := "idle"
var events: Array[Dictionary]=[]
var home := Vector2.ZERO
var target_x := 0.0
var contact_ready := false
var animation_frame := -1
var active := false
var pose_cache: Dictionary={}
var overlay: Sprite2D
var contact_metrics: Dictionary={}
var epoch := 0
var projectiles: Array[Node2D]=[]
var ranged_run := false
var launched := 0
var arrived := 0

func _process(_delta: float) -> void:
	if active and ranged_run and GameState.character!=who_key: cancel()

func _exit_tree() -> void:
	cancel()

func cancel() -> void:
	epoch+=1; active=false; contact_ready=false
	for shot in projectiles:
		if is_instance_valid(shot): shot.cancel_flight(); shot.queue_free()
	projectiles.clear()
	for child in get_children(): child.queue_free()
	if is_instance_valid(overlay): overlay.visible=false
	if is_instance_valid(battle) and is_instance_valid(battle.player_character):
		var body: AnimatedCharacter=battle.player_character
		body.self_modulate.a=1.0
		if ranged_run:
			body.position=home
			body.pose_locked=false
			battle._body_home.erase(body)
		body.play_idle()
	stage="cancelled"

func setup(controller: Node) -> void:
	battle=controller
	rng.randomize() # Cosmetic RNG never consumes question/combat RNG.
	overlay=Sprite2D.new()
	overlay.centered=false
	overlay.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.visible=false
	battle.player_character.add_child(overlay)

func choose(character: String) -> int:
	var key := "female" if character=="female" else "male"
	if bags[key].is_empty():
		var bag: Array=[0,1,2,3,4]
		for i in range(4,0,-1):
			var j := rng.randi_range(0,i)
			var temp: int=bag[i]; bag[i]=bag[j]; bag[j]=temp
		if bag[0]==history[key]:
			var j := rng.randi_range(1,4)
			var temp: int=bag[0]; bag[0]=bag[j]; bag[j]=temp
		bags[key]=bag
	var result: int=bags[key].pop_front()
	history[key]=result
	return result

func mark(beat: String) -> void:
	stage=beat
	events.append({"beat":beat,"frame":animation_frame,"msec":Time.get_ticks_msec()})

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds,false).timeout

func pose_path(frame: int) -> String:
	return "res://assets/images/characters/player_variations/"+who_key+"/"+attack_id+"/frame_%02d.png" % frame

func pose(frame: int) -> void:
	animation_frame=frame
	var path := pose_path(frame)
	if not pose_cache.has(path): pose_cache[path]=load(path)
	var body: AnimatedCharacter=battle.player_character
	var original: Texture2D=body._idle_frames[0]
	var fit := minf(body.size.x/original.get_width(),body.size.y/original.get_height())
	overlay.texture=pose_cache[path]
	overlay.scale=Vector2.ONE*fit
	overlay.position=Vector2((body.size.x-overlay.texture.get_width()*fit)*.5,(body.size.y-original.get_height()*fit)*.5)
	overlay.visible=true
	body.self_modulate.a=0.0

func walk() -> void:
	overlay.visible=false
	battle.player_character.self_modulate.a=1.0
	battle.player_character.play_walk()

func frames(first: int, last: int, seconds: float) -> void:
	var serial := epoch
	for frame in range(first,last+1):
		if serial!=epoch or not active: return
		pose(frame)
		await wait(seconds/float(last-first+1))

func effect(kind: String, at: Vector2, life: float=.3) -> Node2D:
	var node := FX.new()
	node.kind=kind; node.position=at.round(); node.lifetime=life
	node.tint=Color("f6cc65") if who_key=="male" else Color("99dede")
	add_child(node)
	return node

func centre(body: Control) -> Vector2:
	return body.position+body.body_rect().get_center()

func feet(body: Control) -> Vector2:
	return body.position+Vector2(body.body_rect().get_center().x,body.body_rect().end.y)

func sound(phase: String) -> void:
	Audio.play_move_sfx("player_"+attack_id,phase)

func contact_position() -> float:
	var body: Control=battle.player_character
	var enemy: Control=battle.enemy_character
	var tex: Texture2D=load(pose_path(12))
	var original: Texture2D=body._idle_frames[0]
	var fit := minf(body.size.x/original.get_width(),body.size.y/original.get_height())
	var origin := Vector2((body.size.x-tex.get_width()*fit)*.5,0)
	var used: Rect2i=tex.get_image().get_used_rect()
	var image := tex.get_image()
	var tip_y := 0.0
	var count := 0
	for y in range(used.position.y,used.end.y):
		for x in range(maxi(used.position.x,used.end.x-5),used.end.x):
			if image.get_pixel(x,y).a>.5: tip_y+=y; count+=1
	tip_y/=maxi(count,1)
	var contact_y: float=body.position.y+(body.size.y-original.get_height()*fit)*.5+tip_y*fit
	# Measure the current guard/idle silhouette at the fist/foot's height,
	# not an idle prop or shoe far below the contact point.
	var enemy_tex: Texture2D=enemy.texture
	var enemy_fit := minf(enemy.size.x/enemy_tex.get_width(),enemy.size.y/enemy_tex.get_height())
	var enemy_origin := (enemy.size-enemy_tex.get_size()*enemy_fit)*.5
	var enemy_image := enemy_tex.get_image()
	var near_x := enemy_image.get_used_rect().position.x
	var row := int((contact_y-enemy.position.y-enemy_origin.y)/enemy_fit)
	var found := false
	for x in range(enemy_image.get_width()):
		for y in range(maxi(0,row-10),mini(enemy_image.get_height(),row+11)):
			if enemy_image.get_pixel(x,y).a>.5:
				near_x=x; found=true; break
		if found: break
	contact_metrics={"tip_y":tip_y,"contact_y":contact_y,"enemy_row":row,"enemy_pixel_x":near_x,"enemy_world_x":enemy.position.x+enemy_origin.x+near_x*enemy_fit,"tip_local_x":origin.x+used.end.x*fit}
	return float(contact_metrics.enemy_world_x)-float(contact_metrics.tip_local_x)+3

func approach(seconds: float) -> void:
	mark("approach")
	var body: AnimatedCharacter=battle.player_character
	walk() # Existing authored leg cycle; untouched source art.
	var tween := create_tween()
	if who_key=="female" and selected==3:
		mark("airborne")
		pose(7)
		tween.tween_method(func(p: float) -> void:
			pose(6+mini(5,int(p*6)))
			body.position=Vector2(lerpf(home.x,target_x,p),home.y-sin(p*PI*.82)*body.body_rect().size.y*.20)
		,0.0,1.0,seconds)
	else:
		tween.tween_property(body,"position:x",target_x,seconds)
	await tween.finished
	if not (who_key=="female" and selected==3): body.position.y=home.y

func strike() -> void:
	who_key="female" if GameState.character=="female" else "male"
	selected=forced_index if forced_index>=0 else choose(who_key)
	forced_index=-1
	attack_id=IDS[who_key][selected]
	events.clear(); contact_ready=false; active=true
	epoch+=1
	ranged_run=selected<2
	launched=0; arrived=0
	var body: AnimatedCharacter=battle.player_character
	battle._body_begin(body,battle.BODY_FEET)
	home=body.position
	if ranged_run:
		await ranged_strike()
		return
	battle._body_bring_forward(body)
	target_x=contact_position()
	var timing: Array=TIMING[who_key][selected]
	mark("anticipation")
	sound("cast")
	if selected>=3 or (who_key=="female" and selected==2):
		for i in range(3): effect("paper",centre(body)+Vector2(-12+i*12,-20-i*5),.35)
	await frames(0,5,timing[0])
	mark("windup")
	effect("burst",feet(body),.25)
	await approach(timing[1])
	# Multi-hit sequences are visual feints/contacts only: the existing total is
	# committed ONCE at the final contact so shields cannot be bypassed.
	if selected==4 or (who_key=="female" and selected==2):
		for beat in range(2):
			mark("combo_contact_visual")
			var final_id := attack_id
			# Shared lead-in poses are retained assets, not selectable attacks.
			attack_id=(["quick_jab","civic_cross"] if who_key=="male" else ["swift_palm","ballot_flurry"])[beat]
			await frames(6,11,.14 if who_key=="female" else .18)
			effect("burst",centre(battle.enemy_character),.18)
			sound("cast")
			await frames(13,15,.08)
			attack_id=final_id
	mark("execution")
	if who_key=="female" and selected==3:
		var descend := create_tween()
		descend.tween_property(body,"position:y",home.y-3,timing[2])
	if selected>=3 or (who_key=="female" and selected==2): effect("paper",centre(body)+Vector2(20,-15),timing[2]+.1)
	await frames(6,11,timing[2])
	pose(12)
	mark("impact")
	contact_ready=true
	sound("impact")
	effect("check" if selected>=3 or (who_key=="female" and selected==2) else "shock",centre(battle.enemy_character),.30)
	if selected in [1,4]: battle._shake_screen(2.0 if who_key=="female" else 3.0)
	# Return WITHOUT waiting: _play_attack_sequence commits its already-computed
	# damage synchronously on this exact contact frame, through _enemy_take_hit.

func recover() -> void:
	if not active: return
	contact_ready=false
	mark("follow_through")
	var timing: Array=TIMING[who_key][selected]
	if who_key=="female" and selected==3:
		var land := create_tween()
		land.tween_property(battle.player_character,"position:y",home.y,.07)
	await frames(13,17,timing[3])
	var body: AnimatedCharacter=battle.player_character
	if who_key=="female" and selected==3:
		effect("burst",feet(body),.25)
	mark("recovery")
	if not ranged_run:
		walk()
		var tween := create_tween()
		tween.tween_property(body,"position",home,timing[4]).set_trans(Tween.TRANS_SINE)
		await tween.finished
		battle._body_send_back(body)
	await battle._body_end(body,.08)
	body.play_idle()
	overlay.visible=false
	body.self_modulate.a=1.0
	active=false
	mark("idle")

func hand_anchor() -> Vector2:
	# Upper-body leading pixels in the displayed release pose, not node centre.
	var img := overlay.texture.get_image()
	var bounds := img.get_used_rect()
	var lead := Vector2(bounds.get_center().x,bounds.position.y+45)
	for x in range(bounds.end.x-1,bounds.position.x-1,-1):
		var found := false
		# Single-shot windups must not mistake the leading knee for a hand.
		for y in range(bounds.position.y+20,mini(bounds.end.y,90 if selected==0 else 125)):
			if img.get_pixel(x,y).a>.5: lead=Vector2(x,y); found=true; break
		if found: break
	return battle.player_character.position+overlay.position+lead*overlay.scale

func ranged_target() -> Vector2:
	var target := centre(battle.enemy_character)
	if battle._enemy_guard>0:
		if is_instance_valid(battle._regular_combat) and is_instance_valid(battle._regular_combat.shield):
			var shield: Node2D=battle._regular_combat.shield
			if shield.kind!="route": target=shield.position-Vector2(shield.span.x,0)
		elif is_instance_valid(battle._cong_meow) and is_instance_valid(battle._cong_meow.shield):
			var shield: Node2D=battle._cong_meow.shield
			target=shield.position-Vector2(shield.radius.x,0)
	return target

func ranged_strike() -> void:
	var serial := epoch
	mark("anticipation"); sound("cast")
	await frames(0,5,.16 if selected==0 else .27)
	if serial!=epoch: return
	mark("windup")
	var count := 1 if selected==0 else (3 if who_key=="male" else 5)
	var formation: Array[Node2D]=[]
	for i in range(count):
		var at := centre(battle.player_character)+Vector2(-20+i*9,-25-absf(i-count*.5)*7)
		if count==1: at=hand_anchor()
		var card := effect("check" if attack_id=="civic_spark" else "ballot",at,1)
		card.persistent=true; card.scale=Vector2.ONE*.55
		formation.append(card)
	await wait(.10 if selected==0 else .18)
	if serial!=epoch: return
	for i in range(count):
		await frames(6,11,.10 if who_key=="female" else .14)
		if serial!=epoch: return
		pose(12)
		mark("release"); launched+=1
		var start := hand_anchor()
		if selected==1 and i<count-1: start=formation[i].position
		formation[i].queue_free()
		var target := ranged_target()
		var shot := effect("check" if attack_id=="civic_spark" else "ballot",start,1)
		shot.trail_enabled=true
		shot.scale=Vector2.ONE*(.45 if attack_id=="civic_spark" else 1.35 if selected==1 and i==count-1 else .85)
		projectiles.append(shot)
		Audio.play_move_sfx("player_"+attack_id,"launch"+str(i+1))
		var duration := .26 if who_key=="female" else .33
		if selected==1 and i<count-1: duration+=.12
		var trail := effect("ballot" if who_key=="male" else "check",start,.13)
		trail.scale=Vector2.ONE*.22
		var landed: bool=await shot.fly(start,target,duration,-24 if i%2==1 else 0,TAU if who_key=="male" else .3,.3 if i==count-1 else 0)
		projectiles.erase(shot)
		shot.queue_free()
		if not landed or serial!=epoch or GameState.character!=who_key:
			contact_ready=false; return
		arrived+=1
		if i<count-1:
			mark("projectile_visual_impact")
			effect("burst",target,.16)
			Audio.play_move_sfx("player_"+attack_id,"light")
			await frames(13,15,.06)
		else:
			mark("impact"); contact_ready=true
			effect("check",target,.28); effect("burst",target,.24)
			sound("impact")
			# Existing battle flow applies its one authoritative damage value now.
