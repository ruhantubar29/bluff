import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/impostor_player.dart';
import '../models/impostor_round.dart';

const _paper = Color(0xFFFFF3DC);
const _ink = Color(0xFF1B1013);
const _marker = Color(0xFFFFD23F);
const _mint = Color(0xFF9BE28A);
const _sky = Color(0xFF7FD6FF);
const _pink = Color(0xFFFF8FB1);
const _lav = Color(0xFFC9A7FF);
const _orange = Color(0xFFFFA45C);
const _red = Color(0xFFD92F45);

const _artColors = [
  _sky,
  _pink,
  _mint,
  _lav,
  _orange,
];

class VoteScreen extends StatefulWidget {
  const VoteScreen({
    super.key,
    required this.round,
  });

  final ImpostorRound round;

  @override
  State<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends State<VoteScreen>
    with TickerProviderStateMixin {
  ImpostorRound get round => widget.round;

  bool get isRandomMode => round.randomImpostorCount;

  int get voterCount => round.players.length;

  int get requiredVotes => round.impostorIndexes.length;

  int get maximumSelectablePlayers => math.max(0, voterCount - 1);

  late final List<int> _votingOrder;

  int _voterPosition = 0;

  final Set<int> _selectedPlayers = {};

  /// Player index -> number of ballots that selected that player.
  final Map<int, int> _voteCounts = {};

  /// Voter index -> player indexes selected by that voter.
  ///
  /// An empty list means NONE in random mode.
  final Map<int, List<int>> _votesByVoter = {};

  /// Number of voters who selected NONE in random mode.
  int _noneVotes = 0;

  bool _showingPassScreen = false;
  bool _showingResult = false;

  List<int> _finalAccusation = [];

  bool _finalResultIsDraw = false;
  bool _playersWon = false;

  /// Points earned by each player during this vote.
  final Map<int, int> _roundScores = {};

  /// Score each player had before this round started.
  final Map<int, int> _startingScores = {};

  late final AnimationController _pageController;
  late final AnimationController _resultController;

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < round.players.length; i++) {
      _startingScores[i] = round.players[i].score;
    }

    _votingOrder =
        List<int>.generate(voterCount, (index) => index)
          ..shuffle(math.Random());

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _prepareNextVoter();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  int get currentVoterIndex =>
      _votingOrder[_voterPosition];

  String get currentVoterName =>
      round.players[currentVoterIndex].name;

  bool get isLastVoter =>
      _voterPosition == _votingOrder.length - 1;

  void _prepareNextVoter() {
    _selectedPlayers.clear();

    _pageController.forward(from: 0);

    if (mounted) {
      setState(() {
        _showingPassScreen = true;
      });
    }
  }

  void _startCurrentVote() {
    setState(() {
      _showingPassScreen = false;
      _selectedPlayers.clear();
    });

    _pageController.forward(from: 0);
  }

  void _togglePlayer(int playerIndex) {
    if (playerIndex == currentVoterIndex) {
      return;
    }

    if (_showingPassScreen || _showingResult) {
      return;
    }

    setState(() {
      if (_selectedPlayers.contains(playerIndex)) {
        _selectedPlayers.remove(playerIndex);
        return;
      }

      if (isRandomMode) {
        // Selecting a player automatically removes NONE.
        _selectedPlayers.add(playerIndex);
        return;
      }

      if (_selectedPlayers.length >= requiredVotes) {
        return;
      }

      _selectedPlayers.add(playerIndex);
    });
  }

  void _selectNone() {
    if (!isRandomMode ||
        _showingPassScreen ||
        _showingResult) {
      return;
    }

    setState(() {
      _selectedPlayers.clear();
    });
  }

  bool get hasSelectedNone =>
      isRandomMode && _selectedPlayers.isEmpty;

  bool get canSubmitVote {
    if (isRandomMode) {
      // NONE is a valid vote.
      return true;
    }

    return _selectedPlayers.length == requiredVotes;
  }

  void _submitVote() {
    if (!canSubmitVote ||
        _showingPassScreen ||
        _showingResult) {
      return;
    }

    final selected = _selectedPlayers.toList();

    // Store this individual voter's ballot.
    _votesByVoter[currentVoterIndex] = selected;

    if (isRandomMode && selected.isEmpty) {
      _noneVotes++;
    } else {
      for (final playerIndex in selected) {
        _voteCounts[playerIndex] =
            (_voteCounts[playerIndex] ?? 0) + 1;
      }
    }

    if (isLastVoter) {
      _showFinalResult();
      return;
    }

    _voterPosition++;

    _prepareNextVoter();
  }

  void _showFinalResult() {
    _calculateFinalResult();
    _calculateScores();

    setState(() {
      _showingResult = true;
      _showingPassScreen = false;
    });

    _resultController.forward(from: 0);
  }

  void _calculateFinalResult() {
    if (isRandomMode) {
      _calculateRandomResult();
    } else {
      _calculateFixedResult();
    }
  }

