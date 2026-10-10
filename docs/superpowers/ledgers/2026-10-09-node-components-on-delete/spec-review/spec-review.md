# Independent review: "A removed node takes its components", revision 2

Spec: `docs/superpowers/specs/2026-10-09-node-components-on-delete-design.md`
at `e8b48a96` (branch `spec/node-components-on-delete`). Reviewed
2026-10-10.

## Verdict

**Approve with fixes.**

The design holds. D-1's check-then-add-then-restore is exact for every
refusal; `restore` cannot throw once `checkRestorable` passed; D-4's
`lost ⊆ seeds` argument is right; D-2's static capabilities break nothing
in the three suites. I re-ran the spike myself and every count in F-14
matches. Two things must change before a plan is written from it:

- D-7 (removing `_detachFor`) silently takes away the only kill of a
  `TableLabelEdit` all-or-nothing mutant. TD10 has to be re-pinned (V-1).
- N-4's fixture leaves three named or likely mutants alive: M-9 needs a
  non-empty snapshot, the unmapped type must not sort first, and the
  dangling-entry assertion must read the raw `children` (V-2).

The rest are wrong or partly wrong claims and small scope notes.

## Setup

- Scratch worktree:
  `git -C /Users/ahmeturel/Projects/oss/jet-cad worktree add --detach .../scratchpad/review/wt e8b48a96`,
  then `flutter pub get`. Removed with `git worktree remove --force` when
  done. The review worktree was only read; this file is the one write.
- Spike, applied by script in the scratch tree only:
  - D-1 and D-2 in `commands.dart`, as the spec states them.
  - `ComponentRegistry.checkRestorable`, the check `restore` already makes,
    split out.
  - D-7: `_detachFor`'s branch removed from `TableLabelEdit.apply`.
- Commands run, and what they printed:
  - `dart test --reporter expanded` in `jet_cad_2d` (spike plus my 5
    probe tests): `+1268 -9`. The 9 failures are the two standing
    `generate_document_test` fingerprints, plus `compound_command_test`
    *capabilities is the union*, CS7, LV2, DV1, MP6, OB1 and PG1. That is
    1263 + 5 probes, exactly F-14.
  - `flutter test` in `jet_cad_2d_flutter`: `+1431 ~1 -5`. All five
    failures are the text-ladder goldens, as F-14 says.
  - `flutter test --enable-vmservice` in `jet_cad_floor_plan`, with spike
    plus D-7 **plus the V-1 mutant**: `+1912: All tests passed!`
  - Targeted runs: the mutants of V-1, V-2 and F-14 against
    `test/tables/table_data_test.dart`, `test/host/table_data_test.dart`
    and a probe file `test/document/zz_review_probe_test.dart` (PR1 to
    PR7, scratch only). Each mutant was applied with a Python replace and
    reverted from a saved copy. Results are under each finding.

## Findings

### V-1 (Major). D-7 leaves `TableLabelEdit`'s rollback of derived commands unpinned

