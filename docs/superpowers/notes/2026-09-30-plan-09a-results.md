# Plan 09a results — the symbol library core

**Branch:** `plan-09/symbol-library-core`, cut from the plan's commit
`40157af` (the spec branch `spec-09/symbol-library` was cut from `main` at
`5022e32`). **Spec:** [2026-09-30-symbol-library-design.md](../specs/2026-09-30-symbol-library-design.md),
revision 3, amended at execution (its closing section). **Plan:**
[2026-09-30-symbol-library-core.md](../plans/2026-09-30-symbol-library-core.md).
**Ledger:** [`ledgers/2026-09-30-plan-09a/`](../ledgers/2026-09-30-plan-09a/)
(`progress.md` carries every ruling with its cost-if-wrong; the directory is
created by the branch's last commit, which archives the ledger, so the link
resolves only after that commit).

Sub-project 09 is sliced (spec decision 7); this is 09a, the core: two
undoable engine commands for definitions, `SymbolComponent`, the validating
`SymbolLibrary` loader, the placer (`placeSymbol`, `placementTransform`), 25
furniture symbols as data with a generator and the shipped `.jetlib` asset,
and an end-to-end test that a placed symbol is painted, picked, snapped,
saved and loaded correctly. There is **no UI** in 09a; the gallery,
thumbnails, search and the placement tool are 09b (unwritten).

Every task had a fresh implementer and an independent reviewer who re-ran
the gates and re-fired mutants. The final whole-branch review, which
precedes the ledger's archive, is not part of this note's source material.

