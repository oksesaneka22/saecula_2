extends Node

## AudioManager: Процедурний аудіо-рушій та менеджер звукових ефектів гри Saecula.
## Генерує чисті звукові хвилі (AudioStreamWAV) програмно без залежностей від зовнішніх файлів,
## підтримує просторове 3D-позиціонування звуків, пулінг програвачів та глобальне спостереження EventBus.

const MIX_RATE: int = 22050

var _sounds: Dictionary = {} # StringName -> AudioStreamWAV

# Пули програвачів
var _players_2d: Array[AudioStreamPlayer] = []
var _players_3d: Array[AudioStreamPlayer3D] = []
const MAX_2D_PLAYERS: int = 8
const MAX_3D_PLAYERS: int = 16


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_players_pool()
	_pregenerate_sounds()
	_connect_event_bus()
	print("[AudioManager] 🔊 Аудіо-систему успішно ініціалізовано. Згенеровано %d звукових ефектів." % _sounds.size())


# ------------------------------------------------------------------------------
# Ініціалізація пулу аудіо-плеєрів
# ------------------------------------------------------------------------------
func _init_players_pool() -> void:
	for i in range(MAX_2D_PLAYERS):
		var p := AudioStreamPlayer.new()
		p.name = "AudioPlayer2D_%d" % i
		p.bus = "Master"
		add_child(p)
		_players_2d.append(p)

	for i in range(MAX_3D_PLAYERS):
		var p3 := AudioStreamPlayer3D.new()
		p3.name = "AudioPlayer3D_%d" % i
		p3.bus = "Master"
		p3.max_distance = 40.0
		p3.unit_size = 8.0
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p3)
		_players_3d.append(p3)


# ------------------------------------------------------------------------------
# Генерація та кешування процедурних звуків
# ------------------------------------------------------------------------------
func _pregenerate_sounds() -> void:
	var sound_names: Array[StringName] = [
		&"step",
		&"hit_wood",
		&"hit_stone",
		&"hit_grass",
		&"hit_clay",
		&"build",
		&"craft",
		&"pickup",
		&"era_bell",
		&"tech_unlock",
		&"eat",
		&"drink",
		&"death",
		&"demolish",
		&"build_complete"
	]
	for s_id in sound_names:
		_sounds[s_id] = _generate_wav(s_id)


