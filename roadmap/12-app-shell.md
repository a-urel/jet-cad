# 12 — Application shell

**Status:** not started
**Depends on:** 02, 04, 05
**Blocks:** nothing
**Size:** L

---

## What this delivers

Everything around the canvas: the menu bar (File, Edit, Insert, Design, View),
the toolbar (undo, redo, pan, select, line, text, zoom percentage), the
property panel on the right, a layer panel, and file open / save / save-as /
recent.

## Why it exists

It is the last third of the target screenshot and the point at which the
product becomes usable by someone who is not running it from an IDE.

**It is deliberately late.** Each earlier sub-project adds its own thin
affordance to 01's skeleton; this one consolidates them. A shell written before
the things it wraps gets written twice.

## What already exists

- **The codec** — `packages/jet_cad_2d/lib/src/codec/json_codec.dart`,
  deterministic and versioned (`schema_version.dart`). File I/O is a thin
  wrapper over it.
- **`CommandDispatcher`** — `undo.dart:48`, with `execute` (`:102`), `undo`
  (`:117`), `redo` (`:145`), `notifyLoaded` (`:167`), `notifyPurged` (`:176`),
  `clearHistory` (`:183`), and a `Stream<DocChange>` of changes.
- **`UndoStack`** — `undo.dart:10`, `limit` default 200.
- **`DraftPermissions`** — `command.dart:29`, with `all`, `runtime` and
  `readOnly` presets. Read-only and restricted modes already exist.
- **Style tables** — `tables.dart`, `style.dart`, `style_resolver.dart`,
  `resolved_style.dart`, `style_context.dart`. Layers, colours, linetypes and
  lineweights, with a resolution chain.
- `Node.visible` (`node.dart:27`) — visibility already exists in the model.
- `validate.dart`, `diagnostic.dart` — document validation and diagnostics,
  for an error surface.

## What does not exist

- All of it. No menu, no toolbar, no panel, no file dialog, no keyboard
  shortcut handling, no preferences.

## Decisions already made

1. **The property panel is hand-written per type, not reflective over
   components.** A generic panel that reflects over `Component.toJson()` is
   tempting and is a trap: components are `Map<String, Object?>` at the
   serialization boundary with no type, range, unit or label information, so
   the generic panel would need a parallel schema — which is the hand-written
   panel with extra steps and no type safety.
2. **File format is the existing JSON codec.** No new format.
3. **Undo and redo are wired to `CommandDispatcher`**, which already does the
   work. The shell shows state; it does not own history.

## Open questions — these are the spec

- **What is in each menu**, and which items are v1?
- **Keyboard shortcuts**, and whether there is a command palette. A CAD tool
  conventionally has a command line; a consumer tool does not.
- **Autosave and crash recovery.** The codec is deterministic, which makes
  this cheap; deciding it is out of scope is fine if it is deliberate.
- **Recent files** — where is that list stored?
- **The layer panel's scope.** Create, rename, colour, visibility, lock. Is
  lock a new concept? `Node.visible` exists; nothing lock-shaped does.
- **Does the property panel edit multiple selections?** "Change the colour of
  these six things" is one command or six — and six is the compound-command
  problem from 06 again.
- **The zoom control** — a percentage relative to what? A percentage is only
  meaningful once 04 has fixed a paper size and a unit.
- **Dirty-state tracking and the close prompt.** `DocChange` gives the signal.
- **Error surface.** `validate.dart` and `diagnostic.dart` produce
  diagnostics; nothing displays them.
- **Does `DraftPermissions` reach the UI**, so a read-only document greys out
  its tools?

## Exit criteria sketch

- New / open / save / save-as work, and a save → open round-trip is
  byte-identical.
- Undo and redo buttons reflect stack state and are disabled when empty.
- The property panel edits a selected object's properties, one undo step per
  edit.
- The layer panel toggles visibility and the canvas reflects it.
- A read-only document (`DraftPermissions.readOnly`) disables editing
  affordances and no command reaches the dispatcher.
- Closing with unsaved changes prompts; closing clean does not.

## Named mutants to fire

