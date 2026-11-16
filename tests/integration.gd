extends SceneTree

var game
var checks: Array = []
var failures = 0

func _initialize():
	call_deferred("run")

func check(label: String, condition: bool):
	checks.append({"check":label,"pass":condition})
	print("PASS " if condition else "FAIL ",label)
	if not condition: failures += 1

func tick(n: int):
	for i in range(n): game._physics_process(1.0/60.0)

func press(action: String, finger: int = 1):
	var b: Vector3 = game.buttons[action]
	var event = InputEventScreenTouch.new()
	event.index = finger; event.position = Vector2(b.x,b.y); event.pressed = true
	game._input(event)

func release(finger: int = 1):
	var event = InputEventScreenTouch.new()
	event.index = finger; event.position = Vector2.ZERO; event.pressed = false
	game._input(event)

func reset():
	game.start_new(); game.zone_timer = 0; game._clear_input(); tick(3)

func run():
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.test_mode = true
	game.touch_controls = true
	game.save_path = "user://vesper-integration-test.json"
	game.size = Vector2(1280,720); game._layout()
	check("Initial scene opens the main menu",game.mode == "menu")
	game._click_menu(Vector2(game.size.x*.34,435)); tick(3)
	check("Start button enters a playable world",game.mode == "play" and game.grounded)
	var start: Vector2 = game.player
	press("right"); tick(45); release()
	check("Touch movement accelerates and moves right",game.player.x > start.x+170)
	reset(); press("jump"); tick(20)
	check("Touch jump lifts player above ground",game.player.y < 460)
	release(); tick(1); press("jump"); tick(1)
	check("Second touch triggers the double jump",game.jumps == 2 and game.vel.y < -500)
	release(); tick(130)
	check("Gravity returns the player to a platform",game.grounded and game.hp > 0)
	reset(); var dash_start = game.player.x
	press("dash"); tick(12); release()
	check("Dash moves forward and starts a cooldown",game.player.x-dash_start>110 and game.dash_cd>0)
	tick(55)
	check("Dash cooldown recovers",game.dash_cd == 0)
	reset(); game.hp = 3; game.soul = 100
	press("heal"); tick(50); release()
	check("Holding heal restores health and consumes light",game.hp == 4 and game.soul <= 65)
	reset(); var e: Dictionary = game.enemies[0]; e["dir"] = 0.0
	game.soul = 20
	for i in range(3):
		game.player = e["pos"]-Vector2(74,0); game.facing = 1; game.invuln = 1
		press("attack"); tick(1); release(); tick(26)
	check("Three distinct melee strikes defeat a ground enemy",e["hp"] <= 0)
	check("Combat rewards light and shards",game.soul >= 47 and game.shards >= 9)
	reset(); game.player = Vector2(7998,550); game.vel = Vector2(280,0)
	press("right"); tick(5); release()
	check("Final gate blocks entry without three seals",game.player.x <= 8000 and not game.boss_active)
	reset()
	for i in range(3):
		game.player = game.relics[i]+Vector2(0,40); game.vel = Vector2.ZERO; tick(1)
	check("All three reachable relics register once",game.seals.size() == 3)
	var before_shards = game.shards; tick(3)
	check("Collected relics cannot be farmed twice",game.seals.size()==3 and game.shards==before_shards)
	game.player = Vector2(8060,550); game.vel = Vector2.ZERO; tick(1)
	check("Collecting the seals unlocks the boss arena",game.boss_active)
	game.boss["timer"] = 0; tick(1)
	check("Boss telegraphs its attack before charging",game.boss["state"] == "warn")
	game.invuln = 100; tick(56)
	check("Boss transitions from warning to a real charge",game.boss["state"] == "dash")
	game.boss["state"] = "recover"; game.boss["timer"] = 999; game.boss["pos"] = Vector2(8510,550)
	game.boss["hp"] = 28; game.projectiles.clear()
	for i in range(28):
		game.player = Vector2(8420,550); game.vel = Vector2.ZERO; game.facing = 1; game.invuln = 999
		press("attack"); tick(1); release(); tick(26)
	check("Boss can be defeated with actual melee damage",game.boss_dead and not game.boss_active)
	game.player = Vector2(8900,550); game.vel = Vector2.ZERO
	press("interact"); tick(1); release()
	check("Lighting the final lantern reaches the ending",game.mode == "win")
	reset(); game.checkpoint = 1; game.seals = [0]; game.hp = 1; game.player = Vector2(900,1000)
	tick(1)
	check("A fatal fall opens the death screen",game.mode == "dead")
	game.respawn(); tick(2)
	check("Respawn preserves seals and returns to checkpoint",game.mode == "play" and game.hp == 5 and game.seals.has(0) and absf(game.player.x-2885)<5)
	reset(); game.player = game.lamps[2]+Vector2(20,0); game.hp=2; game.soul=12
	press("interact"); tick(1); release()
	check("Checkpoint interaction restores health and light",game.checkpoint==2 and game.hp==5 and game.soul==100)
	game.test_mode = false; game.seals = [0,1]; game.shards=73; game._save_game(); game.test_mode=true
	game.start_new(); game.continue_game(); tick(2)
	check("Save and reload preserve checkpoint, seals and shards",game.checkpoint==2 and game.seals.size()==2 and game.shards==73)
	var f = FileAccess.open(game.save_path,FileAccess.WRITE); f.store_string("invalid json"); f.close()
	game.continue_game()
	check("Invalid save data recovers to a new playable game",game.mode == "play" and game.hp==5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	game.mode = "play"
	press("right",0); press("jump",1); tick(1)
	check("Multitouch supports movement and jumping together",game.act("right") and game.act("jump") and game.vel.y<0 and game.vel.x>0)
	release(0); release(1)
	var report = {"total":checks.size(),"passed":checks.size()-failures,"failed":failures,"checks":checks}
	var report_path = ProjectSettings.globalize_path("res://").path_join("../output/test-results.json").simplify_path()
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var out = FileAccess.open(report_path,FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"  ")); out.close()
	print("RESULT ",checks.size()-failures,"/",checks.size()," passed")
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
