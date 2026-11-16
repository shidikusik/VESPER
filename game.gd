extends Node2D
## VESPER: original, self-contained 2D action adventure. No network or plugins.

const CYAN = Color("8be1e1")
const WHITE = Color("f1f0df")
const GOLD = Color("d6bb83")
const INK = Color("07111e")
const SAVE_PATH = "user://vesper_save.json"
var save_path = SAVE_PATH
const WORLD_END = 9160.0
const ZONE_NAMES = ["УТОПЛЕННЫЙ СОБОР", "САД ЗАБЫТЫХ КОРНЕЙ", "КОЛЫБЕЛЬ ЗАТМЕНИЯ"]
const ZONE_SUB = ["Там, где свет ещё помнит имена", "Слушай тишину под корнями", "Последний огонь не должен погаснуть"]
const ZONE_COLORS = [Color("6dbfcf"), Color("6ccbb2"), Color("b0a2e4")]

var bg: Texture2D = preload("res://assets/cathedral.png")
var hero: Texture2D = preload("res://assets/hero.png")
var icon: Texture2D = preload("res://assets/icon.png")
var warden: Texture2D = preload("res://assets/warden.png")
var enemy_sheet: Texture2D = preload("res://assets/enemies.png")
var font: Font = preload("res://assets/sans.ttf")
var serif: Font = preload("res://assets/serif.ttf")
var mode = "menu"
var previous_mode = "menu"
var size = Vector2(1280, 720)
var clock = 0.0
var cam = Vector2.ZERO
var player = Vector2(230, 550)
var vel = Vector2.ZERO
var facing = 1.0
var grounded = false
var coyote = 0.0
var jump_buffer = 0.0
var jumps = 0
var hp = 5
var max_hp = 5
var soul = 65.0
var shards = 0
var seals: Array = []
var checkpoint = 0
var zone = 0
var zone_timer = 0.0
var notice = ""
var notice_time = 0.0
var invuln = 0.0
var attack_time = 0.0
var attack_cd = 0.0
var attack_serial = 0
var attack_buffer = 0.0
var dash_time = 0.0
var dash_cd = 0.0
var heal_time = 0.0
var death_time = 0.0
var shake = 0.0
var hit_stop = 0.0
var boss_active = false
var boss_dead = false
var boss = {"pos": Vector2(8510, 550), "hp": 28, "max": 28, "timer": 1.6, "state": "idle", "phase": 0, "dir": -1.0, "hit": -1, "hurt": 0.0}
var platforms: Array = []
var spikes: Array = []
var enemies: Array = []
var pickups: Array = []
var particles: Array = []
var projectiles: Array = []
var lamps = [Vector2(250, 550), Vector2(2820, 550), Vector2(5860, 550), Vector2(7340, 550)]
var relics = [Vector2(1690, 287), Vector2(4270, 272), Vector2(6570, 240)]
var fingers = {}
var pending = {}
var buttons = {}
var music_on = true
var low_fx = false
var music: AudioStreamPlayer
var sfx: AudioStreamPlayer
var sfx_jump: AudioStream = preload("res://assets/jump.wav")
var sfx_hit: AudioStream = preload("res://assets/hit.wav")
var sfx_bell: AudioStream = preload("res://assets/bell.wav")
var has_save = false
var test_mode = false
var touch_controls = OS.has_feature("mobile")
var mouse_attack_held = false
var capture_path = ""
var capture_shot = ""
var capture_frames = 0
var capture_done = false

func _ready():
	_setup_input()
	_build_world()
	load_settings()
	has_save = FileAccess.file_exists(save_path)
	music = AudioStreamPlayer.new()
	music.stream = preload("res://assets/ambience.wav")
	music.volume_db = -15
	add_child(music)
	music.finished.connect(func():
		if music_on: music.play())
	if music_on and not DisplayServer.get_name() == "headless": music.play()
	sfx = AudioStreamPlayer.new()
	sfx.volume_db = -10
	add_child(sfx)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--shot="): capture_shot = arg.trim_prefix("--shot=")
		if arg == "--test": test_mode = true
		if arg == "--touch-controls": touch_controls = true
	if not capture_path.is_empty():
		test_mode = true
		start_new()
		match capture_shot:
			"garden": player = Vector2(4030, 550); seals = [0]; shards = 86
			"boss":
				player = Vector2(8150, 550); seals = [0, 1, 2]; shards = 174
				boss_active = true; boss["hp"] = 22
			"menu": mode = "menu"
			_: player = Vector2(1180, 550); shards = 24
		zone_timer = 0.0
		cam.x = maxf(0, player.x - 430)
	queue_redraw()

func _setup_input():
	var bindings = {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE, KEY_W, KEY_UP], "attack": [KEY_J, KEY_Z], "dash": [KEY_K, KEY_SHIFT], "heal": [KEY_H, KEY_C], "interact": [KEY_E], "map": [KEY_M, KEY_TAB], "pause": [KEY_ESCAPE, KEY_P]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for code in bindings[action]:
			var event = InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)

func _build_world():
	platforms.clear(); enemies.clear(); spikes.clear(); pickups.clear()
	# Ground and ledges are in world units. One-way ledges keep movement forgiving.
	for r in [Rect2(0,550,840,300), Rect2(1040,550,970,300), Rect2(2230,550,1180,300), Rect2(3630,550,1530,300), Rect2(5390,550,840,300), Rect2(6460,550,1100,300), Rect2(7750,550,1410,300)]:
		platforms.append({"r":r, "floor":true})
	for r in [Rect2(540,445,180,30), Rect2(770,365,170,30), Rect2(1130,425,170,30), Rect2(1390,352,180,30), Rect2(1600,325,205,34), Rect2(1930,430,160,30), Rect2(2130,360,160,30), Rect2(2480,420,190,30), Rect2(3080,425,170,30), Rect2(3330,342,170,30), Rect2(3570,420,190,30), Rect2(3870,414,180,30), Rect2(4170,310,200,34), Rect2(4480,405,190,30), Rect2(4800,438,200,30), Rect2(5100,372,180,30), Rect2(5330,420,180,30), Rect2(5570,355,180,30), Rect2(6090,432,180,30), Rect2(6290,350,180,30), Rect2(6470,278,210,34), Rect2(6810,393,175,30), Rect2(7130,445,180,30), Rect2(7490,405,170,30), Rect2(7720,430,190,30), Rect2(7970,362,170,30), Rect2(8730,390,190,30)]:
		platforms.append({"r":r, "floor":false})
	for r in [Rect2(1430,532,100,18), Rect2(2590,532,90,18), Rect2(3860,532,95,18), Rect2(4790,532,100,18), Rect2(5720,532,90,18), Rect2(6890,532,100,18)]: spikes.append(r)
	for spec in [[650,0],[1280,0],[1820,1],[2440,0],[3120,1],[3810,0],[4540,1],[5020,0],[5630,1],[6010,0],[6730,1],[7100,0],[7900,1]]:
		var x = float(spec[0]); var kind = int(spec[1])
		enemies.append({"pos":Vector2(x,550 if kind == 0 else 370),"origin":x,"hp":3 if kind == 0 else 2,"kind":kind,"dir":-1.0,"t":x * 0.01,"hit":-1,"hurt":0.0,"fire":2.5})
	for i in range(45):
		var x = 430.0 + i * 182.0
		pickups.append({"pos":Vector2(x, 486 - (i % 3) * 6), "taken":false})

