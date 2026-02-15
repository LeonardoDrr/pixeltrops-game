extends "res://scripts/enemy_base.gd"
class_name EnemyFlying

enum FlyState { HOVER, SWOOP }
var fly_state: FlyState = FlyState.HOVER
var flight_timer: float = 0.0
var swoop_cd: float = 2.0
var random_offset: float = 0.0

func _ready() -> void:
    super._ready()
    add_to_group("flyers")
    random_offset = randf() * 100.0

func _process_enemy_movement(delta: float) -> void:
    # --- No player, idle ---
    if player == null or not is_instance_valid(player) or player.get("is_dead") == true:
        velocity = velocity.move_toward(Vector2.ZERO, speed * delta)
        move_and_slide()
        return

    flight_timer += delta
    swoop_cd -= delta
    
    # --- Distance Check ---
    var vector_to_player = player.global_position - global_position
    var distance_to_player = vector_to_player.length()
    
    # --- State Machine ---
    var target_pos = player.global_position
    
    if fly_state == FlyState.HOVER:
        # Hover Pattern:
        # Fly 80-150px ABOVE flight, swinging Left/Right using Sine wave
        var hover_height = -120.0
        # Erratic X movement:
        var hover_x = sin(flight_timer * 2.0 + random_offset) * 150.0 
        
        target_pos = player.global_position + Vector2(hover_x, hover_height)
        
        # Check Swoop
        if swoop_cd <= 0 and distance_to_player < 400:
            fly_state = FlyState.SWOOP
            # Reset timer allows 1-3 seconds of swooping
            swoop_cd = randf_range(1.5, 3.0) 
            
    elif fly_state == FlyState.SWOOP:
        # Dive directly at player
        target_pos = player.global_position
        
        # End swoop after time or if we hit/passed player
        if swoop_cd <= 0:
            fly_state = FlyState.HOVER
            swoop_cd = randf_range(2.0, 4.0)

    # --- Move towards Target ---
    var steering_force = (target_pos - global_position).normalized() * speed
    
    # "Swoop" is faster than "Hover"
    var current_speed_mult = 1.0 if fly_state == FlyState.HOVER else 1.8
    
    # Apply velocity with some inertia (Lerp)
    velocity = velocity.lerp(steering_force * current_speed_mult, 2.0 * delta)
    
    # --- Avoid Floor (Anti-Stick) ---
    if is_on_floor():
        velocity.y = -150.0 # Jump up immediately
    
    # --- Soft Wall Avoidance ---
    if is_on_wall():
        # Bounce off wall slightly
        var normal = get_wall_normal()
        velocity += normal * 100.0

    move_and_slide()
    
    # --- Animations & Facing ---
    anim.flip_h = (player.global_position.x - global_position.x) < 0
    
    if distance_to_player <= ATTACK_RANGE:
        # We handle damage, but animation triggers
        is_attacking = true
        anim.play(anim_attack)
        if not has_dealt_damage:
            _try_deal_damage()
    else:
        is_attacking = false
        _play_if_not(anim_walk) # Fly

