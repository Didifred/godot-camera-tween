extends Camera
class_name CameraTween

signal camera_tween_completed

# use a curve trajectory for camera tween animation 
export var bezier_curve_enable := true

# excentricity of bezier curves (control point strength)
export var bezier_control_point_strength := 0.6 #default give round circle approximation

# interval distance of pre-calculated points for the Curve3D
export var bake_interval := 0.5

# if true follow the target camera in real time, interrupting an eventual bezier curve
export var follow_target := false 

 # minimum distance between the camera and the focused object to avoid
export var camera_minimum_distance := 5.0

# used as up vector diretion to avoid the object
export var object_up_vector := Vector3(0,1,0) 

# rotation speed pow, value > 1.0 / < 1.0 make slow / fast progress to target orientation at the beginning of animation
export var tween_rotation_speed_pow := 1.0

# progress speed in follow phase, between 0 and 1. If 1, reach immediately the target rotation / camera params
export var follow_progress_speed := 0.5 



var _tween : Tween

var _target_camera_position : Spatial
var _target_object_focus: Spatial
var _initial_global_transform : Transform
var _path : Curve3D
var _speed := 0.0
var intermediate_points : PoolVector3Array # PoolArray of of Vector3
var _duration := 0.0 setget set_duration, get_duration
var _tween_in_progress := false setget ,is_tween_in_progress


var _previous_time := 0.0


## Interpolate the camera between current position and a target one during 
#  the duration looking at target_object_focus spatial node.
#  @target_camera_position The target position node (can be a Camera node)
#  @target_object_focus The node to look at 
#  @duration The duration in seconds of the animation
#  @trans_type The transition type of the tween (see Tween enum TransitionType)
#  @ease_type The ease type of the tween (see Tween enum EaseType)
#  @delay Delay in seconds to start the animation
#  @follow Camera follow in realtime the target camera (usefull when it can move during animation)
#  @intermediate_points Intermediate points between current position and target_camera_position
func interpolate_looking_at(target_camera_position : Spatial, target_object_focus : Spatial,  
							duration : float, trans_type := 0, ease_type := 2, delay := 0.0, follow := false,
							intermediate_points : PoolVector3Array = PoolVector3Array()) :
	assert(target_camera_position != null)
	assert(target_object_focus != null)

	if _tween_in_progress == false:
		# register the target camera position and the target object focus
		_target_camera_position = target_camera_position
		_target_object_focus = target_object_focus
		# register the duration
		_duration = duration
		# follow or not in realtime the target camera
		follow_target = follow

		_initial_global_transform = global_transform # copy of current global_transform

		_tween.interpolate_method(self, "_move_camera", 0.0, 1.0,
								  duration, trans_type, ease_type, delay)
		# set by default physics, allowing regular animation
		_tween.set_tween_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		if ((bezier_curve_enable ==true) and (follow == false)) :
			_build_new_path(intermediate_points)
			
## Interpolate the camera between current position and a target one during the duration 
#  @target_camera_position The target position node (can be a Camera node)
#  @duration the duration in second of the movement
#  @trans_type The transition type of the tween (see Tween enum TransitionType)
#  @ease_type The ease type of the tween (see Tween enum EaseType)
#  @delay Delay in seconds to start the animation
#  @follow Camera follow in realtime the target object
#  @intermediate_points Intermediate points between current position and target_camera_position
func interpolate(target_camera_position : Spatial, 
				 duration : float, trans_type := 0, ease_type := 2, delay := 0.0, follow := false,
				 intermediate_points : PoolVector3Array = PoolVector3Array()) :
	assert(target_camera_position != null)

	if _tween_in_progress == false:
		# register the target camera position and the target object focus
		_target_camera_position = target_camera_position
		_target_object_focus = null
		# register the duration
		_duration = duration
		# follow or not in realtime the target camera
		follow_target = follow

		_initial_global_transform = global_transform # copy of current global_transform

		_tween.interpolate_method(self, "_move_camera", 0.0, 1.0,
								  duration, trans_type, ease_type, delay)
		# set by default physics, allowing regular animation
		_tween.set_tween_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		if ((bezier_curve_enable ==true) and (follow == false)) :
			_build_new_path(intermediate_points)

