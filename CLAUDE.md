# CLAUDE.md — Arrow Escape

Reference and working rules for Claude Code sessions on this repository. Everything here comes from reading the source as of 2026-10-06 (Flutter 3.47.5). Where something could not be determined, it says so. File paths are relative to the repo root.

---

## 1. Project overview

| Item | Value |
| --- | --- |
| App name | **Arrow Escape** (Android label; `AppStrings.appName`). iOS `CFBundleDisplayName` is still the template value `Arrowescapegame`. |
| Dart package | `arrowescapegame` (`pubspec.yaml`), version `1.0.0+7` |
| Android namespace / applicationId | `com.arrowescape.arrowescapegame` |
| iOS bundle id | `com.arrowescape.arrowescapegame` (deployment target iOS 13.0) |
| Dart SDK constraint | `^3.12.2` |
| Flutter used for this analysis | 3.47.5 stable (`.metadata` records template revision `84fc5cbb…`) |
| AGP | 8.11.1 (`android/settings.gradle.kts`) |
| Kotlin Gradle plugin | 2.2.20 |
| Gradle wrapper | 8.14 |
| Java / JVM target | 17 (app and all subprojects are forced to 17) |
| Google Services plugin | 4.5.0; Firebase BoM 34.19.0 (native Android only, see §9) |
| compileSdk / targetSdk / minSdk / NDK | Taken from the Flutter Gradle plugin (`flutter.compileSdkVersion` etc.); exact numbers are not pinned in this repo. Plugin subprojects are forced to compileSdk 36. |

**What the game is:** a portrait-only puzzle. A 20×20 grid is packed with "snake" arrows (bent orthogonal paths with one arrowhead). Tapping an arrow makes it slide out along its path and off the board, but only if the straight lane from its head to the board edge is empty. Tapping a blocked arrow costs a life. Clear every arrow to win.

### Dependencies (`pubspec.yaml`, versions from `pubspec.lock`)

| Package | Locked | Used for |
| --- | --- | --- |
| `get` | 4.7.3 | State management (Rx/Obx), DI (`Get.put/find`), routing (`GetMaterialApp`, named routes) |
| `hive`, `hive_flutter` | 2.2.3 / 1.1.0 | Local persistence (progress, settings, in-progress puzzles) |
| `confetti` | 0.7.0 | Level-complete confetti in `GameplayScreen` |
| `audioplayers` | 6.8.1 | Sound effects |
| `url_launcher` | 6.3.2 | Privacy policy link in Settings |
| `google_mobile_ads` | 5.3.1 | AdMob banner / interstitial / rewarded |
| `cupertino_icons` | 1.0.9 | Icons |
| dev: `build_runner`, `hive_generator` | 2.4.13 / 2.0.1 | Generate `*.g.dart` Hive adapters |
| dev: `flutter_lints` | 6.0.0 | Lints (`analysis_options.yaml`) |

There is **no** Dart Firebase package, RevenueCat, in-app-purchase package, Provider, Riverpod or Bloc.

### Architecture in one paragraph

GetX app with a modular layout: `modules/<feature>/` holds a screen plus its `GetxController`. The game core in `lib/game/` is plain Dart and has no Flutter widget dependencies, except `renderer/`. `GameEngine` owns the rules, `LevelSolver` checks solvability and gives hints, and `LevelGenerator` builds every level procedurally from a seed at runtime. App-wide services (storage, economy, audio, haptics, ads, analytics) are registered as permanent GetX singletons during the splash screen by `AppInitializationService`.

---

## 2. Source structure

```
lib/
  main.dart                      Entry: error filters, portrait lock, GetMaterialApp
  core/
    ads_config.dart              Re-export of modules/ads/config/ads_config.dart (compat shim)
    constants/app_constants.dart Gameplay tuning: grid size, lives, coins, costs, seeds, anim timings, Hive ids
    constants/app_colors.dart    Palette + per-theme colors
    constants/app_strings.dart   All user-facing strings (English only, no i18n)
    theme/app_theme.dart         Material 3 light ThemeData (default font; no custom fonts bundled)
  data/
    models/                      ArrowModel, ArrowDirection, ArrowState, LevelModel, Difficulty,
                                 PlayerProgress (+.g.dart), GameSettings (+.g.dart), ThemeModel,
                                 DailyChallenge, LevelResult
    repositories/
      level_repository.dart      Level cache + generation entry point + daily challenge
      progress_repository.dart   Stars/unlocks/themes/streak/tutorial writes
      theme_repository.dart      Static list of 5 themes
  game/
    config/puzzle_config.dart    Cell spacing / stroke / head size from screen width
    engine/game_engine.dart      Rules: tap, escape check, lives, undo, win, stars
    solver/level_solver.dart     DFS solver, canEscape, hint
    generator/
      level_generator.dart       Campaign generator (pattern + difficulty + quality gates + fallbacks)
      shape_template.dart        PatternType enum + PatternGenerator masks (+ legacy ShapeTemplate)
      shape_path_generator.dart  Grows arrow paths inside a mask (the real arrow builder)
      dependency_analyzer.dart   Metrics: occupancy, lengths, dependency depth, components
      dot_grid_generator.dart    LEGACY generator; only referenced by tests
    models/board_state.dart      Immutable solver state + occupancy map
    models/tap_result.dart       TapResult enum + SolveResult
    renderer/
      arrow_board_widget.dart    InteractiveViewer board, dot grid, tap hit-testing
      arrow_widget.dart          Per-arrow animation controllers (shake/escape/glow)
      arrow_painter.dart         CustomPainter: body, arrowhead, glow, trail; ArrowMotionPath
  modules/
    splash/        Splash + drives AppInitializationService
    home/          Home menu (Continue / Play / Daily / Themes / Settings)
    level_select/  Winding 100-node level map, world banners, progression animation
    gameplay/      GameplayScreen/Controller + dialogs (complete, game over, hint ad, tutorial)
    daily_challenge/
    themes/
    settings/
    ads/           AdsModule, IAdService, AdMobService, NoOpAdService, BannerAdWidget, AdsConfig
  routes/app_router.dart         Named routes
  services/                      storage, economy, audio, haptic, analytics, purchase (stub),
                                 app_initialization
  widgets/                       Shared UI: PrimaryButton, SecondaryButton, CoinBadge, HeartDisplay,
                                 DifficultyBadge, GameIconButton, LevelCard
test/                            12 test files (engine, solver, generators, storage, economy, widgets)
tool/generate_audio.dart         Writes synthetic tap/escape/blocked WAVs to assets/audio/ (not used by app)
assets/sounds/                   arrowsound.m4a (~20 KB), universfield-wrong-answer-beep-149895.mp3 (~36 KB)
assets/audio/                    Declared in pubspec; contains only .gitkeep
android/  ios/                   Platform projects (see §13)
linux/ macos/ windows/ web/      Flutter template folders; not configured for this game
```

Notable files outside `lib/`:

- `analysis_options.yaml`: `flutter_lints`, and excludes `build/` and all platform folders.
- `android/app/src/main/kotlin/.../MainActivity.kt`: registers a `com.arrowescape.arrowescapegame/device` MethodChannel (`sdkInt`). **Nothing in Dart calls it.**
- **Sensitive files (exist locally and are git-ignored; never read them into output or commit them):** `android/key.properties`, `android/app/upload-keystore.jks`, `android/app/google-services.json`. `android/local.properties` is also local-only.
- Stray JVM crash logs in `android/` (`hs_err_pid23928.log`, `replay_pid23928.log`) are local artifacts.

