class_name ScreenCapture
extends Node
## Debug: saves screenshots at set times, then quits. GameFlow adds one when
## the game is started with --capture=DIR --shots=3,20 (seconds since launch).
## Anything can ask for an extra shot with ScreenCapture.request(delay).

static var instance: ScreenCapture

var _directory := ""
var _times: Array[float] = []
var _elapsed := 0.0
var _busy := false


## Queues an extra screenshot `delay` seconds from now, if capturing.
static func request(delay: float) -> void:
	if instance != null:
		instance._times.append(instance._elapsed + delay)
		instance._times.sort()


func _init(directory: String, times: Array[float]) -> void:
	_directory = directory
	_times = times
	_times.sort()


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(_directory)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	_elapsed += delta
	if _busy or _times.is_empty() or _elapsed < _times[0]:
		return
	var at: float = _times.pop_front()
	_busy = true
	_save("%s/shot_%05.1f.png" % [_directory, at])


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	# With HDR 2D the viewport texture is linear; the screen gets sRGB.
	if get_viewport().use_hdr_2d:
		image.convert(Image.FORMAT_RGBA8)
		image.linear_to_srgb()
	image.save_png(path)
	print("ScreenCapture: saved ", path)
	_busy = false
	if _times.is_empty():
		get_tree().quit()
