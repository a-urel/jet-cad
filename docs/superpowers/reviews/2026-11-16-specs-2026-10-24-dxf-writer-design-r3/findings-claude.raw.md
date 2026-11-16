Verification done; writing the findings now.

F1 [major] Containers and transforms
claim: A GroupNode is written as a DXF GROUP only when it carries a component or `exportAsDxfGroup` is set, and its JETCAD `node` record (transform, children, visible) lives in the GROUP's extension dictionary so "a reader restores the tree".
evidence: `GroupNode` in packages/jet_cad_2d/lib/src/document/node.dart defaults `exportAsDxfGroup` to false and may carry no component; the Semantics section gives a group record no home other than a GROUP, so a plain group's transform and nesting are lost, against G4.
fix: State where a component-less, non-GROUP group's `node` record goes (always write the GROUP, or put the record in the document XRECORD).

F2 [major] The plan library
claim: The shared H2 test asserts the DXF bytes of a plan with an `exported: false` object equal the bytes of the same plan with that object deleted.
evidence: "Handles" mints DXF-only handles "above the document's highest handle" and "Version and header" takes `$EXTMIN`/`$EXTMAX` from the document's computed extents; `PlanPageFlows.omittedOf` in packages/jet_cad_2d_plan/lib/src/export/page_flows.dart leaves the omitted group and its leaves in the exported copy, so seed, minted handles and extents differ between the two runs.
fix: Require the writer to compute `$HANDSEED`, minted handles and extents from the written set only, or relax the DXF assertion to a structural comparison.

F3 [major] Entity style columns
claim: "Transparency. Code 440. The engine's 0–255 maps onto DXF's alpha encoding."
evidence: `EntityStore._transparency` in packages/jet_cad_2d/lib/src/store/entity_store.dart is `Int16` because transparency "may itself be BYLAYER or BYBLOCK"; `InstanceNode.transparency` documents `kByBlock` and `kByLayer`; the spec gives no 440 mapping for either sentinel.
fix: Specify the 440 encoding for BYLAYER (omitted) and BYBLOCK, and add "BYLAYER and BYBLOCK transparency swapped" to the mutation list.

F4 [major] Handles
claim: A record with an `OriginComponent` of `source == dxf` is written under that id instead of its engine handle; JETCAD node records carry "its handle, parent"; tests check "draw order matches ascending handle".
evidence: `OriginComponent.id` in packages/jet_cad_2d/lib/src/document/origin_component.dart is a foreign hex string unrelated to the engine handle; the spec never says whether `handle`, `parent`, GROUP membership and the ordering tests use engine handles or written handles, so a parent written under an origin id leaves `parent` unresolvable.
fix: State that every JETCAD reference and every ordering rule uses the written DXF handle, and that the test fixture includes an origin-id record.

F5 [minor] Semantics: the JETCAD data
claim: G4 says every serialisable component is written; the per-handle rule covers entities, GROUPs and BLOCK records, and the document XRECORD's contents are "the builder's".
evidence: `exportPageOf` in packages/jet_cad_2d_plan/lib/src/export/builtin_exporters.dart reads `PageComponent` on `document.rootHandle`, and kit-architecture A8 puts `jetcad.manifest` on the root; root-handle components have no entity, GROUP or BLOCK to hang on.
fix: State that root-handle components are written in the document XRECORD under the same `{ "v": 1, "components": … }` layout.

F6 [minor] Containers and transforms
claim: A group's world transform is baked into its leaves; writing groups as anonymous blocks "is wrong to an AutoCAD user".
evidence: The `GroupNode` doc comment in packages/jet_cad_2d/lib/src/document/node.dart says a group "Exports as an anonymous block rather than a DXF GROUP, because GROUP ... can represent neither nesting nor a transform"; the spec reverses that without saying so.
fix: Record that this decision supersedes the engine comment and that the builder rewrites it.

F7 [minor] Containers and transforms
claim: An instance with shear is written exploded, its definition's leaves transformed into the parent's space, with a Diagnostic.
evidence: `InstanceNode` in node.dart carries colour, lineweight, transparency and linetype that BYBLOCK leaves resolve against, and the Semantics section attaches the instance's JETCAD record to an INSERT that no longer exists; neither the resolution nor the record's home is specified.
fix: State that exploded leaves resolve BYBLOCK to the instance's values and that the instance record is dropped or written on a GROUP.

F8 [minor] Containers and transforms
claim: The INSERT carries the instance's layer, colour, lineweight, linetype and transparency.
evidence: `InstanceNode.linetypeScale` in node.dart is a fifth style field that "multiplies" through nested INSERTs, and the spec's own Entity style columns names code 48; the INSERT list omits it.
fix: Add linetype scale (code 48) to the INSERT's fields.

F9 [minor] The units' colours (H4)
claim: "The units' colours of omitted objects are already excluded by `unitColourUnderlay(…, omitted:)`", matching `omitOwners`' rule "nothing at or beneath an omitted group".
evidence: `unitColourUnderlay` in packages/jet_cad_2d_plan/lib/src/export/unit_colour_underlay.dart skips a unit only when its direct `owner` is in `omitted`; a unit nested deeper than one level under an omitted group keeps its fill.
fix: Either state the one-level assumption as a tested invariant or have the exporter filter fills by ancestry.

F10 [hunch] Version and header
claim: AC1027 "is the oldest version that is UTF-8 throughout" and carries true colour, transparency and lineweight natively.
evidence: not checked against the repository; by the DXF reference AC1021 (R2007) introduced UTF-8 and true colour and transparency date from R2004, so the stated reason for picking R2013 does not hold even if the choice does.
fix: Restate the justification (ezdxf default, every current reader) or drop the "oldest" claim.

F11 [hunch] Tables
claim: A TTF family is written "by font file name plus the family as the `ACAD` 1071 XDATA AutoCAD reads".
evidence: not checked against the repository; in DXF STYLE XDATA the family name is group 1000 and 1071 is the font flags integer.
fix: Say "ACAD XDATA (1000 family, 1071 flags)" so the builder does not write the name into 1071.

F12 [hunch] Verification
claim: Oracle tests carry a tag the default `dart test` excludes via `dart_test.yaml`, and run locally without Python they fail rather than skip.
evidence: Only packages/jet_cad_2d_flutter/dart_test.yaml exists; whether a config-level exclusion combined with a CLI tag selection runs the tests at all depends on the test runner's include/exclude precedence, which the spec does not pin.
fix: Name the exact invocation (a preset such as `dart test -P ezdxf`) the CI job and a developer use.

VERDICT: revise — group records, H2 byte-equality, transparency sentinels and origin-id handles need decisions before planning.