## Follow in realime the target camera looking at target_object_focus spatial node.
#  @target_camera_position The target position node of the camera
#  @target_object_focus The point to look at (optional can be null)
#  @duration the duration in second of the movement
func follow_looking_at(target_camera_position : Spatial, target_object_focus : Spatial, duration : float) :
	assert(target_camera_position != null)
	assert(target_object_focus !=null)
	
	# register the target camera position and the target object focus
	_target_camera_position = target_camera_position
	_target_object_focus = target_object_focus
	
	# register the duration
	_duration = duration
	
	follow_target = true
	

## Follow in realime the target camera
#  @target_camera_position The target position node of the camera (can be a Camera node)
#  @duration the duration in second of the movement
func follow(target_camera_position : Spatial, duration : float) :
	assert(target_camera_position != null)
	
	# register the target camera position and the target object focus
	_target_camera_position = target_camera_position
	_target_object_focus = null
	
	# register the duration
	_duration = duration
	
	follow_target = true

	
## Start the tween animation with parameters set previously by interpolate_camera
func start() :
	assert(_target_camera_position != null)
	if _tween_in_progress == false:
		_tween_in_progress = true
		_previous_time = 0
		_tween.start()

## change the duration to reach the target
#  @duration :  the duration of the camera movement in seconds
func set_duration(duration : float) :
	_duration = duration
	
func get_duration() :
	return _duration

## check if a tween is in progress
func is_tween_in_progress() :
	return _tween_in_progress


#### PRIVATE FUNCTIONS

# Called when the node enters the scene tree for the first time.
func _ready():
	_path = null
	_target_object_focus = null
	_target_camera_position = null
	
	_tween = Tween.new()
	add_child(_tween)
	_tween.connect("tween_all_completed", self, "_on_tween_all_completed")

