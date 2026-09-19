## TEMPORARY DEBUG OVERLAY - Shows real-time audio state to diagnose silence.
## Remove before merge.
extends CanvasLayer

var _label: Label


func _ready() -> void:
    layer = 100
    _label = Label.new()
    _label.add_theme_font_size_override("font_size", 14)
    _label.add_theme_color_override("font_color", Color.YELLOW)
    _label.add_theme_color_override("font_shadow_color", Color.BLACK)
    _label.add_theme_constant_override("shadow_offset_x", 1)
    _label.add_theme_constant_override("shadow_offset_y", 1)
    _label.position = Vector2(10, 10)
    _label.z_index = 100
    add_child(_label)


func _process(_delta: float) -> void:
    if not is_instance_valid(AudioManager):
        _label.text = "AudioManager NOT FOUND"
        return
    
    var lines := []
    lines.append("=== AUDIO DEBUG ===")
    
    # Bus info
    lines.append("Buses: %d" % AudioServer.bus_count)
    for i in AudioServer.bus_count:
        var bus_name := AudioServer.get_bus_name(i)
        var vol_db := AudioServer.get_bus_volume_db(i)
        var mute := AudioServer.is_bus_mute(i)
        lines.append("  [%d] %s: %.1f dB %s" % [i, bus_name, vol_db, "(MUTED)" if mute else ""])
    
    # Music players
    lines.append("Music A: playing=%s stream=%s vol=%.1f" % [
        AudioManager._music_a.playing,
        "LOADED" if AudioManager._music_a.stream else "NULL",
        AudioManager._music_a.volume_db
    ])
    lines.append("Music B: playing=%s stream=%s vol=%.1f" % [
        AudioManager._music_b.playing,
        "LOADED" if AudioManager._music_b.stream else "NULL",
        AudioManager._music_b.volume_db
    ])
    lines.append("Active: %s" % ("A" if AudioManager._active_music == AudioManager._music_a else "B"))
    
    # SFX pool
    var sfx_playing := 0
    for p in AudioManager._sfx_players:
        if p.playing:
            sfx_playing += 1
    lines.append("SFX pool: %d/%d playing" % [sfx_playing, AudioManager._sfx_players.size()])
    
    # Volumes
    lines.append("Volumes: master=%.2f music=%.2f sfx=%.2f" % [
        AudioManager.master_volume,
        AudioManager.music_volume,
        AudioManager.sfx_volume
    ])
    
    _label.text = "\n".join(lines)
