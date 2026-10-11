import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../../../../core/sound/sound_settings.dart';
import '../state/game_controller.dart';
import 'settings_service.dart';

/// Original, procedurally synthesised sound effects.
///
/// Every cue is generated at runtime as PCM audio — no bundled recordings, no
/// third-party audio, no licensing risk. Cues are short "wooden" knocks and
/// chimes that read clearly over board noise.
class SoundService implements ChessSound {
  SoundService._();

  static final SoundService instance = SoundService._();

  static const int sampleRate = 22050;

  bool _ready = false;
  final Map<String, AudioPool> _pools = {};
  final Map<String, Uint8List> _cache = {};

  ChessSettings get _settings => ChessSettingsService.instance.settings;

  /// In-game option AND the app-wide Settings switch must both be on.
  bool get enabled => _settings.playSounds && SoundSettings.instance.enabled;

  double get _volume => _settings.soundVolume.clamp(0.0, 1.0) * SoundSettings.instance.sfxVolume;

  /// Builds the PCM buffers. Safe to call more than once; the audio pools are
  /// created lazily so startup never blocks on the platform side.
  void preload() {
    if (_ready) return;
    _cache['move'] = _synthMove();
    _cache['capture'] = _synthCapture();
    _cache['castle'] = _synthCastle();
    _cache['promote'] = _synthPromote();
    _cache['check'] = _synthCheck();
    _cache['illegal'] = _synthIllegal();
    _cache['tick'] = _synthTick();
    _cache['start'] = _synthStart();
    _cache['win'] = _synthWin();
    _cache['draw'] = _synthDraw();
    _cache['lose'] = _synthLose();
    _ready = true;
  }

  /// Plays a cue; never throws (audio is a nicety, gameplay is not blocked).
  void play(String key, {double? volume}) {
    if (!enabled || !_ready) return;
    final bytes = _cache[key];
    if (bytes == null) return;
    final v = (volume ?? 1.0) * _volume;
    if (v <= 0) return;
    () async {
      try {
        final pool = _pools[key] ??= await AudioPool.create(
          source: BytesSource(bytes),
          maxPlayers: 4,
          minPlayers: 1,
          // NOT PlayerMode.lowLatency: Android's SoundPool rejects byte
          // sources outright, which used to throw here and silently mute
          // every chess cue. MediaPlayer plays them fine.
          playerMode: PlayerMode.mediaPlayer,
        );
        await pool.start(volume: v.clamp(0.0, 1.0));
      } catch (_) {
        // Platform audio unavailable (tests, unsupported device): ignore.
      }
    }();
  }

  // ---------------------------------------------------------- ChessSound --

  @override
  void move({
    required bool capture,
    required bool castle,
    required bool promotion,
  }) {
    if (promotion) {
      play('promote');
    } else if (castle) {
      play('castle');
    } else if (capture) {
      play('capture');
    } else {
      play('move');
    }
  }

  @override
  void check() => play('check');

  @override
  void gameEnd({required bool isDraw, required bool localWon}) {
    if (isDraw) {
      play('draw');
    } else {
      play(localWon ? 'win' : 'lose');
    }
  }

  @override
  void illegal() => play('illegal');

  @override
  void lowTime() => play('tick', volume: 0.8);

  @override
  void start() => play('start');

  // ------------------------------------------------------------- synthesis --

  /// Allocates a silent mono buffer of [seconds].
  List<double> _buffer(double seconds) =>
      List<double>.filled((seconds * sampleRate).ceil(), 0);

  /// Adds a decaying sine (with optional harmonics) starting at [startSec].
  void _tone(
    List<double> out,
    double freq, {
    double startSec = 0,
    double duration = 0.12,
    double amplitude = 0.5,
    double decay = 4.0,
    List<double> harmonics = const [1.0],
  }) {
    final start = (startSec * sampleRate).floor();
    final count = (duration * sampleRate).floor();
    for (var i = 0; i < count; i++) {
      final idx = start + i;
      if (idx >= out.length || idx < 0) break;
      final t = i / sampleRate;
      final env = math.exp(-decay * t);
      var sample = 0.0;
      for (var h = 0; h < harmonics.length; h++) {
        final partial = (h + 1) * freq * 2 * math.pi * t;
        sample += harmonics[h] * math.sin(partial);
      }
      out[idx] += amplitude * env * sample;
    }
  }

  /// Adds a short noise burst (percussive "wood" transient).
  void _noise(
    List<double> out, {
    double startSec = 0,
    double duration = 0.02,
    double amplitude = 0.3,
    double decay = 60.0,
    math.Random? random,
  }) {
    final rnd = random ?? math.Random(1337);
    final start = (startSec * sampleRate).floor();
    final count = (duration * sampleRate).floor();
    for (var i = 0; i < count; i++) {
      final idx = start + i;
      if (idx >= out.length || idx < 0) break;
      final t = i / sampleRate;
      out[idx] += amplitude * math.exp(-decay * t) * (rnd.nextDouble() * 2 - 1);
    }
  }

  /// A single wooden knock: low body + bright transient.
  void _knock(
    List<double> out, {
    double at = 0,
    double gain = 0.62,
    double baseFreq = 176,
  }) {
    final rnd = math.Random(at.hashCode);
    _tone(
      out,
      baseFreq,
      startSec: at,
      duration: 0.11,
      amplitude: gain,
      decay: 26,
    );
    _tone(
      out,
      baseFreq * 2.4,
      startSec: at,
      duration: 0.07,
      amplitude: gain * 0.45,
      decay: 44,
    );
    _tone(
      out,
      baseFreq * 5.1,
      startSec: at,
      duration: 0.04,
      amplitude: gain * 0.2,
      decay: 70,
    );
    _noise(
      out,
      startSec: at,
      duration: 0.022,
      amplitude: gain * 0.5,
      decay: 140,
      random: rnd,
    );
  }

