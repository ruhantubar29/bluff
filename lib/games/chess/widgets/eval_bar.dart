import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chess_theme.dart';

/// Vertical evaluation bar.
///
/// Shows the engine's judgement of the position from White's point of view;
/// the white share of the bar tracks the winning probability so a winning
/// position always reads the same way regardless of magnitude.
class EvalBar extends StatelessWidget {
  const EvalBar({
    super.key,
    required this.scoreCp,
    this.isMate = false,
    this.mateInPly = 0,
    this.orientationWhite = true,
    this.width = 22,
    this.showLabel = true,
    this.labelSuffix = '',
  });

  /// Centipawns from White's perspective (+ = White better).
  final int scoreCp;

  /// True when the search found a forced mate.
  final bool isMate;

  /// Plies to mate (sign carried by [scoreCp]).
  final int mateInPly;

  /// Whether White sits at the bottom of the bar (matches board flip).
  final bool orientationWhite;

  final double width;
  final bool showLabel;

  /// Optional depth note shown under the number (e.g. "· 12").
  final String labelSuffix;

  /// White's winning probability in 0..1.
  static double winProbability(int cp) => 1 / (1 + math.exp(-cp / 400));

  String get label {
    if (isMate) {
      final n = mateInPly <= 0 ? 0 : ((mateInPly + 1) ~/ 2);
      return (scoreCp < 0 ? '-M' : 'M') + (n == 0 ? '?' : '$n');
    }
    final p = scoreCp / 100;
    if (p.abs() < 0.05) return '0.0';
    final text = p.abs().toStringAsFixed(1);
    return p > 0 ? '+$text' : '-$text';
  }

  @override
  Widget build(BuildContext context) {
    final whiteShare = isMate
        ? (scoreCp >= 0 ? 1.0 : 0.0)
        : winProbability(scoreCp).clamp(0.02, 0.98);

    final whiteAhead = scoreCp >= 0;
    final labelColor = whiteAhead ? const Color(0xFF101018) : Colors.white;
    final labelBg = whiteAhead ? Colors.white : const Color(0xFF101018);

    return Semantics(
      label: 'Evaluation $label',
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: const Color(0xFF101018),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: ChessPalette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Align(
              alignment: orientationWhite
                  ? Alignment.bottomCenter
                  : Alignment.topCenter,
              child: FractionallySizedBox(
                heightFactor: whiteShare,
                child: const ColoredBox(color: Color(0xFFF2ECE0)),
              ),
            ),
            if (showLabel)
              Align(
                alignment: orientationWhite
                    ? (whiteAhead ? Alignment.topCenter : Alignment.bottomCenter)
                    : (whiteAhead ? Alignment.bottomCenter : Alignment.topCenter),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: RotatedBox(
                    quarterTurns: orientationWhite ? 1 : -1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: labelBg.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact horizontal eval used on very narrow layouts.
class EvalPill extends StatelessWidget {
  const EvalPill({
    super.key,
    required this.scoreCp,
    this.isMate = false,
    this.mateInPly = 0,
  });

  final int scoreCp;
  final bool isMate;
  final int mateInPly;

  @override
  Widget build(BuildContext context) {
    final p = EvalBar.winProbability(scoreCp);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 7,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF101018),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: ChessPalette.border),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: p.clamp(0.02, 0.98),
              child: const SizedBox(
                height: double.infinity,
                child: ColoredBox(color: Color(0xFFF2ECE0)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isMate
              ? '${scoreCp < 0 ? '-M' : 'M'}'
                  '${mateInPly <= 0 ? '?' : (mateInPly + 1) ~/ 2}'
              : _format(scoreCp),
          style: const TextStyle(
            color: ChessPalette.text,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  String _format(int cp) {
    final p = cp / 100;
    if (p.abs() < 0.05) return '0.0';
    final t = p.abs().toStringAsFixed(1);
    return p > 0 ? '+$t' : '-$t';
  }
}
