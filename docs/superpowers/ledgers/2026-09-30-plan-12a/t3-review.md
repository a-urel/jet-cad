# Task 3 review — plan 12a (7b08ae9)

**Verdict: Approved.** There are no Important findings. The four minor findings below
need no change to this commit. Finding m1 is a note for the Task 5 reviewer.

I reviewed in the detached worktree `.claude/worktrees/plan-12a-review2` at HEAD
`7b08ae97b2e075b945dea2fce0e2006fe98c1543`. I read `CLAUDE.md`, the plan (header, P-1
to P-6, Global constraints, Gates, Task 3, Mutant assignment), spec D4, D8 ("Register",
S-1), the Testing entry for Launch and New, M-12a-27, `t3-brief.md` and `t3-report.md`.
I checked every claim in the report myself, as recorded below.

## Scope and conformance

- **The diff is scoped correctly.** It touches exactly 4 files, all in the app:
  - `lib/new_document.dart` (new)
  - `lib/parametric/catalog.dart`
  - `lib/startup_plan.dart`
  - `test/new_document_test.dart` (new)

  This matches the plan's file table for Task 3. No engine or render file changed,
  `startup_plan_test.dart` is untouched, and `analysis_options.yaml` is not in the
  commit.
- **`registerAppComponents`** calls `PageComponent.register` and then
  `parametricCatalog.registerComponents`. Its dartdoc says "call it once per registry",
  which matches the plan and D8.
  - I checked the two facts the dartdoc states. `ComponentRegistry.register` replaces
    the store unconditionally (`component.dart:67-77`). The catalog's `registerInto`
    skips a type that is already registered (`parametric_system.dart:760-762`).
- **`prepareDocument`** calls `DraftDocument.empty`, `registerAppComponents`, sets
  `header.units = millimeters`, then calls `ensureDashedLinetype`. This is D4's set-up,
  in D4's order.
- **`defaultPage()`** is `PageComponent(originX: -7425, originY: -5250)`, with every
  other field at its default. It is a function rather than `kDefaultPage` because the
  constructor validates its fields and is not const (`page_component.dart:96-116`). The
  plan allows this ("or a function"), so the deviation is legitimate.
  - The defaults are 210 × 297, landscape, 1:50. That gives an effective sheet of
    297 × 210 mm, which is 14,850 × 10,500 world mm, so this origin centres the sheet
    on the world origin.
- **`newDocument`** calls `prepareDocument`, attaches the page through `execute(SetComponentCommand)`,
  then calls `clearHistory()`. This matches D4.
- **`startupPlan`** now starts from `prepareDocument`, and the late
  `PageComponent.register` and units lines are removed. The page is still set through
  the log before the rooms.
  - **Byte identity, checked independently.** I wrote a throwaway probe test, which is
    now deleted. It encoded `startupPlan` at HEAD. I then swapped in the parent's
    `startup_plan.dart` (`git show 06c9c44:…`) by `cp` backup, re-ran the probe and
    restored the file (`diff` exit 0).

    | | Size | sha256 |
    |---|---|---|
    | Before | 176,573 bytes | `6addf747a937c7de44303a1bddcc07face86349409f16d546c910899dc9b65eb` |
    | After | 176,573 bytes | `6addf747a937c7de44303a1bddcc07face86349409f16d546c910899dc9b65eb` |

    `cmp` exited 0. This confirms the report.
- **Tests match the plan's list.**
  - The empty new document: ND1 checks `liveCount 0`, `undoDepth 0`, units in
    millimetres (with a control showing the header default is not millimetres), and
    DASHED at `ReservedHandles.dashedLinetype`, which is `Handle(6)` (`style.dart:121`).
  - The page: ND1 checks the page `==` the literal, written out in the test. The
    comparison covers all 12 fields (`page_component.dart:228-242`).
  - The round trip: ND3 checks that encode then decode with `registerAppComponents`
    gives an equal page, and that re-encoding gives the same bytes.
  - The sample: ND4a decodes it with both registrations and finds a live page and live
    walls. ND4b (page registration only) finds no live walls, and ND4c (catalog only)
    finds no page.
  - The fixture is not degenerate. ND4's setUp asserts that the sample page is not the
    default literal, and that the sample has 10 walls.

## Mutants fired

All mutants followed the same procedure:

1. `cp` the file to `scratchpad/p12r3-<name>-<file>.bak`.
2. Apply the mutation with a python exact-replace (count asserted to be 1).
3. Run `CI=true flutter test`.
4. `cp` the backup back.
5. `diff` the file against the backup. Every one exited 0.

