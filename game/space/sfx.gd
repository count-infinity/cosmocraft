class_name Sfx
extends Node
## A tiny procedural sound kit so the prototype isn't silent. Every sound is
## synthesized at startup from a few parameters; there are no audio files.

const MIX_RATE := 22050
const VOICES := 24
const MIN_REPEAT_MSEC := 30

var muted := false

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_played: Dictionary = {}


func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_streams["shoot"] = _tone(0.07, "square", 1100.0, 480.0, 0.25, 0.002, 1.5)
	_streams["spit"] = _tone(0.09, "sine", 520.0, 260.0, 0.3, 0.002, 1.5)
	_streams["hit"] = _noise(0.05, 0.35, 0.9, 0.5, 0.001, 1.0)
	_streams["pop"] = _noise(0.2, 0.55, 0.5, 0.06, 0.002, 2.0)
	_streams["boom"] = _noise(0.7, 0.8, 0.35, 0.02, 0.003, 1.6)
	_streams["death"] = _noise(1.2, 0.9, 0.4, 0.01, 0.002, 1.3)
	_streams["dash"] = _noise(0.22, 0.4, 0.04, 0.6, 0.04, 1.0)
	_streams["spark"] = _tone(0.08, "sine", 1300.0, 2100.0, 0.25, 0.002, 1.2)
	_streams["hurt"] = _tone(0.18, "square", 260.0, 90.0, 0.4, 0.002, 1.5)
	_streams["warn"] = _tone(0.09, "square", 880.0, 880.0, 0.25, 0.002, 0.8)
	_streams["deny"] = _tone(0.16, "square", 220.0, 180.0, 0.3, 0.002, 1.0)
	_streams["snuff"] = _tone(0.5, "saw", 520.0, 90.0, 0.45, 0.005, 1.2)
	_streams["elite"] = _tone(1.0, "saw", 75.0, 50.0, 0.6, 0.05, 1.0)
	_streams["kindle"] = _chord(0.7, [220.0, 330.0, 440.0], 0.45, 0.06, 1.4)
	_streams["lance"] = _tone(0.25, "saw", 320.0, 140.0, 0.45, 0.003, 1.3)
	_streams["missile"] = _noise(0.25, 0.3, 0.1, 0.4, 0.02, 1.2)
	_streams["flak"] = _noise(0.12, 0.4, 0.4, 0.1, 0.002, 1.6)
	_streams["torpedo"] = _tone(0.4, "saw", 140.0, 60.0, 0.55, 0.01, 1.2)
	_streams["scatter"] = _noise(0.14, 0.45, 0.7, 0.15, 0.001, 1.8)
	_streams["ting"] = _tone(0.12, "sine", 2400.0, 1800.0, 0.2, 0.001, 1.6)
	_streams["zap"] = _tone(0.08, "square", 1800.0, 900.0, 0.18, 0.001, 1.4)
	_streams["ignite"] = _chord(1.8, [196.0, 293.7, 392.0, 587.3], 0.6, 0.12, 1.2)
	_streams["clink"] = _tone(0.09, "sine", 1700.0, 1250.0, 0.22, 0.001, 1.6)
	_streams["shatter"] = _noise(0.35, 0.5, 0.95, 0.2, 0.001, 1.4)
	_streams["chime"] = _tone(0.12, "sine", 880.0, 1320.0, 0.22, 0.002, 1.2)
	_streams["cache"] = _chord(0.6, [330.0, 440.0, 660.0], 0.35, 0.02, 1.4)
	_streams["plant"] = _chord(0.9, [146.8, 220.0, 293.7], 0.5, 0.03, 1.3)
	_streams["liftoff"] = _noise(1.4, 0.55, 0.05, 0.5, 0.25, 1.0)
	_streams["burn"] = _noise(0.25, 0.3, 0.2, 0.05, 0.01, 1.4)


## `pitch` above zero sets the pitch exactly; otherwise it varies slightly.
func play(sound: String, volume_db := 0.0, pitch := 0.0) -> void:
	if muted or not _streams.has(sound):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < MIN_REPEAT_MSEC:
		return
	_last_played[sound] = now
	var player := _players[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	player.stream = _streams[sound]
	player.volume_db = volume_db
	player.pitch_scale = pitch if pitch > 0.0 else randf_range(0.94, 1.06)
	player.play()


## A single oscillator with an exponential pitch sweep.
func _tone(duration: float, wave: String, freq_start: float, freq_end: float, volume: float, attack: float, decay: float) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		phase = fmod(phase + freq_start * pow(freq_end / freq_start, t) / MIX_RATE, 1.0)
		var value := 0.0
		match wave:
			"sine":
				value = sin(phase * TAU)
			"square":
				value = 1.0 if phase < 0.5 else -1.0
			"saw":
				value = phase * 2.0 - 1.0
		samples[i] = value * _envelope(t, duration, attack, decay)
	return _to_wav(samples, volume)


## White noise through a one-pole low-pass whose cutoff sweeps over time.
func _noise(duration: float, volume: float, cutoff_start: float, cutoff_end: float, attack: float, decay: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(duration * 1000.0) + int(cutoff_start * 100.0)
	var count := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var filtered := 0.0
	for i in count:
		var t := float(i) / count
		filtered += (rng.randf_range(-1.0, 1.0) - filtered) * lerpf(cutoff_start, cutoff_end, t)
		samples[i] = filtered * _envelope(t, duration, attack, decay)
	return _to_wav(samples, volume)


## Stacked sines (plus an octave each) that bend slightly upward: a swell.
func _chord(duration: float, frequencies: Array[float], volume: float, attack: float, decay: float) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phases := PackedFloat32Array()
	phases.resize(frequencies.size())
	for i in count:
		var t := float(i) / count
		var value := 0.0
		for v in frequencies.size():
			phases[v] = fmod(phases[v] + frequencies[v] * (1.0 + 0.04 * t) / MIX_RATE, 1.0)
			value += sin(phases[v] * TAU) + 0.3 * sin(phases[v] * TAU * 2.0)
		samples[i] = value * _envelope(t, duration, attack, decay)
	return _to_wav(samples, volume)


func _envelope(t: float, duration: float, attack: float, decay: float) -> float:
	return minf(1.0, t * duration / maxf(attack, 0.0001)) * pow(1.0 - t, decay)


## Normalizes to `volume` peak and packs into 16-bit mono PCM.
func _to_wav(samples: PackedFloat32Array, volume: float) -> AudioStreamWAV:
	var peak := 0.0001
	for sample in samples:
		peak = maxf(peak, absf(sample))
	var gain := volume / peak
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
