extends CharacterBody2D

# Movement
const SPEED = 200
const CROUCH_SPEED = 100
const ACCELERATION = 1200.0
const FRICTION = 800.0

# Jumping
const JUMP_FORCE = -400.0
const DOUBLE_JUMP_FORCE = -350.0
const GRAVITY = 1000.0
const MAX_FALL_SPEED = 900.0
const COYOTE_TIME = 0.15
const JUMP_BUFFER_TIME = 0.1

# Dashing
const DASH_SPEED = 600.0
const DASH_DURATION = 0.15
const DASH_COOLDOWN = 0.5

# Wall jumping
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

# Input
var input_direction := 0

# Nodes
@onready var animated_sprite = $animated_sprite
@onready var wall_check_left = $wall_check_left
@onready var wall_check_right = $wall_check_right

func _physics_process(delta):
	handle_input()
	handle_dash(delta)
	apply_gravity(delta)
	move_character(delta)
	jump_logic()
	handle_animation()

func handle_input():
	input_direction = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	is_crouching = Input.is_action_pressed("ui_down")

	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing:
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN

func apply_gravity(delta):
	if not is_on_floor():
		if not is_dashing:
			velocity.y += GRAVITY * delta
			velocity.y = min(velocity.y, MAX_FALL_SPEED)
	else:
		velocity.y = 0
		has_double_jumped = false
		coyote_timer = COYOTE_TIME
	
	if coyote_timer > 0:
		coyote_timer -= delta
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta

func move_character(delta):
	if is_dashing:
		velocity.y = 0
		velocity.x = DASH_SPEED * sign(input_direction if input_direction != 0 else 1)
		move_and_slide()
		return

	var current_speed = is_crouching ? CROUCH_SPEED : SPEED
	var target_speed = input_direction * current_speed

	if abs(target_speed) > 0.1:
		velocity.x = move_toward(velocity.x, target_speed, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	move_and_slide()

func handle_dash(delta):
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

func jump_logic():
	if jump_buffer_timer > 0:
		# Normal jump
		if is_on_floor() or coyote_timer > 0:
			velocity.y = JUMP_FORCE
			jump_buffer_timer = 0
			coyote_timer = 0
		# Wall jump
		elif is_on_wall():
			var wall_dir = 0
			if wall_check_left.is_colliding():
				wall_dir = 1
			elif wall_check_right.is_colliding():
				wall_dir = -1
			if wall_dir != 0:
				velocity = WALL_JUMP_FORCE * Vector2(wall_dir, 1)
				jump_buffer_timer = 0
		# Double jump
		elif not has_double_jumped and can_double_jump:
			velocity.y = DOUBLE_JUMP_FORCE
			has_double_jumped = true
			jump_buffer_timer = 0

	if Input.is_action_just_released("ui_accept") and velocity.y < 0:
		velocity.y *= 0.5

func handle_animation():
	if is_dashing:
		animated_sprite.play("dash")
	elif not is_on_floor():
		if velocity.y < 0:
			animated_sprite.play("jump")
		else:
			animated_sprite.play("fall")
	elif is_crouching:
		animated_sprite.play("crouch")
	elif abs(velocity.x) > 10:
		animated_sprite.play("run")
	else:
		animated_sprite.play("idle")

	if velocity.x != 0:
		animated_sprite.flip_h = velocity.x < 0
