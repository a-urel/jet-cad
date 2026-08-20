# SDD ledger — plan: docs/superpowers/plans/2026-08-17-jet-cad-2d-plan-3c-text.md

Spec: docs/superpowers/specs/2026-08-17-jet-cad-2d-plan-3c-design.md (binding authority)
Worktree: /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-3c, branch plan-3c
Baseline at a7008a6: 667 engine tests, 123 widget tests (1 skipped, 8 goldens), analyze/format clean.
Note: `flutter pub get` rewrites three analysis_options.yaml files in this repo; they must never be committed.
Note: TodoWrite is unavailable in this session, so this ledger is the only progress record.

## Pre-flight scan — cross-task pairs

| Pair | Produces → consumes | Finding |
|---|---|---|
| T0 → T1 | record fields → `toJson`/`fromJson` keys | clean |
| T0 → T4, T6, T10 | `textAt`/`tagAt`/`textStyleAt`/`textAttrsAt` → bounds, pick, paint | clean |
| T1 → T7 | fingerprint re-baseline → corpus fractions | ordering deliberate: the four codec keys move the fingerprints, so T1 re-baselines before T7 changes the corpus |
| T2 → T3 | `TextMetrics`, `kNominalTextPixels`, `kCapHeightRatio` → geometry | clean |
| T2 → T4 | T2 stubs `entityBounds`' text case; T4 replaces it | intentional, and both tasks say so |
| T3 → T4, T6, T10 | `resolveTextAttributes`, `textLocalTransform`, `textLocalBounds` | clean |
| T4 ↔ T5 | overlay test needs `SetEntityTextCommand` | known hazard: test lands skipped in T4, unskipped in T5 |
| T8 → T9 | `CanvasDrawSink.text` needs the paragraph cache | known hazard: throws `UnimplementedError` until T9; painter does not call it until T10 |
| T8 → T10 | `TextOp`, `DrawSink.text` → painter | clean |
| T9 → T10 | `paragraphFor`, sink constructor gains the measurer | clean; T9 also threads it from `DraftCanvas` |
| T9 → T12 | `kParagraphCacheLimit` → distinct-key measurement | T12 may move the limit; see Ruling 4 |
| T10 → T11, T12 | text drawn → goldens, rig counters | clean |
| T2 → T6 | `measure()` on the pick path | covered by T2's memoisation requirement and the allocation harness |

## Pre-flight scan — per-task self-agreement

| Task | Finding |
|---|---|
| T0 | test references a `_textRecord` helper it does not define — implementer writes it (Ruling 5) |
| T1 | clean; the v3 fixture string must match the codec's actual required top-level keys, implementer adjusts |
| T2 | test references a `_style` `TextStyleRecord` it does not define — Ruling 5. Static metrics cache keyed by length only is called out in the plan as wrong if a second model exists; T4's measurer-dependence test needs two models, so key by the ratios too |
| T3 | **plan defect**: uses `Transform2(a,b,c,d,e,f)` — correct, the positional const ctor exists |
| T4 | **plan defect**: `boxOfLeaf(slot)` returns `Aabb2?`, so the test needs `!` |
| T5 | **plan defect**: `CommandResult.rejected`/`.applied` do not exist |
| T6 | **plan defect**: `Transform2.inverted()` does not exist; `SnapMask.only()` does not exist |
| T7 | clean |
| T8 | clean |
| T9 | `Paragraph.debugDisposed` must be confirmed against this Flutter version before the eviction test relies on it |
| T10 | test helpers (`paintOnce`, `expectSamePicture`, `_docWithOneLabel`) — reuse the existing ones in `test/support/`, do not invent parallel ones |
| T11-T14 | clean |

## Rulings

Ruling 1: `Transform2` has `invert()`, not `inverted()` (`transform2.dart:109`), and it throws `SingularTransformError`. Task 6 uses `invert()`. Cost if wrong: a compile error the implementer fixes in one line.

Ruling 2: commands signal invalid input by **throwing** (`AddEntityCommand` throws `DuplicateHandleError`), and `CommandResult` is `const CommandResult({required inverse, required touched})` with no factories. `SetEntityTextCommand` therefore throws `StateError` on an unknown handle or a non-text kind, and returns a plain `CommandResult`. It must also call `target.invalidateDerived()`, which is how `AddEntityCommand` dirties derived state — that call, not a bespoke notification, is the plan's "index-dirty" requirement. Cost if wrong: a command that silently no-ops instead of throwing, caught by the command test.

Ruling 3: `SnapMask.only(SnapKind.insertion)` does not exist; use `SnapMask.none.with_(SnapKind.insertion)` (`snap.dart:39-62`). Cost if wrong: a compile error.

Ruling 4: `kParagraphCacheLimit` is owned by Task 9 and may be raised **once**, in Task 12, only with the measured distinct-visible-key count recorded beside it. Lowering `attributedInstanceFraction` instead is equally acceptable. What is not acceptable is relaxing the zero-new-layouts gate row. Cost if wrong: a gate row that passes because the corpus was thinned rather than because the cache works — visible in the results note either way.

Ruling 5: test snippets in the plan that reference an undefined local helper (`_textRecord`, `_style`, `_plain`) are shorthand, not placeholders: the implementer writes the helper in the test file. Cost if wrong: nothing — the alternative reading is a compile error the implementer must fix regardless.

Ruling 6: `ContainerIndex.boxOfLeaf` returns `Aabb2?`. Tests dereference with `!` and a null box is a test failure, not a skip. Cost if wrong: a null-check crash that names the right problem anyway.

## Task log

Task 0: complete (commits a7008a6..c3eccba, review clean). 669 engine tests.
Task 0: minor (deferred): the round-trip and purge tests exercise `_text` but not `_tag`/`_textStyle`/`_textAttrs` through `read()`/`purge()`; reviewer verified both wire all four correctly by reading the source, so this is thin coverage rather than a defect. Plan-mandated — the snippets are the brief's.
Task 1: complete (commits c3eccba..7f85226, review clean). 671 engine tests. Fingerprints re-baselined with old and new values recorded in the report; structural assertions beside them untouched and verified by the reviewer.
Task 2: complete (commits 7f85226..2a868b9, review clean, 1 important carried forward as Ruling 8). 675 engine tests.
Task 3: complete (commits 2a868b9..4c12fd4, fix round 1/5: 1 addressed, 0 open). 686 engine tests. The fix was test-only; the re-review confirmed the RED evidence is concrete (exactly one test failed when the cross term was dropped) and that no production code changed.
Task 3: implemented at de3ef5e (685 engine tests). Review verdict: Needs fixes — 1 Important. The implementer generalised the justification offset beyond the brief's sketch (adding the shear cross-term `c*refY`); the reviewer independently re-derived it and confirms the generalisation is correct **and** that no existing test can distinguish it from the sketch. Fix round 1 dispatched to the original implementer: add a crossed-case test (non-baseline vertical justification with non-zero oblique), hand-derived expectation, RED first by deliberately dropping the term.
Task 3: Ruling 9: the review's ⚠️ item — `TextStyleRecord`'s defaults, which live outside the diff — is resolved by the controller, not the fix loop: `widthFactor: 1.0`, `obliqueAngle: 0.0`, `fixedHeight: 0.0` (`tables.dart:233-238`), so the v3-payload test's assumption holds. Cost if wrong: the v3 test would assert the wrong defaults, which the codec round-trip tests would not catch.
Task 2: Ruling 8: the reviewer flagged, as Important and plan-mandated, that `MetricModelMeasurer`'s memo builds a fresh 5-tuple record key per `measure()` call, which may allocate. It is not a Task 2 defect — `query_allocation_test` does not exercise `measure()` today, and the key shape is the brief's own. I am not opening a fix loop on Task 2 for it. Instead the obligation moves to **Task 6**, which is the task that first puts `measure()` on the pick path: Task 6 must run `query_allocation_test` with text present and, if the record key allocates, replace it with a per-instance precomputed key or a nested map. Cost if wrong: Plan 2's zero-allocation budget is quietly spent on the pick path, which the allocation harness catches in Task 6 rather than in Task 2.
Task 2: minor (deferred): `MetricModelMeasurer._cache` is a static, unbounded, never-evicted map; acceptable for an engine-test measurer but the accepted-tradeoff note lives only in the report, not in a doc comment.
Task 4: Ruling 10 (corrects Ruling 6): `ContainerIndex.boxOfLeaf` reads the packed R-tree only (`container_index.dart:745` -> `_leaves.boxOfPayload`). Dirtying a leaf removes it from the packed tree and parks it in the overlay, so after an edit `boxOfLeaf` returns null **correctly**. Ruling 6 ("a null box is a test failure") holds only for a clean index. Any test that reads a box after an edit must use the codebase's own idiom from `spatial_index.dart:2326`: `index.boxOfLeaf(slot) ?? index.dirty.boxOf(slot)`. This defect is in both the Task 4 and Task 5 brief snippets. Verified at source: with the overlay accessor the incremental box is `Aabb2(1000.0, 1942.857142857143 .. 3985.714285714286, 2228.5714285714284)`, bit-identical to the rebuilt box, so the production overlay path is correct and only the test accessor was wrong. Cost if wrong: nothing — the alternative reading is a null-check crash, which is exactly what the interrupted run hit.