  /// Softly limits and encodes the buffer as 16-bit mono PCM WAV.
  Uint8List _encode(List<double> buffer) {
    final n = buffer.length;
    final dataSize = n * 2;
    final bytes = Uint8List(44 + dataSize);
    final data = ByteData.view(bytes.buffer);

    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes[offset + i] = s.codeUnitAt(i);
      }
    }

    ascii(0, 'RIFF');
    data.setUint32(4, 36 + dataSize, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little); // PCM header size
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    data.setUint16(32, 2, Endian.little); // block align
    data.setUint16(34, 16, Endian.little); // bits per sample
    ascii(36, 'data');
    data.setUint32(40, dataSize, Endian.little);

    for (var i = 0; i < n; i++) {
      var v = buffer[i];
      // Gentle soft-knee limiter so layered tones never clip harshly.
      v = v < 0 ? -math.atan(-v) * 0.95 : math.atan(v) * 0.95;
      final sample = (v * 32767).round().clamp(-32768, 32767);
      data.setInt16(44 + i * 2, sample, Endian.little);
    }
    return bytes;
  }

  Uint8List _synthMove() {
    final b = _buffer(0.09);
    _knock(b, at: 0, gain: 0.55);
    return _encode(b);
  }

  Uint8List _synthCapture() {
    final b = _buffer(0.16);
    _knock(b, at: 0, gain: 0.66, baseFreq: 150);
    _knock(b, at: 0.05, gain: 0.5, baseFreq: 190);
    return _encode(b);
  }

  Uint8List _synthCastle() {
    final b = _buffer(0.24);
    _knock(b, at: 0, gain: 0.5, baseFreq: 160);
    _knock(b, at: 0.06, gain: 0.45, baseFreq: 175);
    _knock(b, at: 0.13, gain: 0.5, baseFreq: 150);
    return _encode(b);
  }

  Uint8List _synthPromote() {
    final b = _buffer(0.34);
    const notes = [523.25, 659.25, 783.99, 1046.5]; // C5 E5 G5 C6
    for (var i = 0; i < notes.length; i++) {
      _tone(
        b,
        notes[i],
        startSec: i * 0.06,
        duration: 0.18,
        amplitude: 0.4,
        decay: 14,
        harmonics: const [1.0, 0.25],
      );
    }
    return _encode(b);
  }

  Uint8List _synthCheck() {
    final b = _buffer(0.2);
    _tone(
      b,
      987.77,
      startSec: 0,
      duration: 0.08,
      amplitude: 0.4,
      decay: 22,
      harmonics: const [1.0, 0.4],
    );
    _tone(
      b,
      1318.5,
      startSec: 0.07,
      duration: 0.11,
      amplitude: 0.42,
      decay: 18,
      harmonics: const [1.0, 0.4],
    );
    return _encode(b);
  }

  Uint8List _synthIllegal() {
    final b = _buffer(0.17);
    _tone(
      b,
      98,
      startSec: 0,
      duration: 0.16,
      amplitude: 0.5,
      decay: 12,
      harmonics: const [1.0, 0.7, 0.4],
    );
    _noise(b, startSec: 0, duration: 0.05, amplitude: 0.12, decay: 40);
    return _encode(b);
  }

  Uint8List _synthTick() {
    final b = _buffer(0.05);
    _knock(b, at: 0, gain: 0.34, baseFreq: 320);
    return _encode(b);
  }

  Uint8List _synthStart() {
    final b = _buffer(0.3);
    _tone(
      b,
      783.99,
      startSec: 0,
      duration: 0.14,
      amplitude: 0.4,
      decay: 16,
      harmonics: const [1.0, 0.3],
    );
    _tone(
      b,
      1046.5,
      startSec: 0.1,
      duration: 0.18,
      amplitude: 0.42,
      decay: 14,
      harmonics: const [1.0, 0.3],
    );
    return _encode(b);
  }

  Uint8List _synthWin() {
    final b = _buffer(0.6);
    const notes = [523.25, 659.25, 783.99, 1046.5];
    for (var i = 0; i < notes.length; i++) {
      _tone(
        b,
        notes[i],
        startSec: i * 0.09,
        duration: 0.3,
        amplitude: 0.4,
        decay: 9,
        harmonics: const [1.0, 0.3],
      );
    }
    // Final shimmer.
    _tone(b, 1567.98, startSec: 0.36, duration: 0.2, amplitude: 0.2, decay: 12);
    return _encode(b);
  }

  Uint8List _synthDraw() {
    final b = _buffer(0.55);
    _tone(
      b,
      392,
      startSec: 0,
      duration: 0.5,
      amplitude: 0.34,
      decay: 7,
      harmonics: const [1.0, 0.3],
    );
    _tone(
      b,
      587.33,
      startSec: 0.05,
      duration: 0.45,
      amplitude: 0.3,
      decay: 7,
      harmonics: const [1.0, 0.3],
    );
    return _encode(b);
  }

  Uint8List _synthLose() {
    final b = _buffer(0.55);
    const notes = [523.25, 440.0, 349.23];
    for (var i = 0; i < notes.length; i++) {
      _tone(
        b,
        notes[i],
        startSec: i * 0.11,
        duration: 0.32,
        amplitude: 0.38,
        decay: 9,
        harmonics: const [1.0, 0.25],
      );
    }
    return _encode(b);
  }

  /// Releases pooled players (used by tests / logout).
  Future<void> dispose() async {
    for (final pool in _pools.values) {
      try {
        await pool.dispose();
      } catch (_) {
        // Best effort.
      }
    }
    _pools.clear();
  }
}