---

## 3. Game architecture

### Screens and navigation (`lib/routes/app_router.dart`)

| Route | Screen | Controller |
| --- | --- | --- |
| `/` (initial) | `SplashScreen` | none (calls `AppInitializationService.initialize`) |
| `/home` | `HomeScreen` | `HomeController` |
| `/level-select` | `LevelSelectScreen` | `LevelSelectController` |
| `/gameplay` | `GameplayScreen` | `GameplayController` |
| `/daily-challenge` | `DailyChallengeScreen` | `DailyChallengeController` |
| `/themes` | `ThemesScreen` | `ThemesController` |
| `/settings` | `SettingsScreen` | `SettingsController` |

`/gameplay` takes `Get.arguments` as either an `int` (campaign level) or a `LevelModel` (daily challenge). With no argument it loads level 1. Screens use `Get.put(Controller())` in `build`/`initState`. `GameplayScreen` deletes its controller in `dispose`.

### State management

GetX throughout: `Rx*` fields plus `Obx` widgets. Services extend `GetxService` and are registered `permanent: true`. Controllers are created per screen. There is also global static state: `LevelSelectController.justCompletedLevel` / `lastAnimatedLevel`, the `LevelRepository._cache`, and `LevelGenerator._recentSignatures`.

### Grid system and board dimensions

- **Every campaign and daily level uses a fixed 20×20 grid** (`AppConstants.fixedGridSize = 20`; each `_DifficultyParams.gridSize`).
- A cell is `(row, col)` as a Dart record; row 0 is the top and col 0 is the left.
- Rendering (`ArrowBoardWidget`): `PuzzleConfig.adaptive(screenWidth, overrideGridSize: 20)` gives `cellSpacing = clamp((usableWidth / 20) * 2, 36, 80)`. The board is `cellSpacing × 20` px square. It is drawn at that scene size inside an `InteractiveViewer` (pinch zoom 0.1×–10×, unbounded pan), then fitted to 90% of the available box once (`_initTransform`).
- Cell centre: `((col + 0.5) * cellSpacing, (row + 0.5) * cellSpacing)`.
- Stroke width `clamp(cellSpacing * 0.36, 10, 22)`; arrowhead size `clamp(stroke * 1.70, 18, 36)`. The same formulas appear in both `PuzzleConfig.adaptive` and `ArrowPainter.paint`; keep them in sync.
- A dot is drawn at every cell centre (`_DotGridPainter`).

### Gameplay systems

| System | Where | Behaviour |
| --- | --- | --- |
| Lives | `GameEngine`, `AppConstants.startingLives = maxLives = 4` | Each blocked tap costs 1 life. At 0 lives the game is over. The HUD shows `lives − 1` hearts (0–3), so 0 hearts is the "last chance" state. `LevelModel.maxMistakes` is set per difficulty but **never used**. |
| Moves | `GameEngine._moves` | +1 per valid escape |
| Undo | `GameEngine.undo`, 50-deep stack | Snapshot pushed before each *valid* tap. Undo restores arrows, lives, moves and mistakes, so it also refunds lives lost since that move. Free (`coinsUndoCost` unused). UI enables it when any arrow is removed. |
| Hint | `LevelSolver.hint` | Returns the first currently escapable arrow, highlighted for 2 s. Costs 1 hint. |
| Stars | `GameEngine.calculateStars` | 3 = 0 mistakes (`moveTarget` is always null); 2 = ≤ 2 mistakes; 1 = otherwise |
| Coins | `EconomyService` | +25 per level complete, +10 more for 3 stars (paid on **every** completion, including replays). Daily +50. "2× coins" rewarded ad adds the base amount again. Start 100. |
| Hints economy | `EconomyService`, `GameplayController._ensureStartingHints` | Start 3. Topped back up to 3 on app start and on every level load. `buyHint()` (10 coins) exists but nothing in the UI calls it. 0 hints → "Free Hint" button opens a rewarded ad dialog. |
| Themes | `ThemeRepository` | classic, ocean (free); forest 100, sunset 150, night 200 coins (`coinsRequired`; `AppConstants.*ThemeCost` duplicate these and are unused) |
| Daily challenge | `DailyChallengeController` | Seed = `year*10000 + month*100 + day`. Generated in `Isolate.run`. Streak +1 if yesterday was completed, otherwise reset to 1. |
| Saved in-progress games | `StorageService` saved_game box | Removed arrow ids, moves, mistakes, lives. Saved on every move, on app pause and on screen dispose. Restored on next load if 0 < removed < total. |
| Pause | none | There is no pause screen (`AppStrings.pause` is unused). Leaving the screen saves state. |
| Restart | `GameplayController.onReset` | Clears the saved game and reloads the level (lives back to 4) |
| Tutorial | `TutorialOverlay` | Shown whenever level 1 is opened. `hasSeenTutorial` is written but **never read**. |
| Haptics | `HapticService` | `lightTap` on blocked tap and ad reward; `heavyTap` on win. `mediumTap`/`selectionClick` unused. Respects settings. |

### Win / lose flow

- **Win:** the last arrow's escape timer finishes, then `_checkWin`. It clears the saved game, sets `isCompleting` (board pulse plus 3 coins flying to the HUD), does a heavy haptic, awards coins and calls `markLevelCompleted` (stars only go up; unlocks the next level). After 650 ms it sets `isComplete` and calls `showInterstitial()`. The screen then plays confetti and opens `LevelCompleteDialog` (Next Level / Replay / Home / 2× coins ad).
- **Lose:** after a blocked tap brings lives to 0, `isGameOver` is set after 350 ms, which opens `GameOverDialog` (watch ad to restore 4 lives / RESTART / MAIN MENU).

---

## 4. Arrow system

### Data model: `lib/data/models/arrow_model.dart`

- `id` (`a001`, `a002`, … after generation) and `points: List<(int row, int col)>` **ordered tail → head**. Equality and hashing use `id` only.
- `exitDirection`: an explicit `_exitDirection` if one was given, otherwise derived from the last segment (`points[n-2] → points[n-1]`). Generated arrows never pass an explicit direction, so **direction always comes from the path**. `direction` is a deprecated alias.
- `length = points.length` (cells). `turns` counts 90° bends. `hasValidPath` requires unique cells and each step to be one orthogonal cell.
- `state: ArrowState` is mutable: `normal`, `selected` (unused in the flow), `blocked`, `escaping`, `removed`. The engine replaces arrows through `copyWith` rather than mutating them.
- Legacy constructors (`straight`, `legacy`, `headRow/headCol/length/direction`) build straight arrows. They are kept for tests and old data.

`ArrowDirection` (`up/down/left/right`) provides `dRow/dCol`, `opposite`, `isHorizontal/isVertical`.

### Escape and blocking rules (`LevelSolver._canEscape`, used by both the engine and the solver)

1. The path must be valid, and every cell must be inside the grid.
2. The occupancy map is rebuilt from all remaining arrows. If any two arrows overlap, the board is invalid and nothing can escape.
3. Walk from `head + exitDirection` to the board edge. **Any cell owned by another arrow blocks the move.**
4. The rest of the body never needs a clear lane, because it follows the head along its own path and then out through the head's lane.