Task 4: Ruling 11: Tasks 4 and 5 land as one dispatch. An interrupted Task 4 run left uncommitted work that implements both — `entityBounds`' text case, all four production call sites, every test call site, and `SetEntityTextCommand` — because the Task 4 overlay test needs the command and the implementer chose to write it rather than land the test skipped. Reverting working code to restore the task boundary buys nothing. Both briefs' full obligations still bind, and the work commits in two commits, command first (Task 5) then bounds (Task 4), so no intermediate commit is red. Cost if wrong: one review package spans two tasks instead of one, which the reviewer is told about.

Task 4/5: implemented at 0ad927b (Task 4) + 8a3f2b5 (Task 5), 691 engine tests. Review verdict: spec compliance satisfied, task quality needs fixes — 1 Important defect plus 3 Important test gaps. The implementer swapped my commit order (Task 4 first, not Task 5 first); both the implementer and the reviewer verified independently that the order I asked for leaves the first commit red, because Task 5's brief-mandated box-widening assertion is unsatisfiable before Task 4's bounds fix. The swap stands.

Task 6: complete (commits 419d512..3515a72, review approved with 3 Minors, all taken). 710 engine tests, 123 widget. The anchor x/y swap now fails `test/index/pick_test.dart: a pointer inside a text box hits it as a fill` at the unit level, not only through the differential; the main fill fixture moved to `(300, 20)` with probes straddling the left edge. `TextLayout` is `@internal` — this lint set does not raise `invalid_export_of_internal_element`, so the barrel is untouched and the annotation carries the intent.

Task 8: complete (commits 09f6f6a..c381e24, review approved). 716 engine tests, 127 widget (123 + 4 new) + 1 pre-existing skip. The `UnimplementedError` hazard holds as designed: `CanvasDrawSink.text` is the literal throw, no production caller reaches it, nothing was skipped or stubbed to route around it. The implementer proactively found the brief's Step 1 fixture degenerate on `resolved` — both sides shared one `_resolved` constant, so dropping `resolved` from `TextOp`'s equality left it green — and added a varying-field test. Reviewer confirmed that by mutation.

Task 8: Ruling 20 (carries to Tasks 9 and 10): the reviewer found a genuine divergence between the spec and the plan that no earlier ruling covered. Spec "Phase B — the render path" (SS453-457) specifies `drawText(String text, Handle style, Transform2 local, ResolvedStyle resolved)`, and "Getting the matrix onto the canvas" (SS486-498) argues at length for a **second reusable `Float64List(16)`** in `CanvasDrawSink` to compose `residual . local` without a per-text-entity allocation on the frame path. The plan instead drops `local` and has the painter push an already-composed `residual . textLocal` through the existing `beginResidual`. I keep the plan's shape: `draw_sink.dart` already carries `beginResidual(Transform2, {Handle debugHandle})`, so a second buffer is new machinery for a cost the painter already pays elsewhere — `draft_painter.dart:401-403` does a per-leaf `.multiply()` for circles and arcs today, and Plan 3b's own budgets are per-candidate allowances (Transform2 10, Aabb2 7), not literal zero. But the interface shape must not silently foreclose the spec's design: **Task 10 must measure per-text-leaf allocation on the paint path and record the number.** If it exceeds the per-leaf norm circles and arcs already establish, Task 10 reintroduces the spec's second `Float64List(16)`. Cost if wrong: a per-text-leaf `Transform2` allocation ships unmeasured, which is precisely the frame-path claim this plan's exit gate is supposed to substantiate.

Task 8: Minor parked, carried into Task 9's dispatch: the drop-the-unit-images mutation fails with a `RangeError` rather than a value mismatch, which is adequate RED evidence but weak documentation. `expect(points.length, 3)` in the new flatten tests states the invariant directly. Also recorded: the implementer's *reason* for adding a rotation/shear fixture was wrong — swapping the two unit images is undetectable only when the transform's columns are equal, i.e. a degenerate map, so the brief's pure-scale fixture does catch the swap structurally, not by coincidence. The added fixture is still a strict improvement and stays.

Task 7: complete (commits 3515a72..09f6f6a, fix round 1/5: 5 addressed, 0 open). 716 engine tests, 123 widget. No scoped re-review dispatched: I verified at source that the fix is test-only — `git diff 2f18a02..09f6f6a --name-only` touches one file, `test/testing/generate_document_test.dart`, and no `lib/` path — and each of the five fixes names the mutation and the test that went red under it, so the fix round is self-verifying in a way a production-code change would not be. Task 7 had already carried two full reviews. Cost if wrong: a weak assertion survives in a test file, which the whole-branch review still sees.

Task 7: implemented at 2f18a02, 715 engine tests. Review verdict: implementation correct and unbreakable — the reviewer re-ran all four claimed mutations plus a symmetric attribute-gate one and all five failed named tests — but the fixtures are weaker than the implementer believed: five of the reviewer's own six mutations survived. Fix round 1 dispatched.

Task 7: Ruling 17: the brief's own `expect(labels.length, lessThanOrEqualTo(20))` is a degenerate assertion — it is satisfied by 1, so `_kLabelVocabulary[extra.nextInt(...)]` -> `_kLabelVocabulary[0]` passes all 17 tests while collapsing the corpus to a single distinct label. That destroys "the distribution the cache hits", which is the exact property Task 12's distinct-visible-key measurement and Ruling 4's zero-new-layouts gate row are taken against, and it also removes `labelFraction`'s only draw from `extra`, leaving the shared-stream coupling pinned by prose on the label side. Since the assertion is the brief's, the correction is mine: tighten to `expect(labels.length, 20)`. The reviewer measured the real generator at 20 distinct labels for both the 2000 and 20000 cases, so the exact assertion holds today. Cost if wrong: an exact count is brittle if the vocabulary or the draw changes, which is a loud failure rather than a silent one — the failure mode this plan has now shipped three times is the opposite.

Task 7: Ruling 18: the implementer's three self-raised items are all resolved in its favour and need no change. (a) Its claim that the brief's mutation #1 is untestable as literally written is true — at defaults nothing downstream consumes `extra`, so a discarded draw provably cannot move a written value, and the "gate fails to gate" substitution is the form a real bug takes. The reviewer additionally verified the attribute half is pinned by test, not inspection. (b) Replacing the blank `_addFloorText` entities rather than adding labels on top is correct: additive genuinely yields 21 distinct strings, and nothing depends on those blanks — the only non-generator consumer of text/attrib kinds is `benchmark/overlay_fill.dart:49`, which counts kinds and never inspects content. (c) The +/-100/+/-50 offsets sit inside `_addSymbolEntity`'s +/-500 definition footprint, so attributes cannot distort definition bounds or R-tree shape, and the constant ATTRIB tag is semantically right rather than a shortcut — in DXF the tag is the attribute definition's key, shared across every INSERT, while the value varies per insert, which is exactly what was implemented.

Task 7: Ruling 16: the brief's Step 1 snippet says `<the Task 1 value>` for the fingerprint, which is a placeholder, not a value. The requirement it stands for is that the two fractions default to zero and change nothing, so the implementer reads the fingerprints currently asserted in `generate_document_test.dart` (Task 1 re-baselined them at 7f85226) and asserts they are unchanged. A fingerprint that moves at defaults is a failure, not a re-baseline. Cost if wrong: a silently re-baselined fingerprint would hide a corpus change, which the structural assertions beside it — one layer, three linetypes, every entity ByLayer on layer zero — would only partly catch.

