import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Visual/behavioural preferences for the chess platform.
///
/// Sections follow the product spec: Board, Gameplay, Account, Notifications.
/// Everything persists locally through [SharedPreferences].
class ChessSettings {
  ChessSettings({
    // --- Board ---
    this.boardThemeId = 'tournament',
    this.pieceThemeId = 'classic',
    this.showCoordinates = true,
    this.showLegalDots = true,
    this.showLastMove = true,
    this.showCheckHighlight = true,
    this.animateMoves = true,
    this.moveAnimationMs = 180,
    this.flipBoardWithColor = true,
    // --- Gameplay ---
    this.autoQueen = false,
    this.confirmMoves = false,
    this.playSounds = true,
    this.soundVolume = 0.7,
    this.pieceSoundTheme = 'classic',
    this.showEvalBar = true,
    this.showMoveList = true,
    this.confirmResign = true,
    this.allowTakebacks = true,
    this.defaultTimeControlLabel = '10 + 0',
    this.defaultComputerLevel = 3,
    this.preferBlack = false,
    // --- Account ---
    this.showRatingChanges = true,
    this.richPresence = true,
    // --- Notifications ---
    this.notifyChallenges = true,
    this.notifyFriendRequests = true,
    this.notifyGameStart = true,
    this.notifyDailyPuzzle = true,
  });

  // Board
  String boardThemeId;
  String pieceThemeId;
  bool showCoordinates;
  bool showLegalDots;
  bool showLastMove;
  bool showCheckHighlight;
  bool animateMoves;
  int moveAnimationMs;
  bool flipBoardWithColor;

  // Gameplay
  bool autoQueen;
  bool confirmMoves;
  bool playSounds;
  double soundVolume;
  String pieceSoundTheme;
  bool showEvalBar;
  bool showMoveList;
  bool confirmResign;
  bool allowTakebacks;
  String defaultTimeControlLabel;
  int defaultComputerLevel;
  bool preferBlack;

  // Account
  bool showRatingChanges;
  bool richPresence;

  // Notifications
  bool notifyChallenges;
  bool notifyFriendRequests;
  bool notifyGameStart;
  bool notifyDailyPuzzle;

  Duration get moveAnimation =>
      animateMoves ? Duration(milliseconds: moveAnimationMs) : Duration.zero;

  ChessSettings copyWith({
    String? boardThemeId,
    String? pieceThemeId,
    bool? showCoordinates,
    bool? showLegalDots,
    bool? showLastMove,
    bool? showCheckHighlight,
    bool? animateMoves,
    int? moveAnimationMs,
    bool? flipBoardWithColor,
    bool? autoQueen,
    bool? confirmMoves,
    bool? playSounds,
    double? soundVolume,
    String? pieceSoundTheme,
    bool? showEvalBar,
    bool? showMoveList,
    bool? confirmResign,
    bool? allowTakebacks,
    String? defaultTimeControlLabel,
    int? defaultComputerLevel,
    bool? preferBlack,
    bool? showRatingChanges,
    bool? richPresence,
    bool? notifyChallenges,
    bool? notifyFriendRequests,
    bool? notifyGameStart,
    bool? notifyDailyPuzzle,
  }) {
    final s = ChessSettings(
      boardThemeId: boardThemeId ?? this.boardThemeId,
      pieceThemeId: pieceThemeId ?? this.pieceThemeId,
      showCoordinates: showCoordinates ?? this.showCoordinates,
      showLegalDots: showLegalDots ?? this.showLegalDots,
      showLastMove: showLastMove ?? this.showLastMove,
      showCheckHighlight: showCheckHighlight ?? this.showCheckHighlight,
      animateMoves: animateMoves ?? this.animateMoves,
      moveAnimationMs: moveAnimationMs ?? this.moveAnimationMs,
      flipBoardWithColor: flipBoardWithColor ?? this.flipBoardWithColor,
      autoQueen: autoQueen ?? this.autoQueen,
      confirmMoves: confirmMoves ?? this.confirmMoves,
      playSounds: playSounds ?? this.playSounds,
      soundVolume: soundVolume ?? this.soundVolume,
      pieceSoundTheme: pieceSoundTheme ?? this.pieceSoundTheme,
      showEvalBar: showEvalBar ?? this.showEvalBar,
      showMoveList: showMoveList ?? this.showMoveList,
      confirmResign: confirmResign ?? this.confirmResign,
      allowTakebacks: allowTakebacks ?? this.allowTakebacks,
      defaultTimeControlLabel:
          defaultTimeControlLabel ?? this.defaultTimeControlLabel,
      defaultComputerLevel: defaultComputerLevel ?? this.defaultComputerLevel,
      preferBlack: preferBlack ?? this.preferBlack,
      showRatingChanges: showRatingChanges ?? this.showRatingChanges,
      richPresence: richPresence ?? this.richPresence,
      notifyChallenges: notifyChallenges ?? this.notifyChallenges,
      notifyFriendRequests: notifyFriendRequests ?? this.notifyFriendRequests,
      notifyGameStart: notifyGameStart ?? this.notifyGameStart,
      notifyDailyPuzzle: notifyDailyPuzzle ?? this.notifyDailyPuzzle,
    );
    return s;
  }

