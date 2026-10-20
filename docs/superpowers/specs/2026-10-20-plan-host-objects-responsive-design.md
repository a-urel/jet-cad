# The plan library for a real POS: any object linkable, sections, every device

**Date:** 2026-10-20. **Status:** draft for the human's approval.
**Packages:** `jet_cad_2d_plan` (0.8.1 on pub.dev), `jet_cad_2d_kit` (0.1.0),
`jet_cad_2d_kit_architecture` (0.1.0), `jet_cad_2d_kit_restaurant` (0.1.0);
`apps/restaurant_demo`, `apps/architecture_demo`, `docs/host-guide.md`.

## Intent

The restaurant floor plan is the widget's first real use: monepro, a POS with
a Supabase database, will host `PlanEditor`. The human's words: jet-cad must
not know anything about monepro; a property pane that takes the host's own
widget is enough. This sub-project closes the gaps between what the plan
library offers today and what such a host needs, generically, so any host
(monepro first) can:

- keep its floor plans in its own database and load and save them (already
  possible: plan bytes in, plan bytes out);
- in design mode, link tables, bar counters and sections (Garden, Terrace,
  VIP) to its own records with its own control (a combo) in the property pane;
- know, for every table, which section it stands in, without anyone setting
  it by hand;
- run both modes, design and service, on phones, tablets and desktops with
  the built-in `PlanEditor`;
- keep using what already works: badges on tables (`unitOverlayBuilder`),
  taps (`onUnitTap`, `onUnitDoubleTap`, `onUnitContextMenu`, `onGroupTap`,
  `onFloorTap`), the service events (`onUnitsMoved`, `onLayoutChanged`,
  `onMergeRequested`, `onSplitRequested`) through which moved and grouped
  tables reach the host's database.

monepro's own work (its tables, its plan list, its combo, writing service
changes to Supabase) is the next sub-project, not this one.

## Goals

- **G1 — Any object takes host data.** Not only units: any placed object (a
  symbol such as `restaurant.bar.counter`, a kit object such as a room) can
  carry the host's string map, saved, undone and loaded with the plan, as
  `setUnitData` does for units today.
- **G2 — The property pane takes the host's widget for any object.** When
  exactly one object is selected in design mode, the host's builder is called
  with that object's detail and its widget is shown in the property pane.
- **G3 — Sections.** A table's section is the area its centre stands in,
  computed by the plan, read by the host, and announced when it changes.
- **G4 — Every device.** `PlanEditor` lays itself out for phone, tablet and
  desktop widths, in both modes.
- **G5 — Documented and shown.** The host guide covers all of the above, its
  snippets compiled by the host probe; the restaurant demo shows it working.

## Non-goals

- Anything monepro- or Supabase-specific in jet-cad.
- A new "section" object type: a section is a room of the architecture kit
  (bounded by walls or by separators, so an open garden works).
- Multi-selection inspectors (one selected object only, as today).
- Changing what the service mode does; only how it is laid out on small
  screens.

## Anti-goals (a failure even if it works)

- jet-cad learns a host's vocabulary (no "POS", "table id", "monepro" in any
  API).
- A 0.8.x host breaks: `unitInspectorBuilder`, `setUnitData`, `setUnitsData`,
  `PlanUnitDetail.data` keep their behaviour; a plan saved by 0.8.x opens.
- The desktop layout changes: at desktop widths `PlanEditor` looks and
  behaves as 0.8.1 does (its existing widget and golden tests stay green
  unchanged).
- The frame path allocates per entity (CLAUDE.md non-negotiable): section
  lookup and object data are rebuild-time work, never per frame.

## Constraints

- The repo's non-negotiables (CLAUDE.md): draw order by handle; `Tolerance`
  for geometric decisions; never commit `analysis_options.yaml`; never
  synthesize test output; English code and docs.
- Kit isolation (`tool/ci/check_kit_deps.dart`): a kit names neither the plan
  library nor another kit. The plan library knows no kit's types: whatever it
  learns about areas, it learns through the kit contract (`jet_cad_2d_kit`).
- Host data limits: the same limits as unit data today (`unitDataProblem`).
- Releases are the human's (publish, tags); versions follow the 0.x rule the
  4b wave used (additive → patch, breaking → minor).

## Decisions

The human decided D1–D3, D6's scope and D8's rules; the rest are the
controller's calls, marked *(call)*, open to the human's change while
reading.

### Layout (G4)