  void _calculateFixedResult() {
    final sorted = round.players.asMap().entries.toList()
      ..sort((a, b) {
        final aVotes = _voteCounts[a.key] ?? 0;
        final bVotes = _voteCounts[b.key] ?? 0;

        final comparison =
            bVotes.compareTo(aVotes);

        if (comparison != 0) {
          return comparison;
        }

        return a.key.compareTo(b.key);
      });

    _finalAccusation = sorted
        .take(requiredVotes)
        .map((entry) => entry.key)
        .toList();

    final actual =
        round.impostorIndexes.toSet();

    final accused =
        _finalAccusation.toSet();

    _playersWon =
        accused.length == actual.length &&
        accused.containsAll(actual);

    _finalResultIsDraw = false;
  }

  void _calculateRandomResult() {
    final majorityThreshold =
        voterCount ~/ 2 + 1;

    final majorityPlayers = <int>[];

    for (final entry in _voteCounts.entries) {
      if (entry.value >= majorityThreshold) {
        majorityPlayers.add(entry.key);
      }
    }

    majorityPlayers.sort((a, b) {
      final aVotes = _voteCounts[a] ?? 0;
      final bVotes = _voteCounts[b] ?? 0;

      final comparison =
          bVotes.compareTo(aVotes);

      if (comparison != 0) {
        return comparison;
      }

      return a.compareTo(b);
    });

    _finalAccusation = majorityPlayers;

    // NONE is treated as a candidate for 0 impostors.
    final noneHasMajority =
        _noneVotes >= majorityThreshold;

    if (majorityPlayers.isEmpty &&
        !noneHasMajority) {
      _finalResultIsDraw = true;
      _playersWon = false;
      return;
    }

    if (noneHasMajority) {
      _finalAccusation = [];
    }

    final actual =
        round.impostorIndexes.toSet();

    final accused =
        _finalAccusation.toSet();

    _playersWon =
        accused.length == actual.length &&
        accused.containsAll(actual);

    _finalResultIsDraw = false;
  }

  // ---------------------------------------------------------------------------
  // SCORE SYSTEM
  // ---------------------------------------------------------------------------

  void _calculateScores() {
    _roundScores.clear();

    for (int i = 0; i < voterCount; i++) {
      _roundScores[i] = 0;
    }

    final actualImpostors =
        round.impostorIndexes.toSet();

    /*
     * ZERO IMPOSTOR
     *
     * There are no actual impostors.
     *
     * NONE = +5
     * Choosing a player = -1 for every chosen player.
     */
    if (actualImpostors.isEmpty) {
      for (final entry in _votesByVoter.entries) {
        final voterIndex = entry.key;
        final votes = entry.value;

        if (votes.isEmpty) {
          _roundScores[voterIndex] =
              (_roundScores[voterIndex] ?? 0) + 5;
        } else {
          _roundScores[voterIndex] =
              (_roundScores[voterIndex] ?? 0) -
                  votes.length;
        }
      }

      _applyRoundScores();
      return;
    }

    /*
     * NORMAL IMPOSTOR GAME
     *
     * Non-impostors:
     *   +5 for each actual impostor they correctly accuse.
     *   -1 for each innocent player they accuse.
     *
     * Impostors:
     *   0 from their own voting choices.
     *
     * In addition:
     *   An impostor who escapes the final accusation gets +10.
     *
     *   If the final accusation contains an impostor through a
     *   tied result, that impostor receives +5 instead.
     */

    for (final entry in _votesByVoter.entries) {
      final voterIndex = entry.key;
      final votes = entry.value;

      if (actualImpostors.contains(voterIndex)) {
        // Impostors receive no points from their own vote.
        continue;
      }

      int score = 0;

      for (final targetIndex in votes) {
        if (actualImpostors.contains(targetIndex)) {
          score += 5;
        } else {
          score -= 1;
        }
      }

      _roundScores[voterIndex] =
          (_roundScores[voterIndex] ?? 0) + score;
    }

    /*
     * Add the impostor survival points.
     *
     * If an impostor is in the final accusation, they were caught.
     * Otherwise they escaped.
     */
    for (final impostorIndex in actualImpostors) {
      if (_finalAccusation.contains(impostorIndex)) {
        continue;
      }

      _roundScores[impostorIndex] =
          (_roundScores[impostorIndex] ?? 0) + 10;
    }

    /*
     * Tie handling.
     *
     * If an impostor shares the highest vote count with another
     * player at the accusation boundary, they receive +5 instead
     * of the normal +10 escape bonus.
     */
    final tiedImpostors =
        _findImpostorsCaughtByTie(actualImpostors);

    for (final impostorIndex in tiedImpostors) {
      _roundScores[impostorIndex] =
          (_roundScores[impostorIndex] ?? 0) + 5;
    }

    /*
     * Correct voters in a tied accusation still receive their
     * normal +5 for correctly selecting an impostor.
     *
     * No additional tie bonus is added to avoid double counting.
     */

    _applyRoundScores();
  }

