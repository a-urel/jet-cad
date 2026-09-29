# Plan 11 mutation log -- the spec's 75 mutants, the controls and the tasks' extras

**Tally: the spec's 75 named mutants re-fired at `5ddd96f` (Task 15's
head), each against its full killer list after the rulings, one fire per
site or form: 81 fires, 127 killer commands. All 75 are killed; 122 of the
127 commands are red.** The five green commands:

- `M-11vertex` at `AP3`: green, as ruled (Task 2 ruling (2): every cap
  point is a stored vertex, so `AP3` cannot see it; its killers are `AP1`
  and `AP2`, both red). Fired for the record.
- `M-11negzero` form 1 (`==` on the offset) at `DO3`: green. **A finding:**
  `DO3`'s round-trip equality holds whether or not `==` tells the zeros
  apart. The fixture was fixed, not the mutant (`b3ef430`): `DO3` asserts
  the reloaded `-0.0` dimension is not equal to its `+0.0` twin. Re-fired
  on that fixture: form 1 red at `DO3` (and `DP1`), form 2 still red at
  `DO3`. Both runs are logged below.
- `M-11attachedmoves`' second site (`DimensionGrips._pointOf`, found at Task
  13) at `GE2`, `GE3`, `GE5`: green; `GE1` and `GE4` red. The ledger names
  this site's killers only as "GE"; every GE test was fired, and the site
  is killed.

Every fire restored: `cp` back, `diff` exit 0, `git diff --quiet -- <file>`
exit 0 and `git diff --quiet -- packages/` exit 0, for all 81 fires and for
every later fire in this log (controls, split, re-fires, the probe).

**No mutant survives.** Carried item 1 (`R4-filterAll`, an extra) stopped
on a product finding; the fix round (`49de0e8`, the controller's ruling
under Ruling 11-19) fixed the product and killed it, with the new
`X16-hostVisible`. See "Carried item 1" and "Fix round".

