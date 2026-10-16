### Task 9: POS1 and the builds

**Files:** `apps/restaurant_demo/integration_test/pos_test.dart`.

- [ ] POS1 on macOS (`flutter test integration_test/pos_test.dart -d
  macos`): open the Salon; Service; statuses on three tables; merge two;
  link a POS id; save the layout, move a table, restore; export PNG
  through a temp-dir files/export hook; screenshot via `RepaintBoundary`
  to PNG; copy it to
  `docs/superpowers/notes/2026-10-16-restaurant-kit-pos.png`. Transcribe
  the run's last lines.
- [ ] Builds: `flutter build macos`, `flutter build web`, `flutter build
  ios --simulator --no-codesign`; `flutter build apk --debug` if `flutter
  doctor` shows an Android toolchain, else record why. Transcribe.
- [ ] Commit `test(restaurant_demo): POS1 on macOS; the builds`.

