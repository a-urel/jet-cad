# Changelog

## Unreleased

- `ParametricCatalog.typeIds` and `ParametricCatalog.typeIdOf(target,
  group)`: the registered type ids in registration order, and the type id
  that names a group's live object by the engine's own rule (null when it
  is none).
- `PartialMutationError`, a `StateError` with the same message, is what a
  failed rollback now throws: `CompoundCommand.apply`, and a
  `ParametricEdit` undoing its edit, its reference cascade or its
  regeneration. A caller catching `StateError` is unaffected.
- `ComponentRegistry.loadJson(json, diagnostics: list)` and
  `DraftDocumentCodec.decode(…, keepUnreadableComponents: true)`: a
  component whose factory throws is kept raw, as an unknown type is, and
  reported as a `component.unreadable` diagnostic naming its handle,
  instead of failing the load. Off by default. A value of the type
  attached to that handle later is the one a save writes.
- `ParametricSystem(document, catalog, isFrozen: …)` leaves a frozen
  object out of every survey, view, regeneration, `drift()` and
  `diagnostics()`, as a plain group, and calls none of its type's hooks
  for it. `ParametricSystem.probe(handle)` runs one live object's hooks in
  isolation, changing nothing, and returns the first error, or null.
- `NonLiveWriteError`, a `StateError` with the same message, is what an
  edit now throws when it writes a registered parametric type's component
  on a handle that is not a live root-level group (a frozen object
  included). It names the `handle` and the `typeId`. A caller catching
  `StateError` is unaffected.
- `ParametricType.instances(view, self)` (default: none) lets a type
  generate symbol instances beside its entities. Each
  `GeneratedInstance(definition, transform, attributes: […])` becomes an
  `InstanceNode` child of the object's group, on the object's layer, and
  each `GeneratedAttrib(tag, text, payload)` an ATTRIB the instance owns,
  on layer 0, BYBLOCK. The planner matches instances by position and
  ATTRIBs by tag, so a regeneration keeps a seat's handle and everything
  on it, and an unchanged output plans nothing. An output naming no live
  definition throws `GeneratedDefinitionError` while planning: the edit is
  refused, `probe` returns it and `drift()` throws it. Every
  `InstanceNode` child of an object's group is now that object's
  generated instance: a type that generates none removes it on its next
  regeneration.
- The edit guard covers generated instances. Moving, removing,
  re-pointing or re-layering one, or editing or removing its ATTRIBs, is
  refused with `GeneratedGeometryError`. A components-only write on one
  passes and regenerates nothing. Any node or entity added into a live
  object by anything but the planner is refused, and so is an entity added
  onto one of its generated instances. This includes a `GroupNode`: until
  now a group added into an object passed. A nested group a file brought in
  stays editable. Removing an object's subtree (a dissolve, a reference
  cascade) also removes the entities its instances own, so no ATTRIB is
  left behind.

## 0.7.2

Documentation and funding only; no code change. Plans are stored as in
0.7.1.

- The README links the renderer (`jet_cad_2d_flutter`), the planner
  (`jet_cad_floor_plan`) and the host guide, and says that a host adds
  only the planner: it brings the engine and the renderer with it.
- Funding links (GitHub Sponsors, Buy Me a Coffee) in the pubspec.

## 0.7.1

The first release on pub.dev. The code is the engine of jet-cad 0.7.0
(git tag `v0.7.0`) unchanged; what changed is how it is packaged:

- The package carries its own LICENSE (Apache 2.0), a README written for
  pub.dev and a runnable example (`example/jet_cad_2d_example.dart`).
- The SDK constraint is `^3.6.0` (was `^3.5.0`): the floor pub workspaces
  document for their members.
- The repository URL points at `https://github.com/a-urel/jet-cad`.
- Doc comments that named a member out of scope now resolve in the API
  reference.

From this release on, `jet_cad_2d` has its own version on pub.dev and its own
git tags (`jet_cad_2d-v0.7.1`). Before it, the engine was released with the
other jet-cad packages under one version; that history is in the repository's
[CHANGELOG.md](https://github.com/a-urel/jet-cad/blob/main/CHANGELOG.md).
