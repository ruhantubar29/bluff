import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'sound_settings.dart';

/// Background music for the app.
///
/// There are no bundled audio tracks, so the loop is synthesised at runtime:
/// a punchy chiptune-style arcade bed (kick, snare, hats, bass and a
/// 16th-note lead arpeggio) over a 4-bar Am–F–C–G progression. It is built
/// for 150 BPM in whole 16th-note steps so every note envelope is forced to
/// zero at its end — the 6.4 s loop point never clicks.
///
/// The mix is normalised through a soft clip so it sits loud enough to feel
/// like a game rather than a whisper. Volume comes from
/// [SoundSettings.musicVolume]; zero stops playback. All platform calls are
/// wrapped so a device without audio never crashes.
class MusicService {
  MusicService._();

  static final MusicService instance = MusicService._();

  static const int _sampleRate = 22050;

  /// 16th note at 150 BPM = 0.1 s = 2205 samples (whole samples, so the
  /// sequencer lands exactly on sample boundaries).
  static const int _stepSamples = 2205;

  /// 4 bars of 16 steps.
  static const int _steps = 64;

  static const int _samples = _steps * _stepSamples;

  AudioPlayer? _player;
  bool _started = false;
  Uint8List? _loop;

  /// Starts or stops music so it always matches the saved volume.
  Future<void> syncWithSettings() async {
    final volume = SoundSettings.instance.musicVolume;
    if (volume <= 0) {
      await stop();
    } else {
      await start();
      await setVolume(volume);
    }
  }

  Future<void> start() async {
    if (_started) return;
    try {
      final player = _player ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setSource(BytesSource(_loop ??= _synthLoop()));
      await player.setVolume(SoundSettings.instance.musicVolume);
      await player.resume();
      _started = true;
    } catch (_) {
      // Audio unavailable (tests, web autoplay policy): ignore.
    }
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    try {
      await _player?.stop();
    } catch (_) {
      // ignore
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _player?.setVolume(volume.clamp(0.0, 1.0));
    } catch (_) {
      // ignore
    }
  }

  Future<void> dispose() async {
    try {
      await _player?.dispose();
    } catch (_) {
      // ignore
    }
    _player = null;
    _started = false;
  }

  // ------------------------------------------------------------- synthesis --

  /// Sequences the four-bar loop and returns it as a looping WAV.
  Uint8List _synthLoop() {
    final buf = List<double>.filled(_samples, 0);
    final rng = math.Random(7); // fixed seed → the same track every launch

    // Bar roots (A2, F2, C3, G2) and the arpeggio tones above them.
    const roots = <double>[110.00, 87.31, 130.81, 98.00];
    const tones = <List<double>>[
      [440.00, 523.25, 659.26], // Am
      [349.23, 440.00, 523.25], // F
      [523.25, 659.26, 783.99], // C
      [392.00, 493.88, 587.33], // G
    ];
    const arpOrder = <int>[0, 1, 2, 1];

    for (var bar = 0; bar < 4; bar++) {
      final base = bar * 16;
      final root = roots[bar];
      final chord = tones[bar];

      // Backbeat.
      _kick(buf, (base + 0) * _stepSamples, 1.0);
      _kick(buf, (base + 4) * _stepSamples, 1.0);
      _kick(buf, (base + 8) * _stepSamples, 1.0);
      _kick(buf, (base + 12) * _stepSamples, 1.0);
      _snare(buf, (base + 4) * _stepSamples, 0.5, rng);
      _snare(buf, (base + 12) * _stepSamples, 0.5, rng);

      // Off-beat hats.
      _hat(buf, (base + 2) * _stepSamples, 0.3, rng);
      _hat(buf, (base + 6) * _stepSamples, 0.3, rng);
      _hat(buf, (base + 10) * _stepSamples, 0.3, rng);
      _hat(buf, (base + 14) * _stepSamples, 0.34, rng);

      // Driving eighth-note bass, lifting an octave into the next bar.
      for (var e = 0; e < 8; e++) {
        final step = base + e * 2;
        final freq = e == 7 ? root * 2 : root;
        _tone(
          buf,
          step * _stepSamples,
          2 * _stepSamples,
          freq,
          0.42,
          wave: _triangle,
          decay: 4,
        );
      }

      // Sixteenth-note lead arpeggio.
      for (var s = 0; s < 16; s++) {
        final freq = chord[arpOrder[s % 4]];
        _tone(
          buf,
          (base + s) * _stepSamples,
          _stepSamples,
          freq,
          0.32,
          wave: (phase) => _pulse(phase, 0.25),
          decay: 14,
        );
      }
    }

    // Soft-clip for loudness: push peaks into the limiter so the body of the
    // mix reads as loud as the drums instead of sitting at 12% of full scale.
    var peak = 0.0;
    for (final v in buf) {
      if (v.abs() > peak) peak = v.abs();
    }
    final drive = peak == 0 ? 0.0 : 1.7 / peak;

    final samples = Int16List(_samples);
    for (var i = 0; i < _samples; i++) {
      final v = _tanh(buf[i] * drive) * 0.93 * 32767;
      samples[i] = v.round().clamp(-32768, 32767);
    }

    return _wav(samples, _sampleRate);
  }

