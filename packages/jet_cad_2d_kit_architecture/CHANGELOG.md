## 0.1.1

- Depends on `jet_cad_2d_kit: ^0.1.1`.

- The room declares its area: `roomPlanType` carries the new `PlanType.area`
  capability, the room's traced outer ring in world millimetres (null for a
  seed in a wall or an unbounded face).
- The room declares its own name: `roomPlanType` carries the new
  `PlanType.name` capability, the room's `name`.

## 0.1.0

The architecture kit for the jet_cad_2d plan library, moved from
`jet_cad_floor_plan` unchanged in behaviour (sub-project 3a).

- `architectureKit`: the kit's descriptor (id `architecture`), its type and
  tool ids (`ArchitectureTypes`, `ArchitectureTools`), and its `prepare`,
  which gives a plan the plan library makes the separators' DASHED
  linetype.
- Six types: boxes (`BoxParams`), walls (`WallParams`, `Justification`:
  mitred joints, Ts and nodes, cut by their openings), openings
  (`OpeningParams`, `OpeningKind`, `HingeEnd`, `SwingSide`: doors,
  windows, gaps), room separators (`SeparatorParams`: drawn DASHED, left
  out of PDF and PNG exports), rooms (`RoomParams`: traced from walls and
  separators, tinted, named and measured) and dimensions
  (`DimensionParams`, `DimKind`, `DimEnd`, `AttachedEnd`, `FixedEnd`,
  `WallSide`: attached to wall faces or fixed); their grips, properties
  and section words.
- Eight tools: Box (B), Wall (W), Door (D), Window (N), Gap (G), Room (M),
  Separator (S), Dimension (I); the Room tool's "already a room" and the
  Dimension tool's value as status-line notices.
- The furniture library (41 symbols, six size families, the 30
  wall-attached ones marked `attachTo: ['wall-face']`) and the wall-face
  attachment provider.
- A frozen object is absent from the kit's scans: the shared caches (the
  wall bands, the room inputs, the wall faces) and the tools' and grips'
  memos re-check liveness when read, since a freeze changes no document.
- `buildSampleFlat`, a sample flat for a host's `PlanController(build:)`.
- Words in English, German and Turkish.