**The procedure** (the Global constraints'): a Python driver
(`t16-fire.py`, specs in `t16-specs.py`, scratch `plan11/`) backs up each
file to `plan11/t16-<fire>.<file>.bak`, applies exact-string edits (each
asserted to occur once at HEAD), records `diff <backup> <file>`, runs each
killer, `cp`s the backup back and checks `diff`, `git diff --quiet --
<file>` and `git diff --quiet -- packages/`. A crash marker
(`t16-inflight.json`) is restored first on any restart. Commands use
`flutter test --no-pub` (a deviation from the plan's form: it keeps `pub
get` from rewriting `analysis_options.yaml` between fires). Each app
killer is `--plain-name '<ID> '`, the trailing space so `DL2` does not take
`DL2b`. Red lines below are the driver's extract of each log: the first
failing test in full, and every later failure's name and location.

## Reconciled with the plan and the ledger

Where the ledger and the plan disagree, the ledger's ruling wins; each
difference:

- **`M-11a` and `M-11axisworld`: `DZ1` dropped** from both killer lists
  (Task 8 ruling Minor 3: `DZ1`'s oracle shares `layoutDimension` and
  `measuringDirection`, probes green). Fired against `DL1`, `SP8` and `DR1`,
  `DR3`, `DR4`.
- **`M-11vertex`: `AP1` (+`AP2`), `AP3` dropped** (Task 2 ruling (2)).
  `AP3` fired for the record: green.
- **`M-11b`'s site** is `dimension_geometry.dart:392`, `final textHeight =
  kDimTextPaperMm * scale;` (Task 15: the recorded edit string was stale).
- **`M-11snaponly`: `TL6` only** (Ruling 11-6). The site is the tool's
  commit (its end decision gated on `hoverKind != null`); Task 9's second
  form (`M-11snaponly-third`) is in the extras.
- **`M-11runtime`: the render layer** (Ruling 11-25):
  `grip_cache.dart:273`, `leafGripsLive` returns true, against `GE4`.
- **`M-11fixedworld` and `M-11attachedmoves`: a second site each** in
  `DimensionGrips._pointOf` (Task 13), fired against every GE test.
- **`M-11sign`'s site** is `layoutDimension`'s `final below =
  offset.isNegative;` (Task 6 plan-wrong list; Ruling 11-3 named
  `offsetFor`). **`M-11offsetp0` has two sites** (Task 6): `layoutDimension`
  and `offsetFor`, both fired.
- **`M-11prefilter`: `TL8` added** (the plan's assignment). **`M-11sign`,
  `M-11between`: `GE2` added** (the plan's assignment).
- **`R6-dragSnap`'s site** is `packages/jet_cad_2d/lib/src/index/drag_snap.dart:72`
  (Task 15); an extra, killed by `TL9` at Task 15 (copied).
- **`X2-step1only` is not equivalent.** The plan (Task 16's Controls and
  spec D4/S-2) records it equivalent; the ledger's Task 2 ruling (1)
  accepted the implementer's finding that it is killed (the WR13 3° r/l
  wall at 299° reaches the reverse edge), with D4/S-2 amended at Task 17.
  Re-fired here: **red at `AP2`** (`dimension_attach_points_test.dart
  450:13`, 86.96 mm), green at `AP1`. Logged under "Controls".
- **`M-11shift`'s site** is the commit's `kindFor` (the third click,
  `dimension_tool.dart:283`); the preview's `kindFor` (`:427`) is the
  preview's Shift rule, pinned by `TL5` (`t10-keyIgnoresShift`).
- **The recorded equivalences, as ruled:**
  - **`R-noSimplify` is equivalent** (ledger, Task 2 Minor 1):
    `isSimpleCcw` counts proper crossings; duplicates and collinear spikes
    never change it.
  - **`M-3` (`rv9-shiftNotFromPointerDown`) is accepted as nearly
    equivalent** (ledger, Task 9 M-3): Shift taken from `onPointerDown` is
    unpinned, but hover and `onKey` set Shift first.

**A second copy of each rule** was grepped before declaring it single-site
(Ruling 11-18; `t16-secondsite-grep.log`): `measuringDirection`,
`readable`, `offsetFor`, the paper constants, `kDimLineweight`,
`isNegative`, `EntityFlags.unpickable`, the fixed-end transform, the
attached-end resolution, `drawnCapsOf`, `kindFor`, `roundHalfUp`, the kind
switch, `movable`, `pageKey`, `references`, the degenerate diagnostic, the
I key and the F3 gate. Every rule has one site except those fired at two
(`M-11offsetp0`, `M-11colour`, `M-11fixedworld`, `M-11attachedmoves`) or
recorded above (the preview's `kindFor`; the grips' and the tool's calls of
the shared `offsetFor`, `layoutDimension` and `attachCandidates`, which are
the one site; `main.dart:222`'s palette shortcut for I, which is not
`kShellLetterKeys`; `dimension.dart:212`'s text-height divide, which is
`X13-heightNoScale`).

## Findings and fixes

- **`M-11negzero` form 1 green at `DO3`** (above): fixed in `b3ef430`,
  re-fired red.
- **Carried item 2 (Task 15 Minor 1), `RR1`'s text band:** this task's
  sweep over 36 sub-pixel camera offsets at each scale and zoom (a scratch
  copy of `RR1`, never committed; `t16-rr1-sweep.log`) measured the worst
  edge error of the 3 × 3 darkest sample in device pixels:

  ```
  SWEEP 1:50 at 0.15 px/mm, worst error in device px over 36 offsets: 3x3 bottom 0.25 top 1.46; single bottom 1.25 top 0.46
  SWEEP 1:50 at 0.3 px/mm, worst error in device px over 36 offsets: 3x3 bottom -0.50 top 1.93; single bottom 1.50 top 0.93
  SWEEP 1:100 at 0.15 px/mm, worst error in device px over 36 offsets: 3x3 bottom -0.50 top 1.93; single bottom 1.50 top 0.93
  SWEEP 1:100 at 0.3 px/mm, worst error in device px over 36 offsets: 3x3 bottom 1.00 top 1.86; single bottom 2.00 top 0.86
  ```

  Single-pixel sampling moves the error to the bottom edge (2.00 px, at the
  two-pixel limit), so the ruling's first option was taken: the text band's
  tolerance is three device pixels (`7b55f12`); the extension line keeps
  two. `RR1` green at HEAD; `M-11b-cam`, `M-11b`, `rv15-textGap12` (the gap
  1.2 paper mm) and `rv15-textH23` (the cap height 2.3) re-fired red on
  the edited test (entries below).
- **Carried item 3 (Task 15 Minor 4)**, in the same commit: the unused `r`
  at `dimension_shell_test.dart:39` dropped; `RR3`'s reason on
  `dimText == '4.69'` reworded ("premise: the Hall's value (that a paper
  change regenerates nothing is DO2's)").

## Carried item 1: R4-filterAll -- stopped on a product finding

**The ruling carried (Task 4 Minor 2):** "a hidden/invisible wall or
opening child must not attach". `R4-filterAll` (the Task 4 reviewer's)
turns both candidate queries' `QueryFilter.rendering()` into
`QueryFilter.all()` in `dimension_attach.dart`.

**The probe first** (`t16_hidden_probe_test.dart`, scratch, never committed;
`t16-hidden-probe.log`): a group built with `GroupNode(visible: false)` (a
file can carry one; no command flips visibility), at the origin and at
corpusGroups, `attachCandidates` against the brute-force oracle. Handles
print in hex (`12` = wall A or C, `16` = wall B or S):

```
P1 origin hidden B: corner index [12/1/right] | brute [12/1/right, 16/0/right]
P1 origin hidden B: B far centre index [] | brute [16/1/centre]
P1 origin hidden B: B far faces index [] | brute [16/1/right] ;; index [] | brute [16/1/left]
P2 origin hidden S, visible door left: S/0/l index [16/0/left] | brute [16/0/left]
P2 origin hidden S, visible door left: S/0/c index [16/0/centre] | brute [16/0/centre]
P2 origin hidden S, visible door left: S/0/r index [16/0/right] | brute [16/0/right]
P2 origin hidden S, visible door right: S/0/l index [16/0/left] | brute [16/0/left]
P3 origin visible S, hidden door left: S/0/l index [] | brute [16/0/left]
P3 origin visible S, hidden door left: S/0/c index [] | brute [16/0/centre]
P3 origin visible S, hidden door left: S/0/r index [] | brute [16/0/right]
P4 origin nothing hidden: S/0/l index [16/0/left] | brute [16/0/left]
P1 corpus far origin, 23 deg, own groups hidden B: corner index [12/1/right] | brute [12/1/right, 16/0/right]
P2 corpus far origin, 23 deg, own groups hidden S, visible door left: S/0/l index [16/0/left] | brute [16/0/left]
P3 corpus far origin, 23 deg, own groups visible S, hidden door left: S/0/l index [] | brute [16/0/left]
```

(Excerpt; the log has every line: both swings, all three points, both
placements, each the same.)

- **P1** (the L `c2Walls`, B hidden): B never attaches, at its far end or
  at the shared corner. The product keeps a hidden wall out.
- **P3** (flushT, the door hidden, S visible): nothing attaches at S's
  flush end; the hidden door's children do not make their host a
  candidate.
- **P2** (flushT, **S hidden**, its door visible): **S attaches**, at all
  three points of its flush end, at both placements: the opening-host
  query (S-13) finds the visible door and adds its host without asking
  whether the host is visible. **The product attaches to a hidden wall.**
  Per the ruling ("if the product itself attaches to a hidden wall, that
  is a defect: report it and stop") and Ruling 11-19, this line of work
  stopped here: **no test was added and `R4-filterAll` stays unkilled**,
  pending the controller's ruling. Reachable only from a file (a hidden
  wall group hosting a visible opening).
  **Resolved:** the controller ruled it a defect in Plan 11's own code and
  it was fixed in `49de0e8`, with `AM6b`; see "Fix round".

**`R4-filterAll` against the probe** (`t16-R4-filterAll@probe-run1.log`,
restored, `diff` 0, `git diff --quiet` 0): P1 and P3 change (the hidden B
and the host of the hidden door both attach), P2 and P4 do not. So a test
on P1 or P3 would kill it; the P2 behaviour is the open question.

```
> P1 origin hidden B: corner index [12/1/right, 16/0/right] | brute [12/1/right, 16/0/right]
> P1 origin hidden B: B far centre index [16/1/centre] | brute [16/1/centre]
> P3 origin visible S, hidden door left: S/0/l index [16/0/left] | brute [16/0/left]
```


## Fix round: the hidden host (Ruling 11-19, the controller's ruling)

**The ruling:** P2 is a defect in Plan 11's own code (Task 4): D10 gathers
candidates with `rendering()` so that only what is drawn attaches. Fixed in
`49de0e8` (`fix(app): a hidden wall attaches no dimension through its flush
opening (11 D10)`):

- **Lib** (`apps/floor_planner/lib/parametric/dimension_attach.dart`): the
  opening-host query keeps a host only when
  `FilterEvaluator.acceptsNode(host, QueryFilter.rendering())` holds (the
  engine's public API; no package change): the host's group and every
  group above it visible. One evaluator per call, made at the first host
  found; one check per host, cached per group within the call; no walk
  over the document. The doc comment's step 2 says so.
- **The layer:** a `GroupNode` has no layer (only an `InstanceNode` does,
  and `acceptsNode` checks it there); a wall's children and an opening's
  are all generated on layer 0 (`draftRecord`), so a hidden layer 0 hides
  the opening's children from the query as well as the wall's. `AM6b`
  covers it: with layer 0 hidden nothing attaches at S's flush end or at
  C's start, where the brute-force oracle has a point. (A file that moves a
  wall's children, not its opening's, to another hidden layer is not
  covered: a group's children's layers cannot be read in O(1) through the
  public API; recorded as a limit, not reachable from any command.)
  **The same file-only gap** (the Task 16 review's Minor 2, added at Task
  17): a wall whose children carry `EntityFlags.invisible` under a visible
  group, while its opening's children are drawn, also still attaches
  through the opening; the group passes `acceptsNode`, and a group's
  children's flags cannot be read in O(1) either. Task 17's `6ed9688`
  names both cases in `attachCandidates`' doc comment.
- **Test** (`AM6b`, `dimension_attach_test.dart`, at the origin and at
  corpusGroups, against `bruteCandidates`, each hidden point asserted a
  brute-force candidate first): P1, a hidden B in an L attaches neither at
  its far end's three points nor at the shared corner (index `[A/1/right]`
  where brute force has `[A/1/right, B/0/right]`); P2, a hidden S hosting a
  drawn flush door gives no candidate at S/0's three points, both swings;
  P3, a drawn S with its door hidden gives none; the control with both
  drawn gives S/0's point; layer 0 hidden gives none.

**The mutants** (entries under "The entries", "Fix round"):

- `R4-filterAll` (both candidate queries `rendering()` → `all()`, the Task 4
  reviewer's; survived Task 4's suite and was deferred here): **red** at
  `AM6b` (`dimension_attach_test.dart 900:9`, P1's corner `[12/1/right,
  16/0/right]` for `[12/1/right]`), both placements.
- `X16-hostVisible` (the host test dropped): **red** at `AM6b`
  (`dimension_attach_test.dart 934:13`, P2's S/0/left `[16/0/left]` for
  empty), both placements.
- **Re-fired on the fix** (`49de0e8`): every mutant whose killers are in
  `dimension_attach_test.dart` or `dimension_attach_points_test.dart`, and
  `M-11snaponly` at `TL6`, 22 fires: `M-11nbrs`, `M-11swap`,
  `M-11swapjust`, `M-11fallback`, `M-11centremid`, `M-11localring`,
  `M-11vertex`, `M-11d`, `M-11d2`, `M-11nearest`, `M-11parallel`,
  `M-11lineardir`, `M-11centrefirst`, `M-11attachtol`, `M-11snapoff`,
  `M-11prefilter`, `M-11openinghost`, `M-11hostbox`, `M-11reachcull`,
  `M-11ownerring`, `M-11snaponly`, `X2-step1only`. **Each killer's
  verdict is the same as at `5ddd96f`** (the same commands red, and
  `M-11vertex`'s `AP3` and `X2-step1only`'s `AP1` green as before).
  `M-11openinghost` and `M-11ownerring` replace blocks that now carry the
  host test, so their edits were re-cut to the fixed text (same rule).
  Every restore `diff` 0, `git diff --quiet` 0, `packages/` 0.

## Controls

**The degenerate fixture** (Task 16's control; `t16_degenerate_control_test.dart`,
scratch, never committed): a horizontal dimension along a free,
centre-justified wall (0, 0)–(4000, 0), 200, at the origin, W/0/centre to
W/1/centre, offset 500, in a group at the identity, on a 1:50 mm page. It
asserts the text `4000`, the line (0, 500)–(4000, 500), `drift()` and the
oracle empty. Green unmutated (`t16-CTRL-baseline.log`: `00:00 +1: All
tests passed!`). Under each mutant, as the spec predicts it is blind to
almost all of them:

| mutant | the control | the named killers (above) |
|---|---|---|
| M-11a | green | red (`DL1`, `SP8`) |
| M-11axisworld | green | red (`DR1`, `DR3`, `DR4`) |
| M-11d | **red** (`'0'` for `'4000'`: both ends at k = 0) | red (`AP1`, `SP8`) |
| M-11d2 | green | red (`AP1`, `SP8`) |
| M-11swap | green | red (`AP1`) |
| M-11attachedmoves | green | red (`DR2`, `DR4`) |
| M-11fixedworld | green (no fixed end) | red (`DR2`, `DZ1`) |

Six of seven survive the degenerate fixture; each is killed by its
off-identity killers. Entries: `CTRL-*` below.

**`X2-step1only`**: killed at `AP2` (see "Reconciled"), entry below.

**`SL1`'s later clauses** (the ruling of Task 15 Minor 3: `SL1` stays one
test, a later clause's kill is logged on a scratch per-clause split,
`t16_sl1_split_test.dart`, generated from HEAD's `SL1` with each clause's
body verbatim, never committed). The split is green unmutated
(`t16-split-baseline.log`: `00:05 +8: All tests passed!`). Per clause:

| mutant | the committed `SL1` (first failure) | the split: red clauses |
|---|---|---|
| M-11pickflag | red, clause 1b (`click-e4`, line 256) | `click-e4`, `band` |
| M-11extflag | red, clause 1b (`click-e4`, line 256) | `click-e4`, `band` |
| M-11movable | red, clause 3 (`drag-diagonal`, line 335) | `drag-diagonal`, `rotation-grip`, `together` |

## Equivalent, accepted (cost) and N/A

None among the 75. From the ledger (copied, not re-fired), in the extras
table below: equivalent `R-noSimplify`, `rv8-noTriggered`,
`rv9-otherIsSelf`, `rv10r-clickPassesMap`, `t11-noEqualOther`,
`rv11-noOffsetGuard`, `rv11r-keyNoOrdinal`, `rv12-strictThreshold` and
`rv12-noNormalise` (the reviewers' "acceptable/equivalent"); accepted as
nearly equivalent `M-3` (`rv9-shiftNotFromPointerDown`); accepted
`rv6-alignedH1` (rounding-sized). `rv11r-keyNoDoc` and `rv11r-dropNoCancel`
survive as the Task 11 re-reviewer recorded them (unreachable or
unobservable in the shell) with no further ruling in the ledger. From the
final review: equivalent `rvF-previewFirstCandidate` and
`rvF-commitNoGenBump`; `rvF-paletteNotDrawing` survives as an inherited
gap (a post-11 follow-up). N/A: the Task 10 review's "three
near-equivalent" survivors are not named in the ledger.


## The spec's 75, one row per fire (the plan's Mutant assignment, after the rulings)

| mutant | fire (site / form) | task | site at HEAD | killers fired | result at 5ddd96f |
|---|---|---|---|---|---|
| M-11pickflag | `M-11pickflag` | 1 | `query_filter.dart:39` | QF1 red, SL1 red | KILLED |
| M-11snapflag | `M-11snapflag` | 1 | `spatial_index.dart:1472` | QF2 red, TL9 red | KILLED |
| M-11flagdraws | `M-11flagdraws` | 1 | `query_filter.dart:32` | QF1 red, RR1 red | KILLED |
| M-11nbrs | `M-11nbrs` | 2 | `dimension_geometry.dart:66` | AP1 red, DN1 red | KILLED |
| M-11swap | `M-11swap` | 2 | `dimension_geometry.dart:68` | AP1 red | KILLED |
| M-11swapjust | `M-11swapjust` | 2 | `dimension_geometry.dart:68` | AP1 red | KILLED |
| M-11fallback | `M-11fallback` | 2 | `wall_geometry.dart:534` | AP1 red | KILLED |
| M-11centremid | `M-11centremid` | 2 | `dimension_geometry.dart:65` | AP1 red | KILLED |
| M-11localring | `M-11localring` | 2 | `wall_geometry.dart:542` | AP2 red | KILLED |
| M-11vertex | `M-11vertex` | 2 | `dimension_geometry.dart:69` | AP1 red, AP2 red, AP3 green | KILLED |
| M-11d | `M-11d` | 2 | `dimension_geometry.dart:64` | AP1 red, SP8 red | KILLED |
| M-11d2 | `M-11d2` | 2 | `dimension_geometry.dart:64` | AP1 red, SP8 red | KILLED |
| M-11nearest | `M-11nearest` | 3 | `dimension_attach.dart:237` | AM1 red, AM3 red | KILLED |
| M-11parallel | `M-11parallel` | 3 | `dimension_attach.dart:247` | AM3 red | KILLED |
| M-11lineardir | `M-11lineardir` | 3 | `dimension_attach.dart:238` | AM3 red | KILLED |
| M-11centrefirst | `M-11centrefirst` | 3 | `dimension_attach.dart:277` | AM3 red | KILLED |
| M-11attachtol | `M-11attachtol` | 4 | `dimension_geometry.dart:35` | AM1 red | KILLED |
| M-11snapoff | `M-11snapoff` | 4 | `dimension_attach.dart:102` | AM4 red, TL6 red | KILLED |
| M-11prefilter | `M-11prefilter` | 4 | `dimension_attach.dart:180` | AM1 red, AM6 red, TL8 red | KILLED |
| M-11openinghost | `M-11openinghost` | 4 | `dimension_attach.dart:111` | AM6 red | KILLED |
| M-11hostbox | `M-11hostbox` | 4 | `dimension_attach.dart:111` | AM6 red | KILLED |
| M-11reachcull | `M-11reachcull` | 4 | `dimension_attach.dart:104` | AM1 red | KILLED |
| M-11ownerring | `M-11ownerring` | 4 | `dimension_attach.dart:104` | AM2 red | KILLED |
| M-11e | `M-11e` | 5 | `dimension_geometry.dart:435` | DF1 red, DF2 red, DF3 red | KILLED |
| M-11halfnaive | `M-11halfnaive` | 5 | `dimension_geometry.dart:435` | DF1 red, DF2 red, DF3 red | KILLED |
| M-11cmzero | `M-11cmzero` | 5 | `dimension_geometry.dart:466` | DF1 red | KILLED |
| M-11reduce | `M-11reduce` | 5 | `dimension_geometry.dart:484` | DF1 red | KILLED |
| M-11marks | `M-11marks` | 5 | `dimension_geometry.dart:476` | DF1 red | KILLED |
| M-11negzero | `M-11negzero-f1` | 6 | `dimension.dart:89` | DP1 red, DO3 green | KILLED |
| M-11negzero | `M-11negzero-f2` | 6 | `dimension.dart:59` | DP1 red, DO3 red | KILLED |
| M-11a | `M-11a` | 6 | `dimension_geometry.dart:363` | DL1 red, SP8 red | KILLED |
| M-11offsetp0 | `M-11offsetp0-layout` | 6 | `dimension_geometry.dart:369` | DL2 red | KILLED |
| M-11offsetp0 | `M-11offsetp0-offsetFor` | 6 | `dimension_geometry.dart:225` | DL2 red | KILLED |
| M-11sign | `M-11sign` | 6 | `dimension_geometry.dart:368` | DL2 red, TL3 red, GE2 red | KILLED |
| M-11between | `M-11between` | 6 | `dimension_geometry.dart:227` | DL2 red, TL3 red, GE2 red | KILLED |
| M-11fliptol | `M-11fliptol` | 6 | `dimension_geometry.dart:237` | DL4 red | KILLED |
| M-11flip | `M-11flip` | 6 | `dimension_geometry.dart:238` | DL3 red, DL4 red | KILLED |
| M-11textbelow | `M-11textbelow` | 6 | `dimension_geometry.dart:387` | DL3 red | KILLED |
| M-11slash | `M-11slash` | 6 | `dimension_geometry.dart:386` | DL3 red | KILLED |
| M-11extpage | `M-11extpage` | 6 | `dimension_geometry.dart:373` | DL3 red | KILLED |
| M-11b | `M-11b` | 7 | `dimension_geometry.dart:392` | DO2 red, RR1 red | KILLED |
| M-11page | `M-11page` | 7 | `dimension.dart:160` | DO2 red | KILLED |
| M-11text | `M-11text` | 7 | `regeneration.dart:556` | DO2 red, DN1 red | KILLED |
| M-11lw | `M-11lw` | 7 | `dimension_geometry.dart:261` | DO1 red | KILLED |
| M-11colour | `M-11colour-lines` | 7 | `dimension.dart:200` | RR3 red, DO1 red | KILLED |
| M-11colour | `M-11colour-text` | 7 | `dimension.dart:218` | RR3 red, DO1 red | KILLED |
| M-11extflag | `M-11extflag` | 7 | `dimension.dart:204` | DO1 red, SL1 red | KILLED |
| M-11stable | `M-11stable` | 7 | `dimension.dart:203` | DL5 red | KILLED |
| M-11degenerate | `M-11degenerate` | 7 | `dimension.dart:272` | DD1 red | KILLED |
| M-11broken | `M-11broken` | 7 | `dimension.dart:118` | DD2 red | KILLED |
| M-11closure | `M-11closure` | 8 | `regeneration.dart:397` | DN1 red, DN2 red, DZ1 red | KILLED |
| M-11refs | `M-11refs` | 8 | `dimension.dart:149` | DN1 red, DN3 red | KILLED |
| M-11c | `M-11c` | 8 | `dimension.dart:109` | DN1 red, DN2 red, DZ1 red | KILLED |
| M-11shift | `M-11shift` | 9 | `dimension_tool.dart:283` | TL2 red | KILLED |
| M-11dragside | `M-11dragside` | 9 | `dimension_tool.dart:223` | TL2 red | KILLED |
| M-11zerokind | `M-11zerokind` | 9 | `dimension_tool.dart:225` | TL2 red | KILLED |
| M-11ortho3 | `M-11ortho3` | 9 | `dimension_tool.dart:175` | TL2 red | KILLED |
| M-11degeneratepair | `M-11degeneratepair` | 9 | `dimension_tool.dart:252` | TL4 red | KILLED |
| M-11twosteps | `M-11twosteps` | 9 | `dimension_tool.dart:299` | TL1 red | KILLED |
| M-11key | `M-11key` | 9 | `shortcut_guard.dart:17` | TL7 red | KILLED |
| M-11snaponly | `M-11snaponly` | 9 | `dimension_tool.dart:289` | TL6 red | KILLED |
| M-11notice | `M-11notice` | 10 | `dimension_tool.dart:460` | TL5 red | KILLED |
| M-11otherend | `M-11otherend` | 11 | `dimension_grips.dart:250` | GE3 red | KILLED |
| M-11gripoffset | `M-11gripoffset` | 11 | `dimension_grips.dart:235` | GE2 red | KILLED |
| M-11gripplace | `M-11gripplace` | 11 | `dimension_grips.dart:104` | GE1 red | KILLED |
| M-11runtime | `M-11runtime` | 11 | `grip_cache.dart:273` | GE4 red | KILLED |
| M-11previewkind | `M-11previewkind` | 11 | `dimension_grips.dart:134` | GE5 red | KILLED |
| M-11kindoffset | `M-11kindoffset` | 12 | `selection_panel.dart:566` | PN2 red | KILLED |
| M-11sectionmulti | `M-11sectionmulti` | 12 | `selection_panel.dart:334` | PN1 red | KILLED |
| M-11axesline | `M-11axesline` | 12 | `selection_panel.dart:641` | PN3 red | KILLED |
| M-11endlabel | `M-11endlabel` | 12 | `selection_panel.dart:601` | PN4 red | KILLED |
| M-11panelrw | `M-11panelrw-a` | 12 | `selection_panel.dart:639` | PN5 red | KILLED |
| M-11panelrw | `M-11panelrw-b` | 12 | `selection_panel.dart:564` | PN5 red | KILLED |
| M-11axisworld | `M-11axisworld` | 13 | `dimension_geometry.dart:195` | DR1 red, DR3 red, DR4 red | KILLED |
| M-11fixedworld | `M-11fixedworld` | 13 | `dimension.dart:119` | DR2 red, DZ1 red | KILLED |
| M-11fixedworld | `M-11fixedworld-grips` | 13 | `dimension_grips.dart:207` | GE1 red, GE2 red, GE3 red, GE4 red, GE5 red | KILLED |
| M-11attachedmoves | `M-11attachedmoves` | 13 | `dimension.dart:124` | DR2 red, DR4 red | KILLED |
| M-11attachedmoves | `M-11attachedmoves-grips` | 13 | `dimension_grips.dart:211` | GE1 red, GE2 green, GE3 green, GE4 red, GE5 green | KILLED |
| M-11scale | `M-11scale` | 13 | `dimension_geometry.dart:369` | DR5 red | KILLED |
| M-11movable | `M-11movable` | 15 | `dimension_grips.dart:143` | SL1 red | KILLED |
| M-11b-cam | `M-11b-cam` | 15 | `draft_painter.dart:959` | RR1 red | KILLED |

81 fires of 75 mutants, 127 killer commands, 122 red. Every mutant is killed.

## Part B -- invariants and greps

**Re-run by Task 17 on its final tree** (the Task 16 review's Minor 1;
Task 16's own run was at `b3ef430`, N = 32, and its reviewer's at
`75f04d7`, N = 35). From the repository root, `BASE=9774a55`,
`T1=015d95d` (`plan11/t17-partb.sh`: `t16-partb.sh`'s lines, the
`spike_dims` grep also run in its amended form with
`--exclude-dir=build`, and two reads added: `startup_plan_test.dart`'s
diff and the HEAD hash). Output `plan11/t17-partb.log`, verbatim. It ran
at `97fafbb`, Task 17's docs commit before this paste was amended into
it; the amend adds this paste only, so the tree the greps read and the
count are the final ones (`git rev-list --count` is unchanged by an
amend).

```
$ grep -rnE "^\s*(import|export)\s+.(package:flutter|dart:ui)" packages/jet_cad_2d/lib apps/floor_planner/lib/parametric/dimension_geometry.dart apps/floor_planner/lib/parametric/dimension_attach.dart apps/floor_planner/lib/parametric/wall_geometry.dart apps/floor_planner/lib/parametric/opening_geometry.dart apps/floor_planner/lib/parametric/room_trace.dart apps/floor_planner/lib/parametric/room_label.dart apps/floor_planner/lib/parametric/room_inputs.dart ; echo "exit $?"
exit 1

$ grep -nE "^\s*(import|export)\s" apps/floor_planner/lib/parametric/dimension_geometry.dart apps/floor_planner/lib/parametric/dimension_attach.dart
apps/floor_planner/lib/parametric/dimension_geometry.dart:14:import 'dart:math' as math;
apps/floor_planner/lib/parametric/dimension_geometry.dart:16:import 'package:jet_cad_2d/jet_cad_2d.dart';
apps/floor_planner/lib/parametric/dimension_geometry.dart:17:import 'package:vector_math/vector_math_64.dart' show Vector2;
apps/floor_planner/lib/parametric/dimension_geometry.dart:19:import 'wall.dart' show wallJoin;
apps/floor_planner/lib/parametric/dimension_geometry.dart:20:import 'wall_geometry.dart';
apps/floor_planner/lib/parametric/dimension_attach.dart:7:import 'package:jet_cad_2d/jet_cad_2d.dart';
apps/floor_planner/lib/parametric/dimension_attach.dart:8:import 'package:vector_math/vector_math_64.dart' show Vector2;
apps/floor_planner/lib/parametric/dimension_attach.dart:10:import 'dimension_geometry.dart';
apps/floor_planner/lib/parametric/dimension_attach.dart:11:import 'opening.dart' show OpeningParams;
apps/floor_planner/lib/parametric/dimension_attach.dart:12:import 'opening_geometry.dart' show wallsInDocument;
apps/floor_planner/lib/parametric/dimension_attach.dart:13:import 'wall.dart';

$ git diff "$BASE" -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants | wc -l
0

$ git diff "$BASE" --stat -- packages/jet_cad_2d/lib
 packages/jet_cad_2d/lib/src/document/style.dart    | 10 +++++
 .../jet_cad_2d/lib/src/index/query_filter.dart     | 49 +++++++++++++++++-----
 .../jet_cad_2d/lib/src/index/spatial_index.dart    | 33 ++++++++-------
 .../lib/src/parametric/parametric_system.dart      |  6 ++-
 4 files changed, 72 insertions(+), 26 deletions(-)

$ git diff "$BASE" --stat -- packages/jet_cad_2d/test
 .../jet_cad_2d/test/codec/json_codec_test.dart     |  60 ++++
 .../jet_cad_2d/test/index/query_filter_test.dart   | 103 ++++++-
 .../test/index/snap_centre_index_test.dart         |   5 +-
 packages/jet_cad_2d/test/index/snap_test.dart      | 342 ++++++++++++++++++++-
 .../test/parametric/attributes_test.dart           |  72 +++++
 .../test/parametric/support/clients.dart           |  64 +++-
 6 files changed, 638 insertions(+), 8 deletions(-)

$ git diff "$BASE" -- packages/jet_cad_2d_flutter | wc -l
0

$ git diff "$T1" --stat -- packages/ | wc -l
0

$ grep -n "EntityFlags.unpickable\|excludeUnpickable" packages/jet_cad_2d/lib -r
packages/jet_cad_2d/lib/src/parametric/parametric_system.dart:203:/// writes: ByLayer, flags 0. `EntityFlags.unpickable` exists (spec 11 D19)
packages/jet_cad_2d/lib/src/index/query_filter.dart:18:    this.excludeUnpickable = false,
packages/jet_cad_2d/lib/src/index/query_filter.dart:25:        excludeUnpickable = false;
packages/jet_cad_2d/lib/src/index/query_filter.dart:28:  /// entity carrying [EntityFlags.unpickable].
packages/jet_cad_2d/lib/src/index/query_filter.dart:32:        excludeUnpickable = false;
packages/jet_cad_2d/lib/src/index/query_filter.dart:35:  /// [EntityFlags.unpickable].
packages/jet_cad_2d/lib/src/index/query_filter.dart:39:        excludeUnpickable = true;
packages/jet_cad_2d/lib/src/index/query_filter.dart:42:  /// entities carrying [EntityFlags.unpickable] (spec 11 D19). A locked layer
packages/jet_cad_2d/lib/src/index/query_filter.dart:47:        excludeUnpickable = true;
packages/jet_cad_2d/lib/src/index/query_filter.dart:52:  /// Rejects an entity whose flags carry [EntityFlags.unpickable].
packages/jet_cad_2d/lib/src/index/query_filter.dart:53:  final bool excludeUnpickable;
packages/jet_cad_2d/lib/src/index/query_filter.dart:57:      !visibleOnly && !excludeLocked && !excludeUnpickable;
packages/jet_cad_2d/lib/src/index/query_filter.dart:96:    if (filter.excludeUnpickable &&
packages/jet_cad_2d/lib/src/index/query_filter.dart:97:        document.entities.flagsAt(slot) & EntityFlags.unpickable != 0) {
packages/jet_cad_2d/lib/src/index/spatial_index.dart:1448:  /// `EntityFlags.unpickable`. Not [QueryFilter.all]: snapping to geometry

$ grep -rn "EntityFlags.unpickable" apps/floor_planner/lib
apps/floor_planner/lib/parametric/dimension.dart:168:  /// `EntityFlags.unpickable` (D19); the TEXT is [kDimTextAttrs]. A zero
apps/floor_planner/lib/parametric/dimension.dart:204:      line(l.ext0, flags: EntityFlags.unpickable),
apps/floor_planner/lib/parametric/dimension.dart:205:      line(l.ext1, flags: EntityFlags.unpickable),

$ grep -rn "Tolerance.standard" apps/floor_planner/lib/parametric/dimension*.dart ; echo "exit $?"
exit 1

$ grep -rn "TrueColor" apps/floor_planner/lib/parametric/dimension*.dart ; echo "exit $?"
exit 1

$ grep -rnE "debugDimensionReadsPlaces|readsPlaces|readBox|kDimOffsetPaperMm|kHalfTolerance|kVerticalTolerance|kAttachTolerance|attachMatches|attachAt\b" apps/floor_planner/lib/parametric/dimension*.dart ; echo "exit $?"
exit 1

$ grep -rn "spike_dims\|SPIKE 11" apps packages ; echo "exit $?"
apps/floor_planner/test/support/dimension_fixture.dart:8:// `apps/floor_planner/test/spike_dims/support.dart`); the C1-C10 walls from
grep: apps/floor_planner/build/test_cache/build/99f5cb803d2032707ba73bec2a719151.cache.dill.track.dill: binary file matches
exit 0

$ grep -rn --exclude-dir=build "spike_dims\|SPIKE 11" apps packages ; echo "exit $?"
apps/floor_planner/test/support/dimension_fixture.dart:8:// `apps/floor_planner/test/spike_dims/support.dart`); the C1-C10 walls from
exit 0

$ grep -rnE "debugDimensionGenerates\s*(\+\+|\+=|=)" apps/floor_planner/lib
apps/floor_planner/lib/parametric/dimension.dart:109:int debugDimensionGenerates = 0;
apps/floor_planner/lib/parametric/dimension.dart:183:    debugDimensionGenerates++;

$ git diff "$BASE" --stat -- apps/floor_planner/test/wall_*_test.dart apps/floor_planner/test/opening_*_test.dart apps/floor_planner/test/room_*_test.dart apps/floor_planner/test/separator*_test.dart apps/floor_planner/test/support/wall_fixture.dart apps/floor_planner/test/support/opening_fixture.dart apps/floor_planner/test/support/room_fixture.dart apps/floor_planner/test/selection_panel_test.dart apps/floor_planner/test/page_panel_test.dart apps/floor_planner/test/box_test.dart apps/floor_planner/test/planner_box_test.dart apps/floor_planner/test/planner_grips_test.dart | wc -l
0

$ git diff "$BASE" --stat -- apps/floor_planner/test/planner_shell_test.dart apps/floor_planner/test/planner_draw_test.dart
 apps/floor_planner/test/planner_shell_test.dart | 49 ++++++++++++++++++++++++-
 1 file changed, 47 insertions(+), 2 deletions(-)

$ git diff "$BASE" --stat -- apps/floor_planner/test/startup_plan_test.dart
 apps/floor_planner/test/startup_plan_test.dart | 254 ++++++++++++++++++++++++-
 1 file changed, 246 insertions(+), 8 deletions(-)

$ git rev-parse --short HEAD
97fafbb

$ git rev-list --count "$BASE"..HEAD
37

$ git log --format=%B "$BASE"..HEAD | grep -c "^Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>$"
37

$ git log --format=%B "$BASE"..HEAD | grep -c "^Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv$"
37

$ git log --name-only --format= "$BASE"..HEAD | grep -c "analysis_options.yaml"
0
```

Read against each line's expected output:

- **The import grep:** no match, exit 1. Its positive control, re-run
  (`plan11/t17-posctl.log`):

  ```
  $ grep -rnE "^\s*(import|export)\s+.(package:flutter|dart:ui)" plan11/t17-posctl/x.dart ; echo "exit $?"
  1:import 'package:flutter/widgets.dart';
  exit 0
  ```

  The two pure files import only `dart:math`, `package:jet_cad_2d`,
  `package:vector_math` and app files. Read transitively (Ruling 11-2),
  at this tree: `wall.dart` → `opening_geometry.dart`,
  `room_inputs.dart`, `wall_geometry.dart`; `wall_geometry.dart` →
  `wall.dart`; `opening.dart` → `opening_geometry.dart`, `wall.dart`;
  `opening_geometry.dart` → `opening.dart`, `wall.dart`,
  `wall_geometry.dart`; `room_inputs.dart` → `dart:async`,
  `opening_geometry.dart`, `room_trace.dart`, `separator.dart`,
  `wall.dart`, `wall_geometry.dart`; `room_trace.dart` →
  `room_inputs.dart`; `separator.dart` → `room_inputs.dart`. None
  imports Flutter or `dart:ui`.
- `lib/jet_cad_2d.dart` exports `style.dart` (30), `query_filter.dart`
  (55) and `spatial_index.dart` (58) whole, so `EntityFlags.unpickable`
  and `QueryFilter.snapping()` are public (Task 16's read; the engine is
  unchanged since `015d95d`, the `T1` line above).
- Invariants 0; `packages/jet_cad_2d/lib` the four D19 files; its tests
  the six Ruling 11-1 names; `jet_cad_2d_flutter` 0; `packages/` since
  `T1` 0.
- `EntityFlags.unpickable`/`excludeUnpickable` in the engine: the
  `Generated` doc comment (`parametric_system.dart:203`), the field and
  the presets, the test in `acceptsEntity` (96-97), `snapInto`'s doc
  (1448). The declaration (`style.dart`, `static const int unpickable = 1
  << 1;`) does not match the pattern. In the app: `dimension.dart`'s
  extension lines (204-205) and their doc (168).
- `Tolerance.standard`, `TrueColor`, the spike's dropped names: no match,
  exit 1.
- **`spike_dims|SPIKE 11`, as the plan wrote it:** two matches, exit 0:
  the provenance comment at
  `apps/floor_planner/test/support/dimension_fixture.dart:8` and a binary
  match in the git-ignored `apps/floor_planner/build/test_cache/`. **As
  amended** (Task 16's ruling; the plan's Task 16 amendment),
  `--exclude-dir=build`: **one hit, the provenance comment, the one
  expected hit**, exit 0.
- `debugDimensionGenerates`: the declaration (109) and one increment
  (183).
- 07's, 08's and 10's test files: 0.
- **`planner_shell_test.dart`** (+47 −2) is the one file that differs
  from `9774a55` by exactly Ruling 11-14's ruled edits: the two
  `liveCount` lines (at `9774a55`'s :307 and :391) subtract `3 * 6`,
  each with a comment deriving it from decision 3's cascade; the three
  dimensions on E1 asserted before the delete, gone after it and back with
  six children each after the undo; the `dimensionsOn` helper and its
  import. `planner_draw_test.dart` is unchanged.
- **`startup_plan_test.dart`** (+246 −8, outside the plan's grep)
  carries Task 14's planned `SP1`, `SP5`, `SP8` and `SP9` edits **and**
  Ruling 11-14's two ruled edits (:80 pins the walls' outer rectangle and
  `doc.extents` with its slash and overshoot arithmetic; :113 compares the
  page's centre with the walls' centre (19,000, 12,500)). So it does not
  differ from the base by Ruling 11-14's edits alone (the Task 16 review's
  Minor 4; Task 16's paste of this section said "Ruling 11-14's other two
  edits" only).
- **N = 37** commits `9774a55..HEAD`: six before Task 1 (the spike note,
  the four spec revisions and the plan), 29 for Tasks 1–16 and their fix
  rounds (`59aa198..75f04d7`), and Task 17's two. **37 and 37 trailers**,
  0 `analysis_options.yaml`.

## The tasks' extras, copied from the ledger (not re-fired)

The plan's Task 16 rule: the tasks' extras (`X1-` to `X15-`, and every
implementer's and reviewer's mutant the ledger names) "already fired and
pasted are copied, not re-fired". Each row is the ledger's record, with the
task entry it comes from; "red" means killed where the ledger says. Where a
survivor was fixed, the row names the fixing commit and the killer after it.
None is re-counted in the 75.

The last rows come after Task 16: the Task 16 reviewer's own five (the
ledger's Task 16 review entry) and the final whole-branch review's seven
(`rvF-`, as that review records them). The final fix wave fired the two
`rvF-` survivors it answers, `rvF-mainNoIndex` and `rvF-textAngleNoZero`,
against its new clauses (`SL2`, `DO6`): both red, each restored (`cp`
back, `diff` exit 0).

| mutant | task (ledger) | result as recorded |
|---|---|---|
| X1-passthrough, X1-bit, X1-underVisible | 1 (99ab3ac) | red (QF1 169, 94, 170) |
| X1-lockedSnap | 1 (99ab3ac) | red (QF1 153; the presets test also pins it, Minor 3) |
| R2-isect, R4-flagMask, R5-lockedGate, R7-pickDropFlag | 1 review | red |
| R1b-centreDropFlag | 1 review: survived → fix 015d95d | red (snap_test 750) |
| R3-bandDropFlag (root, descend) | 1 review: survived → fix 015d95d | red (snap_test 851, 864) |
| R6-dragSnap | 1 review: survived → carried to 15 | red at 15 (TL9 524; site `packages/jet_cad_2d/lib/src/index/drag_snap.dart:72`); re-fired by rv15 |
| X2-worldFree, X2-degenerate, X2-degenerate-b | 2 (a21a124) | red (AP1/AP2) |
| R-mapForward, R-startWorld, R-capsSwapped, R-flagOnly | 2 review | red |
| R-reversePoints | 2 review: survived → fix e7e9622 | red (AP2 450:13) |
| R-noSimplify | 2 review | **equivalent** (ruled, Task 2 Minor 1): `isSimpleCcw` counts proper crossings; duplicates and collinear spikes never change it |
| X3-degenerateZero, X3-kHigh, X3-exactMin | 3 (b67ef83) | red (AM3) |
| R-worldAxis, R-sideRev, R-sigmaLocal, R-handleHigh | 3 review | red |
| R-bandWide | 3 review: survived → carried to 4 | red (AM3 208) |
| R-noR8 | 3 review: survived → carried to 6 | red (DL1 ×6) |
| X4-noLocal, X4-degenerateLine, X4-thickestStored | 4 (31ed3b8) | red |
| R4-noSort, R4-localOnly, R4-rightJust | 4 review | red |
| R4-leftJust | 4 review: survived → fix 402e42f | red (dimension_attach_test 523:13) |
| R4-filterAll | 4 review: survived → carried to 16 | survived to Task 16's probe; the product defect it exposed fixed in `49de0e8`, and **red** at `AM6b` (fired here, "Fix round") |
| X16-hostVisible | 16 fix round (`49de0e8`) | **red** at `AM6b` (fired here, "Fix round") |
| X5-splitFirst, X5-tolWide, X5-noAbs | 5 (ac635a2) | red (DF1/DF2; X5-tolWide DF2 169) |
| R5-mPad, R5-angular, R5-reduceOnce, R5-noAbsHalf, R5-tolNarrow | 5 review | red |
| R5-quantaTol | 5 review: survived → fix b6f00a5 | red (DF2 183) |
| X6-dedup, X6-worldStore, X6-groupAngle, X6-gapNoMin | 6 (ed28d61) | red |
| X6-finiteGuard | 6; re-sited in 7 (f32ac75, 94be5e4) | red at the new site (DL1/DO) |
| rv6-negzeroZeroOnly, rv6-sigma, rv6-heightNoPage, rv6-offsetPaper, rv6-axisWorld | 6 review | red |
| rv6-tieBetween, rv6-onHiStrict | 6 review: survived → carried to 7 | red (DL2b) |
| rv6-flagsDropped, rv6-textAttrs, rv6-nonFiniteOffset, rv6-scaleOffset | 6 review | owned by later tests (DO1, DD2, DR5): red there |
| rv6-alignedH1 | 6 review | **accepted** (rounding-sized; the ledger's word "accepted") |
| X7-degenerateError, X7-brokenWarn, X7-danglingTwice, X7-noDefaultPage | 7 (f32ac75) | red |
| t7-degenerateStrict, t7-nonWallDropped, t7-brokenFirstOnly | 7 (f32ac75) | red |
| M-11broken-k, -point, -offset (single forms) | 7 | red (the combined form is the spec's; re-fired here) |
| rv7-degenerateAligned, rv7-degenerateNoTol, rv7-diagIdentity, rv7-offsetNaNOnly, rv7-pointXOnly, rv7-halfExact | 7 review | red |
| rv7-pageKeyScaleOnly, rv7-pageKeyUnitOnly, rv7-kHighOnly | 7 review: survived → fix 94be5e4 | red (DO2, DD2) |
| t7f-lengthGuard | 7 fix round | red |
| rv7r-diagRealOffset, rv7r-lengthReasonAlways | 7 re-review | red |
| rv7r-guardValueOnly, rv7r-degenerateWithBroken | 7 re-review: survived → carried to 8 | red (DD4) |
| t8-noMaxBound, X8-coreNoRefs, X8-reachAll | 8 (5fff87c) | red |
| X8-noOracle | 8 | control: red (DZ1 with the oracle; drift() alone does not see it) |
| rv8-viewHalfNbrs, rv8-noBeforeNbrs, rv8-noAfterNbrs, rv8-noPageSeeds, rv8-M-11c-layout | 8 review | red |
| rv8-refNoJoin, rv8-refNoLeft | 8 review | red (20/20 and 19/20 seeds) |
| rv8-noTriggered | 8 review | **equivalent** (the reviewer's reason: dimensions do not read places) |
| X9-chained, X9-memoCommit, X9-noLengthRule, X9-predict, X9-tieVertical | 9 (dced8e9) | red (TL1/TL2/TL4) |
| X9-noSharedRule | 9; moved to the legal-zoom route in c8d5dd6 | red (TL4 630) |
| M-11snaponly-third (a second form) | 9 | red (TL6) |
| rv9-offsetSwapped | 9 review | red |
| rv9-alignedDecide, rv9-zeroKindExact | 9 review: survived → fix c8d5dd6 | red (TL1 341, TL2 422) |
| rv9-shiftNotFromPointerDown (M-3) | 9 review | **accepted as nearly equivalent** (ruled, Task 9 M-3): Shift taken from onPointerDown is unpinned, but hover and onKey set Shift first |
| rv9-otherIsSelf | 9 review | **equivalent** (the reviewer's) |
| X10-memoForever, X10-noMemo, X10-ringsF3off, X10-previewPerPaint, X10-noticeNoClear | 10 (a9c7f32, 45f6bdf) | red (TL5/TL8) |
| t10-previewPlacedPoints, t10-keyIgnoresShift | 10 | red |
| rv10-statusRoomOnly | 10 review | red |
| rv10-previewDefaultPage, rv10-noRefreshOnChange, rv10-keyIgnoresGeneration, rv10-nullLayoutKeeps, rv10-attachNoBump | 10 review: survived → fix 23e8bc5 | red (TL5) |
| t10f-noWallMemo, t10f-offCanvasNoRefresh | 10 fix round | red |
| rv10r-offCanvasGuard, rv10r-wallPointsNotCleared | 10 re-review | red |
| rv10r-undoNotHeard | 10 re-review: survived → carried to 11 | red (TL8, 24c1a6f) |
| rv10r-clickPassesMap | 10 re-review | **equivalent** (the reviewer's) |
| X11-noNull, X11-fixedWorld, X11-snapAlwaysOn | 11 (24c1a6f) | red (GE) |
| t11-dropKindAligned, t11-dropOtherIsDrop, t11-noDistance, t11-brokenGrips | 11 | red |
| t11-noEqualOther, rv11-noOffsetGuard | 11, 11 review | **equivalent** (confirmed by the reviewer: the distance check refuses the same point) |
| rv11-previewOldPoints, rv11-offsetAligned, rv11-offsetWorld, rv11-degTolExact | 11 review | red |
| rv11-pageDefault, rv11-decideWorld, rv11-thickZero | 11 review: survived → fix 7d248b2 | red (GE5, GE3) |
| t11f-previewThickZero, t11f-noPreviewMemo, t11f-memoKeptOnChange, t11f-dropReadsMemo | 11 fix round | red |
| rv11r-dropNoClear, rv11r-dragKeepsMemo | 11 re-review | red |
| rv11r-keyNoGroup | 11 re-review: survived → carried to 12 | red (GE5 610) |
| rv11r-keyNoOrdinal | 11 re-review | **equivalent** (the reviewer's) |
| rv11r-keyNoDoc, rv11r-dropNoCancel | 11 re-review | survive; the reviewer: unreachable/unobservable in the shell (select_tool swallows keys mid-drag; the pointer is captured). No ruling recorded beyond that: listed here as the ledger has them |
| X12-stringTest, X12-sameKind, X12-staleValue, X12-deadTarget, X12-noCatch | 12 (a21a55a) | red (PN) |
| rv12-zeroSign, rv12-memoAnyDim, rv12-sideSwap, rv12-atan2c, rv12-noGeomCheck, rv12-noStateCatch | 12 review | red |
| rv12-strictThreshold, rv12-noNormalise | 12 review | **equivalent / acceptable** (the reviewer's words) |
| M-11panelrw form b | 12 review: survived → carried to 13 | red (PN5 431); re-fired here as `M-11panelrw-b` |
| X13-heightNoScale, t13-offsetForNoScale | 13 (64777ea) | red (DR5) |
| t13 post-rounding normalisation (carried) | 13 | red (PN3 329) |
| rv13-verticalWorldOnly, rv13-fixedTranslationOnly, rv13-axisInverse, rv13-normaliseBeforeRound, rv13-scaleSquared, rv13-textAngleNoGroup | 13 review | red |
| X14-diagonalOnE2, X14-offsetsSpike, X14-beforeRooms | 14 (2351d97) | red (SP5 574 for X14-beforeRooms) |
| rv14-pageLast, rv14-lineNotPickable, rv14-orphan, rv14-hallOnE4, rv14-diagNegZero | 14 review | red |
| X15-bandIgnoresFlag | 15 (5ddd96f) | red (SL1 split clause 2) |
| rv15-textbelow, rv15-slash, rv15-textGap1.2, rv15-textH2.3, rv15-extpage, rv15-extGap1.3 | 15 review | red (RR1); textH 2.3 and textGap 1.2 re-fired here after the RR1 edit |
| rv15 fixedworld / attachedmoves | 15 review | red (SL1 split clauses 3 and 5) |
| rv15-orphanPolicy | 15 review | red (SL1 split clause 6) |
| rv16-q1all, rv16-q2all, rv16-hostIsOpening, rv16-hostParent, rv16-crossCallCache | 16 review | red at `AM6b` (`dimension_attach_test.dart`): q1all at 900 on P1; q2all at 934 on P3; hostIsOpening and hostParent at 934 on P2; crossCallCache at 934 on the control |
| rvF-gripsNoKCheck | final review | red (GE4 `dimension_grips_test.dart` 519:7, both placements) |
| rvF-07noLocalFallback | final review | red (AP2 354:25 via 399:5) |
| rvF-previewFirstCandidate | final review | **equivalent** (the reviewer's "equivalent in effect": every candidate lies within 1e-5 mm of q, so the previewed point is the same to rounding) |
| rvF-commitNoGenBump | final review | **equivalent** (the reviewer's: a dimension add changes no wall point and no T, and the `DocChange` bumps the generation anyway) |
| rvF-mainNoIndex | final review: survived (`+486`) → killed in the final fix wave (`fd762cc`) | red (SL2 `dimension_shell_test.dart` line 519: offset 900, not 1150) |
| rvF-textAngleNoZero | final review: survived (`+486`) → killed in the final fix wave (`fd762cc`) | red (DO6 `dimension_object_test.dart` 350:7 at all three unturned placements) |
| rvF-paletteNotDrawing | final review | survives (`+55`, planner_draw, tool, shell): an inherited gap, 07's, 08's and 10's palette entries alike (`A12` checks `tool-line` only); a post-11 follow-up, not fixed in 11 |

**The extras' tally** (recounted from the table above, one name per
mutant: a multi-site mutant written with its sites in parentheses,
`R3-bandDropFlag (root, descend)`, counts once; `rv15 fixedworld /
attachedmoves` counts two): **210 names: 193 killed, 11 equivalent** (the
nine listed under "Equivalent, accepted (cost) and N/A", plus
`rvF-previewFirstCandidate` and `rvF-commitNoGenBump`), **1 accepted**
(`rv6-alignedH1`), **1 accepted as nearly equivalent** (M-3), **2
surviving as unreachable in the shell** (`rv11r-keyNoDoc`,
`rv11r-dropNoCancel`), **1 surviving as an inherited gap**
(`rvF-paletteNotDrawing`, a post-11 follow-up) and **1 control**
(`X8-noOracle`). Before the final review the table held 198 names (184
killed), not the 199 (185 killed) the results note first gave: that count
took `R3-bandDropFlag`'s two sites as two names.

## The entries

### The spec's 75 at `5ddd96f` (81 fires)

#### M-11pickflag — `picking()` ignores the not-pickable flag (spec M-11pickflag; killers QF1, SL1)

- **file:** `packages/jet_cad_2d/lib/src/index/query_filter.dart`; backup `t16-M-11pickflag.query_filter.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  39c39
  <         excludeUnpickable = true;
  ---
  >         excludeUnpickable = false;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/index/query_filter_test.dart --plain-name 'QF1 ')` (exit 1; log `t16-M-11pickflag-run1.log`)

  ```
  00:00 +0 -1: QF1 an entity carrying EntityFlags.unpickable passes all() and rendering() and fails picking() and snapping(); an invisible one still fails every preset but all(); a filter asking only for the flag is no passthrough and rejects it [E]
    Expected: {0: true, 1: false, 2: false, 3: false}
      Actual: {0: true, 1: false, 2: true, 3: false}
       Which: at location ['2'] is <true> instead of <false>
    test/index/query_filter_test.dart 144:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_shell_test.dart --plain-name 'SL1 ')` (exit 1; log `t16-M-11pickflag-run2.log`)

  ```
  Expected: [SelectionKey:SelectionKey( 1E)]
    Actual: Set:[SelectionKey:SelectionKey( 286)]
     Which: at location [0] is SelectionKey:<SelectionKey( 286)> instead of
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_shell_test.dart:256:7)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_shell_test.dart line 256
  00:04 +0 -1: SL1 through the select tool on the sample plan: a click on a dimension line selects it; a click on E4's face under the Hall's extension line selects E4; a window band around the Hall's line, slashes and text selects it; dimensions move and turn by their fixed ends only; deleting E1 deletes three dimensions in one st [cut; the full line is in the log]
    The test description was: SL1 through the select tool on the sample plan: a click on a dimension line selects it; a click on E4's face under the Hall's extension line selects E4; a window band around the Hall's line, slashes and text selects it; dimensions move and turn by their fixed ends only; deleting E1 deletes three dimen [cut; the full line is in the log]
  00:04 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/index/query_filter.dart`; `diff` exit 0; `git diff --quiet -- packages/jet_cad_2d/lib/src/index/query_filter.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:20:08Z.