  Map<String, dynamic> toJson() => {
        'boardThemeId': boardThemeId,
        'pieceThemeId': pieceThemeId,
        'showCoordinates': showCoordinates,
        'showLegalDots': showLegalDots,
        'showLastMove': showLastMove,
        'showCheckHighlight': showCheckHighlight,
        'animateMoves': animateMoves,
        'moveAnimationMs': moveAnimationMs,
        'flipBoardWithColor': flipBoardWithColor,
        'autoQueen': autoQueen,
        'confirmMoves': confirmMoves,
        'playSounds': playSounds,
        'soundVolume': soundVolume,
        'pieceSoundTheme': pieceSoundTheme,
        'showEvalBar': showEvalBar,
        'showMoveList': showMoveList,
        'confirmResign': confirmResign,
        'allowTakebacks': allowTakebacks,
        'defaultTimeControlLabel': defaultTimeControlLabel,
        'defaultComputerLevel': defaultComputerLevel,
        'preferBlack': preferBlack,
        'showRatingChanges': showRatingChanges,
        'richPresence': richPresence,
        'notifyChallenges': notifyChallenges,
        'notifyFriendRequests': notifyFriendRequests,
        'notifyGameStart': notifyGameStart,
        'notifyDailyPuzzle': notifyDailyPuzzle,
      };

  factory ChessSettings.fromJson(Map<String, dynamic> json) {
    final d = ChessSettings();
    return d.copyWith(
      boardThemeId: json['boardThemeId'] as String?,
      pieceThemeId: json['pieceThemeId'] as String?,
      showCoordinates: json['showCoordinates'] as bool?,
      showLegalDots: json['showLegalDots'] as bool?,
      showLastMove: json['showLastMove'] as bool?,
      showCheckHighlight: json['showCheckHighlight'] as bool?,
      animateMoves: json['animateMoves'] as bool?,
      moveAnimationMs: (json['moveAnimationMs'] as num?)?.toInt(),
      flipBoardWithColor: json['flipBoardWithColor'] as bool?,
      autoQueen: json['autoQueen'] as bool?,
      confirmMoves: json['confirmMoves'] as bool?,
      playSounds: json['playSounds'] as bool?,
      soundVolume: (json['soundVolume'] as num?)?.toDouble(),
      pieceSoundTheme: json['pieceSoundTheme'] as String?,
      showEvalBar: json['showEvalBar'] as bool?,
      showMoveList: json['showMoveList'] as bool?,
      confirmResign: json['confirmResign'] as bool?,
      allowTakebacks: json['allowTakebacks'] as bool?,
      defaultTimeControlLabel: json['defaultTimeControlLabel'] as String?,
      defaultComputerLevel: (json['defaultComputerLevel'] as num?)?.toInt(),
      preferBlack: json['preferBlack'] as bool?,
      showRatingChanges: json['showRatingChanges'] as bool?,
      richPresence: json['richPresence'] as bool?,
      notifyChallenges: json['notifyChallenges'] as bool?,
      notifyFriendRequests: json['notifyFriendRequests'] as bool?,
      notifyGameStart: json['notifyGameStart'] as bool?,
      notifyDailyPuzzle: json['notifyDailyPuzzle'] as bool?,
    );
  }
}

/// Loads/saves [ChessSettings] and exposes a synchronous in-memory copy so
/// widgets can read preferences without awaiting.
class ChessSettingsService {
  ChessSettingsService._();

  static final ChessSettingsService instance = ChessSettingsService._();

  static const _key = 'chess_settings_v1';

  ChessSettings _settings = ChessSettings();

  ChessSettings get settings => _settings;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _settings = ChessSettings.fromJson(decoded);
      }
    } catch (_) {
      // Corrupt settings fall back to defaults rather than blocking startup.
      _settings = ChessSettings();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_settings.toJson()));
  }

  /// Convenience: replace the current settings and persist.
  Future<void> update(ChessSettings next) async {
    _settings = next;
    await save();
  }

  Future<void> reset() async {
    _settings = ChessSettings();
    await save();
  }
}