  Set<int> _findImpostorsCaughtByTie(
    Set<int> actualImpostors,
  ) {
    final tiedImpostors = <int>{};

    if (requiredVotes <= 0) {
      return tiedImpostors;
    }

    final sorted = round.players.asMap().entries.toList()
      ..sort((a, b) {
        final aVotes = _voteCounts[a.key] ?? 0;
        final bVotes = _voteCounts[b.key] ?? 0;

        final comparison =
            bVotes.compareTo(aVotes);

        if (comparison != 0) {
          return comparison;
        }

        return a.key.compareTo(b.key);
      });

    if (sorted.isEmpty ||
        requiredVotes > sorted.length) {
      return tiedImpostors;
    }

    final boundaryVotes =
        _voteCounts[sorted[requiredVotes - 1].key] ?? 0;

    final boundaryIndexes = sorted
        .where(
          (entry) =>
              (_voteCounts[entry.key] ?? 0) ==
              boundaryVotes,
        )
        .map((entry) => entry.key)
        .toSet();

    /*
     * There is a tie at the cutoff when more candidates have the
     * boundary vote count than there are remaining accusation slots.
     */
    final beforeBoundary = sorted
        .take(requiredVotes - 1)
        .map((entry) => entry.key)
        .toSet();

    final boundaryTie =
        boundaryIndexes.length > 1 &&
        boundaryIndexes.any(
          actualImpostors.contains,
        ) &&
        boundaryIndexes.any(
          (index) =>
              !beforeBoundary.contains(index),
        );

    if (!boundaryTie) {
      return tiedImpostors;
    }

    for (final impostorIndex in actualImpostors) {
      if (boundaryIndexes.contains(impostorIndex)) {
        tiedImpostors.add(impostorIndex);
      }
    }

    /*
     * The impostor must have been selected as part of the final
     * accusation to be considered "caught by tie".
     */
    tiedImpostors.removeWhere(
      (index) => !_finalAccusation.contains(index),
    );

    /*
     * The normal +10 escape bonus was not added above for caught
     * impostors, so +5 here is their complete impostor bonus.
     */
    return tiedImpostors;
  }

  void _applyRoundScores() {
    /*
     * Scores are accumulated on the player objects and returned
     * to the parent screen.
     *
     * isAlive is deliberately untouched.
     */
    for (int i = 0; i < voterCount; i++) {
      final earned = _roundScores[i] ?? 0;

      if (earned == 0) {
        continue;
      }

      final player = round.players[i];

      round.players[i] = player.copyWith(
        score: player.score + earned,
      );
    }
  }

  int _displayScoreFor(int playerIndex) {
    return _roundScores[playerIndex] ?? 0;
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_showingResult) {
      return _buildResultScreen();
    }

    if (_showingPassScreen) {
      return _buildPassScreen();
    }