#### M-11snapflag — snapping ignores the flag (`snapInto`'s default back to `rendering()`) (spec M-11snapflag; killers QF2, TL9)

- **file:** `packages/jet_cad_2d/lib/src/index/spatial_index.dart`; backup `t16-M-11snapflag.spatial_index.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  1472c1472
  <       {QueryFilter filter = const QueryFilter.snapping()}) {
  ---
  >       {QueryFilter filter = const QueryFilter.rendering()}) {
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/index/snap_test.dart --plain-name 'QF2 ')` (exit 1; log `t16-M-11snapflag-run1.log`)

  ```
  00:00 +0 -1: QF2 snapInto by default gives no endpoint, midpoint or intersection snap on a not-pickable LINE, nor a centre snap on a not-pickable CIRCLE; a LINE or CIRCLE beside it still snaps; pickInto with picking() skips it for the LINE behind it; a band with picking() leaves it out, at the root and in an instance [E]
    Expected: false
      Actual: <true>
    test/index/snap_test.dart 664:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_shell_test.dart --plain-name 'TL9 ')` (exit 1; log `t16-M-11snapflag-run2.log`)

  ```
  Expected: null
    Actual: SnapKind:<SnapKind.endpoint>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_shell_test.dart:524:5)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_shell_test.dart line 524
  00:03 +0 -1: TL9 at 0.3 px/mm with the grid snap off, a hover 5 mm off the Hall's extension line's far end gets no object snap and resolves to the raw point [E]
    The test description was: TL9 at 0.3 px/mm with the grid snap off, a hover 5 mm off the Hall's extension line's far end gets no object snap and resolves to the raw point
  00:03 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/index/spatial_index.dart`; `diff` exit 0; `git diff --quiet -- packages/jet_cad_2d/lib/src/index/spatial_index.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:20:17Z.

#### M-11flagdraws — the flag also stops rendering (`rendering()` excludes it) (spec M-11flagdraws; killers QF1, RR1)

- **file:** `packages/jet_cad_2d/lib/src/index/query_filter.dart`; backup `t16-M-11flagdraws.query_filter.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  32c32
  <         excludeUnpickable = false;
  ---
  >         excludeUnpickable = true;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/index/query_filter_test.dart --plain-name 'QF1 ')` (exit 1; log `t16-M-11flagdraws-run1.log`)

  ```
  00:00 +0 -1: QF1 an entity carrying EntityFlags.unpickable passes all() and rendering() and fails picking() and snapping(); an invisible one still fails every preset but all(); a filter asking only for the flag is no passthrough and rejects it [E]
    Expected: {0: true, 1: false, 2: true, 3: false}
      Actual: {0: true, 1: false, 2: false, 3: false}
       Which: at location ['2'] is <false> instead of <true>
    test/index/query_filter_test.dart 140:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_paint_test.dart --plain-name 'RR1 ')` (exit 1; log `t16-M-11flagdraws-run2.log`)

  ```
  Expected: a numeric value within <13.333333333333334> of <75.0>
    Actual: <485.00000000000045>
     Which:  differs by <410.00000000000045>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_paint_test.dart:292:9)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_paint_test.dart line 292
  00:02 +0 -1: RR1 the dimension text is the same world height at 0.15 and 0.3 px/mm and doubles at 1:100; a slash inks; the extension line inks from its gap [E]
    The test description was: RR1 the dimension text is the same world height at 0.15 and 0.3 px/mm and doubles at 1:100; a slash inks; the extension line inks from its gap
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/index/query_filter.dart`; `diff` exit 0; `git diff --quiet -- packages/jet_cad_2d/lib/src/index/query_filter.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:20:26Z.

#### M-11nbrs — the neighbours ignored (`drawnCapsOf(w, const [])`) (spec M-11nbrs; killers AP1, DN1)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11nbrs.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  66c66
  <   final caps = drawnCapsOf(w, others)!;
  ---
  >   final caps = drawnCapsOf(w, const [])!;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP1 ')` (exit 1; log `t16-M-11nbrs-run1.log`)

  ```
  00:00 +0 -1: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <100.0>
       Which: is not a value less than <0.000001>
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -2: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -3: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -4: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -5: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_follow_test.dart --plain-name 'DN1 ')` (exit 1; log `t16-M-11nbrs-run2.log`)

  ```
  00:00 +0 -1: DN1 a neighbour's edit moves a referenced wall's corner and rebuilds the dimension once, at origin [E]
    Expected: '3900'
      Actual: '4000'
       Which: is different.
              Expected: 3900
                Actual: 4000
    test/dimension_follow_test.dart 80:7                main.<fn>
  00:00 +0 -2: DN1 a neighbour's edit moves a referenced wall's corner and rebuilds the dimension once, at corpus far origin, 23 deg, own groups [E]
    test/dimension_follow_test.dart 80:7                main.<fn>
  00:00 +0 -3: DN1 a neighbour's edit moves a referenced wall's corner and rebuilds the dimension once, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_follow_test.dart 80:7                main.<fn>
  00:00 +0 -3: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:20:35Z.

#### M-11swap — the `k = 1` swap of outgoing sides dropped (spec M-11swap; killers AP1)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11swap.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  68c68
  <   final outgoingLeft = (k == 0) == (side == WallSide.left);
  ---
  >   final outgoingLeft = side == WallSide.left;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP1 ')` (exit 1; log `t16-M-11swap-run1.log`)

  ```
  00:00 +0 -1: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <200.0>
       Which: is not a value less than <0.000001>
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -2: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -3: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -4: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -5: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:20:39Z.

#### M-11swapjust — left and right swapped for right-justified walls (spec M-11swapjust; killers AP1)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11swapjust.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  68c68
  <   final outgoingLeft = (k == 0) == (side == WallSide.left);
  ---
  >   final outgoingLeft = (k == 0) == ((side == WallSide.left) != (w.j.name == 'right'));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP1 ')` (exit 1; log `t16-M-11swapjust-run1.log`)

  ```
  00:00 +0 -1: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <233.23807579381202>
       Which: is not a value less than <0.000001>
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -2: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -3: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -4: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -5: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:20:44Z.

#### M-11fallback — no fallback at all in `drawnCapsOf`: both steps return the joined caps (S-2) (spec M-11fallback; killers AP1)

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t16-M-11fallback.wall_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  534a535,540
  >   if (w.degenerate) return null;
  >   return (
  >     endCap: cap(End(w, 1), classify(w, 1, others)).points,
  >     startCap: cap(End(w, 0), classify(w, 0, others)).points,
  >     fellBack: false,
  >   );
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP1 ')` (exit 1; log `t16-M-11fallback-run1.log`)

  ```
  00:00 +0 -1: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <100.0>
       Which: is not a value less than <0.000001>
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -2: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -3: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -4: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -5: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/wall_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:20:48Z.

#### M-11centremid — centre = the cap's midpoint (spec M-11centremid; killers AP1)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11centremid.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  65c65
  <   if (side == WallSide.centre || w.degenerate) return w.endpoint(k);
  ---
  >   if (w.degenerate) return w.endpoint(k);
  67a68
  >   if (side == WallSide.centre) return (c.first + c.last) * 0.5;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP1 ')` (exit 1; log `t16-M-11centremid-run1.log`)

  ```
  00:00 +0 -1: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <60.0>
       Which: is not a value less than <0.000001>
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -2: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -3: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -4: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -5: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:20:52Z.

#### M-11localring — the attach point ignores the local-ring fallback (`capsOf` alone): step 2 removed (spec M-11localring; killers AP2)

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t16-M-11localring.wall_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  542c542
  <   if (isSimpleCcw(local)) return caps;
  ---
  >   return caps;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP2 ')` (exit 1; log `t16-M-11localring-run1.log`)

  ```
  00:00 +0 -1: AP2 under 07's local-ring fallback the face points are the stored free rectangle's corners, at any similarity; drawnCapsOf falls back exactly when localOutlineOf does [E]
    Expected: a value less than <0.00001>
      Actual: <5730.741669592764>
       Which: is not a value less than <0.00001>
    test/dimension_attach_points_test.dart 383:9        main.<fn>.expectLocalFallback
    test/dimension_attach_points_test.dart 399:5        main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/wall_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:20:57Z.

#### M-11vertex — a face point taken from its cap's second point, not its first or last (spec M-11vertex; killers AP1, AP2, AP3)

Killer list per the Task 2 ruling (2): AP1 (+AP2); AP3 dropped (every cap point is a stored vertex). AP3 fired for the record.

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11vertex.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  69c69
  <   return outgoingLeft ? c.first : c.last;
  ---
  >   return outgoingLeft ? c[1] : c.last;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP1 ')` (exit 1; log `t16-M-11vertex-run1.log`)

  ```
  00:00 +0 -1: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <200.0>
       Which: is not a value less than <0.000001>
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -2: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -3: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -4: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -5: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP2 ')` (exit 1; log `t16-M-11vertex-run2.log`)

  ```
  00:00 +0 -1: AP2 under 07's local-ring fallback the face points are the stored free rectangle's corners, at any similarity; drawnCapsOf falls back exactly when localOutlineOf does [E]
    Expected: a value less than <0.00001>
      Actual: <200.00000000009047>
       Which: is not a value less than <0.00001>
    test/dimension_attach_points_test.dart 383:9        main.<fn>.expectLocalFallback
    test/dimension_attach_points_test.dart 399:5        main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP3 ')` (exit 0; log `t16-M-11vertex-run3.log`)

  ```
  00:00 +6: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 3 commands red); green: AP3. Fired at `5ddd96f`, 2026-09-29T11:21:09Z.

#### M-11d — an attached end resolved by its wall handle and side only, `k` ignored (always the start) (spec M-11d; killers AP1, SP8)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11d.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  64a65
  >   k = 0; // M-11d
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP1 ')` (exit 1; log `t16-M-11d-run1.log`)

  ```
  00:00 +0 -1: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <4000.0>
       Which: is not a value less than <0.000001>
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -2: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -3: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -4: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -5: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/startup_plan_test.dart --plain-name 'SP8 ')` (exit 1; log `t16-M-11d-run2.log`)

  ```
  00:00 +0 -1: SP8 the five dimensions read D17's values at 1:50 m with text 125 high, reference the walls listed, and a click on each line selects it [E]
    Expected: ['14.00', '9.00', '4.69', '4.38', '3.58']
      Actual: ['0.00', '0.00', '4.69', '4.38', '10.09']
       Which: at location [0] is '0.00' instead of '14.00'
    test/startup_plan_test.dart 616:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:21:18Z.

#### M-11d2 — `side` ignored (always the centreline end) (spec M-11d2; killers AP1, SP8)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11d2.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  64a65
  >   side = WallSide.centre; // M-11d2
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP1 ')` (exit 1; log `t16-M-11d2-run1.log`)

  ```
  00:00 +0 -1: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <100.0>
       Which: is not a value less than <0.000001>
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -2: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -3: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -4: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -5: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/startup_plan_test.dart --plain-name 'SP8 ')` (exit 1; log `t16-M-11d2-run2.log`)

  ```
  00:00 +0 -1: SP8 the five dimensions read D17's values at 1:50 m with text 125 high, reference the walls listed, and a click on each line selects it [E]
    Expected: ['14.00', '9.00', '4.69', '4.38', '3.58']
      Actual: ['13.75', '8.75', '4.88', '4.50', '3.73']
       Which: at location [0] is '13.75' instead of '14.00'
    test/startup_plan_test.dart 616:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:21:28Z.

#### M-11nearest — the nearest candidate instead of decision 19's rule, ties to the lowest handle (spec M-11nearest; killers AM1, AM3)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16-M-11nearest.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  237a238,251
  >   {
  >     AttachedEnd? n;
  >     var nd = double.infinity;
  >     for (final e in candidates) {
  >       final ws = wallsInDocument(doc, e.wall)!;
  >       final dd = (wallEndPoint(ws.host, ws.walls, e.k, e.side) - at).length;
  >       if (dd < nd || (dd == nd && _before(e, n!))) {
  >         n = e;
  >         nd = dd;
  >       }
  >     }
  >     return n;
  >   }
  >   // ignore: dead_code
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM1 ')` (exit 1; log `t16-M-11nearest-run1.log`)

  ```
  00:00 +0 -1: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at origin [E]
    Expected: AttachedEnd:<1E/1/left>
      Actual: AttachedEnd:<12/0/left>
    test/dimension_attach_test.dart 358:13              main.<fn>
  00:00 +0 -2: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 358:13              main.<fn>
  00:00 +0 -3: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_test.dart 358:13              main.<fn>
  00:00 +0 -3: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM3 ')` (exit 1; log `t16-M-11nearest-run2.log`)

  ```
  00:00 +0 -1: AM3 a shared corner is stored on the wall the committed kind runs along, then on the lowest handle, then face before centre, k, left before right, at origin [E]
    Expected: AttachedEnd:<16/1/left>
      Actual: AttachedEnd:<12/0/left>
    test/dimension_attach_test.dart 151:9               main.<fn>
  00:00 +0 -2: AM3 a shared corner is stored on the wall the committed kind runs along, then on the lowest handle, then face before centre, k, left before right, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 151:9               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:21:37Z.

#### M-11parallel — decision 19's parallel step skipped (the lowest handle first) (spec M-11parallel; killers AM3)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16-M-11parallel.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  247d246
  <     if (!(sigma[e.wall]! <= least + dimAttach.angular)) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM3 ')` (exit 1; log `t16-M-11parallel-run1.log`)

  ```
  00:00 +0 -1: AM3 a shared corner is stored on the wall the committed kind runs along, then on the lowest handle, then face before centre, k, left before right, at origin [E]
    Expected: AttachedEnd:<16/1/left>
      Actual: AttachedEnd:<12/0/left>
    test/dimension_attach_test.dart 151:9               main.<fn>
  00:00 +0 -2: AM3 a shared corner is stored on the wall the committed kind runs along, then on the lowest handle, then face before centre, k, left before right, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 151:9               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:21:41Z.

#### M-11lineardir — a linear kind's parallel measure uses `P1 − P0` instead of its axis (spec M-11lineardir; killers AM3)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16-M-11lineardir.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  238c238
  <   final u = measuringDirection(kind, at, other, m);
  ---
  >   final u = (other - at).normalized();
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM3 ')` (exit 1; log `t16-M-11lineardir-run1.log`)

  ```
  00:00 +0 -1: AM3 a shared corner is stored on the wall the committed kind runs along, then on the lowest handle, then face before centre, k, left before right, at origin [E]
    Expected: AttachedEnd:<16/1/right>
      Actual: AttachedEnd:<12/0/right>
    test/dimension_attach_test.dart 183:9               main.<fn>
  00:00 +0 -2: AM3 a shared corner is stored on the wall the committed kind runs along, then on the lowest handle, then face before centre, k, left before right, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 183:9               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:21:45Z.

#### M-11centrefirst — centre before face (spec M-11centrefirst; killers AM3)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16-M-11centrefirst.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  277c277
  < int _centreRank(WallSide side) => side == WallSide.centre ? 1 : 0;
  ---
  > int _centreRank(WallSide side) => side == WallSide.centre ? 0 : 1;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM3 ')` (exit 1; log `t16-M-11centrefirst-run1.log`)

  ```
  00:00 +0 -1: AM3 a shared corner is stored on the wall the committed kind runs along, then on the lowest handle, then face before centre, k, left before right, at origin [E]
    Expected: AttachedEnd:<12/0/right>
      Actual: AttachedEnd:<12/0/centre>
    test/dimension_attach_test.dart 256:9               main.<fn>
  00:00 +0 -2: AM3 a shared corner is stored on the wall the committed kind runs along, then on the lowest handle, then face before centre, k, left before right, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 256:9               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:21:48Z.

#### M-11attachtol — attach tolerance 1e-9 (spec M-11attachtol; killers AM1)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11attachtol.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  35c35
  < const Tolerance dimAttach = Tolerance(linear: 1e-5, angular: 1e-9);
  ---
  > const Tolerance dimAttach = Tolerance(linear: 1e-9, angular: 1e-9);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM1 ')` (exit 1; log `t16-M-11attachtol-run1.log`)

  ```
  00:00 +1 -1: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at corpus far origin, 23 deg, own groups [E]
    Expected: [AttachedEnd:12/0/right, AttachedEnd:1E/1/right]
      Actual: [AttachedEnd:12/0/right]
       Which: at location [1] is [AttachedEnd:12/0/right] which shorter than expected
    test/dimension_attach_test.dart 353:11              main.<fn>
  00:00 +1 -2: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_test.dart 352:11              main.<fn>
  00:00 +1 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:21:54Z.

#### M-11snapoff — ends attach with F3 off (spec M-11snapoff; killers AM4, TL6)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16-M-11snapoff.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  102d101
  <   if (!objectSnap) return const [];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM4 ')` (exit 1; log `t16-M-11snapoff-run1.log`)

  ```
  00:00 +0 -1: AM4 decision 23: a grid point on the sample's outer corner attaches with F3 on and stays fixed with F3 off, at origin [E]
    Expected: empty
      Actual: [AttachedEnd:12/0/right, AttachedEnd:1E/1/right]
    test/dimension_attach_test.dart 649:7               main.<fn>
  00:00 +0 -2: AM4 decision 23: a grid point on the sample's outer corner attaches with F3 on and stays fixed with F3 off, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 649:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_tool_test.dart --plain-name 'TL6 ')` (exit 1; log `t16-M-11snapoff-run2.log`)

  ```
  00:00 +0 -1: TL6 decision 23 through the tool: with F3 on a grid point on a corner attaches and a flush door's jamb snap attaches the stem's corner; with F3 off every end is fixed, at origin [E]
    Expected: FixedEnd:<(12000.0, 8000.0)>
      Actual: AttachedEnd:<12/0/right>
    test/dimension_tool_test.dart 788:9                 main.<fn>
  00:00 +0 -2: TL6 decision 23 through the tool: with F3 on a grid point on a corner attaches and a flush door's jamb snap attaches the stem's corner; with F3 off every end is fixed, at corpus far origin, 23 deg, own groups [E]
    test/dimension_tool_test.dart 788:9                 main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:22:05Z.

#### M-11prefilter — D10's line test omits the centreline (face lines only) (spec M-11prefilter; killers AM1, AM6, TL8)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16-M-11prefilter.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  180c180
  <   return (o - lOff).abs() <= tol || o.abs() <= tol || (o - rOff).abs() <= tol;
  ---
  >   return (o - lOff).abs() <= tol || (o - rOff).abs() <= tol;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM1 ')` (exit 1; log `t16-M-11prefilter-run1.log`)

  ```
  00:00 +0 -1: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at origin [E]
    Expected: contains AttachedEnd:<12/0/centre>
      Actual: []
       Which: does not contain AttachedEnd:<12/0/centre>
    test/dimension_attach_test.dart 352:11              main.<fn>
  00:00 +0 -2: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 352:11              main.<fn>
  00:00 +0 -3: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_test.dart 352:11              main.<fn>
  00:00 +0 -3: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM6 ')` (exit 1; log `t16-M-11prefilter-run2.log`)

  ```
  00:00 +0 -1: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at origin [E]
    Expected: contains AttachedEnd:<16/0/centre>
      Actual: []
       Which: does not contain AttachedEnd:<16/0/centre>
    test/dimension_attach_test.dart 747:11              main.<fn>
  00:00 +0 -2: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at corpus far origin, 23 deg [E]
    test/dimension_attach_test.dart 747:11              main.<fn>
  00:00 +0 -3: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 747:11              main.<fn>
  00:00 +0 -4: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_test.dart 747:11              main.<fn>
  00:00 +0 -5: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_test.dart 747:11              main.<fn>
  00:00 +0 -6: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_test.dart 747:11              main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_tool_test.dart --plain-name 'TL8 ')` (exit 1; log `t16-M-11prefilter-run3.log`)

  ```
  00:01 +0 -1: TL8 hovering among 600 walls searches once per distinct resolved point, passes no line test between a centreline and its faces or past a door, passes one on a face line and one on a centreline, and a commit searches afresh once per end; the time per move is printed [E]
    Expected: ({int passes, int searches}):<(passes: 2, searches: 42)>
      Actual: ({int passes, int searches}):<(passes: 1, searches: 42)>
    test/dimension_tool_test.dart 1480:5                main.<fn>
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (3 of 3 commands red). Fired at `5ddd96f`, 2026-09-29T11:22:22Z.

#### M-11openinghost — opening hosts not gathered as candidate walls (spec M-11openinghost; killers AM6)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16-M-11openinghost.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  111,119c111
  <   final grown = dimAttach.linear + thickest;
  <   index.forEachInRect(
  <       Aabb2.raw(q.x - grown, q.y - grown, q.x + grown, q.y + grown),
  <       const QueryFilter.rendering(), (slot) {
  <     final owner = doc.entities.ownerAt(slot);
  <     if (!_isLiveGroup(doc, owner)) return;
  <     final host = doc.components.get<OpeningParams>(owner)?.host;
  <     if (host != null && _isLiveWall(doc, host)) walls.add(host);
  <   });
  ---
  >   // M-11openinghost: no opening-host query
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM6 ')` (exit 1; log `t16-M-11openinghost-run1.log`)

  ```
  00:00 +0 -1: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at origin [E]
    Expected: contains AttachedEnd:<16/0/left>
      Actual: []
       Which: does not contain AttachedEnd:<16/0/left>
    test/dimension_attach_test.dart 747:11              main.<fn>
  00:00 +0 -2: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at corpus far origin, 23 deg [E]
    test/dimension_attach_test.dart 747:11              main.<fn>
  00:00 +0 -3: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 747:11              main.<fn>
  00:00 +0 -4: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_test.dart 747:11              main.<fn>
  00:00 +0 -5: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_test.dart 747:11              main.<fn>
  00:00 +0 -6: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_test.dart 747:11              main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:22:26Z.

#### M-11hostbox — opening hosts gathered from the tight box `q ± dimAttach.linear` only (spec M-11hostbox; killers AM6)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16-M-11hostbox.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  111c111
  <   final grown = dimAttach.linear + thickest;
  ---
  >   final grown = dimAttach.linear;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM6 ')` (exit 1; log `t16-M-11hostbox-run1.log`)

  ```
  00:00 +0 -1: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at origin [E]
    Expected: contains AttachedEnd:<16/0/centre>
      Actual: []
       Which: does not contain AttachedEnd:<16/0/centre>
    test/dimension_attach_test.dart 747:11              main.<fn>
  00:00 +0 -2: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at corpus far origin, 23 deg [E]
    test/dimension_attach_test.dart 747:11              main.<fn>
  00:00 +0 -3: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 747:11              main.<fn>
  00:00 +0 -4: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_test.dart 747:11              main.<fn>
  00:00 +0 -5: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_test.dart 747:11              main.<fn>
  00:00 +0 -6: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_test.dart 747:11              main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:22:31Z.

#### M-11reachcull — candidate walls by reach instead of stored boxes (spec M-11reachcull; killers AM1)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16-M-11reachcull.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  104,110c104,110
  <   final tight = dimAttach.linear;
  <   index.forEachInRect(
  <       Aabb2.raw(q.x - tight, q.y - tight, q.x + tight, q.y + tight),
  <       const QueryFilter.rendering(), (slot) {
  <     final owner = doc.entities.ownerAt(slot);
  <     if (_isLiveWall(doc, owner)) walls.add(owner);
  <   });
  ---
  >   for (final h in doc.components.withComponent<WallParams>()) {
  >     if (!_isLiveWall(doc, h)) continue;
  >     if (const WallType()
  >         .reach(doc.components.get<WallParams>(h)!,
  >             doc.tree.accumulatedTransform(h))
  >         .containsPoint(q)) walls.add(h);
  >   }
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM1 ')` (exit 1; log `t16-M-11reachcull-run1.log`)

  ```
  00:00 +0 -1: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at origin [E]
    Expected: contains AttachedEnd:<12/0/left>
      Actual: []
       Which: does not contain AttachedEnd:<12/0/left>
    test/dimension_attach_test.dart 352:11              main.<fn>
  00:00 +0 -2: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 353:11              main.<fn>
  00:00 +0 -3: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_test.dart 353:11              main.<fn>
  00:00 +0 -3: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:22:35Z.

#### M-11ownerring — candidate walls from the snapped entity's owner only (the spike's (A)) (spec M-11ownerring; killers AM2)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16-M-11ownerring.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  104,108c104,109
  <   final tight = dimAttach.linear;
  <   index.forEachInRect(
  <       Aabb2.raw(q.x - tight, q.y - tight, q.x + tight, q.y + tight),
  <       const QueryFilter.rendering(), (slot) {
  <     final owner = doc.entities.ownerAt(slot);
  ---
  >   final res = SnapResult();
  >   index.snapInto(q, dimAttach.linear, kDragSnapMask, res);
  >   if (res.found) {
  >     final owner = res.chainLength > 0
  >         ? Handle(res.chain[0])
  >         : doc.entities.ownerAt(doc.entities.slotOf(res.entity)!);
  110,119c111
  <   });
  <   final grown = dimAttach.linear + thickest;
  <   index.forEachInRect(
  <       Aabb2.raw(q.x - grown, q.y - grown, q.x + grown, q.y + grown),
  <       const QueryFilter.rendering(), (slot) {
  <     final owner = doc.entities.ownerAt(slot);
  <     if (!_isLiveGroup(doc, owner)) return;
  <     final host = doc.components.get<OpeningParams>(owner)?.host;
  <     if (host != null && _isLiveWall(doc, host)) walls.add(host);
  <   });
  ---
  >   }
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM2 ')` (exit 1; log `t16-M-11ownerring-run1.log`)

  ```
  00:00 +0 -1: AM2 a jamb is fixed, a Y lobe vertex finds both walls' points, a T butt corner is the stem's, an X crossing gives no candidate; a degenerate wall and a left-justified wall's points are found, at origin [E]
    Expected: [AttachedEnd:16/0/left, AttachedEnd:1A/0/right]
      Actual: [AttachedEnd:1A/0/right]
       Which: at location [0] is AttachedEnd:<1A/0/right> instead of AttachedEnd:<16/0/left>
    test/dimension_attach_test.dart 429:9               main.<fn>
  00:00 +0 -2: AM2 a jamb is fixed, a Y lobe vertex finds both walls' points, a T butt corner is the stem's, an X crossing gives no candidate; a degenerate wall and a left-justified wall's points are found, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 429:9               main.<fn>
  00:00 +0 -3: AM2 a wall group scaled 1.5 (C11, at its own far placement) has its free rectangle's corners found by the local-frame line test [E]
    test/dimension_attach_test.dart 567:9               main.<fn>
  00:00 +0 -3: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:22:39Z.

#### M-11e — truncate instead of half-up (spec M-11e; killers DF1, DF2, DF3)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11e.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  435,439c435
  <   final n = x.floorToDouble();
  <   if ((mm - (n + 0.5) * quantumMm).abs() <= dimFormat.linear) {
  <     return n.toInt() + 1;
  <   }
  <   return x.round();
  ---
  >   return x.floor();
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_format_test.dart --plain-name 'DF1 ')` (exit 1; log `t16-M-11e-run1.log`)

  ```
  00:00 +0 -1: DF1 every unit at its plan precision, half-up: cm keeps its trailing zero, fractions are reduced, only feet-inches carries marks, and a carry reaches the next foot [E]
    Expected: '3451'
      Actual: '3450'
       Which: is different.
              Expected: 3451
                Actual: 3450
    test/dimension_format_test.dart 121:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_format_test.dart --plain-name 'DF2 ')` (exit 1; log `t16-M-11e-run2.log`)

  ```
  00:00 +0 -1: DF2 half-up is decided within dimFormat.linear of the half: Q5c's rows round up; 3450.5 − 0.9e-6 rounds up and 3450.5 − 2e-6 does not; the review's imperial near-miss prints 9'-0" [E]
    Expected: <101>
      Actual: <100>
    test/dimension_format_test.dart 137:7               main.<fn>.row
    test/dimension_format_test.dart 145:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_format_test.dart --plain-name 'DF3 ')` (exit 1; log `t16-M-11e-run3.log`)

  ```
  00:00 +0 -1: DF3 a half through the object rounds up at all six placements: a free wall 3450.5 long face to face, and a half between two computed corners [E]
    Expected: '3451'
      Actual: '3450'
       Which: is different.
              Expected: 3451
                Actual: 3450
    test/dimension_format_test.dart 253:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (3 of 3 commands red). Fired at `5ddd96f`, 2026-09-29T11:22:52Z.

#### M-11halfnaive — half-up without the tolerance (spec M-11halfnaive; killers DF1, DF2, DF3)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11halfnaive.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  435,438d434
  <   final n = x.floorToDouble();
  <   if ((mm - (n + 0.5) * quantumMm).abs() <= dimFormat.linear) {
  <     return n.toInt() + 1;
  <   }
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_format_test.dart --plain-name 'DF1 ')` (exit 1; log `t16-M-11halfnaive-run1.log`)

  ```
  00:00 +0 -1: DF1 every unit at its plan precision, half-up: cm keeps its trailing zero, fractions are reduced, only feet-inches carries marks, and a carry reaches the next foot [E]
    Expected: '0 1/4'
      Actual: '0 1/8'
       Which: is different.
              Expected: 0 1/4
                Actual: 0 1/8
    test/dimension_format_test.dart 121:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_format_test.dart --plain-name 'DF2 ')` (exit 1; log `t16-M-11halfnaive-run2.log`)

  ```
  00:00 +0 -1: DF2 half-up is decided within dimFormat.linear of the half: Q5c's rows round up; 3450.5 − 0.9e-6 rounds up and 3450.5 − 2e-6 does not; the review's imperial near-miss prints 9'-0" [E]
    Expected: <2>
      Actual: <1>
    test/dimension_format_test.dart 137:7               main.<fn>.row
    test/dimension_format_test.dart 151:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_format_test.dart --plain-name 'DF3 ')` (exit 1; log `t16-M-11halfnaive-run3.log`)

  ```
  00:00 +0 -1: DF3 a half through the object rounds up at all six placements: a free wall 3450.5 long face to face, and a half between two computed corners [E]
    Expected: '3451'
      Actual: '3450'
       Which: is different.
              Expected: 3451
                Actual: 3450
    test/dimension_format_test.dart 253:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (3 of 3 commands red). Fired at `5ddd96f`, 2026-09-29T11:23:04Z.

#### M-11cmzero — the cm trailing zero dropped (spec M-11cmzero; killers DF1)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11cmzero.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  466c466
  <       return '${n ~/ 10}.${n % 10}';
  ---
  >       return n % 10 == 0 ? '${n ~/ 10}' : '${n ~/ 10}.${n % 10}';
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_format_test.dart --plain-name 'DF1 ')` (exit 1; log `t16-M-11cmzero-run1.log`)

  ```
  00:00 +0 -1: DF1 every unit at its plan precision, half-up: cm keeps its trailing zero, fractions are reduced, only feet-inches carries marks, and a carry reaches the next foot [E]
    Expected: '345.0'
      Actual: '345'
       Which: is different. Both strings start the same, but the actual value is missing the following trailing characters: .0
    test/dimension_format_test.dart 121:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:23:08Z.

#### M-11reduce — fractions not reduced (spec M-11reduce; killers DF1)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11reduce.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  484,487d483
  <   while (n.isEven) {
  <     n ~/= 2;
  <     d ~/= 2;
  <   }
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_format_test.dart --plain-name 'DF1 ')` (exit 1; log `t16-M-11reduce-run1.log`)

  ```
  00:00 +0 -1: DF1 every unit at its plan precision, half-up: cm keeps its trailing zero, fractions are reduced, only feet-inches carries marks, and a carry reaches the next foot [E]
    Expected: '136 1/2'
      Actual: '136 4/8'
       Which: is different.
              Expected: 136 1/2
                Actual: 136 4/8
    test/dimension_format_test.dart 121:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:23:12Z.

#### M-11marks — feet-inches without `'` and `"` (spec M-11marks; killers DF1)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11marks.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  476c476
  <       return "$feet'-${rest ~/ 4}${_fraction(rest % 4, 4)}\"";
  ---
  >       return '$feet-${rest ~/ 4}${_fraction(rest % 4, 4)}';
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_format_test.dart --plain-name 'DF1 ')` (exit 1; log `t16-M-11marks-run1.log`)

  ```
  00:00 +0 -1: DF1 every unit at its plan precision, half-up: cm keeps its trailing zero, fractions are reduced, only feet-inches carries marks, and a carry reaches the next foot [E]
    Expected: '11\'-4 1/4"'
      Actual: '11-4 1/4'
       Which: is different.
              Expected: 11'-4 1/4"
                Actual: 11-4 1/4
    test/dimension_format_test.dart 121:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:23:16Z.