func _build_new_path(intermediate_points : PoolVector3Array):
	if _path == null :
		_path = Curve3D.new()
		_path.up_vector_enabled = false
	else :
		_path.clear_points()
		
	_path.bake_interval = bake_interval
	
	#initial camera direction at the beginning of the curve
	var target_camera_position_transform := _target_camera_position.global_transform
	var straight_direction := (target_camera_position_transform.origin -_initial_global_transform.origin)
	var initial_camera_direction := -_initial_global_transform.basis.z
	var length_straight := straight_direction.length()
	initial_camera_direction = initial_camera_direction.normalized()
	
	var final_camera_direction : Vector3
	var target_object_focus_transform : Transform
	if _target_object_focus != null :
		# Take the orientation of the final camera direction, simply with vector from target camera position to target object focus
		target_object_focus_transform = _target_object_focus.global_transform
		final_camera_direction = (target_object_focus_transform.origin - target_camera_position_transform.origin)
	else :
		# Use the target_camera_position itself to retrieve its orientation
		final_camera_direction = -_target_camera_position.global_transform.basis.z
		
	final_camera_direction = final_camera_direction.normalized()
	
	if intermediate_points.empty() == true :
		_path.add_point(_initial_global_transform.origin, 
						-initial_camera_direction*length_straight * bezier_control_point_strength / 2, 
						initial_camera_direction*length_straight * bezier_control_point_strength / 2)
		_path.add_point(target_camera_position_transform.origin, 
						-final_camera_direction*length_straight * bezier_control_point_strength / 2, 
						final_camera_direction*length_straight * bezier_control_point_strength / 2)
	else :
		#first point
		length_straight =  (_initial_global_transform.origin - intermediate_points[0]).length()
		_path.add_point(_initial_global_transform.origin, 
						-initial_camera_direction*length_straight * bezier_control_point_strength / 2, 
						initial_camera_direction*length_straight * bezier_control_point_strength / 2)
		
		#intermediate points only, controls are computed after
		for i in range(intermediate_points.size()) :
			_path.add_point(intermediate_points[i])
		
		# last point
		length_straight = (target_camera_position_transform.origin - intermediate_points[-1]).length()
		_path.add_point(target_camera_position_transform.origin, 
						-final_camera_direction*length_straight * bezier_control_point_strength / 2, 
						final_camera_direction*length_straight * bezier_control_point_strength / 2)
		
		# will start with the point index 1 (that is the intermediate_points[0]
		for i in range(intermediate_points.size()) :
			var controls := _get_control_points(_path.get_point_position(i), _path.get_point_position(i+1), _path.get_point_position(i+2), bezier_control_point_strength)
			_path.set_point_in(i+1, controls[0])
			_path.set_point_out(i+1, controls[1])
	
	if _target_object_focus != null :
		# Check minimum distance of camera to avoid object
		var baked_points := _path.get_baked_points()
		var radial_vector : Vector3
		var index_minimum_distance := -1
		var index := 0
		var minimum_distance := camera_minimum_distance
		var nb_baked_point := baked_points.size()

		# Find the first camera point inferior to the minimum distance allowed (to avoid target in the camera movement)
		for point in baked_points :
			radial_vector =  point - target_object_focus_transform.origin
			if (radial_vector.length() < minimum_distance) :
				minimum_distance = radial_vector.length()
				index_minimum_distance = index
			index = index + 1
			

		if (index_minimum_distance != -1)  and  (nb_baked_point > 1) and (index_minimum_distance < nb_baked_point -1) :
			# Find the point index in the path before the 'minimum distance point' (baked_points[index_minimum_distance])
			var baked_path_length := _path.get_baked_length()
			var curve_points_distance := baked_path_length / (nb_baked_point - 1)
			var vector_point_path : Vector3
			var vector_point_min_distance : Vector3
			var index_baked_points := 0
			var index_path := 0
			
			for point in baked_points :
				vector_point_path = point -_path.get_point_position(index_path)
				
				if (vector_point_path.length() < (curve_points_distance / 2)) :
					index_path = index_path + 1
					
				if point == baked_points[index_minimum_distance] :
					break
					
				index_baked_points = index_baked_points + 1
			
			assert(index_path > 0)
				
			var direction := baked_points[index_minimum_distance+1] - baked_points[index_minimum_distance]
			var perpendicular_direction := object_up_vector.cross(direction).normalized()

			# check if the point is really the most away to the focus point, in this case get the opposite...
			# todo check when factor > 1
			var new_point_side_plus := baked_points[index_minimum_distance] + perpendicular_direction * (camera_minimum_distance - minimum_distance)
			var new_point_side_minus := baked_points[index_minimum_distance] - perpendicular_direction * (camera_minimum_distance - minimum_distance)
			var new_point : Vector3
		
			if ((new_point_side_plus - target_object_focus_transform.origin).length() <  
				(new_point_side_minus - target_object_focus_transform.origin).length() ) :
				new_point = new_point_side_minus
			else :
				new_point = new_point_side_plus
		
			var controls := _get_control_points(_path.get_point_position(index_path-1), new_point, _path.get_point_position(index_path), bezier_control_point_strength)
			# add new point at position index_path
			_path.add_point(new_point, controls[0], controls[1], index_path)
			
			var nb_points := _path.get_point_count()
			assert(nb_points >= 3)
			
			# Adapt control points of previous and next points from new inserted point
			if index_path == 1 :
				# adapt the control points for first point after the insertion of the new point
				var length_straight_first := (_path.get_point_position(1) - _path.get_point_position(0)).length()
				_path.set_point_in(0, -initial_camera_direction*length_straight_first * bezier_control_point_strength / 2)
				_path.set_point_out(0, initial_camera_direction*length_straight_first * bezier_control_point_strength / 2)
			else :
				controls = _get_control_points(_path.get_point_position(index_path-2), _path.get_point_position(index_path-1), _path.get_point_position(index_path), bezier_control_point_strength)
				_path.set_point_in(index_path - 1, controls[0])
				_path.set_point_out(index_path - 1, controls[1])
			
		
			if index_path == nb_points - 2 :
				# adapt the control points for last point after the insertion of the new point
				var length_straight_last := (_path.get_point_position(index_path + 1) - _path.get_point_position(index_path)).length()
				_path.set_point_in(index_path + 1, -final_camera_direction*length_straight_last * bezier_control_point_strength / 2)
				_path.set_point_out(index_path + 1, final_camera_direction*length_straight_last * bezier_control_point_strength / 2)
			else :
				controls = _get_control_points(_path.get_point_position(index_path), _path.get_point_position(index_path + 1), _path.get_point_position(index_path+2), bezier_control_point_strength)
				_path.set_point_in(index_path + 1, controls[0])
				_path.set_point_out(index_path + 1, controls[1])
				

