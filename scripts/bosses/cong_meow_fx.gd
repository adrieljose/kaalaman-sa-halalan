extends Node2D
## Code-native pixel VFX: no filtered textures, gradients or antialiased lines.
var kind: String = "paw"
var tint := Color("ffd56b")
var age := 0.0
var lifetime := 0.5
var persistent := false
var radius := Vector2(35, 62)
var reverse := false
var follow: Control

func _process(delta: float) -> void:
	age += delta
	if is_instance_valid(follow):
		position = (follow.position + follow.body_rect().get_center()).round()
	if not persistent and age >= lifetime:
		queue_free()
		return
	queue_redraw()

func pixel(p: Vector2, s: Vector2, color: Color) -> void:
	draw_rect(Rect2(p.round(), s.round()), color)

func paw(p: Vector2, scale_by: float = 1.0) -> void:
	for r in [Rect2(-3,0,6,5),Rect2(-6,-4,3,3),Rect2(-2,-6,3,3),Rect2(2,-5,3,3),Rect2(5,-2,3,3)]:
		pixel(p+r.position*scale_by,r.size*scale_by,tint)

func cat(p: Vector2) -> void:
	pixel(p+Vector2(-10,-6),Vector2(20,14),tint)
	pixel(p+Vector2(-10,-12),Vector2(6,8),tint)
	pixel(p+Vector2(4,-12),Vector2(6,8),tint)
	for x in [-5,4]: pixel(p+Vector2(x,-1),Vector2(2,3),Color("322642"))
	pixel(p+Vector2(-1,3),Vector2(3,2),Color("322642"))

func _draw() -> void:
	var fade := 1.0 if persistent else clampf((lifetime-age)/0.15,0,1)
	modulate.a = fade
	match kind:
		"shield", "emblem":
			var r := radius if kind=="shield" else Vector2(radius.x,8)
			for i in range(48):
				var angle := TAU*float(i)/48.0
				var point := Vector2(cos(angle)*r.x,sin(angle)*r.y)
				pixel(point,Vector2(3,3),tint)
				if i>0:
					var prior := TAU*float(i-1)/48.0
					draw_line(Vector2(cos(prior)*r.x,sin(prior)*r.y).round(),point.round(),tint,1,false)
			if kind=="shield":
				# Angular ears and curling cat-tail energy orbit the protected body.
				for side in [-1,1]:
					draw_polyline(PackedVector2Array([Vector2(side*22,-r.y+8),Vector2(side*30,-r.y-12),Vector2(side*9,-r.y)]),tint,2,false)
				for i in range(14):
					var a := age*3.0+float(i)*.16
					pixel(Vector2(cos(a)*r.x,sin(a)*r.y).round(),Vector2(3,3),Color("fff4c7"))
				paw(Vector2(0,r.y-6))
			else: cat(Vector2.ZERO)
		"claw":
			for i in range(3):
				var x := float(i-1)*11
				var points := PackedVector2Array([Vector2(x-22,-24),Vector2(x-5,-3),Vector2(x+10,25)])
				if reverse:
					for j in points.size(): points[j].x=-points[j].x
				draw_polyline(points,Color("7b396f"),5,false)
				draw_polyline(points,tint,2,false)
		"cat": cat(Vector2.ZERO)
		"bubble":
			pixel(Vector2(-24,-12),Vector2(48,25),Color("413257"))
			pixel(Vector2(-22,-10),Vector2(44,20),tint)
			pixel(Vector2(-15,8),Vector2(6,9),tint)
		"burst":
			for i in range(8):
				var angle := float(i)*TAU/8
				paw(Vector2(cos(angle),sin(angle))*(8+age*65),.7)
		_: paw(Vector2.ZERO)
