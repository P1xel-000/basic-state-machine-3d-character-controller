extends CharacterBody3D

#Movement Variables
const SPEED : float = 10.0
const SPRINT_SPEED : float = 20.0
#This controls the speed
var speed_change: float = 0.5
const JUMP_VELOCITY : float = 4.5
const GRAVITY : float = 9.8
var direction : Vector3

# Camera variables
@export var mouse_sensitivity : float = 0.0035
var camera_start_pos : Vector3
const BOB_FREQ : float = 2.0
const BOB_AMP : float = 0.04
var t_bob : float = 0.0

#Player Variables
@onready var head := $Head
@onready var camera := $Head/Camera3D

## FINITE STATE MACHINE STUFF
var main_sm: LimboHSM
func initiate_state_machine():
	# makes the state machine
	main_sm = LimboHSM.new()
	add_child(main_sm)
	
	# Set up states
	# if you want you can add .call_on_exit(function_name) at the end of any of these lines
	var idle_state = LimboState.new().named("idle").call_on_enter(idle_start).call_on_update(idle_update)
	var move_state = LimboState.new().named("move").call_on_enter(move_start).call_on_update(move_update)
	var jump_state = LimboState.new().named("jump").call_on_enter(jump_start).call_on_update(jump_update)
	var air_state = LimboState.new().named("air").call_on_enter(air_start).call_on_update(air_update)
	
	# Add states as children of main_sm
	# If you add any states make sure to add them here or else they wont work 
	main_sm.add_child(idle_state)
	main_sm.add_child(move_state)
	main_sm.add_child(jump_state)
	main_sm.add_child(air_state)
	
	# Sets the initial state to the idle state
	main_sm.initial_state = idle_state
	
	# This part kinda sucks but this is just how it works
	# you need to declare all the transitions between states...
	# Have fun anyone trying to add onto the player movement code!!!!!
	main_sm.add_transition(main_sm.ANYSTATE, idle_state, &"state_ended")
	main_sm.add_transition(main_sm.ANYSTATE, move_state, &"to_move")
	main_sm.add_transition(main_sm.ANYSTATE, jump_state, &"to_jump")
	main_sm.add_transition(main_sm.ANYSTATE, air_state, &"to_air")
	
	main_sm.initialize(self)
	main_sm.set_active(true)



func _ready():
	camera_start_pos = camera.position
	print(camera_start_pos)
	initiate_state_machine()
	# Captures the mouse, this should be changed once we have actual UI
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent):
	# Rotates the camera based on mouse movement
	if (event is InputEventMouseMotion):
		head.rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		# Prevents you from doing a sick flip
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta: float) -> void:
	# get movement directions
	var input_dir := Input.get_vector("left", "right", "forward", "back")
	direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	move_and_slide()

func _air_physics(delta: float):
	#Adds gravity
	velocity += Vector3(0,-GRAVITY,0) * delta
	if direction:
		if Input.is_action_pressed("sprint"):
			velocity.x = direction.x * SPRINT_SPEED * speed_change
			velocity.z = direction.z * SPRINT_SPEED * speed_change
		else:
			velocity.x = direction.x * SPEED * speed_change
			velocity.z = direction.z * SPEED * speed_change
	else:
		velocity.x = 0.0
		velocity.z = 0.0

func _ground_physics(delta: float):
	if direction:
		if Input.is_action_pressed("sprint"):
			velocity.x = direction.x * SPRINT_SPEED * speed_change
			velocity.z = direction.z * SPRINT_SPEED * speed_change
		else:
			velocity.x = direction.x * SPEED * speed_change
			velocity.z = direction.z * SPEED * speed_change
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	

func idle_start():
	# Put any code here you only want to execute one, upon entering the state
	pass
	
func idle_update(delta: float):
	# Put any code you want to execute every update (basically just _process()) while in the state
	if not is_on_floor():
		main_sm.dispatch(&"to_air")
	if Input.is_action_just_pressed("jump"):
		main_sm.dispatch(&"to_jump")
	if direction:
		main_sm.dispatch(&"to_move")
	_ground_physics(delta)

# It's possible to make an exit function that will execute whenever you leave the state

func move_start():
	pass
	
func move_update(delta: float):
	if not is_on_floor():
		main_sm.dispatch(&"to_air")
	if velocity.x == 0 and velocity.y == 0:
		main_sm.dispatch(&"state_ended")
	if Input.is_action_just_pressed("jump"):
		main_sm.dispatch(&"to_jump")
	
	# woah cool headbob isn't that so bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	_ground_physics(delta)

func jump_start():
	velocity.y = JUMP_VELOCITY
	
func jump_update(delta: float):
	main_sm.dispatch(&"to_air")

func air_start():
	pass
	
func air_update(delta: float):
	if is_on_floor():
		main_sm.dispatch(&"state_ended")
	else:
		_air_physics(delta)



func _headbob(time) -> Vector3:
	var pos : Vector3 = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos


## This is a super simple character controller, 
## you'll need to tinker with it and add more features to make it actually good
## but this might be a useful base to start from :)