#### M-11negzero-f1 — form 1: the offset compared with `==` (the zero's sign lost) (spec M-11negzero; killers DP1, DO3)

- **file:** `apps/floor_planner/lib/parametric/dimension.dart`; backup `t16-M-11negzero-f1.dimension.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  89c89
  <       other.offset.compareTo(offset) == 0;
  ---
  >       other.offset == offset;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_params_test.dart --plain-name 'DP1 ')` (exit 1; log `t16-M-11negzero-f1-run1.log`)

  ```
  00:00 +0 -1: DP1 DimensionParams round-trips with its keys in order and both end shapes; == is exact and tells -0.0 from +0.0, kept through save, load and save; references are deduplicated, at origin [E]
    Expected: false
      Actual: <true>
    test/dimension_params_test.dart 83:7                main.<fn>
  00:00 +0 -2: DP1 DimensionParams round-trips with its keys in order and both end shapes; == is exact and tells -0.0 from +0.0, kept through save, load and save; references are deduplicated, at corpus far origin, 23 deg, own groups [E]
    test/dimension_params_test.dart 83:7                main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_object_test.dart --plain-name 'DO3 ')` (exit 0; log `t16-M-11negzero-f1-run2.log`)

  ```
  00:00 +2: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 2 commands red); green: DO3. Fired at `5ddd96f`, 2026-09-29T11:23:24Z.

#### M-11negzero-f2 — form 2: `toJson` writing `offset.abs()` (spec M-11negzero; killers DP1, DO3)

- **file:** `apps/floor_planner/lib/parametric/dimension.dart`; backup `t16-M-11negzero-f2.dimension.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  59c59
  <         'offset': offset,
  ---
  >         'offset': offset.abs(),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_params_test.dart --plain-name 'DP1 ')` (exit 1; log `t16-M-11negzero-f2-run1.log`)

  ```
  00:00 +0 -1: DP1 DimensionParams round-trips with its keys in order and both end shapes; == is exact and tells -0.0 from +0.0, kept through save, load and save; references are deduplicated, at origin [E]
    Expected: <-617.375>
      Actual: <617.375>
    test/dimension_params_test.dart 40:7                main.<fn>
  00:00 +0 -2: DP1 DimensionParams round-trips with its keys in order and both end shapes; == is exact and tells -0.0 from +0.0, kept through save, load and save; references are deduplicated, at corpus far origin, 23 deg, own groups [E]
    test/dimension_params_test.dart 40:7                main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_object_test.dart --plain-name 'DO3 ')` (exit 1; log `t16-M-11negzero-f2-run2.log`)

  ```
  00:00 +0 -1: DO3 save, load and save is byte-identical, with references intact, drift() empty after the load, and a -0.0 offset kept, at origin [E]
    Expected: empty
      Actual: [26, 40]
    test/dimension_object_test.dart 276:7               main.<fn>
  00:00 +0 -2: DO3 save, load and save is byte-identical, with references intact, drift() empty after the load, and a -0.0 offset kept, at corpus far origin, 23 deg, own groups [E]
    test/dimension_object_test.dart 276:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:23:34Z.

#### M-11a — aligned computed as the axis-projected distance (spec M-11a; killers DL1, SP8)

DZ1 dropped from the killer list (Task 8 ruling Minor 3: its oracle shares layoutDimension).

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11a.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  363c363
  <   final value = kind == DimKind.aligned ? d.length : d.dot(u).abs();
  ---
  >   final value = kind == DimKind.aligned ? d.dot(m.transformDirection(Vector2(1, 0)).normalized()).abs() : d.dot(u).abs();
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_layout_test.dart --plain-name 'DL1 ')` (exit 1; log `t16-M-11a-run1.log`)

  ```
  00:00 +0 -1: DL1 an aligned dimension on the non-axis pair (0, 0)-(3000, 1200) reads 3231, a horizontal one 3000 and a vertical one 1200, at origin [E]
    Expected: '3231'
      Actual: '3000'
       Which: is different.
              Expected: 3231
                Actual: 3000
    test/dimension_layout_test.dart 77:7                main.<fn>
  00:00 +0 -2: DL1 an aligned dimension on the non-axis pair (0, 0)-(3000, 1200) reads 3231, a horizontal one 3000 and a vertical one 1200, at corpus far origin, 23 deg [E]
    test/dimension_layout_test.dart 77:7                main.<fn>
  00:00 +0 -3: DL1 an aligned dimension on the non-axis pair (0, 0)-(3000, 1200) reads 3231, a horizontal one 3000 and a vertical one 1200, at corpus far origin, 23 deg, own groups [E]
    test/dimension_layout_test.dart 77:7                main.<fn>
  00:00 +0 -4: DL1 an aligned dimension on the non-axis pair (0, 0)-(3000, 1200) reads 3231, a horizontal one 3000 and a vertical one 1200, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_layout_test.dart 77:7                main.<fn>
  00:00 +0 -5: DL1 an aligned dimension on the non-axis pair (0, 0)-(3000, 1200) reads 3231, a horizontal one 3000 and a vertical one 1200, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_layout_test.dart 77:7                main.<fn>
  00:00 +0 -6: DL1 an aligned dimension on the non-axis pair (0, 0)-(3000, 1200) reads 3231, a horizontal one 3000 and a vertical one 1200, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_layout_test.dart 77:7                main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/startup_plan_test.dart --plain-name 'SP8 ')` (exit 1; log `t16-M-11a-run2.log`)

  ```
  00:00 +0 -1: SP8 the five dimensions read D17's values at 1:50 m with text 125 high, reference the walls listed, and a click on each line selects it [E]
    Expected: ['14.00', '9.00', '4.69', '4.38', '3.58']
      Actual: ['14.00', '9.00', '4.69', '4.38', '3.45']
       Which: at location [4] is '3.45' instead of '3.58'
    test/startup_plan_test.dart 616:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:23:43Z.

#### M-11offsetp0-layout — the offset from the first point, not the outermost (site 1: layoutDimension) (spec M-11offsetp0; killers DL2)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11offsetp0-layout.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  369c369
  <   final c = (below ? lo : hi) + offset * m.scaleMagnitude;
  ---
  >   final c = h0 + offset * m.scaleMagnitude;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_layout_test.dart --plain-name 'DL2 ')` (exit 1; log `t16-M-11offsetp0-layout-run1.log`)

  ```
  00:00 +0 -1: DL2 the offset runs from the outermost measured point on the line's side; offsetFor follows the pointer outside the band and sticks to the nearer extreme inside it, its side the sign bit, at origin [E]
    Expected: a numeric value within <0.000001> of <-2500.0>
      Actual: <-600.0>
       Which:  differs by <1900.0>
    test/dimension_layout_test.dart 44:3                expectAt
    test/dimension_layout_test.dart 50:3                expectSegment
    test/dimension_layout_test.dart 167:7               main.<fn>
  00:00 +0 -2: DL2 the offset runs from the outermost measured point on the line's side; offsetFor follows the pointer outside the band and sticks to the nearer extreme inside it, its side the sign bit, at corpus far origin, 23 deg, own groups [E]
    test/dimension_layout_test.dart 44:3                expectAt
    test/dimension_layout_test.dart 50:3                expectSegment
    test/dimension_layout_test.dart 167:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:23:47Z.

#### M-11offsetp0-offsetFor — the offset from the first point, not the outermost (site 2: offsetFor) (spec M-11offsetp0; killers DL2)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11offsetp0-offsetFor.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  225,226c225,226
  <   if (hq >= hi) return (hq - hi) / s;
  <   if (hq <= lo) return -((lo - hq) / s);
  ---
  >   if (hq >= hi) return (hq - 0.0) / s;
  >   if (hq <= lo) return -((0.0 - hq) / s);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_layout_test.dart --plain-name 'DL2 ')` (exit 1; log `t16-M-11offsetp0-offsetFor-run1.log`)

  ```
  00:00 +0 -1: DL2 the offset runs from the outermost measured point on the line's side; offsetFor follows the pointer outside the band and sticks to the nearer extreme inside it, its side the sign bit, at origin [E]
    Expected: a numeric value within <0.000001> of <800>
      Actual: <2000.0>
       Which:  differs by <1200.0>
    test/dimension_layout_test.dart 195:7               main.<fn>
  00:00 +0 -2: DL2 the offset runs from the outermost measured point on the line's side; offsetFor follows the pointer outside the band and sticks to the nearer extreme inside it, its side the sign bit, at corpus far origin, 23 deg, own groups [E]
    test/dimension_layout_test.dart 195:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:23:51Z.

#### M-11sign — the side taken as `offset < 0` (the zero's sign ignored) (spec M-11sign; killers DL2, TL3, GE2)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11sign.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  368c368
  <   final below = offset.isNegative;
  ---
  >   final below = offset < 0;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_layout_test.dart --plain-name 'DL2 ')` (exit 1; log `t16-M-11sign-run1.log`)

  ```
  00:00 +0 -1: DL2 the offset runs from the outermost measured point on the line's side; offsetFor follows the pointer outside the band and sticks to the nearer extreme inside it, its side the sign bit, at origin [E]
    Expected: a numeric value within <0.000001> of <0.0>
      Actual: <1200.0>
       Which:  differs by <1200.0>
    test/dimension_layout_test.dart 44:3                expectAt
    test/dimension_layout_test.dart 50:3                expectSegment
    test/dimension_layout_test.dart 232:7               main.<fn>
  00:00 +0 -2: DL2 the offset runs from the outermost measured point on the line's side; offsetFor follows the pointer outside the band and sticks to the nearer extreme inside it, its side the sign bit, at corpus far origin, 23 deg, own groups [E]
    test/dimension_layout_test.dart 44:3                expectAt
    test/dimension_layout_test.dart 50:3                expectSegment
    test/dimension_layout_test.dart 232:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_tool_test.dart --plain-name 'TL3 ')` (exit 1; log `t16-M-11sign-run2.log`)

  ```
  00:00 +0 -1: TL3 the third click's offset runs from the outermost point, sticks to the nearer extreme inside the band, and keeps its side in the sign bit, at origin [E]
    Expected: a numeric value within <0.000001> of <0.0>
      Actual: <1200.0>
       Which:  differs by <1200.0>
    test/dimension_tool_test.dart 562:9                 main.<fn>
  00:00 +0 -2: TL3 the third click's offset runs from the outermost point, sticks to the nearer extreme inside the band, and keeps its side in the sign bit, at corpus far origin, 0 deg [E]
    test/dimension_tool_test.dart 562:9                 main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_grips_test.dart --plain-name 'GE2 ')` (exit 1; log `t16-M-11sign-run3.log`)

  ```
  00:00 +0 -1: GE2 the offset grip stores offsetFor of the drop with the current kind: outermost, between band, sign bit; one undo step; a drop that changes nothing returns null, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <1200.0000000000005>
       Which: is not a value less than <0.000001>
    test/dimension_grips_test.dart 72:5                 expectNear
    test/dimension_grips_test.dart 164:9                main.<fn>.lineAt
    test/dimension_grips_test.dart 188:9                main.<fn>
  00:00 +0 -2: GE2 the offset grip stores offsetFor of the drop with the current kind: outermost, between band, sign bit; one undo step; a drop that changes nothing returns null, at corpus far origin, 23 deg, own groups [E]
    test/dimension_grips_test.dart 72:5                 expectNear
    test/dimension_grips_test.dart 164:9                main.<fn>.lineAt
    test/dimension_grips_test.dart 188:9                main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (3 of 3 commands red). Fired at `5ddd96f`, 2026-09-29T11:24:04Z.

#### M-11between — the between band always goes to the upper extreme (spec M-11between; killers DL2, TL3, GE2)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11between.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  227c227
  <   return hi - hq <= hq - lo ? 0.0 : -0.0;
  ---
  >   return 0.0;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_layout_test.dart --plain-name 'DL2 ')` (exit 1; log `t16-M-11between-run1.log`)

  ```
  00:00 +0 -1: DL2 the offset runs from the outermost measured point on the line's side; offsetFor follows the pointer outside the band and sticks to the nearer extreme inside it, its side the sign bit, at origin [E]
    Expected: true
      Actual: <false>
    test/dimension_layout_test.dart 227:7               main.<fn>
  00:00 +0 -2: DL2 the offset runs from the outermost measured point on the line's side; offsetFor follows the pointer outside the band and sticks to the nearer extreme inside it, its side the sign bit, at corpus far origin, 23 deg, own groups [E]
    test/dimension_layout_test.dart 227:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_tool_test.dart --plain-name 'TL3 ')` (exit 1; log `t16-M-11between-run2.log`)

  ```
  00:00 +0 -1: TL3 the third click's offset runs from the outermost point, sticks to the nearer extreme inside the band, and keeps its side in the sign bit, at origin [E]
    Expected: <true>
      Actual: <false>
    test/dimension_tool_test.dart 558:9                 main.<fn>
  00:00 +0 -2: TL3 the third click's offset runs from the outermost point, sticks to the nearer extreme inside the band, and keeps its side in the sign bit, at corpus far origin, 0 deg [E]
    test/dimension_tool_test.dart 558:9                 main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_grips_test.dart --plain-name 'GE2 ')` (exit 1; log `t16-M-11between-run3.log`)

  ```
  00:00 +0 -1: GE2 the offset grip stores offsetFor of the drop with the current kind: outermost, between band, sign bit; one undo step; a drop that changes nothing returns null, at origin [E]
    Expected: not null
      Actual: <null>
    test/dimension_grips_test.dart 63:3                 drop
    test/dimension_grips_test.dart 182:9                main.<fn>
  00:00 +0 -2: GE2 the offset grip stores offsetFor of the drop with the current kind: outermost, between band, sign bit; one undo step; a drop that changes nothing returns null, at corpus far origin, 23 deg, own groups [E]
    test/dimension_grips_test.dart 63:3                 drop
    test/dimension_grips_test.dart 182:9                main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (3 of 3 commands red). Fired at `5ddd96f`, 2026-09-29T11:24:18Z.

#### M-11fliptol — no tolerance at exactly vertical (spec M-11fliptol; killers DL4)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11fliptol.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  237c237
  <   if (u.x < -dimFormat.angular || (u.x.abs() <= dimFormat.angular && u.y < 0)) {
  ---
  >   if (u.x < 0 || (u.x == 0 && u.y < 0)) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_layout_test.dart --plain-name 'DL4 ')` (exit 1; log `t16-M-11fliptol-run1.log`)

  ```
  00:00 +0 -1: DL4 readable reverses a direction that would read from the top or the left, reads exactly vertical upwards, and a vertical dimension in a group turned −90° reads +90° [E]
    Expected: a numeric value within <1e-9> of <90>
      Actual: <-89.99999999994272>
       Which:  differs by <179.9999999999427>
    test/dimension_layout_test.dart 363:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:24:23Z.

#### M-11flip — `readable` never flips (spec M-11flip; killers DL3, DL4)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11flip.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  238c238
  <     return -u;
  ---
  >     return u;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_layout_test.dart --plain-name 'DL3 ')` (exit 1; log `t16-M-11flip-run1.log`)

  ```
  00:00 +0 -1: DL3 the children by hand at 1:50 and 1:100, and a pair drawn right to left reads upright with its text above the line, at origin [E]
    Expected: a numeric value within <0.000001> of <3946.966991411009>
      Actual: <4053.033008588991>
       Which:  differs by <106.06601717798185>
    test/dimension_layout_test.dart 43:3                expectAt
    test/dimension_layout_test.dart 50:3                expectSegment
    test/dimension_layout_test.dart 332:7               main.<fn>
  00:00 +0 -2: DL3 the children by hand at 1:50 and 1:100, and a pair drawn right to left reads upright with its text above the line, at corpus far origin, 23 deg, own groups [E]
    test/dimension_layout_test.dart 43:3                expectAt
    test/dimension_layout_test.dart 50:3                expectSegment
    test/dimension_layout_test.dart 332:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_layout_test.dart --plain-name 'DL4 ')` (exit 1; log `t16-M-11flip-run2.log`)

  ```
  00:00 +0 -1: DL4 readable reverses a direction that would read from the top or the left, reads exactly vertical upwards, and a vertical dimension in a group turned −90° reads +90° [E]
    Expected: a numeric value within <1e-9> of <-45>
      Actual: <135.0>
       Which:  differs by <180.0>
    test/dimension_layout_test.dart 355:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:24:31Z.

#### M-11textbelow — the text on the line's other side (`−nr`) (spec M-11textbelow; killers DL3)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11textbelow.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  387c387
  <   final textAt = p0 + ((r0 + r1) * 0.5 + nr * (kDimTextGapPaperMm * scale));
  ---
  >   final textAt = p0 + ((r0 + r1) * 0.5 - nr * (kDimTextGapPaperMm * scale));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_layout_test.dart --plain-name 'DL3 ')` (exit 1; log `t16-M-11textbelow-run1.log`)

  ```
  00:00 +0 -1: DL3 the children by hand at 1:50 and 1:100, and a pair drawn right to left reads upright with its text above the line, at origin [E]
    Expected: a numeric value within <0.000001> of <650.0>
      Actual: <550.0>
       Which:  differs by <100.0>
    test/dimension_layout_test.dart 44:3                expectAt
    test/dimension_layout_test.dart 289:7               main.<fn>
  00:00 +0 -2: DL3 the children by hand at 1:50 and 1:100, and a pair drawn right to left reads upright with its text above the line, at corpus far origin, 23 deg, own groups [E]
    test/dimension_layout_test.dart 44:3                expectAt
    test/dimension_layout_test.dart 289:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:24:36Z.

#### M-11slash — the slash along `ur − nr` (spec M-11slash; killers DL3)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11slash.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  386c386
  <   final t = (ur + nr).normalized() * (kDimSlashPaperMm * scale / 2);
  ---
  >   final t = (ur - nr).normalized() * (kDimSlashPaperMm * scale / 2);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_layout_test.dart --plain-name 'DL3 ')` (exit 1; log `t16-M-11slash-run1.log`)

  ```
  00:00 +0 -1: DL3 the children by hand at 1:50 and 1:100, and a pair drawn right to left reads upright with its text above the line, at origin [E]
    Expected: a numeric value within <0.000001> of <546.966991411009>
      Actual: <653.033008588991>
       Which:  differs by <106.06601717798208>
    test/dimension_layout_test.dart 44:3                expectAt
    test/dimension_layout_test.dart 50:3                expectSegment
    test/dimension_layout_test.dart 286:7               main.<fn>
  00:00 +0 -2: DL3 the children by hand at 1:50 and 1:100, and a pair drawn right to left reads upright with its text above the line, at corpus far origin, 23 deg, own groups [E]
    test/dimension_layout_test.dart 44:3                expectAt
    test/dimension_layout_test.dart 50:3                expectSegment
    test/dimension_layout_test.dart 286:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:24:40Z.

#### M-11extpage — the extension gap and overshoot not multiplied by the page's scale (spec M-11extpage; killers DL3)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11extpage.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  373,374c373,374
  <   final g = kDimExtGapPaperMm * scale;
  <   final v = kDimExtOvershootPaperMm * scale;
  ---
  >   final g = kDimExtGapPaperMm * 1.0;
  >   final v = kDimExtOvershootPaperMm * 1.0;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_layout_test.dart --plain-name 'DL3 ')` (exit 1; log `t16-M-11extpage-run1.log`)

  ```
  00:00 +0 -1: DL3 the children by hand at 1:50 and 1:100, and a pair drawn right to left reads upright with its text above the line, at origin [E]
    Expected: a numeric value within <0.000001> of <75.0>
      Actual: <1.5>
       Which:  differs by <73.5>
    test/dimension_layout_test.dart 44:3                expectAt
    test/dimension_layout_test.dart 50:3                expectSegment
    test/dimension_layout_test.dart 284:7               main.<fn>
  00:00 +0 -2: DL3 the children by hand at 1:50 and 1:100, and a pair drawn right to left reads upright with its text above the line, at corpus far origin, 23 deg, own groups [E]
    test/dimension_layout_test.dart 44:3                expectAt
    test/dimension_layout_test.dart 50:3                expectSegment
    test/dimension_layout_test.dart 284:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:24:44Z.

#### M-11b — the paper half: the text height not multiplied by the page's scale (spec M-11b; killers DO2, RR1)

Site dimension_geometry.dart:392 (the Task 15 correction: the recorded edit string was stale).

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11b.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  392c392
  <   final textHeight = kDimTextPaperMm * scale;
  ---
  >   final textHeight = kDimTextPaperMm;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_object_test.dart --plain-name 'DO2 ')` (exit 1; log `t16-M-11b-run1.log`)

  ```
  00:00 +0 -1: DO2 a page change rewrites every dimension in one undo step with the same child handles; a paper colour or grid change generates none; no page reads as 1:50 m, at origin [E]
    Expected: a numeric value within <1e-9> of <125.0>
      Actual: <2.5>
       Which:  differs by <122.5>
    test/dimension_object_test.dart 175:9               main.<fn>.expectText
    test/dimension_object_test.dart 184:7               main.<fn>
  00:00 +0 -2: DO2 a page change rewrites every dimension in one undo step with the same child handles; a paper colour or grid change generates none; no page reads as 1:50 m, at corpus far origin, 23 deg, own groups [E]
    test/dimension_object_test.dart 175:9               main.<fn>.expectText
    test/dimension_object_test.dart 184:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_paint_test.dart --plain-name 'RR1 ')` (exit 1; log `t16-M-11b-run2.log`)

  ```
  Expected: not null
    Actual: <null>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_paint_test.dart:263:9)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_paint_test.dart line 263
  00:02 +0 -1: RR1 the dimension text is the same world height at 0.15 and 0.3 px/mm and doubles at 1:100; a slash inks; the extension line inks from its gap [E]
    The test description was: RR1 the dimension text is the same world height at 0.15 and 0.3 px/mm and doubles at 1:100; a slash inks; the extension line inks from its gap
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:24:55Z.

#### M-11page — no page key (spec M-11page; killers DO2)