func start_new():
	_build_world()
	player = Vector2(230,550); vel = Vector2.ZERO; hp = 5; soul = 65
	shards = 0; seals.clear(); checkpoint = 0; boss_active = false; boss_dead = false
	boss = {"pos": Vector2(8510,550),"hp":28,"max":28,"timer":1.6,"state":"idle","phase":0,"dir":-1.0,"hit":-1,"hurt":0.0}
	particles.clear(); projectiles.clear(); invuln = 0; attack_cd = 0; dash_cd = 0
	attack_buffer = 0; attack_time = 0; dash_time = 0; hit_stop = 0; heal_time = 0; grounded = false; jumps = 0
	zone = 0; zone_timer = 4.0; mode = "play"; cam = Vector2.ZERO
	toast("Найди три печати и разбуди последний фонарь", 5)
	_clear_input()

func act(action: String) -> bool:
	return Input.is_action_pressed(action) or fingers.values().has(action) or (action == "attack" and mouse_attack_held)

func just(action: String) -> bool:
	return Input.is_action_just_pressed(action) or pending.get(action, false)

func _clear_input():
	fingers.clear(); pending.clear(); mouse_attack_held = false

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F11:
			var full = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif event.is_action("pause"):
			if mode == "play": mode = "pause"; _save_game()
			elif mode in ["pause", "map"]: mode = "play"
			elif mode == "settings": mode = previous_mode
			_clear_input(); get_viewport().set_input_as_handled()
		elif event.is_action("map") and mode in ["play","map"]:
			mode = "map" if mode == "play" else "play"; _clear_input()
		elif event.physical_keycode == KEY_ENTER:
			match mode:
				"menu":
					if has_save: continue_game()
					else: start_new()
				"pause": mode = "play"; _clear_input()
				"dead":
					if death_time > 0.6: respawn()
				"win": mode = "menu"
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				mouse_attack_held = false; fingers.erase(-100)
			elif mode != "play": _click_menu(event.position)
			else:
				var a = _button_at(event.position)
				if a == "pause": mode = "pause"; _save_game(); _clear_input()
				elif a == "map": mode = "map"; _clear_input()
				elif touch_controls and a != "": fingers[-100] = a; pending[a] = true
				elif not touch_controls: mouse_attack_held = true; pending["attack"] = true
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and mode == "play": pending["dash"] = true
	if event is InputEventScreenTouch:
		if event.pressed:
			if mode != "play": _click_menu(event.position)
			else:
				var a = _button_at(event.position)
				if a == "pause": mode = "pause"; _save_game(); _clear_input()
				elif a == "map": mode = "map"; _clear_input()
				elif a != "": fingers[event.index] = a; pending[a] = true
		else: fingers.erase(event.index)
	elif event is InputEventScreenDrag and fingers.has(event.index):
		if fingers[event.index] in ["left","right"]:
			var a = _button_at(event.position)
			fingers[event.index] = a if a in ["left","right"] else ""

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if mode == "play": _save_game()
		get_tree().quit()
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if mode == "play" and not test_mode: mode = "pause"; _save_game(); _clear_input()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if mode == "play": mode = "pause"; _save_game()
		elif mode in ["pause","map"]: mode = "play"
		else: mode = "menu"
		_clear_input()

func _physics_process(dt):
	size = get_viewport_rect().size
	_layout()
	clock += dt
	for i in range(particles.size()-1,-1,-1):
		var p = particles[i]
		p["life"] -= dt; p["pos"] += p["v"] * dt; p["v"].y += p.get("gravity",80.0) * dt
		if p["life"] <= 0: particles.remove_at(i)
	shake = move_toward(shake,0,dt*28)
	notice_time = maxf(0,notice_time-dt)
	zone_timer = maxf(0,zone_timer-dt)
	if mode == "play":
		if hit_stop > 0: hit_stop -= dt
		else: _step_player(dt); _step_enemies(dt); _step_boss(dt); _step_projectiles(dt); _collect()
		var new_zone = 0 if player.x < 3000 else (1 if player.x < 6200 else 2)
		if new_zone != zone: zone = new_zone; zone_timer = 3.6
		var target = Vector2(clampf(player.x-size.x*0.40,0,maxf(0,WORLD_END-size.x)),clampf(player.y-490,-180,30))
		cam = cam.lerp(target,1.0-exp(-dt*6.0))
	elif mode == "dead":
		death_time += dt
	pending.clear()
	queue_redraw()
	if not capture_path.is_empty() and not capture_done:
		capture_frames += 1
		if capture_frames == 82 and capture_shot == "ruins": pending["attack"] = true
		if capture_frames == 90: _capture()

func _step_player(dt):
	invuln = maxf(0,invuln-dt); attack_time = maxf(0,attack_time-dt)
	attack_cd = maxf(0,attack_cd-dt); dash_cd = maxf(0,dash_cd-dt)
	var direction = float(act("right"))-float(act("left"))
	if direction != 0: facing = direction
	if grounded: coyote = 0.12; jumps = 0
	else: coyote = maxf(0,coyote-dt)
	if just("jump"): jump_buffer = 0.14
	else: jump_buffer = maxf(0,jump_buffer-dt)
	if jump_buffer > 0 and (coyote > 0 or jumps < 2):
		if not grounded and coyote <= 0 and jumps == 0: jumps = 1
		vel.y = -600 if jumps == 0 else -560
		jumps += 1; jump_buffer = 0; coyote = 0; grounded = false
		burst(player-Vector2(0,10),CYAN,10,110)
		play_sound(sfx_jump,-7)
	if not act("jump") and vel.y < -220: vel.y = move_toward(vel.y,-220,dt*2100)
	if just("dash") and dash_cd <= 0:
		dash_time = 0.17; dash_cd = 0.8; invuln = maxf(invuln,0.23)
		burst(player-Vector2(0,40),CYAN,14,130)
	if just("attack"): attack_buffer = 0.15
	else: attack_buffer = maxf(0,attack_buffer-dt)
	if (attack_buffer > 0 or act("attack")) and attack_cd <= 0 and dash_time <= 0:
		attack_time = 0.24; attack_cd = 0.32; attack_serial += 1; attack_buffer = 0.0
		play_sound(sfx_hit,-12)
	if act("heal") and soul >= 35 and hp < max_hp and grounded and direction == 0 and attack_time <= 0:
		heal_time += dt
		if heal_time >= 0.8:
			hp += 1; soul -= 35; heal_time = 0; burst(player-Vector2(0,45),CYAN,26,80); play_sound(sfx_bell,-8)
	else: heal_time = 0.0
	if dash_time > 0:
		dash_time -= dt; vel = Vector2(facing*800,0)
		if Engine.get_physics_frames() % 3 == 0: burst(player-Vector2(0,45),Color("509bc7"),3,25)
	else:
		vel.x = move_toward(vel.x,direction*280,dt*(2400 if grounded else 1600))
		vel.y = minf(vel.y+1580*dt,900)
	var before = player
	player.x = clampf(player.x+vel.x*dt,24,WORLD_END-40)
	# Raised ledges are one-way; ground walls stop the player only below their lip.
	for plat in platforms:
		var r: Rect2 = plat["r"]
		if plat["floor"] and before.y > r.position.y+14 and player.y-70 < r.end.y:
			if before.x+15 <= r.position.x and player.x+15 > r.position.x: player.x = r.position.x-15; vel.x = 0
			elif before.x-15 >= r.end.x and player.x-15 < r.end.x: player.x = r.end.x+15; vel.x = 0
	player.y += vel.y*dt
	grounded = false
	if vel.y >= 0:
		for plat in platforms:
			var r: Rect2 = plat["r"]
			if player.x+13 > r.position.x and player.x-13 < r.end.x and before.y <= r.position.y+3 and player.y >= r.position.y:
				player.y = r.position.y; vel.y = 0; grounded = true
	if player.y > 950: _fall()
	for r in spikes:
		if Rect2(player-Vector2(13,75),Vector2(26,75)).intersects(r): damage(1,signf(player.x-r.get_center().x))
	if player.x > 8000 and seals.size() < 3:
		player.x = 8000; toast("Врата ждут три печати · найдено %d/3" % seals.size(),2)
	if player.x > 8030 and seals.size() == 3 and not boss_active and not boss_dead:
		boss_active = true; toast("СТРАЖ ЗАТМЕНИЯ",3); play_sound(sfx_bell,-4)
	if boss_active and not boss_dead: player.x = clampf(player.x,8030,9100)
	if just("interact"):
		var near = nearby_lamp()
		if near >= 0:
			checkpoint = near; hp = max_hp; soul = 100; _save_game()
			toast("Фонарь зажжён · путь сохранён",3); burst(lamps[near]-Vector2(0,70),GOLD,35,130); play_sound(sfx_bell,-5)
		elif boss_dead and player.x > 8750: mode = "win"; _save_game()

