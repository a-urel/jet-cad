# jet_cad_2d_kit_restaurant

The restaurant kit of jet_cad_2d plans: a library of 69 restaurant symbols
(tables, booths and lounge, bar, service, commercial kitchen, outdoor and
decor) on the kit contract (`jet_cad_2d_kit`), 25 of them numbered table
units. It depends on the contract only, never on the plan library.

![The demo's Salon: the kit's tables, booths, bar and host stand](https://raw.githubusercontent.com/a-urel/jet-cad/jet_cad_2d_kit_restaurant-v0.1.0/packages/jet_cad_2d_kit_restaurant/doc/screenshots/restaurant_salon.png)

## What it holds

- **The library**: 69 symbols in six categories — Restaurant Tables, Booths
  and Lounge, Bar, Service, Commercial Kitchen, Outdoor and Decor — keys
  `restaurant.*` at version 1. `restaurantSymbolSource` is the library as a
  symbol source and `RestaurantSymbols` its keys;
  `restaurantSymbolDefinitions()` reads them by `key@1`.
- **25 numbered table units**: every seated symbol is a `table` unit whose
  capacity is its seat count.
- **`restaurantKit`** (id `restaurant`): one symbol source, no types, tools
  or attachments.
- **Words**: `restaurantNames` carries every symbol and category in German
  and Turkish; English is the library's own stored text.

## Use

A host loads it into the plan library (`jet_cad_2d_plan`):
`PlanController(kits: [restaurantKit])`, beside the architecture kit when
the plan draws walls, floors and doors: `kits: [architectureKit, restaurantKit]`.

## Screenshots

![PlanSymbolGallery over the kit's symbols, its sections listed and one open](https://raw.githubusercontent.com/a-urel/jet-cad/jet_cad_2d_kit_restaurant-v0.1.0/packages/jet_cad_2d_kit_restaurant/doc/screenshots/restaurant_gallery.png)

The plan library's symbol gallery over the kit's library: the six restaurant
sections, one of them open, its symbols as thumbnail cells.

These pictures are made by `tool/screenshots` in the repository, with the
demo's own plan.

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
