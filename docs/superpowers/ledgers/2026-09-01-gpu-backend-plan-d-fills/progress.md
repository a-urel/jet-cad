# SDD ledger — plan: docs/superpowers/plans/2026-09-01-gpu-backend-plan-d-fills.md

Branch: `plan-d/fills`, cut from `main` at `bde9196`.
Spec: docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md (revision 4) — read.

## Pre-flight conflict scan

### Pairs that share a file or an interface

| tasks | produced → consumed | finding |
|---|---|---|
| T1 → T2, T3 | `writeFill(...)`, `kKindFill` → both collector fill ops | agrees; six coords + argb in all three call sites |
| T1 → T5 | `kKindFill = 3` → shader `else if (kind < 2.5)` dispatch | agrees; T5 narrows the point branch explicitly |
| T2 ↔ T3 | both modify `geometry_collector.dart` and `geometry_collector_test.dart` | sequential, no overlap in method bodies |
| T2 → T8 | `fillPolygon` → M-D1, M-D7, M-D8 | agrees; each mutation names a test T2 lands |
| T3 → T8 | `fillCircle` → M-D2, M-D6, M-D12 | agrees |
| T4 → T7 | `fillFixture()` handles 900–905, 910 → order gate | agrees; T7 asserts a stroke is emitted after a fill, which is what handle 903 exists for |
| T5 → T6, T7 | expander handles kind 3 → both pixel measurements | agrees; no signature change to `expandInstances` |
| T6 → T7 | `measureResidentColor`, `ResidentColorAgreement` | **CONFLICT — see Ruling D-P1** |
| T6 ↔ T7 | both modify `resident_pixel_differential_test.dart` | sequential |
| T5 → T9 | regenerated `cad.shaderbundle` → harness device run | agrees |

### Each task against itself

| task | tests vs code it specifies | finding |
|---|---|---|
| T1 | garbage pre-fill before `writeFill`, asserts all sixteen slots | agrees — and the pre-fill is what makes the zero-valued slots killable |
| T2 | four tests vs the transcribed reference body | agrees; the degenerate-triangle test matches Ruling D6, not the `_emit` guard |
| T3 | fan/outline step-count equality derived, not hardcoded | agrees |
| T4 | guards vs the fixture it builds | **two API risks — see Ruling D-P2** |
| T5 | expander tests vs both shader and Dart edits | agrees; `dart:math` import needed for the point test's `math.max` (trivial) |
| T6 | tests use `debugTintResident:`, Interfaces block omits it | **CONFLICT — see Ruling D-P1** |
| T7 | helper names used before they are declared | **see Ruling D-P3** |
| T8 | twelve mutations vs the tests they must kill | agrees; every row names a test some earlier task lands |
| T9 | device run, note, STATUS.md | agrees; window checks are the human's, not the implementer's |

## Rulings

Ruling D-P1: `measureResidentColor`'s signature is
`({required Size size, required double devicePixelRatio, required double pixelsPerPaperMm, List<int> Function(List<int>)? permute, int debugTintResident = 0})`.
— Why: Task 6's Interfaces block lists `permute` and its own Step-1 test passes
`debugTintResident`; the test is the binding half, because Plan 3i's Ruling 14
(an instrument whose failing case is never exercised proves nothing) is what
that argument exists for. — Cost if wrong: one extra named argument on a
test-only helper.

Ruling D-P2: Task 4's fixture code is a shape, not a transcript. The
implementer verifies `AddLayerCommand`/`LayerRecord` and the entity
transparency accessor against `packages/jet_cad_2d`'s real API and adapts the
literals; the binding requirements are the six handles, their order, the
hairline layer, the transparency strictly between 0 and 255, and the
non-uniform off-origin placement. — Why: `packages/jet_cad_2d` is untouchable
by Global Constraints, so the fixture bends to that package and not the
reverse. — Cost if wrong: a fixture that compiles but misses one of the five
named properties; the Task 4 guard test is what catches that.

Ruling D-P3: Task 7's helpers (`collectFillFixture`, `renderFillFixture`,
`paintFillFixture`, `countDifferingPixels`, `sortByKind`) are declared by
Task 7's implementer, constrained by the call sites the brief shows. — Why:
the plan names them at their call sites and states where they live; inventing
signatures for them in the plan would have been a fourth copy to drift.
— Cost if wrong: a rename in one test file.

