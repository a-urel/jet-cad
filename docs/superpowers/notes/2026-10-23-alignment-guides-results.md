# Alignment guides: results

Branch `claude/alignment-guides-50cacb` (base `46e95ed9`), done on the branch,
**not merged, not pushed**. Spec:
[2026-10-23-alignment-guides-design.md](../specs/2026-10-23-alignment-guides-design.md)
(revision 3, approved); plan:
[2026-10-23-alignment-guides.md](../plans/2026-10-23-alignment-guides.md);
spec and plan review record:
[2026-10-23-alignment-guides-spec-review.md](2026-10-23-alignment-guides-spec-review.md).
Executed task by task with Sonnet implementers and no reviewer subagents (the
human's rule): the controller read every diff, ran its own mutation and
re-ran the gates. The ledger (`.superpowers/sdd/2026-10-23-alignment-guides/`,
git-ignored) is archived before the merge.

## What was built

Alignment guides (edges, centres, equal spacing) that show and snap while
movable objects are dragged or placed, in design mode (moves, symbol
placement) and in service mode (a waiter dragging tables or a group). Alt
(Option on macOS) suspends them. On by default; `PlanEditor`,
`PlanServiceView` and `PlanCanvas` take `alignmentGuides`;
`PlanController.alignmentGuides` is a `PlanGuideSettings`; each bar has a
toggle (`PlanEditorAction.guides`, `PlanServiceAction.guides`; keys
`toolbar-guides`, `service-guides`); the look is `PlanTheme.guideOnLight`,
`guideOnDark`, `guideWidth` and `PaperPalette.guide`. A guide beats a pointer
object-snap hit in a guide-eligible drag (C-8); an attachment still wins.

## Commits (`git log --oneline 46e95ed9..HEAD`)

```
8791fe80 test(integration): pin-exact-landing tests opt out of alignment guides
64a64199 docs: CHANGELOGs for alignment guides
744387b3 feat(restaurant_demo): alignment guides on show
0a7bb083 docs: alignment guides in the host guide and the probe
f256b9d8 test(plan): the guide allocation invariant in CI time
2eb1a2c6 test(plan): alignment guides add no allocation per event
dafb06b5 perf(plan): a service drag re-aims on a camera change without allocating
8e9e2b1e fix(architecture_demo): the title yields the guides toggle its 800 px room
d515b90b feat(plan): alignment guide toggles in both bars
ed8bc6e5 feat(plan): alignment guide options on the views
8df6a2ab fix(plan): a band still takes Alt under service guides
185f706b feat(plan): alignment guides in service drags
4942a0c8 fix(plan): the placement marker and Alt mid-press under guides
eb6f8d0b feat(plan): alignment guides while placing a symbol
da43f3c3 feat(plan): alignment guides in design moves
09d04ccd feat(plan): PlanGuideSettings and the guide theme fields
794b7798 test(plan): a nested symbol is no guide reference
d291024f feat(plan): alignment guide reference cache
4165befb test(plan): pin the solver's sign tie and the continuing pair's overlap
87b7d574 feat(plan): alignment guide solver
5513ade0 feat(flutter): SelectTool.moveAdjuster seam
92a23caf feat(flutter): PaperPalette.guide for alignment guides
4d9dac91 docs(plan): alignment guides plan, Copilot review folded in; spec amended (P-1, P-2)
b7b8d559 docs(plan): alignment guides implementation plan
85976444 docs(spec): alignment guides approved
66dd2fd3 docs(spec): alignment guides rev 3, Copilot review folded in
9721ee59 docs(spec): alignment guides rev 2, OpenCode review folded in
7adbca00 docs(spec): alignment guides in both modes (draft)
```

(The first six are the spec and plan; the code starts at `92a23caf`.)

## Per task: what landed, tests, named mutations

Every mutation below was applied, shown red, and reverted; the test counts are
the implementers' reports, re-checked by the controller's own mutation.

**Task 1, `PaperPalette.guide` (`92a23caf`, jet_cad_2d_flutter).** `guide`,
`guideColor`, `lightGuide`, `darkGuide`, `withGuide`; `==`, `hashCode` and
`withSelection` carry it. Mutations: `withSelection` drops the guide; `==`
ignores it; the luminance fallback inverted. Controller's own: `withGuide`
ignoring its argument, 2 tests red.

**Task 2, `SelectTool.moveAdjuster` (`5513ade0`, jet_cad_2d_flutter).** The
generic `MoveAdjuster` seam (`begin`, `adjust`, `suppress`, `paint`, `end`,
`changes`), 13 tests (MA1-MA13). Mutations: `moveTo` on the chain point (MA4);
`orthoBase` always passed (MA5); `suppress` not called (MA11); Alt key not
re-targeting (MA8); `end` skipped (MA1, MA2); `paint` not gated on attachment
(MA11); `_lastTouch` not stored (MA7, MA10); `changes` listener never added
(MA12) or never removed (MA12 strengthened, survived first). Controller's
own: Alt key state forced false, MA8 red; `orthoBase` always null, MA5 red.

**Task 3, the solver (`87b7d574`, `4165befb`, jet_cad_2d_plan).**
`solveGuides`, `GuideSolution`, `GuideReferences`; 20 tests with fixtures
shifted off the origin. Mutations: `>=` for the aperture; edge/centre tie
flipped; the `<= eps` gap filters removed; `freeX` ignored; recheck removed or
reading the raw box; moving-set skip removed; line merge removed; the
continuing pair's perpendicular overlap removed (added in fix round 1).
Controller's own: the sign tie-break in `_beats` and the overlap in `_outer`
survived at first, which sent the fix round. See Rulings for the two
unreachable cases.

**Task 4, the reference cache (`d291024f`, `794b7798`, jet_cad_2d_plan).**
`GuideReferenceCache`, `worldBoxOf`; 11 tests; the deviation: a box is that of
the definition's **direct leaves** (`UnitIndex`'s rule), so nested-instance
geometry is not in a box and a symbol nested in a group is not a reference
(spec amendment P-2). Mutations: seat filter removed; parent transform
dropped; never invalidated; hidden root group, own visibility and layer
(non-unit and unit) ignored; three corners instead of four; the root-parent
check removed (added in fix round 1). Equivalent mutants: the ATTRIB skip and
the table-revision key. Controller's own: a nested non-unit instance counted
as a reference survived, fixed.

