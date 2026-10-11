# Bluff Chess Platform

A full chess platform inside Bluff: local-first, honest about what it can and
cannot do, and structured so a backend slots in later without touching screens.

## What lives where

```
lib/games/chess/
├── core/                 # Pure Dart, no Flutter — fully unit-tested
│   ├── board.dart        # Board representation, FEN, square helpers
│   ├── chess_game.dart   # Rules engine (legal moves, check/mate/stalemate)
│   ├── game_clock.dart   # Time controls, increment, flagging
│   ├── elo.dart          # Rating math (K-factor, provisional, expected score)
│   ├── chess_engine.dart # Built-in engine: alpha-beta + quiescence, iter deepening
│   ├── engine/           # Opening book (ECO names), engine levels
│   ├── models/           # Data classes: profiles, games, puzzles, friends…
│   ├── rating/           # RatingCategory helpers
│   └── data/             # Generated datasets (puzzle_data.dart — do not hand-edit)
├── state/
│   └── game_controller.dart  # Orchestrates a game: rules + clock + engine + moves
├── services/
│   ├── chess_storage.dart    # All persistence (SharedPreferences, JSON, keyed)
│   ├── session_service.dart  # Local accounts: PBKDF2 passwords, recovery codes
│   ├── settings_service.dart # Board/gameplay/notification settings
│   ├── sound_service.dart    # Synthesised move/capture/check/end sounds
│   ├── engine_runner.dart    # Engine in an isolate (UI never blocks)
│   ├── stockfish_runner.dart # Native Stockfish (UCI) behind an honest facade
│   ├── stockfish_platform*.dart # Real impl (Android/iOS) + stub, conditional
│   └── online_service.dart   # THE online seam (see below)
├── singleplayer/
│   ├── singleplayer_home.dart      # Chooser: Play with Bot / Solve Puzzles
│   ├── bot_setup_screen.dart       # Bots, side, Options drawer, Elo slider
│   └── puzzle_adventure_screen.dart # Stair level map, cloud-hidden top levels
├── pass_and_play/
│   └── pass_and_play_setup_screen.dart # Player names + clock → straight to board
├── multiplayer/
│   └── online_lobby_screen.dart    # Honest online lobby (queue when backend live)
├── widgets/
│   ├── board/            # ChessBoardView (drag+click, highlights, promotion)
│   ├── chess_theme.dart  # Palette, text styles, cards, buttons, chips
│   ├── time_control_picker.dart # Shared Options drawer (no timer → classical)
│   └── …                 # eval bar, player bar, move list, piece/board themes
└── screens/              # Hub (persistent nav), Play, Puzzles, History,
                          # Profile, Auth, Friends, Leaderboard, Game, Replay
```

Entry points (each Bluff screen opens its own dedicated flow):

| Bluff screen | Opens | Then |
|---|---|---|
| `singleplayer/` | `SingleplayerHome` | Bot setup (6 named opponents, side, Options clock menu, Stockfish/Elo 250–3200) or the puzzle tower (24 levels, clouds hide the top) |
| `pass_and_play/` | `PassAndPlaySetupScreen` | Names + clock → straight to the board |
| `multiplayer/` | `OnlineLobbyScreen` | Quick match (gated on `isAvailable`), friends, local leaderboard |

`ChessHub` stays reachable from every flow (profile/history icon), keeping
settings, analysis, openings and game review one tap away.

## Engines

Two engines, one interface (`GameController` picks per move):

- **Stockfish** (`services/stockfish_runner.dart`) — native UCI via
  `package:stockfish` (bundles Android/iOS binaries). `UCI_LimitStrength` +
  `UCI_Elo` clamp to the supported 1350–3190 band. Reached through a
  conditional import, so web/desktop builds never touch FFI. The package is
  **vendored at `packages/stockfish`** (a path dependency): the published
  1.8.1 build script still calls `jcenter()` and pins AGP 3.5, which breaks
  `flutter build apk` on Gradle 9/AGP 9. Only its `android/build.gradle`
  (and the CMake minimum version) differ from upstream; Dart/iOS/native
  sources are untouched.