## Given precedent, current and next point, return control points
#  @P0 :  Precedent point
#  @P1 :  Current point
#  @P2 :  Next point
#  @t  :  Stenght of the control points
func _get_control_points(P0 : Vector3, P1 : Vector3, P2 : Vector3, t:= 0.5) -> Array:
	var d01 := (P1-P0).length();
	var d12 := (P2-P1).length();
	var fa := t*d01/(d01+d12);  
	var fb := t*d12/(d01+d12);
	
	var pc1 := P1-fa*(P2-P0) 
	var pc2 := P1+fb*(P2-P0) 
	var control1 := pc1-P1
	var control2 := pc2-P1
	
	return [control1,control2];
	
## Move the camera to the target and look at target object focus
#  @param time : time normalized between 0 and 1 following specific tween curve
func _move_camera(time : float) :
	# interpolate the position of the camera
	var current_origin : Vector3
	if follow_target:
		# speed to reach the target at end of tween
		if time < 1.0 :
			_speed = (_target_camera_position.global_transform.origin - global_transform.origin).length() / ((1-time)*_duration)
		#else keep precedent speed	
		_follow_object((time - _previous_time) * _duration, time)
	else :
		if (bezier_curve_enable == true) :
			current_origin = _path.interpolate_baked(_path.get_baked_length()*time, true)
		else :
			# trivial linear movement without object avoidance
			current_origin = lerp(_initial_global_transform.origin, _target_camera_position.global_transform.origin, time)
	
		var target_transform : Transform
		if _target_object_focus != null :
			# camera orientation tracking to the object focused
			target_transform = global_transform.looking_at(_target_object_focus.global_transform.origin, object_up_vector)
			
		else :
			# camera orientation of the target camera position
			target_transform = _target_camera_position.global_transform.basis.orthonormalized()
		# interporlate the rotation of the camera smoothly from initial orientation to target one
		var t := pow(time, tween_rotation_speed_pow)
		var current_rotation := Quat(global_transform.basis.orthonormalized()).slerp(target_transform.basis, t)
		# update global_transform
		global_transform = Transform(current_rotation, current_origin)
			
	
		if _target_camera_position is Camera :
			_interpolate_camera_params((time - _previous_time) * _duration, time)
	
	_previous_time = time

func _physics_process(delta : float):
	if _target_camera_position != null :
		if (follow_target == true) and (_tween_in_progress == false):
			# speed of the camera
			_speed = (_target_camera_position.global_transform.origin - global_transform.origin).length() / (_duration)
			# being out of tween animation, consider a progression of 50%, maybe set a parameter (and suppress speed factor !)
			_follow_object(delta, follow_progress_speed)


## Follow the object looking at it
#  @param delta : time ellapsed since the precedent call is seconds
#  @param progress : value between 0 and 1 representing the progress of the movement
func _follow_object(delta : float, progress : float) :
	# update at each frame
	_initial_global_transform = global_transform # copy of current global_transform
	
	# do linear interpolation at target speed
	var direction := (_target_camera_position.global_transform.origin - _initial_global_transform.origin)
	var distance := direction.length()
	var direction_unit := direction.normalized()
	var step := direction_unit * _speed * delta
	var current_origin := _initial_global_transform.origin + step
	
	var target_transform : Transform
	if _target_object_focus != null :
		current_origin = _avoid_object(current_origin)
	
		# camera orientation tracking to the object focused 
		# return of basis gives an oorthonormalized matrix
		target_transform = global_transform.looking_at(_target_object_focus.global_transform.origin, object_up_vector)
	else :
		# camera orientation of the target camera position
		target_transform = _target_camera_position.global_transform.basis.orthonormalized()
	
	# interporlate the rotation of the camera smoothly from initial orientation to target one
	if _tween_in_progress :
		progress = pow(progress, tween_rotation_speed_pow)

	var current_rotation = Quat(global_transform.basis.orthonormalized()).slerp(target_transform.basis, progress)
	
	# update global_transform
	global_transform = Transform(current_rotation, current_origin)
		
	if _target_camera_position is Camera :
		_interpolate_camera_params(delta, progress)

