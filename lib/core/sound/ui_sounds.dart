import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
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
  /// attack, normalised to sit clearly above the rest of the mix.
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

/// Watches taps across the whole app and ticks only when a control is pressed.
///
/// Mounted above the [Navigator] via [MaterialApp.builder]. Pointers are
/// observed through the router's global route rather than a wrapping
/// [Listener], which keeps this scope out of its own hit test — otherwise it
/// would look like a control on every single tap. A pointer only counts as a
/// tap when it stays under [_maxSlop] and lifts within [_maxDuration], which
/// keeps scrolling, dragging and slider scrubbing silent, *and* the spot it
/// landed on must be pressable, so tapping blank space never ticks.
class TapSoundScope extends StatefulWidget {
  const TapSoundScope({super.key, required this.child});

  final Widget child;

  /// Whether a tap at [position] landed on a pressable control rather than on
  /// blank space.
  ///
  /// Re-runs the hit test at the tap point. Every gesture-driven control —
  /// buttons, tiles, list rows, game options — forwards presses through its
  /// own [RenderPointerListener], and a disabled control drops those
  /// callbacks, so it stays quiet too.
  ///
  /// The [Navigator] installs a listener over the entire app as well, so one
  /// press listener is just chrome and is present on every tap, blank space
  /// included. A control is what puts a *second* one inside it.
  ///
  /// shortcut: a screen that installs its own full-screen press listener
  /// inside the Navigator would read as a control on blank taps — upgrade to
  /// identifying the listener by owner if such a screen is ever added.
  static bool hitsControl(BuildContext context, Offset position) {
    final view = View.maybeOf(context);
    if (view == null) return false;

    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, position, view.viewId);

    var presses = 0;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is! RenderPointerListener) continue;
      if (target.onPointerDown == null) continue;
      presses++;
    }
    return presses > 1;
  }

  @override
  State<TapSoundScope> createState() => _TapSoundScopeState();
}

class _TapSoundScopeState extends State<TapSoundScope> {
  static const double _maxSlop = 18;
  static const Duration _maxDuration = Duration(milliseconds: 350);

  int? _pointer;
  Offset? _origin;
  Duration? _began;

  @override
  void initState() {
    super.initState();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointer);
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handlePointer);
    super.dispose();
  }

  void _handlePointer(PointerEvent e) {
    if (e is PointerDownEvent) {
      if (_pointer != null) return;
      _pointer = e.pointer;
      _origin = e.position;
      _began = e.timeStamp;
      return;
    }

    if (e.pointer != _pointer) return;
    if (e is PointerCancelEvent) {
      _clear();
      return;
    }
    if (e is! PointerUpEvent) return;

    final origin = _origin;
    final began = _began;
    _clear();
    if (origin == null || began == null) return;

    final moved = (e.position - origin).distance;
    final held = e.timeStamp - began;
    if (moved <= _maxSlop &&
        held <= _maxDuration &&
        TapSoundScope.hitsControl(context, e.position)) {
      UiSounds.instance.click();
    }
  }

  void _clear() {
    _pointer = null;
    _origin = null;
    _began = null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