- **M-12a:** ignore `DraftPermissions` in the UI while the dispatcher still
  enforces it. A read-only test asserting no `PermissionDeniedError` is thrown
  must go red — **the UI must not rely on the dispatcher throwing.**
- **M-12b:** write the file with a non-deterministic key order. The
  byte-identical round-trip test must go red.
- **M-12c:** dispatch one command per property field rather than one per edit.
  The one-undo-step test must go red.
- **M-12d:** leave the dirty flag set after a successful save. The close-clean
  test must go red.
- **M-12e:** in the layer panel, toggle `visible` without notifying. The canvas
  test must go red — **and it may not, because `shouldRepaint` is
  unconditionally false on the canvas painter.** Verify the notification path
  actually reaches paint.

## Traps

- **A reflective property panel** looks like less work and is more. Components
  carry no schema.
- **`shouldRepaint` is unconditionally false** on the existing canvas painter,
  and Plan 3i's `_TableListenableAdapter` defect was exactly a table change
  that never reached the frame. A panel that edits state the canvas reads must
  prove the frame happens.
- **`UndoStack.limit` is 200.** A property panel that dispatches per keystroke
  silently empties the user's history.
- The codec is byte-deterministic on purpose and three plans depend on it. Any
  file writing that reorders keys breaks a property the repository treats as
  load-bearing.

---

## Standing context — read before touching anything

**Repo:** `/Users/ahmeturel/Projects/oss/jet-cad`, Dart/Flutter workspace,
branch `main`. **Read `STATUS.md` first**, then `CLAUDE.md`. The full roadmap
context, the target and the dependency graph are in `roadmap/00-README.md`.

**The target:** a **parametric** floor planner. Walls have thickness and clean
up at their corners, openings cut the walls that host them, rooms follow the
walls that enclose them. Chosen by the human on 2026-08-29 over the
stencil-diagram alternative.

**This file is an input to `superpowers:brainstorming`, not a plan.** Read it,
brainstorm, write a spec into `docs/superpowers/specs/`, write a plan into
`docs/superpowers/plans/`, then execute it task by task with
`superpowers:subagent-driven-development`.

**Packages:**

- `packages/jet_cad_2d` — the pure-Dart engine. **No Flutter, no `dart:ui`,
  ever.**
- `packages/jet_cad_2d_flutter` — the Flutter render layer. Here
  `unused_import` and `unused_element` are **errors**.
- `apps/dev_harness_2d` — the measurement harness. An instrument, not a
  product; do not grow the product inside it.

**Non-negotiables (`CLAUDE.md`):**

- The frame path allocates **nothing per entity** in steady state, O(1) per
  flush. Gated by `query_allocation_test.dart` and `paint_allocation_test.dart`.
- **Draw order is ascending handle value**, stable across undo, save, load and
  purge.
- Geometric **decisions** use `Tolerance`; **stored value** comparisons are
  exact `==`.
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three
  of them in this workspace.
- **Never synthesize test output.**
- Code, comments and commit messages in English.

**Every task ends green:**

```sh
cd packages/jet_cad_2d          && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter  && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

**Prefix test commands with `CI=true`** — otherwise Dart's analytics
phone-home blocks the runner for minutes at roughly zero CPU.

**Never `git checkout` a file to revert a mutation.** Copy aside with `cp`,
mutate, restore from the copy, `diff` to verify.

**The testing bar.** Defects here surface through **mutation and differential
testing**, not through reading. The dominant failure mode is the **degenerate
fixture** — a test that passes because every fixture sits at the identity
transform, the origin, or a default attribute. A new test is worth landing only
if a **named mutation** makes it go red. This repository has repeatedly caught
instruments that could not fail; assume yours is one until a mutant proves
otherwise.

**Scale note.** A floor plan is 500–5,000 entities, not 500,000. The repo's own
figures: a 10,000-entity frame is 9.5 ms at `DASHED=0`, and the vertices sink
draws 10,000 entities in 5.71 ms build / 6.68 ms raster. **Default the tile
cache off** (`DraftCanvas(tiles: false)`) and turn it on only if a measurement
demands it. Plan 3i's blurry-zoom behaviour is a 500,000-entity problem.
