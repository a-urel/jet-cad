# jet_cad_2d_kit_architecture

The architecture kit of jet_cad_2d plans: walls, doors, windows and gaps,
room separators, rooms, dimensions, boxes, a furniture library and the
attachment of furniture to wall faces, as one `PlanKit` on the kit contract
(`jet_cad_2d_kit`).

![A sample flat: walls, openings, rooms, dimensions and furniture](https://raw.githubusercontent.com/a-urel/jet-cad/jet_cad_2d_kit_architecture-v0.1.2/packages/jet_cad_2d_kit_architecture/doc/screenshots/architecture_flat.png)

## What it holds

- **Walls** (`WallParams`): a straight run with a thickness, and a
  justification of which side of the run the thickness lies on.
- **Openings** (`OpeningParams`): a **door** (`OpeningKind.door`, with a
  hinge end and a swing side), a **window** or a **gap**, cut into a wall at
  a distance from its start, with a width.
- **Separators** (`SeparatorParams`) and **rooms** (`RoomParams`): a divider
  between two wall faces, and a name on the floor.
- **Dimensions** (`DimensionParams`): a linear dimension between two wall
  ends (`AttachedEnd`) or two fixed points (`FixedEnd`), horizontal or
  vertical, at an offset.
- **Boxes** (`BoxParams`): a rectangle whose outline loses the parts that lie
  strictly inside another box.
- **A furniture library** (`assets/library/furniture.jetlib`) and the wall
  attachment it uses: furniture snaps to and keeps a wall face.

The parameter classes and the type ids (`ArchitectureTypes`,
`ArchitectureTools`) let a host build and edit a plan in code. `buildSampleFlat`
fills a document with the flat the pictures show.

## Use

A host loads it into the plan library (`jet_cad_2d_plan`):
`PlanController(kits: [architectureKit])`. The kit depends on the contract
and the renderer, never on the plan library.

## Screenshots

![One of each of the kit's types: walls, a door, a window, a gap, rooms, a separator, a dimension and boxes](https://raw.githubusercontent.com/a-urel/jet-cad/jet_cad_2d_kit_architecture-v0.1.2/packages/jet_cad_2d_kit_architecture/doc/screenshots/architecture_types.png)

One of each of the kit's types: walls enclosing a room, a door, a window and
a gap in them, a separator splitting the room into two named rooms, a
dimension below and two overlapping boxes.

These pictures are made by `tool/screenshots` in the repository, on the
renderer's own canvas.

## The jet-cad packages

| Package | What it is | Depends on |
|---|---|---|
| [`jet_cad_2d_plan`](https://pub.dev/packages/jet_cad_2d_plan) | The plan library: the editor, the widgets and the host API | the kit contract, the renderer and the engine |
| [`jet_cad_2d_kit_architecture`](https://pub.dev/packages/jet_cad_2d_kit_architecture) | The architecture kit: walls, openings, rooms, dimensions and furniture | the kit contract, the renderer and the engine |
| [`jet_cad_2d_kit_restaurant`](https://pub.dev/packages/jet_cad_2d_kit_restaurant) | The restaurant kit: furniture and service units | the kit contract and the engine |
| [`jet_cad_2d_kit`](https://pub.dev/packages/jet_cad_2d_kit) | The kit contract: types, tools and the symbol library format | the renderer and the engine |
| [`jet_cad_2d_flutter`](https://pub.dev/packages/jet_cad_2d_flutter) | Flutter rendering and interaction | the engine |
| [`jet_cad_2d`](https://pub.dev/packages/jet_cad_2d) | The pure-Dart engine and document model | nothing of jet-cad |

A host that embeds the planner adds `jet_cad_2d_plan` and the kits it loads;
the kit contract, the renderer and the engine come with them, and a host
should not also depend on them directly unless it uses their API itself.

Embedding the floor planner in an app is walked through in the
[host guide](https://github.com/a-urel/jet-cad/blob/main/docs/host-guide.md).

## Support

If jet-cad is useful to you, you can support its development through
[GitHub Sponsors](https://github.com/sponsors/a-urel) or
[Buy Me a Coffee](https://buymeacoffee.com/yazemo).

## License

Apache License 2.0. See [LICENSE](LICENSE).
