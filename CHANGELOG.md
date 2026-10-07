# Changelog

The four packages a host depends on — `jet_cad_2d`, `jet_cad_2d_flutter`,
`jet_cad_floor_plan`, `jet_cad_restaurant_symbols` — are released
together, under one version and one git tag. None is published to
pub.dev: a host depends on them by git (see
[docs/host-guide.md](docs/host-guide.md)).

## Unreleased

On `main`, not yet released.

- **The plan's decimal separator** (Q0): a plan carries its own decimal
  separator, `.` or `,`, chosen on the Page panel (*Decimal separator*).
  Dimension text, room areas and the rulers print with it, and so do the
  PDF and PNG; the change is one undo step. A new plan takes the UI
  language's separator (`,` in German and Turkish); an empty plan a
  `FloorPlanController` creates takes the language of the first
  `FloorPlanView` that shows it. A plan that exists keeps its own.
- **Schema 8.** The JSON codec writes schema 8 (the page's
  `decimalSeparator`). A schema-7 plan opens unchanged, as `.`; **0.1.0
  refuses a plan saved by this version**, and says why, so every terminal
  of a restaurant must move together. The bundled symbol libraries are
  re-encoded.
- **Breaking for a host's own strings:** `FloorPlanStrings` gains the
  abstract `pageDecimalSeparator`; a class that implements or directly
  extends `FloorPlanStrings` must add it (a subclass of a built-in
  language inherits it).
- `jet_cad_2d`: `PageComponent.decimalSeparator`, `DecimalSeparator`,
  and `formatLength(…, decimalSeparator:)`.
- **The GPU renderer moves to its own package, `jet_cad_2d_gpu`.**
  `jet_cad_2d_flutter` no longer depends on `flutter_scene`, so a host's
  graph holds no `flutter_scene`, `flutter_gpu`, `flutter_gpu_shaders`
  or `scene`, and runs no build hook: no shader compiler at build time,
  and about 12 MB less in a web build. **The host's Flutter floor falls
  from 3.47 back to 3.44**, as the host guide says (measured by
  `flutter pub downgrade`). `jet_cad_2d_gpu` is not a host package: it is
  the dev harness's, and a host never depends on it. Nothing a host
  draws changes: the GPU path was only ever chosen by the harness.
- **Breaking for code that imported the GPU types** from
  `jet_cad_2d_flutter`'s barrel (no host did): `GpuDrawBackend`,
  `ResidentGeometry`, `ResidentPatch`, `debugSetGpuAvailable` and
  `uploadResidentCollection` now come from
  `package:jet_cad_2d_gpu/jet_cad_2d_gpu.dart`, which also exports
  `installResidentGpu`, `gpuAvailable`, `debugSetGpuFactory` and
  `GpuContextFactory`; the GPU is used only after `installResidentGpu()`.
  `ResidentGeometry`'s four layout statics stay in `jet_cad_2d_flutter`,
  as `ResidentLayout`.
- `jet_cad_2d_flutter` gains the GPU registry (`ResidentGpu`,
  `registerResidentGpu`, `registeredResidentGpu`), `ResidentLayout`,
  `kFloatsPerInstance` and `InstanceFieldOffset`.

## 0.1.0

The first release a point-of-sale application can pin.

**The 2D engine (`jet_cad_2d`) and its renderer (`jet_cad_2d_flutter`).**
A document model of entities, blocks, layers and styles; commands with
undo and redo; a spatial index, hit-testing and snapping; a
deterministic, versioned JSON codec (schema 7); rendering with a tile
cache, text, dashes and fills; selection, grips and the drawing tools;
the parametric layer that walls, openings, rooms and dimensions are
built on.

**The floor planner (`jet_cad_floor_plan`)**, sub-projects 01–13 and
09c: the app shell, its panels and tools; page, grid and rulers; walls
with cleaned-up junctions, doors and windows that cut them, rooms with
their area, associative dimensions; the symbol library with its palette
and wall-aware symbols; layers; the document lifecycle; PDF and PNG
export and printing.

**The restaurant embedding**, sub-project 14 and slice 14d:

- `FloorPlanController` and `FloorPlanView`: a **design** mode (the
  editor) and a **selection** mode (service) on a copy of the plan, which
  service moves never change;
- tables identified by their numbers; statuses with a colour and a
  caption; selection by number; tap and context-menu callbacks (a
  secondary click, or a long press when the host chooses); numbering
  warnings as values;
- table groups: merged and split by the host, framed and labelled, a
  member selecting and moving its whole group, group statuses;
- the service layout saved and restored as JSON; a view that forbids
  moves; touch;
- a dark theme: the planner follows the host's theme, and a light page
  is shown on a dark canvas;
- English, German and Turkish built in, chosen by the host's locale;
- `jet_cad_restaurant_symbols`: 69 restaurant symbols with German and
  Turkish names.

**Known limits.**

- The plan's own text (dimensions, room areas, the rulers, the PDF and
  PNG) keeps `.` as its decimal separator in every language.
- The German and Turkish text has not been read by native speakers.
- `packages/jet_cad` (the dormant OCCT 3D line) and `apps/dev_harness`
  are not part of the release.
