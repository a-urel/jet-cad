# Release 0.5.0 — independent review

**Target:** `release/0.5.0` at `382f071`
(`382f071aa9ae31db8204fb0fbfcab779c2e712fd`, "chore: version 0.5.0 and its
changelog"), one commit on `main`'s `35950d2`. Compared against `v0.4.0`
= `8367010` (`836701048f9828be0aaedfedba186cb007497e60`). The range holds
O-8, "a removed node takes its components" (merged at `8b0f6b0`), a CI
step for the 0.4.0 host probe (`281a6a2`, merged at `6326e87`;
`.github/workflows/ci.yml` l. 162–170) and docs.

**Reviewer's setup:**
- The release worktree,
  `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/release-0.5.0`,
  is used read-only. The only writes there were made by the probe scripts
  and `tool/ci`'s own tests, into git-ignored outputs.
- Two scratch worktrees under `…/scratchpad/rel5-review/`:
  - `old`, detached at `v0.4.0`;
  - `new`, detached at `382f071`.
  Each ran `flutter pub get` once; `git status --short` was empty in both
  afterwards.
- Flutter 3.47.6 (`/opt/homebrew/bin/flutter`, Dart 3.13.5) on macOS
  (Darwin 27).
- An API dump tool of my own, `rel5-review/apidump`, built on analyzer
  13.3.0 from the pub cache (`dart pub get --offline`). It lives outside
  the repo.
- Monépro's `pubspec.yaml` and `pubspec.lock` copied to
  `rel5-review/monepro-res`.

Nothing was committed or pushed, and Monépro was not touched. In my
scratch worktrees I made temporary changes, all removed afterwards: three
test files (Check 2, Check 7) and a simulated post-merge guide edit
(Check 4).

**Afterwards:**
- Both scratch worktrees were removed with `git worktree remove`.
  `git worktree list` shows neither.
- In the release worktree, `git status --short` is empty, and HEAD is
  still `382f071aa9ae31db8204fb0fbfcab779c2e712fd`.

## Verdict

**Approved with fixes.** Every check that matters for a POS is green:

- **The API.** Across all ten barrels, one existing signature changes:
  `AddNodeCommand(Node node, {int? index})` gains
  `ComponentSnapshot? components`, an optional named parameter. Eight
  lines are added, all in `jet_cad_2d.dart`. The host barrel, `editor.dart`
  and the other seven barrels are identical, line for line. "Nothing a
  0.4.0 host calls changes its signature" holds as worded, and the 0.4.0
  and 0.3.0 host probes analyse clean at `382f071`.
- **Plans and service layouts** cross between 0.4.0 and 0.5.0 byte for
  byte in both directions (schema 9 both). A 0.4.0 plan holding an orphan
  loads, saves, and survives a 0.5.0 delete and undo byte for byte.
- **The same edits, both releases.** For every type the floor planner
  writes (tables with host data, walls, doors, `ObjectLayer`, the demo's
  salon), a delete, its undo and its redo save the same bytes under 0.4.0
  and 0.5.0. The only stored difference I could make is a newer
  release's (unknown) payload on a deleted node: 0.4.0 leaves it, 0.5.0
  takes it.
- **Versions.** The five pubspecs, and nothing else, are at 0.5.0.
- **The probes.** The host probe at the full SHA is green (40 packages,
  no GPU renderer, a 42M web build). The 0.4.0 and 0.3.0 host probes
  analyse clean against `382f071`.
- **Monépro's graph** resolves with 0.5.0, holds no GPU renderer, and
  moves only `pdf` and `printing`, each by a patch, as at 0.4.0.
- **The gates I ran.** `flutter analyze` is clean in the five packages and
  the demo. The planner (1915) and the demo (68) pass whole; the engine
  and the renderer fail only where they are known to on macOS (R-6).

The fix is wording and does not block the merge. R-1 is a CHANGELOG gap
in the engine's additions; R-2 and R-3 are optional sentences.

## Findings

### R-1 — Minor: the CHANGELOG leaves out two engine additions and one behaviour change of `ComponentRegistry`

The barrel diff (Check 1) adds to `jet_cad_2d.dart`:
- `ComponentRegistry.checkRestorable(Handle handle, ComponentSnapshot
  snapshot)`, a new public method (`component.dart` l. 191);
- `AddNodeCommand.components`, a new public field and getter
  (`commands.dart` l. 398, `final ComponentSnapshot components`), beside
  the new constructor parameter (l. 400).

The CHANGELOG names the parameter only by its use
(`components: doc.components.snapshotOf(handle)`), and neither member.

One behaviour of an existing method also changes:
`ComponentRegistry.restore` now runs `checkRestorable`, which adds a
second refusal. A snapshot entry whose value is not of the class
registered under its type id throws `StateError` and writes nothing
(`_accepts`, `component.dart` l. 104, 116, 198). In 0.4.0 such a value was stored. Only
a snapshot from another document can carry one.

The 0.3.0 and 0.4.0 reviews held (R-1 both) that every public addition
belongs in the CHANGELOG. Nothing breaks: the parameter is optional and
the members are new.

**Fix:** append to the CHANGELOG's second 0.5.0 bullet (l. 28–33), after
"without it the node comes back empty.":

> `AddNodeCommand` takes the snapshot as `components` (optional, empty by
> default) and exposes it as a getter. `ComponentRegistry.checkRestorable`
> is public: it is the check `restore` makes before its first write, and
> it now also refuses a value that is not of the class registered under
> its type id (`StateError`, nothing written).

### R-2 — Info: a host may read the first bullet as a change to its own plans; it is not one

CHANGELOG l. 22–25 says a deleted group's, nested group's or instance's
components "now go with it, as a table's host data already did in
0.4.0". In the floor planner a wall's, room's or door's parameters and
`ObjectLayer` already went with a delete in 0.4.0, through the parametric
layer's cleanup (06 D8, 12b D2; the design's F-8). Check 7's differential
shows that for every type the planner writes, 0.4.0 and 0.5.0 save the
same bytes after a delete, an undo and a redo. What 0.5.0 changes is:
- data a newer release wrote (an unknown payload) on a deleted node;
- an instance's or nested group's other components, which no planner
  path writes today;
