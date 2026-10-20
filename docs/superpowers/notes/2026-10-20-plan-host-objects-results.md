# POS-host sub-project: results

Branch `feat/pos-host` (cut from `main` 42cd3e09), done on the branch, **not
merged**. Spec:
[2026-10-20-plan-host-objects-responsive-design.md](../specs/2026-10-20-plan-host-objects-responsive-design.md);
plan: [2026-10-20-plan-host-objects-responsive.md](../plans/2026-10-20-plan-host-objects-responsive.md).
Executed task by task with Sonnet implementers and no reviewer subagents (the
human's rule): the controller read every diff, ran its own mutation and
re-ran the gates. Phone picture of the demo:
[2026-10-20-plan-host-objects-phone.png](2026-10-20-plan-host-objects-phone.png)
(restaurant demo, 375 x 812, design mode, the Salon with its dashed VIP and
Garden sections, real Roboto).

## What was built, per goal

- **G1, host data on any object.** `PlanController.objectDetails` (the objects
  that carry data), `objectDetailOf(PlanObjectRef)`, `setObjectData`,
  `setObjectsData`; `PlanObjectRef` (opaque, `==` by handle), `PlanObjectKind
  {unit, symbol, type}`, `PlanObjectDetail {ref, kind, typeId, symbolKey,
  label, data}`. Objects are root unit instances, root kit-type groups and
  root symbol instances. A unit's data is the same data either way (0.8.1
  plans open unchanged; `unitInspectorBuilder`, `setUnitData`,
  `PlanUnitDetail.data`, `unitChanges` keep their behaviour). The host never
  receives a `Handle`.
- **G2, the inspector for any object.** `PlanEditor.objectInspectorBuilder`
  (`ObjectInspector`, `Key('object-inspector')`) in the property pane for one
  selected object; with `unitInspectorBuilder` also given, units keep going
  to that one.
- **G3, sections.** Kit contract: `PlanType` gains the optional `area`
  capability (`hasArea`, `areaOf`) and the optional `name` capability
  (`hasName`, `nameOf`); `roomPlanType` declares both (traced ring, `name`).
  Plan library: `PlanUnitDetail.section` (the smallest area object whose
  outline contains the unit's centre, boundary inside),
  `PlanController.sectionChanges` (`PlanSectionChange`, labels to new
  sections; design, and after a layout move in service),
  `PlanController.sectionDetails` (every object of an area type, draw order),
  `PlanObjectDetail.label` = own name, else the type's title word.
- **G4, every device.** `PlanEditorLayout {phone, tablet, desktop}`,
  `PlanLayoutBreakpoints(tablet: 600, desktop: 1000)`, `PlanEditor.breakpoints`
  and `.layout`; drawers (one at a time; barrier tap, the same button or
  Escape close; a tool or symbol pick closes the phone/tablet left drawer);
  the tablet's icon-only tool strip; `PlanEditor.serviceSidePanel` and the same
  on `PlanServiceView` (docked 320 on desktop, a 300 drawer behind
  `service-right-button` otherwise); a touch double tap on the canvas ends a
  wall or polyline chain.
- **G5, documented and shown.** Host guide sections 6.10-6.12 and 14
  (`check_guide`: 35 blocks); the restaurant demo's Salon gets Salon, VIP and
  Garden rooms, a combo inspector over `fake_records.dart`, a side panel with
  the table's section, at phone, tablet and desktop widths.

## Tasks and commits (base 42cd3e09)

| Task | Commits |
|---|---|
| 1 PlanType area | da3fe0b8 |
| 2 room area | c55185f0 |
| 3 host data on any object | 3eeb0ae9, b8800b7f, 5b697929 (ref doc fix) |
| 4 sections | 1f4fd331, 6a1fba07 (area tie band fix) |
| 5 object inspector | f458ba1c |
| 6 phone and tablet layout | 8dba22f8 |
| 7 service mode on phones and tablets | 35fb2868, 20d46bb9 (SL7) |
| 8 designing on a phone | 64299e80, 004e2ae1, 92718f5d, 0ce06342, a081cfd3 |
| 9 host guide | 4f96b02a |
| 10 demo | e7899f06, 147b0bc8 |
| 10c name capability, sectionDetails | 8d8d60ca, 32701b77 (import fixup), dd1f2c06, 847ccd16, df384066, 109853a0, e6b3b064 (guide) |
| 10b touch double tap | e42a1307, 29617430 |
| 11 close | this commit |

## Rulings and what each costs if wrong

- **R1** `jet_cad_2d_integration` depends on `jet_cad_2d_kit_restaurant`
  (unpublished test package): one extra dependency line.
- **R2** Sections in service come from the same source as the unit details:
  a host could miss a section change made in service.
- **R3** Frozen walls still bound a room's area (the frozen set is session
  state): a table's section may differ from the drawn room only while a wall
  is frozen.
