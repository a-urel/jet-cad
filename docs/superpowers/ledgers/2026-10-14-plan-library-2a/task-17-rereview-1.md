### Finding Verdicts

- **SW5 could not go red under M-09c-bf** — ADDRESSED. The Size-menu decision is now `sizeMenuMembers` (symbol_section.dart, added after `familyMembers`), called from `_symbolSection` in plan_property_panel.dart. SS12 (symbol_section_test.dart) runs it over `familyEntries`, where `test.bed.table` is servable and its entry names the beds' family (premises asserted). It expects the bed to get three members and the servable instance to get none. Dropping `isServableInstance` makes the second expect fail (reported as `Expected: empty`). SW5's title was corrected.
- **Panel-called kit hooks guarded** — ADDRESSED. Spec read/enabled and tool settings go through `_fieldsOrNull`. The title goes through `_titleWordOf`. Either failure makes `_objectSection` or `_settingsSection` return only the `kit-section-failed` box, with one `hookFailed` diagnostic via `addAfterFrame`, which is safe in a build. `_bound` returns empty on failure, so listener, focus and commit paths do not throw. The colour read goes through `_colourOf`: it marks no swatch and logs one diagnostic after the frame. The colour write is wrapped in `recolourCommand`, which throws `KitHookFailure`. `ColourRow._choose` catches it, executes nothing and logs one diagnostic. P-G1, P-G2 and P-G3 (read and write) each assert no exception, the box or row state, exactly one diagnostic, and that the rest of the panel still works. The report names one mutation per guard, each red.
- **Ruling's effect on the colour write** — the effect holds. The write happens while the command is built, so the throw happens before `execute`. The whole recolour is refused. In P-G3 (write) the box processed before the throwing block is also discarded; the test asserts the box colour is still null, the block is unchanged, the undo depth is unchanged and there is one diagnostic.

### New Breakage in the Fix Diff

None Critical or Important.
- Minor: `colourRowBlocked` and the panel still read `parametric.editCapability` raw. The implementer already flags this, and the ruling did not list it.
- Minor: `_choose` logs with `add` rather than `addAfterFrame`. That is fine, because it runs in an event handler.

### Out-of-Scope Observations

None.

### Verdict

**Fix round:** All findings addressed, no new Critical/Important breakage. Tests were not re-run; I checked the report's output and mutation table against the diff.