Task 6: implemented at 6e046f8, 710 engine tests. Review verdict: approved, spec compliance satisfied, no Critical or Important findings, 3 Minors taken in a follow-up. Ruling 8's debt is paid and was real: the record key allocated 41.5 `_Record`/call on the pick path; the memo is now per-instance and length-keyed, which costs `MetricModelMeasurer` its `const` ctor across 12 test sites and also removes a global cache that leaked between tests. `_Record` joined the watched set (added only — `_depthBoundClasses`/`_depthBoundBudgets` untouched) and was proved RED by restoring the old memo. Oracle independence verified in both directions: the index composes and solves a 2x2 against a closed interval, the oracle maps four corners forward and tests edge cross products, and mutating *only* the oracle turns the differential red.

Task 6: Ruling 14: the implementer deviated from the brief's Step 3 snippet, which allocates four objects per text candidate, by adding a mutable reusable `TextLayout` to `text_geometry.dart` and making Task 3's three functions thin wrappers over it. The deviation stands. A hand-inlined copy inside the index is exactly the drift `text_geometry.dart` exists to prevent, and the reviewer's N2 mutation (descent -> 0 in the shared helper) confirms the shared path carries its own coverage. Only the *public* export was more than the task needed, which `@internal` settles. Cost if wrong: one more exported name than the plan anticipated, reversible in one line.

Task 6: Ruling 15: the reviewer's own N4 mutation — swapping the anchor's x and y — passes every unit pick test and is caught only by the differential, because four of the nine new fixtures anchor at (0,0) and the attrib's (2,3) shifts by less than its probe radius. That is the degenerate-fixture class this project treats as dominant, and later tasks build on these fixtures, so it is fixed now rather than parked. Cost if wrong: nothing; a strongly asymmetric anchor is a strictly stronger fixture.

Task 4: complete (commits 4c12fd4..419d512, fix round 1/5: 4 addressed, 0 open). 697 engine tests, 123 widget.
Task 5: complete (same range; Ruling 11 lands both tasks as one unit). The re-reviewer independently re-ran all four mutations rather than trusting the implementer's RED claims, and each one failed the named new test: the missing-STANDARD extents test crashes under the old `!` pattern, the `fixedHeight` override test fails under a bare STANDARD lookup, both justification tests fail under forced `textAttrs: 0`, and the laid-out-extents test fails under a hard-coded `text: ''`. `_fallbackTextStyle` was confirmed to be a genuine `static const TextStyleRecord`, not a disguised second table lookup. The overlay-equals-rebuild test still compares all four coordinates and still guards `rebuilt.maxX - rebuilt.minX > 0`, so it cannot pass on two degenerate boxes. Both optional Minors were taken.

Task 4/5: Ruling 12: the `?? tables.textStyles[ReservedHandles.standardTextStyle]!` fallback is the brief's own expression (Task 4 Step 3), so its crash is mine to rule on, not the implementer's defect. It is a real regression: `JsonCodec._loadTables` clears the seeded defaults (`json_codec.dart:179`) and `TableSection.remove` is public, so a document whose `textStyles` omits handle 5 now crashes on plain `doc.extents` — the reviewer proved it with a probe on a document containing only a line, and before this change the parameter was a `Handle` that was never dereferenced. Fix: one accessor, `TextStyleRecord DraftDocument.textStyleOf(Handle)`, falling back to a `const TextStyleRecord`, never to a table lookup with `!`. This also retires the verbatim duplication across four production and four test sites — sites that must agree or the differential oracle goes quiet. Cost if wrong: a const fallback silently substitutes STANDARD's metrics for a style a document genuinely lost, which is the same visual outcome as the `!` version minus the crash.

Task 4/5: Ruling 13: the three unpinned-behaviour findings are genuine defects, not brief-mandated, and must be fixed in this round. The reviewer demonstrated each by mutation with the suite still green: replacing the per-entity style lookup with a bare STANDARD lookup (691/691 green — no fixture has a text entity whose style is not STANDARD, so `fixedHeight`/`widthFactor` resolution, the stated reason the signature changed at all, is untested and so is the `??` branch); forcing `textAttrs: 0` at all four sites (691/691 green — every fixture is default left/baseline); and hard-coding `text: ''` at `draft_document.dart:231` (both suites green — and that is the site zoom-to-fit reads). This is the degenerate-fixture failure class this project's testing notes name as dominant. Cost if wrong: nothing; each fix is a strictly stronger fixture.

Task 0: Ruling 7: the brief's test snippet named `ReservedHandles.root`, which does not exist — `ReservedHandles` has `layerZero`, `byLayerLinetype`, `byBlockLinetype`, `continuousLinetype`, `standardTextStyle`, `firstFree` (`style.dart:104-113`). A document's root handle is allocated, not reserved. The implementer substituted `const Handle(100)`, matching the file's existing `lineRecord` convention; that stands. Later tasks that need a real owner inside a document use `doc.rootHandle`. Cost if wrong: nothing — a bare store test has no root node to own anything.

Task 9: complete (uncommitted work from an interrupted run, closed here). 716 engine tests, 133 widget (128 + 5 new) + 1 pre-existing skip. `Paragraph.debugDisposed` is confirmed to exist in this Flutter version, which retires the per-task scan's open question on Task 9.

Task 9: Ruling 21: the implementation was already written when this session picked the task up, so the plan's "write the failing tests" step could not be honoured literally. The controller's ruling, taken with the human partner rather than alone, is that **a named mutation is the RED** — each test was landed, then the specific defect it exists to catch was introduced into working code, the test was watched to fail, the mutation reverted and the test watched to pass. That is stronger evidence than a from-scratch RED, which only proves a symbol is missing and cannot distinguish one test's obligation from another's. The alternative considered and rejected was deleting the 208-line implementation and rebuilding it: it would have discarded two allocation-conscious decisions the brief does not specify — the reusable `_probe` key that keeps a cache *lookup* allocation-free for `query_allocation_test`, and `kMetricsProbeArgb`, which lets `measure()` share the colour-keyed cache without inventing an entry per colour. Cost if wrong: the evidence chain for this one task rests on mutation rather than on absence, which the whole-branch review can re-run in full — every mutation is recorded below with its exact failure.

Task 9: the four mutations, each applied to working code, run, and reverted:

| # | Mutation | Result |
|---|---|---|
| M1 | `_CacheKey.==`/`hashCode` drop `argb` | **killed** — `two colours is two entries`: `Expected: <2> Actual: <1>` |
| M2 | return a fresh `TextMetrics` on a cache hit | **killed** — `a repeat request lays out nothing`: `Expected: true Actual: <false>` |
| M3 | `_evictOldest` no longer calls `paragraph.dispose()` | **killed** — `eviction disposes the paragraph`: `Expected: true Actual: <false>` |
| M4 | lay the paragraph out at `kNominalTextPixels / 4` | **SURVIVED on the brief's own test**, see Ruling 22 |

Task 9: Ruling 22: M4 is the mutant the plan's Task 13 singles out as the one a green suite most plausibly misses ("Lay the paragraph out at the effective em size instead of nominal... if nothing fails, add the assertion that makes it fail before moving on"), and it survived the brief's fourth test verbatim — `expect(metrics.ascent, greaterThan(0))` and `expect(metrics.advanceWidth, greaterThan(0))` are satisfied by *every* positive em size, so the one property this class must never get wrong was pinned by nothing. That is the degenerate-assertion class Ruling 17 already corrected once in Task 7, in the same plan. Following the plan's own instruction, the assertions are now exact: `flutter_test`'s font is 0.75em ascent / 0.25em descent / 1em per character, measured in this session, so `WC` at the nominal size is ascent 75.0, descent 25.0, advance 200.0. M4 re-run against the strengthened test is **killed**: `Expected: a numeric value within <1e-9> of <75.0> Actual: <18.75>`. Cost if wrong: a Flutter upgrade that changes the test font's metrics fails this test loudly, which is the direction this plan has repeatedly chosen over a silent pass.

