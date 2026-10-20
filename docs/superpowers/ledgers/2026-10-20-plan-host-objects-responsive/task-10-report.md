# Task 10 report: the restaurant demo

Status: DONE (with concerns below). Commits: 147b0bc8 (architecture_demo), e7899f06 (restaurant_demo).

## What changed
- Salon sample: five separators + three rooms (Salon, VIP, Garden), each RoomParams/SeparatorParams + ObjectLayer. VIP: separators x=9800 (north wall down to y=4300) and y=4300 (to east wall), enclosing booths 6 and 7. Garden: south wall + separators at y=-2100 and at the two side-wall lines.
- DECISION: no tables added (labels 1-11 and every count stay). The round tables 4/5 (box 1900 mm) cannot fit the A3 sheet's 1800 mm of Garden, so the rect.four tables 2 and 3 were moved into the Garden (y -1250; x 4000 and 10500, clear of the door at x 7300). Sheet unchanged (still centred on origin; SW3 green untouched). Table centres are far from every separator.
- fake_records.dart (T-01..T-13, B-01/B-02, S-SALON/S-VIP/S-GARDEN); RecordPicker combo (key `pos-id`, items `pos-id-<id>`, `pos-id-none` unlinks) replaces the POS-id text field; the demo gives only `objectInspectorBuilder` (Full: bar counters and rooms; Tables: tables; Read only: none; Full keeps no inspector for a table, as before).
- Side panel: "Sections" (`table-sections`, each table's section by record name or "not linked"), a design-only "Link sections" button (`link-sections`; finds each room via the section of a probe table, never a handle); follows `sectionChanges`.
- Responsive: LayoutBuilder; side panel docked from 1300 px window (editor then 1000), else end drawer behind `side-panel-button`, app-bar controls in a horizontal scroller. New strings in en/de/tr.
- architecture_demo: `layout` test seam threaded ArchitectureDemoApp -> DocumentHost -> PlanEditor; DC12 and DC12c (they pin the desktop top bar at 800/1000 px) pass `PlanEditorLayout.desktop` with `// Decided:` (R6). No other architecture_demo test needed it.

## Existing tests edited (each with a `// Decided:` line)
- sample_plans_test: SP1 placements of 2 and 3; SW2 checks the two Garden tables against the Garden box (>= 100 mm) and keeps 1200 mm for the rest.
- look_test DL1: table 2 is in the Garden room, which tints by 0xE5/0xFF; the Bill-pixel expectation reads through that tint (`inRoom`), two places.
- PF3, DH1: the text field became a combo (`pickRecord`, `pickedId` in demo_rig). DH6: Backspace-in-a-text-field now uses the symbol search field (the inspector has no text any more).
- No assertion removed; no count premises changed (still 11 tables). integration_test/pos_test.dart untouched and passes.

## Gates (real runs)
- restaurant_demo: `flutter test` -> `+112: All tests passed!`; analyze `No issues found!`; format exit 0; colour invariant `flutter test test/invariants` -> `+3: All tests passed!`; `flutter build web` -> `Built build/web`.
- architecture_demo: `+176: All tests passed!`; analyze `No issues found!`; format exit 0.
- `flutter test integration_test/pos_test.dart -d macos` -> `+1: All tests passed!` (POS1 ran on macOS).

## New tests (names differ from the brief's DL1-4 because look_test owns DL1-3)
- linking_test: LK1 (=DL1), LK2 (=DL2), LK3 (=DL3). layouts_test: RS1 (=DL4: 375x812, 800x1280, 1440x900, design and service, no exception, correct layout, drawer opens/closes, area switch), RS2 (phone controls scroll).
- Mutations (each run on committed code, reverted, `git diff --quiet` clean): kVipWest=11500 -> LK1..3 red (3 fail); kGardenSouth=-1000 -> LK1 and LK3 red; recordsFor(unit) returns bars -> LK2 red; sectionRecordName ignored -> LK3 red (+1 more); kDockedSidePanel=0 -> RS1 phone x2 / RS2 etc. red (3 fail); inspector null for rooms -> LK2 red.

## Facts / concerns
- flutter_test: `MediaQuery` stays 800x600 under `setSurfaceSize` (dpr 3); only layout constraints change. The demo therefore uses a LayoutBuilder, not MediaQuery.
- A room is selected by tapping its LABEL, not its floor (LK2 taps the VIP label at sheet-relative 12500,7375). Every room's `PlanObjectDetail.label` is the title word "Room", so rooms are told apart only by host data or by their tables.
- Rooms start unlinked (UnitData is internal to the plan package, so the sample cannot pre-link); hence "Link sections".
- Screenshots (test font = boxes): .superpowers/sdd/2026-10-20-plan-host-objects-responsive/restaurant_desktop.png and restaurant_phone.png (git-ignored).
- Concern: the Garden tables 2 and 3 now sit outside the room, so the "tables lie inside the room" intent of SW2 is split in two assertions; the sheet's bottom margin below the Garden is 75 mm.
- Concern: kDemoTableIds still lists salon-1..11 (Link tables unchanged); the fake `T-` records are a separate vocabulary used by the combo; an id outside the list (e.g. salon-3 from Link tables) is shown as an extra item.
