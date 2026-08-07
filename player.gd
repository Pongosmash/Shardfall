extends CharacterBody3D

const SPEED = 6.0
const JUMP_VELOCITY = 8.0
const GRAVITY = 20.0

@export var camera_pivot: Node3D
@export var spawn_check_distance: float = 200.0
var _terrain_ready: bool = false


func _ready() -> void:
	if camera_pivot == null:
		push_error("Player: Feld 'camera_pivot' ist nicht zugewiesen!")
		set_physics_process(false)
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Escape-Taste: Maus wieder freigeben, z.B. für Menüs
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not _terrain_ready:
		if _has_ground_below():
			_terrain_ready = true
		else:
			velocity = Vector3.ZERO
			return
			
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0.0, input_dir.y).rotated(Vector3.UP, camera_pivot.global_rotation.y)

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)

	move_and_slide()

func _has_ground_below() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position
	var to := global_position - Vector3(0.0, spawn_check_distance, 0.0)

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]          # sich selbst nicht treffen
	query.collision_mask = collision_mask # dieselben Layer wie der Player

	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false

	# Direkt auf die Oberfläche setzen, statt von oben heranzufallen
	global_position.y = hit.position.y + 1.0
	return true