**Task 5, `PlanGuideSettings` and the theme fields (`09d04ccd`,
jet_cad_2d_plan).** `PlanGuideSettings`, `PlanController.alignmentGuides`,
`PlanTheme` guide fields through every method. Mutations: `on` ignoring
`allowed`; the allowance notified synchronously; `lerp` dropping `guideWidth`;
the light colour on a dark paper; validation removed. Controller's own:
`toggle()` without `notifyListeners`, red.

**Task 6, design moves (`da43f3c3`, jet_cad_2d_plan).** `PlanMoveGuides`
(the `MoveAdjuster`), `GuidePainter`, the session's guide state; 19 tests
(DG-1 to DG-15 and painter tests). Mutations (M1-M19): object-snapped
short-circuit; ortho pin inverted; fallback from the raw point; `begin`
ignoring `movable`; `suppress` not clearing; the aperture not divided by the
scale; touch ignored; Alt ignored; the setting ignored; the uncaptured axis
overwritten (survived until DG-15); the box shifted by the chain delta, or not
shifted; seats as references; the overhang along screen x, absent; the tick
along the span; a stale tail not cleared; the mark axis swapped; `movable`
always true. See Rulings for the survivor.

**Task 7, placement (`eb6f8d0b`, `4942a0c8`, jet_cad_2d_plan).**
`PlanSymbolTool` solves in `_syncPlacement` (pointer, camera, R, M, re-arm);
12 tests (PG-1 to PG-12). Mutations: attachment on the guided transform; the
placement committing the unguided anchor; the box not recomputed on a turn or
a mirror; the solve removed or only in `_update`; touch ignored; the Alt key
handler off; pointer Alt ignored; the settings listener not added; a guide
painted though attached; `ghostAt` unguided; x always the raw pointer; the
marker at the unguided anchor and Alt key-down mid-press ignored (fix round 1).
Equivalent mutant: writing the uncaptured axis as `raw + fallback`.

