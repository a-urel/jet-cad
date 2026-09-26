# Task 2 — carried from Task 1's review (binding, in addition to the plan's Task 2)

1. **I-1 (Important).** A deleted referent's component is still visible while the
   edit is planned: `_run` computes the D8 cleanup (`regeneration.dart` ~386) but
   applies it only at ~418, after `_plan` has called `generate` (~399);
   `ParametricView.paramsOf` (`parametric_system.dart` ~116) reads components
   directly, so a referrer pulled in by `before.referrers` still sees its dead
   host's component, with `toWorld` falling back to the identity. Reviewer's
   probe on 328df0b: Post A + Pin P, then `deleteObject(doc, hA)` (the select
   tool's cascade, from `guards_test.dart`) printed
   `probe3: A component after edit: null; P segments before 1, after [[1.8e-12, 4.5e-13, 2000.0000000000018, 2.3e-13]]`
   then `Expected: empty Actual: [3000]` — P drew A's edge at the world origin.
   **Ruling:** the view answers `null` from `paramsOf` for an object lost in
   this edit (an object before, not after), so spec D4 ("an orphan sees
   `paramsOf(host) == null`") and M-08f0 ("a childless group") hold as
   written. Pin it with a test (the probe, with the orphan policy client and
   with no cascade) and a mutant (the view reads the component directly) that
   must go red. If you find a cleaner seam (e.g. applying the cleanup before
   planning), report it before choosing it.
2. **m-1.** The closure's before/after halves are not each pinned. Add RF
   tests: "delete a Pin" and "re-point a Pin from Post A to Post C" (kill
   dropping `references_before(seeds)`: `Expected: empty Actual: [1000]`);
   "a loaded Pin names a plain group that then becomes a Post" (kills
   dropping `referrers_after(core)`); your orphan tests must kill dropping
   `referrers_before(core)` — fire all three and report.
3. **m-2.** Deduplication is not pinned: add a referrer declaring `[A, A]` to
   RF1 and fire "a plain list instead of the set".
4. **m-3.** RC2 needs at least 4 warm-ups (its medians were JIT noise). Do not
   add a fast path.
5. Task 1's notes: `diagnose_test.dart` declares its own `Tag`/`TagType` — if
   you add `Tag` to `clients.dart`, avoid the shadowing (rename one, or reuse);
   `PostType.diagnose` emits `test.referrers` info entries — filter
   diagnostics assertions by code. Task 1's test-local `Peg` type may be
   replaced by your `Tag` if that keeps X1-sort killed.
