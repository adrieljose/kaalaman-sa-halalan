extends Node2D
## Pixel-native materials shared by choreography, not generic spell circles.
var kind := "paper"
var tint := Color("e9c575")
var age := 0.0
var lifetime := .5
var persistent := false
var span := Vector2(35,55)
var follow: Control
var pattern := "paper"
var impact := false
signal flight_finished(arrived: bool)
var flight_tween: Tween
var flying := false
var trail_enabled := false
var trail_points: Array[Vector2]=[]

func fly(start: Vector2, target: Vector2, seconds: float, arc: float=0, spin: float=0, growth: float=0, ricochet: bool=false) -> bool:
	persistent=true; flying=true; position=start
	var initial_scale := scale
	flight_tween=create_tween()
	flight_tween.tween_method(func(p: float) -> void:
		var offset := sin(p*TAU)*27 if ricochet else sin(p*PI)*arc
		position=(start.lerp(target,p)+Vector2(0,offset)).round()
		if trail_enabled:
			trail_points.append(position)
			if trail_points.size()>5: trail_points.pop_front()
		rotation=spin*p; scale=initial_scale*(1+p*growth)
	,0.0,1.0,seconds)
	flight_tween.tween_callback(func() -> void:
		flying=false
		flight_finished.emit(true))
	var arrived: bool=await flight_finished
	return arrived

func cancel_flight() -> void:
	if is_instance_valid(flight_tween): flight_tween.kill()
	if flying:
		flying=false
		flight_finished.emit(false)

func _exit_tree() -> void:
	cancel_flight()

func _process(delta: float) -> void:
	age+=delta
	if is_instance_valid(follow): position=(follow.position+follow.body_rect().get_center()).round()
	if not persistent and age>=lifetime:
		queue_free()
		return
	queue_redraw()

func rect(at: Vector2, size: Vector2, c: Color) -> void:
	draw_rect(Rect2(at.round(),size.round()),c)

func paper(at: Vector2, blue: bool=false) -> void:
	rect(at-Vector2(10,13),Vector2(20,26),Color("26303b"))
	rect(at-Vector2(8,11),Vector2(16,22),Color("81c5e8") if blue else Color("ffedbd"))
	for y in [-6,-2,2]: rect(at+Vector2(-5,y),Vector2(10,1),Color("65819b") if blue else Color("807865"))
	rect(at+Vector2(2,5),Vector2(4,4),Color("b85457"))

func coin(at: Vector2) -> void:
	draw_circle(at.round(),4,Color("936028"),true,-1,false)
	draw_circle(at.round(),3,Color("f8d16b"),true,-1,false)
	rect(at+Vector2(-1,-2),Vector2(1,4),Color("946127"))

func _draw() -> void:
	modulate.a=1.0 if persistent else clampf((lifetime-age)/.15,0,1)
	if trail_enabled and trail_points.size()>1:
		var points := PackedVector2Array()
		for point in trail_points: points.append((point-position).rotated(-rotation)/scale)
		draw_polyline(points,Color(tint,.45),2,false)
	match kind:
		"paper","envelope","blueprint","tag","ballot":
			paper(Vector2.ZERO,kind=="blueprint")
			if kind=="ballot":
				draw_polyline(PackedVector2Array([Vector2(-5,1),Vector2(-1,5),Vector2(6,-4)]),tint,2,false)
			if kind=="envelope":
				draw_polyline(PackedVector2Array([Vector2(-8,-9),Vector2(0,0),Vector2(8,-9)]),Color("8c6b58"),1,false)
			if kind=="tag":
				draw_circle(Vector2(4,-7),2,Color("a66151"),true,-1,false)
		"box":
			rect(Vector2(-13,-10),Vector2(26,21),Color("27343c"))
			rect(Vector2(-11,-8),Vector2(22,17),Color("72939d"))
			rect(Vector2(-12,-4),Vector2(24,2),Color("b9cdd0"))
			rect(Vector2(-2,-1),Vector2(5,6),Color("e7c178"))
		"rubble":
			draw_colored_polygon(PackedVector2Array([Vector2(-14,-3),Vector2(-6,-12),Vector2(10,-8),Vector2(15,3),Vector2(6,12),Vector2(-10,9)]),Color("a19c89"))
			draw_polyline(PackedVector2Array([Vector2(-6,-9),Vector2(0,-1),Vector2(-4,8)]),Color("575850"),2,false)
		"coin": coin(Vector2.ZERO)
		"burst":
			for i in range(10):
				var a := float(i)*TAU/10
				var at := Vector2(cos(a),sin(a))*(age*70+5)+Vector2(0,age*age*40)
				if pattern=="coin": coin(at)
				else: rect(at,Vector2(3+(i%3),2+(i%2)),tint)
		"stamp","seal","shock":
			var points := PackedVector2Array()
			for i in range(17):
				var a := float(i)*TAU/16
				points.append(Vector2(cos(a),sin(a))*(18+age*35))
			draw_polyline(points,tint,3,false)
			if kind=="stamp": rect(Vector2(-14,-3),Vector2(28,6),tint)
		"check":
			draw_polyline(PackedVector2Array([Vector2(-20,0),Vector2(-4,17),Vector2(24,-23)]),tint,5,false)
		"grid","zone":
			for i in range(-3,4):
				draw_line(Vector2(i*12,-17),Vector2(i*12,17),tint,1,false)
				draw_line(Vector2(-36,i*5),Vector2(36,i*5),tint,1,false)
			if kind=="zone":
				for i in range(3):
					var rise := clampf(age*45,0,22)
					rect(Vector2(-27+i*22,-rise),Vector2(15,rise),Color("87c8d2"))
					rect(Vector2(-24+i*22,-rise+3),Vector2(3,3),Color("314b69"))
		"route":
			draw_polyline(PackedVector2Array([Vector2(-30,0),Vector2(28,0),Vector2(18,-8),Vector2(28,0),Vector2(18,8)]),tint,3,false)
		"shadow":
			# Deliberately anonymous summoned support, not a duplicate enemy.
			var c := Color(.09,.06,.14,.7)
			draw_circle(Vector2(0,-36),8,c,true,-1,false)
			rect(Vector2(-11,-28),Vector2(22,29),c)
			rect(Vector2(-15,0),Vector2(10,25),c); rect(Vector2(5,0),Vector2(10,25),c)
			draw_polyline(PackedVector2Array([Vector2(-8,-22),Vector2(-21,-12),Vector2(-30,-25)]),c,7,false)
		"guard":
			var c := Color.WHITE if impact else tint
			if pattern=="seal":
				var points := PackedVector2Array()
				for i in range(17):
					var a:=float(i)*TAU/16
					points.append(Vector2(cos(a)*span.x,sin(a)*span.y))
				draw_polyline(points,c,2,false)
			else:
				draw_rect(Rect2(-span,span*2),Color(c,.045),true)
				draw_rect(Rect2(-span,span*2),c,false,2)
			if pattern=="grid":
				for i in range(-2,3): draw_line(Vector2(i*span.x/3,-span.y),Vector2(i*span.x/3,span.y),c,1,false)
			if pattern=="barricade":
				for i in range(6):
					rect(Vector2(-span.x+i*span.x/3,-4),Vector2(span.x/3,8),Color("f1c44e") if i%2==0 else Color("30303a"))
			if pattern=="paperwall":
				for i in range(3): draw_line(Vector2(-span.x,(-1+i)*span.y*.5),Vector2(span.x,(-1+i)*span.y*.5),c,2,false)
