extends Node3D

var player: CharacterBody3D
var ball: RigidBody3D
var camera: Camera3D
var stamina := 1.0
var has_ball := false
var shot_charge := 0.0
var charging := false
var start_player := Vector3(-8, 1.05, 0)
var start_ball := Vector3(-5.5, 0.24, 0)

func _ready():
	_build_world()
	_build_hud()

func mat(color: Color) -> StandardMaterial3D:
	var m=StandardMaterial3D.new(); m.albedo_color=color; m.roughness=.85; return m

func box(parent: Node, name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var m=MeshInstance3D.new(); m.name=name
	var b=BoxMesh.new(); b.size=size; m.mesh=b; m.position=pos; m.material_override=mat(color)
	parent.add_child(m); return m

func _build_world():
	var env=WorldEnvironment.new(); var e=Environment.new()
	e.background_mode=Environment.BG_SKY
	var sky=Sky.new(); var sky_mat=ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color(0.08,0.22,0.48); sky_mat.sky_horizon_color=Color(0.62,0.80,0.96)
	sky_mat.ground_bottom_color=Color(0.03,0.05,0.04); sky_mat.ground_horizon_color=Color(0.38,0.48,0.40)
	sky.sky_material=sky_mat; e.sky=sky
	e.ambient_light_source=Environment.AMBIENT_SOURCE_SKY; e.ambient_light_energy=.7
	env.environment=e; add_child(env)
	var sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-58,-32,0); sun.shadow_enabled=true; sun.light_energy=1.3; add_child(sun)

	# Stadium floor + striped football pitch
	box(self,"Runoff",Vector3(0,-.16,0),Vector3(119,.20,82),Color(0.055,0.22,0.075))
	for i in range(10):
		var x=-47.25+i*10.5
		var c=Color(0.075,0.40,0.11) if i%2==0 else Color(0.065,0.34,0.095)
		box(self,"GrassStripe",Vector3(x,-.045,0),Vector3(10.5,.03,68),c)

	# Correct rectangular markings
	for z in [-34.0,34.0]: box(self,"Touchline",Vector3(0,.01,z),Vector3(105,.025,.10),Color.WHITE)
	for x in [-52.5,52.5]: box(self,"GoalLine",Vector3(x,.01,0),Vector3(.10,.025,68),Color.WHITE)
	box(self,"Halfway",Vector3(0,.012,0),Vector3(.10,.025,68),Color.WHITE)
	for x in [-52.5,52.5]:
		var s=1.0 if x<0 else -1.0
		var px=x+s*16.5
		box(self,"PenaltyFront",Vector3(px,.012,0),Vector3(.10,.025,40.32),Color.WHITE)
		box(self,"PenaltyTop",Vector3(x+s*8.25,.012,-20.16),Vector3(16.5,.025,.10),Color.WHITE)
		box(self,"PenaltyBottom",Vector3(x+s*8.25,.012,20.16),Vector3(16.5,.025,.10),Color.WHITE)
		# goals extend outside pitch
		var gx=x-s*1.25
		for z in [-3.66,3.66]: box(self,"GoalPost",Vector3(x,1.22,z),Vector3(.12,2.44,.12),Color.WHITE)
		box(self,"Crossbar",Vector3(x,2.44,0),Vector3(.12,.12,7.32),Color.WHITE)
		box(self,"GoalBack",Vector3(gx,1.22,0),Vector3(.08,2.44,7.32),Color(0.75,0.78,0.80))
	# center circle using small segments
	for i in range(48):
		var a=TAU*i/48.0
		var p=Vector3(cos(a)*9.15,.018,sin(a)*9.15)
		var seg=box(self,"CenterCircle",p,Vector3(1.22,.025,.09),Color.WHITE); seg.rotation.y=-a
	box(self,"CenterSpot",Vector3(0,.02,0),Vector3(.22,.03,.22),Color.WHITE)

	# Simple stands to give depth
	for z in [-43.0,43.0]: box(self,"Stand",Vector3(0,2.0,z),Vector3(116,4,7),Color(0.10,0.12,0.15))
	for x in [-59.0,59.0]: box(self,"Stand",Vector3(x,2.0,0),Vector3(7,4,78),Color(0.10,0.12,0.15))

	player=CharacterBody3D.new(); player.name="Player"; player.position=start_player; add_child(player)
	var cap=CollisionShape3D.new(); var shape=CapsuleShape3D.new(); shape.radius=.36; shape.height=1.8; cap.shape=shape; player.add_child(cap)
	var body=Node3D.new(); body.name="Visual"; player.add_child(body)
	box(body,"Torso",Vector3(0,.18,0),Vector3(.52,.72,.30),Color(0.06,0.12,0.75))
	box(body,"Head",Vector3(0,.78,0),Vector3(.30,.30,.30),Color(0.70,0.50,0.36))
	box(body,"LegL",Vector3(-.15,-.48,0),Vector3(.17,.72,.19),Color(0.92,0.92,0.94))
	box(body,"LegR",Vector3(.15,-.48,0),Vector3(.17,.72,.19),Color(0.92,0.92,0.94))

	var pivot=Node3D.new(); pivot.name="CameraPivot"; pivot.position=Vector3(0,1.2,0); player.add_child(pivot)
	camera=Camera3D.new(); camera.position=Vector3(0,2.65,5.8); camera.fov=66; camera.current=true; pivot.add_child(camera)\n\tcamera.look_at_from_position(camera.position, Vector3(0,0.25,-2.2), Vector3.UP)

	ball=RigidBody3D.new(); ball.name="Ball"; ball.position=start_ball; ball.mass=.43; ball.linear_damp=.22; ball.angular_damp=.18; add_child(ball)
	var bc=CollisionShape3D.new(); var ss=SphereShape3D.new(); ss.radius=.22; bc.shape=ss; ball.add_child(bc)
	var bm=MeshInstance3D.new(); var sphere=SphereMesh.new(); sphere.radius=.22; sphere.height=.44; bm.mesh=sphere; bm.material_override=mat(Color(0.94,0.94,0.92)); ball.add_child(bm)

	var floor=StaticBody3D.new(); add_child(floor)
	var fc=CollisionShape3D.new(); var fs=BoxShape3D.new(); fs.size=Vector3(119,.20,82); fc.shape=fs; fc.position=Vector3(0,-.16,0); floor.add_child(fc)