- **file:** `apps/floor_planner/lib/parametric/dimension.dart`; backup `t16-M-11page.dimension.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  160,161c160
  <     final p = page ?? _defaultPage;
  <     return (p.displayUnit, p.scaleDenominator);
  ---
  >     return null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_object_test.dart --plain-name 'DO2 ')` (exit 1; log `t16-M-11page-run1.log`)

  ```
  00:00 +0 -1: DO2 a page change rewrites every dimension in one undo step with the same child handles; a paper colour or grid change generates none; no page reads as 1:50 m, at origin [E]
    Expected: a value greater than <1>
      Actual: <1>
       Which: is not a value greater than <1>
    test/dimension_object_test.dart 210:9               main.<fn>
  00:00 +0 -2: DO2 a page change rewrites every dimension in one undo step with the same child handles; a paper colour or grid change generates none; no page reads as 1:50 m, at corpus far origin, 23 deg, own groups [E]
    test/dimension_object_test.dart 210:9               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:25:00Z.

#### M-11text — engine: a matched TEXT's string never rewritten (10's M-10f site) (spec M-11text; killers DO2, DN1)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t16-M-11text.regeneration.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  556c556
  <         if (g.kind == EntityKind.text && t.entities.textAt(slot) != g.text) {
  ---
  >         if (false && g.kind == EntityKind.text && t.entities.textAt(slot) != g.text) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_object_test.dart --plain-name 'DO2 ')` (exit 1; log `t16-M-11text-run1.log`)

  ```
  00:00 +0 -1: DO2 a page change rewrites every dimension in one undo step with the same child handles; a paper colour or grid change generates none; no page reads as 1:50 m, at origin [E]
    Expected: '400.0'
      Actual: '4000'
       Which: is different.
              Expected: 400.0
                Actual: 4000
    test/dimension_object_test.dart 173:9               main.<fn>.expectText
    test/dimension_object_test.dart 211:9               main.<fn>
  00:00 +0 -2: DO2 a page change rewrites every dimension in one undo step with the same child handles; a paper colour or grid change generates none; no page reads as 1:50 m, at corpus far origin, 23 deg, own groups [E]
    test/dimension_object_test.dart 173:9               main.<fn>.expectText
    test/dimension_object_test.dart 211:9               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_follow_test.dart --plain-name 'DN1 ')` (exit 1; log `t16-M-11text-run2.log`)

  ```
  00:00 +0 -1: DN1 a neighbour's edit moves a referenced wall's corner and rebuilds the dimension once, at origin [E]
    Expected: '3850'
      Actual: '3900'
       Which: is different.
              Expected: 3850
                Actual: 3900
    test/dimension_follow_test.dart 91:7                main.<fn>
  00:00 +0 -2: DN1 a neighbour's edit moves a referenced wall's corner and rebuilds the dimension once, at corpus far origin, 23 deg, own groups [E]
    test/dimension_follow_test.dart 91:7                main.<fn>
  00:00 +0 -3: DN1 a neighbour's edit moves a referenced wall's corner and rebuilds the dimension once, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_follow_test.dart 91:7                main.<fn>
  00:00 +0 -3: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet -- packages/jet_cad_2d/lib/src/parametric/regeneration.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:25:08Z.

#### M-11lw — the lines' lineweight not 25 (decision 20's fallback 30 as the fired form) (spec M-11lw; killers DO1)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11lw.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  261c261
  < const int kDimLineweight = 25;
  ---
  > const int kDimLineweight = 30;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_object_test.dart --plain-name 'DO1 ')` (exit 1; log `t16-M-11lw-run1.log`)

  ```
  00:00 +0 -1: DO1 a dimension's children are five LINEs and one TEXT in handle order; only the two extension lines carry EntityFlags.unpickable; lineweight 25, ByLayer, layer 0, bottom-centre text [E]
    Expected: <25>
      Actual: <30>
    test/dimension_object_test.dart 147:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:25:13Z.

#### M-11colour-lines — site 1: the lines generated in a `TrueColor`, not ByLayer (spec M-11colour; killers RR3, DO1)

- **file:** `apps/floor_planner/lib/parametric/dimension.dart`; backup `t16-M-11colour-lines.dimension.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  200c200
  <             lineweight: kDimLineweight, flags: flags);
  ---
  >             lineweight: kDimLineweight, flags: flags, color: const TrueColor(0x000000));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_paint_test.dart --plain-name 'RR3 ')` (exit 1; log `t16-M-11colour-lines-run1.log`)

  ```
  Expected: a value greater than or equal to <230>
    Actual: <0>
     Which: is not a value greater than or equal to <230>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_paint_test.dart:433:9)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_paint_test.dart line 433
  00:03 +0 -1: RR3 on Blueprint paper the dimension ink is the foreground [E]
    The test description was: RR3 on Blueprint paper the dimension ink is the foreground
  00:03 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_object_test.dart --plain-name 'DO1 ')` (exit 1; log `t16-M-11colour-lines-run2.log`)

  ```
  00:00 +0 -1: DO1 a dimension's children are five LINEs and one TEXT in handle order; only the two extension lines carry EntityFlags.unpickable; lineweight 25, ByLayer, layer 0, bottom-centre text [E]
    Expected: ByLayerColor:<ByLayerColor()>
      Actual: TrueColor:<TrueColor(0x000000)>
    test/dimension_object_test.dart 141:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:25:24Z.

#### M-11colour-text — site 2: the text generated in a `TrueColor`, not ByLayer (spec M-11colour; killers RR3, DO1)

- **file:** `apps/floor_planner/lib/parametric/dimension.dart`; backup `t16-M-11colour-text.dimension.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  218c218
  <           textAttrs: kDimTextAttrs),
  ---
  >           textAttrs: kDimTextAttrs, color: const TrueColor(0x000000)),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_paint_test.dart --plain-name 'RR3 ')` (exit 1; log `t16-M-11colour-text-run1.log`)

  ```
  Expected: a value greater than or equal to <230>
    Actual: <0>
     Which: is not a value greater than or equal to <230>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_paint_test.dart:433:9)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_paint_test.dart line 433
  00:02 +0 -1: RR3 on Blueprint paper the dimension ink is the foreground [E]
    The test description was: RR3 on Blueprint paper the dimension ink is the foreground
  00:03 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_object_test.dart --plain-name 'DO1 ')` (exit 1; log `t16-M-11colour-text-run2.log`)

  ```
  00:00 +0 -1: DO1 a dimension's children are five LINEs and one TEXT in handle order; only the two extension lines carry EntityFlags.unpickable; lineweight 25, ByLayer, layer 0, bottom-centre text [E]
    Expected: ByLayerColor:<ByLayerColor()>
      Actual: TrueColor:<TrueColor(0x000000)>
    test/dimension_object_test.dart 141:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:25:35Z.

#### M-11extflag — the extension lines generated without the flag (spec M-11extflag; killers DO1, SL1)

- **file:** `apps/floor_planner/lib/parametric/dimension.dart`; backup `t16-M-11extflag.dimension.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  204,205c204,205
  <       line(l.ext0, flags: EntityFlags.unpickable),
  <       line(l.ext1, flags: EntityFlags.unpickable),
  ---
  >       line(l.ext0),
  >       line(l.ext1),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_object_test.dart --plain-name 'DO1 ')` (exit 1; log `t16-M-11extflag-run1.log`)

  ```
  00:00 +0 -1: DO1 a dimension's children are five LINEs and one TEXT in handle order; only the two extension lines carry EntityFlags.unpickable; lineweight 25, ByLayer, layer 0, bottom-centre text [E]
    Expected: [0, 2, 2, 0, 0, 0]
      Actual: [0, 0, 0, 0, 0, 0]
       Which: at location [1] is <0> instead of <2>
    test/dimension_object_test.dart 132:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_shell_test.dart --plain-name 'SL1 ')` (exit 1; log `t16-M-11extflag-run2.log`)

  ```
  Expected: [SelectionKey:SelectionKey( 1E)]
    Actual: Set:[SelectionKey:SelectionKey( 286)]
     Which: at location [0] is SelectionKey:<SelectionKey( 286)> instead of
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_shell_test.dart:256:7)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_shell_test.dart line 256
  00:03 +0 -1: SL1 through the select tool on the sample plan: a click on a dimension line selects it; a click on E4's face under the Hall's extension line selects E4; a window band around the Hall's line, slashes and text selects it; dimensions move and turn by their fixed ends only; deleting E1 deletes three dimensions in one st [cut; the full line is in the log]
    The test description was: SL1 through the select tool on the sample plan: a click on a dimension line selects it; a click on E4's face under the Hall's extension line selects E4; a window band around the Hall's line, slashes and text selects it; dimensions move and turn by their fixed ends only; deleting E1 deletes three dimen [cut; the full line is in the log]
  00:03 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:25:47Z.

#### M-11stable — a zero dimension generates fewer children (spec M-11stable; killers DL5)

- **file:** `apps/floor_planner/lib/parametric/dimension.dart`; backup `t16-M-11stable.dimension.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  203c203
  <       line((l.q0, l.q1)),
  ---
  >       if ((l.q1 - l.q0).length > wallJoin.linear) line((l.q0, l.q1)),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_layout_test.dart --plain-name 'DL5 ')` (exit 1; log `t16-M-11stable-run1.log`)

  ```
  00:00 +0 -1: DL5 a coincident aligned pair and a vertical pair measured horizontally still draw six children, read 0, and report dimension.degenerate, at origin [E]
    Expected: [
      Actual: [
       Which: at location [4] is EntityKind:<EntityKind.text> instead of EntityKind:<EntityKind.line>
    test/dimension_layout_test.dart 417:7               main.<fn>
  00:00 +0 -2: DL5 a coincident aligned pair and a vertical pair measured horizontally still draw six children, read 0, and report dimension.degenerate, at corpus far origin, 23 deg, own groups [E]
    test/dimension_layout_test.dart 417:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:25:51Z.

#### M-11degenerate — `dimension.degenerate` never reported (spec M-11degenerate; killers DD1)

- **file:** `apps/floor_planner/lib/parametric/dimension.dart`; backup `t16-M-11degenerate.dimension.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  272c272
  <     if (l == null || l.value > wallJoin.linear) return const [];
  ---
  >     return const [];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_object_test.dart --plain-name 'DD1 ')` (exit 1; log `t16-M-11degenerate-run1.log`)

  ```
  00:00 +0 -1: DD1 dimension.degenerate is one warning while the value is within wallJoin.linear of zero, and clears when it grows, at origin [E]
    Expected: [Diagnostic:[warning] dimension.degenerate: 16 measures zero]
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/dimension_object_test.dart 437:7               main.<fn>
  00:00 +0 -2: DD1 dimension.degenerate is one warning while the value is within wallJoin.linear of zero, and clears when it grows, at corpus far origin, 23 deg, own groups [E]
    test/dimension_object_test.dart 437:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:25:55Z.

#### M-11broken — a broken end generates from a fallback point instead of nothing (combined form: k, point, offset) (spec M-11broken; killers DD2)

- **file:** `apps/floor_planner/lib/parametric/dimension.dart`; backup `t16-M-11broken.dimension.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  118,119c118
  <       if (!x.isFinite || !y.isFinite) return null;
  <       return view.toWorld(self).transformPoint(end.point);
  ---
  >       return view.toWorld(self).transformPoint(Vector2(x.isFinite ? x : 0, y.isFinite ? y : 0));
  121d119
  <       if (k != 0 && k != 1) return null;
  124c122
  <       return wallEndPoint(w.host, w.walls, k, side);
  ---
  >       return wallEndPoint(w.host, w.walls, k.clamp(0, 1), side);
  185d182
  <     if (!p.offset.isFinite) return const [];
  192c189
  <     final l = layoutDimension(p0, p1, p.kind, toWorld, p.offset, page);
  ---
  >     final l = layoutDimension(p0, p1, p.kind, toWorld, p.offset.isFinite ? p.offset : 0.0, page);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_object_test.dart --plain-name 'DD2 ')` (exit 1; log `t16-M-11broken-run1.log`)

  ```
  00:00 +0 -1: DD2 dimension.broken from a file (a live box as the wall, k = 2, an infinite point, an infinite offset) and from a command (a NaN point, a NaN offset): each an error, childless; a dead wall handle is parametric.dangling only, at origin [E]
    Expected: empty
      Actual: [28, 29, 30, 33]
    test/dimension_object_test.dart 569:7               main.<fn>
  00:00 +0 -2: DD2 dimension.broken from a file (a live box as the wall, k = 2, an infinite point, an infinite offset) and from a command (a NaN point, a NaN offset): each an error, childless; a dead wall handle is parametric.dangling only, at corpus far origin, 23 deg, own groups [E]
    test/dimension_object_test.dart 569:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:26:00Z.

#### M-11closure — engine: referrers of the seeds only (08's brief rule) (spec M-11closure; killers DN1, DN2, DZ1)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t16-M-11closure.regeneration.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  397,398c397,398
  <     for (final x in core) ...?before.referrers[x],
  <     for (final x in core) ...?after.referrers[x],
  ---
  >     for (final x in seeds) ...?before.referrers[x],
  >     for (final x in seeds) ...?after.referrers[x],
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_follow_test.dart --plain-name 'DN1 ')` (exit 1; log `t16-M-11closure-run1.log`)

  ```
  00:00 +0 -1: DN1 a neighbour's edit moves a referenced wall's corner and rebuilds the dimension once, at origin [E]
    Expected: '3850'
      Actual: '3900'
       Which: is different.
              Expected: 3850
                Actual: 3900
    test/dimension_follow_test.dart 91:7                main.<fn>
  00:00 +0 -2: DN1 a neighbour's edit moves a referenced wall's corner and rebuilds the dimension once, at corpus far origin, 23 deg, own groups [E]
    test/dimension_follow_test.dart 91:7                main.<fn>
  00:00 +0 -3: DN1 a neighbour's edit moves a referenced wall's corner and rebuilds the dimension once, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_follow_test.dart 91:7                main.<fn>
  00:00 +0 -3: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_follow_test.dart --plain-name 'DN2 ')` (exit 1; log `t16-M-11closure-run2.log`)

  ```
  00:00 +0 -1: DN2 the T: the through wall thickened moves the stem's corner; the through wall moved off the stem squares it, at origin [E]
    Expected: '2800'
      Actual: '2900'
       Which: is different.
              Expected: 2800
                Actual: 2900
    test/dimension_follow_test.dart 152:7               main.<fn>
  00:00 +0 -2: DN2 the T: the through wall thickened moves the stem's corner; the through wall moved off the stem squares it, at corpus far origin, 23 deg, own groups [E]
    test/dimension_follow_test.dart 152:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_fuzz_test.dart --plain-name 'DZ1 ')` (exit 1; log `t16-M-11closure-run3.log`)

  ```
  00:00 +0 -1: DZ1 300 seeded edits keep every dimension equal to the all-walls oracle, with neighbour-only rebuilds; a reload agrees [E]
    Expected: empty
      Actual: [
    test/dimension_fuzz_test.dart 314:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet -- packages/jet_cad_2d/lib/src/parametric/regeneration.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (3 of 3 commands red). Fired at `5ddd96f`, 2026-09-29T11:26:12Z.

#### M-11refs — the dimension references nothing (spec M-11refs; killers DN1, DN3)

- **file:** `apps/floor_planner/lib/parametric/dimension.dart`; backup `t16-M-11refs.dimension.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  149,152c149
  <   Iterable<Handle> references(DimensionParams params) => {
  <         if (params.a case AttachedEnd(:final wall)) wall,
  <         if (params.b case AttachedEnd(:final wall)) wall,
  <       };
  ---
  >   Iterable<Handle> references(DimensionParams params) => const <Handle>[];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_follow_test.dart --plain-name 'DN1 ')` (exit 1; log `t16-M-11refs-run1.log`)

  ```
  00:00 +0 -1: DN1 a neighbour's edit moves a referenced wall's corner and rebuilds the dimension once, at origin [E]
    Expected: '3850'
      Actual: '3900'
       Which: is different.
              Expected: 3850
                Actual: 3900
    test/dimension_follow_test.dart 91:7                main.<fn>
  00:00 +0 -2: DN1 a neighbour's edit moves a referenced wall's corner and rebuilds the dimension once, at corpus far origin, 23 deg, own groups [E]
    test/dimension_follow_test.dart 91:7                main.<fn>
  00:00 +0 -3: DN1 a neighbour's edit moves a referenced wall's corner and rebuilds the dimension once, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_follow_test.dart 91:7                main.<fn>
  00:00 +0 -3: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_follow_test.dart --plain-name 'DN3 ')` (exit 1; log `t16-M-11refs-run2.log`)

  ```
  00:00 +0 -1: DN3 deleting a wall carrying three dimensions deletes all three in the same step; the other wall's dimensions rebuild or stay; undo restores every handle, owner and text, at origin [E]
    Expected: null
      Actual: GroupNode:<GroupNode(1A, 0 children)>
    test/dimension_follow_test.dart 229:9               main.<fn>
  00:00 +0 -2: DN3 deleting a wall carrying three dimensions deletes all three in the same step; the other wall's dimensions rebuild or stay; undo restores every handle, owner and text, at corpus far origin, 23 deg, own groups [E]
    test/dimension_follow_test.dart 229:9               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:26:21Z.

#### M-11c — the value computed once per dimension and reused (a memo by handle) (spec M-11c; killers DN1, DN2, DZ1)

- **file:** `apps/floor_planner/lib/parametric/dimension.dart`; backup `t16-M-11c.dimension.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  109a110
  > final _t16memo = <Handle, String>{};
  217c218
  <           l.text,
  ---
  >           _t16memo.putIfAbsent(self, () => l.text),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_follow_test.dart --plain-name 'DN1 ')` (exit 1; log `t16-M-11c-run1.log`)

  ```
  00:00 +0 -1: DN1 a neighbour's edit moves a referenced wall's corner and rebuilds the dimension once, at origin [E]
    Expected: '3850'
      Actual: '3900'
       Which: is different.
              Expected: 3850
                Actual: 3900
    test/dimension_follow_test.dart 91:7                main.<fn>
  00:00 +0 -2: DN1 a neighbour's edit moves a referenced wall's corner and rebuilds the dimension once, at corpus far origin, 23 deg, own groups [E]
    test/dimension_follow_test.dart 91:7                main.<fn>
  00:00 +0 -3: DN1 a neighbour's edit moves a referenced wall's corner and rebuilds the dimension once, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_follow_test.dart 91:7                main.<fn>
  00:00 +0 -3: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_follow_test.dart --plain-name 'DN2 ')` (exit 1; log `t16-M-11c-run2.log`)

  ```
  00:00 +0 -1: DN2 the T: the through wall thickened moves the stem's corner; the through wall moved off the stem squares it, at origin [E]
    Expected: '2800'
      Actual: '2900'
       Which: is different.
              Expected: 2800
                Actual: 2900
    test/dimension_follow_test.dart 152:7               main.<fn>
  00:00 +0 -2: DN2 the T: the through wall thickened moves the stem's corner; the through wall moved off the stem squares it, at corpus far origin, 23 deg, own groups [E]
    test/dimension_follow_test.dart 152:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_fuzz_test.dart --plain-name 'DZ1 ')` (exit 1; log `t16-M-11c-run3.log`)

  ```
  00:00 +0 -1: DZ1 300 seeded edits keep every dimension equal to the all-walls oracle, with neighbour-only rebuilds; a reload agrees [E]
    Expected: empty
      Actual: [
    test/dimension_fuzz_test.dart 314:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (3 of 3 commands red). Fired at `5ddd96f`, 2026-09-29T11:26:33Z.

#### M-11shift — Shift ignored at the third click (spec M-11shift; killers TL2)

The commit's kindFor (the third click); the preview's kindFor is the preview's rule (TL5), not this mutant's site.

- **file:** `apps/floor_planner/lib/parametric/dimension_tool.dart`; backup `t16-M-11shift.dimension_tool.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  283c283
  <     final kind = kindFor(q, p0, p1, shift: _shift);
  ---
  >     final kind = kindFor(q, p0, p1, shift: false);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_tool_test.dart --plain-name 'TL2 ')` (exit 1; log `t16-M-11shift-run1.log`)

  ```
  00:00 +0 -1: TL2 with Shift the third click is linear by the side dragged to, without it aligned; Shift at the second click is ortho, at the third it is not, at origin [E]
    Expected: DimKind:<DimKind.horizontal>
      Actual: DimKind:<DimKind.aligned>
    test/dimension_tool_test.dart 464:9                 main.<fn>
  00:00 +0 -2: TL2 with Shift the third click is linear by the side dragged to, without it aligned; Shift at the second click is ortho, at the third it is not, at corpus far origin, 0 deg [E]
    test/dimension_tool_test.dart 464:9                 main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_tool.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_tool.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:26:37Z.

#### M-11dragside — horizontal and vertical swapped in the drag-side rule (spec M-11dragside; killers TL2)

- **file:** `apps/floor_planner/lib/parametric/dimension_tool.dart`; backup `t16-M-11dragside.dimension_tool.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  223c223
  <     final horizontal = ey > ex || (ey == ex && dx >= dy);
  ---
  >     final horizontal = ex > ey || (ey == ex && dx >= dy);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_tool_test.dart --plain-name 'TL2 ')` (exit 1; log `t16-M-11dragside-run1.log`)

  ```
  00:00 +0 -1: TL2 with Shift the third click is linear by the side dragged to, without it aligned; Shift at the second click is ortho, at the third it is not, at origin [E]
    Expected: DimKind:<DimKind.horizontal>
      Actual: DimKind:<DimKind.vertical>
    test/dimension_tool_test.dart 464:9                 main.<fn>
  00:00 +0 -2: TL2 with Shift the third click is linear by the side dragged to, without it aligned; Shift at the second click is ortho, at the third it is not, at corpus far origin, 0 deg [E]
    test/dimension_tool_test.dart 464:9                 main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_tool.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_tool.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:26:42Z.

#### M-11zerokind — the zero-measuring linear kind is committed (spec M-11zerokind; killers TL2)

- **file:** `apps/floor_planner/lib/parametric/dimension_tool.dart`; backup `t16-M-11zerokind.dimension_tool.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  225c225
  <       return dx <= wallJoin.linear ? DimKind.vertical : DimKind.horizontal;
  ---
  >       return DimKind.horizontal;
  227c227
  <     return dy <= wallJoin.linear ? DimKind.horizontal : DimKind.vertical;
  ---
  >     return DimKind.vertical;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_tool_test.dart --plain-name 'TL2 ')` (exit 1; log `t16-M-11zerokind-run1.log`)

  ```
  00:00 +0 -1: TL2 with Shift the third click is linear by the side dragged to, without it aligned; Shift at the second click is ortho, at the third it is not, at origin [E]
    Expected: DimKind:<DimKind.vertical>
      Actual: DimKind:<DimKind.horizontal>
    test/dimension_tool_test.dart 476:7                 main.<fn>
  00:00 +0 -2: TL2 with Shift the third click is linear by the side dragged to, without it aligned; Shift at the second click is ortho, at the third it is not, at corpus far origin, 0 deg [E]
    test/dimension_tool_test.dart 476:7                 main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_tool.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_tool.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:26:46Z.

#### M-11ortho3 — ortho stays on at the third click (spec M-11ortho3; killers TL2)

- **file:** `apps/floor_planner/lib/parametric/dimension_tool.dart`; backup `t16-M-11ortho3.dimension_tool.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  175c175
  <   Vector2? get orthoBase => points.length >= 2 ? null : super.orthoBase;
  ---
  >   Vector2? get orthoBase => super.orthoBase;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_tool_test.dart --plain-name 'TL2 ')` (exit 1; log `t16-M-11ortho3-run1.log`)

  ```
  00:00 +0 -1: TL2 with Shift the third click is linear by the side dragged to, without it aligned; Shift at the second click is ortho, at the third it is not, at origin [E]
    Expected: [1500.0, 2000.0]
      Actual: [1500.0, 1200.0]
       Which: at location [1] is <1200.0> instead of <2000.0>
    test/dimension_tool_test.dart 105:3                 expectFree
    test/dimension_tool_test.dart 441:35                main.<fn>.place3
    test/dimension_tool_test.dart 463:19                main.<fn>
  00:00 +0 -2: TL2 with Shift the third click is linear by the side dragged to, without it aligned; Shift at the second click is ortho, at the third it is not, at corpus far origin, 0 deg [E]
    test/dimension_tool_test.dart 105:3                 expectFree
    test/dimension_tool_test.dart 441:35                main.<fn>.place3
    test/dimension_tool_test.dart 463:19                main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_tool.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_tool.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:26:50Z.

#### M-11degeneratepair — a second click on the first point is accepted (spec M-11degeneratepair; killers TL4)

- **file:** `apps/floor_planner/lib/parametric/dimension_tool.dart`; backup `t16-M-11degeneratepair.dimension_tool.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  252c252
  <     if ((p1 - p0).length <= wallJoin.linear) return true;
  ---
  >     return false;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_tool_test.dart --plain-name 'TL4 ')` (exit 1; log `t16-M-11degeneratepair-run1.log`)

  ```
  Expected: an object with length of <1>
    Actual: [Vector2:[12250.0,8250.0], Vector2:[12250.0,8250.0]]
     Which: has length of <2>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_tool_test.dart:626:7)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_tool_test.dart line 626
  00:02 +0 -1: TL4 Esc drops one or two pending points and places nothing, and Esc again returns to Select; a second click on the first point, or on the same wall end point 5 µm away, is ignored; Enter with points pending does nothing [E]
    The test description was: TL4 Esc drops one or two pending points and places nothing, and Esc again returns to Select; a second click on the first point, or on the same wall end point 5 µm away, is ignored; Enter with points pending does nothing
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_tool.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_tool.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:26:57Z.

#### M-11twosteps — the tool commits the node and the component as two commands (spec M-11twosteps; killers TL1)

- **file:** `apps/floor_planner/lib/parametric/dimension_tool.dart`; backup `t16-M-11twosteps.dimension_tool.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  299,307c299,305
  <         return CompoundCommand([
  <           AddNodeCommand(GroupNode(
  <               handle: h,
  <               parent: doc.rootHandle,
  <               transform: Transform2.identity(),
  <               children: const [])),
  <           SetComponentCommand<DimensionParams>(
  <               h, DimensionParams(a, b, kind, offset)),
  <         ], label: 'Add dimension');
  ---
  >         ctx.execute(AddNodeCommand(GroupNode(
  >             handle: h,
  >             parent: doc.rootHandle,
  >             transform: Transform2.identity(),
  >             children: const [])));
  >         return SetComponentCommand<DimensionParams>(
  >             h, DimensionParams(a, b, kind, offset));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_tool_test.dart --plain-name 'TL1 ')` (exit 1; log `t16-M-11twosteps-run1.log`)

  ```
  00:00 +0 -1: TL1 three clicks place one dimension in one undo step; ends on wall end points attach, others are fixed; the tool then waits for a new first click, at origin [E]
    Expected: <28>
      Actual: <29>
    test/dimension_tool_test.dart 289:7                 main.<fn>
  00:00 +0 -2: TL1 three clicks place one dimension in one undo step; ends on wall end points attach, others are fixed; the tool then waits for a new first click, at corpus far origin, 23 deg, own groups [E]
    test/dimension_tool_test.dart 289:7                 main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_tool.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_tool.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:27:02Z.

#### M-11key — I missing from `kShellLetterKeys` (spec M-11key; killers TL7)

- **file:** `apps/floor_planner/lib/shortcut_guard.dart`; backup `t16-M-11key.shortcut_guard.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  17d16
  <   LogicalKeyboardKey.keyI,
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_tool_test.dart --plain-name 'TL7 ')` (exit 1; log `t16-M-11key-run1.log`)

  ```
  Expected: false
    Actual: <true>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_tool_test.dart:868:5)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_tool_test.dart line 868
  00:02 +0 -1: TL7 I activates the Dimension tool from the canvas and the palette; typing I into a panel text field switches nothing [E]
    The test description was: TL7 I activates the Dimension tool from the canvas and the palette; typing I into a panel text field switches nothing
  00:03 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/shortcut_guard.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/shortcut_guard.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:27:09Z.

#### M-11snaponly — an end attaches only when an object snap won (the tool's candidate search gated on `hoverKind != null`, Ruling 11-6) (spec M-11snaponly; killers TL6)

Killer TL6 only (Ruling 11-6: AM4 cannot see "an object snap won").

