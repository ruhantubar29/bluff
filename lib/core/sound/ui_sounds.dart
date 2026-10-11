import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import 'sound_settings.dart';

/// A short, soft UI tick played whenever the user taps a control.
///
/// The sound is synthesised (no assets) and pooled for low latency. It obeys
/// the app-wide SFX slider in Settings, so dragging SFX to zero silences taps
/// too. Every platform call is wrapped so a device without audio never
/// crashes.
class UiSounds {
  UiSounds._();

  static final UiSounds instance = UiSounds._();

  static const int _sampleRate = 22050;

  /// ~55 ms woodblock-ish tick buffer length.
  static const int _clickSamples = 1213;

  Future<AudioPool>? _poolFuture;
  Uint8List? _click;

  bool get _enabled =>
      SoundSettings.instance.enabled && SoundSettings.instance.sfxVolume > 0;

  /// Builds the PCM buffer and warms the player pool so the first tap has no
  /// setup latency. Safe to call more than once, and never rejects.
  Future<void> preload() async {
    try {
      _click ??= _synthClick();
      await _ensurePool();
    } catch (_) {
      // Audio unavailable here (tests, unsupported device): clear the memo so
      // the first real tap retries instead of inheriting a poisoned future.
      _poolFuture = null;
    }
  }

  Future<AudioPool> _ensurePool() {
    // Memoise the future so concurrent taps share one pool instead of each
    // racing to build their own.
    return _poolFuture ??= AudioPool.create(
      source: BytesSource(_click!),
      maxPlayers: 3,
      minPlayers: 1,
      // NOTE: NOT PlayerMode.lowLatency. Android's SoundPool path rejects
      // byte sources outright ("Bytes sources are not supported on
      // LOW_LATENCY mode yet"), which silently kills every cue. MediaPlayer
      // supports them and still replays instantly from a prepared player.
      playerMode: PlayerMode.mediaPlayer,
    );
  }

  /// Plays the tap tick; never throws.
  void click() {
    if (!_enabled) return;
    final volume = SoundSettings.instance.sfxVolume;
    if (volume <= 0) return;

    () async {
      try {
        _click ??= _synthClick();
        final pool = await _ensurePool();
        await pool.start(volume: volume.clamp(0.0, 1.0));
      } catch (_) {
        // Audio unavailable (tests, unsupported device): let the next tap
        // retry rather than caching a poisoned pool.
        _poolFuture = null;
      }
    }();
  }

  /// ~55 ms woodblock-ish tick: a fast sine blip with a touch of noise for
  /// attack, normalised so it sits clearly above the music bed.
  Uint8List _synthClick() {
    const n = _clickSamples;
    final buf = List<double>.filled(n, 0);
    final rng = math.Random(11);

    var phase = 0.0;
    double peak = 0;
    for (var i = 0; i < n; i++) {
      final t = i / _sampleRate;
      phase += (1150 - 260 * (i / n)) / _sampleRate;
      final body = math.sin(2 * math.pi * phase);
      final attack = i < 88 ? (rng.nextDouble() * 2 - 1) * 0.5 : 0.0;
      final env = math.exp(-t * 46) * (1 - i / n);
      final v = (body * 0.9 + attack) * env;
      buf[i] = v;
      if (v.abs() > peak) peak = v.abs();
    }

    final samples = Int16List(n);
    final scale = peak == 0 ? 0.0 : 0.72 / peak;
    for (var i = 0; i < n; i++) {
      samples[i] = (buf[i] * scale * 32767).round().clamp(-32768, 32767);
    }
    return _wav(samples);
  }

  Uint8List _wav(Int16List samples) {
    const sampleRate = _sampleRate;
    final dataSize = samples.length * 2;
    final out = ByteData(44 + dataSize);
    var o = 0;

    void ascii(String s) {
      for (final c in s.codeUnits) {
        out.setUint8(o++, c);
      }
    }

    void u32(int v) {
      out.setUint32(o, v, Endian.little);
      o += 4;
    }

    void u16(int v) {
      out.setUint16(o, v, Endian.little);
      o += 2;
    }

    ascii('RIFF');
    u32(36 + dataSize);
    ascii('WAVE');
    ascii('fmt ');
    u32(16);
    u16(1);
    u16(1);
    u32(sampleRate);
    u32(sampleRate * 2);
    u16(2);
    u16(16);
    ascii('data');
    u32(dataSize);
    for (final s in samples) {
      out.setInt16(o, s, Endian.little);
      o += 2;
    }
    return out.buffer.asUint8List();
  }
}

/// Wraps the whole app and ticks on every genuine tap.
///
/// Placed above the [Navigator] via [MaterialApp.builder] so it sees taps on
/// buttons, tiles and list rows alike. A pointer only counts as a tap when it
/// stays under [_maxSlop] and lifts within [_maxDuration] — that keeps
/// scrolling, dragging and slider scrubbing silent.
class TapSoundScope extends StatefulWidget {
  const TapSoundScope({super.key, required this.child});

  final Widget child;

  @override
  State<TapSoundScope> createState() => _TapSoundScopeState();
}

class _TapSoundScopeState extends State<TapSoundScope> {
  static const double _maxSlop = 18;
  static const Duration _maxDuration = Duration(milliseconds: 350);

  int? _pointer;
  Offset? _origin;
  Duration? _began;

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _origin = e.position;
    _began = e.timeStamp;
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    final origin = _origin;
    final began = _began;
    _pointer = null;
    _origin = null;
    _began = null;
    if (origin == null || began == null) return;

    final moved = (e.position - origin).distance;
    final held = e.timeStamp - began;
    if (moved <= _maxSlop && held <= _maxDuration) {
      UiSounds.instance.click();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: (e) {
        if (e.pointer == _pointer) {
          _pointer = null;
          _origin = null;
          _began = null;
        }
      },
      child: widget.child,
    );
  }
}
