extends RefCounted
## Only budgets stationary human presentation. Gameplay and collisions stay live.
const NEAR_DISTANCE=35.0
const FAR_INTERVAL=.2
var pending=0.0
var remaining=0.0
var updates=0
var skipped=0
func configure(seed_value: int) -> void:
    # Spread distant actors over the interval instead of posing all nine together.
    remaining=float(posmod(seed_value,1000))/1000.0*FAR_INTERVAL
func full_rate(point: Vector3,observer: Vector3,camera: Camera3D,forced: bool=false) -> bool:
    if forced or point.distance_squared_to(observer)<=NEAR_DISTANCE*NEAR_DISTANCE:return true
    if not is_instance_valid(camera):return true
    # Conservative sphere: keep complete silhouettes and edge-of-view poses live.
    var center=point+Vector3.UP
    for plane in camera.get_frustum():
        if plane.distance_to(center)>2.0:return false
    return true
func consume(delta: float,immediate: bool) -> float:
    pending+=delta;remaining-=delta
    if not immediate and remaining>0:skipped+=1;return -1.0
    var elapsed=pending;pending=0.0;remaining=FAR_INTERVAL;updates+=1
    return elapsed