func _fall():
	hp -= 1
	if hp <= 0: die(); return
	player = lamps[checkpoint]+Vector2(65,0); vel = Vector2.ZERO; invuln = 1.6; shake = 8
	cam.x = maxf(0,player.x-size.x*0.4)
	toast("Свет фонаря вернул тебя",2)

func damage(amount: int, dir: float):
	if invuln > 0 or mode != "play": return
	hp -= amount; invuln = 1.2; vel = Vector2(dir*310,-280); shake = 9
	burst(player-Vector2(0,40),Color("cba0be"),22,210)
	play_sound(sfx_hit,0)
	if hp <= 0: die()

func die():
	hp = 0; death_time = 0; mode = "dead"; _clear_input(); burst(player-Vector2(0,45),CYAN,50,220)

func respawn():
	hp = max_hp; soul = maxf(50,soul); player = lamps[checkpoint]+Vector2(65,0); vel = Vector2.ZERO
	invuln = 1.8; boss_active = false; boss["hp"] = 28; boss["state"] = "idle"; boss["timer"] = 1.7; boss["pos"] = Vector2(8510,550)
	projectiles.clear(); mode = "play"; _clear_input(); cam.x = maxf(0,player.x-size.x*0.4)
	for e in enemies: e["hp"] = 3 if e["kind"] == 0 else 2

func _step_enemies(dt):
	for e in enemies:
		if e["hp"] <= 0: continue
		e["hurt"] = maxf(0,e["hurt"]-dt); e["t"] += dt
		var p: Vector2 = e["pos"]
		if absf(p.x-player.x) > 1250: continue
		if e["kind"] == 0:
			e["pos"].x += e["dir"] * 64 * dt
			if absf(e["pos"].x-e["origin"]) > 95: e["dir"] *= -1
		else:
			e["pos"] = Vector2(e["origin"]+sin(e["t"]*1.3)*75,360+sin(e["t"]*2.4)*45)
			e["fire"] -= dt
			if e["fire"] <= 0 and absf(player.x-p.x) < 640:
				e["fire"] = 3.3
				projectiles.append({"pos":p-Vector2(0,20),"v":(player-Vector2(0,40)-p).normalized()*170,"life":5.0,"r":7.0})
		p = e["pos"]
		if attack_time > 0.06 and e["hit"] != attack_serial and _attack_rect().intersects(Rect2(p-Vector2(28,52),Vector2(56,52))):
			e["hp"] -= 1; e["hit"] = attack_serial; e["hurt"] = 0.16; e["pos"].x += facing*20
			soul = minf(100,soul+9); shake = 4; hit_stop = 0.035
			burst(p-Vector2(0,30),CYAN,16,180); play_sound(sfx_hit,-1)
			if e["hp"] <= 0:
				shards += 9; burst(p-Vector2(0,30),GOLD,22,190)
		if absf(p.x-player.x) < 42 and absf((p.y-25)-(player.y-38)) < 45: damage(1,signf(player.x-p.x))

func _attack_rect() -> Rect2:
	return Rect2(player+Vector2(5 if facing > 0 else -115,-95),Vector2(110,100))

func _step_boss(dt):
	if not boss_active or boss_dead: return
	boss["timer"] -= dt; boss["hurt"] = maxf(0,boss["hurt"]-dt)
	var p: Vector2 = boss["pos"]
	if boss["state"] == "idle":
		boss["dir"] = signf(player.x-p.x)
		if boss["timer"] <= 0:
			boss["phase"] += 1; boss["state"] = "warn"; boss["timer"] = 0.85 if boss["hp"] > 14 else 0.65
	elif boss["state"] == "warn" and boss["timer"] <= 0:
		if boss["phase"] % 2 == 0:
			boss["state"] = "cast"; boss["timer"] = 1.0
			for i in range(5 if boss["hp"] > 14 else 7):
				var angle = -PI+0.15+i*0.27
				projectiles.append({"pos":p-Vector2(0,80),"v":Vector2(cos(angle),sin(angle))*240,"life":4.0,"r":10.0})
			shake = 5
		else: boss["state"] = "dash"; boss["timer"] = 0.8; burst(p-Vector2(0,60),GOLD,20,140)
	elif boss["state"] == "dash":
		boss["pos"].x = clampf(p.x+boss["dir"]*600*dt,8130,9000)
		if boss["timer"] <= 0: boss["state"] = "recover"; boss["timer"] = 1.3
	elif boss["state"] in ["cast","recover"] and boss["timer"] <= 0:
		boss["state"] = "idle"; boss["timer"] = 0.7
	p = boss["pos"]
	if attack_time > 0.06 and boss["hit"] != attack_serial and _attack_rect().intersects(Rect2(p-Vector2(53,155),Vector2(106,155))):
		boss["hp"] -= 1; boss["hit"] = attack_serial; boss["hurt"] = 0.18
		soul = minf(100,soul+10); shake = 6; hit_stop = 0.045; burst(p-Vector2(0,90),GOLD,20,180); play_sound(sfx_hit,-1)
		if boss["hp"] <= 0:
			boss_dead = true; boss_active = false; projectiles.clear(); shards += 100
			burst(p-Vector2(0,80),GOLD,90,260); toast("Свет вернулся. Зажги фонарь за вратами →",6); _save_game()
	if absf(p.x-player.x) < 64 and player.y > p.y-135: damage(1,signf(player.x-p.x))

func _step_projectiles(dt):
	for i in range(projectiles.size()-1,-1,-1):
		var b = projectiles[i]; b["pos"] += b["v"]*dt; b["life"] -= dt
		if b["life"] <= 0 or b["pos"].y > 850: projectiles.remove_at(i); continue
		if b["pos"].distance_to(player-Vector2(0,40)) < 25:
			damage(1,signf(player.x-b["pos"].x)); projectiles.remove_at(i)

func _collect():
	for i in range(relics.size()):
		if not seals.has(i) and player.distance_to(relics[i]+Vector2(0,40)) < 66:
			seals.append(i); soul = 100; hp = mini(max_hp,hp+1); shards += 20
			burst(relics[i],GOLD,45,180); toast("Печать пробуждена · %d / 3" % seals.size(),3.5); play_sound(sfx_bell,-3); _save_game()
	for p in pickups:
		if not p["taken"] and p["pos"].distance_to(player-Vector2(0,35)) < 45:
			p["taken"] = true; shards += 1; soul = minf(100,soul+2); burst(p["pos"],CYAN,5,45)

func nearby_lamp() -> int:
	for i in range(lamps.size()):
		if player.distance_to(lamps[i]) < 100: return i
	return -1

func burst(pos: Vector2, color: Color, count: int, force: float):
	if low_fx: count = maxi(2,count/3)
	for i in range(count):
		if particles.size() > 220: break
		var angle = randf()*TAU; var v = Vector2(cos(angle),sin(angle))*randf_range(force*0.2,force)
		particles.append({"pos":pos,"v":v,"life":randf_range(0.25,0.8),"col":color,"r":randf_range(1,3.3)})

