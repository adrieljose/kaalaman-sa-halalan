extends Node
## The shadow has to find a character's FEET after the combat choreography has
## moved, rotated and scaled it about an arbitrary pivot. This checks that a
## global-transform round trip actually reports that point, rather than trusting
## that Control.get_transform() composes the way I assume.
func _ready() -> void:
	await get_tree().process_frame
	var host := Control.new()
	host.size = Vector2(640, 480)
	add_child(host)
	var who := AnimatedCharacter.new()
	who.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	who.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.add_child(who)
	who.configure_clips(GameState.PLAYER_CHARACTERS["male"])
	who.position = Vector2(100, 200)
	who.size = Vector2(120, 180)
	await get_tree().process_frame

	var body := who.body_rect()
	var foot_local := Vector2(body.position.x + body.size.x * 0.5, body.end.y)
	var to_host := func(): return host.get_global_transform().affine_inverse() \
		* (who.get_global_transform() * foot_local)

	print("body_rect              %s" % body)
	print("rest foot in host      %s   (expect y = 200 + %.1f)" % [to_host.call(), body.end.y])
	who.pivot_offset = Vector2(60, 180)
	who.rotation = deg_to_rad(10.0)
	who.scale = Vector2(1.1, 0.9)
	print("after rot+scale        %s" % to_host.call())
	who.position += Vector2(40, -25)
	print("after a 25px lift      %s" % to_host.call())
	get_tree().quit(0)
