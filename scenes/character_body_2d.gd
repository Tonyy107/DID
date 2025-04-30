extends CharacterBody2D

# Movement constants
const SPEED = 200.0
const CROUCH_SPEED = 100.0
const ACCELERATION = 1200.0
const FRICTION = 800.0

# Jumping constants
const JUMP_FORCE = -400.0
const DOUBLE_JUMP_FORCE = -350.0
const GRAVITY = 1000.0
const MAX_FALL_SPEED = 900.0
const COYOTE_TIME = 0.15
const JUMP_BUFFER_TIME = 0.1
const WALL_SLIDE_SPEED = 100.0

# Dashing constants
const DASH_SPEED = 600.0
const DASH_DURATION = 0.15
const DASH_COOLDOWN = 0.5

# Wall jumping constants
const WALL_JUMP_FORCE = Vector2(300, -400)

# States
var can_double_jump := true
var has_double_jumped := false
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var is_crouching := false
var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0

# Input variables
var input_direction := 0.0
var last_facing_direction := 1.0

# Load separate shape resources
@onready var stand_shape = preload("res://shapes/stand_shape.tres")
@onready var crouch_shape = preload("res://shapes/crouch_shape.tres")

# Nodes
@onready var wall_check_left = $wall_check_left
@onready var wall_check_right = $wall_check_right
@onready var collider = $CollisionShape2D
@onready var ceiling_check = $ceiling_check

func _physics_process(delta):
	handle_input()
	handle_dash(delta)
	apply_gravity(delta)
	move_character(delta)
	jump_logic(delta)
	move_and_slide()

func handle_input():
	input_direction = Input.get_axis("ui_left", "ui_right")
	if input_direction != 0:
		last_facing_direction = input_direction

	# Crouch logic
	if Input.is_action_pressed("ui_down"):
		is_crouching = true
	elif not ceiling_check.is_colliding():
		is_crouching = false

	collider.shape = crouch_shape if is_crouching else stand_shape

	# Jump buffer
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	# Dash input
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and not is_dashing:
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN

func apply_gravity(delta):
	if not is_on_floor():
		var wall_normal = get_wall_normal()
		if is_on_wall_only() and velocity.y > 0.0 and wall_normal != Vector2.ZERO:
			velocity.y = min(velocity.y + GRAVITY * delta, WALL_SLIDE_SPEED)
		elif not is_dashing:
			velocity.y += GRAVITY * delta
			velocity.y = min(velocity.y, MAX_FALL_SPEED)
	else:
		velocity.y = 0.0
		has_double_jumped = false
		can_double_jump = true
		coyote_timer = COYOTE_TIME

	# Update timers
	coyote_timer = max(coyote_timer - delta, 0.0)
	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

func move_character(delta):
	if is_dashing:
		velocity.y = 0.0
		var dash_dir = input_direction if input_direction != 0 else last_facing_direction
		velocity.x = DASH_SPEED * dash_dir
		return

	var current_speed = CROUCH_SPEED if is_crouching else SPEED
	var target_speed = input_direction * current_speed

	if abs(target_speed) > 0.1:
		velocity.x = move_toward(velocity.x, target_speed, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

func handle_dash(delta):
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			velocity.x = 0.0
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)

func jump_logic(_delta):
	if jump_buffer_timer > 0.0:
		if is_on_floor() or coyote_timer > 0.0:
			velocity.y = JUMP_FORCE
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
		elif is_on_wall():
			var wall_normal = get_wall_normal()
			if wall_normal != Vector2.ZERO:
				velocity = Vector2(WALL_JUMP_FORCE.x * -wall_normal.x, WALL_JUMP_FORCE.y)
				jump_buffer_timer = 0.0
		elif can_double_jump:
			velocity.y = DOUBLE_JUMP_FORCE
			can_double_jump = false
			jump_buffer_timer = 0.0

	# Jump cut
	if Input.is_action_just_released("ui_select") and velocity.y < 0.0:
		velocity.y *= 0.5