func toast(text: String, seconds = 3.0):
	notice = text; notice_time = seconds

func play_sound(stream: AudioStream, db = -5.0):
	if test_mode or not music_on or not is_instance_valid(sfx): return
	sfx.stream = stream; sfx.volume_db = db; sfx.play()

func _save_game():
	if test_mode: return
	var data = {"version":1,"checkpoint":checkpoint,"seals":seals,"shards":shards,"boss_dead":boss_dead}
	var f = FileAccess.open(save_path,FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(data)); has_save = true

func continue_game():
	start_new()
	if not FileAccess.file_exists(save_path): return
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(save_path)) != OK: return
	var data = parser.data
	if not data is Dictionary: return
	checkpoint = clampi(int(data.get("checkpoint",0)),0,lamps.size()-1)
	seals.clear()
	for seal_id in data.get("seals",[]):
		var id = int(seal_id)
		if id >= 0 and id < 3 and not seals.has(id): seals.append(id)
	shards = maxi(0,int(data.get("shards",0))); boss_dead = bool(data.get("boss_dead",false))
	player = lamps[checkpoint]+Vector2(65,0); cam.x = maxf(0,player.x-size.x*0.4)
	zone = 0 if player.x < 3000 else (1 if player.x < 6200 else 2)
	toast("Фонарь помнит твой путь",3)

func load_settings():
	var cfg = ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		music_on = cfg.get_value("game","audio",true); low_fx = cfg.get_value("game","low_fx",false)

func save_settings():
	if test_mode: return
	var cfg = ConfigFile.new()
	cfg.set_value("game","audio",music_on); cfg.set_value("game","low_fx",low_fx); cfg.save("user://settings.cfg")

func _layout():
	var w = size.x; var h = size.y
	buttons = {"left":Vector3(76,h-85,45),"right":Vector3(182,h-85,45),"jump":Vector3(w-87,h-105,53),"attack":Vector3(w-205,h-136,47),"dash":Vector3(w-192,h-45,32),"heal":Vector3(w-85,h-221,31),"pause":Vector3(w-44,43,24),"map":Vector3(w-105,43,24),"interact":Vector3(124,h-202,31)}

func _button_at(pos: Vector2) -> String:
	for key in buttons:
		if not touch_controls and key not in ["pause", "map"]: continue
		if key == "interact" and nearby_lamp() < 0 and not (boss_dead and player.x > 8750): continue
		var b: Vector3 = buttons[key]
		if pos.distance_to(Vector2(b.x,b.y)) <= b.z+9: return key
	return ""

func _click_menu(pos: Vector2):
	var center = size*0.5
	match mode:
		"menu":
			var cx = size.x*0.34
			if Rect2(cx-160,410,320,58).has_point(pos):
				if has_save: continue_game()
				else: start_new()
			elif Rect2(cx-160,484,320,46).has_point(pos):
				if has_save: mode = "confirm_new"
				else: previous_mode = "menu"; mode = "settings"
			elif has_save and Rect2(cx-160,544,320,42).has_point(pos): previous_mode = "menu"; mode = "settings"
		"pause":
			if Rect2(center.x-155,286,310,54).has_point(pos): mode = "play"; _clear_input()
			elif Rect2(center.x-155,354,310,48).has_point(pos): mode = "map"
			elif Rect2(center.x-155,416,310,48).has_point(pos): previous_mode = "pause"; mode = "settings"
			elif Rect2(center.x-155,478,310,48).has_point(pos): _save_game(); mode = "menu"
		"settings":
			if Rect2(center.x-210,285,420,60).has_point(pos):
				music_on = not music_on; save_settings()
				if music_on: music.play()
				else: music.stop()
			elif Rect2(center.x-210,365,420,60).has_point(pos): low_fx = not low_fx; save_settings()
			elif Rect2(center.x-155,480,310,54).has_point(pos): mode = previous_mode
		"map": mode = "play"; _clear_input()
		"dead":
			if death_time > 0.6 and Rect2(center.x-165,414,330,56).has_point(pos): respawn()
		"win":
			if Rect2(center.x-165,490,330,56).has_point(pos): mode = "menu"
		"confirm_new":
			if Rect2(center.x-165,380,330,56).has_point(pos): start_new(); _save_game()
			elif Rect2(center.x-165,456,330,48).has_point(pos): mode = "menu"

func _capture():
	capture_done = true
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	var err = image.save_png(capture_path)
	print("CAPTURE ",capture_path," ",image.get_size()," code=",err)
	image = null
	var tree = get_tree()
	tree.create_timer(0.15).timeout.connect(tree.quit.bind(0 if err == OK else 1))
	tree.call_deferred("unload_current_scene")

# ----- Painting: all screenshots use this exact runtime renderer. -----
var world_offset = Vector2.ZERO
var glow_texture: Texture2D

func _make_glow():
	var gradient = Gradient.new()
	gradient.set_color(0,Color(1,1,1,0.8)); gradient.set_color(1,Color(1,1,1,0))
	gradient.add_point(0.25,Color(1,1,1,0.27)); gradient.add_point(0.6,Color(1,1,1,0.055))
	var tex = GradientTexture2D.new()
	tex.gradient = gradient; tex.width = 128; tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5,0.5); tex.fill_to = Vector2(1,0.5)
	glow_texture = tex

func glow(pos: Vector2, radius: float, color: Color):
	if glow_texture == null: _make_glow()
	draw_texture_rect(glow_texture,Rect2(pos-Vector2.ONE*radius,Vector2.ONE*radius*2),false,color)

func _draw():
	size = get_viewport_rect().size
	_layout()
	_background()
	if mode in ["menu","settings","confirm_new"] and (mode != "settings" or previous_mode == "menu"):
		_draw_menu()
		if mode == "settings": _settings()
		elif mode == "confirm_new": _confirm_new()
		return
	world_offset = -cam
	if shake > 0 and not low_fx: world_offset += Vector2(sin(clock*117),cos(clock*93))*shake
	draw_set_transform(world_offset)
	_world_decor()
	for plat in platforms:
		var r: Rect2 = plat["r"]
		if r.end.x < cam.x-100 or r.position.x > cam.x+size.x+100: continue
		_platform(r,plat["floor"])
	for r in spikes:
		if _visible(r.position.x): _thorns(r)
	for i in range(lamps.size()):
		if _visible(lamps[i].x): _lamp(lamps[i],i==checkpoint)
	for i in range(relics.size()):
		if _visible(relics[i].x) and not seals.has(i): _relic(relics[i],i)
	for p in pickups:
		if not p["taken"] and _visible(p["pos"].x):
			var loc: Vector2 = p["pos"]+Vector2(0,sin(clock*2.2+p["pos"].x)*5)
			glow(loc,18,Color(0.4,0.9,0.9,0.35)); _diamond(loc,3,CYAN)
	for e in enemies:
		if e["hp"] > 0 and _visible(e["pos"].x): _enemy(e)
	if not boss_dead and _visible(boss["pos"].x): _draw_boss()
	if boss_active:
		for x in [8020,9130]:
			glow(Vector2(x,390),125,Color(0.65,0.55,0.8,0.3))
			for j in range(8): draw_line(Vector2(x+sin(clock*3+j)*6,270+j*35),Vector2(x+cos(clock*2+j)*6,307+j*35),Color(0.6,0.55,0.8,0.35),3,true)
	if boss_dead:
		_lamp(Vector2(8920,550),true)
		glow(Vector2(8920,390),220,Color(0.9,0.75,0.4,0.5))
	for b in projectiles:
		glow(b["pos"],b["r"]*5,Color(0.7,0.4,0.8,0.5))
		draw_circle(b["pos"],b["r"],Color("efafde")); draw_circle(b["pos"],b["r"]*.45,WHITE)
	_draw_hero()
	for p in particles:
		var c: Color = p["col"]; c.a *= minf(1,p["life"]*2)
		draw_circle(p["pos"],p["r"],c)
	_foreground()
	draw_set_transform(Vector2.ZERO)
	_vignette()
	_hud()
	if mode == "pause": _pause()
	elif mode == "settings": _settings()
	elif mode == "map": _map()
	elif mode == "dead": _death()
	elif mode == "win": _win()