- **file:** `apps/floor_planner/lib/parametric/dimension_tool.dart`; backup `t16-M-11snaponly.dimension_tool.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  289,290c289,290
  <         decideEnd(doc, _candidatesAt(ctx, at, t),
  <             kind: kind, at: at, other: other, m: m) ??
  ---
  >         (hoverKind != null ? decideEnd(doc, _candidatesAt(ctx, at, t),
  >             kind: kind, at: at, other: other, m: m) : null) ??
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_tool_test.dart --plain-name 'TL6 ')` (exit 1; log `t16-M-11snaponly-run1.log`)

  ```
  00:00 +0 -1: TL6 decision 23 through the tool: with F3 on a grid point on a corner attaches and a flush door's jamb snap attaches the stem's corner; with F3 off every end is fixed, at origin [E]
    Expected: AttachedEnd:<12/0/right>
      Actual: FixedEnd:<(12000.0, 8000.0)>
    test/dimension_tool_test.dart 788:9                 main.<fn>
  00:00 +0 -2: TL6 decision 23 through the tool: with F3 on a grid point on a corner attaches and a flush door's jamb snap attaches the stem's corner; with F3 off every end is fixed, at corpus far origin, 23 deg, own groups [E]
    test/dimension_tool_test.dart 788:9                 main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_tool.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_tool.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:27:14Z.

#### M-11notice — no status notice (spec M-11notice; killers TL5)

- **file:** `apps/floor_planner/lib/parametric/dimension_tool.dart`; backup `t16-M-11notice.dimension_tool.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  460d459
  <     if (!_disposed) _notice.value = l.text;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_tool_test.dart --plain-name 'TL5 ')` (exit 1; log `t16-M-11notice-run1.log`)

  ```
  00:00 +0 -1: TL5 the preview's five lines equal the committed children in world; the notice is the value; attach rings mark only attaching points; a repaint rebuilds nothing and Shift alone rebuilds once, at origin [E]
    Expected: '6.63'
      Actual: <null>
       Which: not an <Instance of 'String'>
    test/dimension_tool_test.dart 963:9                 main.<fn>
  00:00 +0 -2: TL5 the preview's five lines equal the committed children in world; the notice is the value; attach rings mark only attaching points; a repaint rebuilds nothing and Shift alone rebuilds once, at corpus far origin, 23 deg, own groups [E]
    test/dimension_tool_test.dart 963:9                 main.<fn>
  00:00 +0 -3: TL5 on a 1:100 ft-in page the preview and the notice are the committed dimension's; a page change heard off the canvas re-reads the notice; an unlayable hover previews nothing; a re-activated tool reads the document afresh; a neighbour edit, its undo and its redo each re-read the ring, at origin [E]
    test/dimension_tool_test.dart 1175:9                main.<fn>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_tool_test.dart:1392:9)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_tool_test.dart line 1392
  00:02 +0 -5: TL5 the status line reads Dimension — 4.69 over the Hall's corners, and clears after the commit and on a switch to Select [E]
  00:02 +0 -5: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_tool.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_tool.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:27:21Z.

#### M-11otherend — an end-grip drop re-decides the other end too (spec M-11otherend; killers GE3)

- **file:** `apps/floor_planner/lib/parametric/dimension_grips.dart`; backup `t16-M-11otherend.dimension_grips.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  250a251,259
  >     final re = decideEnd(
  >             d,
  >             attachCandidates(d, index, otherW,
  >                 objectSnap: objectSnap(), thickest: thickestWall(d)),
  >             kind: p.kind,
  >             at: otherW,
  >             other: w,
  >             m: s.m) ??
  >         other;
  252,253c261,262
  <         ? (params: p.copyWith(a: end), p0: w, p1: s.p1)
  <         : (params: p.copyWith(b: end), p0: s.p0, p1: w);
  ---
  >         ? (params: p.copyWith(a: end, b: re), p0: w, p1: s.p1)
  >         : (params: p.copyWith(b: end, a: re), p0: s.p0, p1: w);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_grips_test.dart --plain-name 'GE3 ')` (exit 1; log `t16-M-11otherend-run1.log`)

  ```
  00:00 +0 -1: GE3 an end grip attaches a fixed end, detaches an attached one, moves one to another wall's point, and never re-decides the other end, at origin [E]
    Expected: AttachedEnd:<16/1/left>
      Actual: AttachedEnd:<12/0/left>
    test/dimension_grips_test.dart 412:9                main.<fn>
  00:00 +0 -2: GE3 an end grip attaches a fixed end, detaches an attached one, moves one to another wall's point, and never re-decides the other end, at corpus far origin, 23 deg, own groups [E]
    test/dimension_grips_test.dart 412:9                main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_grips.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_grips.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:27:26Z.

#### M-11gripoffset — the offset grip stores the drop's distance from the first point (spec M-11gripoffset; killers GE2)

- **file:** `apps/floor_planner/lib/parametric/dimension_grips.dart`; backup `t16-M-11gripoffset.dimension_grips.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  235c235,236
  <       final o = offsetFor(q, s.p0, s.p1, p.kind, s.m);
  ---
  >       final u = measuringDirection(p.kind, s.p0, s.p1, s.m);
  >       final o = (q - s.p0).dot(Vector2(-u.y, u.x)) / s.m.scaleMagnitude;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_grips_test.dart --plain-name 'GE2 ')` (exit 1; log `t16-M-11gripoffset-run1.log`)

  ```
  00:00 +0 -1: GE2 the offset grip stores offsetFor of the drop with the current kind: outermost, between band, sign bit; one undo step; a drop that changes nothing returns null, at origin [E]
    Expected: a numeric value within <0.000001> of <800.0>
      Actual: <2000.0>
       Which:  differs by <1200.0>
    test/dimension_grips_test.dart 184:9                main.<fn>
  00:00 +0 -2: GE2 the offset grip stores offsetFor of the drop with the current kind: outermost, between band, sign bit; one undo step; a drop that changes nothing returns null, at corpus far origin, 23 deg, own groups [E]
    test/dimension_grips_test.dart 184:9                main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_grips.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_grips.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:27:31Z.

#### M-11gripplace — the offset grip at `Q0` instead of the line's midpoint (spec M-11gripplace; killers GE1)

- **file:** `apps/floor_planner/lib/parametric/dimension_grips.dart`; backup `t16-M-11gripplace.dimension_grips.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  104c104
  <     final mid = (s.layout.q0 + s.layout.q1) * 0.5;
  ---
  >     final mid = s.layout.q0;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_grips_test.dart --plain-name 'GE1 ')` (exit 1; log `t16-M-11gripplace-run1.log`)

  ```
  00:00 +0 -1: GE1 a dimension has three grips, at its line's midpoint and its two measured points, in world, under a turned group, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <1499.9999999999998>
       Which: is not a value less than <0.000001>
    test/dimension_grips_test.dart 72:5                 expectNear
    test/dimension_grips_test.dart 100:7                main.<fn>
  00:00 +0 -2: GE1 a dimension has three grips, at its line's midpoint and its two measured points, in world, under a turned group, at corpus far origin, 23 deg, own groups [E]
    test/dimension_grips_test.dart 72:5                 expectNear
    test/dimension_grips_test.dart 100:7                main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_grips.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_grips.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:27:36Z.

#### M-11runtime — the grips hit without `components` and `geometry`: `leafGripsLive` returns true (render layer, Ruling 11-25) (spec M-11runtime; killers GE4)

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; backup `t16-M-11runtime.grip_cache.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  273,274c273
  <   bool get leafGripsLive =>
  <       document.commands.permissions.allows(Capability.geometry);
  ---
  >   bool get leafGripsLive => true;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_grips_test.dart --plain-name 'GE4 ')` (exit 1; log `t16-M-11runtime-run1.log`)

  ```
  00:00 +0 -1: GE4 a degenerate drop returns null; under runtime permissions no grip is hit and no drag lands; a broken dimension has no grips, at origin [E]
    Expected: <-1>
      Actual: <0>
    test/dimension_grips_test.dart 502:9                main.<fn>
  00:00 +0 -2: GE4 a degenerate drop returns null; under runtime permissions no grip is hit and no drag lands; a broken dimension has no grips, at corpus far origin, 23 deg, own groups [E]
    test/dimension_grips_test.dart 502:9                main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; `diff` exit 0; `git diff --quiet -- packages/jet_cad_2d_flutter/lib/src/grip_cache.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:27:41Z.

#### M-11previewkind — a grip preview laid out as aligned whatever the kind (spec M-11previewkind; killers GE5)

- **file:** `apps/floor_planner/lib/parametric/dimension_grips.dart`; backup `t16-M-11previewkind.dimension_grips.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  134c134
  <         layoutDimension(next.p0, next.p1, p.kind, s.m, p.offset, _pageOf(d));
  ---
  >         layoutDimension(next.p0, next.p1, DimKind.aligned, s.m, p.offset, _pageOf(d));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_grips_test.dart --plain-name 'GE5 ')` (exit 1; log `t16-M-11previewkind-run1.log`)

  ```
  00:00 +0 -1: GE5 the preview equals the committed lines on a horizontal dimension over the non-axis pair, for an offset drag and an end drag, on a 1:50 mm page and a 1:100 ft-in page; after another dimension's drag abandoned the preview equals a fresh provider's, at origin [E]
    Expected: a value less than <1e-9>
      Actual: <1291.8880488418279>
       Which: is not a value less than <1e-9>
    test/dimension_grips_test.dart 72:5                 expectNear
    test/dimension_grips_test.dart 571:13               main.<fn>
  00:00 +0 -2: GE5 the preview equals the committed lines on a horizontal dimension over the non-axis pair, for an offset drag and an end drag, on a 1:50 mm page and a 1:100 ft-in page; after another dimension's drag abandoned the preview equals a fresh provider's, at corpus far origin, 23 deg, own groups [E]
    test/dimension_grips_test.dart 72:5                 expectNear
    test/dimension_grips_test.dart 571:13               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_grips.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_grips.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:27:45Z.

#### M-11kindoffset — a kind switch resets the offset to zero (spec M-11kindoffset; killers PN2)

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t16-M-11kindoffset.selection_panel.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  566c566
  <     final next = p.copyWith(kind: kind);
  ---
  >     final next = p.copyWith(kind: kind, offset: 0.0);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_panel_test.dart --plain-name 'PN2 ')` (exit 1; log `t16-M-11kindoffset-run1.log`)

  ```
  Expected: <-617.375>
    Actual: <0.0>
  Horizontal: the offset kept
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart:225:7)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart line 225
  00:02 +0 -1: PN2 a kind click is one undo step that keeps the ends and the offset; switching back restores the children bit for bit; the current kind issues nothing, at origin [E]
    The test description was: PN2 a kind click is one undo step that keeps the ends and the offset; switching back restores the children bit for bit; the current kind issues nothing, at origin
  Expected: <-617.375>
    Actual: <0.0>
  Horizontal: the offset kept
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart:225:7)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart line 225
  00:03 +0 -2: PN2 a kind click is one undo step that keeps the ends and the offset; switching back restores the children bit for bit; the current kind issues nothing, at corpus far origin, 23 deg, own groups [E]
  00:03 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/selection_panel.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:27:53Z.

#### M-11sectionmulti — the section shown with two dimensions selected (spec M-11sectionmulti; killers PN1)

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t16-M-11sectionmulti.selection_panel.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  334c334
  <   Handle? get _dimension => _selected<DimensionParams>();
  ---
  >   Handle? get _dimension => [for (final k in widget.selection.keys) if (k.chain.isEmpty && _isObject<DimensionParams>(k.target)) k.target].firstOrNull;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_panel_test.dart --plain-name 'PN1 ')` (exit 1; log `t16-M-11sectionmulti-run1.log`)

  ```
  Expected: no matching candidates
    Actual: _KeyWidgetFinder:<Found 1 widget with key [<'dimension-section'>]: [
     Which: means one was found but none were expected
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart:161:7)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart line 161
  00:02 +0 -1: PN1 the Dimension section shows for exactly one dimension, its value as its text reads, at origin [E]
    The test description was: PN1 the Dimension section shows for exactly one dimension, its value as its text reads, at origin
  Expected: no matching candidates
    Actual: _KeyWidgetFinder:<Found 1 widget with key [<'dimension-section'>]: [
     Which: means one was found but none were expected
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart:161:7)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart line 161
  00:03 +0 -2: PN1 the Dimension section shows for exactly one dimension, its value as its text reads, at corpus far origin, 23 deg, own groups [E]
  00:03 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/selection_panel.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:28:01Z.

#### M-11axesline — the axes line never shown (spec M-11axesline; killers PN3)

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t16-M-11axesline.selection_panel.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  641c641
  <       if (axes != null) ...[
  ---
  >       if (axes != null && axes == '') ...[
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_panel_test.dart --plain-name 'PN3 ')` (exit 1; log `t16-M-11axesline-run1.log`)

  ```
  Bad state: No element
  #2      textAt (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart:42:12)
  #3      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart:329:18)
  00:02 +0 -1: PN3 a linear dimension turned shows Axes turned by the rounded angle; aligned and unturned show none; 0.04° and −0.04° show none, 0.06° shows 0.1°, at origin [E]
    The test description was: PN3 a linear dimension turned shows Axes turned by the rounded angle; aligned and unturned show none; 0.04° and −0.04° show none, 0.06° shows 0.1°, at origin
  Bad state: No element
  #2      textAt (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart:42:12)
  #3      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart:329:18)
  00:03 +0 -2: PN3 a linear dimension turned shows Axes turned by the rounded angle; aligned and unturned show none; 0.04° and −0.04° show none, 0.06° shows 0.1°, at corpus far origin, 23 deg, own groups [E]
  00:03 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/selection_panel.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:28:08Z.

#### M-11endlabel — the end lines print `k` swapped (start for end) (spec M-11endlabel; killers PN4)

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t16-M-11endlabel.selection_panel.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  601c601
  <           'Wall ${wall.toHex()}, ${k == 0 ? 'start' : 'end'}, '
  ---
  >           'Wall ${wall.toHex()}, ${k == 0 ? 'end' : 'start'}, '
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_panel_test.dart --plain-name 'PN4 ')` (exit 1; log `t16-M-11endlabel-run1.log`)

  ```
  Expected: 'Wall 3E, end, right face'
    Actual: 'Wall 3E, start, right face'
     Which: is different.
            Expected: Wall 3E, end, right ...
              Actual: Wall 3E, start, rig ...
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart:365:7)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart line 365
  00:02 +0 -1: PN4 the end lines read Wall <hex>, start or end, left face, centreline or right face, or Fixed, at origin [E]
    The test description was: PN4 the end lines read Wall <hex>, start or end, left face, centreline or right face, or Fixed, at origin
  Expected: 'Wall 3E, end, right face'
    Actual: 'Wall 3E, start, right face'
     Which: is different.
            Expected: Wall 3E, end, right ...
              Actual: Wall 3E, start, rig ...
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart:365:7)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart line 365
  00:03 +0 -2: PN4 the end lines read Wall <hex>, start or end, left face, centreline or right face, or Fixed, at corpus far origin, 23 deg, own groups [E]
  00:03 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/selection_panel.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:28:16Z.

#### M-11panelrw-a — form a: the kind switch enabled under runtime permissions (`onSelectionChanged` always set) (spec M-11panelrw; killers PN5)

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t16-M-11panelrw-a.selection_panel.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  639c639
  <         onSelectionChanged: editable ? (s) => _setKind(dim, s.single) : null,
  ---
  >         onSelectionChanged: (s) => _setKind(dim, s.single),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_panel_test.dart --plain-name 'PN5 ')` (exit 1; log `t16-M-11panelrw-a-run1.log`)

  ```
  Expected: null
    Actual: <Closure: (Set<DimKind>) => void>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart:412:9)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart line 412
  00:02 +0 -1: PN5 under runtime permissions the switch is read-only; a refused edit leaves the switch on the model's kind, at origin [E]
    The test description was: PN5 under runtime permissions the switch is read-only; a refused edit leaves the switch on the model's kind, at origin
  Expected: null
    Actual: <Closure: (Set<DimKind>) => void>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart:412:9)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart line 412
  00:03 +0 -2: PN5 under runtime permissions the switch is read-only; a refused edit leaves the switch on the model's kind, at corpus far origin, 23 deg, own groups [E]
  00:03 +1 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/selection_panel.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:28:24Z.

#### M-11panelrw-b — form b: `_setKind`'s own `_dimensionEditable` check removed (a stale callback) (spec M-11panelrw; killers PN5)

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t16-M-11panelrw-b.selection_panel.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  564c564
  <     if (!_dimensionEditable || !_isObject<DimensionParams>(target)) return;
  ---
  >     if (!_isObject<DimensionParams>(target)) return;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_panel_test.dart --plain-name 'PN5 ')` (exit 1; log `t16-M-11panelrw-b-run1.log`)

  ```
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart:431:12)
  00:03 +0 -1: PN5 under runtime permissions the switch is read-only; a refused edit leaves the switch on the model's kind, at origin [E]
    The test description was: PN5 under runtime permissions the switch is read-only; a refused edit leaves the switch on the model's kind, at origin
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_panel_test.dart:431:12)
  00:04 +0 -2: PN5 under runtime permissions the switch is read-only; a refused edit leaves the switch on the model's kind, at corpus far origin, 23 deg, own groups [E]
  00:04 +1 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/selection_panel.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:28:32Z.

#### M-11axisworld — linear axes in world, not the group's (spec M-11axisworld; killers DR1, DR3, DR4)

DZ1 dropped from the killer list (Task 8 ruling Minor 3: its oracle shares measuringDirection).

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11axisworld.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  195c195
  <       return m.transformDirection(Vector2(1, 0)).normalized();
  ---
  >       return Vector2(1, 0);
  197c197
  <       return m.transformDirection(Vector2(0, 1)).normalized();
  ---
  >       return Vector2(0, 1);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_rotate_test.dart --plain-name 'DR1 ')` (exit 1; log `t16-M-11axisworld-run1.log`)

  ```
  00:00 +0 -1: DR1 a fixed-fixed pair turned 30° keeps 3000 horizontal and 3231 aligned, its line at the placement's angle plus 30°, at origin [E]
    Expected: ['3000', '1200', '3231']
      Actual: ['1998', '2539', '3231']
       Which: at location [0] is '1998' instead of '3000'
    test/dimension_rotate_test.dart 118:7               main.<fn>
  00:00 +0 -2: DR1 a fixed-fixed pair turned 30° keeps 3000 horizontal and 3231 aligned, its line at the placement's angle plus 30°, at corpus far origin, 23 deg [E]
    test/dimension_rotate_test.dart 105:7               main.<fn>
  00:00 +0 -3: DR1 a fixed-fixed pair turned 30° keeps 3000 horizontal and 3231 aligned, its line at the placement's angle plus 30°, at corpus far origin, 23 deg, own groups [E]
    test/dimension_rotate_test.dart 105:7               main.<fn>
  00:00 +0 -4: DR1 a fixed-fixed pair turned 30° keeps 3000 horizontal and 3231 aligned, its line at the placement's angle plus 30°, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_rotate_test.dart 105:7               main.<fn>
  00:00 +0 -5: DR1 a fixed-fixed pair turned 30° keeps 3000 horizontal and 3231 aligned, its line at the placement's angle plus 30°, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_rotate_test.dart 118:7               main.<fn>
  00:00 +0 -6: DR1 a fixed-fixed pair turned 30° keeps 3000 horizontal and 3231 aligned, its line at the placement's angle plus 30°, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_rotate_test.dart 105:7               main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_rotate_test.dart --plain-name 'DR3 ')` (exit 1; log `t16-M-11axisworld-run2.log`)

  ```
  00:00 +0 -1: DR3 walls and dimensions turned together keep every value, at origin [E]
    Expected: ['4100', '3100', '3764']
      Actual: ['3551', '2685', '3764']
       Which: at location [0] is '3551' instead of '4100'
    test/dimension_rotate_test.dart 287:7               main.<fn>
  00:00 +0 -2: DR3 walls and dimensions turned together keep every value, at corpus far origin, 23 deg, own groups [E]
    test/dimension_rotate_test.dart 272:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_rotate_test.dart --plain-name 'DR4 ')` (exit 1; log `t16-M-11axisworld-run3.log`)

  ```
  00:00 +0 -1: DR4 a both-ends-attached linear dimension turned alone turns its axis: 4000 reads 3464, at origin [E]
    Expected: '3464'
      Actual: '4000'
       Which: is different.
              Expected: 3464
                Actual: 4000
    test/dimension_rotate_test.dart 334:7               main.<fn>
  00:00 +0 -2: DR4 a both-ends-attached linear dimension turned alone turns its axis: 4000 reads 3464, at corpus far origin, 23 deg, own groups [E]
    test/dimension_rotate_test.dart 322:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (3 of 3 commands red). Fired at `5ddd96f`, 2026-09-29T11:28:46Z.

#### M-11fixedworld — fixed ends ignore the group transform (site 1: `endPointInView`) (spec M-11fixedworld; killers DR2, DZ1)

- **file:** `apps/floor_planner/lib/parametric/dimension.dart`; backup `t16-M-11fixedworld.dimension.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  119c119
  <       return view.toWorld(self).transformPoint(end.point);
  ---
  >       return end.point;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_rotate_test.dart --plain-name 'DR2 ')` (exit 1; log `t16-M-11fixedworld-run1.log`)

  ```
  00:00 +0 -1: DR2 an attached end stays with its wall while a fixed end moves and turns with the group, at origin [E]
    Expected: '3000'
      Actual: '1768'
       Which: is different.
              Expected: 3000
                Actual: 1768
    test/dimension_rotate_test.dart 182:7               main.<fn>
  00:00 +0 -2: DR2 an attached end stays with its wall while a fixed end moves and turns with the group, at corpus far origin, 23 deg, own groups [E]
    test/dimension_rotate_test.dart 182:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_fuzz_test.dart --plain-name 'DZ1 ')` (exit 1; log `t16-M-11fixedworld-run2.log`)

  ```
  00:00 +0 -1: DZ1 300 seeded edits keep every dimension equal to the all-walls oracle, with neighbour-only rebuilds; a reload agrees [E]
    Expected: empty
      Actual: [
    test/dimension_fuzz_test.dart 314:5                 main.<fn>
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:28:54Z.

#### M-11fixedworld-grips — fixed ends ignore the group transform (site 2: `DimensionGrips._pointOf`) (spec M-11fixedworld; killers GE1, GE2, GE3, GE4, GE5)

Second site found at Task 13 (ledger); fired against every GE test.

- **file:** `apps/floor_planner/lib/parametric/dimension_grips.dart`; backup `t16-M-11fixedworld-grips.dimension_grips.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  207c207
  <         return m.transformPoint(end.point);
  ---
  >         return end.point;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_grips_test.dart --plain-name 'GE1 ')` (exit 1; log `t16-M-11fixedworld-grips-run1.log`)

  ```
  00:00 +0 -1: GE1 a dimension has three grips, at its line's midpoint and its two measured points, in world, under a turned group, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <1789.4434228340986>
       Which: is not a value less than <0.000001>
    test/dimension_grips_test.dart 72:5                 expectNear
    test/dimension_grips_test.dart 100:7                main.<fn>
  00:00 +0 -2: GE1 a dimension has three grips, at its line's midpoint and its two measured points, in world, under a turned group, at corpus far origin, 23 deg, own groups [E]
    test/dimension_grips_test.dart 72:5                 expectNear
    test/dimension_grips_test.dart 100:7                main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_grips_test.dart --plain-name 'GE2 ')` (exit 1; log `t16-M-11fixedworld-grips-run2.log`)

  ```
  00:00 +0 -1: GE2 the offset grip stores offsetFor of the drop with the current kind: outermost, between band, sign bit; one undo step; a drop that changes nothing returns null, at origin [E]
    Expected: a numeric value within <0.000001> of <800.0>
      Actual: <2000.0>
       Which:  differs by <1200.0>
    test/dimension_grips_test.dart 184:9                main.<fn>
  00:00 +0 -2: GE2 the offset grip stores offsetFor of the drop with the current kind: outermost, between band, sign bit; one undo step; a drop that changes nothing returns null, at corpus far origin, 23 deg, own groups [E]
    test/dimension_grips_test.dart 184:9                main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_grips_test.dart --plain-name 'GE3 ')` (exit 1; log `t16-M-11fixedworld-grips-run3.log`)

  ```
  00:00 +1 -1: GE3 an end grip attaches a fixed end, detaches an attached one, moves one to another wall's point, and never re-decides the other end, at corpus far origin, 23 deg, own groups [E]
    Expected: AttachedEnd:<12/0/right>
      Actual: AttachedEnd:<16/1/right>
    test/dimension_grips_test.dart 381:11               main.<fn>
  00:00 +1 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_grips_test.dart --plain-name 'GE4 ')` (exit 1; log `t16-M-11fixedworld-grips-run4.log`)

  ```
  00:00 +0 -1: GE4 a degenerate drop returns null; under runtime permissions no grip is hit and no drag lands; a broken dimension has no grips, at origin [E]
    Expected: null
      Actual: <Instance of 'SetComponentCommand<DimensionParams>'>
    test/dimension_grips_test.dart 455:11               main.<fn>
  00:00 +0 -2: GE4 a degenerate drop returns null; under runtime permissions no grip is hit and no drag lands; a broken dimension has no grips, at corpus far origin, 23 deg, own groups [E]
    test/dimension_grips_test.dart 455:11               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_grips_test.dart --plain-name 'GE5 ')` (exit 1; log `t16-M-11fixedworld-grips-run5.log`)

  ```
  00:00 +0 -1: GE5 the preview equals the committed lines on a horizontal dimension over the non-axis pair, for an offset drag and an end drag, on a 1:50 mm page and a 1:100 ft-in page; after another dimension's drag abandoned the preview equals a fresh provider's, at origin [E]
    Expected: a value less than <1e-9>
      Actual: <1200.0000000000011>
       Which: is not a value less than <1e-9>
    test/dimension_grips_test.dart 72:5                 expectNear
    test/dimension_grips_test.dart 571:13               main.<fn>
  00:00 +0 -2: GE5 the preview equals the committed lines on a horizontal dimension over the non-axis pair, for an offset drag and an end drag, on a 1:50 mm page and a 1:100 ft-in page; after another dimension's drag abandoned the preview equals a fresh provider's, at corpus far origin, 23 deg, own groups [E]
    test/dimension_grips_test.dart 72:5                 expectNear
    test/dimension_grips_test.dart 571:13               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_grips.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_grips.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (5 of 5 commands red). Fired at `5ddd96f`, 2026-09-29T11:29:15Z.

#### M-11attachedmoves — attached ends moved by the group transform (site 1: `endPointInView`) (spec M-11attachedmoves; killers DR2, DR4)

- **file:** `apps/floor_planner/lib/parametric/dimension.dart`; backup `t16-M-11attachedmoves.dimension.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  124c124
  <       return wallEndPoint(w.host, w.walls, k, side);
  ---
  >       return view.toWorld(self).transformPoint(wallEndPoint(w.host, w.walls, k, side));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_rotate_test.dart --plain-name 'DR2 ')` (exit 1; log `t16-M-11attachedmoves-run1.log`)

  ```
  00:00 +0 -1: DR2 an attached end stays with its wall while a fixed end moves and turns with the group, at origin [E]
    Expected: '3000'
      Actual: '1768'
       Which: is different.
              Expected: 3000
                Actual: 1768
    test/dimension_rotate_test.dart 182:7               main.<fn>
  00:00 +0 -2: DR2 an attached end stays with its wall while a fixed end moves and turns with the group, at corpus far origin, 23 deg, own groups [E]
    test/dimension_rotate_test.dart 182:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_rotate_test.dart --plain-name 'DR4 ')` (exit 1; log `t16-M-11attachedmoves-run2.log`)

  ```
  00:00 +0 -1: DR4 a both-ends-attached linear dimension turned alone turns its axis: 4000 reads 3464, at origin [E]
    Expected: '3464'
      Actual: '4000'
       Which: is different.
              Expected: 3464
                Actual: 4000
    test/dimension_rotate_test.dart 334:7               main.<fn>
  00:00 +0 -2: DR4 a both-ends-attached linear dimension turned alone turns its axis: 4000 reads 3464, at corpus far origin, 23 deg, own groups [E]
    test/dimension_rotate_test.dart 322:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:29:23Z.

#### M-11attachedmoves-grips — attached ends moved by the group transform (site 2: `DimensionGrips._pointOf`) (spec M-11attachedmoves; killers GE1, GE2, GE3, GE4, GE5)

Second site found at Task 13 (ledger); fired against every GE test.