func _build_hud():
	var layer=CanvasLayer.new(); layer.name="HUDLayer"; add_child(layer)
	var panel=ColorRect.new(); panel.position=Vector2(18,16); panel.size=Vector2(455,104); panel.color=Color(0.015,0.02,0.03,.76); layer.add_child(panel)
	var label=Label.new(); label.name="HUD"; label.position=Vector2(34,28); label.add_theme_font_size_override("font_size",18); layer.add_child(label)

func _physics_process(delta):
	var input=Input.get_vector("move_left","move_right","move_forward","move_back")
	var dir=Vector3(input.x,0,input.y).normalized()
	var sprint=Input.is_action_pressed("sprint") and stamina>.02
	var speed=7.3 if sprint else 4.6
	if sprint and dir.length()>.1: stamina=max(0.0,stamina-delta/11.0)
	else: stamina=min(1.0,stamina+delta/7.0)
	player.velocity.x=dir.x*speed; player.velocity.z=dir.z*speed
	if not player.is_on_floor(): player.velocity.y-=9.8*delta
	else: player.velocity.y=0
	player.move_and_slide()
	if dir.length()>.1: player.rotation.y=lerp_angle(player.rotation.y,atan2(-dir.x,-dir.z),delta*9.0)
	_update_ball(delta,sprint)
	if Input.is_action_just_pressed("shoot"): charging=true; shot_charge=0
	if charging: shot_charge=min(1.0,shot_charge+delta/1.25)
	if Input.is_action_just_released("shoot"): _shoot()
	if Input.is_action_just_pressed("pass_ball"): _pass()
	if Input.is_action_just_pressed("reset"): _reset()
	var hud=get_node("HUDLayer/HUD")
	hud.text="PITCHBORN  •  TRAINING GROUND\nWASD  Muovi   SHIFT  Sprint   J  Passa   K  Tira   R  Reset\nStamina %d%%     Possesso %s     Tiro %d%%" % [int(stamina*100),"SI" if has_ball else "NO",int(shot_charge*100)]

func _update_ball(delta,sprint):
	var d=player.global_position.distance_to(ball.global_position)
	if not has_ball and d<1.25 and ball.linear_velocity.length()<12: has_ball=true
	if has_ball:
		var forward=-player.global_transform.basis.z.normalized()
		var target=player.global_position+forward*(1.12 if sprint else .72); target.y=.24
		var err=target-ball.global_position
		ball.linear_velocity=ball.linear_velocity.lerp(player.velocity+err*7.0,min(1.0,delta*8.0))
		if d>2.2: has_ball=false

func _kick(power: float,lift: float):
	var forward=-player.global_transform.basis.z.normalized(); has_ball=false
	ball.linear_velocity=forward*power+Vector3.UP*lift

func _pass():
	if has_ball or player.global_position.distance_to(ball.global_position)<1.7: _kick(12.0,.5)

func _shoot():
	if not charging: return
	charging=false
	if has_ball or player.global_position.distance_to(ball.global_position)<1.7: _kick(15.0+shot_charge*13.0,1.0+shot_charge*4.0)
	shot_charge=0

func _reset():
	player.position=start_player; player.velocity=Vector3.ZERO
	ball.position=start_ball; ball.linear_velocity=Vector3.ZERO; ball.angular_velocity=Vector3.ZERO; has_ball=false
