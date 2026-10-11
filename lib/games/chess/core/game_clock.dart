import 'models/time_control.dart';

String _twoDigits(int n) => n.toString().padLeft(2, '0');

/// Which player a clock belongs to.
enum ClockSide { white, black }

extension ClockSideLabel on ClockSide {
  bool get isWhite => this == ClockSide.white;
  ClockSide get other =>
      this == ClockSide.white ? ClockSide.black : ClockSide.white;
  String get label => isWhite ? 'White' : 'Black';
}

/// A real chess clock.
///
/// Pure logic with an injectable time source, so behaviour (countdown,
/// increment, timeout) can be tested without wall-clock sleeps. The clock
/// only advances while [isRunning]; callers stop it the moment a game ends.
class GameClock {
  GameClock({
    required this.timeControl,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        _whiteRemaining = timeControl.initial,
        _blackRemaining = timeControl.initial;

  final TimeControl timeControl;
  final DateTime Function() _now;

  Duration _whiteRemaining;
  Duration _blackRemaining;

  DateTime? _runningSince;
  ClockSide _activeSide = ClockSide.white;
  bool _expired = false;

  // ------------------------------------------------------------- state --

  bool get hasClock => timeControl.hasClock;

  bool get isRunning => hasClock && _runningSince != null && !_expired;

  /// Side whose clock is counting down (only meaningful while running).
  ClockSide get activeSide => _activeSide;

  /// True once either side has reached zero.
  bool get isExpired => _expired;

  ClockSide? get expiredSide {
    if (!_expired) return null;
    if (_whiteRemaining <= Duration.zero) return ClockSide.white;
    if (_blackRemaining <= Duration.zero) return ClockSide.black;
    return null;
  }

  // ------------------------------------------------------------ reading --

  /// Remaining time for [side], counting down live while running.
  Duration remaining(ClockSide side) {
    var base = side == ClockSide.white ? _whiteRemaining : _blackRemaining;
    if (isRunning && _activeSide == side) {
      base -= _now().difference(_runningSince!);
      if (base < Duration.zero) base = Duration.zero;
    }
    return base;
  }

  Duration get whiteRemaining => remaining(ClockSide.white);
  Duration get blackRemaining => remaining(ClockSide.black);

  /// Milliseconds left, for persistence and comparisons.
  int whiteMs() => whiteRemaining.inMilliseconds;
  int blackMs() => blackRemaining.inMilliseconds;

  /// True when [side] has under [threshold] left (low-time warnings).
  bool isLowTime(ClockSide side, {Duration threshold = const Duration(seconds: 20)}) =>
      hasClock && remaining(side) <= threshold;

  bool isCriticalTime(ClockSide side) =>
      hasClock && remaining(side) <= const Duration(seconds: 10);

  // ----------------------------------------------------------- control --

  /// Starts the clock for [side]. Idempotent while already running.
  void start({ClockSide? forSide}) {
    if (!hasClock || _expired) return;
    if (forSide != null) _activeSide = forSide;
    _runningSince ??= _now();
  }

  /// Stops the clock, banking the elapsed time for the active side.
  void stop() {
    _flush();
  }

  /// Stops permanently (game over). Further [start] calls do nothing.
  void halt() {
    _flush();
    _expired = true;
  }

  /// Resets to the initial time control (rematch).
  void reset() {
    _whiteRemaining = timeControl.initial;
    _blackRemaining = timeControl.initial;
    _runningSince = null;
    _activeSide = ClockSide.white;
    _expired = false;
  }

  /// Records a move by [side]: applies the increment and hands the clock to
  /// the opponent. The clock must be running for time to be consumed first.
  void movePlayed(ClockSide side) {
    if (!hasClock || _expired) return;
    final wasRunning = isRunning;
    _flush();
    if (timeControl.increment > Duration.zero) {
      if (side == ClockSide.white) {
        _whiteRemaining += timeControl.increment;
      } else {
        _blackRemaining += timeControl.increment;
      }
    }
    _activeSide = side.other;
    if (wasRunning) _runningSince = _now();
  }

  /// Forces a side's remaining time (server-authoritative sync). Clamps at
  /// zero and marks expiry when the time is gone. Keeps the clock running if
  /// it was running before the sync.
  void setRemaining(ClockSide side, Duration value) {
    final wasRunning = _runningSince != null;
    _flush();
    if (value < Duration.zero) value = Duration.zero;
    if (side == ClockSide.white) {
      _whiteRemaining = value;
    } else {
      _blackRemaining = value;
    }
    if (value == Duration.zero && hasClock) _expired = true;
    _runningSince = (wasRunning && !_expired) ? _now() : null;
  }

  /// Checks for timeout and, if a side has run out, stops the clock and
  /// returns the side that flagged. Call from the ticking UI loop.
  ClockSide? checkTimeout() {
    if (!hasClock || _expired) return null;
    final side = _activeSide;
    if (remaining(side) > Duration.zero) return null;
    _flush();
    if (side == ClockSide.white) _whiteRemaining = Duration.zero;
    if (side == ClockSide.black) _blackRemaining = Duration.zero;
    _expired = true;
    return side;
  }

  /// Snapshot for persistence.
  Map<String, dynamic> toJson() => {
        'whiteMs': whiteMs(),
        'blackMs': blackMs(),
        'activeSide': _activeSide.name,
      };

  /// Restores a snapshot; call [start] afterwards to resume ticking.
  void restoreFromJson(Map<String, dynamic> json) {
    _whiteRemaining =
        Duration(milliseconds: (json['whiteMs'] as num?)?.toInt() ?? 0);
    _blackRemaining =
        Duration(milliseconds: (json['blackMs'] as num?)?.toInt() ?? 0);
    final side = json['activeSide'] as String?;
    _activeSide = side == 'black' ? ClockSide.black : ClockSide.white;
    _runningSince = null;
    _expired = _whiteRemaining <= Duration.zero || _blackRemaining <= Duration.zero;
  }

  void _flush() {
    if (_runningSince == null) return;
    final elapsed = _now().difference(_runningSince!);
    if (_activeSide == ClockSide.white) {
      _whiteRemaining -= elapsed;
      if (_whiteRemaining < Duration.zero) _whiteRemaining = Duration.zero;
    } else {
      _blackRemaining -= elapsed;
      if (_blackRemaining < Duration.zero) _blackRemaining = Duration.zero;
    }
    _runningSince = null;
  }

  /// Formats as m:ss, or h:mm:ss for long controls. Tenth of a second is
  /// shown under 20 seconds for urgency.
  static String format(Duration d, {bool verbose = false}) {
    if (d < Duration.zero) return '0:00';
    final total = d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;

    if (h > 0) return '$h:${_twoDigits(m)}:${_twoDigits(s)}';
    if (verbose && d.inMilliseconds < 20000) {
      final tenths = (d.inMilliseconds % 1000) ~/ 100;
      return '$m:${_twoDigits(s)}.$tenths';
    }
    return '$m:${_twoDigits(s)}';
  }
}
