import 'package:flutter/material.dart';

/// Original visual identity for the chess platform.
///
/// A near-black surface system with a warm red accent, matching Bluff's
/// identity. Nothing here derives from any other product's artwork, logo or
/// trade dress — only ordinary dark-UI conventions.
abstract final class ChessPalette {
  static const background = Color(0xFF0A0A10);
  static const surface = Color(0xFF14141D);
  static const surfaceAlt = Color(0xFF1B1B27);
  static const surfaceHigh = Color(0xFF252534);

  static const border = Color(0x14FFFFFF); // 8% white
  static const borderStrong = Color(0x29FFFFFF); // 16% white

  static const accent = Color(0xFFC62828);
  static const accentSoft = Color(0x2EC62828);

  static const text = Color(0xFFFFFFFF);
  static const textDim = Color(0xB3FFFFFF); // 70%
  static const textFaint = Color(0x7AFFFFFF); // 48%

  static const success = Color(0xFF43A047);
  static const warning = Color(0xFFF9A825);
  static const danger = Color(0xFFE53935);
  static const gold = Color(0xFFFFD166);

  static const lightSquare = Color(0xFFEFE0C8);
  static const darkSquare = Color(0xFF9B6A4B);

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(9));
}

/// Text styles used across the chess screens.
abstract final class ChessText {
  static const display = TextStyle(
    color: ChessPalette.text,
    fontSize: 26,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.4,
  );

  static const title = TextStyle(
    color: ChessPalette.text,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
  );

  static const body = TextStyle(
    color: ChessPalette.text,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const dim = TextStyle(
    color: ChessPalette.textDim,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const caption = TextStyle(
    color: ChessPalette.textFaint,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const label = TextStyle(
    color: ChessPalette.textDim,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
  );

  /// Tabular figures for clocks and evals so digits don't dance.
  static const mono = TextStyle(
    color: ChessPalette.text,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// A raised surface used for panels and rows.
class ChessCard extends StatelessWidget {
  const ChessCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = ChessPalette.surface,
    this.border,
    this.onTap,
    this.radius = ChessPalette.cardRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final BoxBorder? border;
  final VoidCallback? onTap;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: border ?? Border.all(color: ChessPalette.border),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return decorated;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: decorated,
      ),
    );
  }
}

/// Primary call-to-action button.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
    this.danger = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final bool danger;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bg = danger ? ChessPalette.danger : ChessPalette.accent;
    final enabled = onPressed != null && !busy;

    final child = busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          );

    final button = Material(
      color: enabled ? bg : bg.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: child,
        ),
      ),
    );

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// Secondary (outline) button.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
    this.danger = false,
    this.selected = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final bool danger;
  final bool selected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final fg = danger
        ? ChessPalette.danger
        : selected
            ? ChessPalette.text
            : ChessPalette.textDim;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 7),
        ],
        Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: dense ? 12.5 : 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    final button = Material(
      color: selected
          ? ChessPalette.accentSoft
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 12 : 16,
            vertical: dense ? 8 : 11,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? ChessPalette.accent.withValues(alpha: 0.7)
                  : ChessPalette.borderStrong,
            ),
          ),
          child: content,
        ),
      ),
    );

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// Uppercase section heading with the signature accent tick.
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: ChessPalette.accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: ChessText.label.copyWith(
                    color: ChessPalette.text,
                    fontSize: 12.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: ChessText.caption),
                ],
              ],
            ),
          ),
          if (trailing != null) ?trailing,
        ],
      ),
    );
  }
}

/// Small rounded pill used for tags, ratings and ECO codes.
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.label,
    this.icon,
    this.color = ChessPalette.surfaceHigh,
    this.textColor,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final Color? textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: ChessPalette.chipRadius,
        border: Border.all(color: ChessPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.5, color: textColor ?? ChessPalette.textDim),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor ?? ChessPalette.textDim,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return InkWell(onTap: onTap, borderRadius: ChessPalette.chipRadius, child: chip);
  }
}
