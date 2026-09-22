extends Node
## Encounter-scoped choreography/AI. The existing controller owns HP and turns.
const FX = preload("res://scripts/bosses/cong_meow_fx.gd")
const ART := "res://assets/images/characters/chapter3/cong_meow_"
var battle: Node
var selected := 0
var previous := -1
var streak := 0
var guard_uses := 0
var cooldown := 0
var shield: Node2D
var hum: AudioStreamPlayer
var rng := RandomNumberGenerator.new()
var impacts: Array[int] = [] # Same-frame applied damage; useful local diagnostics.

func setup(controller: Node) -> void:
	battle = controller
	rng.randomize()

func can_guard() -> bool:
	return guard_uses < 3 and cooldown == 0 and battle._enemy_guard == 0.0

func choose_next() -> void:
	var ratio := float(battle._enemy_hp)/float(battle._enemy.max_hp)
	var weights: Array = [0.72,0.28,0.0] if ratio>.65 else [0.38,0.62,0.0]
	if ratio<=.85 and can_guard(): weights[2]=.45 if ratio<=.3 else .28
	if previous>=0:
		weights[previous]*=.18 if streak<2 else 0.0
	var roll: float = rng.randf()*(weights[0]+weights[1]+weights[2])
	selected=0
	for i in range(3):
		roll-=weights[i]
		if roll<=0:
			selected=i
			break

func wait(seconds: float) -> void:
	# Unlike SceneTreeTimer's default, this clock MUST stop with the pause menu.
	await get_tree().create_timer(seconds,false).timeout

func sound(cue: String) -> void:
	Audio.play_move_sfx("cong_meow_"+cue,"cast")

func effect(kind: String, at: Vector2, seconds: float=.4) -> Node2D:
	var node := FX.new()
	node.kind=kind; node.position=at.round(); node.lifetime=seconds
	add_child(node)
	return node

func center(who: Control) -> Vector2:
	return who.position+who.size*Vector2(.5,.45)

func clip(name: String, count: int, duration: float) -> void:
	battle.enemy_character.play_clip(ART+name,count,duration)

func hit(amount: int, heavy: bool=false) -> void:
	var actual := mini(amount,int(battle._player_hp))
	if actual<=0: return
	battle._player_hp=maxi(0,battle._player_hp-actual)
	battle.player_heart_row.set_value(battle._player_hp)
	battle.player_character.play_hit()
	Audio.play_sfx("player_hurt")
	battle._fx_word("-%d HP" % actual,battle.player_character,Color("ffb3a8"),20,0,12)
	if heavy: battle._shake_screen(5.0)
	impacts.append(actual)

func resolve(move: EnemyMove) -> void:
	impacts.clear()
	var move_slot := int(battle._enemy.moves.find(move))
	var mud: int=battle._pending_enemy_damage
	battle._pending_enemy_damage=0
	var speed := .80 if float(battle._enemy_hp)/battle._enemy.max_hp<=.3 else 1.0
	battle.word_preview_label.text=move.move_name
	match move_slot:
		0: await claw(move.direct_damage,mud,speed)
		1: await viral(move.direct_damage,mud,speed)
		2:
			# A stale/externally forced choice cannot bypass the defense rules.
			if can_guard(): await nine_lives(speed)
			if mud>0: hit(mud)
	if move_slot!=2: cooldown=maxi(0,cooldown-1)
	streak=streak+1 if previous==move_slot else 1
	previous=move_slot
	battle.enemy_character.play_idle()
	battle._move_index+=1
	choose_next()
	battle._highlight_current_move()

