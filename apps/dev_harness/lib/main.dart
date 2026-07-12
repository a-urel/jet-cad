import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'harness_page.dart';

void main() {
  runApp(
    ShadApp(
      theme: ShadThemeData(
        colorScheme: const ShadZincColorScheme.dark(),
        brightness: Brightness.dark,
      ),
      home: const HarnessPage(),
    ),
  );
}