- **file:** `apps/floor_planner/lib/parametric/dimension_grips.dart`; backup `t16-M-11attachedmoves-grips.dimension_grips.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  211c211,212
  <         if (memo != null) return _find(memo, k, side);
  ---
  >         Vector2? mv(Vector2? p) => p == null ? null : m.transformPoint(p);
  >         if (memo != null) return mv(_find(memo, k, side));
  214c215
  <         if (points == null) return wallEndPoint(ws.host, ws.walls, k, side);
  ---
  >         if (points == null) return mv(wallEndPoint(ws.host, ws.walls, k, side));
  216c217
  <         return _find(six, k, side);
  ---
  >         return mv(_find(six, k, side));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_grips_test.dart --plain-name 'GE1 ')` (exit 1; log `t16-M-11attachedmoves-grips-run1.log`)

  ```
  00:00 +0 -1: GE1 a dimension has three grips, at its line's midpoint and its two measured points, in world, under a turned group, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <950.1909013038237>
       Which: is not a value less than <0.000001>
    test/dimension_grips_test.dart 72:5                 expectNear
    test/dimension_grips_test.dart 128:7                main.<fn>
  00:00 +0 -2: GE1 a dimension has three grips, at its line's midpoint and its two measured points, in world, under a turned group, at corpus far origin, 23 deg, own groups [E]
    test/dimension_grips_test.dart 72:5                 expectNear
    test/dimension_grips_test.dart 128:7                main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_grips_test.dart --plain-name 'GE2 ')` (exit 0; log `t16-M-11attachedmoves-grips-run2.log`)

  ```
  00:00 +2: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_grips_test.dart --plain-name 'GE3 ')` (exit 0; log `t16-M-11attachedmoves-grips-run3.log`)

  ```
  00:00 +2: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_grips_test.dart --plain-name 'GE4 ')` (exit 1; log `t16-M-11attachedmoves-grips-run4.log`)

  ```
  00:00 +0 -1: GE4 a degenerate drop returns null; under runtime permissions no grip is hit and no drag lands; a broken dimension has no grips, at origin [E]
    Expected: null
      Actual: <Instance of 'SetComponentCommand<DimensionParams>'>
    test/dimension_grips_test.dart 455:11               main.<fn>
  00:00 +0 -2: GE4 a degenerate drop returns null; under runtime permissions no grip is hit and no drag lands; a broken dimension has no grips, at corpus far origin, 23 deg, own groups [E]
    test/dimension_grips_test.dart 455:11               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_grips_test.dart --plain-name 'GE5 ')` (exit 0; log `t16-M-11attachedmoves-grips-run5.log`)

  ```
  00:00 +2: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_grips.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_grips.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 5 commands red); green: GE2, GE3, GE5. Fired at `5ddd96f`, 2026-09-29T11:29:44Z.

#### M-11scale — the offset not multiplied by the group's scale (spec M-11scale; killers DR5)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11scale.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  369c369
  <   final c = (below ? lo : hi) + offset * m.scaleMagnitude;
  ---
  >   final c = (below ? lo : hi) + offset;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_rotate_test.dart --plain-name 'DR5 ')` (exit 1; log `t16-M-11scale-run1.log`)

  ```
  00:00 +0 -1: DR5 under a turned, translated group scaled 1.5 the world offset is 1.5 times the stored one and the text is 125 world mm tall, at the corpus far origin [E]
    Expected: a numeric value within <0.000001> of <900.75>
      Actual: <600.5000000000014>
       Which:  differs by <300.24999999999864>
    test/dimension_rotate_test.dart 424:7               main.<fn>.expectScaled
    test/dimension_rotate_test.dart 451:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:29:49Z.

#### M-11movable — dimensions immovable by the select tool (spec M-11movable; killers SL1)

- **file:** `apps/floor_planner/lib/parametric/dimension_grips.dart`; backup `t16-M-11movable.dimension_grips.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  143c143
  <   bool movable(DraftDocument d, Handle group) => true;
  ---
  >   bool movable(DraftDocument d, Handle group) => false;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_shell_test.dart --plain-name 'SL1 ')` (exit 1; log `t16-M-11movable-run1.log`)

  ```
  Expected: <1>
    Actual: <0>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_shell_test.dart:335:7)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_shell_test.dart line 335
  00:04 +0 -1: SL1 through the select tool on the sample plan: a click on a dimension line selects it; a click on E4's face under the Hall's extension line selects E4; a window band around the Hall's line, slashes and text selects it; dimensions move and turn by their fixed ends only; deleting E1 deletes three dimensions in one st [cut; the full line is in the log]
    The test description was: SL1 through the select tool on the sample plan: a click on a dimension line selects it; a click on E4's face under the Hall's extension line selects E4; a window band around the Hall's line, slashes and text selects it; dimensions move and turn by their fixed ends only; deleting E1 deletes three dimen [cut; the full line is in the log]
  00:04 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_grips.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_grips.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:29:58Z.

#### M-11b-cam — the camera half: the painter's TEXT held at its 0.15 px/mm cap height at every zoom (render layer, Ruling 11-16) (spec M-11b-cam; killers RR1)

- **file:** `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`; backup `t16-M-11b-cam.draft_painter.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  959a960,964
  >     // M-11b-cam: a uniform scale about the insertion point that holds the
  >     // on-screen cap height at its 0.15 px/mm size at every zoom.
  >     final camK = 0.15 / chain.scaleMagnitude;
  >     final camX = payload.coords[0] - localOrigin.x;
  >     final camY = payload.coords[1] - localOrigin.y;
  962,963c967,971
  <           chain.multiply(Transform2(
  <               layout.a, layout.b, layout.c, layout.d, layout.e, layout.f)),
  ---
  >           chain
  >               .multiply(Transform2(
  >                   camK, 0, 0, camK, camX * (1 - camK), camY * (1 - camK)))
  >               .multiply(Transform2(
  >                   layout.a, layout.b, layout.c, layout.d, layout.e, layout.f)),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_paint_test.dart --plain-name 'RR1 ')` (exit 1; log `t16-M-11b-cam-run1.log`)

  ```
  Expected: a numeric value within <6.666666666666667> of <228.57142857142858>
    Actual: <144.99999999999994>
     Which:  differs by <83.57142857142864>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_paint_test.dart:287:9)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_paint_test.dart line 287
  00:02 +0 -1: RR1 the dimension text is the same world height at 0.15 and 0.3 px/mm and doubles at 1:100; a slash inks; the extension line inks from its gap [E]
    The test description was: RR1 the dimension text is the same world height at 0.15 and 0.3 px/mm and doubles at 1:100; a slash inks; the extension line inks from its gap
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`; `diff` exit 0; `git diff --quiet -- packages/jet_cad_2d_flutter/lib/src/draft_painter.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:30:06Z.


### Re-fires after this task's test fixes

Fired on the working tree whose test edits were then committed unchanged as
`7b55f12` (RR1) and `b3ef430` (DO3); `git rev-parse` still read `5ddd96f`,
which is what each entry's "Fired at" prints.

#### M-11negzero-f1@after-DO3 — form 1: the offset compared with `==` (the zero's sign lost) (spec M-11negzero; killers DO3, DP1)

Re-fired after DO3 gained the +0.0-twin check (this task's survivor fix).

- **file:** `apps/floor_planner/lib/parametric/dimension.dart`; backup `t16-M-11negzero-f1@after-DO3.dimension.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  89c89
  <       other.offset.compareTo(offset) == 0;
  ---
  >       other.offset == offset;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_object_test.dart --plain-name 'DO3 ')` (exit 1; log `t16-M-11negzero-f1@after-DO3-run1.log`)

  ```
  00:00 +0 -1: DO3 save, load and save is byte-identical, with references intact, drift() empty after the load, and a -0.0 offset kept, at origin [E]
    Expected: false
      Actual: <true>
    test/dimension_object_test.dart 288:7               main.<fn>
  00:00 +0 -2: DO3 save, load and save is byte-identical, with references intact, drift() empty after the load, and a -0.0 offset kept, at corpus far origin, 23 deg, own groups [E]
    test/dimension_object_test.dart 288:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_params_test.dart --plain-name 'DP1 ')` (exit 1; log `t16-M-11negzero-f1@after-DO3-run2.log`)

  ```
  00:00 +0 -1: DP1 DimensionParams round-trips with its keys in order and both end shapes; == is exact and tells -0.0 from +0.0, kept through save, load and save; references are deduplicated, at origin [E]
    Expected: false
      Actual: <true>
    test/dimension_params_test.dart 83:7                main.<fn>
  00:00 +0 -2: DP1 DimensionParams round-trips with its keys in order and both end shapes; == is exact and tells -0.0 from +0.0, kept through save, load and save; references are deduplicated, at corpus far origin, 23 deg, own groups [E]
    test/dimension_params_test.dart 83:7                main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `5ddd96f`, 2026-09-29T11:42:26Z.

#### M-11negzero-f2@after-DO3 — form 2: `toJson` writing `offset.abs()` (spec M-11negzero; killers DO3)

Re-fired after the DO3 edit: form 2 must stay red.

- **file:** `apps/floor_planner/lib/parametric/dimension.dart`; backup `t16-M-11negzero-f2@after-DO3.dimension.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  59c59
  <         'offset': offset,
  ---
  >         'offset': offset.abs(),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_object_test.dart --plain-name 'DO3 ')` (exit 1; log `t16-M-11negzero-f2@after-DO3-run1.log`)

  ```
  00:00 +0 -1: DO3 save, load and save is byte-identical, with references intact, drift() empty after the load, and a -0.0 offset kept, at origin [E]
    Expected: empty
      Actual: [26, 40]
    test/dimension_object_test.dart 276:7               main.<fn>
  00:00 +0 -2: DO3 save, load and save is byte-identical, with references intact, drift() empty after the load, and a -0.0 offset kept, at corpus far origin, 23 deg, own groups [E]
    test/dimension_object_test.dart 276:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:42:31Z.

#### M-11b-cam@after-RR1 — the camera half: the painter's TEXT held at its 0.15 px/mm cap height at every zoom (render layer, Ruling 11-16) (spec M-11b-cam; killers RR1)

Re-fired after RR1's text band took three device pixels (carried item, Task 15 Minor 1): must stay red.

- **file:** `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`; backup `t16-M-11b-cam@after-RR1.draft_painter.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  959a960,964
  >     // M-11b-cam: a uniform scale about the insertion point that holds the
  >     // on-screen cap height at its 0.15 px/mm size at every zoom.
  >     final camK = 0.15 / chain.scaleMagnitude;
  >     final camX = payload.coords[0] - localOrigin.x;
  >     final camY = payload.coords[1] - localOrigin.y;
  962,963c967,971
  <           chain.multiply(Transform2(
  <               layout.a, layout.b, layout.c, layout.d, layout.e, layout.f)),
  ---
  >           chain
  >               .multiply(Transform2(
  >                   camK, 0, 0, camK, camX * (1 - camK), camY * (1 - camK)))
  >               .multiply(Transform2(
  >                   layout.a, layout.b, layout.c, layout.d, layout.e, layout.f)),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_paint_test.dart --plain-name 'RR1 ')` (exit 1; log `t16-M-11b-cam@after-RR1-run1.log`)

  ```
  Expected: a numeric value within <10.0> of <228.57142857142858>
    Actual: <144.99999999999994>
     Which:  differs by <83.57142857142864>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_paint_test.dart:295:9)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_paint_test.dart line 295
  00:02 +0 -1: RR1 the dimension text is the same world height at 0.15 and 0.3 px/mm and doubles at 1:100; a slash inks; the extension line inks from its gap [E]
    The test description was: RR1 the dimension text is the same world height at 0.15 and 0.3 px/mm and doubles at 1:100; a slash inks; the extension line inks from its gap
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`; `diff` exit 0; `git diff --quiet -- packages/jet_cad_2d_flutter/lib/src/draft_painter.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:43:34Z.

#### M-11b@after-RR1 — the paper half: the text height not multiplied by the page's scale (spec M-11b; killers RR1)

Re-fired after RR1's text band took three device pixels (carried item, Task 15 Minor 1): must stay red.

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-M-11b@after-RR1.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  392c392
  <   final textHeight = kDimTextPaperMm * scale;
  ---
  >   final textHeight = kDimTextPaperMm;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_paint_test.dart --plain-name 'RR1 ')` (exit 1; log `t16-M-11b@after-RR1-run1.log`)

  ```
  Expected: not null
    Actual: <null>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_paint_test.dart:270:9)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_paint_test.dart line 270
  00:02 +0 -1: RR1 the dimension text is the same world height at 0.15 and 0.3 px/mm and doubles at 1:100; a slash inks; the extension line inks from its gap [E]
    The test description was: RR1 the dimension text is the same world height at 0.15 and 0.3 px/mm and doubles at 1:100; a slash inks; the extension line inks from its gap
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:43:41Z.

#### rv15-textGap12@after-RR1 — the text gap 1.2 paper mm instead of 1.0 (the Task 15 reviewer's) (spec rv15-textGap12; killers RR1)

Re-fired after RR1's text band took three device pixels (carried item, Task 15 Minor 1): must stay red.

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-rv15-textGap12@after-RR1.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  387c387
  <   final textAt = p0 + ((r0 + r1) * 0.5 + nr * (kDimTextGapPaperMm * scale));
  ---
  >   final textAt = p0 + ((r0 + r1) * 0.5 + nr * (1.2 * scale));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_paint_test.dart --plain-name 'RR1 ')` (exit 1; log `t16-rv15-textGap12@after-RR1-run1.log`)

  ```
  Expected: a numeric value within <10.0> of <228.57142857142858>
    Actual: <241.66666666666686>
     Which:  differs by <13.095238095238273>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_paint_test.dart:295:9)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_paint_test.dart line 295
  00:02 +0 -1: RR1 the dimension text is the same world height at 0.15 and 0.3 px/mm and doubles at 1:100; a slash inks; the extension line inks from its gap [E]
    The test description was: RR1 the dimension text is the same world height at 0.15 and 0.3 px/mm and doubles at 1:100; a slash inks; the extension line inks from its gap
  00:03 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:43:48Z.

#### rv15-textH23@after-RR1 — the cap height 2.3 paper mm instead of 2.5 (the Task 15 reviewer's) (spec rv15-textH23; killers RR1)

Re-fired after RR1's text band took three device pixels (carried item, Task 15 Minor 1): must stay red.

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-rv15-textH23@after-RR1.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  392c392
  <   final textHeight = kDimTextPaperMm * scale;
  ---
  >   final textHeight = 2.3 * scale;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_paint_test.dart --plain-name 'RR1 ')` (exit 1; log `t16-rv15-textH23@after-RR1-run1.log`)

  ```
  Expected: a numeric value within <10.0> of <228.57142857142858>
    Actual: <215.0000000000001>
     Which:  differs by <13.57142857142847>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_paint_test.dart:295:9)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/dimension_paint_test.dart line 295
  00:02 +0 -1: RR1 the dimension text is the same world height at 0.15 and 0.3 px/mm and doubles at 1:100; a slash inks; the extension line inks from its gap [E]
    The test description was: RR1 the dimension text is the same world height at 0.15 and 0.3 px/mm and doubles at 1:100; a slash inks; the extension line inks from its gap
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:43:55Z.


### SL1 per clause (the scratch split, never committed)

#### M-11pickflag@split — `picking()` ignores the not-pickable flag — on the scratch per-clause split of SL1 (t16_sl1_split_test.dart, never committed) (spec M-11pickflag; killers SL1 (split))

Every SL1 clause as its own test, so a later clause is not hidden behind the first failure.

- **file:** `packages/jet_cad_2d/lib/src/index/query_filter.dart`; backup `t16-M-11pickflag@split.query_filter.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  39c39
  <         excludeUnpickable = true;
  ---
  >         excludeUnpickable = false;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/t16_sl1_split_test.dart --plain-name 'SL1 split')` (exit 1; log `t16-M-11pickflag@split-run1.log`)

  ```
  Expected: [SelectionKey:SelectionKey( 1E)]
    Actual: Set:[SelectionKey:SelectionKey( 286)]
     Which: at location [0] is SelectionKey:<SelectionKey( 286)> instead of
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/t16_sl1_split_test.dart:253:7)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/t16_sl1_split_test.dart line 253
  00:04 +1 -1: SL1 split click-e4 [E]
    The test description was: SL1 split click-e4
  Expected: [SelectionKey:SelectionKey( 286)]
    Actual: Set:[]
     Which: at location [0] is Set:[] which shorter than expected
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/t16_sl1_split_test.dart:304:7)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/t16_sl1_split_test.dart line 304
  00:06 +1 -2: SL1 split band [E]
  00:08 +6 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/index/query_filter.dart`; `diff` exit 0; `git diff --quiet -- packages/jet_cad_2d/lib/src/index/query_filter.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:38:02Z.

#### M-11extflag@split — the extension lines generated without the flag — on the scratch per-clause split of SL1 (t16_sl1_split_test.dart, never committed) (spec M-11extflag; killers SL1 (split))

Every SL1 clause as its own test, so a later clause is not hidden behind the first failure.

- **file:** `apps/floor_planner/lib/parametric/dimension.dart`; backup `t16-M-11extflag@split.dimension.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  204,205c204,205
  <       line(l.ext0, flags: EntityFlags.unpickable),
  <       line(l.ext1, flags: EntityFlags.unpickable),
  ---
  >       line(l.ext0),
  >       line(l.ext1),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/t16_sl1_split_test.dart --plain-name 'SL1 split')` (exit 1; log `t16-M-11extflag@split-run1.log`)

  ```
  Expected: [SelectionKey:SelectionKey( 1E)]
    Actual: Set:[SelectionKey:SelectionKey( 286)]
     Which: at location [0] is SelectionKey:<SelectionKey( 286)> instead of
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/t16_sl1_split_test.dart:253:7)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/t16_sl1_split_test.dart line 253
  00:03 +1 -1: SL1 split click-e4 [E]
    The test description was: SL1 split click-e4
  Expected: [SelectionKey:SelectionKey( 286)]
    Actual: Set:[]
     Which: at location [0] is Set:[] which shorter than expected
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/t16_sl1_split_test.dart:304:7)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/t16_sl1_split_test.dart line 304
  00:05 +1 -2: SL1 split band [E]
  00:07 +6 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:38:14Z.

#### M-11movable@split — dimensions immovable by the select tool — on the scratch per-clause split of SL1 (t16_sl1_split_test.dart, never committed) (spec M-11movable; killers SL1 (split))

Every SL1 clause as its own test, so a later clause is not hidden behind the first failure.