func claw(total: int, mud: int, speed: float) -> void:
	var who: Control=battle.enemy_character
	battle._body_begin(who,battle.BODY_FEET)
	battle._body_bring_forward(who)
	clip("anticipate",6,.32*speed)
	effect("paw",center(who)+Vector2(-25,-18),.30*speed)
	await wait(.30*speed)
	sound("dash")
	battle.enemy_character.play_walk()
	var approach := create_tween()
	approach.tween_property(who,"position:x",battle._melee_target_x(),.20*speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await approach.finished
	var light := int(total*.27)
	var hits: Array[int]=[light,light,total-2*light+mud]
	for i in range(3):
		if battle._player_hp<=0: break
		var duration := (.34 if i<2 else .46)*speed
		clip("slash%d" % (i+1),6 if i<2 else 8,duration)
		sound("swipe")
		await wait(duration*.40)
		var scratch: Node2D=effect("claw",center(battle.player_character),.23)
		scratch.reverse=i==1
		if i==2: scratch.scale=Vector2(1.25,1.25)
		sound("impact")
		hit(hits[i],i==2)
		await wait(duration*.60)
	battle.enemy_character.play_walk()
	var retreat := create_tween()
	retreat.tween_property(who,"position:x",battle._body_home_x(who),.30*speed).set_trans(Tween.TRANS_SINE)
	await retreat.finished
	battle._body_send_back(who)
	await battle._body_end(who,.08)

func projectile(kind: String, travel: float, arc: float, amount: int, heavy: bool=false) -> void:
	var start: Vector2=center(battle.enemy_character)+Vector2(-22,-12)
	var finish: Vector2=center(battle.player_character)
	var node := effect(kind,start,travel+.1)
	node.tint=Color("97eaff") if kind!="bubble" else Color("ffe18b")
	if kind=="bubble":
		var label := Label.new()
		label.text="MEOW!"; label.position=Vector2(-20,-10)
		label.add_theme_font_size_override("font_size",11)
		label.add_theme_color_override("font_color",Color("322642"))
		node.add_child(label)
	sound("digital")
	var flight := create_tween()
	flight.tween_method(func(p: float) -> void:
		if is_instance_valid(node): node.position=(start.lerp(finish,p)+Vector2(0,sin(p*PI)*arc)).round(),0.0,1.0,travel)
	await flight.finished
	if is_instance_valid(node): node.queue_free()
	effect("burst",finish,.28)
	sound("meow" if heavy else "notification")
	hit(amount,heavy)

func viral(total: int, mud: int, speed: float) -> void:
	clip("phone",16,2.55*speed)
	sound("tap")
	effect("cat",center(battle.enemy_character)+Vector2(-10,-45),.4)
	await wait(.38*speed)
	var first := int(total*.19)
	var third := int(total*.25)
	var damage: Array[int]=[first,first,third,total-2*first-third+mud]
	var kinds: Array[String]=["paw","cat","paw","bubble"]
	var travel: Array[float]=[.40,.42,.23,.46]
	for i in range(4):
		if battle._player_hp<=0: break
		sound("tap")
		effect("paw",center(battle.enemy_character)+Vector2(10,-35),.25)
		await projectile(kinds[i],travel[i]*speed,-35.0 if i==1 else 0.0,damage[i],i==3)
		await wait(.09*speed)
	await wait(.16*speed)

func nine_lives(speed: float) -> void:
	guard_uses+=1
	cooldown=2
	clip("guard",12,.8*speed)
	sound("activation")
	var who: Control=battle.enemy_character
	var emblem: Node2D=effect("emblem",who.position+who.size*Vector2(.5,.96),.8*speed)
	emblem.radius.x=who.size.x*.30
	await wait(.38*speed)
	shield=effect("shield",center(who),1)
	shield.persistent=true; shield.follow=who
	var bounds: Rect2=who.body_rect()
	shield.radius=bounds.size*Vector2(.56,.53)
	var rise := create_tween()
	shield.scale=Vector2(1,.12)
	rise.tween_property(shield,"scale",Vector2.ONE,.26*speed)
	battle._enemy_guard=.5
	battle._show_enemy_guard_badge()
	battle._enemy_guard_badge.text="NINE LIVES -50%% | %d/3" % guard_uses
	battle._enemy_guard_badge.position=Vector2(bounds.position.x,bounds.position.y-13)
	battle._refresh_damage_preview()
	hum=AudioStreamPlayer.new()
	hum.stream=load("res://assets/audio/sfx/moves/cong_meow_hum_cast.wav")
	hum.bus="SFX"; hum.volume_db=-22
	add_child(hum)
	hum.finished.connect(func() -> void:
		if is_instance_valid(shield): hum.play())
	hum.play()
	await wait(.42*speed)
	battle.word_preview_label.text="Nine Lives: next hit reduced 50%"

func consume_shield() -> void:
	sound("shield_hit")
	floating("1 LIFE USED",-25,Color("ffe18b"))
	if is_instance_valid(shield):
		shield.persistent=false; shield.age=0; shield.lifetime=.18; shield.tint=Color.WHITE
		shield=null
	if is_instance_valid(hum): hum.queue_free()
	effect("burst",center(battle.enemy_character),.55)
	sound("shield_break")

func show_damage(amount: int) -> void:
	floating("-%d HP" % amount,3,Color("ffcf9b"))

func block_reaction() -> void:
	# Shielded player hits retain the phone/guard pose rather than an unguarded
	# hurt clip. HP and shield consumption still belong to the battle controller.
	var who: Control=battle.enemy_character
	battle._body_begin(who,battle.BODY_FEET)
	clip("guard",8,.28)
	await battle._body_play(who,[battle._beat(3,0,2,1,1,.10),battle._beat(0,0,0,1,1,.15)])
	await battle._body_end(who,.06)
	who.play_idle()

func floating(text: String, offset: float, tint: Color) -> void:
	# Separate vertical lanes keep the life-used notice and actual HP readable.
	var label := Label.new()
	label.text=text
	label.add_theme_font_override("font",battle.HUD_TITLE_FONT)
	label.add_theme_font_size_override("font_size",12)
	label.add_theme_color_override("font_color",tint)
	label.add_theme_color_override("font_outline_color",Color("251a32"))
	label.add_theme_constant_override("outline_size",3)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.size=Vector2(150,18)
	label.position=center(battle.enemy_character)+Vector2(-75,offset)
	add_child(label)
	var motion := label.create_tween()
	motion.tween_property(label,"position:y",label.position.y-10,.6)
	motion.parallel().tween_property(label,"modulate:a",0.0,.6).set_delay(.25)
	motion.tween_callback(label.queue_free)

func clear_effects() -> void:
	for child in get_children(): child.queue_free()
	shield=null
