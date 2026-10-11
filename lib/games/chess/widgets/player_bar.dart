import 'package:flutter/material.dart';

import '../core/board.dart';
import '../core/game_clock.dart';
import 'chess_theme.dart';

/// Player row above/below the board: identity, captured material and clock.
class PlayerBar extends StatelessWidget {
  const PlayerBar({
    super.key,
    required this.name,
    required this.isWhite,
    this.rating,
    this.captured = const [],
    this.advantage = 0,
    this.clock,
    this.clockActive = false,
    this.clockUrgent = false,
    this.clockCritical = false,
    this.thinking = false,
    this.onTap,
  });

  final String name;
  final bool isWhite;
  final int? rating;

  /// FEN letters of the pieces this player has captured (in capture order).
  final List<String> captured;

  /// Extra material in pawns (0 = level).
  final double advantage;

  /// Remaining time; null renders no clock (unlimited games).
  final Duration? clock;
  final bool clockActive;
  final bool clockUrgent;
  final bool clockCritical;
  final bool thinking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          _Avatar(isWhite: isWhite, name: name),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ChessPalette.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (rating != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '$rating',
                        style: ChessText.caption.copyWith(
                          color: ChessPalette.textFaint,
                        ),
                      ),
                    ],
                    if (thinking) ...[
                      const SizedBox(width: 8),
                      const _ThinkingDots(),
                    ],
                  ],
                ),
                if (captured.isNotEmpty || advantage >= 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        for (final letter in captured)
                          _CapturedPiece(fenLetter: letter),
                        if (advantage >= 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              '+${advantage.floor()}',
                              style: const TextStyle(
                                color: ChessPalette.success,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (clock != null) ...[
            const SizedBox(width: 8),
            _ClockChip(
              remaining: clock!,
              active: clockActive,
              urgent: clockUrgent,
              critical: clockCritical,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.isWhite, required this.name});

  final bool isWhite;
  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isWhite ? const Color(0xFFEDE7DA) : const Color(0xFF33333F),
        border: Border.all(color: ChessPalette.borderStrong),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: isWhite ? const Color(0xFF1A1A22) : ChessPalette.text,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CapturedPiece extends StatelessWidget {
  const _CapturedPiece({required this.fenLetter});

  final String fenLetter;

  @override
  Widget build(BuildContext context) {
    final type = pieceTypeFromLetter(fenLetter.toLowerCase());
    if (type == null) return const SizedBox.shrink();
    final isWhite = fenLetter == fenLetter.toUpperCase();
    return SizedBox(
      width: 13,
      child: Center(
        child: Text(
          type.glyph,
          style: TextStyle(
            fontSize: 13.5,
            height: 1,
            color: isWhite
                ? const Color(0xFFEDEDED)
                : const Color(0xFF8B8B9A),
          ),
        ),
      ),
    );
  }
}

class _ClockChip extends StatelessWidget {
  const _ClockChip({
    required this.remaining,
    required this.active,
    required this.urgent,
    required this.critical,
  });

  final Duration remaining;
  final bool active;
  final bool urgent;
  final bool critical;

  @override
  Widget build(BuildContext context) {
    final bg = !active
        ? ChessPalette.surface
        : critical
            ? ChessPalette.danger
            : urgent
                ? ChessPalette.warning
                : ChessPalette.surfaceHigh;

    final fg = active && critical
        ? Colors.white
        : active && urgent
            ? const Color(0xFF14141C)
            : active
                ? ChessPalette.text
                : ChessPalette.textFaint;

    return Container(
      constraints: const BoxConstraints(minWidth: 78),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: ChessPalette.chipRadius,
        border: Border.all(
          color: active
              ? Colors.white.withValues(alpha: 0.14)
              : ChessPalette.border,
        ),
      ),
      child: Text(
        GameClock.format(remaining, verbose: urgent),
        style: TextStyle(
          color: fg,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Three pulsing dots shown while the opponent (or engine) is thinking.
class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value - i * 0.2) % 1.0;
            final opacity = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
            return Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Opacity(
                opacity: (0.25 + opacity * 0.75).clamp(0.0, 1.0),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: ChessPalette.accent,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