- **D1 — Phone.** The plan fills the screen. The editor bar gets a button on
  the left that opens the tools and symbols as a panel over the plan from
  the left, and a button on the right that opens the properties (with the
  host's widget), the layers and the page as a panel from the right.
- **D2 — Tablet (option C of the sketch).** The tool strip stays docked on the
  left, icons only; the right button opens the properties, layers and page
  panel. *(call)* The symbols gallery opens from a symbols icon at the foot
  of the strip, as a left panel.
- **D3 — Desktop.** As today: both side panels docked.
- **D4 — Which layout.** *(call)* The editor's own width decides, not the
  device: phone below 600 logical pixels, tablet from 600 to below 1000,
  desktop from 1000. The host can pass its own breakpoints, or force one
  layout.
- **D5 — Panels on phone and tablet.** *(call)* One panel open at a time;
  tapping the plan, the same button again, or Escape closes it. Opening the
  right panel never moves the camera.
- **D6 — Service mode.** The plan and the service bar fill the screen on
  phone and tablet; *(call)* the host can hand a service side panel widget
  (orders, table detail): docked on the right on desktop, behind the right
  button on phone and tablet. Without one, no right button in service.
- **D7 — Touch.** Design mode must be usable on a 375 × 812 phone: draw a
  wall, place a table from the symbols, select it, change a property, use
  the host's widget. The existing touch tools are used; whatever stops that
  scenario is in scope.

### Objects, data and the inspector (G1, G2)

- **D8 — Host data on any object.** *(call on names)* The controller gains
  `setObjectData(PlanObjectRef object, Map<String, String> data)` and its
  batch form, and a read of every object that carries data. An object is
  named by a reference that survives save and load (its handle is persisted
  and draw-order stable). Units keep their label-keyed API, unchanged; a
  unit's data written either way is the same data.
- **D9 — The inspector for any object.** *(call on names)* `PlanEditor`
  gains `objectInspectorBuilder(BuildContext, PlanObjectDetail)`, called for
  exactly one selected object in design mode: its reference, what it is (a
  unit, a symbol and its key, or a kit type and its id), its label or name
  when it has one, its host data, and for a unit its section (D10). When the
  host passes both builders, `unitInspectorBuilder` keeps units and
  `objectInspectorBuilder` gets the rest; with only the new one, it gets
  everything. The widget sits in the property pane, below the object's own
  properties, on every layout.

### Sections (G3)

- **D10 — The rules (the human's).** A table's section is the area its
  centre stands in. Outside every area: no section. On a boundary: the
  centre decides. Nested areas (a VIP corner inside the Salon): the
  smallest area that contains the centre.
- **D11 — Areas through the contract.** *(call)* A kit type can declare its
  objects' area (a closed outline in the world); the architecture kit's
  room does, from its traced outline. The plan library computes sections
  from declared areas only, so it names no kit.
- **D12 — Reading and hearing it.** *(call on names)* `PlanUnitDetail` gains
  the unit's section: the area object's reference, name and host data, or
  none. The host is told when units' sections change (a table moved, a
  room's walls or separators changed), as one event per change with the
  units whose section changed, so it can write them to its database.

### Documentation and demo (G5)

- **D13 — Host guide.** New sections: the inspector (both builders), object
  data, sections, the layouts and breakpoints, the service side panel;
  every snippet in the host probe (`check_guide`).
- **D14 — Restaurant demo.** The Salon gains two sections (VIP and Garden,
  the garden bounded by separators); the demo's inspector links tables, bar
  counters and sections to the demo's own fake records with a combo; the
  side panel shows each table's section; the demo runs on phone, tablet and
  desktop widths.

## Testing bar

As the repo's: a test lands only if a named mutation turns it red. In
particular:

- sections with rotated and mirrored tables and rooms, a room not at the
  origin, a table on a boundary, nested rooms, a table outside every room;
- layout tests at a phone, a tablet and a desktop width, both modes; the
  desktop tests and goldens of 0.8.1 unchanged;
- object data round trips (set, undo, save, load) on a symbol and a room;
  a plan saved by 0.8.1 opens with its unit data intact;
- the frame-path allocation invariants stay green.

## Left to the builder

The exact names of new types and members within the shapes above, the
panels' look and animation, the icons, how object data is stored in the
document (one component for units and objects, or two) as long as 0.8.x
plans open, and how the plan is split into tasks.

## Open after this

monepro's sub-project: its schema for plans, sections, tables and links, its
plan list, its combo, writing the service events and section changes to
Supabase.