Removing an arrow never blocks another one, so the puzzle is monotone. Any order of currently escapable arrows eventually clears a solvable board. "Deadlock" can only exist as a generation-time property (a cycle of mutual blocking), and the solver rejects such boards.

### Tap detection (`ArrowBoardWidget`)

The `GestureDetector` sits outside the `InteractiveViewer`. `onTapUp` converts the tap with `_tc.toScene()`, takes `floor(x / cellSize)` / `floor(y / cellSize)`, and picks the first non-removed, non-escaping arrow whose `occupiedCells` contains that cell. A tap anywhere on the body counts; there is no tolerance outside the cell. `GameplayController.onArrowTap` ignores taps while an escape is animating, after completion or game over, or at 0 lives.

### Rendering (`arrow_widget.dart`, `arrow_painter.dart`)

- Each arrow is its own `ArrowWidget` with a full-board `Positioned.fill` `CustomPaint`. It has 3 `AnimationController`s: shake (250 ms), escape (400–500 ms by length, `arrowFlightDurationForLength`), and glow (900 ms, **always repeating**).
- `ArrowMotionPath.build` turns the cell centres into a `Path` with rounded corners (radius `0.10 × cell`, cubic Bézier arcs) and caches its `PathMetric`.
- Body: a polyline sampled densely along the metric (36–320 samples), stroked with round caps and joins in one colour. Colours: `theme.arrowColor` normal, `accentColor` escaping, `Colors.redAccent` blocked.
- Head: a filled triangle at `last point + 0.35 cell` in the head direction. The body line stops at `0.7 × headSize` behind the tip.
- Escape animation: the whole snake shifts along its path and then straight along the exit direction by `(pathLength + cell*(length+2)) * easeInQuad(t)`, fading out over the last 25%. A soft blurred trail is drawn behind the tail.
- Blocked: a small bump in the exit direction (+3.5 px / −1 px) and a red tint. The arrow returns to `normal` after ~300 ms.
- Hint: blurred glow stroke plus opacity pulsing between 0.3 and 1.0.

### Arrow lengths

Generator target tiers (`ShapePathGenerator._rangeFor`, in cells):

| Tier | Range |
| --- | --- |
| short | 4–7 |
| medium | 7–10 |
| long | 10–13 |
| veryLong | 13–16 |
| extraLong | 16–min(22, maxArrowLen) |

Tail absorption can then extend arrows up to `maxArrowLen = 45` cells. The quality gate rejects any arrow shorter than 3 cells.

**Note:** `DependencyAnalyzer` uses *different* buckets for its metrics (short ≤ 9, medium ≤ 15, long ≤ 24, veryLong ≤ 34, extraLong > 34). The names "long / very-long / extra-long" therefore mean different things in the generator and in the metrics and tests.

Rendering works for any length; escape duration is capped at 500 ms for arrows of 10 or more cells.

### Known limitations

- Blocking only checks the lane from the head; the body never "collides". That is the intended rule, but keep it in mind.
- Hit-testing is exact to the cell. With thin strokes, taps in the gap between parallel arrows land on whichever arrow owns that cell.
- Hint always picks the first available arrow in map order, not a "smart" one.

---

## 5. Level generation

- **There are no hand-made levels.** Every level is procedural and generated **at runtime on the device** (`LevelRepository.getLevel(n)`, cached in memory).
- Seed: `AppConstants.levelSeed(n) = n * 31337 + 42`. Per-attempt RNG: `Random(seed ^ (attempt * 0x9E3779B9) ^ (n * 31337))`. Fallback passes use `seed ^ (attempt * 0x7FFFFFED) ^ 0xBEEF` and `seed ^ (attempt * 0x12345678) ^ 0xFEED`.
- Campaign length: `AppConstants.totalLevels = 100` (map, unlocks). After level 100, "Next Level" still calls `loadLevel(101)`; nothing caps it.

### Pipeline: `LevelGenerator.generate(levelNumber, seed, [difficulty])`

1. **Difficulty**: an explicit argument, otherwise `selectDifficulty(n)`:

   | Levels | Difficulty | maxMistakes (unused) | minArrows | minBends | minDepth |
   | --- | --- | --- | --- | --- | --- |
   | 1–3 | easy | 5 | 30 | 0.4 | 1 |
   | 4–5 | normal | 4 | 38 | 0.5 | 2 |
   | 6–10 | hard | 3 | 46 | 0.6 | 3 |
   | 11–20 | expert | 2 | 54 | 0.7 | 4 |
   | 21+ | extreme | 1 | 62 | 0.8 | 5 |

   All tiers use grid 20, `targetDensity 0.98` and `maxArrowLen 45`. **This does not match** `AppConstants.easyLevelsStart…expertLevelsEnd` (1–20 / 21–50 / 51–80 / 81–100), the World 1–4 "Easy/Normal/Hard/Expert" banners on the level map, or the difficulties the tests pass explicitly. In production, 80 of the 100 levels are "EXTREME", and the HUD badge shows that.
2. **Pattern**: `getPatternForLevel(n)`. Levels 1–20 use a fixed list; after that, `PatternType.values[(n-1) % 25]`.
3. **Mask**: `PatternGenerator.generateMask`. For each cell, maps (row, col) to normalized (u, v) ∈ [-1, 1] with a random scale (0.95–1.0), optional 90° rotation and flips (except rotation-locked shapes), and tests the shape's inequality. If the mask is under 48% of the grid, a centred square is added. Only the largest connected component is kept.
4. **Paths**: `ShapePathGenerator.generatePaths`. Arrows are grown **in reverse escape order**:
   - Choose a head cell whose exit ray is currently empty. Heads that sit on earlier arrows' exit rays score higher, which creates dependencies; deeper contour cells also score higher.
   - Grow the body backward with serpentine preferences: turns +4.5, straight +2, more than 6 straight −8, following a contour +3, crossing exit rays +6.
   - Lengths come from tier requests (≈16% extraLong, 28% veryLong, 32% long, 18% medium, rest short), then a random fill loop.
   - Post-passes: tail absorption (never into the exit ray of an arrow that escapes earlier), gap filling (new arrows of 3 or more cells), and absorption again.
   - The list is reversed and ids are renamed `a001…`.
5. **Quality gate** `_passesQuality`: arrow count ≥ `max(12, min(minArrows, mask/5.5))`; occupancy floor ramps from 35% (level 1) to 75% (level 9+); every arrow ≥ 3 cells; no exit direction above 75% of arrows; average bends ≥ minBends; dependency depth ≥ minDepth; no empty pocket larger than `max(16, 15% of the mask)`.
6. **Solver**: `LevelSolver.solve`, a DFS with memoization on the remaining-id set. **It gives up after 3,000 visited states** (`AppConstants.solverMaxIterations = 100000` is unused).
7. **Anti-duplicate**: reject a candidate that is too similar to `_recentSignatures[n-1]`.
8. **Fallbacks**: 8 strict attempts, then relaxed (4), relaxed-2 (4), and emergency (4, solver only). Otherwise it returns `null`, and `LevelRepository._fallbackLevel` tries seeds `n*13` and `999` as easy and **force-unwraps with `!`**.

In debug builds every accepted level prints a metrics block (`Level number:` … `Random seed:`).

