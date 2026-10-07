# Q0 — the plan's decimal separator: results

**Asked by the human:** *"Q0 ile devam et"* (2026-10-07).

**Spec:** [2026-10-07-decimal-separator-design.md](../specs/2026-10-07-decimal-separator-design.md),
revision 2. Revision 1 was reviewed independently: *Approved with fixes*,
V-1 to V-19. Q2 is assumed as proposed (N1).

**Plan:** [2026-10-07-decimal-separator.md](../plans/2026-10-07-decimal-separator.md).

**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `0ca8b64`.
**Not merged.**

**Process.** Each of Tasks 1–4 had a fresh implementer, then an
independent reviewer working in its own clone. Task 5 (the docs and the
exit) was the controller's. An independent review of the whole range
closed the slice.

## What a user sees

- **The Page panel** gains *Decimal separator* (*Dezimaltrennzeichen*,
  *Ondalık ayırıcı*): two segments, `1.5` and `1,5`, after the unit menu.
  A change is one undo step. Every room's area and every dimension's text
  is rewritten in that same step, and the rulers follow at the next paint.
- **On paper.** The PDF and PNG print the stored texts, so they follow
  the page's setting.
- **A new plan takes the UI language's separator:**
  - in the floor planner: the launch plan, New and Open sample;
  - for a controller: its empty plan, settled by the first
    `FloorPlanView` that shows it.
- **Existing plans.** A plan that exists keeps its separator in every
  language. A 0.1.0 plan opens as `.`.
- **Schema 8.** Plans are saved at schema 8, which 0.1.0 refuses.

## The tasks

| Task | Commits | Review | Fixes |
|---|---|---|---|
| 1 — the page's field, schema 8 (E1, E2) | `d8d0ef8` | Approved with fixes: the fingerprint comments | `f8cbb94` |
| 2 — the text: formatters, ruler, `pageKey` (T1–T4) | `44e96ef` | Approved with fixes: R-1, three "the UI's separator leaks into an echo" mutants survived the planner suite (only an English UI was tested) | `f9dc265`: Q0-E3, Q0-E3b under a German UI on a `point` page |
| 3 — the Page panel control (P1) | `0c7bfca` | Approved; nothing tested the control's place | `7e3632f`: PS1 asserts the order. Spec P1 corrected: the leak tests run in Turkish only, and PS3 pins the German word |
| 4 — new plans, the settling (N1, N2) | `f100a11` | Approved; a mutant survived in the planner (the first report on a matching page not ending the unsettled state, killed only by the demo) | `f4afa58`: NS6; the first report always ends the state |
| 5 — docs, exit | `314a3e3`, this note | — | — |

Per-task briefs, reports and reviews:
`.superpowers/sdd/2026-10-07-decimal-separator/` (git-ignored), archived
to `docs/superpowers/ledgers/` on merge.

## Named mutants (all red)

| Mutant | Killed by |
|---|---|
| M-Q0-a: the separator out of `RoomType.pageKey`, out of `DimensionType.pageKey`, out of `PageComponent.==` | Q0-S1, Q0-E1 |
| M-Q0-b: each formatter printing `.` always; `formatLength` swapping before it trims | Q0-F1, Q0-DF1, Q0-RA1 (and Q0-S1, Q0-E1, Q0-E2) |
| M-Q0-c: the key not written; not read; `kSchemaVersion` left at 7 | Q0-P1, Q0-C1, Q0-C2, Q0-P3, the version pins, QF3 |
| M-Q0-d: the ruler passing no separator | Q0-R1 |
| M-Q0-e: New always `point` | FS2 |
| M-Q0-e: `documentSeparatorFor` always `point` | NS1, NS2, NS5, FS1–FS3, DQ1, DQ2 |
| M-Q0-e: the launch plan reading `locales.first` | FS1 |
| M-Q0-e: the view not reporting, or not on a swap | NS1, NS2, NS5, DQ1, DQ2 |
| M-Q0-e: `newPlan()` ignoring the language | NS1, DQ2 |
| M-Q0-e: settling a touched plan; settling a loaded plan; settling leaving history or a dirty plan | NS1, NS3, NS4, NS6, DT1 |
| M-Q0-f: the shell setting the page's separator from the UI on open | DT1 (extended) |
| M-Q0-g: the control showing the UI's separator; bound to a constant; the change dropped or wrong; the caption unrecorded, literal or misplaced | PS1–PS3, LK1, LK2 |
| M-Q0-h: the rows' memo not cleared on a page change; the UI's separator substituted into the Area row, the Value row or the notice | Q0-E1, Q0-E3, Q0-E3b |

The reviewers' own mutants are recorded in their reviews. Every survivor
they found is now red, with one exception: a `toString` without the field,
which the testing bar does not ask for.

## Gates (at `f4afa58`)

| Package | Result |
|---|---|
| engine `packages/jet_cad_2d` | `+1253 -2`: the standing comparison reads "1255 tests; the standing failures and skips, exactly". Analyze and format clean. |
| render `packages/jet_cad_2d_flutter` | `+1334 ~1 -7`: the standing comparison reads "1342 tests; the standing failures and skips, exactly". Analyze and format clean. |
| planner `packages/jet_cad_floor_plan` | **1,375 passed**. Analyze and format clean. |
| restaurant symbols | **97 passed**. Analyze and format clean. |
| app `apps/floor_planner` | **212 passed**. Analyze and format clean. `flutter build web` ✓ |
| demo `apps/restaurant_demo` | **37 passed**. Analyze and format clean. `flutter build web` ✓ |
| `tool/ci` | **32 passed**. `check_guide` is green; the guide's code blocks are unchanged. |

The two allocation invariant tests and the goldens are untouched.

**Smoke test** in Chromium, on the web build of the floor planner at this
commit:
- **`de-DE`:**
  - The launch plan's Page panel shows *Dezimaltrennzeichen* with `1,5`
    selected.
  - *Beispiel öffnen* gives `8,45 m²`, `22,00 m²` and `23,04 m²`, and the
    dimensions `4,69`, `4,38` and `14,00`.
  - Zoomed in, the rulers read `5,5 m` and `6,5 m`.
  - A click on `1.5` rewrites them to `23.04 m²` and `5.5 m`, and the
    title gains its unsaved dot.
- **`en-US`:** the sample prints `.` with `1.5` selected.
- No page error and no console error.

## Found, not fixed

- **The engine's two macOS fingerprints** (`generate_document_test`) move
  again with the version, as they did after 12b. They are not
  re-baselined; that is owed on macOS. On Linux the same two names stay
  standing.
- **The leak tests run in Turkish only.** The German caption is pinned by
  PS3.
- **`newPlan()` with no view mounted** takes the language a view last
  reported, which may be stale. This is by design (spec N1) and the host
  guide says so.
- **Two views on one controller** are not supported, as before.
- **`formatLength` above 1e21** prints an exponent form (`1,5e+21`). This
  is unreachable: dimensions cap at 1e15.

## Owed to the human

- **The Q2 ruling.** Should a new plan follow the UI language? This slice
  assumed yes (N1). If the answer is "`.` always",
  `documentSeparatorFor` becomes a constant and the settling goes.
- **A look** in German and Turkish: the Page panel, the plan, the PDF.
- **The macOS re-baseline** of the two fingerprints.
- **The merge**, on the human's word. No release and no tag: schema 8 is
  unreleased on `main` (CHANGELOG *Unreleased*).
