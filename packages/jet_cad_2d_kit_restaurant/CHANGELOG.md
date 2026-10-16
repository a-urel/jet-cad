## 0.1.0 (unreleased)

The restaurant kit for the jet_cad_2d plan library (sub-project 4a): the
restaurant symbol catalog of `jet_cad_restaurant_symbols`, ported to the kit
contract's authoring toolkit.

- 69 symbols in six categories (Restaurant Tables, Booths and Lounge, Bar,
  Service, Commercial Kitchen, Outdoor and Decor), keys `restaurant.*` at
  version 1, each with the geometry of the old catalog.
- `restaurantSymbolSource`, the library as a symbol source; `RestaurantSymbols`,
  its keys; `restaurantSymbolDefinitions()`, its definitions by `key@1`.
- `restaurantKit`, the `PlanKit` (id `restaurant`): one symbol source, no
  types, tools or attachments.
- 25 units: every seated symbol is a numbered `table` unit whose capacity is
  its seat count.
- `restaurantNames`: every symbol and category in German and Turkish.
