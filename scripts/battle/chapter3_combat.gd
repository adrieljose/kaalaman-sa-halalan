extends Node
## Choreography for the EXISTING eight resources, not a new enemy implementation.
const FX = preload("res://scripts/battle/chapter3_combat_fx.gd")
const SLUGS := ["bokal_bulsa","assessor_altapresyo","treasurer_tago","auditor_alibi","planner_palusot","engineer_eskandalo","contractor_kutsaba","project_padrino"]
const COLORS := ["e7ba56","ed7475","90c1ce","f17382","74dbea","f1b444","e3d173","d6b66d"]
const MATERIALS := ["paper","tag","box","paper","blueprint","rubble","paper","envelope"]
const GUARDS := ["folder","grid","vault","paperwall","route","barricade","board","seal"]
const STAMPS := ["APPROVED","P 999,999","LOCKED","DISALLOWANCE","REVISED","UNDER CONSTRUCTION","CHANGE ORDER","SEALED DEAL"]
var battle: Node
var index := 0
var selected := 0
var uses := 0
var cooldown := 0
var shield: Node2D
var allies: Array[Node2D]=[]
var move: EnemyMove
var impacts: Array[int]=[]
var releases := 0
var stage := "idle"
var elapsed := 0.0
var events: Array[Dictionary]=[]

func setup(controller: Node) -> void:
	battle=controller
	index=SLUGS.find(battle._enemy.enemy_name.to_lower().replace(" ","_"))

func mark(beat: String) -> void:
	stage=beat
	events.append({"beat":beat,"msec":Time.get_ticks_msec(),"player_hp":battle._player_hp})

func can_guard() -> bool:
	return uses<3 and cooldown==0 and battle._enemy_guard==0.0

func next_move() -> void:
	selected=(selected+1)%3
	if selected==2 and not can_guard(): selected=0

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds,false).timeout

func clip(name: String, duration: float) -> void:
	battle.enemy_character.play_clip("res://assets/images/characters/chapter3/combat/"+SLUGS[index]+"/"+name,12 if name=="walk" else 8,duration)

func sound(phase: String) -> void:
	Audio.play_move_sfx(move.signature_id(),phase)

func center(who: Control) -> Vector2:
	return who.position+who.body_rect().get_center()

func foot(who: Control) -> Vector2:
	var bounds: Rect2=who.body_rect()
	return who.position+Vector2(bounds.get_center().x,bounds.end.y-2)

func hand() -> Vector2:
	var who: Control=battle.enemy_character
	var bounds: Rect2=who.body_rect()
	return who.position+bounds.position+bounds.size*Vector2(.12,.35)

func fx(kind: String, at: Vector2, life: float=.4) -> Node2D:
	var node := FX.new()
	node.kind=kind; node.position=at.round(); node.lifetime=life; node.tint=Color(COLORS[index])
	add_child(node)
	return node

func caption(text: String, at: Vector2, life: float=.65) -> void:
	var label := Label.new()
	label.text=text; label.size=Vector2(150,18); label.position=at-Vector2(75,12)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",battle.HUD_TITLE_FONT)
	label.add_theme_font_size_override("font_size",10 if text.length()>14 else 12)
	label.add_theme_color_override("font_color",Color(COLORS[index]))
	label.add_theme_color_override("font_outline_color",Color("221c25"))
	label.add_theme_constant_override("outline_size",3)
	add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label,"position:y",label.position.y-10,life)
	tween.parallel().tween_property(label,"modulate:a",0.0,life).set_delay(.15)
	tween.tween_callback(label.queue_free)

func hit(amount: int, heavy: bool=false) -> void:
	var actual := mini(amount,int(battle._player_hp))
	if actual<=0: return
	mark("impact")
	battle._player_hp=maxi(0,battle._player_hp-actual)
	battle.player_heart_row.set_value(battle._player_hp)
	battle.player_character.play_hit()
	Audio.play_sfx("player_hurt")
	caption("-%d HP" % actual,center(battle.player_character)+Vector2(0,-28))
	var burst := fx("burst",center(battle.player_character),.4)
	burst.pattern="coin" if index in [0,2] else MATERIALS[index]
	if heavy: battle._shake_screen(4.0 if index!=7 else 6.0)
	sound("impact")
	impacts.append(actual)

func split_damage(total: int, count: int, bonus: int) -> Array[int]:
	var result: Array[int]=[]
	var part := total/count
	for i in range(count): result.append(part if i<count-1 else total-part*(count-1)+bonus)
	return result

