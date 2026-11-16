F1 [major] Containers and transforms
claim: "every `GroupNode` that carries a component, or whose `exportAsDxfGroup` is set, is written as an unnamed, selectable DXF GROUP of every leaf and INSERT beneath it."
evidence: The document root is a `GroupNode` (`DraftDocument` constructor in `draft_document.dart`) and carries `PageComponent` (`builtin_exporters.dart` reads the page from the root) and, per kit-architecture A8, `jetcad.manifest`; under this rule the whole drawing becomes one GROUP, so clicking anything in AutoCAD selects everything.
fix: Exclude the root (or name which component kinds make a GROUP) and add a mutation "root written as a GROUP" to the suite.

F2 [major] The plan library
claim: The shared H2 test asserts the DXF bytes of a plan with an `exported: false` object equal the bytes of the same plan with that object deleted.
evidence: Handles says minted handles sit "above the document's highest handle" and `$HANDSEED` "lies above every handle written"; `DraftDocument.handleSeed` is persisted by the codec (`json_codec.dart`, key `handleSeed`) and handles are never reissued, so "highest handle" can mean the seed or the highest written record, and only one of those readings makes omit-vs-delete byte-identical when the omitted object holds the top handle.
fix: State that minted handles and `$HANDSEED` derive from the written set only, and make the H2 fixture's omitted object the highest handle so the test can go red.

F3 [minor] Semantics: the JETCAD data
claim: A node record carries "its handle, parent" and GROUP/pointer codes resolve, while Handles says a record with `OriginComponent` of `source == dxf` is written under that id instead.
evidence: `OriginComponent.id` in `origin_component.dart` is a free `String` unrelated to the engine `Handle`; nothing says whether `parent`, `children`, the fill's boundary pointer and GROUP members are written in engine-handle space or written-id space.
fix: Declare one pointer space (written ids) for every handle the JETCAD JSON and DXF codes 330/340 carry.

F4 [minor] Entity style columns
claim: "Transparency. Code 440. The engine's 0–255 maps onto DXF's alpha encoding."
evidence: `EntityRecord.transparency` in `entity_store.dart` is "0..255, or one of kByLayer, kByBlock" (`kByLayer = -1`, `kByBlock = -2` in `style.dart`); the by-layer and by-block cases have no mapping, so an implementation may write 440 for them or omit it.
fix: Say by-layer omits code 440 and by-block writes DXF's ByBlock value, and pin both in the transparency test.

F5 [minor] Containers and transforms
claim: "The instance's own style fields (layer, colour, lineweight, linetype, transparency) go on the INSERT."
evidence: `InstanceNode` in `node.dart` also stores `linetypeScale`, documented as a multiplier that DXF composes through nested INSERTs; the spec's INSERT list omits it although Entity style columns maps linetype scale to code 48.
fix: Add `linetypeScale` to the INSERT's fields (code 48) and to the "group transform baked twice" family of mutations.

F6 [minor] Version and header
claim: "`$EXTMIN`/`$EXTMAX`: `importedExtents` when set, otherwise the document's computed extents."
evidence: `DraftDocument` working extents (`draft_document.dart`, "Working extents, in root space. Derived") include omitted objects' leaves and exclude the minted units' colours, so the written file's extents may not match its contents.
fix: Compute extents from what is written (omissions removed, extra fills included) and say so.

F7 [minor] Handles
claim: An `OriginComponent` with `source == dxf` is reused as the written handle "as the architecture spec says."
evidence: The only spec this document links is the kit-architecture spec, which does not say this; the rule is in the engine architecture spec `2026-07-27-jet-cad-2d-architecture-design.md` ("Export reuses it when present and mints a new identifier otherwise") and in `origin_component.dart`'s doc comment.
fix: Link the 2026-07-27 engine architecture spec where "the architecture spec" is cited.

F8 [minor] The plan library
claim: The H2 test compares "the drawing operators for PDF if its metadata differs."
evidence: `PlanPdfExporter` in `builtin_exporters.dart` uses the `pdf` package, which stamps dates and IDs; the spec names no extractor or oracle for "drawing operators", so the PDF leg of the test cannot be specified or run as written.
fix: Name the comparison (for example `pdf`'s content streams after stripping the info dictionary) or drop PDF to a separate existing test.

F9 [hunch] Entities
claim: The `fill` HATCH's "boundary loop comes from the boundary entity it references" and Later says "the hatch knows its boundary handle."
evidence: not checked; `GeometryPayload` in `geometry_store.dart` holds only `coords` and `scalars`, and `AddRegionCommand` carries the boundary as a separate record, so where the fill stores the boundary handle was not found.
fix: Name the field the writer reads the boundary handle from.

F10 [hunch] Version and header
claim: AC1027 "is the oldest version that is UTF-8 throughout."
evidence: not checked against the repository; AutoCAD's own DXF reference introduces Unicode/UTF-8 text at R2007 (AC1021), which would make the stated reason for choosing R2013 wrong even if the choice stands.
fix: Re-state the reason for R2013 (transparency, lineweight, true colour in 2013-era readers) or correct the version claim.

VERDICT: revise — root-as-GROUP and the omit-vs-delete byte test are contradictions; the rest are gaps a plan would hit.
