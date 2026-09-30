# L2b brief — the L2 review's m1, m2, m5 (code)

Implementer, branch `fix/live-object-rule`, worktree
`/home/user/jet-cad/.claude/worktrees/fix-live-object-rule` (HEAD `980947d`).
Read `CLAUDE.md`, `l2-brief.md`, `l2-report.md` and `l2-review.md` beside
this file. Commit; do NOT push. Test-only plus one comment wrap; no `lib`
behaviour change.

1. **m1**: the committed shadow tests use Wall+Opening and Separator+Opening
   only, so a fix that special-cases `OpeningParams` (skip groups carrying
   it) passes them. Land a third pair, as the reviewer's scratch RV1 did: a
   rotated, off-origin **dimension** (or room) group that also carries
   `WallParams` (written through the store as a file would). It is not a
   wall anywhere: not in `wallsInDocument`'s walls, not in the band cache,
   not in `thickestWall`, no wall grips; and a wall drag near it does not
   touch it. Mutants that must go red: M-RV-narrowBands (wall_bands skips
   only groups carrying `OpeningParams`), M-RV-narrowAdapter (the same in
   `wallsInDocument`).
2. **m2**: `room_tool.dart`'s two `liveObjectsOf<RoomParams>` sites
   (l.278, l.352 at 980947d) are unpinned: M-L2-5t (both reverted to the
   old `is GroupNode && parent == root && get<RoomParams> != null`
   spelling) survives. Find what each site decides, then a fixture where a
   room group shadowed by a later type (a `DimensionParams` attached
   through the store) makes the old spelling do something wrong visible
   through the Room tool. If a site is unreachable by any document (say
   why, with the code), report it instead of forcing a test.
3. **m5**: `wall_grips.dart` l.22 doc comment past 80 columns: wrap it.

Procedure: backups under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/l2b-`,
mutate, run, `cp` back, `diff` exit 0. NEVER `git checkout --` a .dart file.
`CI=true` on every test command. Never synthesize output. Never commit
`analysis_options.yaml`.

Gates: app `flutter test`, `analyze`, `format`, `flutter build web --release`
(`export PATH=/root/flutter/bin:$PATH`). Branch app 512.

Commit `test(app): shadow pairs beyond openings; the Room tool's live rooms`
with the two trailers
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv
```
Write `.superpowers/sdd/fix-live-object-rule/l2b-report.md` and return it:
hash, tests, every mutant with red test and line, gates, anything outside
scope.