- **Section:** D-7 ("`TableLabelEdit` keeps its label stamping, its
  all-or-nothing and its replay"), and Testing ("TD7 to TD7c and HD12 run
  unedited").
- **Claim:** removing `_detachFor` changes nothing a test can observe.
- **Evidence:**
  - The rollback is `table_label_system.dart:108-115`: the derived
    inverses applied so far, in reverse, then `r.inverse`.
  - The only test that drives it is `tables/table_data_test.dart` TD10
    (`:415-447`, title *"a stamp that throws after the detach puts the
    data back with the edit"*). At `e281372` the derived command applied
    before the throw is `_detachFor`'s detach. After D-1 plus D-7 nothing
    derived is applied before the throw, so the loop runs over an empty
    list.
  - Mutant: replace the loop with nothing, keeping only
    `r.inverse.apply(target)`.
    - At `e8b48a96` code (no spike), `table_data_test.dart` gives
      `TD10 ... [E]`, `Some tests failed`. The mutant is killed today.
    - With spike plus D-7, `test/tables/` plus `host/table_data_test.dart`
      give `+85: All tests passed!`. The **full** `jet_cad_floor_plan`
      suite gives `+1912: All tests passed!`. It survives.
- **Why it matters:** the all-or-nothing the spec says it keeps is no
  longer guarded. Under the testing bar it is unpinned code.
- **Fix:**
  - Add to D-7 that TD10 is rewritten so a **stamp** is applied before
    the throw. For example, two tables turned in one edit, with a
    `_RefusingTarget` that refuses the second table's geometry read after
    the first stamp has written.
  - Name the mutant (*"`TableLabelEdit`'s catch skips the derived
    inverses"*) with TD10 as its killer.
  - Rename or re-word TD8, TD9 and TD10 and the `_RefusingTarget` doc,
    which describe the expander's detach.

### V-2 (Minor). N-4's fixture leaves M-9, an unnamed checkRestorable mutant and M-14's kill conditional

- **Section:** Testing, N-4, M-9, M-10, M-14.
- **Evidence (probe tests in the scratch tree):**
  - **M-9 needs a non-empty snapshot.**
    - PR3 is an out-of-range `index` with an **empty** snapshot. PR4 is
      the same with a mapped snapshot (`Tally` plus an unknown payload).
    - With M-9 applied (restore before `addNode`), only `PR4 ... [E]`
      fails; PR3 passes.
    - N-4 says only *"one whose node closes a definition cycle, and one
      whose index is out of range → throw, nothing attached"*. With an
      empty snapshot, *"nothing attached"* is vacuous and M-9 survives.
  - **An unnamed mutant: `checkRestorable` checks only the first type
    id.**
    - With M-16 (`break` after the first entry), PR1 passes. PR1's
      foreign snapshot carries one type.
    - PR6 fails: its snapshot carries `jet_cad.object_layer` (mapped)
      then `test.foreign` (unmapped).
    - `restore` keeps its own full check, so under this mutant `addNode`
      has run when `restore` throws: the node stays in the tree.
  - **M-14 is killed only by the raw `children` list.**
    - PR2: the encoder writes `childNodesOf(children)`
      (`json_codec.dart:62-63`, `tree.dart:104-107`), which drops a
      dangling entry. The encoding before and after (A)'s rollback is
      therefore the same.
    - M-14 turned PR1 and PR7 red only through the
      `(tree[g] as GroupNode).children` assertion.
- **Fix:** in N-4:
  - Give the cycle and index cases a **mapped, non-empty** snapshot
    (registered plus unknown).
  - Let the foreign snapshot carry a mapped type that sorts **before**
    the unmapped one, and name the first-only mutant with this case as
    its killer.
  - State that the dangling case compares `tree[parent].children` (the
    raw list), not the encoding.

### V-3 (Minor). Revision 2's reason for rejecting (A) misdates the defect; F-4 says only a file can make a dangling entry

- **Sections:** Revision 2 (*"`addNode` gained two refusals and an insert
  that skips an already-listed handle. That made revision 1's rollback
  inexact"*), D-1 (A) (*"Not exact at `e281372`"*), and F-4 (*"which only
  a malformed file's dangling entry can make true"*).
- **Evidence:**
  - At `85905bd`, `_link` already returned early when the list named the
    handle (`git show 85905bd:.../tree.dart`, lines 560 and 566). Revision
    1's rollback was already inexact there. Only the index refusals and
    the insert-at-index are new.
  - A dangling entry does not need a file. `AddNodeCommand` accepts a
    `GroupNode` whose `children` already lists a handle not yet added: it
    has no check like `AddDefinitionCommand`'s (`commands.dart:398-410`
    against `:498-504`).
  - PR7 does exactly this, `AddNodeCommand(GroupNode(g, children: [x]))`,
    and the premise asserts `children == [x]` and `tree[x] == null`. It
    passes on the spike; under M-14 it is red.
  - The defect of (A) is real, but in memory only: it never reaches a
    saved plan (V-2, PR2).
- **Fix:**
  - Correct the Revision 2 bullet: (A) was inexact at `85905bd` too.
  - In F-4, say a dangling entry comes from a file **or** from a hand-built
    `AddNodeCommand` with a pre-filled `children`.
  - Note that (A)'s change is to the in-memory raw list, which the
    encoder filters. The rejection still stands on I-3.

### V-4 (Minor). I-1 as written is false for the spec's own re-parent idiom

- **Section:** Invariants I-1 (*"After any command, no component ...
  sits on a handle that a `RemoveNodeCommand` in that command removed"*).
- **Evidence:**
  - D-3's idiom is `RemoveNodeCommand(h)` then
    `AddNodeCommand(node', components: snapshot)` in one compound. After
    it, `h` carries components, and `h` was removed by a
    `RemoveNodeCommand` in that command.
  - A compound `[RemoveNodeCommand(h), SetComponentCommand<T>(h, x)]` does
    the same. `SetComponentCommand` does not check liveness
    (`commands.dart:605-618`).
  - After D-7 nothing catches the second case for table data either.
- **Fix:** state I-1 about `RemoveNodeCommand.apply` itself: on return,
  `snapshotOf(handle).isEmpty`. Or say "a handle that names nothing after
  the command".

### V-5 (Minor). D-2's consequence omits undo of an add and redo of a delete

- **Section:** D-2, *Consequence*.
- **Evidence:** the dispatcher checks an inverse's `capabilities` on undo
  and redo (`undo.dart:212, 243, 287-293`). After D-2:
  - Undoing **any** `AddNodeCommand` runs a `RemoveNodeCommand`, which
    declares `{structure, components}`.
  - Under a `{structure, !components}` profile, a bare node add is
    allowed but its undo is refused (`PermissionDeniedError`; the entry
    stays, `undo.dart:214-225`).
  - `RemoveDefinitionCommand` already has the same asymmetry, so there is
    precedent. No production profile is affected (F-5).
- **Fix:** add one sentence to D-2 and one N-3 assertion: an add allowed
  under that profile is not undoable there.

### V-6 (Minor). Stale doc comments D-8 does not list

- **Section:** D-8.
- **Evidence:**
  - `planner_shell.dart:925-929` (`_deleteByHost`): *"one undo step, the
    table-data expander"*.
  - `table_label_system.dart:1-4` (file header). D-7 mentions it.
  - `_RefusingTarget`'s doc and TD8, TD9, TD10's titles in
    `tables/table_data_test.dart` (TD8 `:356`, TD9 `:392`, TD10 `:415`; `_RefusingTarget` `:452-455`).
  - The host guide (`docs/host-guide.md:1099-1100`) stays true and needs
    nothing.
- **Fix:** add `planner_shell.dart:927` and the test titles to D-8's list.

### V-7 (Info). D-6's "the orphans are inert" overstates

- **Section:** D-6 (3).
- **Evidence:**
  - `ParametricSystem.diagnostics()` iterates `t.handles(document)`, dead
    handles included, and reports any not-object holder as
    `parametric.misplaced` (`parametric_system.dart:618-629`).
  - `validate()` reports an `ObjectLayer` on any handle naming a missing
    layer (`validate.dart:329-337`).
  - An orphan parametric component also keeps `ParametricSystem._expand`
    wrapping every command (`parametric_system.dart:671-674`).
  - An orphan `SeatingComponent` keeps `TableLabelSystem` off its cheap
    path (`table_label_system.dart:49`).
  - None of this changes an outcome. The no-sweep decision stands.
- **Fix:** reword to "nothing **edits** through a dead handle; diagnostics
  may still report one".

### V-8 (Info). Data on dead handles that this spec does not touch: `rawData`, and table data written onto a dead handle

- **Section:** scope, D-7, Out of scope.
- **Evidence:**
  - `RawDataStore` is keyed by handle (`raw_data.dart:11`), and
    `CommandTarget` does not expose it (`command.dart:88-109`). So no
    command, `RemoveNodeCommand` after D-1 included, can drop a deleted
    node's raw data. Only a load writes it today
    (`json_codec.dart:135`), so it is file-borne only.
  - At `e281372`, `_detachFor` also undid a hand-built
    `SetComponentCommand<FloorPlanTableData>(deadHandle, x)` in the same
    edit. After D-7 that write persists. `setTablesData` only targets live
    tables (`floor_plan_controller.dart:1585-1591`), and
    `activeDocument` is `@internal` (`:800-802`), so only a hand-built
    command reaches it.
- **Fix:** record both under Out of scope next to O-1.

### V-9 (Info). D-4's "only `RemoveNodeCommand` removes a node" holds for shipped commands only

- **Section:** D-4.
- **Evidence:**
  - `tree.removeNode` is called only at `commands.dart:442`.
    `_dropInstance` (`tree.dart:547`) runs only from `repairCycles` at
    load, and `tree.clear` (`json_codec.dart:240`) only at load.
  - `DraftCommand` is a public `abstract class` (`command.dart:122`), and
    `CommandTarget.tree` is mutable. A host command that calls
    `target.tree.removeNode` on a parametric object loses 0.4.0's cleanup
    after D-4: the component and layer now orphan where they did not.
  - This is consistent with the "engine owns the invariant" stance, which
    ties it to `RemoveNodeCommand`.
- **Fix:** one Risks line.

### V-10 (Info). D-3's snapshot is read at build time

- **Section:** D-3.
- **Evidence:** a compound that writes `h`'s components before
  `RemoveNodeCommand(h)` and then re-adds with a snapshot read at build
  time restores the stale set. The write is silently lost; the snapshot is
  restored as built (`component.dart:189-205`).
- **Fix:** add one sentence to the CHANGELOG or D-3 note: build the
  snapshot from the state the removal will see.

### V-11 (Info). `restore` on a handle that already carries components appends unknown payloads

- **Section:** D-1, question 2 of the brief.
- **Evidence:**
  - PR5 passes: `restore(h, snapshotOf(h))` on a handle with one unknown
    payload leaves `unknownOf(h)` with 2 entries, because unknowns append
    (`component.dart:202-204`).
  - `toJson` then writes only the last payload per type id and handle
    (`:256`).
  - Within D-1 this is unreachable through history: a removal detached
    the handle, and stack order means every later write on it is undone
    first. It is reachable through O-4 (seed below an orphan) or a
    hand-built add.
- **Fix:** none required. Optionally note it in `restore`'s doc ("meant
  for a handle that carries nothing", already there) and in O-4.

### F-14 cross-check (no finding)

With spike plus D-7, each mutant applied alone, against the TD7 family
and HD12:

| Mutant | Red |
|---|---|
| M-1 | TD7, TD7b, TD7c, TD8, TD10, HD12 |
| M-2 | TD7, TD7b, TD7c, TD8, TD10, HD12 |
| M-3 | TD7, TD7b, TD7c, TD8, TD10, HD12 |
| M-15 | TD7b, TD7c, TD10, HD12 |

F-14's narrower claims (M-1 → TD7, HD12; M-2 → TD7; M-15 → TD7b) hold.
The kill table may list more.

## Facts F-1 to F-14

| Fact | Verdict | Note |
|---|---|---|
| F-1 | held | `commands.dart:436-448`, `:384-410` |
| F-2 | held | `:532-576`, `:491-513`, `:483-485`, `:526-542` |
| F-3 | held | `component.dart:156-205`; `restore` cannot throw after its check |
| F-4 | partly | lines right; a dangling entry can also be made in-session (V-3) |
| F-5 | held | `command.dart:53-62`; controller `:294, 1194, 1306` |
| F-6 | held | the only production `RemoveNodeCommand`s are `select_tool.dart:800, 841, 845` and `regeneration.dart:870, 874` |
| F-7 | held | 5 startup, 1 placer, 6 tools, 3 `generate_document`; all fresh handles |
| F-8 | held | `regeneration.dart:483-490, 556-562, 972-983`; host spec `:587-589` |
| F-9 | held | rulings `:24-31`; MP6's lines are `:246-249` (off by one) |
| F-10 | held | CS7 `:405-431`, LV2 `:773-800`; OB1's re-parent is `:122-124` (off by one) |
| F-11 | held | `component.dart:273-292`; seed raised by tables, tree, entities |
| F-12 | held | `table_label_system.dart:96, 134-142`; TD7 to TD10 `:249-447`, HD12 `:458` |
| F-13 | held | `schema_version.dart:48`; host spec `:572-577` |
| F-14 | held | re-run here: 1263 + 7 + 2, 5 goldens, 1912; mutant kills confirmed |