| Mutant | Change | Result | Red test and line |
|---|---|---|---|
| **M-12a-27** (named) | `defaultPage` origin from the portrait size: `(-210*50/2, -297*50/2)` = (-5250, -7425) | **RED** +4 -2 | ND1 `new_document_test.dart:41` (page `==` literal); ND3 `:73` |
| MA (implementer's) | `newDocument` without `clearHistory()` | RED +5 -1 | ND1 `:28` (`undoDepth == 0`) |
| MB (implementer's) | `prepareDocument` does not set units | RED +3 -3 | ND1 `:34`, ND2 `:59`, ND3 `:76` |
| MC (implementer's) | `prepareDocument` without `ensureDashedLinetype` | RED +3 -3 | ND1 `:35`, ND2 `:60`, ND3 `:77` |
| MD (implementer's) | `registerAppComponents` without `PageComponent.register` | RED +0 -6 | ND1 `:25`, ND2 `:54`, ND3 `:67`, ND4 setUp `:87` |
| ME (implementer's) | `registerAppComponents` without the catalog | RED +4 -2 | ND2 `:55`, ND4a `:102` |
| R3field (mine) | `defaultPage` with `gridVisible: false` (a non-origin field) | RED +4 -2 | ND1 `:41`, ND3 `:73` |
| R4clearFirst (mine) | `newDocument` clears history before `execute` | RED +5 -1 | ND1 `:28` |
| R5twice (mine) | `startupPlan` calls `registerAppComponents` again after setting the page (breaks "once per registry") | RED +15 -5 | `startup_plan_test.dart:139`, `:688`; ND4 setUp `new_document_test.dart:92` |
| R1order (mine) | `registerAppComponents` registers the catalog first, then the page | survives, +20 (`new_document_test` + `startup_plan_test`) | Equivalent: `PageComponent` is not a parametric type, and the codec sorts type ids |
| R2nolog (mine) | `newDocument` uses `components.attach<PageComponent>` directly instead of `execute` | **survives**, +6 | See m2 |
| R6fromNew (mine) | `startupPlan` starts from `newDocument` instead of `prepareDocument` | survives, +20 | Equivalent. A probe under the mutant gave bytes `cmp`-equal to HEAD and `undoDepth 0`. Only `stateId` differs: 471 against 470 |

Every red result the report claims for its mutants reproduced exactly, with the same
counts and the same lines.

## Findings

### Important

None.

### Minor

- **m1 — Comments describe the Task 5 end state, which is not yet true at this commit.**
  - Two comments say launch opens the empty document:
    - `startup_plan.dart:1-4`: "The app no longer opens on it; launch and New open the
      empty document".
    - `new_document.dart:2`: "New and launch call [newDocument]".
  - At 7b08ae9, `main.dart:64` still falls back to `widget.document ?? startupPlan(_measurer)`.
    The plan instructed this correction (D4), and Task 5 makes it true.
  - **Note for the Task 5 reviewer:** confirm that `main.dart:64` and the bare
    `PlannerShell()` path (P-4) use `newDocument`.
  - The implementer already flagged `startup_plan.dart:26-28` ("the fixture a human looks
    at every session"), which is stale after D4 for the same reason. It fits Task 5 or
    Task 9's amendments. It needs no fix here.
- **m2 — Attaching the page outside the log goes undetected (R2nolog).** D4 says the
  page "is attached through `execute`".
  - The only observable difference is `commands.stateId`: `execute` moves it and
    `clearHistory` keeps it (`undo.dart:179-185`).
  - The host takes the save point after `newDocument` returns, so nothing the spec
    observes (clean state, Undo disabled, page, bytes) differs. The mutant is effectively
    equivalent at this layer.
  - A kill would need an assertion on `stateId` that no spec clause motivates, so I do
    not ask for one. It is recorded so that Task 9's sweep does not rediscover it as a
    gap.
- **m3 — R1order and R6fromNew are equivalent mutants.** Evidence is in the table. No
  action.
- **m4 — Doc reference style.** `catalog.dart`'s dartdoc cites
  `DraftDocumentCodec.decode(…, registerComponents: …)`, while D8 uses `decodeString`.
  Both take `registerComponents` (`json_codec.dart:93-99`, `152-158`), so the dartdoc is
  correct. No action.

## Gates

I ran these myself in the review worktree, with `CI=true` and
`PATH=/root/flutter/bin:$PATH`, after `flutter pub get`.

| Package | Tests | Analyze | Format |
|---|---|---|---|
| Engine `packages/jet_cad_2d` | `dart test`: **+1106 -2**, exit 1. The 2 failures are the standing `generate_document_test` ones ("the default document is the one Plan 2 measured, byte for byte" and "both text fractions default to zero and change nothing") | "No issues found!", exit 0 | 159 files, 0 changed, exit 0 |
| Render `packages/jet_cad_2d_flutter` | `flutter test`: **+974 ~1 -7**, exit 1. The 7 failures are the standing `text_ladder` rungs 1–5 and `text_lod_ladder` rungs 1–2 | "No issues found!", exit 0 | 178 files, 0 changed, exit 0 |
| App `apps/floor_planner` | `flutter test`: **+520** (514 + 6), "All tests passed!", exit 0 | "No issues found! (ran in 3.7s)", exit 0 | 106 files, 0 changed, exit 0 |

The engine and render counts are unchanged from the brief.

The worktree was left clean apart from the known `packages/jet_cad/analysis_options.yaml`
rewrite from `pub get`. The probe test file is deleted, and every mutated file was
restored with `diff` exit 0.
