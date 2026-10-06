# Changelog

The four packages a host depends on — `jet_cad_2d`, `jet_cad_2d_flutter`,
`jet_cad_floor_plan`, `jet_cad_restaurant_symbols` — are released
together, under one version and one git tag. None is published to
pub.dev: a host depends on them by git (see
[docs/host-guide.md](docs/host-guide.md)).

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
  caption; selection by number; tap, long-press and context-menu
  callbacks; numbering warnings as values;
- the service layout saved and restored as JSON; a view that forbids
  moves; touch;
- English, German and Turkish built in, chosen by the host's locale;
- `jet_cad_restaurant_symbols`: 69 restaurant symbols with German and
  Turkish names.

**Known limits.**

- The plan's own text (dimensions, room areas, the rulers, the PDF and
  PNG) keeps `.` as its decimal separator in every language.
- The German and Turkish text has not been read by native speakers.
- `packages/jet_cad` (the dormant OCCT 3D line) and `apps/dev_harness`
  are not part of the release.