func resolve(chosen: EnemyMove) -> void:
	move=chosen
	var slot: int=battle._enemy.moves.find(move)
	impacts.clear(); events.clear(); releases=0
	mark("anticipation")
	var mud: int=battle._pending_enemy_damage
	battle._pending_enemy_damage=0
	battle.word_preview_label.text=move.move_name
	sound("cast")
	match slot:
		0: await physical(move.direct_damage,mud)
		1: await ranged(move.direct_damage,mud)
		2:
			if can_guard(): await defend()
			if mud>0: hit(mud)
	if slot!=2: cooldown=maxi(0,cooldown-1)
	mark("recovery")
	await wait(.12)
	if battle._enemy_guard>0:
		battle.enemy_character.play_loop_clip("res://assets/images/characters/chapter3/combat/"+SLUGS[index]+"/brace",8,5)
	else: battle.enemy_character.play_idle()
	mark("idle")
	battle._move_index+=1
	next_move()
	battle._highlight_current_move()
	battle.word_preview_label.text=move.move_name+ (": protected for next hit" if slot==2 else " complete")

func travel_to(x: float, duration: float) -> void:
	clip("walk",duration+.04)
	var tween := create_tween()
	tween.tween_property(battle.enemy_character,"position:x",x,duration).set_trans(Tween.TRANS_SINE)
	await tween.finished

func contact_x() -> float:
	# Attack silhouettes differ from idle bounds (raised stamps, extended palms).
	# Put the leading attack pixel against the player's visible right edge.
	var who: Control=battle.enemy_character
	var texture: Texture2D=load("res://assets/images/characters/chapter3/combat/"+SLUGS[index]+"/strike/frame_3.png")
	var fit := minf(who.size.x/texture.get_width(),who.size.y/texture.get_height())
	var origin := (who.size-texture.get_size()*fit)*.5
	var used: Rect2i=texture.get_image().get_used_rect()
	var player: Control=battle.player_character
	return player.position.x+player.body_rect().end.x-origin.x-used.position.x*fit-6

func physical(total: int, mud: int) -> void:
	var who: Control=battle.enemy_character
	battle._body_begin(who,battle.BODY_FEET)
	battle._body_bring_forward(who)
	clip("windup",.38)
	await wait(.34)
	mark("approach")
	var approach_time := .78 if index in [0,7] else .32 if index==5 else .58
	await travel_to(contact_x(),approach_time)
	mark("windup")
	clip("windup",.30)
	await wait(.25)
	var count := 3 if index in [3,4,6] else 1
	var damage := split_damage(total,count,mud)
	for i in range(count):
		if battle._player_hp<=0: break
		mark("execution")
		var duration := .48 if i==count-1 else .32
		clip("strike",duration)
		await wait(duration*.40)
		if index==1:
			fx("stamp",center(battle.player_character),.5)
			caption("OVERVALUED!",center(battle.player_character))
		elif index==3 and i==count-1: fx("check",center(battle.player_character),.5)
		elif index==7: fx("shock",center(battle.player_character),.6)
		hit(damage[i],i==count-1)
		await wait(duration*.60)
		mark("follow_through")
		if i<count-1:
			clip("windup",.18)
			await wait(.16)
	if index==0:
		# The dropped coin arcs back to the pocket during the catching gesture.
		var coin := fx("coin",hand()+Vector2(-8,16),.36)
		clip("prepare",.35)
		var catch_coin := create_tween()
		catch_coin.tween_property(coin,"position",center(who)+Vector2(8,20),.27)
		await catch_coin.finished
	elif index in [1,6]:
		fx("burst",hand(),.3)
		clip("windup",.27)
		await wait(.23)
	elif index==7: await wait(.28)
	mark("recovery")
	await travel_to(battle._body_home_x(who),.65 if index==7 else .48)
	battle._body_send_back(who)
	await battle._body_end(who,.08)

func projectile(kind: String, amount: int, duration: float, arc: float=0, spin: float=0, label: String="", start_override: Vector2=Vector2.INF, ricochet: bool=false) -> void:
	mark("release"); releases+=1
	var start := hand() if start_override==Vector2.INF else start_override
	var target := center(battle.player_character)
	var object := fx(kind,start,duration+.1)
	if not label.is_empty():
		object.scale=Vector2(1.5,1.5)
		var text := Label.new()
		text.text=label; text.position=Vector2(-30,-24); text.add_theme_font_size_override("font_size",8)
		text.add_theme_color_override("font_color",Color("fff1c0")); text.add_theme_color_override("font_outline_color",Color("322335")); text.add_theme_constant_override("outline_size",3)
		object.add_child(text)
	if kind=="tag" and not label.is_empty(): object.scale=Vector2.ONE
	var arrived: bool=await object.fly(start,target,duration,arc,spin,.75 if kind=="tag" and not label.is_empty() else 0.0,ricochet)
	object.queue_free()
	if arrived: hit(amount,not label.is_empty())