## In follow mode avoid object focused when camera distance too much close
#  Return new position
#  @param current_origin : current camera position
func _avoid_object(current_origin : Vector3) -> Vector3 :
	# move on side if camera distance below threshold
	var target_object_focus_transform := _target_object_focus.global_transform
	var minimum_distance := camera_minimum_distance
	var radial_vector := current_origin - target_object_focus_transform.origin

	if ( radial_vector.length() < minimum_distance) :
		var direction := current_origin - _initial_global_transform.origin
		var target_camera_position_transform := _target_camera_position.global_transform
		var final_camera_direction := (target_object_focus_transform.origin - target_camera_position_transform.origin)
		var perpendicular_direction := object_up_vector.cross(direction).normalized()

		# check if the point is really the most away to the focus point, in this case get the opposite...
		var coeff := (minimum_distance-radial_vector.length())/minimum_distance
		var new_direction_side_plus := (direction.normalized() * (1-coeff)) + (perpendicular_direction * coeff)
		var new_direction_side_minus := (direction.normalized() * (1-coeff)) - (perpendicular_direction * coeff)

		var new_direction : Vector3
		if ( (_initial_global_transform.origin + new_direction_side_plus - target_object_focus_transform.origin).length() <
			 (_initial_global_transform.origin + new_direction_side_minus - target_object_focus_transform.origin).length() ) :
			new_direction = new_direction_side_minus
		else :
			new_direction = new_direction_side_plus
		
		current_origin = _initial_global_transform.origin + new_direction.normalized()*direction.length()
	
	return current_origin

## Interpolate camera params
#  @param delta : delta time ellapsed
#  @param progress : progres between 0 and 1
func _interpolate_camera_params(delta : float, progress : float) :
	var camera := _target_camera_position as Camera
	# The target node can be a Camera3D, which allows interpolating additional properties.
	# In this case, make sure the "Current" property is enabled on the CameraTween
	# and disabled on the Camera3D.
	
	if camera.projection == self.projection:
		var time_remaining := (1-progress) * _duration
		
		# Interpolate the near and far clip plane distances.
		var new_near := 0.0
		var new_far := 0.0
		if time_remaining > 0 :
			var speed_camera_near := (camera.near - self.near) / time_remaining 
			new_near = self.near + speed_camera_near * delta
		else :
			new_near = camera.near
		
		if time_remaining > 0 :
			var speed_camera_far := (camera.far - self.far) / time_remaining
			new_far = self.far + speed_camera_far * delta
		else :
			new_far = camera.far

		# Interpolate size or field of view.
		if camera.projection == Camera.PROJECTION_ORTHOGONAL:
			var new_size := 0.0
			if (time_remaining > 0) :
				var speed_camera_size := (camera.size - self.size)/ time_remaining
				new_size =  self.size + speed_camera_size * delta
			else :
				new_size = camera.size
				
			set_orthogonal(new_size, new_near, new_far)
		else:
			var new_fov := 0.0 
			#var new_fov := lerp(self.fov, camera.fov, t * fov_factor) as float
			if (time_remaining > 0):
				var speed_camera_fov := (camera.fov - self.fov)/ time_remaining
				new_fov = self.fov + speed_camera_fov * delta
			else :
				new_fov = camera.fov
				
			set_perspective(new_fov, new_near, new_far)
	

func _on_tween_all_completed():
	_tween_in_progress = false
	emit_signal("camera_tween_completed")