**Observed output** (from `test/level_generator_test.dart`, with the test's explicit difficulties): boards levels 81–100 have about **20–28 arrows**, 56–78% shape occupancy, longest arrow 17–26 cells, and dependency depth 4–8. Arrow counts are well below the strict `minArrows` (30–62), because the quality gate uses `min(minArrows, mask/5.5)`, and generation likely often reaches the relaxed/fallback passes (not instrumented).

### Determinism: important caveat

Generation is deterministic for a given (levelNumber, seed, difficulty) **only if `_recentSignatures[n-1]` is in the same state**. That static map is filled only when level n−1 was generated earlier in the same process. Cold-starting at level n (no n−1 generated) skips the anti-duplicate check, while playing n−1 first enables it. If the first passing candidate is "too similar", the two paths produce **different boards for the same level**. A saved in-progress game stores removed arrow *ids*, so restoring it onto a different board would remove the wrong arrows. Treat this as a known risk; do not make it worse.

### Daily challenge

`LevelRepository.getDailyChallenge(dateSeed)` calls `generate(levelNumber: 0, seed: dateSeed, difficulty: normal)`, with a fallback of `seed+1` as easy and `!`. `getPatternForLevel(0)` → `values[(-1) % 25]` = **always `swirl`**. It runs in `Isolate.run`, so the main-isolate cache is not filled.

### Preloading

`getLevel(n)` schedules a `Future.microtask` that **synchronously** generates n+1…n+3 on the UI isolate (not in an isolate). The splash screen also generates the player's current level synchronously.

### How to add levels

Raise `AppConstants.totalLevels`. The map, unlocks and seeds scale automatically, and `getPatternForLevel` cycles patterns beyond 20. **Never change** the seed formula, `getPatternForLevel` for existing level numbers, `selectDifficulty`, the RNG call order in the generators, or the tier tables without accepting that **every existing level changes** (and saved in-progress games break).

### How to change difficulty safely

- Prefer changing *new* level ranges only (for example, branch in `selectDifficulty` for `n > 100`).
- Any edit to `_params`, `_rangeFor`, `_tiersFor`, `_averageFor`, the scoring weights, or `PatternGenerator` changes existing boards.
- After any change, run `flutter test test/level_generator_test.dart test/solver_test.dart test/winding_path_levels_test.dart` and check level-generation time on a low-end device (generation is synchronous; see §14).

---

## 6. Shape / pattern system

Defined in `lib/game/generator/shape_template.dart`.

**`PatternType` (25 values, the ones actually used):** star, square, spiral, ring, diamond, starSquare, starRing, squareRing, diamondSpiral, interlocked, randomGeometric, extremeCombination, heart, butterfly, crown, cat, snake, hexagon, flower, cross, infinity, lightning, rocket, bow, swirl.

- From the list the task asked about: heart, star, cat, butterfly, rocket and crown **exist**. **Dog does not exist** as a pattern; it only appears in the unused `ShapeType` enum.
- `ShapeType` (22 values incl. dog, fish, house, tree, moon, gem, cloud, trophy…) and `ShapeTemplate` are **legacy**. `ShapeTemplate.generateMask` always returns a square, and only tests use it.
- Several patterns produce very similar silhouettes. `diamondSpiral` is just a diamond, `interlocked` is a clipped diamond, and `extremeCombination` ≈ `squareRing`.

**Levels 1–20 sequence:** square, heart, star, diamond, cat, ring, butterfly, diamond, randomGeometric, cross, squareRing, starSquare, rocket, interlocked, crown, ring, butterfly, diamond, crown, hexagon. Levels 21+ cycle through `PatternType.values` in declaration order, starting at index 20 (`infinity`).

**Representation:** each pattern is an implicit inequality in `_isInsidePattern(u, v, …)`, using polar (r, θ) where useful. It produces a `Set<(row, col)>` mask. The mask only limits where arrows may be *placed*; the grid is always the full 20×20, exit lanes run to the real grid edge, and cells outside the mask stay empty. Rotation and flip are disabled for `_rotationLocked` shapes (heart, cat, crown, rocket, butterfly, lightning, infinity, bow, snake, flower, swirl).

**How to add a new pattern**

1. **Append** the new value to the *end* of `PatternType`. Inserting it in the middle shifts `values[(n-1) % length]` and changes every level ≥ 21. Appending still changes `length`, which shifts the cycle for levels ≥ 21. To leave existing levels untouched, also special-case new level numbers in `getPatternForLevel` rather than relying on the modulo.
2. Add its `case` to `_isInsidePattern` (the switch is exhaustive).
3. Add it to `_rotationLocked` if it is not symmetric.
4. Assign it to level numbers in `getPatternForLevel`.
5. Make sure the mask passes the quality gate (≥ 48% of cells, or the square fallback kicks in) and run the generator tests.

---

## 7. UI / UX

- **Orientation:** portrait only (`SystemChrome` in `main.dart` and `android:screenOrientation="portrait"`). On iOS, `Info.plist` still lists template orientations, but the Dart lock applies.
- **Theme:** `AppTheme.lightTheme` (Material 3, light only, default font). There are **no bundled or Google fonts**; `main.dart` still filters "Failed to load font" errors, probably left over from earlier code. Colours live in `AppColors`.
- **Game themes:** 5 `ThemeModel`s that change the gameplay background gradient, arrow colour, accent and text colour. Menu screens keep the light palette.
- **Splash:** an animated arrow and a progress bar driven by `InitializationProgress` (storage 15% → progress 35% → audio 55% → ads 70% → level 88% → done). On error it shows "Unable to initialize game". On success it calls `Get.offNamed('/home')`.
- **Home:** coins, Settings and Themes buttons, hero illustration, a "Continue Level N" card (when progress exists), Play (→ level map), Daily Challenge banner, an "Achievements" item that **does nothing** (`onTap: () {}`), and a banner ad.
- **Level select:** a vertical winding map of 100 nodes (96 px per row), boss nodes at multiples of 10, challenge nodes at multiples of 5, world banners at 1/21/51/81, an animated progression after completing a level, and an auto-scroll to the current level.
- **Gameplay:** top bar (back, "Level N", settings), HUD (coins, difficulty badge, hearts), the board (pinch and pan), a bottom bar (Hint/Free Hint, moves, Undo), and a banner ad. The tutorial overlay shows on level 1.
- **Dialogs:** `LevelCompleteDialog` (stars animation, 2× coins ad, Next/Replay/Home), `GameOverDialog` ("Out of Lives!", watch ad, RESTART, MAIN MENU, snackbar if no ad), `HintAdDialog` (watch ad → "Use Hint Now"/"Keep for Later"), the reset-progress confirm in Settings, and the theme unlock confirm in Themes.
- **Settings:** toggles for Sound, Music (no effect, since there is no music), Haptics and Notifications (no effect, since notifications are not implemented), Reset Progress (clears Hive and navigates to `/`), a Privacy Policy link (external Notion URL), and app info.
- **Responsiveness:** the board fits any width via `InteractiveViewer`. Menu layouts use fixed paddings; small-height devices were not verified (see §15).
- **Animations:** splash arrow and fade; home hero loop; level-map pulses and progression; arrow shake/escape/glow; board pulse and coin fly on win; confetti; dialog scale/elastic and star reveal; route transitions (fade / rightToLeftWithFade).

---

## 8. Ads / monetization

- **SDK:** `google_mobile_ads`. App ID is in `AndroidManifest.xml` and in iOS `Info.plist` (`GADApplicationIdentifier`, plus one `SKAdNetworkItems` entry). The manifest sets `OPTIMIZE_INITIALIZATION` and `OPTIMIZE_AD_LOADING`, and declares the `AD_ID` permission.
- **Ad unit IDs:** `lib/modules/ads/config/ads_config.dart`. Android uses **production** IDs in **all builds, including debug**. iOS IDs are placeholders (`ca-app-pub-XXXXXXXXXXXXXXXX/…`). `isSupportedDevice()` always returns true. There are no test-device settings or test IDs.
- **Initialization:** `AdsModule.initialize()` (splash step 4) registers `NoOpPurchaseService`, then `AdMobService` on Android/iOS (`NoOpAdService` elsewhere). `AdMobService.onInit` calls `MobileAds.instance.initialize()` and preloads one interstitial and one rewarded ad.
- **Banner:** `BannerAdWidget` (320×50 `AdSize.banner`) at the bottom of Home and Gameplay. Collapses to zero height when not loaded.
- **Interstitial:** `showInterstitial()` is called on every level completion. It shows only on every **3rd** completion **and** at least **2 minutes** after the last one. The counter is in memory and resets each launch.
- **Rewarded** (one shared unit, loaded on demand with a 10 s timeout if not preloaded):
  - `showRewardedLife`: Game Over → restore 4 lives
  - `showRewardedHint`: Hint ad dialog → +1 hint
  - `showRewardedCoins`: Level Complete → +base coins (2×)
  - Each returns true only if `onUserEarnedReward` fired, and resolves after dismissal.
- **Remove ads / IAP:** `IPurchaseService` has only `NoOpPurchaseService` (`removeAdsPurchased = false`). `PlayerProgress.removeAds` exists but is never read. **No RevenueCat or in-app purchases are implemented.**
- **Consent (UMP / GDPR) and ATT:** not implemented (no `ConsentInformation` usage and no `NSUserTrackingUsageDescription`). Not determined from the current codebase whether this is handled elsewhere.

---

## 9. Firebase

- **Android native only:** the `com.google.gms.google-services` plugin is applied, `google-services.json` exists locally (git-ignored), and `firebase-bom` + `firebase-analytics` are native dependencies. The native Firebase Analytics SDK therefore auto-initializes and collects **automatic** events only (first_open, session_start, screen views of the Activity, and so on).
- **Dart side:** **no** `firebase_core`, `firebase_analytics`, Crashlytics or Messaging packages, and no `Firebase.initializeApp()`. No custom event reaches Firebase.
- **iOS:** no `GoogleService-Info.plist` and no Podfile. Firebase is not configured on iOS.
- **App analytics layer:** `lib/services/analytics_service.dart` defines `IAnalyticsService` with **only** `DebugAnalyticsService`, which `print`s every event (in release too).

  | Event | Logged from | Params |
  | --- | --- | --- |
  | `level_started` | `GameplayController.loadLevel` (campaign only) | `level`, `difficulty` |
  | `arrow_tapped` | valid tap | `arrowId` |
  | `arrow_blocked` | blocked tap | none |
  | `hint_used` | hint shown | none |
  | `undo_used` | undo | none |
  | `level_completed` | win | `level`, `stars`, `moves` |
  | `theme_unlocked` | theme purchase | `themeId` |

  Defined but **never logged**: `game_opened`, `level_failed`, `daily_challenge_started`, `daily_challenge_completed`, `ad_watched`, `purchase_completed`.
- **Missing:** a Dart Firebase integration (an `IAnalyticsService` implementation backed by `firebase_analytics`), Crashlytics, FCM, and an iOS config.

---

## 10. Audio

- **Service:** `IAudioService`, implemented by `AudioPlayersService` (real) and `NoOpAudioService` (tests, or when init fails), registered in splash step 3.
- **Audio context:** Android `usageType: game`, `contentType: sonification`, `gainTransientMayDuck`; iOS `ambient` (respects the silent switch and mixes with other audio).
- **Players:** a pool of 3 for escapes, 1 for blocked, 1 for UI. Each play calls `stop()` and then `play(AssetSource)`.

| Sound | Asset | Status |
| --- | --- | --- |
| Arrow escape | `assets/sounds/arrowsound.m4a` | Plays on every valid tap |
| Blocked / wrong | `assets/sounds/universfield-wrong-answer-beep-149895.mp3` | Plays on every blocked tap |
| Button click | (reuses arrowsound) | `playButtonClick()` is **never called** |
| Level complete, coin, star | none | Methods are **empty stubs** |
| Background music | none | Not implemented; the `musicOn` setting is stored but has no effect |

- **Volume:** no volume control; only on/off (`soundOn`).
- `tool/generate_audio.dart` writes `assets/audio/{tap,escape,blocked}.wav`. The app does not reference them, and `assets/audio/` only holds `.gitkeep`.

---

## 11. Controllers, services, repositories

| Class | Type | Responsibility |
| --- | --- | --- |
| `AppInitializationService` | static | Ordered startup; registers all permanent services; pre-generates the current level |
| `StorageService` | plain, `Get.put` | Hive boxes; progress, settings, saved games (in-memory fallback if the box is not open) |
| `ProgressRepository` | GetxService | Stars, unlocks, themes, streak, tutorial flag, reset. **Imports `LevelSelectController`** (data layer → UI dependency) |
| `EconomyService` | GetxService | `coins`/`hints` Rx; add/spend/award; persists through storage. "All coin/hint changes must go through here." |
| `HapticService` | GetxService | Light/medium/heavy/selection haptics, on/off |
| `IAudioService` | GetxService | See §10 |
| `IAdService` / `AdsModule` | GetxService | See §8 |
| `IAnalyticsService` | GetxService | See §9 |
| `IPurchaseService` | GetxService | No-op stub |
| `LevelRepository` | static | Generate/cache levels, preload, daily |
| `ThemeRepository` | static | Theme list / lookup |
| `GameEngine` | plain | Rules; owned by `GameplayController` |
| `GameplayController` | GetxController | Bridges engine ↔ UI; timers for animations; save/restore; rewards; ads |
| `HomeController`, `LevelSelectController`, `DailyChallengeController`, `ThemesController`, `SettingsController` | GetxController | Per-screen state |

---

## 12. Data storage

Only **Hive** is used; there is no SharedPreferences, SQLite, files or cloud storage. Initialized in `AppInitializationService.initializeStorage()` (`Hive.initFlutter()`, adapters for typeId 0 and 1).

| Box | Key | Content |
| --- | --- | --- |
| `progress_box` | `player` | `PlayerProgress` (typeId 0): `highestUnlockedLevel`, `levelStars` (Map<int,int>), `coins`, `hints`, `currentThemeId`, `dailyStreak`, `lastDailyCompletedDate`, `removeAds` (unused), `hasSeenTutorial` (unused on read), `unlockedThemes` |
| `settings_box` | `settings` | `GameSettings` (typeId 1): `soundOn`, `musicOn`, `hapticsOn`, `notificationsOn` |
| `saved_game` | `level_<n>` | Map: `levelNumber`, `removedArrowIds`, `moves`, `mistakes`, `lives`, `isDaily` (always false), `savedAt` |
| `saved_game` | `last_active_level` | int: the level the Home "Continue" card uses |

Rules: Hive field indexes and typeIds are part of the on-disk format. **Never renumber or reuse `@HiveField` indexes or typeIds; only add new indexes.** Regenerate adapters with `build_runner` after model changes. Levels themselves are never stored; they are regenerated from seeds.

---

## 13. Android build configuration

| Setting | Value |
| --- | --- |
| namespace / applicationId | `com.arrowescape.arrowescapegame` |
| compileSdk / targetSdk / minSdk / ndkVersion | From the Flutter plugin defaults (not pinned) |
| versionCode / versionName | From `pubspec.yaml` `version` (`1.0.0+7`) |
| Java / Kotlin JVM target | 17 / 17 |
| AGP / Kotlin / Gradle | 8.11.1 / 2.2.20 / 8.14 |
| `gradle.properties` | `-Xmx8G`, AndroidX, `android.newDsl=false`, `android.builtInKotlin=false`, `kotlin.incremental=false` |
| Build dir | Redirected to the repo-root `build/` |
| Signing | `release` config reads `android/key.properties` (`keyAlias`, `keyPassword`, `storeFile`, `storePassword`; `storeFile` is resolved relative to `android/`). If the file is missing, the release build has an incomplete signing config and will fail to sign. |
| Debug signing | Default debug keystore |
| ProGuard / R8 | No `proguard-rules.pro`; `minifyEnabled`/`shrinkResources` are not set, so release minification is not enabled explicitly by this project. |
| Obfuscation / split-debug-info | Not configured in the repo; pass `--obfuscate --split-debug-info=<dir>` at build time if wanted (`.gitignore` already ignores `app.*.symbols`). |
| Tree shaking | Flutter default (icon tree-shaking on in release) |
| Permissions | `INTERNET`, `ACCESS_NETWORK_STATE`, `com.google.android.gms.permission.AD_ID` |
| Manifest | Single `MainActivity`, portrait, `singleTop`, hardware-accelerated; AdMob meta-data; `<queries>` for PROCESS_TEXT and http/https VIEW (needed by url_launcher) |
| Custom Gradle hack | `doNotTrackState` on `FlutterTask` (Gradle 9 compatibility); subprojects forced to compileSdk 36 and Java 17 |

---

## 14. Performance

### Confirmed from code

1. **Level generation runs on the UI isolate.** `LevelRepository.getLevel` (synchronous) runs on first open of a level, and `_preloadNextLevels` generates 3 more levels in a microtask right after, still on the main isolate. Each generation can run up to 20 attempts, each with mask building, path growth, analysis and a DFS solve on a 20×20 board. This can cause visible jank or frame drops when entering gameplay and just after. Only the daily challenge uses `Isolate.run`.
2. **Every arrow rebuilds every frame.** Each `ArrowWidget` has a glow controller that `repeat`s forever, and its `AnimatedBuilder` listens to it even when the arrow is not hinted. With 30–60+ arrows, that is 30–60 widget rebuilds and painter allocations per frame. `shouldRepaint` limits the actual repaints.
3. **Overdraw:** each arrow is a full-board `CustomPaint` layer, so N layers the size of the board.
4. **The solver rebuilds occupancy for every `canEscape` call.** `getAvailableArrows` is O(N² × cells) per DFS node; capped by the 3,000-state limit.
5. **Debug-only overhead:** `DependencyAnalyzer.analyze` and a large `print` per accepted level in `kDebugMode`.
6. **`DebugAnalyticsService` prints in release builds** on every tap.

### Possible improvements (not verified by profiling)

- Generate levels in `Isolate.run`/`compute` (as the daily does), or pre-generate and ship the level data as assets.
- Only run the glow controller when the arrow is hinted. Paint all idle arrows in one `CustomPainter`.
- Cache occupancy in the solver per `BoardState`.
- 100 level-map nodes are built eagerly in a `Stack`. Fine at 100; consider lazy building if the level count grows a lot.
- Assets are small (~56 KB total audio).

---

## 15. Bugs and risks

Severity is a judgment based on reading the code; none of these were reproduced on a device.

**High**

1. **Undo/reset during an escape animation.** `onArrowTap` schedules `Future.delayed(... markArrowRemoved; _checkWin)`, which is never cancelled. Undo stays enabled while an animation runs (whenever an earlier arrow is already removed), and `onUndo`/`onReset`/`loadLevel` do not cancel the pending timer. After an undo or reset, the old timer still removes the arrow and may trigger a win. The same applies to the blocked-arrow and game-over timers.
2. **Level determinism depends on session history** (`_recentSignatures`; see §5). Saved games can be restored onto a different board.
3. **Daily challenge pollutes campaign state.** `loadLevelModel` uses level number 0:
   - `saveCurrentGame` writes `level_0` and `last_active_level = 0`, so Home can show "Continue Level 0" and call `getLevel(0)`, which fails the `n >= 1` assert in debug.
   - `_checkWin` calls `markLevelCompleted(0, …)`, which adds `levelStars[0]` to total stars.
   - It awards normal level coins on top of the daily +50.
   - "Next Level" after a daily loads level 1.
4. **Force-unwraps in the fallbacks** (`LevelRepository._fallbackLevel`, `getDailyChallenge`) crash if generation returns null.
5. **Production ad IDs in debug builds** risk AdMob policy violations; **no consent (UMP) flow**.

**Medium**

6. **Production difficulty differs from what was intended:** levels 21–100 are all "extreme", versus the 4-world plan in `AppConstants`/UI. Tests pass explicit difficulties, so they don't cover the production configuration.
7. **The solver's 3,000-state cap** can label a large solvable board "unsolvable". That only causes extra regeneration and is safe, but it makes generation slower and the fallbacks more likely.
8. **`_fillRemainingGaps` direction bug.** It checks the exit ray for `dir`, but if the first step back from the head is sideways, the arrow's real `exitDirection` (derived from the last segment) differs from `dir`. The exit-ray safety check is then wrong. The solver gate catches unsolvable results.
9. **Undo refunds lives and mistakes** (it restores the snapshot taken before the move), so mistakes can be erased to earn 3 stars.
10. **Coin farming:** level-complete coins are paid on every replay.
11. **`Isolate.run` with a closure created inside a controller method** may try to send the closure's captured context. If that fails, the daily screen shows "Could not prepare today's challenge." Not verified on a device.
12. **Hints are topped up to 3 on every level load,** so hints are effectively unlimited, and the rewarded hint ad matters little.
13. `onHint` consumes a hint before checking that one exists (it is lost if no arrow is available).
14. `BannerAdWidget` disposes the ad in `onAdLoaded` when unmounted, and again in `dispose`.

**Low / cleanup**

- Unused: `DotGridGenerator`, `ShapeTemplate`/`ShapeType`, `maxMistakes`, `moveTarget`, `timeTargetSeconds`, `coinsUndoCost`, `*ThemeCost`, `solverMaxIterations`, `arrowPressDelayMs`, `newlyAvailableArrowIds` (never filled), `ArrowState.selected`, `buyHint`, `playButtonClick`, the `sdkInt` MethodChannel, `removeAds`, `hasSeenTutorial` (never read), `AppStrings.pause/resume`, and several analytics events.
- Stale comments: "23–45-cell arrows" in `ShapePathGenerator`; `_fallbackLevel` says "3-arrow level".
- `flutter test` (2026-10-06): **all 44 tests pass** in about 2 min (most of that is the 100-level generation test).
- `flutter analyze` reports 88 issues: 2 unused-import warnings (`game_over_dialog.dart`, `app_initialization_service.dart`), 71 `withOpacity` deprecations, and minor lints. There are **no errors**.
- Template TODOs in `android/app/build.gradle.kts` (applicationId comment, Firebase deps comment).
- iOS display name `Arrowescapegame`; iOS ad IDs are placeholders; no Firebase on iOS.
- The `ever(...)` workers in `GameplayScreen` and `DailyChallengeScreen._launchChallenge` are never disposed.
- UI overflow: menu screens use fixed sizes inside `Column`s with `Spacer`. Short screens or large font scales were not checked; treat them as a risk.

---

## 16. Current app flow (as implemented)

```
main()
  ├─ FlutterError / PlatformDispatcher filters (swallow font-load + ClientException)
  ├─ lock portrait, transparent status bar
  └─ GetMaterialApp(initialRoute: '/')
        ↓
SplashScreen → AppInitializationService.initialize()
  1 Hive init + adapters + StorageService            (critical)
  2 ProgressRepository, EconomyService (tops hints to 3), HapticService
  3 Audio (AudioPlayersService or NoOp) + apply saved settings
  4 AdsModule (NoOpPurchase, AdMobService → MobileAds.initialize + preload) + DebugAnalytics
  5 LevelRepository.getLevel(highestUnlockedLevel)    (sync generation + preload n+1..n+3)
        ↓ Get.offNamed('/home')
Home ── Continue (last_active_level or highest) ──► /gameplay(int)
     ── Play ──► /level-select ── tap unlocked node ──► /gameplay(int)
     ── Daily ──► /daily-challenge (Isolate.run generate) ── Start ──► /gameplay(LevelModel)
     ── Themes / Settings
        ↓
GameplayScreen.initState → GameplayController.loadLevel(n)
  ├─ LevelRepository.getLevel(n) (cache or sync generate)
  ├─ restore saved_game level_n if partially played
  └─ tutorial overlay if n == 1
        ↓
Player taps a cell → ArrowBoardWidget hit-test → onArrowTap(id) → GameEngine.tapArrow
  ├─ valid   → state=escaping, moves++, undo snapshot, escape sound, animation (400–500 ms)
  │            → timer: markArrowRemoved → save game → _checkWin
  └─ blocked → state=blocked, mistakes++, lives--, blocked sound, light haptic, shake
               → lives==0 → GameOverDialog (ad → +4 lives | restart | home)
        ↓ (all arrows removed)
_checkWin: clear save, heavy haptic, coins +25(+10), stars saved, next level unlocked,
           LevelSelectController.recordLevelCompletion, analytics
        ↓ 650 ms
isComplete → interstitial (every 3rd, ≥2 min) → confetti → LevelCompleteDialog
        ↓
Next Level → loadLevel(n+1)  |  Replay → onReset  |  Home → /home
(Level map animates the completed → next node the next time it opens)
```

---

## 17. Development rules (project-specific)

These follow from the existing architecture. Items marked **[PROJECT]** are specific to this game.

1. **[PROJECT] Keep the fixed 20×20 grid** (`AppConstants.fixedGridSize`). Do not make the board size vary by screen or level. Responsiveness comes from `PuzzleConfig.adaptive` scaling and the `InteractiveViewer` fit, not from changing `gridSize`.
2. **[PROJECT] Keep levels deterministic.** Do not change the seed formula, RNG consumption order, pattern mapping, difficulty selection, tier tables or quality thresholds for existing level numbers unless the user explicitly asks to regenerate the campaign. If you must, say clearly that every existing level and every saved in-progress game is affected.
3. **[PROJECT] Keep the arrow model semantics:** `points` is tail → head, direction is derived from the last segment, and escape checks only the head lane. Renderer, hit-testing, solver and generator all depend on this.
4. **[PROJECT] Keep long arrow support:** generator tiers up to 22 cells, absorption up to 45, and length-scaled escape timing. Do not add caps that shorten arrows.
5. **[PROJECT] Keep arrow appearance:** stroke and head formulas, rounded corners, a single arrowhead, theme colours. Change them only on request, and keep `PuzzleConfig.adaptive` and `ArrowPainter` in sync.
6. **[PROJECT] Keep the existing UI and flows** (screens, dialogs, HUD layout, ad placements) unless asked.
7. **[PROJECT] Route all coin/hint changes through `EconomyService`,** and all progress writes through `ProgressRepository`.
8. **[PROJECT] Never renumber Hive typeIds or `@HiveField` indexes;** append new fields and run `build_runner`.
9. **[PROJECT] Every generated level must stay solver-verified.** Never return a board that skipped `LevelSolver.solve`.
10. **[PROJECT] Use the service interfaces** (`IAdService`, `IAudioService`, `IAnalyticsService`, `IPurchaseService`) so tests can keep using the NoOp implementations.
11. Avoid dependency changes. Check `pubspec.yaml` first; if a new package is really needed, explain why.
12. Do not edit platform build files, signing, manifest or ad IDs unless asked.
13. After changes, run `flutter analyze` (expect 0 errors; do not add new warnings) and the relevant `flutter test` files. Run the generator and solver tests for anything under `lib/game/`.

---

## 18. How to modify the project

| Task | Steps |
| --- | --- |
| **Add a screen** | Create `lib/modules/<name>/<name>_screen.dart` and `<name>_controller.dart` (extends `GetxController`; get services with `Get.find`). Add a constant to `AppRoutes` and a `GetPage` to `AppPages.routes`. Navigate with `Get.toNamed(AppRoutes.x)`. Put strings in `AppStrings` and colours in `AppColors`. |
| **Add levels** | Increase `AppConstants.totalLevels` (see §5). Optionally add explicit `getPatternForLevel` cases and `selectDifficulty` branches **for the new numbers only**. Run the generator tests and time generation. |
| **Add a shape pattern** | See §6 (append to the enum, add an inequality case, consider rotation lock, map to level numbers). |
| **Add an arrow type** | Not supported today: there is one arrow type, and behaviour comes from `points` only. A new type would need a field on `ArrowModel` (and `copyWith`), escape rules in `LevelSolver._canEscape` (shared by engine and solver), drawing in `ArrowPainter`/`ArrowWidget`, generator placement, and saved-game compatibility. Discuss the design with the user first. |
| **Change difficulty** | `_params` / `selectDifficulty` / `getMinOccupancyForLevel` in `level_generator.dart`; length tiers in `shape_path_generator.dart`. Read the warnings in §5 first. |
| **Add a sound** | Put the file in `assets/sounds/` (already declared). Add a method to `IAudioService`, then implement it in both `AudioPlayersService` (use a dedicated or pooled `AudioPlayer`, and respect `_soundEnabled`) and `NoOpAudioService`. Call it from the controller. |
| **Add an analytics event** | Add a constant to `AnalyticsEvent` and call `_analytics.logEvent(name, params: {...})` from a controller. For real analytics, add `firebase_core` + `firebase_analytics` (needs the user's approval), implement `FirebaseAnalyticsService implements IAnalyticsService`, and register it in `AppInitializationService.initializeAds()`. |
| **Change ads** | IDs: `lib/modules/ads/config/ads_config.dart`. Frequency/cooldown: `AdMobService` (`% 3`, `_interstitialCooldown`). Placements: `BannerAdWidget` in Home/Gameplay; rewarded calls in `GameplayController` and `LevelCompleteDialog`. App ID: `AndroidManifest.xml` / `Info.plist`. |
| **Debug APK** | `flutter build apk --debug` (or `flutter run`) |
| **Release APK / AAB** | Needs `android/key.properties` and the keystore locally. `flutter build apk --release` / `flutter build appbundle --release`. Bump `version` in `pubspec.yaml` first. Optional: `--obfuscate --split-debug-info=build/symbols`. |
| **Run tests** | `flutter test` (all) or `flutter test test/<file>_test.dart` |
| **Static analysis** | `flutter analyze` |
| **Regenerate Hive adapters** | `dart run build_runner build --delete-conflicting-outputs` |

---

## 19. Important files

| File | Purpose | Importance | Be careful about |
| --- | --- | --- | --- |
| `lib/core/constants/app_constants.dart` | Tuning, seeds, Hive ids | Critical | `levelSeed`, `fixedGridSize`, Hive typeIds change saved or generated data |
| `lib/game/generator/level_generator.dart` | Campaign generation | Critical | Any change alters existing levels; static `_recentSignatures`; force-unwrap fallbacks |
| `lib/game/generator/shape_path_generator.dart` | Arrow path construction | Critical | RNG order, tier tables, exit-ray safety in absorption |
| `lib/game/generator/shape_template.dart` | Pattern masks | High | Enum order drives levels 21+; only append |
| `lib/game/solver/level_solver.dart` | Escape rule, solver, hint | Critical | `_canEscape` is the single rule for engine and solver; 3,000-state cap |
| `lib/game/engine/game_engine.dart` | Gameplay rules | Critical | Undo snapshot semantics, lives, stars |
| `lib/data/models/arrow_model.dart` | Arrow representation | Critical | tail → head order, derived direction, `id` equality |
| `lib/modules/gameplay/gameplay_controller.dart` | Game ↔ UI glue, rewards, saves | Critical | Uncancelled timers, daily level 0 handling |
| `lib/game/renderer/arrow_painter.dart`, `arrow_widget.dart`, `arrow_board_widget.dart` | Visuals and hit-testing | High | Size formulas, per-arrow controllers, scene-coordinate tap mapping |
| `lib/data/repositories/level_repository.dart` | Cache, preload, daily | High | Main-isolate generation; `!` fallbacks |
| `lib/services/storage_service.dart`, `data/models/player_progress.dart`, `game_settings.dart` | Persistence | High | Hive schema compatibility; regenerate `.g.dart` |
| `lib/services/economy_service.dart` | Coins and hints | High | Single place for economy changes |
| `lib/services/app_initialization_service.dart` | Startup and DI | High | Registration order; `Get.find` in controllers depends on it |
| `lib/modules/ads/**` | Monetization | High | Production IDs; frequency rules; reward-only-on-earned |
| `android/app/build.gradle.kts` | Build, signing, Firebase | High | Never print or commit `key.properties` values |
| `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist` | Permissions, AdMob app id, orientation | Medium | Ad app ID must match the account |
| `pubspec.yaml` | Dependencies, assets, version | Medium | Asset folders; version bump per release |
| `test/level_generator_test.dart` | Level quality regression | High | Uses explicit difficulties, not the production `selectDifficulty` |

---

## 20. Architecture map

```
┌──────────────────────── UI (Flutter widgets) ────────────────────────┐
│ Splash · Home · LevelSelect(map) · Gameplay(+dialogs, tutorial)       │
│ DailyChallenge · Themes · Settings · shared widgets · BannerAdWidget   │
│ game/renderer: ArrowBoardWidget → ArrowWidget → ArrowPainter          │
└──────────────┬────────────────────────────────────────────────────────┘
               │ Obx / Get.find / Get.toNamed
┌──────────────▼──────────── Controllers (GetX) ───────────────────────┐
│ GameplayController · HomeController · LevelSelectController           │
│ DailyChallengeController · ThemesController · SettingsController      │
└──────┬───────────────────────────────┬────────────────────────────────┘
       │                               │
┌──────▼────── Game logic ──────┐  ┌───▼──────────── Services (permanent) ─────────┐
│ GameEngine (rules, undo, ★)   │  │ EconomyService · HapticService · IAudioService │
│ LevelSolver (canEscape, DFS,  │  │ IAdService(AdMob/NoOp) · IAnalyticsService     │
│   hint) · BoardState          │  │ IPurchaseService(NoOp) · AppInitialization     │
└──────┬────────────────────────┘  └───┬────────────────────────────────────────────┘
       │                               │
┌──────▼──── Level generation ───────┐ │  ┌──── Repositories ─────────────────────┐
│ LevelRepository (cache, preload,   │ │  │ ProgressRepository · ThemeRepository   │
│   daily) → LevelGenerator          │ │  └───────────────┬───────────────────────┘
│   → PatternGenerator (mask)        │ │                  │
│   → ShapePathGenerator (arrows)    │ │                  │
│   → DependencyAnalyzer (metrics)   │ │                  │
│   → LevelSolver (verify)           │ │                  │
└──────┬─────────────────────────────┘ │                  │
       │                               │                  │
┌──────▼─────────── Models ─────────────▼──────────────────▼───────────────┐
│ ArrowModel · ArrowDirection · ArrowState · LevelModel · Difficulty        │
│ PlayerProgress · GameSettings · ThemeModel · DailyChallenge               │
└──────┬────────────────────────────────────────────────────────────────────┘
       │
┌──────▼──────── Storage / external ───────────────────────────────────────┐
│ StorageService → Hive (progress_box, settings_box, saved_game)            │
│ google_mobile_ads (AdMob) · audioplayers · url_launcher · HapticFeedback  │
│ Firebase Analytics (native Android auto-events only)                      │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## Instructions for Claude Code

1. **Read before changing.** Open the files involved, and their callers, before editing. For gameplay or generation, read §4 and §5 above first.
2. **Make minimal, targeted changes.** No rewrites, renames, reformatting or "cleanups" of code you were not asked to touch. Match the surrounding style (GetX patterns, `AppStrings`/`AppColors`, service interfaces).
3. **Preserve gameplay and UI/UX** (rules, lives, stars, layout, arrow look, fixed 20×20 grid) unless the user explicitly asks for a change.
4. **Do not break level generation.** Anything that changes seeds, RNG order, pattern order, difficulty selection or generator thresholds changes existing levels. Warn the user and get confirmation first.
5. **Check dependencies before adding any.** Prefer what is already in `pubspec.yaml`. Ask before adding a package or changing versions or Gradle/Android/iOS config.
6. **Verify:** run `flutter analyze` and the relevant `flutter test` files after changes, and report the results honestly (including failures).
7. **Explain the change:** list every file you changed and why.
8. **Never expose secrets:** do not read out, print, copy or commit `key.properties`, keystores, `google-services.json`, or passwords. Ad unit IDs are already in source; do not spread them further.
9. **Never modify unrelated files,** including the user's uncommitted work (check `git status`).
10. **When unsure about intended behaviour** (for example, which difficulty table is "correct"), ask instead of guessing; §15 lists known ambiguities.