Task 9: Ruling 23 (a defect found by the mutation work, fixed under TDD): `FlutterTextMeasurer.measure(text: '')` returned `advanceWidth = -3.4028234663852886e+38` — `Paragraph.longestLine` is -FLT_MAX for a paragraph with no lines. **-FLT_MAX is finite**, so no `isFinite` guard downstream would have caught it. `MetricModelMeasurer` returns `0.0` for the same input, so the two implementations of the `TextMeasurer` seam disagreed, and the differential oracle's whole premise is that they are interchangeable. The blast radius is the bounds path, not the draw path: Task 10's planned `if (record.text.isEmpty)` guard protects drawing only, and `entityBounds` shipped in Task 4 with no `isEmpty` guard of its own, so an empty text entity would have handed `doc.extents` and the R-tree a box 3.4e38 wide — zoom-to-fit to infinity. Fix: `advanceWidth` now shares the `lines.isEmpty` guard that `ascent` and `descent` already used, which is a one-condition change and makes the two measurers agree. A new test, `an empty string measures zero, not the negative float floor`, was written first and watched to fail against the real defect (`Expected: <0.0> Actual: <-3.4028234663852886e+38>`) before the fix; it also asserts the two measurers agree, so a future divergence in either direction fails. Cost if wrong: nothing — both measurers now return 0.0, which is what every caller already assumed.

Task 9: carried to Task 10: Ruling 23 fixed the measurer, **not** `entityBounds`. An empty text entity now contributes a zero-width box at its anchor rather than a poisoned one, which is correct for bounds, but Task 10 still owes the draw-path guard its own brief specifies. Task 10 should also confirm no test asserts a *non-zero* box for empty text.

Task 10: complete. 717 engine tests (716 + 1 new allocation gate), 143 widget (141 + 2 added during the mutation round) + 1 pre-existing skip. Both suites green, both analyze and format clean.

Task 10: Ruling 24: the brief's Step 3 snippet opens a **second, inner** `beginResidual` inside the one `_drawLeafComposed` has already pushed. `CanvasDrawSink.beginResidual` does not nest — it overwrites `_residual` and `endResidual` clears it back to the identity (`canvas_draw_sink.dart:87-117`), so the inner pair would leave the outer residual at the identity for everything after it. The plan's own prose is the correct reading ("through the **existing** `beginResidual`"): text is routed out of `_emit` entirely, before any residual is pushed, and `chain . textLocal` is pushed once. Cost if wrong: nothing here; the alternative shape would have needed a residual stack in every sink.

Task 10: Ruling 25: the snippet's anchor is `payload.pointAt(0)`, unrebased, while the residual it is composed into already carries `translate(localOrigin)`. The anchor has to be rebased like every other coordinate that reaches `chain`. This is invisible at the origin and wrong everywhere else — the degenerate-fixture class again, and the reason the Task 10 fixtures anchor at (300, 20) inside a document whose rebase origin is non-zero. Proved by mutation three ways (M2, M13, M15 below).

Task 10: Ruling 26: **the brief's Step 4 is wrong and the assertion does not flip the way it says.** It states that on the default corpus text now draws, so `skippedTextCount` is 0. It is not: `generateDocument`'s `_addFloorText` sets no `text`, so every text entity in the default corpus carries the empty string, and the brief's *own* Step 3 guard (`if (record.text.isEmpty) { _skippedText++; break; }`) therefore skips all of them. The two halves of the brief contradict each other. Resolution: the counter keeps its `greaterThan(0)` on the default corpus but its *meaning* changes from "the model has no text content" to "this entity has nothing to hand `Canvas`", and the root test now asserts both halves — blank corpus skips and emits no `TextOp`, `labelFraction`-on corpus skips nothing and emits over a hundred. A bare `greaterThan(0)` would have passed just as well against a painter that never learned to draw. Cost if wrong: nothing; the test is strictly stronger than either single assertion.

Task 10: Ruling 27: the brief's mirror assertion — "the determinant stays negative" — has the sign backwards for this codebase's camera. `ViewportTransform.fit` flips y (`d = -s`), so an **unmirrored** text residual is already left-handed and `lessThan(0)` passes on a corrected drawing too. The property that actually says "not corrected" is that the sign is the *opposite* of the same text's unmirrored twin, and that is what the test asserts, against two documents differing only in the sign of one scale factor. Cost if wrong: the brief's literal assertion is satisfied by exactly the behaviour it was written to forbid.

Task 10: Ruling 28 (a defect the brief does not mention at all): `Canvas.drawParagraph` lays glyphs out in **paragraph space** — y increasing downward from the top of the first line — while the residual the painter composes maps **glyph space**, y up with the origin on the baseline, because that is the space `textLocalBounds` and therefore `entityBounds` are expressed in and the camera has already flipped y once on the way there. Nothing reconciled the two, so every string rendered **mirrored about its own baseline**, 75 px (one nominal ascent) off, while every box in the document stayed right. No bounds test, pick test, golden-free differential or op-count assertion can see this: the `TextOp` and its residual are correct: it is only what `dart:ui` does with them that is wrong. Fixed in `CanvasDrawSink.text` — `save`, `translate(0, alphabeticBaseline)`, `scale(1, -1)`, draw, `restore` — and deliberately *not* in the painter: it is a fact about `drawParagraph`, not about the document, and `reference_walk` composes the same residual by an independent route and must not have to know it, or the two would share exactly the assumption the oracle exists to test. Two tests pin it: one composes everything the sink pushed and checks the baseline lands on the residual's origin with the line above it and a descender below, the other pins `Paragraph.alphabeticBaseline == TextMetrics.ascent`, which is the equality the flip and the glyph box each depend on separately. Cost if wrong: the flip is one `save`/`restore` pair per text leaf, which the sink already pays for every other primitive through `_pushTransform`.

Task 10: Ruling 29 (a second pre-existing defect, in the oracle): `reference_walk` never reached an **instance-owned ATTRIB**. Its `_collect` treats an instance as a recursion boundary and reads `leavesByOwner[definition]`; a leaf whose owner is the *instance node* — which is what a DXF attribute is, and what `attributedInstanceFraction` generates — is in `leavesByOwner[instanceHandle]` and was never queried. `ContainerIndex` gets this right and says so at length (`container_index.dart:194-210`). It was invisible while the walk skipped every text and attrib kind at the top of `_leaf`; turning text on surfaced it immediately as "the painter drew `text:ATTR00010` and the reference did not". The walk now adds those leaves to the *enclosing* container under the instance's composed transform, which is what the index does, so they sort among their siblings by handle exactly as the draw order requires. Cost if wrong: the oracle would be silently blind to every attribute in every document, which is the failure an oracle exists to prevent.

Task 10: Ruling 30: `expectPainterSupersetOfReference` could not run at a **cropping** camera, and the plan's Step 1 asks for exactly that (`workingSetCamera`). The painter culls against index boxes carrying narrow-phase slack, in container space, against a clip inflated by 32 px; the reference culls against exact entity bounds in root space against the viewport itself. An entity whose geometry falls a fraction of a pixel outside the frame edge is therefore drawn by one and dropped by the other and **both are right** — measured on this corpus: a circle 0.29 px below the bottom edge, and a polyline 20 px below it. The helper reported that as "a wrong drawing, not loose culling". It now takes `edgeBandPx`, which excludes a band along the inside of the frame from the *extra-ops* half only; the superset half — everything the reference drew, the painter drew — is never relaxed, and the default stays 0 so every existing caller keeps the tight reading. The painter's clip inflate also stopped being an anonymous local and became `kScreenClipInflate`. Cost if wrong: a wrong drawing that lands entirely within 4 px of the frame edge escapes the cropped-camera run; it does not escape the fit-camera run beside it.

Task 10: Ruling 31 (**Ruling 20 discharged, with numbers**). Measured with the existing `AllocationMeter`, 20,000 warm iterations then 20,000 measured, in `packages/jet_cad_2d/test/invariants/text_paint_allocation_test.dart`:

| path | allocations per leaf | what they are |
|---|---|---|
| the chain every residual-path leaf composes | **1.00** | one `Transform2` (the VM scalar-replaces the two intermediates) |
| a text leaf through `resolveTextAttributes` + `textLocalTransform` | **9.00** | `Transform2` 2, `TextLayout` 2, `_Float64List` 3, `ResolvedTextAttributes` 1, `Vector2` 1 |
| a text leaf as the painter now does it | **0.87 - 1.00** | one `Transform2`, the residual itself |

