## Rulings made here rather than left to an implementer

Each ruling says what the plan does, why, and what it costs if wrong.
Those marked **(spec amended)** are written into the spec in Task 11 as
"Amended at execution (Plan 06)" paragraphs.

- **Ruling 06-1 — types live in a `ParametricCatalog` (spec amended, D3
  and D10).**
  - **The problem.** Revision 2 put `registerComponents` on
    `ParametricSystem`, whose constructor takes a document. But
    `DraftDocumentCodec.decode` *creates* the document, and it needs the
    factories *before* it loads components (`json_codec.dart:115`). A
    per-document system cannot exist yet at that point.
  - **The fix.** A document-free `ParametricCatalog` holds the types.
    - `catalog.register<T>(typeId, factory, type)` adds one.
    - `catalog.registerComponents` is what `decode` receives.
    - `ParametricSystem(document, catalog)` registers the catalog's
      components into that document and reads its types.
  - **Cost if wrong:** one indirection.
- **Ruling 06-2 — one library, two files.** `parametric_system.dart`
  declares `part 'regeneration.dart';`. The planner uses the private
  registration type, and a `part` keeps it private without widening the
  API. **Cost:** none.
- **Ruling 06-3 — the clean-up detaches only components of objects that
  were live before the edit (spec amended, D4 step 4).**
  - **Why.** Revision 2 says "every parametric component whose group node
    no longer exists". Taken literally, that would also detach a
    *misplaced* component on a leaf handle (D5) on every edit. A leaf
    handle has no tree node either.
  - **Cost if wrong:** a misplaced component survives a delete. It is
    already reported by `diagnostics()`.
- **Ruling 06-4 — a touched handle that *was* an object is a seed too.**
  An explicit `SetComponentCommand<T>(h, null)` turns a box back into a
  plain group. Its old neighbours must regrow, so `before.objects` handles
  seed as well as `after.objects` handles. **Cost:** none.
- **Ruling 06-5 — M-06b is "every sort removed" (spec amended, the mutant
  table).**
  - **Why.** The survey sorts the live objects, because it merges several
    types, and the closure sorts again. So the spec's "both" (planner and
    store) is three sorts here.
  - **The mutants.**
    - M-06b removes the survey's sort, the closure's sort and
      `ComponentStore.handles`' sort.
    - M-06b′ removes the closure's sort alone.
  - **Cost:** none.
- **Ruling 06-6 — M-06p's observable is child-handle stability, not raw
  bytes (spec amended).**
  - **Why.** A remove followed by an add reuses the freed slot, since the
    free list is LIFO (`slot_allocator.dart:52`). So the raw bytes can
    match while the child's handle changes.
  - **The kill.** P2 asserts that a width edit keeps every child handle.
  - **Cost:** none.
- **Ruling 06-7 — M-06f is fired as `ParametricSystem.install()`
  regenerating everything (spec amended).**
  - The stale-file test N9 turns red. The spike's probe answer, that
    regeneration on load is a no-op on a clean file, stands.
  - **Cost:** none.
- **Ruling 06-8 — where the transform mutants live.**
  - **M-06g (engine)** makes the system's `worldOf` return the identity.
    It is killed by the engine's relational tests.
  - **M-06g (app)** and **M-06o** live in `BoxType`, which is client code.
    They are killed by the app's rotated-pair tests.
  - **Cost:** none.
- **Ruling 06-9 — the test clients duplicate `BoxType`'s clipping on
  purpose.**
  - **Why.** The engine tests cannot import the app, and the fixture must
    not share a bug with the code it checks.
  - **Cost:** about sixty lines, twice.
- **Ruling 06-10 — new mutant M-06u:** `commit` ignores its `needs`
  argument. It is killed by `CN1` (Task 5).
- **Ruling 06-11 — `ParametricEdit`'s constructor is private.** Only the
  expander creates one, so "single-use" cannot be broken from outside. A
  test obtains one by calling `document.commands.expander!(command)`.
- **Ruling 06-13 — registration never re-registers (spec amended, D1).**
  - **The trap.** `ComponentRegistry.register<T>` *replaces* `T`'s store
    (`component.dart:74`), which wipes every component of that type. A
    second `ParametricSystem` over a loaded document would do exactly that.
    `drift()` checks and the app's SP5 build one.
  - **The fix.** The engine gains `bool ComponentRegistry.isRegistered<T>()`,
    a second small addition outside `parametric/`. The catalog registers a
    type only when it is not registered yet.
  - **Pinned by P10** and mutant **M-06v**.
  - **Cost:** one method.
- **Ruling 06-12 — the shell installs in `initState` and disposes in
  `dispose`.** A test that pumps `PlannerShell(document: doc)` installs on
  its own document. A second `install()` on one document throws, which is
  spec D2.

