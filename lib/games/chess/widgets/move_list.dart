import 'package:flutter/material.dart';

import '../core/models/move_record.dart';
import 'chess_theme.dart';

/// Scrollable move list with the opening label.
///
/// Rows are pairs of half-moves; the latest move stays visible by scrolling
/// itself into view. Tapping a move reports its ply index (used by the
/// analysis board and review).
class MoveListView extends StatefulWidget {
  const MoveListView({
    super.key,
    required this.moves,
    this.openingName,
    this.openingEco,
    this.onMoveTap,
    this.selectedIndex,
    this.emptyLabel = 'The moves will appear here.',
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    this.background,
    this.border,
    this.showOpening = true,
  });

  final List<MoveRecord> moves;
  final String? openingName;
  final String? openingEco;
  final ValueChanged<int>? onMoveTap;
  final int? selectedIndex;
  final String emptyLabel;
  final EdgeInsetsGeometry padding;
  final Color? background;
  final BoxBorder? border;
  final bool showOpening;

  @override
  State<MoveListView> createState() => MoveListViewState();
}

class MoveListViewState extends State<MoveListView> {
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant MoveListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.moves.length != oldWidget.moves.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTail());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToTail() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasHeader = widget.showOpening &&
        (widget.openingName != null || widget.moves.isNotEmpty);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.background ?? ChessPalette.surface,
        borderRadius: ChessPalette.cardRadius,
        border: widget.border ?? Border.all(color: ChessPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Row(
                children: [
                  if (widget.openingEco != null) ...[
                    InfoChip(label: widget.openingEco!),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      widget.openingName ?? 'Opening',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ChessPalette.textDim,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: widget.moves.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        widget.emptyLabel,
                        textAlign: TextAlign.center,
                        style: ChessText.caption.copyWith(height: 1.5),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: widget.padding,
                    itemCount: (widget.moves.length + 1) ~/ 2,
                    itemBuilder: (context, index) => _buildRow(index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(int pairIndex) {
    final whiteIndex = pairIndex * 2;
    final blackIndex = whiteIndex + 1;
    final hasWhite = whiteIndex < widget.moves.length;
    final hasBlack = blackIndex < widget.moves.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${pairIndex + 1}.',
              style: const TextStyle(
                color: ChessPalette.textFaint,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: hasWhite
                ? _MoveCell(
                    record: widget.moves[whiteIndex],
                    ply: whiteIndex,
                    selected: widget.selectedIndex == whiteIndex,
                    onTap: widget.onMoveTap,
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: hasBlack
                ? _MoveCell(
                    record: widget.moves[blackIndex],
                    ply: blackIndex,
                    selected: widget.selectedIndex == blackIndex,
                    onTap: widget.onMoveTap,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _MoveCell extends StatelessWidget {
  const _MoveCell({
    required this.record,
    required this.ply,
    required this.selected,
    required this.onTap,
  });

  final MoveRecord record;
  final int ply;
  final bool selected;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? ChessPalette.accent.withValues(alpha: 0.28)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        record.san,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          color: selected ? ChessPalette.text : ChessPalette.textDim,
          fontSize: 13.5,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );

    if (onTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap!(ply),
      child: child,
    );
  }
}