So the wrapper form is **nine times** the per-leaf norm, which is well past Ruling 20's threshold. The fix is not the spec's second reusable `Float64List(16)` in `CanvasDrawSink` — under the plan's shape the sink composes nothing, so that buffer has no work to do — it is the one the engine's own pick path already made: fill a single long-lived `TextLayout` in place instead of letting the two allocating wrappers build one each. That took the text leaf to **at or below** the norm, and the residual `Transform2` is the one allocation neither path can avoid, since `DrawSink.beginResidual` takes an immutable one.

Doing it required dropping `@internal` from `TextLayout`. That annotation's stated reason was that the query path was the only caller with an allocation budget; the frame path — in another package, and the subject of this project's first non-negotiable — is a second, and an annotation that forbids the fix for a budget in another package is encoding an assumption rather than a rule. The ownership rule ("nothing may hold a reference to a `TextLayout` it did not fill itself") is unchanged and is what still binds.

Every assertion in that gate is a **ratio** against the measured norm, not an absolute count: this profiler was observed once, in a full concurrent suite run, to report 0.07 per leaf where two other runs of the same code reported 1.00 — the low-read artefact `vm_allocation_meter.dart` documents — and that artefact scales all three loops together.

**Known limitation, carried to Task 12:** the gate lives in the engine suite because `jet_cad_2d_flutter` has no `vm_service` dependency and cannot reach `AllocationMeter`, so it measures the engine helpers the painter calls, in the painter's order, rather than the painter itself. A painter that went back through the wrappers would **not** turn it red. Proved by mutation both ways: mutating the measured sequence back to the wrappers fails it at 9.00 (M17), and mutating the painter alone does not. Task 12 owns the measurement infrastructure and can close this by moving `AllocationMeter` into `jet_cad_2d/lib/src/testing/`.

Task 10: Ruling 32: `generateDocument` gained a `measurer` parameter, defaulting to the `InsertionPointMeasurer` every earlier caller already got implicitly, so no fingerprint and no `extents` moves. It is needed because a corpus with `labelFraction` on and the zero measurer is a corpus that *looks* like it covers text and does not: every glyph box collapses to a point and every text transform to a singular matrix, and a differential run over it compares nothing.

Task 10: the mutation round. Seventeen mutations, each applied to working code, run, and reverted. **Three survived**, all of the degenerate-fixture class this project treats as dominant, and two of them are Ruling 13's exact class recurring one plan later:

| # | Mutation | Result |
|---|---|---|
| M1 | painter drops the empty-text guard | killed — `an empty text entity draws nothing`: `Expected: empty Actual: [TextOp(, 5)]`, and the root test at `Expected: a value greater than <0> Actual: <0>` |
| M2 | painter composes an unrebased anchor | killed — `lands the glyph box where the bounds say`: `Expected: within <1e-6> of <20.0> Actual: <4046.398797416171>` |
| M3 | painter passes `textAttrs: 0` | killed — same test, `Actual: <338.50419672881776>` |
| M4 | walk drops instance-owned ATTRIBs | killed — the differential: `the painter drew text:ATTR00010 ... and the reference did not` |
| M5 | sink drops the glyph-space flip | killed — `drawn in glyph space, y up`: `Expected: within <1e-9> of <0.0> Actual: <-75.0>` |
| M6 | sink flips but does not lift to the baseline | killed — same test, `Actual: <75.0>` |
| M7 | walk drops the empty-text guard | **SURVIVED** — see below |
| M8 | walk composes `textLocal . chain`, wrong order | killed — the differential: `Expected: <14039> Actual: <1258>` |
| M9 | painter measures the wrong string | killed — the box test, `Actual: <335.6689997856083>` |
| M10 | painter resolves STANDARD, not the entity's style | **SURVIVED** — see below |
| M11 | painter hands the sink the wrong style handle | killed — `Expected: <30> Actual: <5>` |
| M12 | walk resolves STANDARD, not the entity's style | **SURVIVED** — see below |
| M13 | walk composes an unrebased anchor | killed — three tests |
| M14 | walk passes `textAttrs: 0` | killed — two tests |
| M15 | painter passes a zero rebase origin to the text path | killed — four tests |
| M16 | text ignores the instance placement | killed — four tests, including the mirror one at `Expected: a value greater than <0> Actual: <-0.9871622654018621>` |
| M17 | the allocation gate's measured sequence goes back through the wrappers | killed — `Expected: <= 1.5505 Actual: <9.00035>` |

Task 10: Ruling 33: the three survivors and what they cost.

