import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'viewport_transform.dart';

/// The camera that shows the whole sheet with `fit`'s 5 % margin (spec D4).
ViewportTransform fitToPage(PageComponent page, Size viewport) =>
    ViewportTransform.fit(sheetWorldRect(page), viewport);
