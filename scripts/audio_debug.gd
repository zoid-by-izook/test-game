## TEMPORARY DEBUG OVERLAY - Shows real-time audio state to diagnose silence.
## Remove before merge.
extends CanvasLayer

var _label: Label
# TEMPORARY: web AudioContext state via the debug hook injected into index.js
# by the deploy workflow (remove with the hook before merge).
var _ctx_state := "n/a"
var _ctx_poll := 0.0


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


func _process(delta: float) -> void:
    if not is_instance_valid(AudioManager):
        _label.text = "AudioManager NOT FOUND"
        return

    # Poll the AudioContext state at 2 Hz (temporary debug).
    _ctx_poll += delta
    if _ctx_poll >= 0.5:
        _ctx_poll = 0.0
        _ctx_state = _read_ctx_state()

    var lines := []
    lines.append("=== AUDIO DEBUG ===")
    lines.append("AudioContext: %s" % _ctx_state)
    
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
    # TEMPORARY: confirm the #119026 workaround is live (2 = STREAM).
    lines.append("Playback: A=%d B=%d (2=stream)" % [
        AudioManager._music_a.playback_type,
        AudioManager._music_b.playback_type
    ])
    
    # SFX pool
    var sfx_playing := 0
    for p in AudioManager._sfx_players:
        if p.playing:
            sfx_playing += 1
    lines.append("SFX pool: %d/%d playing" % [sfx_playing, AudioManager._sfx_players.size()])

    # TEMPORARY: JS bus-routing state (Godot issue #119026). Remove before merge.
    lines.append("Bus routing: %s" % _read_bus_state())
    
    # Volumes
    lines.append("Volumes: master=%.2f music=%.2f sfx=%.2f" % [
        AudioManager.master_volume,
        AudioManager.music_volume,
        AudioManager.sfx_volume
    ])
    
    _label.text = "\n".join(lines)


# TEMPORARY: reads the AudioContext state through the debug hook injected into
# index.js by the deploy workflow (window.__godotAudioDbg). Remove before merge.
func _read_ctx_state() -> String:
    if not OS.has_feature("web"):
        return "n/a (not web)"
    var res = JavaScriptBridge.eval(
        "window.__godotAudioDbg ? window.__godotAudioDbg.state() : \"no-hook\"", true)
    if res == null:
        return "null"
    return str(res)


# TEMPORARY: reads the JS bus-routing state through the debug hook injected
# into index.js by the deploy workflow. masterSendNull=true means the Master
# bus still feeds ctx.destination (no #119026 scramble). Remove before merge.
func _read_bus_state() -> String:
    if not OS.has_feature("web"):
        return "n/a (not web)"
    var res = JavaScriptBridge.eval(
        "window.__godotAudioDbg && window.__godotAudioDbg.busState ? window.__godotAudioDbg.busState() : \"no-hook\"", true)
    if res == null:
        return "null"
    return str(res)
