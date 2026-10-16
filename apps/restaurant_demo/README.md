# restaurant_demo

The restaurant embedding's demo host, on `jet_cad_2d_plan` and the
architecture and restaurant kits: two dining areas (Salon, Teras), each a
`PlanController` over `[architectureKit, restaurantKit]` whose plan is built
in code (`lib/samples`). It names neither `jet_cad_floor_plan` nor
`jet_cad_restaurant_symbols`. The service features come back in later tasks
of the restaurant-kit plan. An example and an integration surface, not a
product.

```sh
flutter pub get        # at the repository root (a pub workspace)
cd apps/restaurant_demo
flutter run -d chrome  # or macos, windows, linux, android, ios
```