- **Built-in Dart engine** — alpha-beta in an isolate; `EngineSearchRequest.fromElo`
  maps any slider value (250–3200) to depth/noise/blunder knobs.

A null from Stockfish (unsupported platform, failed start) always falls back
to the built-in engine — the game never freezes and never lies about who
played.

## Local-first policy

Every screen is fully functional on-device: play, puzzles, history, ratings,
friends roster, leaderboard, analysis and review all read from
`ChessStorage`. Nothing in the UI pretends to be online.

## The online seam

`services/online_service.dart` defines `OnlineService`: matchmaking, live
games (server-authoritative events), presence, challenges and leaderboards.

- The default `StubOnlineService` reports `isAvailable == false` and throws
  `OnlineUnavailableException` on every operation — it never invents data.
- **This build installs no backend.** `lib/main.dart` deliberately leaves the
  stub in place, so nothing ever claims to be online: the multiplayer chess
  card, the lobby, and the friends and leaderboard screens all render their
  honest offline copy.
- All UI gates on `OnlineService.instance.isAvailable` first and listens to
  `phaseChanges`, so screens follow the connection as it comes and goes.
- `test/chess/online_service_test.dart` proves the contract with an
  in-memory fake.

### Bringing a backend back

Chess online ships without a server. A `ws://localhost:8080` endpoint is
meaningless on a user's device — it resolves to the phone itself — so the
previous bundled dev server has been removed rather than left as a trap.

When chess online actually launches, assign a real implementation once at
startup in `lib/main.dart`:

```dart
OnlineService.instance = YourBackendService();
```

Anything implementing `OnlineService` works, and the UI needs no changes:
every screen already gates on `isAvailable` and follows `phaseChanges`.

## Anti-cheat architecture

Designed for server authority the moment the backend exists:

- **Moves, not positions.** The client proposes UCI moves only; a backend
  re-validates them against its own rules engine and owns the canonical game
  state, clocks and result. A modified client can only slow itself down.
- **Server-owned ratings.** Local `Elo` math powers offline play (vs computer,
  puzzles); rated online outcomes must be computed server-side from the
  server's own game record.
- **Timing telemetry is unavoidable.** Move times and latency flow through the
  server channel, giving an engine-use signal no client change can hide.
- **Passwords never stored.** PBKDF2-HMAC-SHA256, 120k iterations, per-account
  salt; the one-time `BLUFF-XXXX-XXXX-XXXX` recovery code is stored only as a
  hash. Local-first, so nothing leaves the device today.
- **No phantom features.** Challenge, presence and leaderboard surfaces render
  the honest "server required" state instead of fake data whenever no backend
  is connected.

## Data model (storage keys, all JSON under `SharedPreferences`)

| Key | Entity |
| --- | --- |
| `chess_profiles_v1` | `PlayerProfile` — per-category `PlayerRating` (+history), `PuzzleStats` |
| `chess_current_profile_v1` | Signed-in profile id (`''` = guest) |
| `chess_games_v1` | `ChessGameRecord` — moves, result, time control, ids (cap 300) |
| `chess_friends_v1` / `chess_challenges_v1` | `ChessFriend`, `ChessChallenge` |
| `chess_puzzle_attempts_v1` / `chess_seen_puzzles_v1` | Attempts (cap 200), seen ids |
| `chess_accounts_v1` | Auth records (salt, PBKDF2 hash, recovery hash) |

## Tests

```
flutter analyze lib/games/chess test/chess tool
flutter test          # everything
flutter test test/chess/chess_game_test.dart
```

Coverage highlights: perft-validated rules (perft(4)=197281, kiwipete
perft(3)=97862), clock/flagging, Elo edge cases, generated puzzle dataset
replay validation (every solution plays legally), hub responsive layouts
(phone rail/bar, desktop rail), rating updates, auth flows, and the
`OnlineService` contract.
