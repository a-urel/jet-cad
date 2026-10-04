# restaurant_demo

The restaurant embedding's demo host (spec 14b-2 H10): two dining areas
(Salon, Teras), each a `FloorPlanController` over a plan kept in memory, a
Design / Service toggle, selection by table number and a log of the API's
state. It uses `package:jet_cad_floor_plan/jet_cad_floor_plan.dart` and
`package:jet_cad_restaurant_symbols` only. An example and an integration
surface, not a product.

```sh
flutter pub get        # at the repository root (a pub workspace)
cd apps/restaurant_demo
flutter run -d chrome  # or macos, windows, linux, android, ios
```
