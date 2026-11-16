extends SceneTree
var game
var checks = []
var failures = 0
func _initialize(): call_deferred("run")
func check(label, ok):
	checks.append({"check":label,"pass":ok})
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func tick(n):
	for i in range(n): game._physics_process(1.0/60.0)
func mouse(button, pressed, pos):
	var event = InputEventMouseButton.new()
	event.button_index=button; event.pressed=pressed; event.position=pos
	game._input(event)
func keyboard(code, pressed):
	var event=InputEventKey.new(); event.physical_keycode=code; event.pressed=pressed
	Input.parse_input_event(event); Input.flush_buffered_events()
func run():
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	game.set_physics_process(false); game.test_mode=true; game.touch_controls=false; game.has_save=false
	game.size=Vector2(1280,720); game._layout()
	check("Desktop defaults to keyboard and mouse controls",not game.touch_controls)
	mouse(MOUSE_BUTTON_LEFT,true,Vector2(game.size.x*.34,435)); mouse(MOUSE_BUTTON_LEFT,false,Vector2.ZERO); tick(3)
	check("Mouse starts a game from the main menu",game.mode=="play" and game.grounded)
	check("Menu click does not leave attack held",not game.mouse_attack_held and game.attack_serial==0)
	var start_x=game.player.x
	keyboard(KEY_D,true); tick(40); keyboard(KEY_D,false)
	check("Physical D key moves the player right",game.player.x>start_x+155)
	check("Releasing D stops held movement",not game.act("right"))
	game.set_physics_process(true); keyboard(KEY_SPACE,true)
	await physics_frame; await process_frame
	game.set_physics_process(false)
	check("Physical Space triggers a jump",game.vel.y<0 and game.jumps==1)
	await process_frame
	keyboard(KEY_SPACE,false); tick(8)
	await process_frame
	game.set_physics_process(true); keyboard(KEY_SPACE,true)
	await physics_frame; await process_frame
	game.set_physics_process(false)
	check("Second physical Space press double jumps",game.jumps==2 and game.vel.y<0)
	keyboard(KEY_SPACE,false); await process_frame; tick(100)
	game.player=Vector2(230,550); game.vel=Vector2.ZERO; game.attack_cd=0
	mouse(MOUSE_BUTTON_LEFT,true,Vector2(600,300)); tick(60)
	check("Holding left mouse repeats melee attacks",game.attack_serial>=3 and game.mouse_attack_held)
	mouse(MOUSE_BUTTON_LEFT,false,Vector2.ZERO); var serial=game.attack_serial; tick(40)
	check("Releasing left mouse stops repeated attacks",not game.mouse_attack_held and game.attack_serial==serial)
	mouse(MOUSE_BUTTON_RIGHT,true,Vector2(600,300)); tick(1)
	check("Right mouse triggers a dash",game.dash_time>0 and absf(game.vel.x)>700)
	keyboard(KEY_ESCAPE,true); keyboard(KEY_ESCAPE,false)
	check("Escape opens the pause screen",game.mode=="pause")
	keyboard(KEY_ENTER,true); keyboard(KEY_ENTER,false)
	check("Enter resumes from pause",game.mode=="play")
	var b=game.buttons["jump"]
	check("Hidden phone jump button cannot capture desktop clicks",game._button_at(Vector2(b.x,b.y))=="")
	var report={"total":checks.size(),"passed":checks.size()-failures,"failed":failures,"checks":checks}
	var p=ProjectSettings.globalize_path("res://").path_join("../../output/desktop-test-results.json").simplify_path()
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f=FileAccess.open(p,FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("RESULT ",checks.size()-failures,"/",checks.size()," desktop checks passed")
	game.queue_free(); await process_frame; quit(1 if failures else 0)
