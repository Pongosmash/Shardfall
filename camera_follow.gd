extends Camera3D

@export var target: Node3D          # -> SpringPosition
@export var lerp_power: float = 12.0


func _ready() -> void:
	if target == null:
		push_error("Camera3D: Feld 'target' ist nicht zugewiesen!")
		set_process(false)
		return

	top_level = true
	global_transform = target.global_transform


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-lerp_power * delta)
	global_position = global_position.lerp(target.global_position, weight)
	global_basis = target.global_basis
