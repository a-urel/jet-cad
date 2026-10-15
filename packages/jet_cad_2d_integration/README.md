# jet_cad_2d_integration

Not published. The tests that run the architecture kit
(`jet_cad_2d_kit_architecture`) inside the plan library's widgets
(`jet_cad_2d_plan`): the kit's tools on the canvas, its property sections,
the layer rules for its objects, its grips through the select tool, the
wall attachment end to end, and the export of rooms and separators.

A kit may not name the plan library (umbrella A1,
`tool/ci/check_kit_deps.dart`), and the plan library's own tests stay free
of any domain, so these tests live here, in a package that imports both
through their public libraries only, as a host does (spec 3a C6). `lib/`
holds the fixtures, `test/` the tests.

Run with `flutter test --enable-vmservice`: the paint-allocation invariant
reads the VM's allocation profiler.
