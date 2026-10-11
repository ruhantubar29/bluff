import 'package:flutter/material.dart';

import '../core/models/time_control.dart';
import 'chess_theme.dart';

/// One section of the shared clock menu (e.g. BULLET).
class TimeControlGroup {
  const TimeControlGroup(this.title, this.controls);

  final String title;
  final List<TimeControl> controls;
}

/// The full clock menu from the spec: no timer, bullet, blitz, rapid — plus
/// a long classical control. Shared by bot setup and pass & play so both
/// flows offer the same options.
const List<TimeControlGroup> timeControlGroups = [
  TimeControlGroup('NO TIMER', [TimeControl.unlimited]),
  TimeControlGroup('BULLET', [
    TimeControl(
      initial: Duration(minutes: 1),
      increment: Duration.zero,
      category: TimeCategory.bullet,
      label: '1 + 0',
    ),
    TimeControl(
      initial: Duration(minutes: 1),
      increment: Duration(seconds: 1),
      category: TimeCategory.bullet,
      label: '1 + 1',
    ),
    TimeControl(
      initial: Duration(minutes: 2),
      increment: Duration(seconds: 1),
      category: TimeCategory.bullet,
      label: '2 + 1',
    ),
  ]),
  TimeControlGroup('BLITZ', [
    TimeControl(
      initial: Duration(minutes: 3),
      increment: Duration(seconds: 2),
      category: TimeCategory.blitz,
      label: '3 + 2',
    ),
    TimeControl(
      initial: Duration(minutes: 5),
      increment: Duration.zero,
      category: TimeCategory.blitz,
      label: '5 + 0',
    ),
    TimeControl(
      initial: Duration(minutes: 5),
      increment: Duration(seconds: 5),
      category: TimeCategory.blitz,
      label: '5 + 5',
    ),
  ]),
  TimeControlGroup('RAPID', [
    TimeControl(
      initial: Duration(minutes: 10),
      increment: Duration.zero,
      category: TimeCategory.rapid,
      label: '10 + 0',
    ),
    TimeControl(
      initial: Duration(minutes: 10),
      increment: Duration(seconds: 5),
      category: TimeCategory.rapid,
      label: '10 + 5',
    ),
    TimeControl(
      initial: Duration(minutes: 15),
      increment: Duration(seconds: 10),
      category: TimeCategory.rapid,
      label: '15 + 10',
    ),
    TimeControl(
      initial: Duration(minutes: 20),
      increment: Duration.zero,
      category: TimeCategory.rapid,
      label: '20 + 0',
    ),
    TimeControl(
      initial: Duration(minutes: 30),
      increment: Duration.zero,
      category: TimeCategory.rapid,
      label: '30 + 0',
    ),
  ]),
  TimeControlGroup('CLASSICAL', [
    TimeControl(
      initial: Duration(minutes: 70),
      increment: Duration.zero,
      category: TimeCategory.classical,
      label: '70 + 0',
    ),
  ]),
];

/// 'No timer' for the unlimited control, its label otherwise.
String timeControlLabel(TimeControl tc) =>
    tc == TimeControl.unlimited ? 'No timer' : tc.displayLabel;

/// The Options end-drawer: a scrollable, grouped clock menu. Picking a tile
/// fires [onSelected] and closes the drawer.
class TimeControlDrawer extends StatelessWidget {
  const TimeControlDrawer({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final TimeControl selected;
  final ValueChanged<TimeControl> onSelected;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: ChessPalette.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'TIME CONTROL',
                    style: ChessText.label.copyWith(
                      color: ChessPalette.text,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: ChessPalette.textDim,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final group in timeControlGroups) ...[
              const SizedBox(height: 14),
              Text(
                group.title,
                style: ChessText.caption.copyWith(
                  color: ChessPalette.textFaint,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              for (final tc in group.controls) _tile(context, tc),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- tiles --

  Widget _tile(BuildContext context, TimeControl tc) {
    final isSelected = tc == selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          onSelected(tc);
          Navigator.of(context).pop(); // close the drawer
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? ChessPalette.accentSoft
                : ChessPalette.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? ChessPalette.accent
                  : ChessPalette.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeControlLabel(tc),
                      style: ChessText.body.copyWith(
                        color: isSelected
                            ? ChessPalette.text
                            : ChessPalette.textDim,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(tc.categoryName, style: ChessText.caption),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: ChessPalette.accent,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