func _visible(x: float) -> bool:
	return x > cam.x-150 and x < cam.x+size.x+150

func _background():
	var cover = maxf(size.x/bg.get_width(),size.y/bg.get_height())*1.10
	var dim = Vector2(bg.get_size())*cover
	var motion = Vector2(-fmod(cam.x*.055,80),-cam.y*.10)
	var col = Color(0.70,0.80,0.87) if mode in ["menu","settings","confirm_new"] else Color(0.56,0.72,0.83)
	if zone == 1: col = Color(0.42,0.72,0.66)
	elif zone == 2: col = Color(0.58,0.58,0.77)
	draw_texture_rect(bg,Rect2((size-dim)*.5+motion,dim),false,col)
	_quad_gradient(Rect2(Vector2.ZERO,size),Color(0.015,0.025,0.045,0.12),Color(0.015,0.025,0.045,0.76))
	# Slowly drifting dust lives in screen space and never obscures collision shapes.
	var count = 26 if low_fx else 72
	for i in range(count):
		var x = fposmod(i*137.71+sin(clock*.13+i)*30-cam.x*.12,size.x)
		var y = fposmod(i*89.13-clock*(3+i%4),size.y*.82)
		var a = (0.2+0.19*sin(clock+i))*0.7
		draw_circle(Vector2(x,y),1.0+(i%3)*.45,Color(.60,.85,.88,a))

func _quad_gradient(r: Rect2, top: Color, bottom: Color):
	draw_polygon(PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]),PackedColorArray([top,top,bottom,bottom]))

func _world_decor():
	# Midground ruined columns and arch traces at a different parallax depth.
	var first = int((cam.x-250)/460)
	for i in range(first,first+int(size.x/460)+3):
		var x = i*460.0+130
		var c = Color(0.035,0.10,0.15,0.62)
		draw_rect(Rect2(x,155,26,395),c)
		draw_rect(Rect2(x-9,150,44,16),Color(0.12,0.24,0.28,0.4))
		draw_line(Vector2(x+7,180),Vector2(x+7,530),Color(.2,.35,.38,.24),2,true)
		draw_arc(Vector2(x+155,250),142,PI,TAU,28,Color(0.14,0.28,0.33,0.28),8,true)
		for j in range(4): draw_line(Vector2(x+62+j*48,259),Vector2(x+62+j*48,505),Color(.12,.25,.29,.20),3,true)
	# A readable landmark over every relic.
	for i in range(relics.size()):
		var p: Vector2 = relics[i]
		if _visible(p.x):
			glow(p+Vector2(0,-90),155,Color(ZONE_COLORS[i],0.25))
			draw_arc(p+Vector2(0,-80),80,0,TAU,64,Color(ZONE_COLORS[i],.18),1,true)
			for j in range(8):
				var a = j*TAU/8
				draw_line(p+Vector2(0,-80)+Vector2.from_angle(a)*74,p+Vector2(0,-80)+Vector2.from_angle(a)*83,Color(ZONE_COLORS[i],.4),2,true)
	# Hanging roots, broken chains, and soft shafts of moonlight.
	for i in range(int(cam.x/340)-1,int((cam.x+size.x)/340)+2):
		var x = i*340.0+80
		var length = 150+absf(sin(i*2.1))*115
		var chain = PackedVector2Array()
		for j in range(14): chain.append(Vector2(x+sin(j*.3+i)*12,j*length/13-80))
		draw_polyline(chain,Color(.03,.08,.11,.9),5,true)
		if i%2 == 0:
			var p = chain[-1]
			glow(p,75,Color(0.3,0.7,0.8,0.16)); draw_circle(p,3,Color("79a9b2"))

func _platform(r: Rect2, floor_piece: bool):
	var x = r.position.x; var y = r.position.y; var w = r.size.x
	var h = minf(r.size.y,230)
	var points = PackedVector2Array([Vector2(x,y+6),Vector2(x+9,y),Vector2(x+w-12,y),Vector2(x+w,y+7),Vector2(x+w-4,y+h*.7),Vector2(x+w-22,y+h),Vector2(x+w*.55,y+h-8),Vector2(x+20,y+h+5),Vector2(x+4,y+h*.6)])
	draw_colored_polygon(points,Color("0c1b27"))
	var close = points.duplicate(); close.append(points[0]); draw_polyline(close,Color("050d17"),3,true)
	draw_rect(Rect2(x+6,y+8,w-12,10),Color("183443"))
	draw_line(Vector2(x+10,y+2),Vector2(x+w-12,y+2),Color("476675"),2,true)
	draw_line(Vector2(x+11,y+15),Vector2(x+w-9,y+15),Color(.025,.05,.08,.8),2,true)
	for j in range(int(w/62)):
		var tx = x+j*62+18
		draw_line(Vector2(tx,y+20),Vector2(tx+sin(tx)*9,y+minf(h-4,48)),Color("1e3541"),1,true)
		if j%3 == 1: draw_line(Vector2(tx+5,y+29),Vector2(tx+31,y+30),Color("1a303b"),1,true)
	if floor_piece:
		_quad_gradient(Rect2(x+2,y+50,w-4,h-50),Color(.04,.09,.13,.05),Color(.012,.025,.045,1))
		for j in range(int(w/120)):
			var px = x+j*120+40
			draw_arc(Vector2(px,y+92),30,PI,TAU,16,Color(.12,.23,.28,.28),3,true)
	# Moss strands cling to the lit edge and small ferns break its silhouette.
	for j in range(int(w/17)):
		var px = x+9+j*17
		var b = 3+absf(sin(px*3.2))*9
		draw_line(Vector2(px,y+3),Vector2(px+4,y+b),Color("264a50"),2,true)
	for j in range(int(w/102)+1):
		var px = x+25+j*102
		if px > x+w-10: continue
		_plant(Vector2(px,y),0.65+absf(sin(px))*.65)
	# Roots under floating ledges.
	if not floor_piece:
		for j in range(3):
			var px = x+20+j*w/3
			draw_polyline(PackedVector2Array([Vector2(px,y+h-2),Vector2(px+6,y+h+14),Vector2(px+2,y+h+32-j*8)]),Color("193039"),2,true)

func _plant(p: Vector2, s: float):
	var tint = Color("397478") if zone != 1 else Color("468a75")
	for j in range(3):
		var a = -PI*.82+j*.35+sin(p.x+clock*1.3)*.05
		var end = p+Vector2(cos(a)*18*s,sin(a)*22*s)
		draw_line(p,end,tint,1.2,true)
		var mid = p.lerp(end,.62)
		var axis = (end-mid).normalized()
		var normal = Vector2(-axis.y,axis.x)*3*s
		var leaf = PackedVector2Array([mid-axis*4*s,mid+normal,end,mid-normal])
		draw_colored_polygon(leaf,Color(tint,.8))
	if int(p.x)%4 == 0:
		var t = p+Vector2(5,-25*s)
		draw_line(p,t,Color("4a777b"),1.3,true)
		_oval(t,Vector2(9,4)*s,Color("72c3c2"))
		glow(t,27*s,Color(.3,.9,.8,.16))

