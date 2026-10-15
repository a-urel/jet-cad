# The 2b follow-ups (2026-10-15)

**Asked by:** the session that ran 2b. The brief was to close the small
items 2b left open once 2b was merged. **Branch:** `fix/plan-library-2b-followups`,
from local `main` at `2b1f7a0e` (2b merged at `fa294563`, not pushed).
**Inputs:** the 2b ledger
([progress.md](../ledgers/2026-10-14-plan-library-2b/progress.md), its
"minor (deferred)" and "Final: parked" lines) and the final review's Minor
list ([final-review.md](../ledgers/2026-10-14-plan-library-2b/final-review.md)).
Every test below was turned red by its named mutation, which was then
reverted (`git diff --quiet` on the mutated file).

## Done

| Item | Commit | Test | Mutation (red) |
|---|---|---|---|
| F-1 of `chrome_change_test.dart` (design-only, a 2a port gap), assertions unchanged | `7f86f1ef` | editor_modes_test "F-1 the canvas kept across a change of both side columns" (4 cases) | M-F1: the canvas's `Expanded` in `PlanEditor` unkeyed. 4/4 red ("the canvas kept its element") |
| Parked: a profile changed in service is the one applied on leaving | `fb69e4f1` | canvas_service_mode_test SM-design-readonly-profile | M-SM-capture: `permissions.draft` captured on entering service and applied on leaving. Only the new test goes red; SM-design-readonly and -load stay green |
| Parked: the kit CHANGELOG's 2b line past the wrap width | `fb69e4f1` | — | — |
| M-8: `PlanExportRequest(unitColourOpacity:)` took any double | `ef502718` | unit_colour_export_test M-8 | M-ER-unchecked: the argument stored unchecked ("Expected: throws ArgumentError") |
| T9: UA-locked-write's title says "no label" but it never asked | `923b9c4c` | unit_api_test UA-locked-write | M-UA-seat-label: setUnitsLabel's generated-or-locked refusal removed (GeneratedGeometryError) |
| T13: a restored group member naming only a hidden or locked unit is kept (S3, decision 7) | `873b660a` | service_record_controller_test SR-group-hidden-locked | M-SR-group-selectable: the match counts only visible, unlocked units. Only the new test goes red |
| M-9 and the ledger's cosmetic lines | `6f83bb39`, `59c6b402` | — | the M-SS5/M-SS6/M-SS7 markers re-run: SS-locked-not-selected goes red at `selectableMembers` (M-SS5) and at the first `activeSelection` expect (M-SS6); SS-mixed-group goes red at `selectedGroup` (M-SS7) |

The cosmetic lines: `UnitTop`'s doc ("a unit's top"), `UnitInspector`'s
class doc, `framingFor`'s doc, `_named`'s doc (host words make new
`PlanSymbol`s), service_tool's comment at the refused drag,
DS-click-attrib's comment (a positive control), box_kit and
value_words_test reflowed, unit_label_stack_test's imports sorted.
`symbol_placer.dart`'s "no table record" is **not stale**: it names the
engine's table records (layers, styles).

## Gates (at the branch's code head, `59c6b402`)

- `jet_cad_2d_plan`: `flutter test --enable-vmservice` +1519 (2b's 1512 and
  the 7 new tests), `flutter analyze` no issues, format 0 changed,
  `dart pub publish --dry-run` 0 warnings.
- `jet_cad_2d_kit`: `flutter test` +340, analyze no issues, format 0
  changed, dry run 0 warnings.
- `jet_cad_2d`: +1337 -2. `jet_cad_2d_flutter`: +1450 ~1 -5. Both are
  exactly the standing lines in `tool/ci/standing_failures.txt` (the two
  document fingerprints, the five text-ladder goldens). `jet_cad_2d_gpu`:
  +20. Analyze and format are clean in all three.

## Left, for the human

The final review recommended taking M-1 and M-4 "if time allows; otherwise
record them for sub-project 4's parity work". Neither is cheap, and
neither is a spec-named rule:

- **M-1, a mixed drag previews the seats moving.** The renderer draws every
  selected key on the tool's single `selectionPreviewTransform` unless
  `ToolContext.grips.isMovable` says otherwise, and `grips` is the concrete
  `GripCache` (which would also draw grips in service). A fix needs a
  per-key preview hook in `jet_cad_2d_flutter`, a published package, for
  example a `ToolContext` "movable" predicate. That is an API decision.
- **M-4, every design edit rebuilds the unit index.** This is edit rate,
  not frame rate. The fix is an early return in `_refreshSelected`, or
  `UnitIndex.of` skipping the walk with no `UnitComponent`. Pinning it
  needs a counting seam the library does not have.
- **M-5, a coloured-unit export is O(units × entities).** It has the
  oracle's shape and costs only at export time. Passing
  `document.leavesByOwner` fixes it, but no behaviour changes, so no test
  can pin it.
- **M-6, the design-side panels read the active index.** This cannot be
  observed today: the handles are equal and commits are refused in
  service. It goes away if the panels become inert in service.
- **`PlanServiceView._listen`'s double `setState` on a mode switch** (M-9,
  T16a). Harmless.
- **A `_buildService` throw during `load`/`newPlan` in service** (parked)
  leaves the controller half-replaced. The edge predates 2b and the spec
  is silent on it. Unreachable for a design that just decoded.

The rest of the ledger's deferred minors stay as the final review triaged
them ("can wait"). They are loaded-file edges with no generated FILL or
non-ATTRIB entity, test-kit oracles (`entryTop`, `rowSeatTransform`,
`samePayload`, M-UL-turn), the ruled E5G identity check, the
host_words/plan_kit parser duplication, the two `unit:` word-namespace
nits to revisit with R4, the inspector's unreachable generated branch,
`editor_options_test` importing a test as a library, `_buildService`'s
untested constructor-throw cleanup, the pick-allocation baseline and the
PA1-PA3 Transform2 oracle gap (A12), the restore's unreachable
apply-failure path, the VE18 reorder, `plan_editor.dart`'s length, the
`snappingAllowed` asymmetry (revisit with multi-view hosts) and barrel B5.
The "1501" count slip is in a report only, not of record.
