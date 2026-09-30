# fix/live-object-rule: one "which registration names the object" rule

**Branch:** `fix/live-object-rule`, cut at `019aedb` (`main`, after the
`fix/post-11` merge).
**Source:** [the fix/post-11 note](2026-09-29-fix-post-11.md), "Found, not
fixed": **shadowing** and **the root-level-group check spelled five ways**.
The human asked for both on one branch (2026-09-30), and chose where the rule
lives: in the engine, as a public query ("Motor API'si").
**Ledger:** [`ledgers/2026-09-30-fix-live-object-rule/`](../ledgers/2026-09-30-fix-live-object-rule/).

Every commit had a fresh implementer and an independent reviewer, who re-ran
the gates and re-fired the mutants in a separate, detached worktree.

| Item | Commits | Review |
|---|---|---|
| L1: the engine exposes its object rule | `e0a56d0` | Approved |
| L2: every app type decision asks it | `980947d` | Approved |
| L2b: the L2 review's test gaps | `9a4df2a` | Approved |
| L2c: the L2b review's R1 (EG10 reaches the attach walk) | `3ede604` | Approved |

## The defect

The engine's object rule (spec 06 D5): a live object is a root-level
`GroupNode` carrying a registered parametric component, and when it carries
two, **the later registration names it** (the earlier component is kept, not
regenerated). The rule was private. The floor planner decided "is this a live
wall / opening / room / …" on its own — not five ways but seven
(`opening_geometry`'s and `dimension_attach`'s `_isLiveGroup`, `_keptPut`,
the band cache, `liveObjectsOf`, the Selection panel's `_isObject`, and
`ObjectGrips._of`, which picked the **first** matching type, wall before
opening) — and none of them knew the naming rule. A file's root-level group
carrying `WallParams` and `OpeningParams` was an opening to the engine and a
wall to the app: it followed a wall joint as a phantom, and with a dangling
host a select-tool drag of a neighbouring wall's corner threw
`DanglingReferenceError` from pointer dispatch.

Why nothing caught it: no engine test pinned the naming rule (the survey
naming by the **first** registration passes all 1,090 earlier engine tests),
and every app fixture carries one type per group.

## L1: the engine (`e0a56d0`)

One private function, `_naming(t, types, h)`: null unless `h`'s node is a
root-level `GroupNode`, else the last registration whose component `h`
carries. `_isObject` and `_survey` decide by it; the survey's `found` and
`stray` are unchanged (the review ran the old survey beside the new one over
the whole engine suite and a double-registration scratch test: no mismatch).
`ParametricCatalog.names<T>(target, h)` and `objectsOf<T>(target)` are the
public query on the same function. `T` matches exactly (`U == T`):
`names<Component>`, a shared interface, a subtype and an unregistered type
answer false; `is _Registration<T>` was rejected as covariant. `objectsOf`
is ascending by the store's own contract (no second sort). Tests `LO1`–`LO5`;
mutants M-L1a–h and the review's own three red. Spec 06 D5 amended.

## L2 and L2b: the app (`980947d`, `9a4df2a`)

`apps/floor_planner/lib/parametric/live_objects.dart`: `isLiveObject<T>` and
`liveObjectsOf<T>`, thin wrappers over the catalog's query. All seven
spellings go through it, plus two more decisions the grep found (the
Selection panel's Position check of an opening's host, and the dimension
attach walk's opening read); every other component read is of a handle
already known to be a live object of that type (listed in the L2 report and
re-checked by the review). Behaviour is unchanged for every document the app
makes; a shadowed group (a file) is now the later type's object everywhere
and the earlier type's nowhere. `dimension.dart` and `room.dart` take
`visibleForTesting` from `package:meta` (declared in the app's pubspec; the
lock is unchanged) so the pure geometry files stay free of Flutter (Ruling
11-2).

Tests: `EG7` (the throw, through the select tool: one step, no exception),
`EG8` (the phantom), `EG9` (Wall+Opening and Separator+Opening shadows:
an opening everywhere, a wall nowhere, including grips and the panel),
`AM7` (six placements), `EG10` (a dimension group carrying `WallParams`, so a
fix that special-cases `OpeningParams` goes red; after L2c its attach query
sits where the stray's line crosses the dimension's drawn line, so the attach
walk's owner check is reached), `TT10` (the Room tool's
two live-room sites). One mutant per site reverted to its old spelling, and
the reviews' narrowed variants, all red. Specs 06, 07, 08, 10 and 11 amended
where their text spelled the rule.

A file-only behaviour change: an opening hosted on a shadowed group no
longer accepts a typed Position (its host is not a live wall), `EG9`.

## Found, not fixed

- **A shadowed component is not reported.** `diagnostics()`'s
  `parametric.misplaced` reads only holders that are not objects; a
  shadowed component sits on an object, so a file's shadowed `WallParams`
  is silent. A new diagnostic is its own spec 06 change.
- **A shadowed group keeps its earlier type's generated children** until an
  edit regenerates it (`drift()` lists it). File only.
- **`ParametricView.objectsOf<U>` matches by `is`**, the catalog's
  `objectsOf<U>` exactly: they agree for a concrete registered type (the
  app's only use, `room.dart:404`, reads `RoomParams`, a final class) and
  differ for a supertype. (The L2 report said the app never calls it; it
  does, harmlessly.)
- **A type registered twice** makes `diagnostics()` report each misplaced
  component of it twice (pre-existing; no app path registers twice).
- Carried from fix/post-11, untouched: 06 D8's cleanup detaches only the
  naming registration; the codec does not raise the handle seed for
  components; the app's raw-coordinate `signedArea` (a far, short wall gets
  a spurious `wall.fallback`); a −0.0 opening position shows "-0.0"; the
  zoom percentage saturates; a fractional page scale's text is unpinned;
  the phantom-snap allocation case depends on its file's order; (b) a
  tapered piece under a scaled group.

## Gates (Linux container)

Branch point (`019aedb`): engine 1,090 + 2 standing
(`test/testing/generate_document_test.dart`), render layer 940 + 1 skip + 7
standing goldens, app 503.

- **engine** 1,095 + 2 standing (`e0a56d0`, the L1 implementer and its
  review, and again by the L2 review; analyze and format clean). +5:
  `LO1`–`LO5`. No engine file changes after it.
- **render layer** 940 + 1 skip + 7 standing (`980947d`, L2 and its review;
  no render file changed on the branch).
- **app** 514 (`3ede604`, the L2c implementer and its review; analyze and
  format clean; `9a4df2a` the same), +11: `EG7`–`EG10`, `AM7` ×6, `TT10`.
- **web** `flutter build web --release` `✓ Built` (`9a4df2a`).

On the human's machine: the standing macOS lines. Nothing here changes a
document the app makes; there is nothing new to look at.
