class_name AudioMenu
extends VBoxContainer

signal back_requested

var _mute_button: Button
var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	_build()


func refresh() -> void:
	_sync()
	_mute_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var title := Label.new()
	title.text = "AUDIO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	add_child(title)

	_mute_button = Button.new()
	_mute_button.custom_minimum_size = Vector2(300, 56)
	_mute_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_mute_button.add_theme_font_size_override("font_size", 24)
	_mute_button.pressed.connect(_on_mute_pressed)
	add_child(_mute_button)

	_master_slider = _make_row("Master")
	_music_slider = _make_row("Music")
	_sfx_slider = _make_row("SFX")

	_master_slider.value_changed.connect(func(v: float) -> void: AudioManager.set_master_volume(v))
	_music_slider.value_changed.connect(func(v: float) -> void: AudioManager.set_music_volume(v))
	_sfx_slider.value_changed.connect(_on_sfx_changed)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(300, 56)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func() -> void: back_requested.emit())
	add_child(back)


func _make_row(label_text: String) -> HSlider:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(110, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	row.add_child(label)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(260, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.max_value = 1.0
	slider.step = 0.01
	row.add_child(slider)
	return slider


func _sync() -> void:
	_master_slider.set_value_no_signal(AudioManager.master_volume)
	_music_slider.set_value_no_signal(AudioManager.music_volume)
	_sfx_slider.set_value_no_signal(AudioManager.sfx_volume)
	_mute_button.text = "Sound: Off" if AudioManager.is_muted() else "Sound: On"


func _on_mute_pressed() -> void:
	AudioManager.set_muted(not AudioManager.is_muted())
	_sync()


func _on_sfx_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)
	AudioManager.play_sfx("coin")
