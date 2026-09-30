extends Node3D

var player: CharacterBody3D
var ball: RigidBody3D
var camera: Camera3D
var stamina := 1.0
var has_ball := false
var shot_charge := 0.0
var charging := false
var start_player := Vector3(-8,0.9,0)
var start_ball := Vector3(0,0.35,0)

func _ready():
	_build_world()
	_build_hud()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func box(parent: Node, name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var m=MeshInstance3D.new(); m.name=name
	var b=BoxMesh.new(); b.size=size; m.mesh=b; m.position=pos
	var mat=StandardMaterial3D.new(); mat.albedo_color=color; m.material_override=mat
	parent.add_child(m); return m

func _build_world():
	var env=WorldEnvironment.new(); var e=Environment.new()
	e.background_mode=Environment.BG_COLOR; e.background_color=Color(0.35,0.62,0.86)
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color=Color.WHITE; e.ambient_light_energy=0.65
	env.environment=e; add_child(env)
	var sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-55,-25,0); sun.shadow_enabled=true; add_child(sun)
	box(self,"Pitch",Vector3(0,-0.12,0),Vector3(105,0.2,68),Color(0.08,0.42,0.12))
	# field markings
	for z in [-34.0,34.0]: box(self,"Line",Vector3(0,0.015,z),Vector3(105,0.025,0.10),Color.WHITE)
	for x in [-52.5,0.0,52.5]: box(self,"Line",Vector3(x,0.015,0),Vector3(0.10,0.025,68),Color.WHITE)
	for x in [-52.5,52.5]:
		box(self,"Post",Vector3(x,1.22,-3.66),Vector3(0.12,2.44,0.12),Color.WHITE)
		box(self,"Post",Vector3(x,1.22,3.66),Vector3(0.12,2.44,0.12),Color.WHITE)
		box(self,"Bar",Vector3(x,2.44,0),Vector3(0.12,0.12,7.32),Color.WHITE)
	player=CharacterBody3D.new(); player.name="Player"; player.position=start_player; add_child(player)
	var cap=CollisionShape3D.new(); var shape=CapsuleShape3D.new(); shape.radius=.38; shape.height=1.8; cap.shape=shape; player.add_child(cap)
	var body=Node3D.new(); player.add_child(body)
	box(body,"Torso",Vector3(0,.25,0),Vector3(.55,.75,.32),Color(0.08,0.12,0.18))
	box(body,"Head",Vector3(0,.88,0),Vector3(.32,.32,.32),Color(0.76,0.57,0.43))
	box(body,"LegL",Vector3(-.16,-.48,0),Vector3(.18,.75,.20),Color(0.08,0.12,0.18))
	box(body,"LegR",Vector3(.16,-.48,0),Vector3(.18,.75,.20),Color(0.08,0.12,0.18))
	camera=Camera3D.new(); camera.position=Vector3(0,5.2,8.5); camera.rotation_degrees=Vector3(-18,180,0); player.add_child(camera)
	ball=RigidBody3D.new(); ball.name="Ball"; ball.position=start_ball; ball.mass=.43; ball.linear_damp=.18; ball.angular_damp=.22; add_child(ball)
	var bc=CollisionShape3D.new(); var ss=SphereShape3D.new(); ss.radius=.22; bc.shape=ss; ball.add_child(bc)
	var bm=MeshInstance3D.new(); var sphere=SphereMesh.new(); sphere.radius=.22; sphere.height=.44; bm.mesh=sphere; ball.add_child(bm)
	var floor=StaticBody3D.new(); add_child(floor); var fc=CollisionShape3D.new(); var fs=BoxShape3D.new(); fs.size=Vector3(105,.2,68); fc.shape=fs; fc.position=Vector3(0,-.12,0); floor.add_child(fc)

func _build_hud():
	var layer=CanvasLayer.new(); add_child(layer)
	var label=Label.new(); label.name="HUD"; label.position=Vector2(24,20); label.add_theme_font_size_override("font_size",22); layer.add_child(label)

func _physics_process(delta):
	var input=Input.get_vector("move_left","move_right","move_forward","move_back")
	var dir=Vector3(input.x,0,input.y)
	var sprint=Input.is_action_pressed("sprint") and stamina>0.02
	var speed=7.3 if sprint else 4.6
	if sprint and dir.length()>0.1: stamina=max(0.0,stamina-delta/11.0)
	else: stamina=min(1.0,stamina+delta/7.0)
	player.velocity.x=dir.x*speed; player.velocity.z=dir.z*speed
	if not player.is_on_floor(): player.velocity.y-=9.8*delta
	else: player.velocity.y=0
	player.move_and_slide()
	if dir.length()>0.1:
		player.rotation.y=lerp_angle(player.rotation.y,atan2(-dir.x,-dir.z),delta*9.0)
	_update_ball(delta,dir,sprint)
	if Input.is_action_just_pressed("shoot"): charging=true; shot_charge=0
	if charging: shot_charge=min(1.0,shot_charge+delta/1.25)
	if Input.is_action_just_released("shoot"): _shoot()
	if Input.is_action_just_pressed("pass_ball"): _pass()
	if Input.is_action_just_pressed("reset"): _reset()
	var hud=get_node("CanvasLayer/HUD")
	hud.text="PITCHBORN  |  PROTOTIPO GODOT\nWASD Muovi   Shift Sprint   J Passaggio   K Tiro   R Reset\nStamina: %d%%   Possesso: %s   Potenza tiro: %d%%" % [int(stamina*100),"SI" if has_ball else "NO",int(shot_charge*100)]

func _update_ball(delta,dir,sprint):
	var d=player.global_position.distance_to(ball.global_position)
	if not has_ball and d<1.25 and ball.linear_velocity.length()<12: has_ball=true
	if has_ball:
		var forward=-player.global_transform.basis.z.normalized()
		var target=player.global_position+forward*(1.15 if sprint else .75); target.y=.35
		var err=target-ball.global_position
		ball.linear_velocity=ball.linear_velocity.lerp(player.velocity+err*7.0,min(1.0,delta*8.0))
		if d>2.2: has_ball=false

func _kick(power: float, lift: float):
	var forward=-player.global_transform.basis.z.normalized()
	has_ball=false; ball.linear_velocity=forward*power+Vector3.UP*lift

func _pass(): 
	if has_ball or player.global_position.distance_to(ball.global_position)<1.7: _kick(12.0,0.5)

func _shoot():
	if not charging: return
	charging=false
	if has_ball or player.global_position.distance_to(ball.global_position)<1.7: _kick(15.0+shot_charge*13.0,1.0+shot_charge*4.0)
	shot_charge=0

func _reset():
	player.position=start_player; player.velocity=Vector3.ZERO
	ball.position=start_ball; ball.linear_velocity=Vector3.ZERO; ball.angular_velocity=Vector3.ZERO; has_ball=false

func _unhandled_input(event):
	if event is InputEventKey and event.keycode==KEY_ESCAPE and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