func _thorns(r: Rect2):
	for i in range(int(r.size.x/13)):
		var p = r.position+Vector2(i*13,0)
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,18),p+Vector2(7,-7),p+Vector2(13,18)]),Color("53556e"))
		draw_line(p+Vector2(7,-7),p+Vector2(2,15),Color("9b8ca4"),1,true)

func _lamp(p: Vector2, lit: bool):
	var color = GOLD if lit else Color("80d6dd")
	glow(p-Vector2(0,82),125,Color(color,.43 if lit else .18))
	draw_rect(Rect2(p.x-24,p.y-8,48,8),Color("253c49"))
	draw_line(p+Vector2(0,-7),p+Vector2(0,-66),Color("2e3e4d"),10,true)
	draw_line(p+Vector2(-2,-13),p+Vector2(-2,-65),Color("617584"),2,true)
	draw_line(p+Vector2(-25,-67),p+Vector2(25,-67),Color("52717c"),4,true)
	draw_colored_polygon(PackedVector2Array([p+Vector2(-17,-68),p+Vector2(-12,-106),p+Vector2(0,-118),p+Vector2(12,-106),p+Vector2(17,-68)]),Color("152b39"))
	draw_polyline(PackedVector2Array([p+Vector2(-17,-68),p+Vector2(-12,-106),p+Vector2(0,-118),p+Vector2(12,-106),p+Vector2(17,-68)]),Color("6c8790"),2,true)
	_oval(p+Vector2(0,-86),Vector2(7+sin(clock*4),17),Color(color,.75))
	draw_circle(p+Vector2(0,-86),4,WHITE)
	for j in [-1,1]: draw_line(p+Vector2(j*11,-73),p+Vector2(j*8,-104),Color("091723"),3,true)
	if lit: draw_arc(p-Vector2(0,84),34,-PI*.95,-PI*.05,25,Color(GOLD,.5),1,true)

func _relic(p: Vector2, index: int):
	var bob = Vector2(0,sin(clock*2.2+index)*8)
	glow(p+bob,90,Color(GOLD,.42))
	draw_arc(p+bob,26,clock*.6,clock*.6+TAU*.78,40,Color(GOLD,.55),1.2,true)
	draw_arc(p+bob,34,-clock*.3,-clock*.3+PI,24,Color(CYAN,.28),1,true)
	_diamond(p+bob,14,GOLD); _diamond(p+bob,8,Color("f5f2da")); _diamond(p+bob,3,Color("97e7df"))
	for j in range(4):
		var angle = j*TAU/4+clock*.5
		_diamond(p+bob+Vector2.from_angle(angle)*34,2,CYAN)

func _diamond(p: Vector2, r: float, color: Color):
	draw_colored_polygon(PackedVector2Array([p+Vector2(0,-r),p+Vector2(r*.64,0),p+Vector2(0,r),p+Vector2(-r*.64,0)]),color)

func _oval(p: Vector2, r: Vector2, color: Color, angle = 0.0):
	var pts = PackedVector2Array()
	for i in range(24): pts.append(p+(Vector2.from_angle(i*TAU/24)*r).rotated(angle))
	draw_colored_polygon(pts,color)

func _enemy(e: Dictionary):
	var p: Vector2 = e["pos"]
	var flash = e["hurt"] > 0
	if e["kind"] == 0:
		_oval(p+Vector2(0,-2),Vector2(30,6),Color(0,0,0,.35))
		var bob = sin(clock*11+e["origin"])*1.4
		draw_set_transform(world_offset+p+Vector2(0,bob),0,Vector2(-e["dir"],1))
		draw_texture_rect_region(enemy_sheet,Rect2(-43,-63,86,66),Rect2(50,148,815,548),Color(1.4,1.4,1.6) if flash else Color(1,1,1))
	else:
		var flap = 1.0+sin(clock*11+e["origin"])*.11
		draw_set_transform(world_offset+p-Vector2(0,24),sin(clock*2)*.05,Vector2(flap,1))
		draw_texture_rect_region(enemy_sheet,Rect2(-61,-49,122,84),Rect2(1030,80,937,616),Color(1.4,1.4,1.6) if flash else Color(.86,.94,1))
	draw_set_transform(world_offset)
	if e["kind"] == 1: glow(p-Vector2(0,12),30,Color(.55,.35,.85,.24))

func _draw_boss():
	var p: Vector2 = boss["pos"]
	var pulse = sin(clock*2)*2
	var warning = boss["state"] == "warn"
	glow(p-Vector2(0,100),160,Color(.5,.35,.7,.18))
	_oval(p-Vector2(0,2),Vector2(72,11),Color(0,0,0,.4))
	var flip = 1.0 if boss["dir"]<0 else -1.0
	draw_set_transform(world_offset+p+Vector2(0,pulse),-.07*flip if boss["state"]=="dash" else 0,Vector2(flip,1))
	draw_texture_rect(warden,Rect2(-110,-249,220,255),false,Color(1.4,1.3,1.4) if boss["hurt"]>0 else Color(.85,.82,.97))
	draw_set_transform(world_offset)
	if warning:
		glow(p-Vector2(0,164),100,Color(1,.65,.46,.37))
		draw_line(p+Vector2(boss["dir"]*70,-3),p+Vector2(boss["dir"]*500,-3),Color(1,.5,.4,.45),2,true)
		_diamond(p+Vector2(0,-273),9,Color("edbb8d"))
	if boss["state"]=="dash":
		var slash = p+Vector2(boss["dir"]*50,-80)
		draw_arc(slash,102,-PI*.8,PI*.6,40,Color(.9,.7,.95,.7),5,true)

func _draw_hero():
	if mode == "dead": return
	var run = absf(vel.x)>40 and grounded
	var bob = sin(clock*(17 if run else 2.4))*(2.5 if run else 1.2)
	var alpha = 0.40 if invuln > 0 and fmod(clock,.12)<.055 else 1.0
	_oval(player+Vector2(0,-1),Vector2(27,6),Color(0,0,0,.38))
	glow(player-Vector2(0,60),78,Color(.4,.8,.9,.13))
	if dash_time > 0:
		for i in range(1,4):
			draw_set_transform(world_offset+player-Vector2(facing*i*28,0),0,Vector2(facing,1))
			draw_texture_rect(hero,Rect2(-59,-112,118,118),false,Color(.35,.65,.9,.16/i))
	draw_set_transform(world_offset+player+Vector2(0,bob),vel.x*.00010,Vector2(facing,1))
	draw_texture_rect(hero,Rect2(-59,-112,118,118),false,Color(1,1,1,alpha))
	draw_set_transform(world_offset)
	if attack_time > 0:
		var phase = (0.24-attack_time)/.24
		var center = player+Vector2(facing*16,-55)
		var a = -1.45+phase*2.5
		var pts = PackedVector2Array()
		for i in range(22):
			var angle = a-1.2+i*.09
			pts.append(center+Vector2(cos(angle)*facing,sin(angle))*100)
		for i in range(21,-1,-1):
			var angle = a-1.2+i*.09
			pts.append(center+Vector2(cos(angle)*facing,sin(angle))*67)
		draw_colored_polygon(pts,Color(.68,.95,.98,.65*(1-phase)))
		draw_arc(center,99,a-1.2 if facing>0 else PI-a-.69,a+.69 if facing>0 else PI-a+1.2,28,Color(.9,1,1,.9*(1-phase)),3,true)
	if heal_time > 0:
		glow(player-Vector2(0,50),90,Color(.5,1,.8,.5))
		draw_arc(player-Vector2(0,50),46,-PI/2,-PI/2+TAU*heal_time/.8,48,CYAN,2,true)