func _generate_wav(sound_id: StringName) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false

	var duration: float = 0.1
	match sound_id:
		&"step": duration = 0.08
		&"hit_wood": duration = 0.12
		&"hit_stone": duration = 0.14
		&"hit_grass": duration = 0.10
		&"hit_clay": duration = 0.10
		&"build": duration = 0.16
		&"craft": duration = 0.25
		&"pickup": duration = 0.09
		&"era_bell": duration = 1.4
		&"tech_unlock": duration = 0.5
		&"eat": duration = 0.14
		&"drink": duration = 0.22
		&"death": duration = 0.8
		&"demolish": duration = 0.28
		&"build_complete": duration = 0.40

	var sample_count: int = int(float(MIX_RATE) * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	for i in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		var val: float = 0.0

		match sound_id:
			&"step":
				var freq: float = lerpf(180.0, 50.0, progress)
				var env: float = exp(-progress * 14.0)
				val = sin(t * freq * TAU) * env + (randf() * 2.0 - 1.0) * 0.15 * env
			&"hit_wood":
				var freq: float = lerpf(160.0, 80.0, progress)
				var env: float = exp(-progress * 9.0)
				var click: float = (randf() * 2.0 - 1.0) * exp(-progress * 40.0) * 0.6
				val = (sin(t * freq * TAU) * 0.7 + sin(t * freq * 2.2 * TAU) * 0.3) * env + click
			&"hit_stone":
				var env: float = exp(-progress * 8.0)
				var click: float = (randf() * 2.0 - 1.0) * exp(-progress * 30.0) * 0.8
				val = (sin(t * 720.0 * TAU) * 0.5 + sin(t * 1440.0 * TAU) * 0.3 + sin(t * 2200.0 * TAU) * 0.2) * env + click
			&"hit_grass":
				var env: float = exp(-progress * 10.0)
				var noise: float = (randf() * 2.0 - 1.0)
				val = noise * env * sin(t * 300.0 * TAU)
			&"hit_clay":
				var freq: float = lerpf(110.0, 55.0, progress)
				var env: float = exp(-progress * 11.0)
				val = (sin(t * freq * TAU) * 0.8 + (randf() * 2.0 - 1.0) * 0.2) * env
			&"build":
				var env: float = exp(-progress * 7.5)
				var click: float = (randf() * 2.0 - 1.0) * exp(-progress * 25.0) * 0.4
				val = (sin(t * 420.0 * TAU) * 0.6 + sin(t * 840.0 * TAU) * 0.3) * env + click
			&"craft":
				# Висхідний приємний акорд (C5 -> G5)
				var freq: float = 523.25 if progress < 0.45 else 783.99
				var note_t: float = t if progress < 0.45 else (t - 0.45 * duration)
				var env: float = exp(-fmod(progress, 0.45) * 8.0)
				val = (sin(note_t * freq * TAU) + sin(note_t * freq * 2.0 * TAU) * 0.3) * env
			&"pickup":
				var freq: float = lerpf(450.0, 950.0, progress)
				var env: float = exp(-progress * 5.0)
				val = sin(t * freq * TAU) * env
			&"era_bell":
				# Величний дзвін епохи (обертони дзвіниці)
				var env: float = exp(-progress * 3.5)
				val = (sin(t * 220.0 * TAU) * 0.4
					+ sin(t * 440.0 * TAU) * 0.3
					+ sin(t * 660.0 * TAU) * 0.15
					+ sin(t * 880.0 * TAU) * 0.1
					+ sin(t * 1100.0 * TAU) * 0.05) * env
			&"tech_unlock":
				# Трьохнотне святкове арпеджіо (C5, E5, G5)
				var freqs: Array = [523.25, 659.25, 783.99]
				var note_idx: int = clamp(int(progress * 3.0), 0, 2)
				var f: float = freqs[note_idx]
				var sub_prog: float = fmod(progress * 3.0, 1.0)
				var env: float = exp(-sub_prog * 5.5)
				val = (sin(t * f * TAU) + sin(t * f * 2.0 * TAU) * 0.25) * env
			&"eat":
				var crunch: float = (randf() * 2.0 - 1.0) * exp(-fmod(progress * 3.0, 1.0) * 12.0)
				val = crunch * 0.7
			&"drink":
				var bubble: float = sin(t * lerpf(300.0, 600.0, progress) * TAU) * exp(-progress * 6.0)
				val = bubble * 0.8
			&"death":
				var env: float = exp(-progress * 4.0)
				val = (sin(t * 80.0 * TAU) * 0.7 + sin(t * 120.0 * TAU) * 0.3) * env
			&"demolish":
				var freq: float = lerpf(160.0, 45.0, progress)
				var env: float = exp(-progress * 6.5)
				var wood_crack: float = (randf() * 2.0 - 1.0) * exp(-fmod(progress * 4.0, 1.0) * 10.0) * 0.65
				var rumble: float = sin(t * freq * TAU) * 0.6 + sin(t * freq * 0.5 * TAU) * 0.4
				val = (rumble + wood_crack) * env
			&"build_complete":
				# Урочистий мажорний акорд завершення споруди (C5 -> E5 -> G5 -> C6)
				var freqs: Array = [523.25, 659.25, 783.99, 1046.50]
				var note_idx: int = clamp(int(progress * 4.0), 0, 3)
				var f: float = freqs[note_idx]
				var sub_prog: float = fmod(progress * 4.0, 1.0)
				var env: float = exp(-sub_prog * 5.0) * exp(-progress * 2.0)
				var overtone: float = sin(t * f * 2.0 * TAU) * 0.28
				var warmth: float = sin(t * (f * 0.5) * TAU) * 0.2
				val = (sin(t * f * TAU) * 0.65 + overtone + warmth) * env

		val = clampf(val, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(val * 24000.0))

	wav.data = bytes
	return wav


# ------------------------------------------------------------------------------
# Відтворення звуків (API)
# ------------------------------------------------------------------------------
## Відтворює 2D звук інтерфейсу чи глобальної події
func play_sound(sound_name: StringName, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	var stream: AudioStreamWAV = _sounds.get(sound_name, null)
	if stream == null:
		return null

	for player in _players_2d:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.pitch_scale = pitch_scale
			player.play()
			return player

	var p: AudioStreamPlayer = _players_2d[0]
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch_scale
	p.play()
	return p


## Відтворює 3D звук у координатах світу з урахуванням дистанції до слухача
func play_sound_3d(sound_name: StringName, position: Vector3, volume_db: float = 0.0, pitch_scale: float = 1.0, max_distance: float = 35.0) -> AudioStreamPlayer3D:
	var stream: AudioStreamWAV = _sounds.get(sound_name, null)
	if stream == null:
		return null

	for player3d in _players_3d:
		if not player3d.playing:
			player3d.global_position = position
			player3d.max_distance = max_distance
			player3d.stream = stream
			player3d.volume_db = volume_db
			player3d.pitch_scale = pitch_scale
			player3d.play()
			return player3d

	var p3: AudioStreamPlayer3D = _players_3d[0]
	p3.global_position = position
	p3.max_distance = max_distance
	p3.stream = stream
	p3.volume_db = volume_db
	p3.pitch_scale = pitch_scale
	p3.play()
	return p3


# ------------------------------------------------------------------------------
# Інтеграція з EventBus
# ------------------------------------------------------------------------------
func _connect_event_bus() -> void:
	if EventBus == null:
		return

	if EventBus.has_signal("era_advanced"):
		EventBus.era_advanced.connect(func(_new_era, _old_era):
			play_sound(&"era_bell", 2.0)
		)

	if EventBus.has_signal("technology_unlocked"):
		EventBus.technology_unlocked.connect(func(_tech_id):
			play_sound(&"tech_unlock", 1.0)
		)

	if EventBus.has_signal("building_completed"):
		EventBus.building_completed.connect(func(building_node, _b_id, coords):
			var pos: Vector3 = Vector3(coords.x, 0, coords.y)
			if building_node is Node3D:
				pos = (building_node as Node3D).global_position
			elif GridManager != null:
				pos = GridManager.map_to_world_3d(coords, 0.0)
			play_sound_3d(&"build_complete", pos, 2.5, 1.0)
		)

	if EventBus.has_signal("player_died"):
		EventBus.player_died.connect(func(_reason):
			play_sound(&"death", 2.0)
		)

	if EventBus.has_signal("item_picked_up"):
		EventBus.item_picked_up.connect(func(_collector, _item_id, _amount):
			play_sound(&"pickup", -3.0, randf_range(0.95, 1.1))
		)


func _exit_tree() -> void:
	for p in _players_2d:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	for p3 in _players_3d:
		if is_instance_valid(p3):
			p3.stop()
			p3.stream = null
	_players_2d.clear()
	_players_3d.clear()
	_sounds.clear()
