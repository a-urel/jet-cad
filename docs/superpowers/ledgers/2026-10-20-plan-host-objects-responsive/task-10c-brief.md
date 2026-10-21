### Task 10c: An object's own name, and the plan's sections (gaps Task 10 found)

**Why:** spec D9: the detail carries "its label or name when it has one". Today a room's `PlanObjectDetail.label` is the type word "Room" (`_titleOf`, plan_controller.dart ~1666), so a host cannot tell VIP from Garden. And a host cannot list the sections it must link (`objectDetails` lists only objects that carry data); the restaurant demo works around it with a probe table (apps/restaurant_demo/lib/pos_links.dart:73-90, `kSectionProbeTable`).

**Interfaces:**
- `jet_cad_2d_kit`: `PlanType({..., String? Function(T value)? name})`, `bool get hasName`, `String? nameOf(DraftDocument document, Handle group)` — erased-operation pattern as `areaOf`/`colourOf`. CHANGELOG line.
- `jet_cad_2d_kit_architecture`: `roomPlanType` declares `name: (p) => p.name`. CHANGELOG line.
- `jet_cad_2d_plan`: `PlanObjectDetail.label` for a type object = `nameOf(...)` when non-empty, else today's title word. New `List<PlanObjectDetail> get sectionDetails` on PlanController — every root object of a type with `hasArea`, in draw order, data or not (an area that is currently null still listed). Barrel/CHANGELOG as needed.

**Tests:**
- kit `NM1 a type without name: hasName false, nameOf null`; `NM2 nameOf returns the capability's value for the group's component`.
- architecture `RN1 roomPlanType.nameOf is the room's name`.
- plan (zone kit with a name capability) `SD1 sectionDetails lists every area object in draw order, with and without data`; `SD2 a type object's detail label is its name; a type without name keeps its title word`; integration with real rooms `SD3 a Salon/VIP/Garden plan: sectionDetails labels are the three names`.
- A mutation per package turning its new test red.

**Demo:** apps/restaurant_demo — remove the probe (`kSectionProbeTable` and the probe lookup); "Link sections" (or link on load) uses `sectionDetails` by name; the inspector shows the room's name; its tests keep their assertions (update only the probe's own tests, with `// Decided:`).

**Guide:** docs/host-guide.md §6.10 (labels: a unit's label, an object's own name, else its type word) and §6.11 (listing sections with `sectionDetails`; a room is selected by tapping its label, its floor picks nothing); every new dart block in the probe.

**Gates:** kit, architecture, plan and integration (--enable-vmservice), restaurant demo, check_kit_deps, check_guide, the host probe.