- **file:** `apps/floor_planner/lib/parametric/dimension_grips.dart`; backup `t16-M-11movable@split.dimension_grips.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  143c143
  <   bool movable(DraftDocument d, Handle group) => true;
  ---
  >   bool movable(DraftDocument d, Handle group) => false;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/t16_sl1_split_test.dart --plain-name 'SL1 split')` (exit 1; log `t16-M-11movable@split-run1.log`)

  ```
  Expected: <1>
    Actual: <0>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/t16_sl1_split_test.dart:331:7)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/t16_sl1_split_test.dart line 331
  00:03 +3 -1: SL1 split drag-diagonal [E]
    The test description was: SL1 split drag-diagonal
  Expected: true
    Actual: <false>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/t16_sl1_split_test.dart:363:7)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/t16_sl1_split_test.dart line 363
  00:04 +3 -2: SL1 split rotation-grip [E]
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/t16_sl1_split_test.dart:399:7)
    file:///home/user/jet-cad/.claude/worktrees/plan-dims/apps/floor_planner/test/t16_sl1_split_test.dart line 399
  00:05 +3 -3: SL1 split together [E]
  00:06 +5 -3: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_grips.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_grips.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:38:24Z.


### Controls

#### CTRL-M-11a — aligned computed as the axis-projected distance — the degenerate-fixture control (spec M-11a; killers CONTROL (scratch))

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-CTRL-M-11a.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  363c363
  <   final value = kind == DimKind.aligned ? d.length : d.dot(u).abs();
  ---
  >   final value = kind == DimKind.aligned ? d.dot(m.transformDirection(Vector2(1, 0)).normalized()).abs() : d.dot(u).abs();
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/t16_degenerate_control_test.dart --plain-name 'CONTROL')` (exit 0; log `t16-CTRL-M-11a-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** SURVIVED (0 of 1 red). Fired at `5ddd96f`, 2026-09-29T11:38:28Z.

#### CTRL-M-11axisworld — linear axes in world, not the group's — the degenerate-fixture control (spec M-11axisworld; killers CONTROL (scratch))

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-CTRL-M-11axisworld.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  195c195
  <       return m.transformDirection(Vector2(1, 0)).normalized();
  ---
  >       return Vector2(1, 0);
  197c197
  <       return m.transformDirection(Vector2(0, 1)).normalized();
  ---
  >       return Vector2(0, 1);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/t16_degenerate_control_test.dart --plain-name 'CONTROL')` (exit 0; log `t16-CTRL-M-11axisworld-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** SURVIVED (0 of 1 red). Fired at `5ddd96f`, 2026-09-29T11:38:31Z.

#### CTRL-M-11d — an attached end resolved by its wall handle and side only, `k` ignored (always the start) — the degenerate-fixture control (spec M-11d; killers CONTROL (scratch))

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-CTRL-M-11d.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  64a65
  >   k = 0; // M-11d
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/t16_degenerate_control_test.dart --plain-name 'CONTROL')` (exit 1; log `t16-CTRL-M-11d-run1.log`)

  ```
  00:00 +0 -1: CONTROL degenerate fixture: horizontal, free centred wall, origin, centre to centre, identity group [E]
    Expected: '4000'
      Actual: '0'
       Which: is different.
              Expected: 4000
                Actual: 0
    test/t16_degenerate_control_test.dart 24:5          main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `5ddd96f`, 2026-09-29T11:38:35Z.

#### CTRL-M-11d2 — `side` ignored (always the centreline end) — the degenerate-fixture control (spec M-11d2; killers CONTROL (scratch))

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-CTRL-M-11d2.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  64a65
  >   side = WallSide.centre; // M-11d2
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/t16_degenerate_control_test.dart --plain-name 'CONTROL')` (exit 0; log `t16-CTRL-M-11d2-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** SURVIVED (0 of 1 red). Fired at `5ddd96f`, 2026-09-29T11:38:39Z.

#### CTRL-M-11swap — the `k = 1` swap of outgoing sides dropped — the degenerate-fixture control (spec M-11swap; killers CONTROL (scratch))

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16-CTRL-M-11swap.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  68c68
  <   final outgoingLeft = (k == 0) == (side == WallSide.left);
  ---
  >   final outgoingLeft = side == WallSide.left;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/t16_degenerate_control_test.dart --plain-name 'CONTROL')` (exit 0; log `t16-CTRL-M-11swap-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** SURVIVED (0 of 1 red). Fired at `5ddd96f`, 2026-09-29T11:38:43Z.

#### CTRL-M-11attachedmoves — attached ends moved by the group transform (site 1: `endPointInView`) — the degenerate-fixture control (spec M-11attachedmoves; killers CONTROL (scratch))

- **file:** `apps/floor_planner/lib/parametric/dimension.dart`; backup `t16-CTRL-M-11attachedmoves.dimension.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  124c124
  <       return wallEndPoint(w.host, w.walls, k, side);
  ---
  >       return view.toWorld(self).transformPoint(wallEndPoint(w.host, w.walls, k, side));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/t16_degenerate_control_test.dart --plain-name 'CONTROL')` (exit 0; log `t16-CTRL-M-11attachedmoves-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** SURVIVED (0 of 1 red). Fired at `5ddd96f`, 2026-09-29T11:38:46Z.

#### CTRL-M-11fixedworld — fixed ends ignore the group transform (site 1: `endPointInView`) — the degenerate-fixture control (spec M-11fixedworld; killers CONTROL (scratch))

- **file:** `apps/floor_planner/lib/parametric/dimension.dart`; backup `t16-CTRL-M-11fixedworld.dimension.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  119c119
  <       return view.toWorld(self).transformPoint(end.point);
  ---
  >       return end.point;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/t16_degenerate_control_test.dart --plain-name 'CONTROL')` (exit 0; log `t16-CTRL-M-11fixedworld-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** SURVIVED (0 of 1 red). Fired at `5ddd96f`, 2026-09-29T11:38:50Z.

#### X2-step1only — drawnCapsOf's step 1 removed alone (capsOf's own fallback skipped; step 2, the local-ring test, kept) — the plan's control (spec X2-step1only; killers AP2, AP1)

The plan records it equivalent (D4, S-2); the ledger (Task 2 ruling (1), fix e7e9622) records it killed at AP2: the ledger wins.

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t16-X2-step1only.wall_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  535,536c535,540
  <   final caps = capsOf(w, others);
  <   if (caps == null || caps.fellBack) return caps;
  ---
  >   if (w.degenerate) return null;
  >   final caps = (
  >     endCap: cap(End(w, 1), classify(w, 1, others)).points,
  >     startCap: cap(End(w, 0), classify(w, 0, others)).points,
  >     fellBack: false,
  >   );
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP2 ')` (exit 1; log `t16-X2-step1only-run1.log`)

  ```
  00:00 +0 -1: AP2 under 07's local-ring fallback the face points are the stored free rectangle's corners, at any similarity; drawnCapsOf falls back exactly when localOutlineOf does [E]
    Expected: a value less than <0.00001>
      Actual: <86.96452191368587>
       Which: is not a value less than <0.00001>
    test/dimension_attach_points_test.dart 450:13       main.<fn>.agree
    test/dimension_attach_points_test.dart 473:11       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP1 ')` (exit 0; log `t16-X2-step1only-run2.log`)

  ```
  00:00 +6: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/wall_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 2 commands red); green: AP1. Fired at `5ddd96f`, 2026-09-29T11:38:58Z.


### Carried item 1: R4-filterAll against the probe (prints only; the diff of its output is above)

#### R4-filterAll@probe — the candidate queries' visibility filter dropped (`rendering()` -> `all()`, both queries) (spec R4-filterAll; killers )

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16-R4-filterAll@probe.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  107c107
  <       const QueryFilter.rendering(), (slot) {
  ---
  >       const QueryFilter.all(), (slot) {
  114c114
  <       const QueryFilter.rendering(), (slot) {
  ---
  >       const QueryFilter.all(), (slot) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/t16_hidden_probe_test.dart)` (exit 0; log `t16-R4-filterAll@probe-run1.log`)

  ```
  00:00 +2: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** SURVIVED (0 of 1 red). Fired at `5ddd96f`, 2026-09-29T11:39:58Z.

### Fix round (`49de0e8`)

#### R4-filterAll — the candidate queries' visibility filter dropped (both queries `rendering()` -> `all()`; Task 4's reviewer) (spec R4-filterAll; killers AM6b)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16f-R4-filterAll.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  115c115
  <       const QueryFilter.rendering(), (slot) {
  ---
  >       const QueryFilter.all(), (slot) {
  123c123
  <       const QueryFilter.rendering(), (slot) {
  ---
  >       const QueryFilter.all(), (slot) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM6b ')` (exit 1; log `t16f-R4-filterAll-run1.log`)

  ```
  00:00 +0 -1: AM6b only a drawn wall attaches: a hidden wall neither by its own children nor as the host of a visible flush door; a hidden door makes its host no candidate; a hidden layer 0 hides every wall, at origin [E]
    Expected: [AttachedEnd:12/1/right]
      Actual: [AttachedEnd:12/1/right, AttachedEnd:16/0/right]
       Which: at location [1] is [AttachedEnd:12/1/right, AttachedEnd:16/0/right] which longer than expected
    test/dimension_attach_test.dart 900:9               main.<fn>
  00:00 +0 -2: AM6b only a drawn wall attaches: a hidden wall neither by its own children nor as the host of a visible flush door; a hidden door makes its host no candidate; a hidden layer 0 hides every wall, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 900:9               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `49de0e8`, 2026-09-29T11:57:21Z.

#### X16-hostVisible — the opening-host query keeps a host whether or not the renderer draws it (this round's host test dropped) (spec X16-hostVisible; killers AM6b)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16f-X16-hostVisible.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  131,133c131
  <     if (drawn!.acceptsNode(host, const QueryFilter.rendering())) {
  <       walls.add(host);
  <     }
  ---
  >     walls.add(host);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM6b ')` (exit 1; log `t16f-X16-hostVisible-run1.log`)

  ```
  00:00 +0 -1: AM6b only a drawn wall attaches: a hidden wall neither by its own children nor as the host of a visible flush door; a hidden door makes its host no candidate; a hidden layer 0 hides every wall, at origin [E]
    Expected: empty
      Actual: [AttachedEnd:16/0/left]
    test/dimension_attach_test.dart 934:13              main.<fn>
  00:00 +0 -2: AM6b only a drawn wall attaches: a hidden wall neither by its own children nor as the host of a visible flush door; a hidden door makes its host no candidate; a hidden layer 0 hides every wall, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 934:13              main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `49de0e8`, 2026-09-29T11:57:24Z.


### The attach re-fires on the fix (`49de0e8`)

#### M-11nbrs@fix — the neighbours ignored (`drawnCapsOf(w, const [])`) (spec M-11nbrs; killers AP1, DN1)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16f-M-11nbrs@fix.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  66c66
  <   final caps = drawnCapsOf(w, others)!;
  ---
  >   final caps = drawnCapsOf(w, const [])!;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP1 ')` (exit 1; log `t16f-M-11nbrs@fix-run1.log`)

  ```
  00:00 +0 -1: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <100.0>
       Which: is not a value less than <0.000001>
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -2: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -3: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -4: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -5: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_follow_test.dart --plain-name 'DN1 ')` (exit 1; log `t16f-M-11nbrs@fix-run2.log`)

  ```
  00:00 +0 -1: DN1 a neighbour's edit moves a referenced wall's corner and rebuilds the dimension once, at origin [E]
    Expected: '3900'
      Actual: '4000'
       Which: is different.
              Expected: 3900
                Actual: 4000
    test/dimension_follow_test.dart 80:7                main.<fn>
  00:00 +0 -2: DN1 a neighbour's edit moves a referenced wall's corner and rebuilds the dimension once, at corpus far origin, 23 deg, own groups [E]
    test/dimension_follow_test.dart 80:7                main.<fn>
  00:00 +0 -3: DN1 a neighbour's edit moves a referenced wall's corner and rebuilds the dimension once, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_follow_test.dart 80:7                main.<fn>
  00:00 +0 -3: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `49de0e8`, 2026-09-29T11:57:39Z.

#### M-11swap@fix — the `k = 1` swap of outgoing sides dropped (spec M-11swap; killers AP1)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16f-M-11swap@fix.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  68c68
  <   final outgoingLeft = (k == 0) == (side == WallSide.left);
  ---
  >   final outgoingLeft = side == WallSide.left;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP1 ')` (exit 1; log `t16f-M-11swap@fix-run1.log`)

  ```
  00:00 +0 -1: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <200.0>
       Which: is not a value less than <0.000001>
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -2: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -3: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -4: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -5: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `49de0e8`, 2026-09-29T11:57:42Z.

#### M-11swapjust@fix — left and right swapped for right-justified walls (spec M-11swapjust; killers AP1)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16f-M-11swapjust@fix.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  68c68
  <   final outgoingLeft = (k == 0) == (side == WallSide.left);
  ---
  >   final outgoingLeft = (k == 0) == ((side == WallSide.left) != (w.j.name == 'right'));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP1 ')` (exit 1; log `t16f-M-11swapjust@fix-run1.log`)

  ```
  00:00 +0 -1: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <233.23807579381202>
       Which: is not a value less than <0.000001>
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -2: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -3: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -4: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -5: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `49de0e8`, 2026-09-29T11:57:46Z.

#### M-11fallback@fix — no fallback at all in `drawnCapsOf`: both steps return the joined caps (S-2) (spec M-11fallback; killers AP1)

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t16f-M-11fallback@fix.wall_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  534a535,540
  >   if (w.degenerate) return null;
  >   return (
  >     endCap: cap(End(w, 1), classify(w, 1, others)).points,
  >     startCap: cap(End(w, 0), classify(w, 0, others)).points,
  >     fellBack: false,
  >   );
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP1 ')` (exit 1; log `t16f-M-11fallback@fix-run1.log`)

  ```
  00:00 +0 -1: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <100.0>
       Which: is not a value less than <0.000001>
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -2: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -3: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -4: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -5: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/wall_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `49de0e8`, 2026-09-29T11:57:50Z.

#### M-11centremid@fix — centre = the cap's midpoint (spec M-11centremid; killers AP1)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16f-M-11centremid@fix.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  65c65
  <   if (side == WallSide.centre || w.degenerate) return w.endpoint(k);
  ---
  >   if (w.degenerate) return w.endpoint(k);
  67a68
  >   if (side == WallSide.centre) return (c.first + c.last) * 0.5;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP1 ')` (exit 1; log `t16f-M-11centremid@fix-run1.log`)

  ```
  00:00 +0 -1: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <60.0>
       Which: is not a value less than <0.000001>
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -2: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -3: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -4: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -5: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `49de0e8`, 2026-09-29T11:57:54Z.

#### M-11localring@fix — the attach point ignores the local-ring fallback (`capsOf` alone): step 2 removed (spec M-11localring; killers AP2)

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t16f-M-11localring@fix.wall_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  542c542
  <   if (isSimpleCcw(local)) return caps;
  ---
  >   return caps;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP2 ')` (exit 1; log `t16f-M-11localring@fix-run1.log`)

  ```
  00:00 +0 -1: AP2 under 07's local-ring fallback the face points are the stored free rectangle's corners, at any similarity; drawnCapsOf falls back exactly when localOutlineOf does [E]
    Expected: a value less than <0.00001>
      Actual: <5730.741669592764>
       Which: is not a value less than <0.00001>
    test/dimension_attach_points_test.dart 383:9        main.<fn>.expectLocalFallback
    test/dimension_attach_points_test.dart 399:5        main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/wall_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `49de0e8`, 2026-09-29T11:57:58Z.

#### M-11vertex@fix — a face point taken from its cap's second point, not its first or last (spec M-11vertex; killers AP1, AP2, AP3)

Killer list per the Task 2 ruling (2): AP1 (+AP2); AP3 dropped (every cap point is a stored vertex). AP3 fired for the record.

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16f-M-11vertex@fix.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  69c69
  <   return outgoingLeft ? c.first : c.last;
  ---
  >   return outgoingLeft ? c[1] : c.last;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP1 ')` (exit 1; log `t16f-M-11vertex@fix-run1.log`)

  ```
  00:00 +0 -1: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <200.0>
       Which: is not a value less than <0.000001>
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -2: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -3: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -4: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -5: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP2 ')` (exit 1; log `t16f-M-11vertex@fix-run2.log`)

  ```
  00:00 +0 -1: AP2 under 07's local-ring fallback the face points are the stored free rectangle's corners, at any similarity; drawnCapsOf falls back exactly when localOutlineOf does [E]
    Expected: a value less than <0.00001>
      Actual: <200.00000000009047>
       Which: is not a value less than <0.00001>
    test/dimension_attach_points_test.dart 383:9        main.<fn>.expectLocalFallback
    test/dimension_attach_points_test.dart 399:5        main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP3 ')` (exit 0; log `t16f-M-11vertex@fix-run3.log`)

  ```
  00:00 +6: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 3 commands red); green: AP3. Fired at `49de0e8`, 2026-09-29T11:58:08Z.

#### M-11d@fix — an attached end resolved by its wall handle and side only, `k` ignored (always the start) (spec M-11d; killers AP1, SP8)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16f-M-11d@fix.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  64a65
  >   k = 0; // M-11d
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP1 ')` (exit 1; log `t16f-M-11d@fix-run1.log`)

  ```
  00:00 +0 -1: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <4000.0>
       Which: is not a value less than <0.000001>
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -2: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -3: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -4: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -5: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/startup_plan_test.dart --plain-name 'SP8 ')` (exit 1; log `t16f-M-11d@fix-run2.log`)

  ```
  00:00 +0 -1: SP8 the five dimensions read D17's values at 1:50 m with text 125 high, reference the walls listed, and a click on each line selects it [E]
    Expected: ['14.00', '9.00', '4.69', '4.38', '3.58']
      Actual: ['0.00', '0.00', '4.69', '4.38', '10.09']
       Which: at location [0] is '0.00' instead of '14.00'
    test/startup_plan_test.dart 616:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `49de0e8`, 2026-09-29T11:58:16Z.

#### M-11d2@fix — `side` ignored (always the centreline end) (spec M-11d2; killers AP1, SP8)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16f-M-11d2@fix.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  64a65
  >   side = WallSide.centre; // M-11d2
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP1 ')` (exit 1; log `t16f-M-11d2@fix-run1.log`)

  ```
  00:00 +0 -1: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at origin [E]
    Expected: a value less than <0.000001>
      Actual: <100.0>
       Which: is not a value less than <0.000001>
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -2: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -3: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -4: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -5: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, k = 1 and both faces included, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_points_test.dart 287:11       main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/startup_plan_test.dart --plain-name 'SP8 ')` (exit 1; log `t16f-M-11d2@fix-run2.log`)

  ```
  00:00 +0 -1: SP8 the five dimensions read D17's values at 1:50 m with text 125 high, reference the walls listed, and a click on each line selects it [E]
    Expected: ['14.00', '9.00', '4.69', '4.38', '3.58']
      Actual: ['13.75', '8.75', '4.88', '4.50', '3.73']
       Which: at location [0] is '13.75' instead of '14.00'
    test/startup_plan_test.dart 616:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `49de0e8`, 2026-09-29T11:58:25Z.

#### M-11nearest@fix — the nearest candidate instead of decision 19's rule, ties to the lowest handle (spec M-11nearest; killers AM1, AM3)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16f-M-11nearest@fix.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  252a253,266
  >   {
  >     AttachedEnd? n;
  >     var nd = double.infinity;
  >     for (final e in candidates) {
  >       final ws = wallsInDocument(doc, e.wall)!;
  >       final dd = (wallEndPoint(ws.host, ws.walls, e.k, e.side) - at).length;
  >       if (dd < nd || (dd == nd && _before(e, n!))) {
  >         n = e;
  >         nd = dd;
  >       }
  >     }
  >     return n;
  >   }
  >   // ignore: dead_code
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM1 ')` (exit 1; log `t16f-M-11nearest@fix-run1.log`)

  ```
  00:00 +0 -1: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at origin [E]
    Expected: AttachedEnd:<1E/1/left>
      Actual: AttachedEnd:<12/0/left>
    test/dimension_attach_test.dart 429:13              main.<fn>
  00:00 +0 -2: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 429:13              main.<fn>
  00:00 +0 -3: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_test.dart 429:13              main.<fn>
  00:00 +0 -3: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM3 ')` (exit 1; log `t16f-M-11nearest@fix-run2.log`)

  ```
  00:00 +0 -1: AM3 a shared corner is stored on the wall the committed kind runs along, then on the lowest handle, then face before centre, k, left before right, at origin [E]
    Expected: AttachedEnd:<16/1/left>
      Actual: AttachedEnd:<12/0/left>
    test/dimension_attach_test.dart 222:9               main.<fn>
  00:00 +0 -2: AM3 a shared corner is stored on the wall the committed kind runs along, then on the lowest handle, then face before centre, k, left before right, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 222:9               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `49de0e8`, 2026-09-29T11:58:34Z.

#### M-11parallel@fix — decision 19's parallel step skipped (the lowest handle first) (spec M-11parallel; killers AM3)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16f-M-11parallel@fix.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  262d261
  <     if (!(sigma[e.wall]! <= least + dimAttach.angular)) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM3 ')` (exit 1; log `t16f-M-11parallel@fix-run1.log`)

  ```
  00:00 +0 -1: AM3 a shared corner is stored on the wall the committed kind runs along, then on the lowest handle, then face before centre, k, left before right, at origin [E]
    Expected: AttachedEnd:<16/1/left>
      Actual: AttachedEnd:<12/0/left>
    test/dimension_attach_test.dart 222:9               main.<fn>
  00:00 +0 -2: AM3 a shared corner is stored on the wall the committed kind runs along, then on the lowest handle, then face before centre, k, left before right, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 222:9               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `49de0e8`, 2026-09-29T11:58:38Z.

#### M-11lineardir@fix — a linear kind's parallel measure uses `P1 − P0` instead of its axis (spec M-11lineardir; killers AM3)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16f-M-11lineardir@fix.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  253c253
  <   final u = measuringDirection(kind, at, other, m);
  ---
  >   final u = (other - at).normalized();
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM3 ')` (exit 1; log `t16f-M-11lineardir@fix-run1.log`)

  ```
  00:00 +0 -1: AM3 a shared corner is stored on the wall the committed kind runs along, then on the lowest handle, then face before centre, k, left before right, at origin [E]
    Expected: AttachedEnd:<16/1/right>
      Actual: AttachedEnd:<12/0/right>
    test/dimension_attach_test.dart 254:9               main.<fn>
  00:00 +0 -2: AM3 a shared corner is stored on the wall the committed kind runs along, then on the lowest handle, then face before centre, k, left before right, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 254:9               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `49de0e8`, 2026-09-29T11:58:41Z.

#### M-11centrefirst@fix — centre before face (spec M-11centrefirst; killers AM3)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16f-M-11centrefirst@fix.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  292c292
  < int _centreRank(WallSide side) => side == WallSide.centre ? 1 : 0;
  ---
  > int _centreRank(WallSide side) => side == WallSide.centre ? 0 : 1;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM3 ')` (exit 1; log `t16f-M-11centrefirst@fix-run1.log`)

  ```
  00:00 +0 -1: AM3 a shared corner is stored on the wall the committed kind runs along, then on the lowest handle, then face before centre, k, left before right, at origin [E]
    Expected: AttachedEnd:<12/0/right>
      Actual: AttachedEnd:<12/0/centre>
    test/dimension_attach_test.dart 327:9               main.<fn>
  00:00 +0 -2: AM3 a shared corner is stored on the wall the committed kind runs along, then on the lowest handle, then face before centre, k, left before right, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 327:9               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `49de0e8`, 2026-09-29T11:58:45Z.

#### M-11attachtol@fix — attach tolerance 1e-9 (spec M-11attachtol; killers AM1)

- **file:** `apps/floor_planner/lib/parametric/dimension_geometry.dart`; backup `t16f-M-11attachtol@fix.dimension_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  35c35
  < const Tolerance dimAttach = Tolerance(linear: 1e-5, angular: 1e-9);
  ---
  > const Tolerance dimAttach = Tolerance(linear: 1e-9, angular: 1e-9);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM1 ')` (exit 1; log `t16f-M-11attachtol@fix-run1.log`)

  ```
  00:00 +1 -1: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at corpus far origin, 23 deg, own groups [E]
    Expected: [AttachedEnd:12/0/right, AttachedEnd:1E/1/right]
      Actual: [AttachedEnd:12/0/right]
       Which: at location [1] is [AttachedEnd:12/0/right] which shorter than expected
    test/dimension_attach_test.dart 424:11              main.<fn>
  00:00 +1 -2: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_test.dart 423:11              main.<fn>
  00:00 +1 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `49de0e8`, 2026-09-29T11:58:49Z.

#### M-11snapoff@fix — ends attach with F3 off (spec M-11snapoff; killers AM4, TL6)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16f-M-11snapoff@fix.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  110d109
  <   if (!objectSnap) return const [];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM4 ')` (exit 1; log `t16f-M-11snapoff@fix-run1.log`)

  ```
  00:00 +0 -1: AM4 decision 23: a grid point on the sample's outer corner attaches with F3 on and stays fixed with F3 off, at origin [E]
    Expected: empty
      Actual: [AttachedEnd:12/0/right, AttachedEnd:1E/1/right]
    test/dimension_attach_test.dart 720:7               main.<fn>
  00:00 +0 -2: AM4 decision 23: a grid point on the sample's outer corner attaches with F3 on and stays fixed with F3 off, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 720:7               main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_tool_test.dart --plain-name 'TL6 ')` (exit 1; log `t16f-M-11snapoff@fix-run2.log`)

  ```
  00:00 +0 -1: TL6 decision 23 through the tool: with F3 on a grid point on a corner attaches and a flush door's jamb snap attaches the stem's corner; with F3 off every end is fixed, at origin [E]
    Expected: FixedEnd:<(12000.0, 8000.0)>
      Actual: AttachedEnd:<12/0/right>
    test/dimension_tool_test.dart 788:9                 main.<fn>
  00:00 +0 -2: TL6 decision 23 through the tool: with F3 on a grid point on a corner attaches and a flush door's jamb snap attaches the stem's corner; with F3 off every end is fixed, at corpus far origin, 23 deg, own groups [E]
    test/dimension_tool_test.dart 788:9                 main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (2 of 2 commands red). Fired at `49de0e8`, 2026-09-29T11:58:57Z.

#### M-11prefilter@fix — D10's line test omits the centreline (face lines only) (spec M-11prefilter; killers AM1, AM6, TL8)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16f-M-11prefilter@fix.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  195c195
  <   return (o - lOff).abs() <= tol || o.abs() <= tol || (o - rOff).abs() <= tol;
  ---
  >   return (o - lOff).abs() <= tol || (o - rOff).abs() <= tol;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM1 ')` (exit 1; log `t16f-M-11prefilter@fix-run1.log`)

  ```
  00:00 +0 -1: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at origin [E]
    Expected: contains AttachedEnd:<12/0/centre>
      Actual: []
       Which: does not contain AttachedEnd:<12/0/centre>
    test/dimension_attach_test.dart 423:11              main.<fn>
  00:00 +0 -2: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 423:11              main.<fn>
  00:00 +0 -3: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_test.dart 423:11              main.<fn>
  00:00 +0 -3: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM6 ')` (exit 1; log `t16f-M-11prefilter@fix-run2.log`)

  ```
  00:00 +0 -1: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at origin [E]
    Expected: contains AttachedEnd:<16/0/centre>
      Actual: []
       Which: does not contain AttachedEnd:<16/0/centre>
    test/dimension_attach_test.dart 818:11              main.<fn>
  00:00 +0 -2: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at corpus far origin, 23 deg [E]
    test/dimension_attach_test.dart 818:11              main.<fn>
  00:00 +0 -3: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 818:11              main.<fn>
  00:00 +0 -4: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_test.dart 818:11              main.<fn>
  00:00 +0 -5: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_test.dart 818:11              main.<fn>
  00:00 +0 -6: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_test.dart 818:11              main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_tool_test.dart --plain-name 'TL8 ')` (exit 1; log `t16f-M-11prefilter@fix-run3.log`)

  ```
  00:01 +0 -1: TL8 hovering among 600 walls searches once per distinct resolved point, passes no line test between a centreline and its faces or past a door, passes one on a face line and one on a centreline, and a commit searches afresh once per end; the time per move is printed [E]
    Expected: ({int passes, int searches}):<(passes: 2, searches: 42)>
      Actual: ({int passes, int searches}):<(passes: 1, searches: 42)>
    test/dimension_tool_test.dart 1480:5                main.<fn>
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (3 of 3 commands red). Fired at `49de0e8`, 2026-09-29T11:59:10Z.

#### M-11openinghost@fix — opening hosts not gathered as candidate walls (spec M-11openinghost; killers AM6)

 Edit re-cut for the fixed opening-host query (the block it replaces now carries the host test).

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16f-M-11openinghost@fix.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  119,134c119
  <   final grown = dimAttach.linear + thickest;
  <   FilterEvaluator? drawn;
  <   index.forEachInRect(
  <       Aabb2.raw(q.x - grown, q.y - grown, q.x + grown, q.y + grown),
  <       const QueryFilter.rendering(), (slot) {
  <     final owner = doc.entities.ownerAt(slot);
  <     if (!_isLiveGroup(doc, owner)) return;
  <     final host = doc.components.get<OpeningParams>(owner)?.host;
  <     if (host == null || !_isLiveWall(doc, host)) return;
  <     // Only a host the renderer draws (D10: what is drawn attaches): the
  <     // opening's children passed `rendering()`, its host's group must too.
  <     drawn ??= FilterEvaluator(doc);
  <     if (drawn!.acceptsNode(host, const QueryFilter.rendering())) {
  <       walls.add(host);
  <     }
  <   });
  ---
  >   // M-11openinghost: no opening-host query
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM6 ')` (exit 1; log `t16f-M-11openinghost@fix-run1.log`)

  ```
  00:00 +0 -1: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at origin [E]
    Expected: contains AttachedEnd:<16/0/left>
      Actual: []
       Which: does not contain AttachedEnd:<16/0/left>
    test/dimension_attach_test.dart 818:11              main.<fn>
  00:00 +0 -2: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at corpus far origin, 23 deg [E]
    test/dimension_attach_test.dart 818:11              main.<fn>
  00:00 +0 -3: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 818:11              main.<fn>
  00:00 +0 -4: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_test.dart 818:11              main.<fn>
  00:00 +0 -5: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_test.dart 818:11              main.<fn>
  00:00 +0 -6: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_test.dart 818:11              main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `49de0e8`, 2026-09-29T11:59:15Z.

#### M-11hostbox@fix — opening hosts gathered from the tight box `q ± dimAttach.linear` only (spec M-11hostbox; killers AM6)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16f-M-11hostbox@fix.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  119c119
  <   final grown = dimAttach.linear + thickest;
  ---
  >   final grown = dimAttach.linear;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM6 ')` (exit 1; log `t16f-M-11hostbox@fix-run1.log`)

  ```
  00:00 +0 -1: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at origin [E]
    Expected: contains AttachedEnd:<16/0/centre>
      Actual: []
       Which: does not contain AttachedEnd:<16/0/centre>
    test/dimension_attach_test.dart 818:11              main.<fn>
  00:00 +0 -2: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at corpus far origin, 23 deg [E]
    test/dimension_attach_test.dart 818:11              main.<fn>
  00:00 +0 -3: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 818:11              main.<fn>
  00:00 +0 -4: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at +1e9 mm (1e6 m), 23 deg [E]
    test/dimension_attach_test.dart 818:11              main.<fn>
  00:00 +0 -5: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at +1e9 mm (1e6 m), 0 deg [E]
    test/dimension_attach_test.dart 818:11              main.<fn>
  00:00 +0 -6: AM6 a door flush with a wall end leaves none of the end's three points stored, and each still attaches by position, and through the jamb's snap, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_test.dart 818:11              main.<fn>
  00:00 +0 -6: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `49de0e8`, 2026-09-29T11:59:19Z.

#### M-11reachcull@fix — candidate walls by reach instead of stored boxes (spec M-11reachcull; killers AM1)

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16f-M-11reachcull@fix.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  112,118c112,118
  <   final tight = dimAttach.linear;
  <   index.forEachInRect(
  <       Aabb2.raw(q.x - tight, q.y - tight, q.x + tight, q.y + tight),
  <       const QueryFilter.rendering(), (slot) {
  <     final owner = doc.entities.ownerAt(slot);
  <     if (_isLiveWall(doc, owner)) walls.add(owner);
  <   });
  ---
  >   for (final h in doc.components.withComponent<WallParams>()) {
  >     if (!_isLiveWall(doc, h)) continue;
  >     if (const WallType()
  >         .reach(doc.components.get<WallParams>(h)!,
  >             doc.tree.accumulatedTransform(h))
  >         .containsPoint(q)) walls.add(h);
  >   }
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM1 ')` (exit 1; log `t16f-M-11reachcull@fix-run1.log`)

  ```
  00:00 +0 -1: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at origin [E]
    Expected: contains AttachedEnd:<12/0/left>
      Actual: []
       Which: does not contain AttachedEnd:<12/0/left>
    test/dimension_attach_test.dart 423:11              main.<fn>
  00:00 +0 -2: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 424:11              main.<fn>
  00:00 +0 -3: AM1 every one of the sample plan's 60 wall end points, snapped through snapInto from 5 mm away, has the brute-force candidate set and decision 19's end, at +1e9 mm (1e6 m), 23 deg, own groups [E]
    test/dimension_attach_test.dart 424:11              main.<fn>
  00:00 +0 -3: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `49de0e8`, 2026-09-29T11:59:23Z.

#### M-11ownerring@fix — candidate walls from the snapped entity's owner only (the spike's (A)) (spec M-11ownerring; killers AM2)

 Edit re-cut for the fixed opening-host query (the block it replaces now carries the host test).

- **file:** `apps/floor_planner/lib/parametric/dimension_attach.dart`; backup `t16f-M-11ownerring@fix.dimension_attach.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  112,116c112,117
  <   final tight = dimAttach.linear;
  <   index.forEachInRect(
  <       Aabb2.raw(q.x - tight, q.y - tight, q.x + tight, q.y + tight),
  <       const QueryFilter.rendering(), (slot) {
  <     final owner = doc.entities.ownerAt(slot);
  ---
  >   final res = SnapResult();
  >   index.snapInto(q, dimAttach.linear, kDragSnapMask, res);
  >   if (res.found) {
  >     final owner = res.chainLength > 0
  >         ? Handle(res.chain[0])
  >         : doc.entities.ownerAt(doc.entities.slotOf(res.entity)!);
  118,134c119
  <   });
  <   final grown = dimAttach.linear + thickest;
  <   FilterEvaluator? drawn;
  <   index.forEachInRect(
  <       Aabb2.raw(q.x - grown, q.y - grown, q.x + grown, q.y + grown),
  <       const QueryFilter.rendering(), (slot) {
  <     final owner = doc.entities.ownerAt(slot);
  <     if (!_isLiveGroup(doc, owner)) return;
  <     final host = doc.components.get<OpeningParams>(owner)?.host;
  <     if (host == null || !_isLiveWall(doc, host)) return;
  <     // Only a host the renderer draws (D10: what is drawn attaches): the
  <     // opening's children passed `rendering()`, its host's group must too.
  <     drawn ??= FilterEvaluator(doc);
  <     if (drawn!.acceptsNode(host, const QueryFilter.rendering())) {
  <       walls.add(host);
  <     }
  <   });
  ---
  >   }
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_test.dart --plain-name 'AM2 ')` (exit 1; log `t16f-M-11ownerring@fix-run1.log`)

  ```
  00:00 +0 -1: AM2 a jamb is fixed, a Y lobe vertex finds both walls' points, a T butt corner is the stem's, an X crossing gives no candidate; a degenerate wall and a left-justified wall's points are found, at origin [E]
    Expected: [AttachedEnd:16/0/left, AttachedEnd:1A/0/right]
      Actual: [AttachedEnd:1A/0/right]
       Which: at location [0] is AttachedEnd:<1A/0/right> instead of AttachedEnd:<16/0/left>
    test/dimension_attach_test.dart 500:9               main.<fn>
  00:00 +0 -2: AM2 a jamb is fixed, a Y lobe vertex finds both walls' points, a T butt corner is the stem's, an X crossing gives no candidate; a degenerate wall and a left-justified wall's points are found, at corpus far origin, 23 deg, own groups [E]
    test/dimension_attach_test.dart 500:9               main.<fn>
  00:00 +0 -3: AM2 a wall group scaled 1.5 (C11, at its own far placement) has its free rectangle's corners found by the local-frame line test [E]
    test/dimension_attach_test.dart 638:9               main.<fn>
  00:00 +0 -3: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_attach.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_attach.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `49de0e8`, 2026-09-29T11:59:26Z.

#### M-11snaponly@fix — an end attaches only when an object snap won (the tool's candidate search gated on `hoverKind != null`, Ruling 11-6) (spec M-11snaponly; killers TL6)

Killer TL6 only (Ruling 11-6: AM4 cannot see "an object snap won").

- **file:** `apps/floor_planner/lib/parametric/dimension_tool.dart`; backup `t16f-M-11snaponly@fix.dimension_tool.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  289,290c289,290
  <         decideEnd(doc, _candidatesAt(ctx, at, t),
  <             kind: kind, at: at, other: other, m: m) ??
  ---
  >         (hoverKind != null ? decideEnd(doc, _candidatesAt(ctx, at, t),
  >             kind: kind, at: at, other: other, m: m) : null) ??
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_tool_test.dart --plain-name 'TL6 ')` (exit 1; log `t16f-M-11snaponly@fix-run1.log`)

  ```
  00:00 +0 -1: TL6 decision 23 through the tool: with F3 on a grid point on a corner attaches and a flush door's jamb snap attaches the stem's corner; with F3 off every end is fixed, at origin [E]
    Expected: AttachedEnd:<12/0/right>
      Actual: FixedEnd:<(12000.0, 8000.0)>
    test/dimension_tool_test.dart 788:9                 main.<fn>
  00:00 +0 -2: TL6 decision 23 through the tool: with F3 on a grid point on a corner attaches and a flush door's jamb snap attaches the stem's corner; with F3 off every end is fixed, at corpus far origin, 23 deg, own groups [E]
    test/dimension_tool_test.dart 788:9                 main.<fn>
  00:00 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/dimension_tool.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/dimension_tool.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 1 commands red). Fired at `49de0e8`, 2026-09-29T11:59:31Z.

#### X2-step1only@fix — drawnCapsOf's step 1 removed alone (capsOf's own fallback skipped; step 2, the local-ring test, kept) — the plan's control (spec X2-step1only; killers AP2, AP1)

The plan records it equivalent (D4, S-2); the ledger (Task 2 ruling (1), fix e7e9622) records it killed at AP2: the ledger wins.

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t16f-X2-step1only@fix.wall_geometry.dart.bak`
- **edit** (`diff <backup> <file>`):

  ```diff
  535,536c535,540
  <   final caps = capsOf(w, others);
  <   if (caps == null || caps.fellBack) return caps;
  ---
  >   if (w.degenerate) return null;
  >   final caps = (
  >     endCap: cap(End(w, 1), classify(w, 1, others)).points,
  >     startCap: cap(End(w, 0), classify(w, 0, others)).points,
  >     fellBack: false,
  >   );
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP2 ')` (exit 1; log `t16f-X2-step1only@fix-run1.log`)

  ```
  00:00 +0 -1: AP2 under 07's local-ring fallback the face points are the stored free rectangle's corners, at any similarity; drawnCapsOf falls back exactly when localOutlineOf does [E]
    Expected: a value less than <0.00001>
      Actual: <86.96452191368587>
       Which: is not a value less than <0.00001>
    test/dimension_attach_points_test.dart 450:13       main.<fn>.agree
    test/dimension_attach_points_test.dart 473:11       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test --no-pub test/dimension_attach_points_test.dart --plain-name 'AP1 ')` (exit 0; log `t16f-X2-step1only@fix-run2.log`)

  ```
  00:00 +6: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0; `git diff --quiet -- apps/floor_planner/lib/parametric/wall_geometry.dart` exit 0; `git diff --quiet -- packages/` exit 0.
- **result:** KILLED (1 of 2 commands red); green: AP1. Fired at `49de0e8`, 2026-09-29T11:59:39Z.

