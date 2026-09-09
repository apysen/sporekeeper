class_name RunAudio
extends Node

## Every sound the run plays for itself: the ambient forest theme and the three
## Clover machine voices.
##
## It owns the players and the one repair the theme needs; what to play and when is
## decided by whoever asks, so the run root and the slot panel call in rather than
## this node watching them. `AudioSettings` still owns the bus names and the output
## caps, and the pause menu still owns the sliders - a level set on the bus reaches
## these players because they sit on that bus, not because this node was told.

## Plays and loops the authored ambient forest theme.
@export var ambient_music: AudioStreamPlayer
## The lever going down. Optional, like the two below it: a scene without the player
## simply runs the machine silently rather than failing to load.
@export var slot_lever: AudioStreamPlayer
## One reel coming to rest. Polyphonic, because three reels stop close together and
## the third click must not cut the second one off.
@export var slot_reel: AudioStreamPlayer
## A jackpot landing, path or Clover alike.
@export var slot_jackpot: AudioStreamPlayer


func _ready() -> void:
	_configure_ambient_music()


func play_lever() -> void:
	_play(slot_lever)


func play_reel() -> void:
	_play(slot_reel)


func play_jackpot() -> void:
	_play(slot_jackpot)


func _play(voice: AudioStreamPlayer) -> void:
	# Every slot-machine sound goes out the same door. The players sit on the SFX bus,
	# which is where the run's 20% output cap lives, so none of them can be louder than
	# the rest of the game's effects however the stream itself was recorded.
	if voice == null or voice.stream == null:
		return
	voice.play()


func _configure_ambient_music() -> void:
	var wav_stream := ambient_music.stream as AudioStreamWAV
	var repaired_loop_bounds := false
	if wav_stream != null:
		var full_stream_sample_count := roundi(wav_stream.get_length() * wav_stream.mix_rate)
		if wav_stream.loop_begin != 0 or wav_stream.loop_end <= wav_stream.loop_begin:
			wav_stream.loop_begin = 0
			wav_stream.loop_end = full_stream_sample_count
			repaired_loop_bounds = true
		if wav_stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			repaired_loop_bounds = true
	if repaired_loop_bounds:
		ambient_music.stop()
	call_deferred("_ensure_playing")


func _ensure_playing() -> void:
	if ambient_music.stream != null and not ambient_music.playing:
		ambient_music.play()