    return _buildVoteScreen();
  }

  // ---------------------------------------------------------------------------
  // PASS DEVICE SCREEN
  // ---------------------------------------------------------------------------

  Widget _buildPassScreen() {
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(
                painter: _DoodleBackgroundPainter(),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    final value =
                        Curves.easeOutBack.transform(
                      _pageController.value,
                    );

                    return Transform.scale(
                      scale: 0.92 + (value * 0.08),
                      child: Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SketchText(
                        text: 'PASS THE DEVICE',
                        size: 34,
                        rotation: -0.025,
                      ),
                      const SizedBox(height: 26),
                      _SketchBox(
                        fill: _marker,
                        radius: 26,
                        strokeWidth: 3,
                        seed: _voterPosition + 4,
                        shadow: const Offset(5, 6),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              _DoodleCircle(
                                size: 92,
                                fill: _artColors[
                                    _voterPosition %
                                        _artColors.length],
                                child: Text(
                                  '${_voterPosition + 1}',
                                  style: GoogleFonts.atma(
                                    color: _ink,
                                    fontSize: 48,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                currentVoterName,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.atma(
                                  color: _ink,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w700,
                                  height: 0.95,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'It is your turn to vote.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.atma(
                                  color: _ink.withValues(
                                    alpha: 0.72,
                                  ),
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      _SketchButton(
                        text: 'I AM READY',
                        fill: _mint,
                        onTap: _startCurrentVote,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${_voterPosition + 1} / $voterCount',
                        style: GoogleFonts.atma(
                          color: _ink.withValues(
                            alpha: 0.55,
                          ),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: _SmallDoodleLabel(
                text: 'VOTE',
                rotation: -0.05,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VOTE SCREEN
  // ---------------------------------------------------------------------------

  Widget _buildVoteScreen() {
    final players =
        List<int>.generate(voterCount, (index) => index);

    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(
                painter: _DoodleBackgroundPainter(),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    14,
                    18,
                    0,
                  ),
                  child: Row(
                    children: [
                      _BackButton(
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SketchText(
                          text: 'VOTE',
                          size: 34,
                          rotation: -0.018,
                        ),
                      ),
                      _ProgressBadge(
                        current: _voterPosition + 1,
                        total: voterCount,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                  ),
                  child: _buildInstruction(),
                ),
                const SizedBox(height: 10),

                if (isRandomMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      10,
                    ),
                    child: _NoneVoteCard(
                      selected: hasSelectedNone,
                      onTap: _selectNone,
                    ),
                  ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      2,
                      20,
                      14,
                    ),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final playerIndex = players[index];
                      final isSelf =
                          playerIndex == currentVoterIndex;

                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: 12,
                        ),
                        child: _VotePlayerCard(
                          name: round
                              .players[playerIndex]
                              .name,
                          number: index + 1,
                          selected:
                              _selectedPlayers.contains(
                            playerIndex,
                          ),
                          disabled: isSelf,
                          accent: _artColors[
                              index % _artColors.length],
                          onTap: isSelf
                              ? null
                              : () {
                                  _togglePlayer(
                                    playerIndex,
                                  );
                                },
                        ),
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    14,
                  ),
                  child: _SketchButton(
                    text: isRandomMode
                        ? (hasSelectedNone
                            ? 'VOTE NONE'
                            : 'SUBMIT VOTE')
                        : 'SUBMIT ${_selectedPlayers.length}/$requiredVotes',
                    fill: isRandomMode && hasSelectedNone
                        ? _lav
                        : _mint,
                    enabled: isRandomMode
                        ? true
                        : canSubmitVote,
                    onTap: _submitVote,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstruction() {
    if (isRandomMode) {
      return Column(
        children: [
          Text(
            'WHO DO YOU THINK ARE THE IMPOSTORS?',
            textAlign: TextAlign.center,
            style: GoogleFonts.atma(
              color: _ink,
              fontSize: 23,
              fontWeight: FontWeight.w700,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasSelectedNone
                ? 'NONE selected — tap a player to choose players.'
                : '${_selectedPlayers.length} selected • you may choose 1 to $maximumSelectablePlayers',
            textAlign: TextAlign.center,
            style: GoogleFonts.atma(
              color: _ink.withValues(alpha: 0.62),
              fontSize: 17,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Text(
          'SELECT EXACTLY $requiredVotes',
          textAlign: TextAlign.center,
          style: GoogleFonts.atma(
            color: _ink,
            fontSize: 27,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${_selectedPlayers.length} / $requiredVotes selected',
          style: GoogleFonts.atma(
            color: _ink.withValues(alpha: 0.62),
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // RESULT
  // ---------------------------------------------------------------------------

  Widget _buildResultScreen() {
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(
                painter: _DoodleBackgroundPainter(),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  22,
                  28,
                  22,
                  30,
                ),
                child: AnimatedBuilder(
                  animation: _resultController,
                  builder: (context, child) {
                    final scale =
                        Curves.easeOutBack.transform(
                      _resultController.value,
                    );

                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildResultHeader(),
                      const SizedBox(height: 24),
                      _buildVoteSummary(),
                      const SizedBox(height: 24),
                      _buildScoreSummary(),
                      const SizedBox(height: 24),
                      _buildActualImpostors(),
                      const SizedBox(height: 28),
                      _SketchButton(
                        text: 'FINISH',
                        fill: _marker,
                        onTap: _finishGame,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultHeader() {
    if (_finalResultIsDraw) {
      return Column(
        children: [
          _DoodleCircle(
            size: 94,
            fill: _marker,
            child: const Text(
              '=?',
              style: TextStyle(
                color: _ink,
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SketchText(
            text: 'DRAW!',
            size: 42,
            rotation: -0.025,
          ),
          const SizedBox(height: 4),
          Text(
            'Nobody reached a majority.',
            textAlign: TextAlign.center,
            style: GoogleFonts.atma(
              color: _ink.withValues(alpha: 0.68),
              fontSize: 21,
            ),
          ),
        ],
      );
    }

    final title =
        _playersWon ? 'PLAYERS WIN!' : 'IMPOSTORS WIN!';

    return Column(
      children: [
        _DoodleCircle(
          size: 96,
          fill: _playersWon ? _mint : _red,
          child: Icon(
            _playersWon
                ? Icons.check_rounded
                : Icons.close_rounded,
            color: _ink,
            size: 58,
          ),
        ),
        const SizedBox(height: 16),
        _SketchText(
          text: title,
          size: 38,
          rotation: _playersWon ? -0.018 : 0.018,
        ),
        const SizedBox(height: 4),
        Text(
          _buildResultSubtitle(),
          textAlign: TextAlign.center,
          style: GoogleFonts.atma(
            color: _ink.withValues(alpha: 0.68),
            fontSize: 20,
          ),
        ),
      ],
    );
  }

  String _buildResultSubtitle() {
    if (isRandomMode) {
      if (_finalAccusation.isEmpty) {
        return 'The final accusation was NONE.';
      }

      return 'The majority selected the players below.';
    }

    return 'The top $requiredVotes vote-getters were accused.';
  }

  Widget _buildVoteSummary() {
    final sorted = round.players.asMap().entries.toList()
      ..sort((a, b) {
        final aVotes = _voteCounts[a.key] ?? 0;
        final bVotes = _voteCounts[b.key] ?? 0;

        final comparison =
            bVotes.compareTo(aVotes);

        if (comparison != 0) {
          return comparison;
        }

        return a.key.compareTo(b.key);
      });

    return _SketchBox(
      fill: Colors.white,
      radius: 22,
      strokeWidth: 3,
      seed: 18,
      shadow: const Offset(4, 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          18,
          18,
          18,
          10,
        ),
        child: Column(
          children: [
            Text(
              'VOTE TALLY',
              style: GoogleFonts.atma(
                color: _ink,
                fontSize: 25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ...sorted.map(
              (entry) {
                final playerIndex = entry.key;
                final votes =
                    _voteCounts[playerIndex] ?? 0;
                final accused =
                    _finalAccusation.contains(
                  playerIndex,
                );

                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 8,
                  ),
                  child: _TallyRow(
                    number: entry.key + 1,
                    name:
                        round.players[playerIndex].name,
                    votes: votes,
                    highlighted: accused,
                    color: _artColors[
                        entry.key %
                            _artColors.length],
                  ),
                );
              },
            ),
            if (isRandomMode) ...[
              const SizedBox(height: 4),
              const Divider(
                color: _ink,
                thickness: 1.4,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'NONE',
                      style: GoogleFonts.atma(
                        color: _ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '$_noneVotes',
                    style: GoogleFonts.atma(
                      color: _ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SCORE SUMMARY
  // ---------------------------------------------------------------------------

  Widget _buildScoreSummary() {
    final sorted = round.players.asMap().entries.toList()
      ..sort((a, b) {
        final aScore = _displayScoreFor(a.key);
        final bScore = _displayScoreFor(b.key);

        final comparison =
            bScore.compareTo(aScore);

        if (comparison != 0) {
          return comparison;
        }

        return a.key.compareTo(b.key);
      });

    return _SketchBox(
      fill: _marker,
      radius: 22,
      strokeWidth: 3,
      seed: 27,
      shadow: const Offset(4, 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          18,
          18,
          18,
          12,
        ),
        child: Column(
          children: [
            Text(
              'POINTS',
              style: GoogleFonts.atma(
                color: _ink,
                fontSize: 25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'THIS ROUND',
              style: GoogleFonts.atma(
                color: _ink.withValues(alpha: 0.58),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...sorted.map(
              (entry) {
                final playerIndex = entry.key;
                final earned =
                    _displayScoreFor(playerIndex);

                final previous =
                    _startingScores[playerIndex] ??
                    0;

                final total =
                    round.players[playerIndex].score;

                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 8,
                  ),
                  child: _ScoreRow(
                    number: playerIndex + 1,
                    name:
                        round.players[playerIndex].name,
                    previous: previous,
                    earned: earned,
                    total: total,
                    color: _artColors[
                        playerIndex %
                            _artColors.length],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActualImpostors() {
    if (round.impostorIndexes.isEmpty) {
      return _SketchBox(
        fill: _mint,
        radius: 22,
        strokeWidth: 3,
        seed: 33,
        shadow: const Offset(4, 5),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Text(
                'THE TRUTH',
                style: GoogleFonts.atma(
                  color: _ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'THERE WERE NO IMPOSTORS',
                textAlign: TextAlign.center,
                style: GoogleFonts.atma(
                  color: _ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 0.95,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final names = round.impostorIndexes
        .map(
          (index) => round.players[index].name,
        )
        .toList();

    return _SketchBox(
      fill: _pink,
      radius: 22,
      strokeWidth: 3,
      seed: 37,
      shadow: const Offset(4, 5),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(
              'THE TRUTH',
              style: GoogleFonts.atma(
                color: _ink,
                fontSize: 23,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...names.asMap().entries.map(
              (entry) {
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 5,
                  ),
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.atma(
                      color: _ink,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _buildResultLabel() {
    if (_finalResultIsDraw) {
      return 'DRAW';
    }

    return _playersWon
        ? 'PLAYERS WIN'
        : 'IMPOSTORS WIN';
  }

  // ---------------------------------------------------------------------------
  // FINISH
  // ---------------------------------------------------------------------------

  void _finishGame() {
    /*
     * Return the same player objects containing their accumulated
     * scores.
     *
     * IMPORTANT:
     * No player's isAlive value is changed here.
     */
    Navigator.pop(context, round.players);
  }
}

// =============================================================================
// SCORE ROW
// =============================================================================

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.number,
    required this.name,
    required this.previous,
    required this.earned,
    required this.total,
    required this.color,
  });

  final int number;
  final String name;
  final int previous;
  final int earned;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final String earnedText;

    if (earned > 0) {
      earnedText = '+$earned';
    } else {
      earnedText = '$earned';
    }

    final Color earnedColor;

    if (earned > 0) {
      earnedColor = _mint;
    } else if (earned < 0) {
      earnedColor = _red;
    } else {
      earnedColor = _ink.withValues(alpha: 0.42);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          _DoodleCircle(
            size: 38,
            fill: color,
            child: Text(
              '$number',
              style: GoogleFonts.atma(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.atma(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Previous score
          Text(
            '$previous',
            style: GoogleFonts.atma(
              color: _ink.withValues(alpha: 0.48),
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(width: 5),

          // Points gained/lost this round
          Text(
            earnedText,
            style: GoogleFonts.atma(
              color: earnedColor,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(width: 5),

          // New total
          Text(
            '$total',
            style: GoogleFonts.atma(
              color: _ink,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PLAYER CARD
// =============================================================================

class _VotePlayerCard extends StatelessWidget {
  const _VotePlayerCard({
    required this.name,
    required this.number,
    required this.selected,
    required this.disabled,
    required this.accent,
    required this.onTap,
  });

  final String name;
  final int number;
  final bool selected;
  final bool disabled;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fill = disabled
        ? Colors.black.withValues(alpha: 0.08)
        : selected
            ? accent
            : Colors.white;

    final inkColor = disabled
        ? _ink.withValues(alpha: 0.32)
        : _ink;

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: _SketchBox(
        fill: fill,
        radius: 19,
        strokeWidth: selected ? 3.5 : 2.5,
        seed: number + 50,
        shadow: disabled
            ? Offset.zero
            : const Offset(3, 4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          child: Row(
            children: [
              _DoodleCircle(
                size: 46,
                fill: disabled
                    ? Colors.black.withValues(
                        alpha: 0.08,
                      )
                    : accent,
                child: Text(
                  '$number',
                  style: GoogleFonts.atma(
                    color: inkColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.atma(
                        color: inkColor,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (disabled)
                      Text(
                        'THAT\'S YOU',
                        style: GoogleFonts.atma(
                          color: _ink.withValues(
                            alpha: 0.42,
                          ),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _DoodleCheck(
                checked: selected,
                disabled: disabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// NONE CARD
// =============================================================================

class _NoneVoteCard extends StatelessWidget {
  const _NoneVoteCard({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SketchBox(
      fill: selected
          ? _lav
          : Colors.white,
      radius: 20,
      strokeWidth: selected ? 3.5 : 2.5,
      seed: 81,
      shadow: selected
          ? const Offset(4, 4)
          : const Offset(2, 3),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        child: Row(
          children: [
            _DoodleCircle(
              size: 46,
              fill: _marker,
              child: Text(
                '0',
                style: GoogleFonts.atma(
                  color: _ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'NONE',
                    style: GoogleFonts.atma(
                      color: _ink,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'I think there are no impostors.',
                    style: GoogleFonts.atma(
                      color: _ink.withValues(
                        alpha: 0.62,
                      ),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            _DoodleCheck(
              checked: selected,
              disabled: false,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TALLY
// =============================================================================

class _TallyRow extends StatelessWidget {
  const _TallyRow({
    required this.number,
    required this.name,
    required this.votes,
    required this.highlighted,
    required this.color,
  });

  final int number;
  final String name;
  final int votes;
  final bool highlighted;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: highlighted
            ? color.withValues(alpha: 0.55)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$number',
              style: GoogleFonts.atma(
                color: _ink.withValues(alpha: 0.55),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.atma(
                color: _ink,
                fontSize: 21,
                fontWeight: highlighted
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$votes',
            style: GoogleFonts.atma(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SKETCH BUTTON
// =============================================================================

class _SketchButton extends StatelessWidget {
  const _SketchButton({
    required this.text,
    required this.fill,
    required this.onTap,
    this.enabled = true,
  });

  final String text;
  final Color fill;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _SketchBox(
      fill: enabled
          ? fill
          : Colors.black.withValues(alpha: 0.10),
      radius: 18,
      strokeWidth: 3,
      seed: 91,
      shadow: enabled
          ? const Offset(4, 5)
          : Offset.zero,
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.atma(
              color: enabled
                  ? _ink
                  : _ink.withValues(alpha: 0.35),
              fontSize: 23,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SKETCH BOX
// =============================================================================

class _SketchBox extends StatelessWidget {
  const _SketchBox({
    required this.fill,
    required this.radius,
    required this.strokeWidth,
    required this.seed,
    required this.shadow,
    required this.child,
    this.onTap,
  });

  final Color fill;
  final double radius;
  final double strokeWidth;
  final int seed;
  final Offset shadow;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = CustomPaint(
      painter: _SketchBoxPainter(
        fill: fill,
        radius: radius,
        strokeWidth: strokeWidth,
        seed: seed,
        shadow: shadow,
      ),
      child: child,
    );

    if (onTap == null) {
      return content;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

// =============================================================================
// DOODLE CIRCLE
// =============================================================================

class _DoodleCircle extends StatelessWidget {
  const _DoodleCircle({
    required this.size,
    required this.fill,
    required this.child,
  });

  final double size;
  final Color fill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DoodleCirclePainter(
          fill: fill,
        ),
        child: Center(
          child: child,
        ),
      ),
    );
  }
}

// =============================================================================
// CHECK
// =============================================================================

class _DoodleCheck extends StatelessWidget {
  const _DoodleCheck({
    required this.checked,
    required this.disabled,
  });

  final bool checked;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: CustomPaint(
        painter: _CheckPainter(
          checked: checked,
          disabled: disabled,
        ),
      ),
    );
  }
}

// =============================================================================
// TEXT
// =============================================================================

class _SketchText extends StatelessWidget {
  const _SketchText({
    required this.text,
    required this.size,
    required this.rotation,
  });

  final String text;
  final double size;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.atma(
          color: _ink,
          fontSize: size,
          fontWeight: FontWeight.w700,
          height: 0.9,
        ),
      ),
    );
  }
}

class _SmallDoodleLabel extends StatelessWidget {
  const _SmallDoodleLabel({
    required this.text,
    required this.rotation,
  });

  final String text;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: CustomPaint(
        painter: _LabelPainter(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 7,
          ),
          child: Text(
            text,
            style: GoogleFonts.atma(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// BACK BUTTON
// =============================================================================

class _BackButton extends StatelessWidget {
  const _BackButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _BackButtonPainter(),
        child: const SizedBox(
          width: 48,
          height: 44,
          child: Icon(
            Icons.arrow_back_rounded,
            color: _ink,
            size: 25,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PROGRESS
// =============================================================================

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({
    required this.current,
    required this.total,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.025,
      child: CustomPaint(
        painter: _BadgePainter(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 7,
          ),
          child: Text(
            '$current/$total',
            style: GoogleFonts.atma(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PAINTERS
// =============================================================================

class _SketchBoxPainter extends CustomPainter {
  _SketchBoxPainter({
    required this.fill,
    required this.radius,
    required this.strokeWidth,
    required this.seed,
    required this.shadow,
  });

  final Color fill;
  final double radius;
  final double strokeWidth;
  final int seed;
  final Offset shadow;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final random = math.Random(seed);

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        shadow.dx.abs(),
        shadow.dy.abs(),
        size.width -
            shadow.dx.abs() -
            1,
        size.height -
            shadow.dy.abs() -
            1,
      ),
      Radius.circular(radius),
    );

    if (shadow != Offset.zero) {
      final shadowPaint = Paint()
        ..color = _ink.withValues(alpha: 0.20)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        rect.shift(shadow),
        shadowPaint,
      );
    }

    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      rect,
      fillPaint,
    );

    final outline = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    final left = 1.0;
    final top = 1.0;
    final right = size.width - 1.0;
    final bottom = size.height - 1.0;

    path.moveTo(
      left + radius,
      top + random.nextDouble() * 1.5,
    );

    path.lineTo(
      right - radius,
      top + random.nextDouble() * 1.5,
    );

    path.quadraticBezierTo(
      right,
      top,
      right + random.nextDouble() * 0.8,
      top + radius,
    );

    path.lineTo(
      right + random.nextDouble() * 0.8,
      bottom - radius,
    );

    path.quadraticBezierTo(
      right,
      bottom,
      right - radius,
      bottom + random.nextDouble() * 0.8,
    );

    path.lineTo(
      left + radius,
      bottom + random.nextDouble() * 0.8,
    );

    path.quadraticBezierTo(
      left,
      bottom,
      left - random.nextDouble() * 0.8,
      bottom - radius,
    );

    path.lineTo(
      left + random.nextDouble() * 0.8,
      top + radius,
    );

    path.quadraticBezierTo(
      left,
      top,
      left + radius,
      top,
    );

    canvas.drawPath(
      path,
      outline,
    );

    final secondOutline = Paint()
      ..color = _ink.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;

    final innerRect = Rect.fromLTWH(
      3,
      3,
      size.width - 6,
      size.height - 6,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        innerRect,
        Radius.circular(radius - 3),
      ),
      secondOutline,
    );
  }

  @override
  bool shouldRepaint(
    covariant _SketchBoxPainter oldDelegate,
  ) {
    return oldDelegate.fill != fill ||
        oldDelegate.seed != seed ||
        oldDelegate.shadow != shadow;
  }
}

class _DoodleCirclePainter extends CustomPainter {
  _DoodleCirclePainter({
    required this.fill,
  });

  final Color fill;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center = size.center(Offset.zero);
    final radius =
        math.min(size.width, size.height) / 2 - 2;

    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      center,
      radius,
      fillPaint,
    );

    final outline = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    final path = Path();

    for (int i = 0; i <= 40; i++) {
      final angle =
          (math.pi * 2 * i) / 40;

      final wobble =
          math.sin(i * 1.7) * 1.2;

      final r = radius + wobble;

      final point = Offset(
        center.dx +
            math.cos(angle) * r,
        center.dy +
            math.sin(angle) * r,
      );

      if (i == 0) {
        path.moveTo(
          point.dx,
          point.dy,
        );
      } else {
        path.lineTo(
          point.dx,
          point.dy,
        );
      }
    }

    canvas.drawPath(
      path,
      outline,
    );
  }

  @override
  bool shouldRepaint(
    covariant _DoodleCirclePainter oldDelegate,
  ) {
    return oldDelegate.fill != fill;
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({
    required this.checked,
    required this.disabled,
  });

  final bool checked;
  final bool disabled;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center = size.center(Offset.zero);
    final radius =
        math.min(size.width, size.height) / 2 - 2;

    final fill = Paint()
      ..color = disabled
          ? _ink.withValues(alpha: 0.08)
          : checked
              ? _ink
              : Colors.transparent
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      center,
      radius,
      fill,
    );

    final outline = Paint()
      ..color = disabled
          ? _ink.withValues(alpha: 0.25)
          : _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3;

    canvas.drawCircle(
      center,
      radius,
      outline,
    );

    if (checked && !disabled) {
      final check = Paint()
        ..color = _paper
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path()
        ..moveTo(
          size.width * 0.27,
          size.height * 0.52,
        )
        ..lineTo(
          size.width * 0.44,
          size.height * 0.69,
        )
        ..lineTo(
          size.width * 0.75,
          size.height * 0.33,
        );

      canvas.drawPath(
        path,
        check,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _CheckPainter oldDelegate,
  ) {
    return oldDelegate.checked != checked ||
        oldDelegate.disabled != disabled;
  }
}

class _DoodleBackgroundPainter
    extends CustomPainter {
  const _DoodleBackgroundPainter();

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = _ink.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(
        size.width * 0.06,
        size.height * 0.17,
      ),
      Offset(
        size.width * 0.22,
        size.height * 0.13,
      ),
      paint,
    );

    canvas.drawLine(
      Offset(
        size.width * 0.78,
        size.height * 0.11,
      ),
      Offset(
        size.width * 0.93,
        size.height * 0.16,
      ),
      paint,
    );

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(
          size.width * 0.90,
          size.height * 0.78,
        ),
        radius: 30,
      ),
      0.3,
      2.1,
      false,
      paint,
    );

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(
          size.width * 0.09,
          size.height * 0.72,
        ),
        radius: 23,
      ),
      -0.4,
      2.2,
      false,
      paint,
    );

    final dotPaint = Paint()
      ..color = _ink.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    for (final point in [
      Offset(
        size.width * 0.12,
        size.height * 0.27,
      ),
      Offset(
        size.width * 0.89,
        size.height * 0.28,
      ),
      Offset(
        size.width * 0.16,
        size.height * 0.86,
      ),
      Offset(
        size.width * 0.82,
        size.height * 0.90,
      ),
    ]) {
      canvas.drawCircle(
        point,
        2.5,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _DoodleBackgroundPainter oldDelegate,
  ) {
    return false;
  }
}

class _LabelPainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = _marker
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(2, 4)
      ..lineTo(
        size.width - 3,
        2,
      )
      ..lineTo(
        size.width - 1,
        size.height - 4,
      )
      ..lineTo(
        5,
        size.height - 1,
      )
      ..close();

    canvas.drawPath(
      path,
      paint,
    );

    final outline = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    canvas.drawPath(
      path,
      outline,
    );
  }

  @override
  bool shouldRepaint(
    covariant _LabelPainter oldDelegate,
  ) {
    return false;
  }
}

class _BadgePainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = _sky
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(2, 4)
      ..quadraticBezierTo(
        size.width / 2,
        0,
        size.width - 2,
        4,
      )
      ..lineTo(
        size.width - 3,
        size.height - 4,
      )
      ..quadraticBezierTo(
        size.width / 2,
        size.height,
        2,
        size.height - 4,
      )
      ..close();

    canvas.drawPath(
      path,
      paint,
    );

    final outline = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    canvas.drawPath(
      path,
      outline,
    );
  }

  @override
  bool shouldRepaint(
    covariant _BadgePainter oldDelegate,
  ) {
    return false;
  }
}

class _BackButtonPainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final outline = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        1,
        2,
        size.width - 4,
        size.height - 5,
      ),
      const Radius.circular(13),
    );

    canvas.drawRRect(
      rect,
      fill,
    );

    canvas.drawRRect(
      rect,
      outline,
    );
  }

  @override
  bool shouldRepaint(
    covariant _BackButtonPainter oldDelegate,
  ) {
    return false;
  }
}