## Task log
Task 1: complete (commits bde9196..2dbaf15, review clean — spec ✅, quality approved, no Critical/Important)
Task 2: review found 1 Important + 2 Minor. Ruling D-2a: the "unkillable test"
Minor is promoted into the fix loop — CLAUDE.md's testing bar ("a new test is
only worth landing if a named mutation makes it go red") is a repo
non-negotiable, and Plan C's ledger records 8 of 14 review findings being
exactly this shape. — Cost if wrong: one round of loop on a test that could
have been deleted instead.
Task 2: Ruling D-2b: the plan's own `skippedOps` doc text was FALSE at Task 2's
commit (it claims `text` alone while `fillCircle` still counts). The finding
beats the plan text; corrected in fix round 1 and Task 3's dispatch carries the
follow-up. — Why: a doc contradicted by a test three lines away is the defect
this repo's review culture exists to catch. — Cost if wrong: none, the sentence
becomes true again at Task 3.
Task 2: Ruling D-2c: the loop-bound Minor (`i + 2 < length` vs the oracle's
`i < length`) is folded into the same round as a comment rather than deferred,
because it is one line inside a method already being edited. — Cost if wrong:
a comment nobody needed.
Task 2: fix round 1/5 (3 addressed, 0 open — skippedOps doc made true, non-killing test deleted with its reasoning verified against `_reserve`'s body, loop-bound comment added; commits e128fe5..3094312)
Task 2: complete (commits 2dbaf15..3094312, re-review clean, no new breakage)
Task 3: review found 1 Important (no test kills the `_coveredArgb` mutation on
the fillCircle path -- all three new tests sit above kMinStrokeDevicePixels and
none reads a colour slot) + 1 Minor (rim test checks x1 only). Both into fix
round 1. Ruling D-3a: the Important is treated as blocking rather than deferred
because M-D2 is a PRE-COMMITTED mutation in Task 8's table -- deferring it would
mean discovering the gap as a survivor after eight more tasks. -- Cost if wrong:
one round on a test Task 8 would have forced anyway.
Task 3: fix round 1/5 (2 addressed, 0 open — hairline colour test added and its mutation fired (alpha 1.0 -> 0.0745, arithmetic verified independently by the re-reviewer as 19/255), y1 assertion added; commits ef5b834..a102be5)
Task 3: complete (commits 3094312..a102be5, re-review clean, no new breakage)
Task 4: complete (commits a102be5..6c1b980, review clean — spec ✅ under Ruling D-P2, quality approved)
Task 4: minor (deferred): the `Handle(900).value < Handle(901).value` guard compares compile-time literals and no fixture mutation can turn it red. Self-flagged by the implementer, reviewed, and LEFT deliberately — the property it stands for is proved by `strokeInkInsideFill`'s measurement (337 device px of overlap against a floor of 200). Final review may triage it.
Task 4: note — the brief's lineweight 60 gave only 172 px of overlap, under the 200 floor; the implementer raised strokes 900 and 903 to 120 and re-measured 337. The plan's literal was wrong and the guard is what caught it.
Task 5: complete (commits 6c1b980..5074475, review clean — spec ✅, quality approved, one Minor that needs no code change)
Task 5: Ruling D-5a: the brief's `strings … | grep -c "attribute "` expectation of 8 was WRONG — this repo's bundle embeds the source twice, so the honest count is 16 occurrences of 8 unique attribute names. Verified independently by the reviewer, which extracted both the old and the new bundle and enumerated them (kind_half, p0, p1, corner, p2, join_weight, color, dash). The check stands but its expected number is 16. — Cost if wrong: a later task chasing a phantom attribute regression.
Task 5: note — the reviewer verified bundle freshness by decompiling it and finding the new dispatch verbatim in the embedded Metal source (`if (in.kind_half.x < 2.5) … else { _576 = ((p0*w.x) + (p1*(w.y+w.w))) + (p2*w.z); }`). That is the strongest evidence available in this package that a committed bundle is not stale.
Task 5: minor (deferred): the task report misattributes which test the brief's "defect this catches" comment belongs to. Report-only; no code change.
Task 6: complete (commits 5074475..76518fd, review clean — spec ✅ under Ruling D-P1, quality approved)
Task 6: measured on the stroke corpus: union=8183, withinTwo=100.000%, overEight=0, referenceInk=8183. Control arm (`debugTintResident: 0x00202020`) reads 0.000% — the instrument can fail. The primary test was additionally shown to kill a real defect (an R/G swap in `instance_expander._argbOf`, reverted), which the coverage instrument cannot see at all.
Task 6: minor (deferred): `resident_pixel_differential_test.dart:278-279` and the report label the corpus colour "R=0x30 G=0x20 B=0x10", backwards from `0xAARRGGBB` (R=0x10, B=0x30). Harmless because the tint is symmetric, but it is channel-position confusion sitting in the file that exists to prevent it.
Task 6: minor (deferred): `debugTintResident` adds to a packed colour word, so it is only a clean per-channel offset while no channel carries across a byte boundary. Proven safe for its one caller; a second caller could pick an unsafe tint silently.
Task 7: review (opus) found 1 Important + 3 Minor. The gate itself is real: the
reviewer reproduced the mutation transcript's arithmetic independently (the
mutant's `Expected: a value greater than <154> / Actual: <53>` is only
producible from a 155-instance kind-sorted buffer, and its third failure
reproduces the unmutated permuted measurement exactly), and read
`_reorderedInstances` as a correct whole-record gather. Measured: differing
9297 against a gate of >200 (46x), permuted withinTwoFraction 0.97635 against
<0.995, unpermuted 100.000%, referenceInk 393051.
Task 7: Ruling D-7a: the three Minors are folded into the same fix round rather
than deferred, because all three are one-liners in the two files the Important
already reopens. -- Cost if wrong: three lines of churn.
Task 7: fix round 1/5 (4 addressed, 0 open — permute pinned by an identity-no-op test and a 16-float multiset-equality test, unit corrected, order validated by assert, anti-vacuity comment made honest; commits 9c639b5..ca89212)
Task 7: note — the implementer DISPROVED a claim the reviewer and the controller both made: multiset equality does NOT catch a pure stride slide, because a stride bug composed with a real permutation stays a bijection. It fired the mutation, found the comment false, and rewrote it. The identity test is what covers that class. Both tests are needed and neither subsumes the other; the re-review worked the algebra independently and agreed.
Task 7: complete (commits 76518fd..ca89212, re-review clean, no new breakage)
Task 8: complete (commits ca89212..36dfb7e, review clean — spec ✅, quality approved). 11 of 12 killed on the first firing; M-D4 survived and was a REAL coverage gap, not an equivalent mutant: the corner table's fold triangle is zero-area whether M folds onto p1 or p2, and the plan's own test measured only area. Closed by pinning the M vertex's absolute position (which discriminates all three fold targets, not just the two named) and re-fired to show it dies.
Task 8: the reviewer cross-checked the log against two earlier rounds. M-D2 reproduced alpha 0.07450980693101883 to the last digit. M-D9 reproduced two of three assertions exactly and diverged on the third (overEight 9330 vs 9297) — traced to this round's mutant omitting the earlier one's explicit tie-break, so within-kind order differs. A divergence with a cause is better evidence of a real run than a perfect match.
Task 8: minor (deferred): the M-D5 log section does not restate that the Dart transcription is being mutated as a shader stand-in (M-D3 and M-D4 both do).
Task 8: minor (deferred): task-8-report.md:41 overstates M-D9 as reproducing "exactly"; the log itself is accurate.
Task 9: review found 1 Important (the new buffer-budget test's killability is
never stated in the record) -> fix round 1. Everything else verified: no
fabricated device observation anywhere, the buffer comparison against Plan C is
like-for-like on generation knobs (the reviewer checked that dpr affects
halfWidth and alpha but never instance counts, so the byte comparison holds
across a CPU-vs-device harness difference), both figures PASS an unmoved 8 MB
gate, and STATUS.md carries the 4+5+5=14 window-check debt without a lapse.
Task 9: measured — 6.51 MB / 106,636 instances at Plan-C-matched knobs, 7.00 MB
/ 114,717 at default knobs, against 8 MB. Plan C's fills-off figure was 6.41 MB
/ 105,076.
Task 9: Ruling D-9a: the device run and the human window check were withheld
from the implementer entirely and written into the note as OWED. -- Why: an
agent cannot see a window, and a note that presents an unobserved run as done
is the one failure this repo's record-keeping exists to prevent. -- Cost if
wrong: the exit gate reads 8 of 9 until a human runs the harness, which is the
true state rather than a flattering one.
Task 9: note — the plan's own harness command was missing
`--dart-define=SPIKE_FILLS=true`; run verbatim it would have shown zero fills.
The implementer caught it and recorded the corrected command instead.
Task 9: fix round 1/5 (1 addressed, 0 open — the buffer-budget test's killability fired for real: `_addFillRegions` disabled gives `Expected: a value greater than <0> / Actual: <0>`, restored from a /tmp cp backup; the second assertion is recorded as UNTESTED rather than claimed either way, because firing it needs a mutation inside GeometryCollector rather than in the harness; commits 8338fd5..d6d5c58)
Task 9: complete (commits 36dfb7e..d6d5c58, re-review clean, no new breakage)
Final whole-branch review (opus): 2 Important + 4 Minor + 2 record items. One fix
wave (3b5e55b, eabca9e), one scoped re-review: all eight ADDRESSED, no new
breakage, nothing left standing. The two Important were both mine, not the
implementers': STATUS.md carried a false claim that `main` was unchanged since
Plan C's merge (it is two commits later, and this branch's 798 engine tests are
inherited from `main`, not produced by Plan D), and the GLSL/Dart drift guard was
never extended to the `kind < 2.5` threshold this plan introduced -- so a
GLSL-only regression would have turned nothing red anywhere in the suite.
Plan D: nine tasks complete, commits bde9196..eabca9e, final review clean.