- **M7** (the walk drawing empty text) survived because the corpus cannot carry a blank text entity at all: `labelFraction` *replaces* the blank floor texts one for one rather than adding to them (Ruling 18(b)'s deliberate choice), so a corpus with real strings has none left. Fixed by a hand-built fixture with one blank and one real label, asserting the walk emits exactly `['STAIR']` — which also pins the direction the superset assertion forbids, since a walk that drew the blank would emit a `TextOp` the painter never emits.
- **M10** and **M12** (painter and walk resolving STANDARD instead of the entity's own style) survived for exactly the reason Ruling 13 records for Task 4/5: **every text fixture in the suite, generated and hand-built alike, is on STANDARD**, so `textStyleOf(entity.textStyle)` and a hard-coded `textStyleOf(standardTextStyle)` are the same expression. That the same hole reopened in a later task, in two new call sites, says the fixture set is the problem and not any one task. Fixed by a `TITLE` style whose `fixedHeight`, `widthFactor` and `obliqueAngle` all differ from STANDARD's, on an entity that overrides *none* of them, so all three only reach the drawing through the record — plus a differential run on that same document, which is what kills the oracle's copy.

Cost if wrong: nothing in any of the three; each is a strictly stronger fixture, and the two style ones close a hole this plan has now had open across two tasks.

Task 10: carried to Task 11 (goldens): the attribute ladder and the mirror now have a *second* thing to prove beyond placement — Ruling 28's flip is pinned by composition arithmetic, not by pixels. A golden of a single left-baseline string is what would catch a flip that is right in the matrix and wrong in the rasteriser.

---

## Task 11 — Goldens: the attribute ladder and the mirror — COMPLETE

Created `packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart`
and `text_ladder_1..5.png`, plus `test/golden/fonts/` (Roboto-Regular.ttf, its
Apache-2.0 licence, and a README recording provenance and SHA-256).
`.gitignore` gained `**/test/golden/failures/`.

Gates: `jet_cad_2d` 717 pass, analyze and format clean. `jet_cad_2d_flutter`
148 pass (143 + 5 rungs), 1 pre-existing skip, analyze and format clean.
`flutter test --tags golden` 13 pass, **no existing PNG regenerated** — the
stroke-width and dash-ladder goldens are byte-identical.

Task 11: Ruling 34: **Step 2's review criterion for rung 4 is backwards.** The
step says to check that the crossed cells are "wider at the same slope rather
than more slanted". The engine composes the oblique shear *before* the
width-factor x-scale — `w * (x + k*y)` — which `textLocalTransform`'s own doc
comment names as the DXF reading and which `text_geometry_test.dart` pins as
`c = widthFactor * tan(oblique) * scale`. The stem slope is therefore
`widthFactor * tan(oblique)`, and the wide cell **is** more slanted. The
sentence describes the *swapped* order, which is the drawing this rung exists
to reject. Resolved in favour of the spec and the landed test; the golden pins
the engine and the rung's doc comment states the expectation with the reason.
Cost if wrong: none — the mutation table below shows the swapped order turning
rung 4 red, so the golden is discriminating in the direction claimed.

Task 11: Ruling 35: **the goldens load a vendored font.** `flutter_test`
renders every string in Ahem — one solid box per glyph — unless a real font is
loaded. Ahem is enough for justification, rotation and shear, and it makes
rung 5 *structurally* impossible: a mirrored box is a box, so the one rung
whose whole purpose is that a mirrored label reads backwards would assert
nothing. `Roboto-Regular.ttf` is copied into the test tree rather than read
from `FLUTTER_ROOT` at run time, because a golden is a byte comparison and the
SDK's copy is a different file in each release; reading it live would expire
every PNG here on the next `flutter upgrade` for a reason unrelated to this
code. Cost if wrong: 168 KB of Apache-2.0 binary in the test tree, and the
goldens must be regenerated if the font is ever replaced.

Task 11: Ruling 36: **the golden documents are built with `FlutterTextMeasurer`,
not a model measurer.** The painter reads its scale from
`document.textMeasurer` while the sink lays the paragraph out through its own,
separate measurer; the glyphs land inside the box the document believes they
occupy only while the two agree. A golden built on `MetricModelMeasurer` would
pin a drawing that no production wiring ever produces, which is the degenerate
fixture in its most expensive form — a *reviewed* one.

Task 11: Ruling 37: **a colour golden catches a dropped `argb` cache key only
if the string repeats.** Rung 1 was first written as four self-describing
labels — LEFT, CENTRE, RIGHT, MIDDLE — in four colours. Dropping `argb` from
`_CacheKey` left that rung **green**: four different strings are four distinct
keys with or without the colour, so nothing collides and nothing is mispainted.
The rung now draws one string, `JUSTIFY`, four times in four colours, and the
same mutation turns it red. This constrains Task 13's "visibly by a colour
golden" requirement: it is a requirement on the *fixture*, not on the palette.
The one-string form is also the better ladder for its own reason — an identical
advance width makes the four offsets a comparison you can see instead of one
you have to compute — which is why rung 2 was already written that way.

Task 11: Ruling 38: **no rung is a sole catcher, and that is recorded rather
than glossed.** Every mutation below is killed somewhere else too. What the
goldens add is that they are the only thing inside the widget package tying the
engine's composition to the pixels it produces: for M1, M3, M4 and M6,
`flutter test --exclude-tags golden` stays **green** and only the engine suite
and these five PNGs go red.

### Mutation table — 7 mutants, 7 killed, 0 survivors

Run with a backup-based runner that `shutil.copy`s each file to a temp
directory before mutating and restores it in a `finally` block. **Never
`git checkout` to revert a mutation** — Task 10 lost a full task's uncommitted
work that way.

| # | mutation | site | goldens | everything else |
|---|---|---|---|---|
| M1 | `lc = k * scale` — x-scale before the shear | `text_geometry.dart` | rung 4 RED | widget-without-goldens **green**; engine 716 +1 RED |
| M2 | sink drops the lift *and* the flip | `canvas_draw_sink.dart` | rungs 1–5 RED | `canvas_draw_sink_test` RED |
| M3 | justification offset forced to `dx = dy = 0` | `text_geometry.dart` | rungs 1, 2 RED | widget-without-goldens **green**; engine −6 RED |
| M4 | `sin(-rotation)` — rotation sign flipped | `text_geometry.dart` | rung 3 RED | widget-without-goldens **green**; engine −1 RED |
| M5 | lift kept, `scale(1, -1)` dropped | `canvas_draw_sink.dart` | rungs 1–5 RED | `canvas_draw_sink_test` RED |
| M6 | scale by `metrics.ascent`, not `capHeight` | `text_geometry.dart` | rungs 1–5 RED | widget-without-goldens **green**; engine −6 RED |
| M7 | `argb` dropped from `_CacheKey` | `flutter_text_measurer.dart` | rung 1 RED *(green before Ruling 37's fixture change)* | `flutter_text_measurer_test`: "the same string in two colours is two entries, not one" RED |

### What the review actually found

Step 2 says to look at all five PNGs. Two changes came out of looking, neither
of which any assertion would have reported:

1. **Rung 3's `-0.9` cell was clipped.** The anchors were on a 2×2 grid; a
   rotated string sweeps out of its cell in the direction it points, and the
   last glyph of the clockwise cell fell off the bottom edge. The anchors are
   now staggered, and the comment says why they are not a grid.
2. **Rung 1's colours were decorative.** See Ruling 37.

Task 11: carried to Task 12: nothing new. Task 10's carried item stands —
the allocation gate lives in the engine suite because `vm_service` is not
available in the flutter package, so it measures the engine helpers in the
painter's order rather than the painter itself.

---

## Task 12 — Rigs, counters, and the number the gate depends on — COMPLETE

Modified `test/rig/rig_support.dart`, `test/rig/paint_microbench_test.dart`,
`apps/dev_harness_2d/lib/main.dart` and
`apps/dev_harness_2d/integration_test/frame_timing_test.dart`. Production
surface added: `DraftPainter.drawText`, `DraftPainter.textOpCount`,
`DraftCanvas.drawText`, `FlutterTextMeasurer.resetCounters`.

Gates: `jet_cad_2d` 717 pass. `jet_cad_2d_flutter` **152 pass** (148 + 4),
1 pre-existing skip. `dev_harness_2d` analyzes clean. All three format clean.

### Step 2 — the number the gate's feasibility rests on

Measured on `textRigCorpus(50000)`, printed by
`flutter test --tags rig --run-skipped test/rig/paint_microbench_test.dart
--plain-name "text paint at 50000"`.

| camera | distinct `(string, style, argb)` keys | vs limit 512 | steady-state frame |
|---|---|---|---|
| working set (3000 x 2250 world units) | **18** | **under, by 28x** | newLayouts 0, newEvictions 0 |
| whole drawing (~96000 wide) | **4140** | 8x over | newLayouts 4140, newEvictions 4140 |

**`kParagraphCacheLimit` does not move, and `attributedInstanceFraction` does
not move.** The gate row is specified against the working-set camera; the
whole-drawing camera is the one `rig_support` itself calls "the worst case, and
not a frame anyone renders", and R1 has always reported it at a second per
frame. Ruling 4's single permitted raise stays unspent.

Where the 4140 comes from: 4000 ATTRIB leaves, each carrying a unique
`ATTRnnnnn` tag, plus 928 label entities drawing from the 20-word vocabulary =
**4020** distinct `(string, style)` pairs, times **7** distinct resolved
colours. The unique-per-instance ATTRIB tag is the whole of the pressure; the
labels contribute twenty keys no matter how many of them there are.

Task 12: Ruling 39: the limit stays at 512 because the measurement says so, not
because nobody looked.

Task 12: Ruling 40: **the row is reachable and it is weak.** 18 of 512 means it
would stay green at a limit of 32, so "under the limit" is not the same as
"under the limit with margin", and the margin is what Task 14 has to state.
The rig therefore prints a key-pressure ladder, zooming out about the same
centre:

| view width (world units) | distinct keys | text ops | |
|---|---|---|---|
| 3000 (the working set) | 18 | 19 | under |
| 6000 | 72 | 73 | under |
| 12000 | 273 | 287 | under |
| 24000 | 976 | 1075 | **over** |
| 48000 | 3469 | 4107 | over |
| 96000 (whole drawing) | 4140 | 4928 | over |

The limit starts binding between 12000 and 24000 units wide — **about five
times the working-set camera**. That is the margin, as a number.

Task 12: Ruling 41: **there are two paragraph caches, and the metrics one is on
the query path.** The painter reads `document.textMeasurer.measure(...)`; the
sink lays paragraphs out through `DraftCanvas`'s own `FlutterTextMeasurer`.
They are different objects with different keys — the metrics probe is always
built at `kMetricsProbeArgb`, the drawn paragraph at the entity's colour — so a
frame's text costs up to two layouts, not one. Visible at the whole-drawing
camera: the doc cache did **422,100** layouts against the sink cache's
**173,880**, and `R3 query-only` — which draws into a `NullDrawSink` and lays
out no paragraphs at all — still paid **+97 ms** for text (335.5 -> 432.7 ms
p50), because the metrics probe happens whatever the sink is. The rig prints
both caches for that reason.

Task 12: Ruling 42: **nothing outside the tests ever wires a real measurer into
a document.** `DraftDocument.empty`'s default is `InsertionPointMeasurer`, the
zero metrics. With it, `composeTransform`'s `scale` is `height / capHeight` on
`capHeight == 0` — so `scale = 0.0`, the text transform is singular, and
`entityBounds` collapses every glyph box to a point. An application that builds
a document the ordinary way and draws text gets **nothing visible, and no
error**. Out of Task 12's scope to fix — it is a question about who owns the
document's measurer, not about the rigs — but `textRigCorpus` now *requires* a
measurer with no default, and the harness wires a `FlutterTextMeasurer` when
`TEXT=true`. Carried to Task 14.

Task 12: Ruling 43: **R1 was building a fresh `FlutterTextMeasurer` inside the
timed body.** Pre-existing and harmless while nothing drew text — and fatal the
moment something did, because it hands every measured frame an empty paragraph
cache and measures cold layout over and over. Hoisted; both rigs now hold one
for the run.

### Step 3 — the counters, on and off, one flag apart

`DraftPainter.drawText` (default `true`, measurement-only, the same convention
`DraftCanvas.lineweightScale` already set) skips a text leaf before anything is
resolved for it, so the delta covers attribute resolution, layout composition
and the paragraph lookup together. Rebuilding the corpus with
`labelFraction: 0` was rejected for the reason the plan gives for
`textRigCorpus` itself: it moves the entity mix, the extents and therefore both
cameras.

R1, working-set camera: `ops/frame` 66904 -> 66847 (57 = 19 text leaves x
begin/text/end), `canvasCalls` 59212 -> 59193 (19). Paint p50 30.8 -> 31.5 ms —
**inside the noise**; nineteen text ops do not move a frame.

R1, whole-drawing camera: paint p50 956 -> 861 ms with text off, i.e. **+95 ms
for 4928 text ops**, on a cache thrashing 4140 entries a frame in each of two
caches.

Device rig (R2, macOS, profile, `flutter drive`, one run each):

| run | build p50 | raster p50 | canvasCalls | textOps | newLayouts |
|---|---|---|---|---|---|
| `TEXT` unset — Plan 3b's corpus | 20.76 ms | 79.28 ms | 54164 | 0 | 0 |
| `TEXT=true` | 20.19 ms | 89.03 ms | 51298 | 23 | **0** |
| `TEXT=true DRAW_TEXT=false` | 20.13 ms | 81.59 ms | 51275 | 0 | 0 |

Only rows 2 and 3 are comparable — row 1 is a different document and is here to
show the baseline was not disturbed. **+7.4 ms raster for 23 text ops**, build
unchanged. Single runs, so treat that gap as suggestive rather than settled.
The steady-state row is the one that matters and it reads **zero new layouts on
real hardware**; the run totals (`layouts=1190 evictions=678`) show the pan and
zoom sweep does briefly widen the view enough to thrash, which is the ladder
above happening in motion.

Task 12: Ruling 46: **`bool.fromEnvironment` accepts only `"true"` and
`"false"`.** `--dart-define=TEXT=1` reads as **false**, and the rig printed
`corpus=off` on a run that otherwise looked entirely correct. One whole device
run measured the wrong document before the `corpus=`/`draw=` line — added for
exactly this reason — gave it away.

Task 12: Ruling 47: **`flutter drive` rewrites
`apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`.** CocoaPods bumps
`MACOSX_DEPLOYMENT_TARGET` from 10.15 to 12.0 in all three build
configurations. Same class as the `analysis_options.yaml` trap: a tool-
generated edit that would read as a deliberate platform decision. Reverted, not
committed.

### Mutation table — 9 mutants, 9 killed, 0 survivors

Three of them only after the tests they exposed were written. Backup-based
runner; **never `git checkout` to revert a mutation.**

| # | mutation | first result | killed by |
|---|---|---|---|
| M8 | `drawText` guard deleted (branch a no-op) | KILLED | `drawText: false drops the text ops...` |
| M9 | `_textOps++` deleted | KILLED | same, plus the canvas test |
| M10 | `DraftCanvas` drops the `drawText` forward | **SURVIVED** | new: `drawText reaches the painter...` |
| M11 | `didUpdateWidget` ignores `drawText` | KILLED | same test's second half |
| M12 | `resetCounters` also clears the cache | **SURVIVED** | new: `resetCounters zeroes the counters and keeps the cache warm` |
| M13 | `TextKeySink` drops `argb` from its key | **SURVIVED** | new: `TextKeySink keys the same triple this cache does` |
| M14 | `TextKeySink` drops the style handle | KILLED | same |
| M15 | `textRigCorpus` drops `attributedInstanceFraction` | KILLED *(by the rig)* | the rig's own degeneracy guard |
| M16 | `textRigCorpus` drops `labelFraction` | KILLED *(by the rig)* | the rig's own degeneracy guard |

Task 12: Ruling 44: **the three survivors were all silently-dead measurement
machinery**, which is the failure mode this task is most exposed to. A dropped
`drawText` forward does not fail — it prints a text-off row identical to the
text-on row. A `resetCounters` that cleared the cache does not fail — it prints
one new layout per visible string and makes a working cache read as a failing
gate. A `TextKeySink` missing the colour axis does not fail — it under-reports
the number the gate's feasibility rests on. None of the three produces an
error; all three produce a *plausible number*, and this plan's exit gate is
made of numbers.

Task 12: Ruling 45: **`textRigCorpus`'s non-degeneracy is guarded inside the
rig, not in the suite.** Building it costs about two seconds — most of it the
20,000 instances, which do not shrink with `entityCount` — and at small entity
counts it is degenerate in a way that would make a cheap guard worthless:
`labelFraction` comes out of the *root* budget, which the instances mostly
consume, so `textRigCorpus(2000)` yields **4000 attribs and 0 labels**. The rig
now throws with both counts if either is missing, in the same spirit as R2's
"no repaint happened" guard, and M15/M16 confirm it fires.

Task 12: carried to Task 13: Ruling 42 (nothing wires a real measurer in
production) is a real defect with no owner yet. Task 10's carried item stands:
the allocation gate lives in the engine suite and measures the engine helpers,
not the painter.

### Task 12 addendum — the other two device rigs

`flutter drive --profile -d macos --dart-define=TEXT=true`, no `RIG` filter, so
all three ran in one session. This is the run that actually proves Step 3's
"from every rig": the earlier `RIG=pan` run exercised `printTextCounters` in R2
only, and R4a/R4b returned early without reaching it.

| rig | build p50 | raster p50 | canvasCalls | textOps | steady-state | run totals |
|---|---|---|---|---|---|---|
| R2 pan and zoom | 20.15 ms | 88.18 ms | 51298 | 23 | **newLayouts 0** | layouts 1190, evictions 678 |
| R4a leaf edit per frame | 21.17 ms | 88.87 ms | 48940 | 18 | **newLayouts 0** | layouts 1179, evictions 667 |
| R4b instance drag per frame | 24.07 ms | 85.24 ms | 50510 | 18 | **newLayouts 0** | layouts 1165, evictions 653 |

Three independent camera scripts, three steady-state frames, **zero new layouts
in all three**. The run totals are close to identical across the three
(1165–1190 layouts, 653–678 evictions) because all three scripts start from the
same working-set camera and only R2 zooms; the thrash they record is the
ladder's 12000–24000-unit crossover being touched briefly during the sweep, not
a steady-state cost.

R4a and R4b were not re-run with `DRAW_TEXT=false`. The on/off delta is
measured on R2 and on R1, and a third and fourth reading of the same one-branch
delta would not add a fact.

---

## Task 13 — Mutation testing — COMPLETE

Created `docs/superpowers/notes/plan-3c-mutation-log.md`. Four new tests, in
`text_geometry_test.dart`, `query_allocation_test.dart`, `text_overlay_test.dart`
and `extents_test.dart`; `query_allocation_test`'s pick-path watch list gained
`TextMetrics`.

Gates: `jet_cad_2d` **720 pass** (717 + 3), `jet_cad_2d_flutter` **152 pass**
(1 pre-existing skip). Analyze and format clean in both packages and in
`apps/dev_harness_2d`.

Task 13: Ruling 48: **the spec's table has twenty-one rows, not the plan's
"sixteen".** Counted, not estimated. The spec is the binding authority, so all
twenty-one were accounted for: twenty run, one — *use group 73 as ATTRIB
justification* — recorded **not applicable**, because Plan 3c ships no DXF
codec. Group numbers appear in this codebase only inside doc comments. Cost if
wrong: none; a DXF importer would bring the mutant with it and the log says so.

Task 13: Ruling 49: **four of the spec's twenty mutants survived the suite the
spec names as their killer.** Each is a different way for a named killer to be
the wrong one, and all four are now closed:

- **S9, flip the sign of rotation.** The spec says "arithmetic expectation".
  `text_geometry_test.dart`'s *rotation is not symmetric about its sign*
  asserts `plus.b == -minus.b`, which survives negating **both**. A global sign
  flip walked past the entire engine text-geometry file and was caught two
  packages away by a pick test and by golden rung 3.
- **S14, a fresh `TextMetrics` on a cache hit.** The spec names
  `query_allocation_test` — the standing allocation gate — and it stayed green.
  Its pick-path watch list was `{Vector2, _Record}` and a per-candidate
  `TextMetrics` was invisible to it, for exactly the reason that file already
  documents about `_Record`. With `TextMetrics` watched the gate reads
  **55.533 per call against a budget of 0.5**. The harness was blind to
  fifty-five allocations per pick.
- **S16, drop `touched` from `SetEntityTextCommand`.** Survived both full
  suites and is **not** a wrong-answer defect: `_reconcile` treats an empty
  `touched` as "cannot pin down what changed" and falls back to `rebuildAll()`,
  so the overlay-equals-rebuild test still passes — by the most expensive route
  available. It is a cost defect, a full index rebuild per keystroke, and the
  only mutant in the table invisible to any assertion about output.
- **S21, the extents walk ignoring the document's measurer.** Survived because
  every text case in `extents_test.dart` passes `entityBounds` an explicit
  measurer, which proves the function reads its argument and nothing about the
  field. The spec's measurer-dependence test did not exist.

Task 13: Ruling 50: **three of the four are the same failure the whole plan
keeps finding** — a test that names the right property against a fixture that
cannot tell right from wrong. S9's fixture is symmetric under its own mutation;
S21's passes the answer in as an argument; S14's harness watches a list the new
object is not on. The new `extents` test therefore uses two measurers differing
only in their *ratios*: a second measurer of a different *kind*
(`InsertionPointMeasurer`) would pass against a mutant hard-coding any real
model.

Task 13: Ruling 51: **two of the spec's mutants had to be restated to be
runnable, and both restatements are the design working.** *Lay the paragraph
out at the effective em size* has no site — `_buildEntry` is handed no size and
`fontSize` is a constant — so what was run is the nearest reachable mutant with
the same observable, `final hit = _cache[_probe]` forced to null, i.e. layout
never reuses. *Swap the measurer mid-life* cannot be spelled either, because
`DraftDocument.textMeasurer` is `final` for exactly that reason and says so;
the reachable form is the extents walk ignoring it. Both restatements are
recorded in the log beside the rows they belong to, not buried.

### Mutation table — 20 run, 20 killed, 1 not applicable

S1–S8, S11–S13, S15, S17–S20 were killed by the narrowest suite the spec names,
first try. S9, S14, S16 and S21 survived and were closed. Full table with the
observed failure text for every row is in the log.

Task 13: carried to Task 14: Ruling 42 (nothing wires a real measurer into a
document in production) is still open and now has a second piece of evidence —
S21 showed the extents path's dependence on that field was untested until this
task. Task 10's carried item stands: the per-text-leaf allocation gate lives in
the engine suite and measures the engine helpers in the painter's order, not
the painter.

---

## Task 14 — Exit gate and the results note — COMPLETE

Created `docs/superpowers/notes/2026-08-20-plan-3c-results.md`. Repaired
`text_paint_allocation_test.dart`. Extended the text rig to both entity counts
and to the hit rate split by source.

**The gate passes.** Every check ran, every failable criterion is met, and the
one benchmark failure is Plan 2's carried `snap at dirty threshold`
(p95 1.0800 ms against < 1.0 ms; every other gated row passes).

Task 14: Ruling 52: **macOS Low Power Mode was ON for this whole session**
(`pmset -g` → `lowpowermode 1`), exactly as it was for Plan 3b. Every timing in
the note is contaminated and comparable only within this session. It does not
touch the verdict: **all eight failable criteria are counters or pass/fail on a
test — layouts, evictions, live paragraphs, `skippedTextCount` — and none is a
timing.** Stated at the top of the note in a banner rather than in a footnote,
because 3b's contamination was discovered after the numbers had been published.

Task 14: Ruling 53: **the allocation gate was lying, one full-suite run in
eleven.** `text_paint_allocation_test` failed with `Expected: <= 0.9482 /
Actual: 1.00035` while the code was correct: the subject read a healthy 1.00 and
the **control** read 0.60. Ruling 31 had already met the profiler's low-read
artefact and answered it with ratios, which work when all three loops read low
*together*; this is the other kind, where only the control reads low — and a
ratio makes that **worse**, because a smaller denominator tightens the bound.

The repair is a plausibility guard, not a wider bound. The norm and wrappers
loops are controls whose answers are fixed by construction (1.00 and 9.00) and
neither depends on the subject, so a reading materially below either is a failed
measurement: the test re-takes it up to four times and fails with *"this is a
meter failure; nothing is known about the text path from this run"* if it never
gets a clean read. **Retrying cannot mask a text regression — nothing
`_drawText` could do would make the control loop under-report**, and that
argument is the whole licence for the retry.

Verified both ways: fifteen consecutive full-suite runs after the repair, **0
failures**; and with `attempts` mutated to 1 the very first read came back
**0.70**, so the retry is load-bearing and measured rather than defensive
decoration.

Cost if wrong: a genuine text regression that also happened to depress the
control loop would be retried instead of reported. The floors are on the
controls only, the failure message names the meter rather than the subject, and
the subject's own assertion is untouched.

Task 14: Ruling 54: **labels are free and attributes are the entire cost.** The
spec asked for the hit rate split by source and the split is the finding: at
500,000 entities and the whole-drawing camera, 9,928 label draws are served by
**140** cache entries — twenty vocabulary words across seven colours, a
**98.6%** hit rate — while all 4,000 attributes miss every time, because each
carries a string built from its own instance ordinal. Blended, that reads as a
mediocre cache; split, it says the cache is working perfectly on the half it can
work on. The rig cross-checks the classification against the document's own
entity-kind counts and throws if an attribute tag ever repeats.

Task 14: Ruling 55: **the whole-drawing thrash is the case for text LOD, not
for a bigger cache.** 4,140 layouts and 4,140 evictions per frame, and the count
is **4,140 at both 50,000 and 500,000 entities** because it is bounded by the
corpus's string variety, not its size. Raising the limit to 4,140 would hold one
zoom level of one corpus, and a real site plan has more distinct tag values than
this one. What removes the cost is not drawing text too small to read — Plan
3e's decision. The working-set numbers say the cache is the right mechanism for
frames a user renders; the whole-drawing numbers say it is not a mechanism for
frames they do not.

Task 14: Ruling 56: **`kCapHeightRatio`'s deviation, measured rather than
declared.** Parsed from the vendored `Roboto-Regular.ttf`: `unitsPerEm` 2048,
`OS/2.sCapHeight` 1456, true ratio **0.710938** against the constant's 0.7 —
**−1.54%**. Under-stating cap height over-states the scale, so text is about
**1.56% taller than DXF-nominal** in Roboto: under a millimetre on a 50 mm
title. It is a constant rather than a per-font lookup, so the deviation differs
in every other font, which is why the note declares it instead of burying it.

### Failable criteria, as measured

| Criterion | Reading |
|---|---|
| repeat frame, working set | **0** new layouts at 50k and 500k, and 0 on device in R2, R4a, R4b |
| evictions per repeat frame | **0** at both sizes |
| peak live paragraphs | **512** = the declared limit |
| `skippedTextCount` on `textRigCorpus` | **0**, both sizes, both cameras |
| differential + non-vacuity, text on | `text_paint_test` 9 pass |
| reference-query differential, text picking | engine `differential_test` 72 pass |
| overlay-equals-rebuild, edited text | `text_overlay_test` 4 pass |
| mutation log | 53 accounted, 52 killed, 1 not applicable, none argued equivalent |

Task 14: carried to the branch close: six items, in the note's own table. The
first — **nothing outside the tests wires a real measurer into a document, so a
text entity in an ordinary application draws nothing and reports no error** — is
a real defect with no owner and must be settled before text ships to an
application. It is out of Plan 3c's scope: the plan specifies the seam, not who
plugs it in.
