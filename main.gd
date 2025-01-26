extends Node

const FLIGHT_SPEED = 10.0
const FLIGHT_ACCEL = 10000.0
const FLIGHT_VERTICAL_SPEED = FLIGHT_SPEED - 4.0
const BOOST_MULTI = 2.0
const DELTA_DAMP = 20.0

var flight_velocity = Vector3()
var flying = false
var vertical_velocity = 0.0
var flight_direction = Vector3()
var final_velocity = Vector3()

var player
var in_game = false

var PlayerAPI
var KeybindsAPI

func _ready():
	KeybindsAPI = get_node_or_null("/root/BlueberryWolfiAPIs/KeybindsAPI")
	PlayerAPI = get_node_or_null("/root/BlueberryWolfiAPIs/PlayerAPI")
	PlayerAPI.connect("_ingame", self, "_fly_ready")

func _fly_ready():
	in_game = true
	
	var toggle_fly_signal = KeybindsAPI.register_keybind({
		"action_name": "toggle_fly",
		"key": KEY_F3,
		"control": true,
		"title": "Toggle Fly"
	})
	
	KeybindsAPI.connect(toggle_fly_signal, self, "_toggle_flight")
	
	player = PlayerAPI.local_player
	print("flyfishing player init ", player.name)

func _physics_process(delta):
	if not in_game:
		return
	_get_input()
	_process_movement(delta)

func _get_speed_multiplier():
	var sprinting = not Input.is_action_pressed("move_sneak") and Input.is_action_pressed("move_sprint")
	var sneaking = Input.is_action_pressed("move_sneak") and not Input.is_action_pressed("move_sprint")
	
	if sprinting:
		return player.boost_mult * BOOST_MULTI
	elif sneaking:
		return 0.5
	return 1.0

func _get_input():
	if not flying:
		return

	flight_direction = Vector3.ZERO
	var camera_basis = player.camera.transform.basis

	if Input.is_action_pressed("move_forward"):
		flight_direction -= camera_basis.z
	if Input.is_action_pressed("move_back"):
		flight_direction += camera_basis.z
	if Input.is_action_pressed("move_left"):
		flight_direction -= camera_basis.x
	if Input.is_action_pressed("move_right"):
		flight_direction += camera_basis.x

	var speed_multiplier = _get_speed_multiplier()

	if Input.is_action_pressed("move_up"):
		vertical_velocity = FLIGHT_VERTICAL_SPEED * speed_multiplier
	elif Input.is_action_pressed("move_down"):
		vertical_velocity = -FLIGHT_VERTICAL_SPEED * speed_multiplier
	else:
		vertical_velocity = lerp(vertical_velocity, 0, 0.1)

func _toggle_flight():
	flying = not flying
	player.gravity_disable = flying
	
	if flying:
		print("flying start")
		player.animation_data["moving"] = 2
		player.freecamming = true
		PlayerData._send_notification("Now flying", 0)
	else:
		print("flying stop")
		player.animation_data["moving"] = 0
		player.freecamming = false
		PlayerData._send_notification("No longer flying", 1)
		player.rotation = player.cam_base.rotation

func _process_movement(delta):
	if flying:
		_process_flight_movement(delta)

func _process_flight_movement(delta):
	var target_speed = FLIGHT_SPEED * _get_speed_multiplier()
	player.diving = false

	flight_velocity = flight_velocity.move_toward(
		flight_direction.normalized() * target_speed,
		delta * FLIGHT_ACCEL
	)

	final_velocity = lerp(final_velocity, flight_velocity + Vector3(0, vertical_velocity, 0), delta * DELTA_DAMP)
	player.rotation = lerp(player.rotation, player.camera.rotation, delta * DELTA_DAMP)
	player.move_and_slide(final_velocity)
