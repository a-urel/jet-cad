// The live view a kit's tools, grip providers and attachment providers get
// of one plan (spec 2a P1): one per kit per controller, implemented by the
// plan library. And a kit's words at the plan's locale.
import 'dart:ui' show Locale;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show CameraController;

import '../model/kit_names.dart';
import 'attachment.dart';

/// A kit's words at the plan's current locale (spec 2a P5).
abstract interface class KitWords {
  /// The word [wordId] in the locale, else in English, else [wordId] itself
  /// (a missing word shows its id, never nothing).
  String word(String wordId);

  /// The word [wordId] in the locale, else in English, else null.
  String? maybe(String wordId);

  /// The locale the words are in now.
  Locale get locale;
}

/// [KitWords] over a kit's [names], at the locale [locale] answers each
/// time it is read: a change of the plan's language shows at once.
final class KitNamesWords implements KitWords {
  KitNamesWords(this.names, Locale Function() locale) : _locale = locale;

  final KitNames names;
  final Locale Function() _locale;

  @override
  Locale get locale => _locale();

  @override
  String? maybe(String wordId) => names.word(locale.languageCode, wordId);

  @override
  String word(String wordId) => maybe(wordId) ?? wordId;
}

/// What a kit's `shared` object implements to be released with its
/// document (spec 2a P1, lifetimes).
abstract interface class Disposable {
  void dispose();
}

/// One plan, as a kit's code sees it. Every member reads the current
/// document: a kit's factories run once per document (spec 2a P1,
/// lifetimes), so what they keep never outlives it.
abstract interface class PlanServices {
  /// The current document.
  DraftDocument get document;

  /// Its spatial index.
  SpatialIndex get index;

  /// The camera, for apertures in world units.
  CameraController get camera;

  /// The effective object-snap flag: F3 and the editor's snapping option.
  bool get objectSnap;

  /// Every loaded kit's attachment providers.
  AttachmentRegistry get attachments;

  /// This kit's words at the plan's locale.
  KitWords get words;

  /// The current settings of the tool [toolId] (one of this kit's tools
  /// with settings). Throws [ArgumentError] for another id or an `S` the
  /// settings are not.
  S settingsOf<S extends Object>(String toolId);

  /// This kit's one [T] for the current document: [create] runs on the
  /// first call, later calls return the same instance. A [T] that is a
  /// [Disposable] is disposed with its document. Keyed by (kit, `T`), so two
  /// kits asking for the same type get one each.
  T shared<T extends Object>(T Function(PlanServices) create);
}
