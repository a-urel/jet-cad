// The app's shadcn look: the zinc palette in the plan's bundled `Roboto`
// (the same face on every platform, as the documents name it), given to the
// `ShadApp` root. The planner's chrome and the app's own dialogs use the
// ancestor `ShadTheme` as they find it; the canvas reads the Material theme
// `ShadApp` derives from it.
import 'dart:ui' show Brightness;

import 'package:shadcn_ui/shadcn_ui.dart';

/// The app's `ShadTheme` for [brightness]: shadcn's zinc, in `Roboto`.
ShadThemeData appShadTheme(Brightness brightness) => ShadThemeData(
      brightness: brightness,
      colorScheme: brightness == Brightness.light
          ? const ShadZincColorScheme.light()
          : const ShadZincColorScheme.dark(),
      textTheme: ShadTextTheme(family: 'Roboto'),
    );