func _foreground():
	# Fine silhouetted grasses frame the ground without hiding hazards.
	for i in range(int(cam.x/210),int((cam.x+size.x)/210)+1):
		var x = i*210.0+35
		for j in range(4):
			var base = Vector2(x+j*10,686)
			draw_polyline(PackedVector2Array([base,base+Vector2(-5,-30-j*7),base+Vector2(-18,-42-j*9)]),Color(.008,.018,.03,.8),4,true)

func _vignette():
	_quad_gradient(Rect2(0,0,size.x,135),Color(.005,.012,.025,.80),Color(.005,.012,.025,0))
	_quad_gradient(Rect2(0,size.y-140,size.x,140),Color(.005,.012,.025,0),Color(.005,.012,.025,.83))
	_quad_gradient(Rect2(0,0,size.x,8),Color(0,0,0,.20),Color(0,0,0,0))

func text_at(text: String, pos: Vector2, sz: int, color = WHITE, use_serif = false):
	draw_string(serif if use_serif else font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,sz,color)

func text_center(text: String, y: float, sz: int, color = WHITE, use_serif = false, x = -1.0):
	var f = serif if use_serif else font
	var w = f.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,sz).x
	text_at(text,Vector2((size.x if x<0 else x*2)*.5-w*.5,y),sz,color,use_serif)

func panel(r: Rect2, color = Color(.025,.055,.085,.91), border = Color(.32,.55,.61,.4), radius = 15):
	var s = StyleBoxFlat.new()
	s.bg_color = color; s.border_color = border; s.set_border_width_all(1); s.set_corner_radius_all(radius)
	draw_style_box(s,r)