  /// A single enveloped note. The envelope is forced to exactly zero at the
  /// note's end, which is what makes the loop seam inaudible.
  void _tone(
    List<double> buf,
    int start,
    int len,
    double freq,
    double amp, {
    required double Function(double phase) wave,
    required double decay,
  }) {
    for (var i = 0; i < len; i++) {
      final idx = start + i;
      if (idx >= buf.length) return;
      final t = i / _sampleRate;
      final env = math.exp(-decay * t) * (1 - i / len);
      buf[idx] += wave(freq * t) * env * amp;
    }
  }

  void _kick(List<double> buf, int start, double amp) {
    final len = (0.22 * _sampleRate).round();
    var phase = 0.0;
    for (var i = 0; i < len; i++) {
      final idx = start + i;
      if (idx >= buf.length) return;
      final t = i / _sampleRate;
      phase += (48 + 130 * math.exp(-t * 45)) / _sampleRate;
      final env = math.exp(-t * 16) * (1 - i / len);
      buf[idx] += math.sin(2 * math.pi * phase) * env * amp;
    }
  }

  void _snare(List<double> buf, int start, double amp, math.Random rng) {
    final len = (0.16 * _sampleRate).round();
    for (var i = 0; i < len; i++) {
      final idx = start + i;
      if (idx >= buf.length) return;
      final t = i / _sampleRate;
      final noise = rng.nextDouble() * 2 - 1;
      final tone = math.sin(2 * math.pi * 195 * t);
      final env = math.exp(-t * 26) * (1 - i / len);
      buf[idx] += (noise * 0.75 + tone * 0.35) * env * amp;
    }
  }

  void _hat(List<double> buf, int start, double amp, math.Random rng) {
    final len = (0.05 * _sampleRate).round();
    for (var i = 0; i < len; i++) {
      final idx = start + i;
      if (idx >= buf.length) return;
      final t = i / _sampleRate;
      final noise = rng.nextDouble() * 2 - 1;
      final env = math.exp(-t * 90) * (1 - i / len);
      buf[idx] += noise * env * amp;
    }
  }

  // --------------------------------------------------------------- waves --

  /// dart:math has no tanh — this is the standard exponential form.
  static double _tanh(double x) {
    if (x > 8) return 1;
    if (x < -8) return -1;
    final e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }

  static double _pulse(double phase, double duty) {
    final f = phase - phase.floor();
    return f < duty ? 1.0 : -1.0;
  }

  static double _triangle(double phase) {
    final f = phase - phase.floor();
    return f < 0.5 ? 4 * f - 1 : 3 - 4 * f;
  }

  /// Wraps 16-bit mono PCM samples in a standard RIFF/WAVE header.
  Uint8List _wav(Int16List samples, int sampleRate) {
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
    u32(16); // PCM chunk size
    u16(1); // PCM format
    u16(1); // mono
    u32(sampleRate);
    u32(sampleRate * 2); // byte rate
    u16(2); // block align
    u16(16); // bits per sample
    ascii('data');
    u32(dataSize);
    for (final s in samples) {
      out.setInt16(o, s, Endian.little);
      o += 2;
    }
    return out.buffer.asUint8List();
  }
}
