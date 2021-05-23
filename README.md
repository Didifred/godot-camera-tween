# godot-camera-tween

**This add-on is compatible with Godot 3.2.x.**

A extended camera node add-on to do animations between two camera positions with various easing curves.

___

This add-on allows to do animation movements of a camera in a given time duration with various easing curves (the same than Tween node).
It can behave in 2 different modes non-exclusive :
- Tween like animation, the camera goes to current position to the target in a given (strictly) duration.
The camera trajectory can be simply straight or curved using bezier path automatically computed precalculated at start of the animation
- Follow in realtime the target camera position with constant time duration.

When the target camera position move after the start of the animation, it is suitable to follow it in realtime. 
For that Tween like animation APIs have a follow boolean option. It is also possible to switch to follow mode after the start of the animation.

Optionally it can look at a target object and avoid it with a configurarable minimum distance.

Note that the deprecated InterpolatedCamera can be replaced with this add-on using simply the function   ```func follow(target_camera_position : Spatial, duration : float)```

This repository only contains the add-on.

See https://github.com/Didifred/godot-3d-mannequin/tree/feature/camera-tween-demo for the demonstration project.

## Installation

1. Clone this Git repository:

```bash
git clone https://github.com/didifred/godot-camera-tween.git
```

Alternatively, you can
[download a ZIP archive]( https://github.com/didifred/godot-camera-tween/archive/main.zip)
if you do not have Git installed.

2. Move the `addons/` folder to your project folder.
3. In the editor, open **Project > Project Settings**, go to **Plugins**
   and enable the **CameraTween** plugin.

## Usage

1. After enabling the plugin (see above), add an CameraTween node
   to your scene.

2. For tween like animations, use following functions calls:
   ```
   interpolate_looking_at(target_camera_position : Spatial, target_object_focus : Spatial, duration : float, trans_type=0, ease_type=2, delay=0, follow=false ) 
   or
   interpolate(target_camera_position : Spatial, duration : float, trans_type=0, ease_type=2, delay=0, follow=false )
   start()
   ```
   
   For follow behaviour, use following function calls :
   ```
   follow_looking_at(target_camera_position : Spatial, target_object_focus : Spatial, duration : float)
   or
   follow(target_camera_position : Spatial, duration : float)
    ```
    
3. Configure the CameraTween's parameter values to your liking.
   bezier_curve_enable : (true/false), use a curve trajectory for camera tween animation
   bake_interval : in meters, interval distance of pre-calculated points for the internal Curve3D
   follow_target : (true/false) if true follow the target camera in real time, interrupting an eventual bezier curve
   minimum_distance_factor : (0 to 1.0) , minimum distance between the camera and the focused object to avoid, 1.0 means the distance of the camera target to object to focus.
   object_up_vector : up vector used to avoid object, usually Vector3(0,1,0) 
   tween_rotation_speed_pow : rotation speed pow, value > 1.0 make slow rotation progress at start of the animation but accelerate after to reach the target.
   follow_progress_speed :  progress speed in follow mode, between 0 and 1.0. If 1, reach immediately the target rotation / camera params. If 0, frozen rotation / camera params.
   
## License

Copyright © 2021 Didifred

Unless otherwise specified, files in this repository are licensed under the
MIT license. See LICENCE for more information.
