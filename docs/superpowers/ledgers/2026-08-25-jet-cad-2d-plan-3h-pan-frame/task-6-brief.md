### Task 6: `PAN_STEP`

**Files:**
- Modify: `apps/dev_harness_2d/lib/main.dart`
- Modify: `apps/dev_harness_2d/lib/measurement_rig.dart`

**Interfaces:**
- Produces: `double kPanStep` in `main.dart`, forwarded to `runTilePhases`.

**Four properties, each a defect if omitted:**

1. **A magnitude, not a component.** The rig's step is `Offset(-7, -3)`, magnitude `sqrt(58)` = 7.615773. `PAN_STEP` scales that vector, preserving direction, so every arm meets the tile lattice at the angle every prior number was taken at.
2. **Unset means no scaling at all.** `7.6 / sqrt(58)` is 0.99793, so passing the rounded figure would rescale the historical step and make the arm incomparable with every row already recorded at it.
3. **The tile phase only** (`measurement_rig.dart:523`), never R2's own pan (`:357`). Taking both would make every prior plan's R2 row incomparable.
4. **A throwing parse.** `main.dart` already has `_intDefine` for exactly this reason; a magnitude needs its `double` sibling.

- [ ] **Step 1: Add `_doubleDefine` and `kPanStep`**

In `apps/dev_harness_2d/lib/main.dart`, beside `_intDefine`, add:

```dart
/// [_intDefine]'s sibling, for a define that is not an integer.
///
/// Same rule and the same reason: a silent default writes one run into the
/// table under a heading the command line claimed and the run did not use.
double _doubleDefine(String name, String raw, double fallback,
    {double? minimum}) {
  if (raw.isEmpty) return fallback;
  final value = double.tryParse(raw);
  if (value == null || !value.isFinite) {
    throw ArgumentError.value(raw, name, 'not a finite number');
  }
  if (minimum != null && value < minimum) {
    throw ArgumentError.value(raw, name, 'below $minimum');
  }
  return value;
}

/// The tile-pan phase's speed, in logical pixels per frame.
///
/// **A magnitude along the rig's existing direction, and unset means no
/// scaling at all.** The historical step is `Offset(-7, -3)`, magnitude
/// `sqrt(58)` = 7.615773; `PAN_STEP=7.6` would scale it by 0.99793 and make
/// the arm incomparable with every row already recorded at it. `NaN` is the
/// sentinel for unset because zero is a legal magnitude to ask about.
///
/// It reaches the **tile phase only**. R2's own pan keeps `Offset(-7, -3)`
/// unconditionally, or every prior plan's R2 row becomes incomparable.
final double kPanStep = _doubleDefine(
    'PAN_STEP', const String.fromEnvironment('PAN_STEP'), double.nan,
    minimum: 0);
```

- [ ] **Step 2: Thread it to the tile phase**

In `measurement_rig.dart`, add `required double panStep,` to `runTilePhases`' parameters, and replace the tile-pan call:

```dart
  // `PAN_STEP` unset leaves the historical step untouched -- see `kPanStep`.
  const historical = Offset(-7, -3);
  final magnitude = historical.distance;
  final step = panStep.isNaN
      ? historical
      : Offset(historical.dx * panStep / magnitude,
          historical.dy * panStep / magnitude);
  print('  tile pan step: dx=${step.dx.toStringAsFixed(4)} '
      'dy=${step.dy.toStringAsFixed(4)} '
      'magnitude=${step.distance.toStringAsFixed(4)}');
  await phase('tile pan', 120, step);
```

`:357`'s `camera.panBy(const Offset(-7, -3))` is **not touched**.

In `runR2Rig`, add `panStep: panStep,` to the `runTilePhases(...)` call and `required double panStep,` to `runR2Rig`'s own parameters; pass `kPanStep` from `main.dart`'s call site.

- [ ] **Step 3: Verify the default changes nothing**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d
flutter analyze && dart format --output=none --set-exit-if-changed .
caffeinate -dimsu flutter drive --profile -d macos \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart \
  --dart-define=ENTITIES=50000 --dart-define=TILES=on 2>&1 | grep "tile pan step"
```

Expected: `dx=-7.0000 dy=-3.0000 magnitude=7.6158`. **Any other value means the default rescaled the historical step** and step 1's `isNaN` sentinel is wrong.

- [ ] **Step 4: Verify a bad value throws**

```sh
caffeinate -dimsu flutter drive --profile -d macos \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart \
  --dart-define=ENTITIES=50000 --dart-define=TILES=on \
  --dart-define=PAN_STEP=30px 2>&1 | tail -5
```

Expected: an `ArgumentError` naming `PAN_STEP`. A run that silently proceeds at 7.6 is the exact failure `_intDefine`'s doc comment was written against.

- [ ] **Step 5: Commit**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad
git status --porcelain   # project.pbxproj may appear; do NOT stage it
git add apps/dev_harness_2d/lib/main.dart apps/dev_harness_2d/lib/measurement_rig.dart
git commit -m "feat(rig): PAN_STEP, a magnitude along the rig's existing direction

Criteria 4 and 5 read a band of pan speeds, and the band has to meet the tile
lattice at one angle: an axis-aligned fast pan would measure a different
interaction than the diagonal one every prior number was taken on.

Unset means no scaling at all, not PAN_STEP=7.6 -- 7.6 / sqrt(58) is 0.99793
and would rescale the historical step. It reaches the tile phase only; R2's
own pan is untouched, or every prior plan's R2 row becomes incomparable. The
parse throws, for _intDefine's reason."
```

---