- every component in a document with no parametric system (bare
  `jet_cad_2d`, `jet_cad_2d_flutter`).

Nothing listed is wrong. The intro's "Nothing is stored differently"
holds for every type 0.4.0 and 0.5.0 write. **Optional:** add one
sentence to the bullet:

> In the floor planner a wall's, room's or door's parameters already went
> with it too, so for every type 0.4.0 and 0.5.0 write, a plan after a
> delete is the same bytes in both; what changes is data a newer release
> wrote, and every component in a bare `jet_cad_2d` document.

### R-3 — Info: two after-the-fact detaches are gone, for code that does not delete through `RemoveNodeCommand`

The design removes two detaches that ran after an edit (D-4, D-7). With
`RemoveNodeCommand` they never fire, and the outcome is unchanged. They
still did something in 0.4.0 for code that bypasses it:
- **The parametric cleanup** (`regeneration.dart`, the `cleanup` list and
  `_detachLayer`, removed). A host's own `DraftCommand` that unlinks a
  parametric object through `target.tree.removeNode` loses it. In 0.4.0
  the object's component and `ObjectLayer` were detached in the same
  edit. In 0.5.0 they stay on the dead handle. The design records this
  under Risks (review V-9).
- **`TableLabelEdit`'s `_detachFor`** (`table_label_system.dart`, removed).
  `TableLabelEdit` is exported by `editor.dart`. A hand-built
  `SetComponentCommand<FloorPlanTableData>` onto a dead handle now
  persists (the design's O-7).

`DraftCommand`, `CommandTarget.tree` and `SetComponentCommand` are public,
so an engine user can reach both cases. A host using
`FloorPlanController` cannot: `activeDocument` is `@internal`.
**Optional:** add to the second bullet "Delete a node through
`RemoveNodeCommand`: the parametric layer's and the table system's
after-the-edit detaches are gone, so a command that unlinks a node
itself leaves its components behind."

### R-4 — Info: "Nothing a 0.4.0 host calls changes its signature" is exact as worded

- **One changed line in all ten barrels** (Check 1): `AddNodeCommand`'s
  constructor, which gains an optional named parameter.
- **No class header changed.** The `<header>` lines (abstract, sealed,
  final, base, interface, mixin, supertypes) are identical in both trees.
- **`RemoveNodeCommand.capabilities` and `AddNodeCommand.capabilities`**
  are new overrides with the inherited signature, `Set<Capability> get
  capabilities`. What they return changes. The CHANGELOG lists that for
  the remove, and D-2 for the add with a non-empty snapshot.
- **The 0.4.0 and 0.3.0 host probes** analyse clean against `382f071`
  (Check 5).
- **No production permission profile** allows `structure` without
  `components` (`DraftPermissions.all`, `.runtime`, `.readOnly`; design
  F-5). `FloorPlanEditorCapabilities` is not a permission profile, so
  `tablesOnly` still deletes tables. A host sees no new refusal.

### R-5 — Info: a mixed 0.4.0 and 0.5.0 fleet disagrees on nothing a host can see

The question asked was whether a 0.4.0 terminal and a 0.5.0 terminal
sharing one plan can disagree in a way a host would notice. For example,
a 0.4.0 delete could leave orphans that a 0.5.0 undo cannot restore.
What I found (Check 7):
- **Undo history is not stored.** A 0.5.0 terminal never undoes a 0.4.0
  terminal's delete: each terminal undoes only its own session's steps.
  So no 0.5.0 undo meets a 0.4.0 orphan as something to restore.
- **A 0.4.0 delete leaves no orphan of any type either release writes.**
  This holds for table data, walls, doors, `ObjectLayer`, and the salon's
  thirteen objects: the bytes are the same as 0.5.0's.
- **A 0.4.0 delete does leave an unknown payload behind.** 0.5.0 loads
  that plan, saves it byte for byte, and deletes and undoes other tables
  on it byte for byte. The orphan stays, as the Known limits say.
- **No release writes an unknown payload yet.** 0.5.0 registers no new
  component type (no `register` changed in the range).

**The one caveat is for the next release, not this one.** Once a release
after 0.5.0 stores a new component type, a 0.4.0 terminal still in the
fleet will orphan it on delete. A 0.5.0 terminal will not. The
0.5.0 Known-limits sentence ("A plan an older release edited may still
hold entries of nodes it deleted") already covers this. That release's
notes should repeat it.

### R-6 — Info: on macOS, the suites fail only where they are known to

The results, run in my `new` worktree:
- **Engine** (`dart test`): `+1281 -2`. The two failures are the
  `generate_document_test` fingerprints, which are in the standing set
  (0.4.0: `+1270 -2`).
- **Renderer** (`flutter test`): `+1432 ~1 -5`. The five failures are
  the text ladder's rungs 1–5; the skip is the paint micro-benchmark rig
  (0.4.0: `+1431 ~1 -5`).
- **Planner** (`flutter test --enable-vmservice`): `+1915`, all pass
  (0.4.0's review: `+1908 ~3 -1`, the T-1 caption test, since fixed).
- **Demo** (`flutter test`): `+68`, all pass.

CI on Linux is the gate of record.

### R-7 — Info: a POS's lock moves `pdf` and `printing` by a patch, as at 0.4.0

I resolved Monépro's own `pubspec.yaml` and `pubspec.lock` (develop,
`e4cb1f1`), adding the guide's two git dependencies at `382f071`. That
adds the four jet-cad packages at 0.5.0 and moves:
- `pdf` 3.13.0 → 3.13.1;
- `printing` 5.15.0 → 5.15.1.

That is 186 → 190 packages, with no GPU renderer. The `sdks:` floor is
unchanged (`flutter: ">=3.44.0"`). This is exactly the 0.4.0 review's
R-6. Monépro still has no jet-cad dependency in its `pubspec.yaml`, and
pins Flutter 3.47.6 in all four workflows.

### R-8 — Info: other version strings, correctly left alone

- `packages/jet_cad/pubspec.yaml` `version: 0.3.0`: the dormant line.
- `.github/workflows/ci.yml` l. 162–170 and `tool/ci/test/scripts_test.dart`
  SC18 name `v0.3.0` and `v0.4.0` on purpose: the P-1 job analyses each
  released host's code. This discharges the 0.4.0 review's R-7 follow-up.
- `apps/floor_planner/lib/document_files_web.dart` l. 11: "0.4.0 removed
  it…" is about the `cross_file` package, not jet-cad.
- STATUS l. 3–4 ("`main` carries release 0.4.0"), STATUS's history lines,
  the roadmap's row 14 and the guide's 19 "since 0.4.0" markers are
  either history or post-merge lines.
- The guide's §1 placeholders are the 0.4.0 pattern (Check 4).

## Check 1 — the CHANGELOG against the API diff

**Method.** I wrote `apidump/bin/apidump.dart` on analyzer 13.3.0's
`AnalysisContextCollection`. For each barrel it resolves the library and
walks `exportNamespace.definedNames2`. For each name it prints:
- the element kind and its display string;
- for interfaces, a `<header>` line with `abstract`, `sealed`, `final`,
  `base`, `interface` and `mixin`, and the supertypes;
- every public constructor, field, getter, setter and method, with the
  flags `@internal`, `@visibleForTesting`, `@deprecated`, `abstract` and
  `static`. A getter carries its field's metadata.

The output is sorted. The barrels (zsh, so `${=B}` splits the list):

```
B="packages/jet_cad_2d/lib/jet_cad_2d.dart packages/jet_cad_2d/lib/testing.dart
   packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/lib/export_testing.dart
   packages/jet_cad_floor_plan/lib/jet_cad_floor_plan.dart packages/jet_cad_floor_plan/lib/editor.dart
   packages/jet_cad_floor_plan/lib/symbols.dart packages/jet_cad_floor_plan/lib/symbol_sources.dart
   packages/jet_cad_restaurant_symbols/lib/jet_cad_restaurant_symbols.dart
   packages/jet_cad_2d_gpu/lib/jet_cad_2d_gpu.dart"
$ dart run bin/apidump.dart $S/old ${=B} > $S/old.api 2>$S/old.err; echo old=$?
old=0
$ dart run bin/apidump.dart $S/new ${=B} > $S/new.api 2>$S/new.err; echo new=$?
new=0
    7882 old.api
    7889 new.api
# stderr, names per barrel (old | new):
jet_cad_2d.dart 248 | 248; testing.dart 5 | 5; jet_cad_2d_flutter.dart 180 | 180;
export_testing.dart 16 | 16; jet_cad_floor_plan.dart 50 | 50; editor.dart 349 | 349;
symbols.dart 16 | 16; symbol_sources.dart 4 | 4; jet_cad_restaurant_symbols.dart 6 | 6;
jet_cad_2d_gpu.dart 9 | 9
$ diff old.api new.api
72c72
< jet_cad_2d.dart :: AddNodeCommand .. AddNodeCommand(Node node, {int? index})
---
> jet_cad_2d.dart :: AddNodeCommand .. AddNodeCommand(Node node, {int? index, ComponentSnapshot? components})
74a75
> jet_cad_2d.dart :: AddNodeCommand .. ComponentSnapshot get components
75a77
> jet_cad_2d.dart :: AddNodeCommand .. Set<Capability> get capabilities
77a80
> jet_cad_2d.dart :: AddNodeCommand .. field ComponentSnapshot components
78a82
> jet_cad_2d.dart :: AddNodeCommand .. field Set<Capability> capabilities
254a259
> jet_cad_2d.dart :: ComponentRegistry .. void checkRestorable(Handle handle, ComponentSnapshot snapshot)
1485a1491
> jet_cad_2d.dart :: RemoveNodeCommand .. Set<Capability> get capabilities
1488a1495
> jet_cad_2d.dart :: RemoveNodeCommand .. field Set<Capability> capabilities
lt=1 gt=8
```

(The `field … capabilities` lines are the analyzer's synthetic fields
for the two getter overrides.) `ComponentSnapshot`, `snapshotOf`,
`detachAll` and `restore` were already public at `v0.4.0`.

| Barrel | Change | In CHANGELOG |
|---|---|---|
| `jet_cad_2d` | `AddNodeCommand({components})` | yes, by its use (l. 31–33) |
| `jet_cad_2d` | `RemoveNodeCommand.capabilities` = `{structure, components}` | yes (l. 28–30) |
| `jet_cad_2d` | `AddNodeCommand.capabilities` (`{structure}`, plus `components` for a non-empty snapshot) | yes, as "the undo of a node add" is the remove; the add's own set is D-2's |
| `jet_cad_2d` | `AddNodeCommand.components` getter, `ComponentRegistry.checkRestorable` | **no**: R-1 |
| `jet_cad_2d` | `restore`'s new class check (behaviour) | **no**: R-1 |
| host, `editor.dart`, `testing`, `jet_cad_2d_flutter`, `export_testing`, `symbols`, `symbol_sources`, restaurant, GPU | none | — |

**Behaviour changes without a signature change**, from
`git diff v0.4.0..HEAD -- packages/*/lib` (8 files, 139+/115−):
- `commands.dart`: the remove snapshots and `detachAll`s; the add checks,
  links, restores. This is listed.
- `regeneration.dart`: the cleanup and the dissolve's detaches are gone.
  The outcome through `RemoveNodeCommand` is unchanged (Check 7); for
  other code, see R-3.
- `parametric_system.dart`: doc comments and one unused import.
- `table_label_system.dart`: `_detachFor` is gone. The outcome is
  unchanged (TD7, HD12; Check 2's table delete); see R-3.
- `planner_shell.dart`: one doc comment.
- `jet_cad_2d_flutter/lib`, `jet_cad_2d_gpu/lib`,
  `jet_cad_restaurant_symbols`, the codec and `host/` are unchanged.

**Nothing listed is wrong.** I checked each CHANGELOG claim against the
code and tests:
- the static `{structure, components}` (`commands.dart` l. 469);
- the refusal of the delete and of an add's undo under a profile without
  `components` (`node_components_test.dart` N-3, l. 184–212: a
  `PermissionDeniedError`, the undo depth unchanged);
- the re-parent idiom (D-3; CS7, LV2 and OB1 rewritten to it; N-6).

**Dependencies.** The pubspecs change only in their `version:` lines:

```
$ git diff v0.4.0..HEAD -- '*pubspec.yaml' '*pubspec.lock' '*analysis_options.yaml' | grep '^[-+]'
--- a/packages/jet_cad_2d/pubspec.yaml / +++ …   -version: 0.4.0  +version: 0.5.0
(the same pair for jet_cad_2d_flutter, jet_cad_2d_gpu, jet_cad_floor_plan, jet_cad_restaurant_symbols)
```

## Check 2 — the compatibility claim

**The source facts.** The codec and the service layout are unchanged in
the range, so `kSchemaVersion` is 9 in both:

```
$ git diff --stat v0.4.0..HEAD -- packages/*/lib apps packages/jet_cad_restaurant_symbols packages/jet_cad_2d_gpu packages/jet_cad_2d/lib/src/codec packages/jet_cad_floor_plan/lib/src/host
 packages/jet_cad_2d/lib/src/document/commands.dart | 48 +++++++++++++++--
 .../jet_cad_2d/lib/src/document/component.dart     | 54 +++++++++++++------
 .../lib/src/parametric/parametric_system.dart      | 36 +++++++------
 .../lib/src/parametric/regeneration.dart           | 63 +++++++---------------
 packages/jet_cad_2d_gpu/pubspec.yaml               |  2 +-
 .../jet_cad_floor_plan/lib/src/planner_shell.dart  |  5 +-
 .../lib/src/tables/table_label_system.dart         | 44 +++++----------
 packages/jet_cad_restaurant_symbols/pubspec.yaml   |  2 +-
 8 files changed, 139 insertions(+), 115 deletions(-)
```

**A cross-tree round trip.** I put one temporary widget test,
`test/host/xfer_review_test.dart`, in each scratch tree's planner, outside
git, and removed it afterwards. `--dart-define`s choose the tree and the
phase. Every controller is mounted in a `FloorPlanView`, so that
`deleteSelection()` (the host API) runs the editor's own delete.
- **Seed (old).** Load the embedding fixture (`embeddingPlanJson()`,
  identical in both trees). `setTablesData` on tables `1` and `2`. Then,
  in the codec's order, add an unknown type `z.next` on both tables'
  placements (handles 22 and 24, one payload nested). This stands in for
  data a newer release wrote. Write `input.json`.
- **Act (each tree).** Load `input.json` and require `designJson()` to
  be byte-equal and `dirty` false. `select({'1'})`, then
  `deleteSelection()`: one undo step. Save `<tree>.deleted.json`.
  `undo()` must give `input.json` byte for byte; `redo()` must give the
  delete. Switch to selection, move table `2` by (350, −125), and save
  `<tree>.layout.json`.
- **Read (each tree, the other's files).** Load `<other>.deleted.json`
  and require it byte-equal and clean. Delete table `2` there, report
  what is left on its handle and on table 1's, then undo and require
  `<other>.deleted.json` byte for byte. Restore `<other>.layout.json` on
  `input.json` and require `serviceLayoutJson()` byte-equal to it.

```
00:00 +0: xfer old seed
seed: 7352 B, schema 9, table 1 = 22, table 2 = 24, types on 1: [jetcad.table_data, z.next], on 2: [jetcad.table_data, z.next]
00:00 +1: All tests passed!
00:00 +0: xfer old act
old deleteSelection(1): one step; entries left on the dead handle 22: [z.next]
old undo: designJson == input: true, details of 1 data: {pos_table_id: abc-123}
old layout: 169 B
00:01 +1: All tests passed!
00:00 +0: xfer new act
new deleteSelection(1): one step; entries left on the dead handle 22: []
new undo: designJson == input: true, details of 1 data: {pos_table_id: abc-123}
new layout: 169 B
00:01 +1: All tests passed!
00:00 +0: xfer old read
old reads new.deleted.json: byte-equal, clean
old on new.deleted.json: delete 2 leaves on 24: [z.next]; orphans of 1 kept: []
old undo: designJson == new.deleted.json
old restores new.layout.json: byte-equal, applied [2], dropped []
00:01 +1: All tests passed!
00:00 +0: xfer new read
new reads old.deleted.json: byte-equal, clean
new on old.deleted.json: delete 2 leaves on 24: []; orphans of 1 kept: [z.next]
new undo: designJson == old.deleted.json
new restores old.layout.json: byte-equal, applied [2], dropped []
00:01 +1: All tests passed!
$ cmp old.layout.json new.layout.json && echo "layouts byte-equal"
layouts byte-equal
# python3 -I, comparing the two deletes:
old.deleted len 6756 new.deleted len 6722
top-level key differs: components
components z.next old {'22': {'v': 1, 'nested': {'b': [1, 2]}}, '24': {'v': 2}} new {'24': {'v': 2}}
```

The claims hold:
- **Each release reads the other's plans and layouts byte for byte.**
  Layouts written by each tree are byte-equal.
- **A 0.4.0 plan holding an orphan** (`old.deleted.json`: `z.next` on the
  dead handle 22) loads in 0.5.0 byte for byte. A 0.5.0 delete and undo
  of another table on it keeps the orphan and gives the file back byte
  for byte. That is the CHANGELOG's "orphaned entries an older release
  left in a plan load and save as they are".
- **Undo restores exactly** in both. In 0.5.0 that includes the unknown
  payload, with its nesting.
- **The only byte difference between the two deletes** is the unknown
  payload 0.4.0 leaves behind.

## Check 3 — versions

```
$ grep -n "^version:" packages/*/pubspec.yaml apps/*/pubspec.yaml tool/ci/pubspec.yaml
packages/jet_cad_2d_gpu/pubspec.yaml:6:version: 0.5.0
packages/jet_cad_2d/pubspec.yaml:5:version: 0.5.0
packages/jet_cad/pubspec.yaml:3:version: 0.3.0                 # dormant (R-8)
packages/jet_cad_2d_flutter/pubspec.yaml:6:version: 0.5.0
apps/dev_harness_2d/pubspec.yaml:7:version: 0.0.1
packages/jet_cad_restaurant_symbols/pubspec.yaml:8:version: 0.5.0
packages/jet_cad_floor_plan/pubspec.yaml:8:version: 0.5.0
apps/dev_harness/pubspec.yaml:4:version: 0.0.1
apps/restaurant_demo/pubspec.yaml:7:version: 0.0.1
apps/floor_planner/pubspec.yaml:7:version: 0.0.1
tool/ci/pubspec.yaml:7:version: 0.1.0
```

**Stray versions.** I ran `git grep -nE '0\.4\.0|v0\.4|0\.5\.0|v0\.5' -- .
':!docs/superpowers' ':!*.lock' ':!*lock.txt' ':!CHANGELOG.md'
':!STATUS-HISTORY.md'`. Every hit is one of these:
- the five pubspecs;
- `ci.yml` l. 166–170 and `scripts_test.dart` l. 266, 286 (the P-1 job);
- STATUS's history and post-merge lines (l. 3–4, 26–27, 130–208,
  234–238, 302–303, 548);
- the roadmap's row 14 (release 0.4.0's line);
- the `cross_file` comment;
- the guide's 0.5.0 lines (Check 4) and its "since 0.4.0" markers, which
  are right: those features are 0.4.0's.

Nothing stale needs to move. In the scratch `new` worktree, `git status
--short` was empty after `flutter pub get`, so the workspace lock and
the three `analysis_options.yaml` are unchanged by it.

## Check 4 — `docs/host-guide.md`

- **Header** (l. 7): **0.5.0**.
- **§1 is the 0.4.0 release commit's, version for version:**
  ```
  $ diff <(git show 84c76df:docs/host-guide.md | sed -n 1,56p | sed 's/0\.4\.0/0.5.0/g') <(sed -n 1,56p docs/host-guide.md) && echo "§1 identical to 84c76df's, version for version"
  §1 identical to 84c76df's, version for version
  ```
  `84c76df` is 0.4.0's release commit. l. 18–19 read "the SHA the
  release tag `v0.5.0` points at (`git rev-parse 'v0.5.0^{commit}'`; the
  guide on `main` names it)"; l. 29 and l. 34 read `ref: <the commit SHA
  of v0.5.0>`; l. 41 reads `ref: v0.5.0`.
- **The post-merge edit, simulated.** I took `f5fa221` (0.4.0's "the
  guide names the release SHA"), changed 0.4.0 to 0.5.0 and the SHA to a
  dummy 40-hex value, and applied it in the scratch `new` worktree. Then
  I reverted it:
  ```
   docs/host-guide.md | 9 +++++----
   1 file changed, 5 insertions(+), 4 deletions(-)
  docs/host-guide.md: all 48 code blocks are in the host probe
  check_guide exit=0
  00:00 +5: All tests passed!          # tool/ci test/guide_test.dart
  reverted
  ```
- **The new sharing sentence** (l. 2006–2007): "0.4.0 and 0.5.0 save the
  same plans and service layouts, so they can share them". It is true:
  the format is the same (Check 2), and for every type either release
  writes, the same edits save the same bytes (Check 7).
- **Nothing in the guide contradicts O-8:**
  - l. 1098–1099: "Delete drops it; Undo brings it back. Deleting a table
    in the editor removes its data in the same step."
  - l. 1641–1644: `deleteSelection()` deletes "one undo step, a deleted
    table's data gone with it and back with its undo".

  Both hold in 0.5.0 (Check 2's act phase; TD7 and HD12 unedited). The
  guide says nothing about other components on delete, nor about
  permission profiles (a host has none to set). The "since 0.4.0"
  markers are unchanged and right. There is no "unreleased" marker:
  `grep -n -i 'unreleased\|not yet released\|on main\b\|on \`main\`'`
  finds only l. 19, the placeholder's "the guide on `main` names it".
- **The floor paragraph** (l. 51–52): "Flutter 3.44 or later; 0.5.0 was
  built and tested with Flutter 3.47.6". The SDK constraints are
  unchanged in the range, and the probe's lock says `flutter:
  ">=3.44.0"`.

```
$ dart run tool/ci/check_guide.dart          # in the release worktree
docs/host-guide.md: all 48 code blocks are in the host probe
check_guide exit=0
$ cd tool/ci && dart test 2>&1 | tail -3
00:03 +61: test/scripts_test.dart: SC19 old_host_probe.sh the tag's main.dart analysed; this commit's put back
00:04 +62: test/scripts_test.dart: SC19 old_host_probe.sh analysis fails: exit non-zero, main.dart put back
00:04 +63: All tests passed!
tool/ci test exit=0
```

## Check 5 — the probes and the gates

**The probes, from the release worktree** (one command, in sequence):

```
$ git rev-parse HEAD
382f071aa9ae31db8204fb0fbfcab779c2e712fd
$ tool/ci/host_probe.sh "file:///Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/release-0.5.0" 382f071aa9ae31db8204fb0fbfcab779c2e712fd; echo "probe exit=$?"
…/tool/ci/host_probe/pubspec.lock: 40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu
No issues found! (ran in 3.7s)
Compiling lib/main.dart for the Web...                             36.3s
✓ Built build/web
host probe: no GPU renderer, no build hook; build/web is  42M
probe exit=0
$ tool/ci/old_host_probe.sh v0.4.0; echo "old probe v0.4.0 exit=$?"
Analyzing host_probe...
No issues found! (ran in 3.8s)
old host probe: v0.4.0's main.dart analyses against 382f071aa9ae31db8204fb0fbfcab779c2e712fd
old probe v0.4.0 exit=0
$ tool/ci/old_host_probe.sh v0.3.0; echo "old probe v0.3.0 exit=$?"
Analyzing host_probe...
No issues found! (ran in 3.8s)
old host probe: v0.3.0's main.dart analyses against 382f071aa9ae31db8204fb0fbfcab779c2e712fd
old probe v0.3.0 exit=0
$ git status --short          # afterwards
(empty)
```

The probe's lock resolves the four host packages at `resolved-ref:
"382f071aa9ae31db8204fb0fbfcab779c2e712fd"` (4 matches), each at
`version: "0.5.0"` (4 matches). Its `sdks:` reads `dart: ">=3.13.0
<4.0.0"`, `flutter: ">=3.44.0"`.

**`flutter analyze`**, in the scratch `new` worktree at `382f071`:

```
== packages/jet_cad_2d              No issues found! (ran in 2.0s)  exit=0
== packages/jet_cad_2d_flutter      No issues found! (ran in 4.9s)  exit=0
== packages/jet_cad_floor_plan      No issues found! (ran in 6.4s)  exit=0
== packages/jet_cad_restaurant_symbols No issues found! (ran in 3.3s) exit=0
== packages/jet_cad_2d_gpu          No issues found! (ran in 2.6s)  exit=0
== apps/restaurant_demo             No issues found! (ran in 3.1s)  exit=0
```

**The suites** (R-6):

```
$ cd packages/jet_cad_2d && dart test
00:11 +1281 -2: Some tests failed.
  test/testing/generate_document_test.dart: both text fractions default to zero and change nothing
  test/testing/generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte
$ cd packages/jet_cad_2d_flutter && flutter test
… text ladder rung 1–5 (RenderBackend.canvas) [E]
00:28 +1432 ~1 -5: Some tests failed.
$ cd packages/jet_cad_floor_plan && flutter test --enable-vmservice
02:09 +1915: All tests passed!
$ cd apps/restaurant_demo && flutter test
00:20 +68: All tests passed!
```

## Check 6 — a POS's graph (Monépro)

I copied Monépro's `pubspec.yaml` and `pubspec.lock` (develop, `e4cb1f1`,
"docs(cloud): verify #620's background Flutter install in a cloud VM
(run 5) (#626)") to `rel5-review/monepro-res`. Monépro has no jet-cad
dependency to repoint (`grep jet_cad` finds nothing in either file). As
the guide's §1 says, I added `jet_cad_floor_plan` and
`jet_cad_restaurant_symbols` by git at `file://<release worktree>`, `ref:
382f071aa9ae31db8204fb0fbfcab779c2e712fd`. Nothing in Monépro was
touched, and its `git status --short` is empty.

```
$ flutter pub get
+ jet_cad_2d 0.5.0 from git …/release-0.5.0 at 382f07 in packages/jet_cad_2d
+ jet_cad_2d_flutter 0.5.0 from git …/release-0.5.0 at 382f07 in packages/jet_cad_2d_flutter
+ jet_cad_floor_plan 0.5.0 from git …/release-0.5.0 at 382f07 in packages/jet_cad_floor_plan
+ jet_cad_restaurant_symbols 0.5.0 from git …/release-0.5.0 at 382f07 in packages/jet_cad_restaurant_symbols
> pdf 3.13.1 (was 3.13.0)
> printing 5.15.1 (was 5.15.0)
Changed 6 dependencies!
pub get exit=0
$ dart run …/tool/ci/check_host_lock.dart pubspec.lock
pubspec.lock: 190 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu
lockcheck exit=0
# python3 -I, both locks parsed:
packages 186 -> 190
jet_cad_2d None -> 0.5.0
jet_cad_2d_flutter None -> 0.5.0
jet_cad_floor_plan None -> 0.5.0
jet_cad_restaurant_symbols None -> 0.5.0
pdf 3.13.0 -> 3.13.1
printing 5.15.0 -> 5.15.1
# sdks: identical before and after
  dart: ">=3.12.0 <4.0.0"
  flutter: ">=3.44.0"
```

`resolved-ref: "382f071a…"` has 4 matches, and no GPU renderer is in the
graph. Monépro pins `flutter-version: 3.47.6` in `deploy-staging.yml`,
`deploy-production.yml`, `tests.yml` and `quality-gates.yml`. See R-7.

## Check 7 — the CHANGELOG's intro and Known limits

**The question.** The intro says "Nothing is stored differently" and "a
restaurant may move its terminals one at a time". Can a 0.4.0 terminal
and a 0.5.0 terminal sharing one plan disagree in a way a host would
notice?

**Differential tests.** I put two more temporary tests in each scratch
tree (removed afterwards). Each runs the same edits in both trees and
compares the saved bytes:

1. `test/host/xfer_plain_test.dart`, through the host API in a mounted
   `FloorPlanView`:
   - `deleteSelection()` of table `3` of the embedding fixture;
   - every root-level object of the demo's `salon.json` (13 instances)
     selected and deleted in one step, then undone.
2. `test/xfer_walls_test.dart`, in the shell's rig (the parametric
   system, then the table system, `tables/table_data_test.dart`'s
   `rig()`). The plan has:
   - a non-zero layer;
   - a table turned and mirrored, with host data;
   - a wall off the origin and turned 1.2 rad, hosting a door, both on
     that layer through `ObjectLayer`.

   The steps are: delete the table (`deleteTable`), then the wall
   (`deleteLikeSelectTool`, whose cascade takes the door); undo both;
   redo both.

```
00:01 +2: All tests passed!     # plain old      (old salon: 13 deleted in one step; undo ok)
00:01 +2: All tests passed!     # plain new      (new salon: 13 deleted in one step; undo ok)
plain3: old == new byte for byte
salon-empty: old == new byte for byte
salon-undone: old == new byte for byte
00:00 +1: All tests passed!     # walls old
00:00 +1: All tests passed!     # walls new
w0: old == new byte for byte    # before
w1: old == new byte for byte    # table deleted
w2: old == new byte for byte    # wall and door deleted
wu: old == new byte for byte    # both undone
w3: old == new byte for byte    # both redone
redo == delete (new)
w0 {'floor_planner.opening': ['29'], 'floor_planner.wall': ['25'], 'jet_cad.object_layer': ['25', '29'], 'jetcad.seating': ['19'], 'jetcad.symbol': ['19'], 'jetcad.table_data': ['23']}
w1 {'floor_planner.opening': ['29'], 'floor_planner.wall': ['25'], 'jet_cad.object_layer': ['25', '29'], 'jetcad.seating': ['19'], 'jetcad.symbol': ['19']}
w2 {'jetcad.seating': ['19'], 'jetcad.symbol': ['19']}
```

The walls test's first run compared the undone plan's raw bytes with the
plan before. It failed in **both** trees, at an entity's slot order
(`"handle":26` against `"handle":27`): slot order is history (06 D11),
which is why the suite's own P-1 to P-3 compare `canon()`. The rerun
compares `canon()` for that assertion and still writes the raw bytes. The
raw undone bytes are equal across the trees (`wu`).

**Findings:**
- **"Nothing is stored differently" is accurate.** The format is the
  same. For every type 0.4.0 and 0.5.0 write, the same edits save the
  same bytes, deletes, undos and redos included. The one difference is an
  unknown payload on a deleted node (Check 2), which neither release
  writes.
- **"A restaurant may move its terminals one at a time" is accurate.**
  - History is not stored (design, Risks), so a 0.5.0 Undo never has a
    0.4.0 delete to undo.
  - A 0.4.0 delete leaves no entry of any type either release writes.
  - The only orphan a 0.4.0 terminal can leave, a newer release's
    payload, is loaded and saved unchanged by 0.5.0.

  No host-visible disagreement remains (R-5): not in `tables`,
  `tableDetails`, `designJson()` bytes, `dirty`, or what Undo restores.
- **The bullets.** "Undo brings them back exactly" holds (Check 2,
  unknown payload with nesting). "Plans are unchanged (schema 9)" holds.
  The wording point is R-2; the two additions missing from the bullets
  are R-1.
- **Known limits.** "0.4.0's stand": nothing in the range touches them
  (`git diff --stat` above: no host, view or theme file changed). "A plan
  an older release edited may still hold entries of nodes it deleted;
  they load and save as they are, and nothing removes them" is shown by
  Check 2's read phase. The GPU package, `packages/jet_cad` and the apps
  are outside the release, as before.
- **Recorded in the design, not owed here:**
  - no `validate()` diagnostic for orphans (O-2);
  - no purge-time sweep (O-3);
  - `loadJson` does not raise the seed past component handles (O-4).

  None is reachable through a file jet-cad writes.
