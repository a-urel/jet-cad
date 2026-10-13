# jet-cad

jet-cad is a parametric floor planner for Flutter, built to be embedded in an
application such as a restaurant's point of sale. It is a Dart workspace of
three packages on pub.dev:

| Package | What it is | Depends on |
|---|---|---|
| [`jet_cad_floor_plan`](https://pub.dev/packages/jet_cad_floor_plan) | The embeddable floor planner and its host API | the renderer and the engine |
| [`jet_cad_2d_flutter`](https://pub.dev/packages/jet_cad_2d_flutter) | Flutter rendering and interaction | the engine |
| [`jet_cad_2d`](https://pub.dev/packages/jet_cad_2d) | The pure-Dart engine and document model | nothing of jet-cad |

A host that embeds the planner adds only `jet_cad_floor_plan`; the other two
come with it, and a host should not also depend on them directly unless it
uses their API itself.

Embedding the floor planner in an app: [docs/host-guide.md](docs/host-guide.md).

## Support

If jet-cad is useful to you, you can support its development through
[GitHub Sponsors](https://github.com/sponsors/a-urel) or
[Buy Me a Coffee](https://buymeacoffee.com/yazemo).

## License

JetCAD is licensed under the [Apache License 2.0](LICENSE). The dormant
`packages/jet_cad` line depends on Open CASCADE Technology (OCCT), which is
distributed under the GNU LGPL v2.1 with the Open CASCADE Exception. OCCT remains a third-party dependency with its own
license; JetCAD's Apache 2.0 license is independent of OCCT's license. See the
[LICENSES](LICENSES/) directory for third-party license information.