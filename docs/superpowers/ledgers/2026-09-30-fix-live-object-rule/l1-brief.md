# L1 brief — the engine answers "which registration names this object"

You are the implementer for L1 on branch `fix/live-object-rule`, worktree
`/home/user/jet-cad/.claude/worktrees/fix-live-object-rule`. Work only there.
Read `CLAUDE.md`, then spec 06
(`docs/superpowers/specs/2026-09-24-parametric-layer-design.md`: D5, D6, D8,
D10) and `packages/jet_cad_2d/lib/src/parametric/` (`parametric_system.dart`,
`regeneration.dart`: `_isObject`, `_survey`, `_Registration`). Commit; do NOT
push.

## The defect (fix/post-11 note, "Found, not fixed": shadowing)
The engine's object rule (spec 06 D5, `_survey`): a live object is a
root-level `GroupNode` carrying a registered parametric component; when it
carries two, **the later registration names the object** and the earlier
one's component is a stray. The rule is private. The floor planner re-spells
"is this a live wall / opening / …" seven times (`is GroupNode && parent ==
root && get<T>(h) != null`), none of which knows the naming rule, so a file's
root-level group carrying `WallParams` and a later-registered `OpeningParams`
is an opening to the engine and a wall to the app. With a dangling host,
dragging a neighbouring wall throws `DanglingReferenceError` from pointer
dispatch. The human ruled: the engine exposes the rule; the app (L2, not
yours) routes every spelling through it.

## The change (ruled; the shape is yours to justify)
1. **One private rule** in `regeneration.dart`: the registration naming `h`
   in `t`, or null — null unless `t.tree[h]` is a `GroupNode` whose parent is
   the root; otherwise the **last** registration (catalog order) whose
   component `h` carries, or null if none. `_isObject` becomes "that is not
   null"; `_survey` decides `found`/`stray` by it (a shadowed component stays
   in `stray` exactly as today). No behaviour change in the engine: prove it
   (the full engine suite unchanged, plus your own reading).
2. **A public query on `ParametricCatalog`** (the app holds the catalog as a
   global; `ParametricSystem` exposes `catalog`), built on that same private
   function:
   - `bool names<T extends Component>(CommandTarget t, Handle h)`: `h` is a
     live object of `t` and `T`'s registration names it. False for an
     unregistered `T`.
   - `List<Handle> objectsOf<T extends Component>(CommandTarget t)`: every
     such `h`, ascending by handle value (walk `withComponent<T>()`, filter,
     sort — the app's `liveObjectsOf` does exactly this today).
   Names are a suggestion; pick ones that read well at the call sites
   (`catalog.names<WallParams>(doc, h)`). Decide and justify how "`T`'s
   registration" is matched (`r is _Registration<T>`, `r.type is
   ParametricType<T>`, a stored `Type`): it must be exact — `names<Component>`
   must not answer true for everything; state what it answers and pin it.
   If a type could be registered twice, say what happens (read `register` and
   `registerInto`, Ruling 06-13) — do not add a check unless you find a real
   path.
   Doc comments say: this is the engine's own rule (D5), the one `_survey`
   uses; a client that asks "is this a live `T`" must ask here.
3. Export: `lib/jet_cad_2d.dart` already exports `parametric_system.dart`;
   confirm nothing else is needed.

Cost: `names` is O(types) per call; no frame path calls it today (the app's
callers run on edits, grip-cache rebuilds, tool events and the band cache's
rebuild). Say so; do not add caches.

## Tests (a test lands only if a named mutant turns it red)
Beside the existing parametric tests (`packages/jet_cad_2d/test/parametric/`;
reuse the registered test types there, at least three of them, so "later"
and "earlier" are not the first and last registered). Non-degenerate: groups
rotated and translated off the origin; handles not the lowest allocated.
At least:
- a root-level group carrying one type: `names<ThatType>` true, every other
  registered type false; `objectsOf` lists it.
- a root-level group carrying two types A (registered earlier) and B
  (later): `names<B>` true, `names<A>` false, `objectsOf<A>` omits it,
  `objectsOf<B>` lists it; and the **survey agrees** — the object the
  system regenerates is B's (observe it through what the survey drives:
  `drift()`, a regeneration, `diagnostics()`, whichever is observable).
  The same pair registered in the opposite order in a second catalog flips
  both answers (the rule is order, not type identity).
- a nested group, a root-level `InstanceNode`, a leaf, a deleted object's
  handle (component still in the store, as a file would leave it: write the
  store the way the fix/post-11 fixtures do, not through `ParametricEdit`),
  a never-allocated handle: all false; `objectsOf` omits them.
- an unregistered component type: false.
- `objectsOf` ascending when handles were allocated out of order (e.g. attach
  to a higher handle first).
Mutants (fire each; record the red test and line): M-L1a the public query
checks only `get<T>(h) != null` (the app's current spelling); M-L1b the
**first** registration names the object (in the public query only); M-L1c
the same in the private rule (both the survey and the query — which tests
go red, engine suites included?); M-L1d parent check dropped (a nested group
passes); M-L1e `GroupNode` check dropped (an instance passes); M-L1f
`objectsOf` unsorted. Add your own where these miss a seam.

Procedure (binding): `cp` the file to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/l1-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --`
a .dart file. `CI=true` on every test command. Never synthesize output. Never
commit `analysis_options.yaml`.

## Docs
Spec 06 D5: an "Amended by fix/live-object-rule" paragraph in the style of
the existing ones: the naming rule stated (a root-level group carrying two
registered types is the later registration's object; the earlier component is
a stray the diagnostics report), and that `ParametricCatalog` exposes it —
the only rule a client may use.

## Gates
```sh
export PATH=/root/flutter/bin:$PATH
(cd packages/jet_cad_2d         && CI=true dart test ; CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd packages/jet_cad_2d_flutter && CI=true flutter test ; CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd apps/floor_planner          && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
```
Branch point (019aedb): engine 1,090 + 2 standing
(`test/testing/generate_document_test.dart`); render 940 + 1 skip + 7
standing (`text_ladder` 1–5, `text_lod_ladder` 1–2); app 503. Paste summaries
and exit codes. The app must stay at 503 (L1 changes no app file).

## Commit and report
`feat(engine): ParametricCatalog answers which registration names an object`,
ending with
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv
```
Write `.superpowers/sdd/fix-live-object-rule/l1-report.md` and return it:
hash; the API and the matching decision with their cost; every mutant with its
red test and line; gates; deviations; anything found outside scope (reported,
not fixed).
