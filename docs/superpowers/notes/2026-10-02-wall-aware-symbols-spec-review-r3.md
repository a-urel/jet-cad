# Spec 09c (wall-aware symbols): spot check of revision 3

**Spec:** `docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md`, rev 3 (`ceb7b17`). **Reviewer:** independent, read-only, 2026-10-02. I read the code on the same tree.

## Verdict: **Ready with amendments**

All ten amendments, S-1 to S-10, appear in the decision sections. Checked against the code, they hold:

- **S-1, the anchor.** It works.
  - While a symbol is attached, `T·c` is `q`. A drag along the face therefore has `s` equal to the pointer's perpendicular drift, so the symbol stays attached at any zoom.
  - A free symbol attaches once its plain-moved back comes within `[−w/2, capture]` of a face.
  - `u` is continuous, given the D9 test that every base point lies on the box's centre `x`.
- **S-2, the face lines.** The `HostFrame` caps are local: `hostFrameOf` maps them through `toLocal`, or builds local free caps (`opening_geometry.dart:80-90`). Mapping them through `toWorld` is therefore correct.
  - `startCap.first` and `endCap.last` lie on the left face for free, Tee, mitre and node-owner caps (`wall_geometry.dart:260-339`).
  - Choosing `m` as the normal pointing away from the other face line works for every justification. A face at offset 0 (the centreline) is still `t·s` from the other face.
- **S-3, the side test.** `End(B,k).a` points into B's body (`wall_geometry.dart:63-83`). `frame.n` is the local left normal of the local `d`, and the local left face is `lOff` along it (`opening_geometry.dart:40,59`). So the sign of `toLocal(a)·n` picks the face B butts, in local terms, and it flips correctly when `det < 0`.
- **S-4 to S-10** are applied as asked. The `_retarget`, `_onCamera` and Shift paths all go through `select_tool.dart:347-380` and `:565-574`. The no-op check is component-wise. `singleNode` and the key count are both required.

Two problems remain. One stale sentence contradicts S-1 (T-1). One input to the obstacle cut is unspecified (T-2). Everything else is minor or a nit. Every amendment is mechanical, so no further review round is needed.

---

**T-1 (major). D4 still names the anchor that S-1 replaced.**
- **Location:** D4, the opening paragraph (line 306-307).
- **Evidence:** it reads "`p` is the anchor point: the pointer in placement (D6), **the plain-moved insertion point in a move (D8)**". D8 (lines 509-511) says the plain-moved back-centre. This sentence is the old W-6 anchor, which S-1 found blocking. 09c-2's plan writer reads D4 as "the one rule".
- **Amendment:** change it to "the plain-moved back-centre `delta · node.transform · c` in a move (D8)".

**T-2 (minor). D3 does not say which faces of the obstacle wall B cut the host. With world offsets, the S-2 and S-3 errors return through B.**
- **Location:** D3, the T and X bullets ("where B's two faces cross this face line"); D14, the "Inherited (S-3)" bullet.
- **Evidence:**
  - D3 now computes the cuts itself and uses `obstaclesOf` only for the wall names. If B's faces are taken as `WorldWall.offsets` along the world normal (as `obstaclesOf` builds them, `opening_geometry.dart:131-133,151-159`), then:
    - in a scaled group where B fell back locally, B is drawn `t·s` thick but cut as `t` thick;
    - in a mirrored group where B is not centre-justified, B is drawn on the other side of its centreline (`localOutlineOf`, `wall_geometry.dart:468-482`).
  - D14 blames "`obstaclesOf`'s band", which D3 no longer uses.
- **Amendment:**
  - Specify B's two faces as its **drawn** face lines, by D3's own rule applied to B's `HostFrame`. `WallFaces` builds a frame for every wall anyway.
  - Delete "together with B's cap points on it". On the face line those points are the crossings themselves.
  - Narrow D14 to what is still inherited: B's T cap follows 07's world near face. If D14 is kept as it is, it should name the obstacle wall, not the host.

**T-3 (minor). A face line through two cap points is fragile when the face is short.**
- **Location:** D3, "The face lines are the drawn ones".
- **Evidence:**
  - Without a fallback, an inside face can be close to zero length. Example: a 200 mm wall between two 200 mm walls in a U, where the inside face is `200 − 100 − 100`.
  - The run is then dropped (piece ≤ `wallJoin.linear`), but the other face's `m` ("away from the other face line") and `w` still read that line, whose direction is rounding noise.
  - Elsewhere, an exactly axis-aligned frame picks up round-trip noise (`toLocal` then `toWorld`).