func ranged(total: int, mud: int) -> void:
	mark("windup")
	clip("prepare",.5)
	if index==1:
		# Measuring tape/grid is a readable pre-release tell, not damage.
		fx("grid",center(battle.player_character),.4)
	elif index in [0,3,6]: fx("paper",hand()+Vector2(0,-24),.32)
	await wait(.40)
	if index==4:
		await zoning(total,mud)
		return
	if index==7:
		await backroom(total,mud)
		return
	var count := 4 if index in [3,6] else 3
	var damage := split_damage(total,count,mud)
	for i in range(count):
		if battle._player_hp<=0: break
		# Treasury/concrete final/second projectile is launched by the visible foot.
		var kicking := (index==2 and i==2) or (index==5 and i==1)
		clip("release" if kicking or not index in [2,5] else "prepare",.48)
		mark("execution")
		await wait(.13)
		var start := foot(battle.enemy_character)+Vector2(-30,-24) if kicking else Vector2.INF
		await projectile(MATERIALS[index],damage[i],.24 if i==count-1 else .36,
			-35 if i==1 else 0,PI*2 if i==1 else .2,
			STAMPS[index] if i==count-1 else "",start,index==0 and i==count-1)
		mark("follow_through")
		clip("prepare",.19)
		await wait(.16)

func zoning(total: int, mud: int) -> void:
	clip("prepare",.7)
	var table := fx("blueprint",hand()+Vector2(15,20),.7)
	table.scale=Vector2(2,1)
	var at := foot(battle.player_character)
	fx("grid",at,.65)
	caption("! ZONING !",at+Vector2(0,-35),.5)
	await wait(.5)
	clip("release",.65)
	var model := fx("zone",at,.65)
	await wait(.32)
	mark("release"); releases=1
	var collapse := model.create_tween()
	collapse.tween_property(model,"scale:y",.12,.18)
	await collapse.finished
	hit(total+mud,true)
	fx("burst",at,.4)
	await wait(.18)

func backroom(total: int, mud: int) -> void:
	var veil := ColorRect.new()
	veil.color=Color(.08,.03,.13,.12)
	veil.size=battle.get_viewport_rect().size
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	for i in range(3): fx("envelope",hand()+Vector2(15+i*9,-20-i*10),.6)
	await wait(.25)
	var damage := split_damage(total,5,mud)
	for i in range(5):
		if battle._player_hp<=0: break
		clip("release",.48)
		await wait(.12)
		var start := center(battle.player_character)+Vector2(0,-75) if i==3 else hand()+Vector2(0,18 if i==1 else -18 if i==2 else 0)
		if i==3: fx("box",start,.25)
		await projectile("paper" if i==3 else "envelope",damage[i],.35,-22 if i%2==1 else 15,0,STAMPS[index] if i==4 else "",start)
	veil.queue_free()
	clip("prepare",.25)
	await wait(.22)

func defend() -> void:
	mark("windup")
	clip("prepare",.35)
	await wait(.27)
	mark("execution")
	clip("brace",.55)
	var who: Control=battle.enemy_character
	if index in [6,7]:
		for i in range(2 if index==7 else 1):
			var ally := fx("shadow",center(who)+Vector2(22+i*20,-3),1)
			ally.persistent=true; allies.append(ally)
	await wait(.30)
	shield=fx("guard",center(who),1)
	shield.persistent=true; shield.follow=who; shield.pattern=GUARDS[index]
	shield.span=who.body_rect().size*Vector2(.53,.50)
	if index==4:
		shield.kind="route"; shield.follow=null; shield.position=foot(who)
	if index==5: caption("UNDER CONSTRUCTION",center(who))
	uses+=1; cooldown=2
	battle._enemy_guard=move.guard_reduction
	battle._show_enemy_guard_badge()
	battle._enemy_guard_badge.position=who.body_rect().position+Vector2(0,-12)
	battle._enemy_guard_badge.text="GUARD -35%"
	battle._refresh_damage_preview()
	sound("impact")
	await wait(.22)

func consume_guard() -> void:
	if is_instance_valid(shield):
		shield.impact=true; shield.persistent=false; shield.age=0; shield.lifetime=.35
		shield=null
	for ally in allies:
		if is_instance_valid(ally): ally.persistent=false; ally.age=0; ally.lifetime=.35
	allies.clear()
	var burst := fx("burst",center(battle.enemy_character),.48)
	burst.pattern="coin" if index==2 else "paper"
	caption("REROUTED" if index==4 else "BLOCK -35%",center(battle.enemy_character)+Vector2(0,-25))
	Audio.play_move_sfx(battle._enemy.moves[2].signature_id(),"impact")

func defend_impact(damage: int) -> void:
	var who: Control=battle.enemy_character
	battle._body_begin(who,battle.BODY_FEET)
	clip("block_hit",.52)
	caption("-%d HP" % damage,center(who)+Vector2(0,4))
	if index==4:
		fx("route",foot(who),.5)
		await battle._body_play(who,[battle._beat(-17,0,-3,1,1,.18),battle._beat(-17,0,0,1,1,.13),battle._beat(0,0,0,1,1,.20)])
	else:
		await battle._body_play(who,[battle._beat(3 if index==7 else 6,1,2,1,1,.13),battle._beat(2,0,0,1,1,.18),battle._beat(0,0,0,1,1,.20)])
	await battle._body_end(who,.06)
	battle.enemy_character.play_idle()

func clear_effects() -> void:
	for child in get_children(): child.queue_free()
	shield=null; allies.clear()