**Task 8, service (`185f706b`, `8df6a2ab`, jet_cad_2d_plan).** `ServiceTool`
drag solves, a camera listener only while a guide-eligible drag lives;
the SG-* tests. Mutations: `_reset` without `_endGuides`; a listener added with
guides off; `_dx/_dy` without the offset; self-snap (`moving: const {}`); no
settings listener; the Alt key handler disabled; touch ignored; `dispose`
without `_endGuides`; the cache keeping seats; `_aim` ignoring eligibility;
pointer Alt ignored; the Alt branch returning ignored in a band (fix round
1). Controller's own: `_reset` without `_endGuides`, SG-cancel red.

**Task 9, view options (`ed8bc6e5`, jet_cad_2d_plan).** The three
`alignmentGuides` options, the allowance (one owner per mounted view, no reset
on dispose), the stroke from the theme; 5 tests (M-GV-1 to M-GV-5).
Mutations: a dispose reset added; `PlanEditor` not passing the value on; the
stroke from `selectionWidth`; the canvas swap reset removed; the service swap
reset removed. Controller's own: the `didUpdateWidget` write removed, M-GV-3
red.

**Task 9b, bar toggles and strings (`d515b90b`, `8e9e2b1e`).** The two enum
values, the toggle in both bars (`IconButton.isSelected`), the `alignmentGuides`
string in en, de, tr; 8 tests. Mutations: the editor command inside the undo
gate; the editor and the service `selected` read once; the service group
switch putting `guides` in group 1. Pinned bar tests grew with the enums.
Controller's own: the editor toggle's `run` made a no-op, `guide_bar_test`
red. See Rulings for the architecture demo's title width.

**Task 10, the allocation invariant (`dafb06b5`, `2eb1a2c6`, `f256b9d8`).**
`test/invariants/guide_allocation_test.dart` (GA1-GA7): design move of 1 and 3
tables, placement, service 1 and 3, the painter, the solution's buffers;
control, guides off and guides on, at 10 and 200 references. `perf`: the
service camera re-aim no longer allocates two `Vector2` per change. Mutations:
`Paint` per paint call; `drawLine(Offset, Offset)`; a `Float64List` of
candidates per solve; `raw.clone()` kept in a field; `Set<Handle>.of` per
service event; `_reaim` back to `screenToWorld(Vector2)`; the buffer capacity
+1 and reallocated in `reset()`. Controller's own: an escaping `Float32List`
per paint, GA6 red (a non-escaping one is elided by the JIT, see Rulings).
The file runs in 1:31 under the VM service (5:05 before fix round 1).

**Task 11, docs, demo, CHANGELOGs, gate (this task).**
- `docs/host-guide.md` section 10.1 and the probe (`0a7bb083`): three
  snippets (`PlanEditor(alignmentGuides: false)`, `controller.alignmentGuides`
  with a listener, `PlanTheme(guideOnLight: ..., guideWidth: 2)`);
  `check_guide`: all 38 blocks in the probe; the probe resolves, analyzes and
  builds as CI does.