- **R4** The room-area memo keys on `commands.stateId`, which `notifyLoaded`
  does not move; checked: `load()` builds a new document, so no stale
  sections (SC10 green, no fix).
- **R5** A `PlanObjectRef` is valid for its plan only (documented, not
  prevented): a careless host that keeps refs across loads may address an
  unrelated object.
- **R6** Breakpoints stay 600/1000; three existing editor test files (plus
  the architecture demo's top-bar tests) pass `layout: PlanEditorLayout.desktop`,
  no assertion touched: a 0.8 host with a window narrower than 1000 px gets
  the tablet layout after upgrading (hence the minor bump below).
- **R7** Escape closes a drawer except while focus is in an editable text:
  Escape in a drawer text field does nothing to the drawer.
- **R8** Optional `name` capability and `sectionDetails`: one more optional
  kit capability; without it a room's label stays the word "Room" and a host
  cannot list sections.

## Deferred minors

- Re-picking the already-active tool or symbol leaves a phone drawer open
  (nothing changes).
- A double-tap-then-drag ends a chain at the second down; a deliberately tiny
  wall placed within 300 ms / 40 px reads as a double tap.
- A room is selected only by its label (its floor picks nothing): a guide
  note, not a fix.
- The guide header still reads 0.8.0 (versions are not bumped here).

## For the human

1. **Proposed versions (0.x rule: additive is a patch, a behaviour change a
   minor).**
   - `jet_cad_2d_kit` **0.1.1** (area and name capabilities, additive).
   - `jet_cad_2d_kit_architecture` **0.1.1** (the room declares area and name,
     additive).
   - `jet_cad_2d_plan` **0.9.0** (R6: a `PlanEditor` narrower than 1000 px now
     lays out as tablet or phone, a behaviour change for 0.8 hosts; the rest
     is additive). It uses `PlanType.area` and `name`, so its pubspec floor on `jet_cad_2d_kit` (still `^0.1.0` on the branch) must rise to `^0.1.1`; release the kit first. The same holds for `jet_cad_2d_kit_architecture` (kit floor) and the demos' floors.
   - `jet_cad_2d_kit_restaurant`: unchanged (`git diff main...HEAD` over the
     package is empty).
   - `jet_cad`, `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_gpu`:
     unchanged (the same diff is empty for each).
   - The CHANGELOG lines sit under `## Unreleased` in the three packages;
     moving them under a version is part of the release.
2. **Open questions.**
   - Double-tap-then-drag on touch: it ends the chain at the second down
     (today's rule); should a drag after the first tap start a new segment?
   - Tiny walls: a wall deliberately shorter than 40 px placed within 300 ms
     reads as a double tap and ends the chain. Acceptable, or shorten the
     window?
   - A room is picked by its label only (its floor picks nothing): should a
     click on the floor select the room?
   - Frozen walls bound areas (R3): is a table's section allowed to follow a
     wall that is frozen, or must frozen walls drop out (3a's open
     frozen-neighbour question)?
3. **Next sub-project:** monepro's integration (the POS app takes the
   inspector, sections and the phone layout through the released versions).