| Task | Commits | Review |
|---|---|---|
| 1 Engine: `AddDefinitionCommand`, `RemoveDefinitionCommand` (D4) | `477138f`, `e96c9cc` (1b, test-only) | Needs fixes (major: Remove's capability and `touched` unpinned, both mutants green) -> 1b Approved |
| 2 `SymbolComponent` and its registration (D3) | `51a9bda` | Approved (minor: `fromJson` leniency per omitted field unpinned, closed by 2b, `5b9237f`; hashCode dropping tags is legal, no action) |
| 3 `SymbolLibrary`, the validating loader (D5) | `f9e4c33`, `5b9237f` (2b, test-only: SC6 per omitted field) | Approved (minor: zero-sweep tolerance unpinned, closed by 6b) |
| 4 The placer (D6) | `478c6dc` | Approved (info: a placement cannot mutate the library entry, unpinned, closed by 6b's P19) |
| 5 Content, generator, asset (D7, D2) | `81a3271`, `a5e38a0` | Approved (minors: outline closedness and per-symbol category unpinned, closed by 6c) |
| 6 End to end (F-7, P-6 item 2) | `ba812dd`, `22bc83d` (6b, test-only: sweep boundary R27b-e, read-only entry P19), `971eb76` (6c, test-only: outline and category tables) | 6 + 6b Approved (info: the end-to-end fixture is quarter turn 1 mirrored only); 6c folded into the final whole-branch review |

No `lib/` file changed after `a5e38a0` (Tasks 6, 6b and 6c are test-only).

## What the execution found that the spec did not

Each ruling is in the ledger with its cost-if-wrong.

- **R-T2-1:** the plan named `ParametricSystem.regenerate`; it does not
  exist (regeneration runs as the dispatcher's expander). SC10 checks
  `drift()`, `diagnostics()` and `validate()` around an edit instead. Test
  wording only.
- **R-T2-2:** purge never touches components (P-6 item 1, observed by SC11
  and SC12), and `RemoveDefinitionCommand` does not clear the component, so
  the placer's undo must include `SetComponentCommand<SymbolComponent>(h,
  null)`. It does (D6).
- **R-T2-3:** `CompoundCommand` needs a named `label`.
- **R-T3-1:** D5's "non-finite bulge" is void: a polyline here carries no
  scalars (straight segments only). The rule became "a polyline carries no
  scalars" (R20c) plus the generic finite-scalar check.
- **R-T3-2:** the codec silently repairs a definition cycle by dropping the
  instance that closes it, so a nested-instance rule alone cannot see one;
  the loader refuses any codec diagnostic (R08).
- **R-T3-3:** the loader adds two rules from D3 that D5 did not list: keys
  lower-case with no white space (R03, R03b) and tags lower-case (R03c).
- **R-T4-1:** reuse requires the definition to still exist. A
  `SymbolComponent` outlives a removed definition (neither
  `RemoveDefinitionCommand` nor purge clears it), and reusing such an orphan
  would make an instance name nothing (P13, mutant X-orphan).
- **R-T4-2:** `AddNodeCommand` does not check that the instance's definition
  exists, so a wrongly ordered compound is accepted on execute and fails only
  on undo. The placer's order is pinned by P5, P9 and P10.
- **R-T5-1:** D7's list adds up to 25 symbols (5 Dining, 5 Kitchen, 4 Bed, 4
  Living, 4 Bath, 3 Office), not "about 24".
- **R-T5-2:** the library document is `DraftDocument.empty()` +
  `registerAppComponents` + mm, not `prepareDocument` (which adds the DASHED
  record at handle 6; no leaf may use it). Leaf style: layer 0, BYBLOCK
  linetype, `ByBlockColor`, `kByBlock` lineweight and transparency, flags 0.
- **R-T6-1:** no engine or render defect: the first combined
  transform + style + paint + pick + snap test passed (F-7 closed; P-7 not
  triggered). The Select tool's move and rotation grips work on a placed,
  mirrored `InstanceNode` (P-6 item 2); an instance has no per-leaf reshape
  grips, by design (D3). `GripCache` and `OutlineCache` follow the change
  stream asynchronously, so a test yields (`Future.delayed(Duration.zero)`)
  before reading the box or pivot after a command.
- **The purge finding (P-6 item 1, SC11, SC12):** `DraftDocument.purge()`
  compacts the geometry store and entity slots, rewrites `geomIndex`,
  invalidates derived state and notifies; it never touches `components` or
  the tree. A component on a definition survives purge and is byte-identical
  before and after; an orphan component also survives. Nothing a save needs
  is lost: no fix.
- **The `validate()` finding (P-6 item 3, P15):** `validate()` on a saved
  plan with rotated, mirrored, coloured symbols and a second instance of one
  of them reports 0 diagnostics; the decoded plan validates empty and
  re-encodes byte-identical. `validate()` does not look at components, so a
  component on a definition, or an orphan one, is silent.
- **The grips finding:** see R-T6-1 above (P-6 item 2).
- **The BYBLOCK lineweight finding (R-T5-2 confirmed by Task 6):** a BYBLOCK
  leaf under a default-style instance resolves to `StyleContext.documentRoot`:
  ACI 7 (argb `0xFFFFFFFF` with the default foreground) and lineweight 25
  (0.25 mm). The end-to-end test's control places the same symbol at the
  default style and asserts `0xFFFFFFFF` / 25, so the coloured assertions
  (`0xFF33AA77` / 70) cannot pass at defaults.
- **M-09g and M-09p are equivalent, by experiment (Task 1).** M-09g1 (Add
  skips `invalidateDerived`): the file `+14` all passed and the whole engine
  suite showed only the 2 standing failures; M-09g2 (Remove skips it): same.
  M-09p (Add `touched: {}`): an empty `touched` set falls back to
  `rebuildAll`, so the index is unaffected; the whole suite stays green apart
  from the direct assertion the task added on Add's `touched` (which makes
  the mutant red but not through the index). M-09p2 (Remove `touched: {}`)
  was green until Task 1b pinned it. The calls stay.
- **The environment.** Flutter was not preinstalled: 3.47.2 was installed at
  `/root/flutter` from `storage.googleapis.com`. The container restarted
  during execution (Task 3's first implementer was lost with three untracked
  files, which the replacement read in full and re-derived from D5; Task 4's
  review was written in two parts around a restart, the first marked
  PARTIAL). `flutter pub get` rewrites `packages/jet_cad/analysis_options.yaml`;
  it was never staged. Outbound access goes through the agent proxy, which
  refuses deleting remote branches (the plan's exit gate names merged remote
  branches for the human to delete); no other proxy or remote fact is
  recorded in the reports.

## Gates of record (Linux container, `CI=true`)

Baseline at `40157af`: engine 1,106 + 2 standing, app 596; the render
baseline count was not recorded (the ledger left it to the final sweep).

- **engine** 1,121 + 2 standing (`test/testing/generate_document_test.dart`:
  "the default document is the one Plan 2 measured, byte for byte" and "both
  text fractions default to zero and change nothing"); +15 from
  `definition_commands_test.dart`; analyze and format clean. No engine file
  changed after `e96c9cc`.
- **render** 974 + 1 skip + 7 standing text ladders; unchanged by the branch;
  analyze and format clean (last run in full at `22bc83d`'s Task 6 report and
  its review).
- **app** 780 (`971eb76`, Task 6c's report; 596 + 12 + 46 + 5 + 24 + 85 + 8 +
  4 = 780); analyze and format clean.
- **web** `CI=true flutter build web --release`: `Built build/web`
  (Task 6 report, after `22bc83d`; the generator asset is at
  `build/web/assets/assets/library/furniture.jetlib`, 33,423 bytes).
- **The two allocation invariant tests** are unedited: `git diff 40157af HEAD
  --stat` over `packages/jet_cad_2d/test/invariants` and
  `packages/jet_cad_2d_flutter/test/invariants` is empty (checked when this
  note was written). Their green run is part of the engine and render suites
  above.
- **`lib/symbols/` greps:** no `dart:io`, `dart:ui` or `package:flutter`
  import (only comments that say so). `analysis_options.yaml` is not in
  `git diff 40157af HEAD --stat`.
- **The asset:** `dart run tool/generate_furniture_library.dart` prints
  `wrote assets/library/furniture.jetlib: 33423 bytes` and leaves `git
  status` clean (Task 5's review); the committed bytes equal the built
  library (a test pins it).

## Mutants

**P-8 (the controller's ruling, recorded in the ledger).** The plan's "re-run
every mutant of Tasks 1-6 in the final tree" is replaced by: this table is
compiled from each task's report and independent review, both of which fired
real runs at the task commit, and the final whole-branch review re-fires a
sample across every task. Reason: after Task 5 no `lib/` file changed
(`git diff a5e38a0..HEAD -- apps/floor_planner/lib packages` is empty), so
the task-time results describe the final tree. Cost if wrong: a mutant that
went green only because of a later test edit; the review's sample and the
diff check bound it. **The sample and its result are not in this note.**

**The P-8 sample (the final whole-branch review, on the tip `bdca1ed`, a fresh
reviewer; 20 mutants, all red, each file restored with `diff` exit 0):**

| Task | Mutant | Red tests |
|---|---|---|
| 1 | Remove drops the owner guard (`commands.dart:480`) | "refuses while a leaf is owned by it", "extents follow a compound placement and its undo" |
| 1 | Add drops the children guard (`:430`) | "refuses a definition that lists children, and mutates nothing" |
| 1 | Remove drops the instance/parent guard (`:472`) | "refuses while an instance names it", "while a node is parented to it" |
| 1 | Add drops the duplicate-definition arm (`:425`) | "refuses a handle that names a definition, a node or an entity" |
| 2 | registration dropped (`catalog.dart:48`) | SC7, SC8, SC9, SC10, SC11 |
| 2 | tag-order equality ignored (`symbol_component.dart:86`) | SC1, SC2 |
| 3 | colour allow-list drops ByLayer (`symbol_library.dart:228`) | L5 |
| 3 | lineweight allow-list arm (`:232`) | L5 |
| 3 | flags check dropped (`:240`) | R18, R18b |
| 3 | children throw dropped (`:148`) | R04 |
| 3 | zero sweep `== 0` (`:291`) | R27b, R27c, R27d |
| 4 | M-09a no `-basePoint` (`symbol_placer.dart:51`) | P1 |
| 4 | M-09b never reuse (`:83`) | P7, P8c, P11, P15, P19 |
| 4 | M-09i leaves keep library handles (`:117`) | P5, P10, P11 |
| 4 | M-09o leaves reversed (`:114`) | P16, P19, P6 |
| 5 | a catalog radius edited, asset not regenerated | "the committed bytes equal the built library" |
| 6 | M-09c rotation dropped (`:49`), end-to-end file | the end-to-end test and "the Select tool moves and rotates a placed, mirrored instance" |

The reviewer also ran, on the tip, with a throwaway test (deleted): a symbol
placed under an installed `ParametricSystem` and a live `SpatialIndex` gives
no diagnostics, no drift and an empty `validate()`; undo restores the bytes,
the container count, the entity and node counts and the extents; redo gives
identical bytes; three placements survive `purge` with identical bytes; save,
load, save is byte-identical; placing on the loaded document reuses both
definitions.

Red test names are the tests' own ids; "first red" lines are in each task's
report. Spec ids first; `X-`/unnamed rows are the tasks' own extras. Every
run restored the file (`diff` exit 0).

| Id | Where | Red test | Task |
|---|---|---|---|
| M-09q1 Remove drops the instance/parent "named by" guard | `commands.dart:472` | "refuses while an instance names it" and "...while a node is parented to it" | 1 |
| M-09q2 Remove drops the entity-owner guard | `commands.dart:480` | "refuses while a leaf is owned by it" | 1 |
| M-09r1 Add drops the non-empty children guard | `commands.dart:430` | "refuses a definition that lists children" | 1 |
| M-09r2/r3/r4 Add drops the definition / node / entity arm of the duplicate check | `commands.dart:425-426` | "refuses a handle that names a definition, a node or an entity" (each) | 1 |
| X-raise Add drops `handleSeed.raiseTo` | `commands.dart:438` | "raises the handle seed past a handle it is given" | 1 |
| X-cap Add capability geometry | `commands.dart:417` | "capability is structure and touched names the handle" | 1 |
| X-inv / X-inv2 / X-rmstate / X-rmunknown | `commands.dart:441, 488, 485, 469` | add/undo/redo, pick, extents, undo-value and unknown-handle tests | 1 |
| Remove capability geometry; Remove `touched: {}` | `commands.dart:460, 489` | "RemoveDefinitionCommand capability is structure and touched names the handle" (green before 1b) | 1b |
| M-09u-a tag order ignored by equality | `symbol_component.dart:86` | SC2 | 2 |
| M-09u-b toJson swaps category and key | `symbol_component.dart:58` | SC5 | 2 |
| registration omitted; `PageComponent.register` dropped | `catalog.dart:48`, `:46` | SC7-SC12; SC9 | 2 |
| equality drops name / version / tag length; tags not copied; version < 0 and empty key accepted; missing field tolerated | `symbol_component.dart:83, 85, 89, 44, 48, 45, 75` | SC1; SC3; SC4; SC6 | 2 |
| engine `toJson` skips unknown payloads; `purge()` also clears components | `component.dart:151`; `draft_document.dart:204` | SC8; SC11, SC12 | 2 |
| fromJson tolerates a missing key / name / category / tags / version, each alone | `symbol_component.dart` | the matching SC6 case, each on its own | 2b |
| SC10 (no parametric interference) | - | **unfired**: a guard with no mutant | 2 |
| M-09j, one mutant per D5 rule (29 throw sites, 29 rules and sub-rules): unreadable bytes, codec cycle repair, instance, group, no component, duplicate key+version, key case, tag case, children, basePoint, leaf owner, text/fill/attrib, point, layer, linetype, text style, colour, lineweight, transparency, flags, linetypeScale, malformed payload, coordinate, scalar, zero-length line, polyline < 2, circle radius, arc radius, zero sweep | `symbol_library.dart:91-292` | R00, R08, R06, R07, R01, R02, R03/R03b, R03c, R04, R05, R09, R10, R11, R12-R19, R20-R20c, R21-R21d, R22-R27 (one or more each) | 3 |
| M-09a no `translation(-basePoint)` | `symbol_placer.dart:51` | P1 | 4 |
| M-09b every placement copies | `:83` | P7, P8c, P11, P15 | 4 |
| M-09c rotation dropped / mirror dropped | `:49`, `:50` | P1, P2, P4 / P1, P4 | 4 |
| M-09d colour, lineweight, transparency, linetype, linetypeScale dropped | `:135-139` | P8 (its own field) and P8c, each | 4 |
| M-09e `AddDefinitionCommand` omitted | `:98-103` | P6-P13, P15, P16 (10 red) | 4 |
| M-09f1 instance command first | `:124` | P5, P9, P10, P16 | 4 |
| M-09f2 component attached without `SetComponentCommand` | `:103-113` | P5, P9, P10, P17 | 4 |
| M-09h lookup ignores version | `:82` | P11 | 4 |
| M-09i leaves keep the library's handles | `:117` | P5, P10, P11 | 4 |
| M-09n `rotation(q * pi/2)` | `:49` | P3, P4, P14 | 4 |
| M-09o descending leaf handles | `:114/117` | P6, P16 | 4 |
| M-09t `#n` suffix loop deleted | `:94-96` | P12 | 4 |
| M-09v translation applied before scale (R.T.S) | `:50-51` | P1 | 4 |
| X-orphan orphan component reused; `-0.0` not normalised | `:83`; `:52` | P13; P3, P14 | 4 |
| and the review's own: q not modulo, name not `key@version`, basePoint dropped, component/leaf fields altered, leaves reversed, instance parent/layer/label | `symbol_placer.dart` | P2; P11/P12/P15; P6; P6; P6, P16; P6, P5 (instance parent = definition: `CycleDetectedError` across the suite, not one named assertion) | 4 review |
| bed.double basePoint (0,0), asset regenerated | `furniture_catalog.dart` | "every base point is off the origin" | 5 |
| every leaf forced to a point, regenerated | `build_library.dart` | decode, placement and size tests (`leaf 13 of 12 is a point`) | 5 |
| catalog edited, asset not regenerated; pubspec asset removed; duplicate key; tag upper-cased; size slip | catalog, `pubspec.yaml` | "the committed bytes equal the built library"; "the asset is declared in the pubspec"; "built library decodes"; same; "plausible size" | 5 review |
| all rectangles open; `bed.single` category swapped (both green at Task 5) | `_rect`, catalog | closed-count and outline tests; category table ("Expected 'Bed Room', Actual 'Kitchen'") | 6c |
| M-09c rotation / mirror, M-09a, identity transform | `symbol_placer.dart:49, 50, 51, 129` | end-to-end painter ("leaf 0 vertex 0"), pick, snap, Select test | 6 |
| M-09d colour, lineweight | `:135, :136` | end-to-end "leaf 0 colour" / "leaf 0 weight" | 6 |
| zero sweep `== 0`; `.abs() <` strict; no `.abs()` | `symbol_library.dart:291` | R27b, R27c, R27d; R27d; R27e | 6b |
| payload `coords[0] += 1` / `scalars[0] += 1` in the copy loop | `symbol_placer.dart` | P19 | 6b |
| M-09g1, M-09g2, M-09p2 | `commands.dart:438, 485, 488` | **equivalent, recorded** (M-09p1 red only through the direct `touched` assertion) | 1 |

Notes on the table. The end-to-end rows were also run against temporary
copies of the test with the painter block removed (and then painter and pick
removed): pick catches M-09a and identity, and the snap assertion alone
catches M-09a. Two attempted mutants at Task 1 and several at Task 4 did not
compile or were no-ops and are not counted. Three Task 3 sites (91, 131, 168)
cannot be "delete the throw" (flow analysis) and use `rethrow`/`continue`;
the Task 3 review did not re-fire the two `continue` variants. Named mutants
of the spec that are not 09a's: M-09k, l, m, s, w, x are 09b's (see below).

## Found, not fixed

- **The duplicate checks of `AddEntityCommand` and `AddNodeCommand` still
  ignore definitions** (spec D4, D14): seed-allocated handles never collide
  with a definition and the placer hands them no other.
- **`AddNodeCommand` does not check that the instance's definition exists**
  (R-T4-2): a wrongly ordered compound fails only on undo.
- **A component outlives a removed definition** (R-T2-2, SC12): neither
  `RemoveDefinitionCommand` nor purge clears it; only the placer's own undo
  does, and `validate()` does not look at components.
- **A found definition is reused even if its leaves were edited** (D14).
- **The real `rootBundle` load is untested until 09b:** the tests read the
  asset through `File('assets/library/furniture.jetlib')`; the pubspec
  declaration is pinned by a regex test.
- **End to end only at quarter turn 1, mirrored.** Quarter turns 0, 2, 3 and
  the unmirrored case are covered by the placer tests P1-P4, not end to end;
  each symbol is also placed at turns 1 (plain) and 3 (mirrored) with
  `validate()` empty and extents containing `at` (Task 5).
- **Survivors recorded by reviews:** Task 1 review finding 2 (the pick test
  proves the index is wired to command changes, not the touched-definition
  structural arm: equivalent per F-13); the `hashCode` dropping `tags` is
  legal; Task 4 found no mutant that changes the compound's reported
  capabilities without another test failing.
- The Task 5 review's taste note: the tub's drain is at the left and the tap
  at the right end.
- Carried from earlier, untouched: the live-object-rule note's list.

- **The "4 seats" and "6 seats" dining tables draw no chairs** (the final
  review's worst content issue): `_table` in `furniture_catalog.dart` is a
  rectangle with an inset, so the names promise seats the geometry does not
  show. The content is the human's to judge; a rename or chairs are a
  catalog change and a regenerated asset.
- **A circle or arc radius is only checked finite**, not bounded by the
  loader's coordinate limit (a radius of 1e300 loads): a nit, no symbol is
  affected.

## Owed to 09b

- **M-09w** (the tool skips the `components` capability): the placer's
  compound reports `{structure, geometry, components}` (asserted in P5) and a
  denied `components` (P17) or a read-only document (P18) refuses and changes
  nothing; the tool's own permission check before allocation is 09b's test.
- **Search (D8)**, M-09l and M-09s; **gallery and thumbnails (D9)**, M-09k and
  M-09x; **the placement tool (D11)**, M-09m; **the panel (D12)**.
- **`R`/`M` key consumption while armed** and the ghost using
  `placementTransform`.
- The real `rootBundle` load of `assets/library/furniture.jetlib`.
- **Contrast of BYBLOCK leaves on a light canvas:** under a default-style
  instance they resolve to ACI 7 (`0xFFFFFFFF` with the default foreground);
  09b's thumbnails and ghost must check them on both themes.
- **The human's look for 09b (copied from the spec's Exit gate; never marked
  done for them), macOS and web (Chrome, Firefox):** the gallery's look in
  light and dark; category collapse; the search box takes focus and typing
  fires no shortcut, `Esc` returns focus to the canvas; thumbnails are sharp
  on a Retina display; the ghost follows the pointer and snaps; a
  press-drag-release places (and on a touch screen or a simulated touch);
  `R`, `M`, `Esc`; two placements, then undo twice and redo; saving and
  reopening a plan with symbols; an older-version plan opens and its symbols
  stay.

## The human's look

**09a: none needed.** There is no UI in this slice: nothing in it can be
looked at. Nothing is marked done for the human. The list above is 09b's.
