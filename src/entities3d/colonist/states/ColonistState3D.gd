class_name ColonistState3D
extends State

## ColonistState3D: Базовий клас для всіх станів FSM 3D колоніста.
## Інкапсулює спільну фізику гравітації, плавні горизонтальні повороти
## та логіку завершення завдань із переходом до розвантаження на склад.

const GRAVITY: float = 19.6


## Застосовує гравітаційне прискорення до актора та опціонально викликає move_and_slide
func apply_gravity(delta: float, apply_slide: bool = false) -> void:
	if actor == null:
		return
	if not actor.is_on_floor():
		actor.velocity.y -= GRAVITY * delta
	if apply_slide:
		actor.move_and_slide()


## Плавно повертає актора обличчям (+Z) до цільової 3D точки у горизонтальній площині X-Z
func face_target(target_pos: Vector3, delta: float, turn_speed: float = 10.0) -> void:
	if actor == null:
		return
	var look_dir := target_pos - actor.global_position
	look_dir.y = 0.0
	if look_dir.length_squared() > 0.001:
		var target_angle := atan2(look_dir.x, look_dir.z)
		actor.rotation.y = lerp_angle(actor.rotation.y, target_angle, turn_speed * delta)


## Завершення дії: перевіряє наявність вантажу в інвентарі робітника для розвантаження
## на склад, або переводить FSM у стан спокою (&"idle")
func try_unload_or_idle() -> void:
	if actor != null and actor.has_method("has_items_to_unload") and actor.has_items_to_unload():
		actor.start_unloading_to_stockpile()
	elif state_machine != null:
		state_machine.transition_to(&"idle")