- **Amendment:**
  - Take each face's direction from `toWorld.transformDirection(frame.d)`, normalised. The two faces are parallel under the similarity.
  - Pass each line through one cap point, and project both cap points onto `t` for the extent.
  - Compute `w = |(P_left − P_right)·m|`.

**T-4 (minor). `isUsableHost` lives in a Flutter file.**
- **Location:** D1 (`wall_attach.dart` is "no Flutter, no `dart:ui`, … parametric files only"); D3, Candidates; D4, Neighbours.
- **Evidence:**
  - `isUsableHost` is in `opening_tool.dart:447`, which imports `dart:ui` and Flutter (`:1-7`).
  - The neighbour rule also needs `SymbolComponent`, which is in `lib/symbols/symbol_component.dart`. That file is Flutter-free, but it is not a parametric file.
- **Amendment:** move `isUsableHost` into a Flutter-free file (for example `wall_bands.dart`; it is three lines over `objectLayer`, `layer_commands.dart:69`), or pass it in as an `accept` predicate the way `hostAt` takes one. Also allow `symbol_component.dart` in D1's sentence.

**T-5 (minor). The S-1 anchor changes decision 10's "as in placement", and the human is not shown what that means.**
- **Location:** D8, the app's resolver; D14; the 09c-2 look.
- **Evidence:** with the back-centre anchor, whether a symbol attaches depends on where its back is.
  - A free bed whose back faces away from the target wall attaches only after its plain preview has crossed about `D` (2000 mm) through the wall.
  - A bed turned 90° must cross about `W/2`.
  - Placement attaches on the pointer (D6).
- **Amendment:**
  - Add a D14 bullet that states this.
  - Add a 09c-2 look item: "drag a free bed whose back faces away from a wall".
  - Add a test that pins the result.

**T-6 (nit). Mutant killability.** Every new mutant, M-09c-as to M-09c-be, is killable with the fixtures named. Some fixtures need sharper wording:
- **M-09c-af:** the other piece of the host face is a candidate only if the stem is narrower than `captureWorld − 1 px`, and "right of the stem" must mean `+t`. Otherwise the tie key is never reached and the mutant is equivalent.
- **M-09c-ah (`−w`):** at mid-stem, B's own side faces are candidates (`u < 0` but within capture, `|s| ≤ w_B/2`). The correct answer there is a B face, not null, so the test must assert the winner.
- **M-09c-an:** the raw-pointer variant survives if the press is within `captureWorld` of the back. Name a press on the front half of the body.
- **M-09c-au:** at `(1e5, −7e4)` and 30°, a run of `W − 2e-10` sits close to the rounding noise. The test should assert `L < W` as a precondition. It should also assert `u == L/2` exactly, because a hand-written clamp does not throw, it is only 1e-10 off.
- **M-09c-be:** the `geometry` variant needs a custom `DraftPermissions` with only `geometry` false; `runtime` also denies `structure`. Add "Mirror read-only under runtime", which S-9 listed and which is missing.

**T-7 (nit). Wording.**
- D3 says "a pointer move … allocates nothing", but `attachToWall` returns a `Transform2` and a `q`, and `liveWalls`'s view is allocated per call unless it is cached. Say "O(1), nothing per run", and cache the view in a field.
- `toLocal.linear` is not an API. Write `toLocal.transformDirection(a)`.
- The parenthetical "(these are `drawnCapsOf`'s points)" is true only within rounding. In a mirrored, scaled group with 07's world fallback, `drawnCapsOf` step 1 returns world free caps (`wall_geometry.dart:536`), while the frame holds the local ones. Drop the claim, or qualify it.

## Amendment status

| S | Status |
|---|---|
| 1 | applied, correct in D8 and Testing; stale anchor sentence in D4 (T-1); consequence not surfaced (T-5) |
| 2 | applied, correct for the host; obstacle wall's faces unspecified (T-2); short-face robustness (T-3) |
| 3 | applied, correct; D14 wording (T-2) |
| 4, 5, 6, 7, 8 | applied, correct |
| 9 | applied; fixture detail (T-6) |
| 10 | applied, correct |
