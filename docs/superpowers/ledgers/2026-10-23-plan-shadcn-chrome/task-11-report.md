# Task 11 report
Commits: see git log (feat(kit_architecture): Lucide icons; test(plan): the kept-Material scan...).
Icon pairs: kit wall maximize->brickWall; room meeting_room_outlined->house; box crop_din->squareDashed; separator horizontal_rule->minus; door door_front_door_outlined->doorClosed; window window_outlined->appWindow; gap space_bar->space; dimension straighten->ruler. Plan generic tools: north_west->mousePointer2, horizontal_rule->minus, polyline->route, crop_square->square, circle_outlined->circle, looks->spline, title->type. Editor symbols button: category_outlined->shapes.
Restaurant kit: grep "Icons\." lib prints nothing.
Migrated leftovers: plan_editor chrome-symbols-button Material IconButton -> PlanIconButton (same key; label/tooltip = tabSymbols); kits/section_boundary Theme.of(...).colorScheme.error -> planShadThemeOf.colorScheme.destructive.
Kept (allowlisted): CircularProgressIndicator in symbol gallery (shadcn has no spinner); panel-root transparent Materials (property/page/layer panels).
Mutations: IconButton in plan_layer_panel -> KM1 red ("plan_layer_panel.dart|IconButton: found 1, kept null"); Icons.remove in generic_tools -> KM2 red; removing Scrollbar -> KM1 "kept but unused".
Gates: plan 1845 passed/13 skipped, analyze clean, format clean; integration, restaurant_demo, architecture_demo, tool/ci, api boundary, kit tests (661), check_kit_deps green.
No rulings added (no existing test changed).