- `apps/restaurant_demo` (`744387b3`): `alignmentGuides: true` explicit,
  `guideWidth: 1.5` in the POS look's two `PlanTheme`s (the view override
  `kPosViewOverride` and the Standard look are pinned by `look_test`, so the
  width sits in the ambient extension), `test/guides_test.dart` (GD1: the bar
  toggle in design and service, the controller's switch; GD2: the theme width).
  Mutations: `alignmentGuides: false` in the demo and `guideWidth: 1` in the
  theme, both red. The Terrace already has a row of three tables at y 7000
  (round, round, high table); no table was added.
- CHANGELOGs (`64a64199`).
- `8791fe80`, a fix this branch owed: see Rulings (Task 11).

## Rulings (verbatim from the ledger)

- Ruling: Task 3's solver lives in jet_cad_2d_plan (not jet_cad_2d) as the spec says — keeps engine API unchanged before 1.0 — cost if wrong: a later move to the engine.
- Ruling: the sequential-vs-simultaneous recheck mutation is not killable (implementer's argument: a failed spacing recheck implies the other axis took an edge capture, so the orders agree) — the code does the simultaneous version the spec states — cost if wrong: an untested corner where two spacing captures interact.
- Ruling: plan's "40 references on one line -> lineCount == 16" is unreachable (step 6 draws only zero-offset candidates and merges equal coordinates: at most 3 lines per axis); the test checks merging and the bound instead — cost if wrong: capacity guards untested.
- Ruling: F1 (the negative-before-positive tie) is unreachable with distinct handles — every earlier key (|o|, kind, pair, handle, second handle) already separates two candidates — kept as written, untested — cost if wrong: none observable.
- Ruling: the ATTRIB skip in the bucketing pass is redundant (boxOfLeaves skips attributes) but kept per the brief; the label test pins the behaviour — cost if wrong: none.
- Ruling: the table-revision key is subsumed by the identical-UnitIndex check; kept to mirror the brief — cost if wrong: none.
- Ruling: `movable`'s root-parent check survives its mutation — a SelectTool move's handles are root-level captures, so a nested instance never reaches begin(); the check stays as a guard — cost if wrong: a nested generated unit dragged alone would get guides.
- Ruling: the gap-mark tick reaches 4 px to each side (8 px across), the implementer's reading of "a short perpendicular tick (4 px)" — cost if wrong: a one-constant change (kGuideTickPixels = 2).
- Ruling: DG-14 (attachment) is tool-level, since the plan package has no restaurant kit; fixtures use the fx kit — cost if wrong: attachment path covered only by the seam test.
- Ruling: writing an uncaptured axis as raw + (at − raw) is numerically the same as copying at for nearby doubles; the captured-only write stays, pinned by M11 — cost if wrong: an ulp on the uncaptured axis.
- Ruling: test/support/service_host.dart's serviceController defaults guides off (opt in with guides: true) — four existing service tests (TG-G8, G12, G14, VE8) stand tables in rows and pin landings without guides; their assertions are untouched — cost if wrong: those suites no longer exercise the default (guides on) path; the guides suite does.
- Ruling: implementer wrote code before tests (TDD order broken); red evidence is the compile failure plus 11 mutations — accepted, no rework — cost if wrong: none observable.
- Ruling: the architecture demo's DC12/DC12c 800 px floor stays (spec 12a D7); raising it to 840 px is an assertion weakened — the toggle must fit: compact the toggle first, else compact the demo's own open-sample button — cost if wrong: a slightly smaller hit target on the toggle.
- Ruling: pinned bar tests (ED-4, O23, TB7, the enum name tables) updated to the grown enums and button sets — legitimate growth, not weakening — cost if wrong: none.
- Ruling: Task 9b space for the toggle comes from the architecture demo's _DocumentTitle max width (144 px lowered), the toggle stays uniform with the other toolbar buttons; DC12/DC12c unchanged at 800 px — cost if wrong: a long file name is cut 40 px sooner in the demo.
- Ruling: the invariant meters with a per-epoch floor and asserts least(on) − most(off) ≤ 0.05/event over rounds, not the brief's single on−off subtraction — the JIT's escape analysis toggles the baseline's own Transform2/Vector2 between runs — cost if wrong: a small real regression hidden inside the noise band.
- Ruling: a bare List of candidates and a non-escaping Vector2 clone are invisible to the meter (the JIT elides them); escaping allocations and Float64List/Set are watched — cost if wrong: an elided allocation that stops being elided would go unseen.
- Ruling: Task 11 `jet_cad_2d_integration`: the package's own `recording_plan_strings.dart` copy lacked the new `alignmentGuides` string (analyze error, two suites failed to load), and four tests that pin exact landings (`against_wall_rotate_test.dart` three tests, `wall_attach_tool_test.dart`'s rig) landed aligned because guides are on by default. The copy gained the getter; `mountEditor` gained `alignmentGuides` (default true) and those tests pass `false` (the rig toggles it off); no assertion changed - cost if wrong: those suites no longer exercise the default (guides on) path.
- Ruling: Task 11 `apps/restaurant_demo`: the guide width sits in `kPosPlanLight`/`kPosPlanDark` (the ambient extension), not in `kPosViewOverride`, because `look_test` pins the view's `theme:` as `PlanTheme(selectionWidth: 3)` under the POS look and null under Standard; so the Standard look draws guides at the default 1 px - cost if wrong: the Standard look shows 1 px guides.

- Ruling: the growth check compares guides-on at 200 refs with the baseline envelope (max of on@10, off@10, off@200 + budget) — JIT elision of the baseline's own Vector2/_Float64List varies by round, so on@10 alone is a flaky bound; a per-reference allocation still fails by orders of magnitude — cost if wrong: a growth below ~100 objects per 250 events hidden.

## Deferred minors

- Task 5: minor (deferred): guide_settings.dart header cites a spec section "The setting" that does not exist ("Turning them off"); the controller's guides import sits out of alphabetical order.
- Task 9: minor (deferred): two earlier full runs showed "did not complete" flakes (barrel_test, editor_modes_test F-3), a clean rerun after — watch in the exit gate.
- Task 10: minor (deferred): in one GA[134] run GA3 stayed green under the Float64List-candidates mutation while GA1/GA4 went red (red alone); the merged pointer/camera windows share one allowance.
- Task 11: `packages/jet_cad_2d` fails the two standing `generate_document_test` fingerprint tests on this macOS run (`tool/ci/standing_failures.txt` lists them); the package is untouched by the branch.

## Gates (real last lines)

Run from the worktree at `8791fe80` (plus this note and STATUS).

```
packages/jet_cad_2d:      dart test: 00:09 +1343 -2: Some tests failed.
                          (failing: test/testing/generate_document_test.dart, "the default document is the
                          one Plan 2 measured, byte for byte" and "both text fractions default to zero and
                          change nothing"; both in tool/ci/standing_failures.txt; no other failure)
                          dart analyze: No issues found!
                          dart format: Formatted 188 files (0 changed) in 0.53 seconds.
packages/jet_cad_2d_flutter: flutter test: 00:29 +1470 ~1 -7: Some tests failed.
                          (7 failures = text_ladder rungs 1-5 and text_lod_ladder rungs 1-2, all standing)
                          flutter analyze: No issues found! (ran in 3.1s)
                          dart format: Formatted 235 files (0 changed) in 0.49 seconds.
packages/jet_cad_2d_gpu:  flutter test: 00:01 +20: All tests passed!
                          flutter analyze: No issues found! (ran in 3.2s)
                          dart format: Formatted 10 files (0 changed) in 0.01 seconds.
packages/jet_cad_2d_plan: flutter test --enable-vmservice: 02:24 +1754: All tests passed!
                          flutter analyze: No issues found! (ran in 3.6s)
                          dart format: Formatted 339 files (0 changed) in 0.85 seconds.
packages/jet_cad_2d_integration: flutter test: 01:29 +240: All tests passed!   (after 8791fe80; before it: +235 -6)
                          flutter analyze: No issues found! (ran in 5.8s)
                          dart format: Formatted 83 files (0 changed) in 0.28 seconds.
packages/jet_cad_2d_kit:  flutter test: 00:07 +409: All tests passed!   analyze: No issues found!   format: 94 files (0 changed)
packages/jet_cad_2d_kit_architecture: 00:22 +661: All tests passed!   analyze: No issues found!   format: 138 files (0 changed)
packages/jet_cad_2d_kit_restaurant:   00:03 +184: All tests passed!   analyze: No issues found!   format: 22 files (0 changed)
apps/restaurant_demo:     flutter test: 00:48 +114: All tests passed!   analyze: No issues found! (ran in 3.8s)   format: 42 files (0 changed)
apps/architecture_demo:   flutter test: 01:02 +176: All tests passed!   analyze: No issues found! (ran in 6.4s)   format: 44 files (0 changed)
tool/ci:                  dart test: 00:56 +114: All tests passed!
                          dart run tool/ci/check_guide.dart: docs/host-guide.md: all 38 code blocks are in the host probe
                          dart run tool/ci/check_readmes.dart: package READMEs: all 2 code blocks are in the probes
                          dart format --language-version=3.6 (host_probe/lib): Formatted 1 file (0 changed)
host probe:               tool/ci/host_probe.sh "file://$PWD" "$(git rev-parse HEAD)" at 0a7bb083:
                          Analyzing host_probe... No issues found! (ran in 3.8s)
                          Compiling lib/main.dart for the Web... 34.0s  ✓ Built build/web
                          host probe: no GPU renderer, no build hook; build/web is  42M
dart pub publish --dry-run: jet_cad_2d_plan: Package has 0 warnings.   jet_cad_2d_flutter: Package has 0 warnings.
```

### Controller re-run after Task 10's fix round 2 (`8fa0db2e`)

The controller's own exit-gate run first failed GA1 once in a full plan run
(the growth check against guides-on at 10 references, a JIT-elision artefact);
fix round 2 compares against the baseline envelope. Then:

- implementer, three full plan runs: `03:33 +1754: All tests passed!`,
  `03:48 +1754: All tests passed!`, `04:13 +1754: All tests passed!`
- controller, full plan run: `02:44 +1754: All tests passed!`; analyze `No issues found!`
- controller: integration `01:20 +240: All tests passed!`; restaurant_demo
  `00:27 +114: All tests passed!`; architecture_demo `01:40 +176: All tests
  passed!`; tool/ci `01:03 +114: All tests passed!`; jet_cad_2d_flutter only
  the standing text-ladder rungs.

## Release note

`jet_cad_2d_plan` depends on `jet_cad_2d_flutter: ^0.7.3` and the guides use
`SelectTool.moveAdjuster` and `PaperPalette.guide`, which are new in
`jet_cad_2d_flutter`'s Unreleased section. **`jet_cad_2d_flutter` must be
published (as 0.7.4 or 0.8.0, the human's call: the change is additive, so
a patch is defensible) before the plan library's floor is raised to it and
before `jet_cad_2d_plan` is published.** No pubspec was changed on the
branch; `dart pub publish --dry-run` for both packages reports 0 warnings.
The plan's changelog asks hosts to read three things: guides are on by default
(pinned landings need `alignmentGuides.toggle()` or `alignmentGuides: false`),
the two enums grew, and C-8.

## Open questions

- Version numbers: `jet_cad_2d_flutter` 0.7.4 or 0.8.0, and `jet_cad_2d_plan`
  0.9.1 or 0.10.0 (a behaviour change for hosts: on by default, grown enums).
- The Standard look of the restaurant demo draws 1 px guides; the POS look 1.5.
  Say so if the Standard look should show the showcase width too.
- The `shadcn_ui` session restyles the two toggles; they are plain
  `IconButton`s with a selected state, as the spec asks.
- Whether `guideOnLight`/`guideOnDark` need a contrast check against
  `canvasBackground`: not done; the built-in magenta was checked against both
  canvases (spec).