func _hud():
	panel(Rect2(24,22,242,78),Color(.025,.055,.085,.76),Color(.32,.55,.61,.24),18)
	for i in range(5):
		var p = Vector2(51+i*41,48)
		_mask_icon(p,12,WHITE if i<hp else Color("263644"))
	text_at("СВЕТ",Vector2(40,85),10,Color("8cabb8"))
	draw_rect(Rect2(86,77,158,5),Color("182b3a"))
	draw_rect(Rect2(86,77,158*soul/100,5),CYAN)
	text_at("%03d" % shards,Vector2(52,130),19,GOLD)
	_diamond(Vector2(36,123),7,GOLD)
	text_center(ZONE_NAMES[zone],45,14,Color("acbfcb"))
	for i in range(3): _diamond(Vector2(size.x*.5-24+i*24,69),7,GOLD if seals.has(i) else Color("324657"))
	if boss_active:
		var bw = minf(size.x-320,620)
		var bx = (size.x-bw)*.5
		text_center("СТРАЖ ЗАТМЕНИЯ",size.y-37,15,Color("ddc3d6"),true)
		draw_rect(Rect2(bx,size.y-24,bw,5),Color("282438"))
		draw_rect(Rect2(bx,size.y-24,bw*float(boss["hp"])/28,5),Color("c59ab6"))
	_controls()
	if zone_timer > 0:
		var a = minf(1,minf(zone_timer,4-zone_timer))
		text_center(ZONE_NAMES[zone],187,29,Color(WHITE,maxf(.0,a)),true)
		text_center(ZONE_SUB[zone],218,13,Color(CYAN,maxf(.0,a*.8)))
	if notice_time > 0:
		var y = 153 if zone_timer<=0 else 258
		var width = font.get_string_size(notice,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+38
		panel(Rect2((size.x-width)*.5,y-25,width,39),Color(.025,.055,.085,.85),Color(.4,.65,.7,.25),12)
		text_center(notice,y,15,Color("d6e5e6"))
	if player.x < 520:
		if touch_controls:
			text_center("Двойной прыжок · рывок · удар · удерживай + для лечения",size.y-28,12,Color("88a6b3"))
		else:
			text_center("A/D — движение    Пробел — прыжок    ЛКМ/J — меч    Shift/ПКМ — рывок",size.y-40,12,Color("88a6b3"))
			text_center("H — лечение    E — фонарь    M — карта    Esc — пауза    F11 — полный экран",size.y-19,11,Color("88a6b3"))

func _mask_icon(p: Vector2, r: float, color: Color):
	var pts = PackedVector2Array([p+Vector2(-r,-r*.25),p+Vector2(-r*.7,-r),p+Vector2(r*.7,-r),p+Vector2(r,-r*.25),p+Vector2(r*.62,r*.6),p+Vector2(0,r),p+Vector2(-r*.62,r*.6)])
	draw_colored_polygon(pts,color)
	_oval(p+Vector2(-r*.34,0),Vector2(r*.16,r*.28),INK,-.25)
	_oval(p+Vector2(r*.34,0),Vector2(r*.16,r*.28),INK,.25)

func _controls():
	var visible_actions = ["left","right","jump","attack","dash","heal","pause","map"] if touch_controls else ["pause","map"]
	for a in visible_actions:
		var b: Vector3 = buttons[a]; var p = Vector2(b.x,b.y); var r = b.z
		var active = act(a)
		var c = Color(.24,.65,.70,.40) if active else Color(.035,.09,.14,.65)
		if a == "jump": c = Color(.17,.37,.42,.66) if not active else Color(.3,.7,.7,.7)
		draw_circle(p,r,c); draw_arc(p,r,0,TAU,50,Color(.48,.73,.77,.55 if a=="jump" else .25),1.3,true)
		var col = Color("c8e1e2") if a in ["jump","attack"] else Color("7d9daa")
		match a:
			"left","right":
				var d = -1 if a=="left" else 1
				draw_polyline(PackedVector2Array([p+Vector2(-d*5,-12),p+Vector2(d*8,0),p+Vector2(-d*5,12)]),col,2.5,true)
			"jump":
				draw_polyline(PackedVector2Array([p+Vector2(-13,5),p+Vector2(0,-10),p+Vector2(13,5)]),col,2.8,true)
				draw_polyline(PackedVector2Array([p+Vector2(-9,17),p+Vector2(0,7),p+Vector2(9,17)]),Color(col,.6),2,true)
			"attack":
				draw_line(p+Vector2(-11,12),p+Vector2(14,-15),col,3,true)
				draw_line(p+Vector2(-13,2),p+Vector2(-3,12),GOLD,2.5,true)
				_diamond(p+Vector2(16,-17),4,col)
			"dash":
				for j in range(2): draw_polyline(PackedVector2Array([p+Vector2(-8+j*10,-7),p+Vector2(-1+j*10,0),p+Vector2(-8+j*10,7)]),col,2,true)
				if dash_cd>0: draw_arc(p,r-3,-PI/2,-PI/2+TAU*dash_cd/.8,32,Color(.7,.85,.85,.5),2,true)
			"heal":
				draw_line(p-Vector2(7,0),p+Vector2(7,0),col,2.5,true); draw_line(p-Vector2(0,7),p+Vector2(0,7),col,2.5,true)
			"pause":
				for j in [-1,1]: draw_line(p+Vector2(j*4,-7),p+Vector2(j*4,7),col,2,true)
			"map":
				draw_polyline(PackedVector2Array([p+Vector2(-9,7),p+Vector2(-9,-7),p+Vector2(-3,-4),p+Vector2(3,-7),p+Vector2(9,-4),p+Vector2(9,9),p+Vector2(3,6),p+Vector2(-3,9),p+Vector2(-9,7)]),col,1.5,true)
	if nearby_lamp()>=0 or (boss_dead and player.x>8750):
		if not touch_controls:
			panel(Rect2(size.x*.5-135,size.y-115,270,43),Color(.06,.10,.13,.88),Color(GOLD,.4),10)
			text_center("E  ·  ЗАЖЕЧЬ ФОНАРЬ",size.y-87,13,GOLD)
			return
		var b: Vector3 = buttons["interact"]; var p = Vector2(b.x,b.y)
		glow(p,60,Color(GOLD,.2)); draw_circle(p,b.z,Color(.15,.16,.15,.78)); draw_arc(p,b.z,0,TAU,40,Color(GOLD,.6),1.3,true)
		_diamond(p,11,GOLD)
		text_at("ЗАЖЕЧЬ",p+Vector2(-28,52),11,GOLD)

func _draw_menu():
	_vignette()
	var x = size.x*.34
	# The hero portrait is the actual in-game sprite, drawn over the painted world.
	var hero_x = size.x*.76
	glow(Vector2(hero_x,351),255,Color(.25,.70,.8,.24))
	draw_arc(Vector2(hero_x,280),144,0,TAU,100,Color(.45,.8,.8,.35),1,true)
	draw_arc(Vector2(hero_x,280),158,PI*.18,PI*.87,40,Color(GOLD,.3),1,true)
	var hero_dim = Vector2(333,390)
	draw_texture_rect(hero,Rect2(Vector2(hero_x-hero_dim.x*.5,207+sin(clock*1.7)*3),hero_dim),false,Color(.9,.95,1))
	text_center("П Е С Н Ь   Г Л У Б И Н",191,13,Color("9db8c6"),false,x)
	text_center("VESPER",291,82,WHITE,true,x)
	draw_line(Vector2(x-125,318),Vector2(x-20,318),Color(GOLD,.5),1,true)
	_diamond(Vector2(x,318),6,GOLD)
	draw_line(Vector2(x+20,318),Vector2(x+125,318),Color(GOLD,.5),1,true)
	text_center("Когда гаснет мир — стань его светом.",357,14,Color("a8c1cb"),false,x)
	_menu_button(Rect2(x-160,410,320,58),"ПРОДОЛЖИТЬ" if has_save else "НАЧАТЬ ПУТЬ",true)
	_menu_button(Rect2(x-160,484,320,46),"НОВАЯ ИГРА" if has_save else "НАСТРОЙКИ",false)
	if has_save: _menu_button(Rect2(x-160,544,320,42),"НАСТРОЙКИ",false)
	text_at("ОРИГИНАЛЬНОЕ ПРИКЛЮЧЕНИЕ",Vector2(32,size.y-46),10,Color("78939f"))
	text_at("3 области  ·  один последний огонь",Vector2(32,size.y-25),11,Color("9ab2bd"))
	var label = "v1.0.1 / OFFLINE"
	text_at(label,Vector2(size.x-142,size.y-27),10,Color("718a9b"))

func _menu_button(r: Rect2, label: String, primary = false):
	panel(r,Color(.13,.27,.30,.9) if primary else Color(.026,.06,.09,.77),Color(.55,.77,.75,.60) if primary else Color(.35,.51,.58,.35),9)
	text_center(label,r.position.y+r.size.y*.5+6,15,CYAN if primary else Color("9eb7c4"),false,r.get_center().x)
	if primary: _diamond(Vector2(r.position.x+25,r.get_center().y),4,GOLD)

func _overlay():
	draw_rect(Rect2(Vector2.ZERO,size),Color(.008,.018,.035,.88))
	glow(size*.5,400,Color(.18,.4,.48,.15))

func _pause():
	_overlay()
	text_center("ТИШИНА МЕЖДУ ШАГАМИ",196,12,Color("87b5c1"))
	text_center("Пауза",249,40,WHITE,true)
	var x = size.x*.5
	_menu_button(Rect2(x-155,286,310,54),"ВЕРНУТЬСЯ",true)
	_menu_button(Rect2(x-155,354,310,48),"КАРТА МИРА")
	_menu_button(Rect2(x-155,416,310,48),"НАСТРОЙКИ")
	_menu_button(Rect2(x-155,478,310,48),"В ГЛАВНОЕ МЕНЮ")
	text_center("Прогресс сохраняется у фонарей",577,12,Color("87a4b1"))

func _settings():
	_overlay(); var x = size.x*.5
	text_center("Настройки",216,36,WHITE,true)
	_menu_button(Rect2(x-210,285,420,60),"ЗВУК: "+("ВКЛЮЧЁН" if music_on else "ВЫКЛЮЧЕН"))
	_menu_button(Rect2(x-210,365,420,60),"ЭФФЕКТЫ: "+("ЭКОНОМНЫЕ" if low_fx else "ПОЛНЫЕ"))
	text_center("Экономные эффекты уменьшают частицы и дрожание камеры",456,12,Color("94aeba"))
	_menu_button(Rect2(x-155,480,310,54),"НАЗАД",true)
	text_center("Кнопки и камера адаптируются к соотношению сторон экрана",590,12,Color("718c9d"))

func _map():
	_overlay()
	text_center("Карта забытых глубин",176,32,WHITE,true)
	text_center("Пробуди три печати. Доберись до Колыбели и верни свет.",215,14,Color("9cb9c7"))
	var width = size.x-140; var left = 70.0
	var names = ["СОБОР","САД КОРНЕЙ","КОЛЫБЕЛЬ"]
	for i in range(3):
		var x = left+i*width/3
		panel(Rect2(x+6,285,width/3-12,114),Color(.06,.12,.17,.8),Color(ZONE_COLORS[i],.4),9)
		text_center(names[i],325,14,ZONE_COLORS[i],false,x+width/6)
		text_center("ПЕЧАТЬ НАЙДЕНА" if seals.has(i) else "НАЙТИ ПЕЧАТЬ",367,10,GOLD if seals.has(i) else Color("6d8a9a"),false,x+width/6)
		if i<2: draw_line(Vector2(x+width/3-4,342),Vector2(x+width/3+4,342),CYAN,3,true)
	var px = left+clampf(player.x/WORLD_END,0,1)*width
	_diamond(Vector2(px,435),8,CYAN)
	text_center("ТЫ ЗДЕСЬ",465,11,CYAN,false,clampf(px,110,size.x-110))
	for p in lamps:
		var lx = left+p.x/WORLD_END*width
		draw_circle(Vector2(lx,414),4,GOLD)
	text_center("Золотые огни — места сохранения",516,12,GOLD)
	text_center("Нажми в любом месте, чтобы вернуться",580,14,Color("a0becb"))

func _death():
	_overlay()
	text_center("ТВОЙ СВЕТ НЕ ПОГАС",240,12,CYAN)
	text_center("Ещё один рассвет",313,40,WHITE,true)
	text_center("Фонарь помнит дорогу назад.",360,15,Color("9fbdc9"))
	_menu_button(Rect2(size.x*.5-165,414,330,56),"ВОЗРОДИТЬСЯ",true)

func _win():
	_overlay(); glow(Vector2(size.x*.5,260),230,Color(GOLD,.3))
	text_center("ПОСЛЕДНИЙ ОГОНЬ ЗАЖЖЁН",225,13,GOLD)
	text_center("Глубины снова дышат",300,38,WHITE,true)
	text_center("Ты принёс свет туда, где его уже не ждали.",354,15,Color("bbced0"))
	text_center("3 / 3 печати     ·     %d осколков" % shards,414,16,CYAN)
	_menu_button(Rect2(size.x*.5-165,490,330,56),"В ГЛАВНОЕ МЕНЮ",true)

func _confirm_new():
	_overlay()
	text_center("Начать новый путь?",277,34,WHITE,true)
	text_center("Текущее сохранение будет заменено.",327,15,Color("9cb6c3"))
	_menu_button(Rect2(size.x*.5-165,380,330,56),"НАЧАТЬ ЗАНОВО",true)
	_menu_button(Rect2(size.x*.5-165,456,330,48),"НАЗАД")
