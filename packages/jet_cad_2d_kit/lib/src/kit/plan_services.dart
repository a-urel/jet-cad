// The live view a kit's tools, grip providers and attachment providers get
// of one plan (spec 2a P1): one per kit per controller, implemented by the
// plan library. And a kit's words at the plan's locale, and (spec 2b S2) the
// symbol definitions a kit's types place.
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show CameraController;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../model/kit_names.dart';
import 'attachment.dart';
import 'symbols_state.dart';

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
/// A symbol definition a kit's code uses (spec 2b S2): a parametric type
/// generates instances of it (E5), a tool places it. Every value is in the
/// definition's space.
final class SymbolDefinitionRef {
  const SymbolDefinitionRef(
      {required this.handle,
      required this.add,
      required this.basePoint,
      required this.top});

  /// The definition's handle in the current document: a definition it
  /// holds, or the one [add] adds.
  final Handle handle;

  /// One command that adds the definition, its leaves and its
  /// `jetcad.symbol` and `jetcad.unit` (the plan's symbol placer's), or
  /// null when the document holds the definition. Executed once, before
  /// or with the first command that uses [handle].
  final DraftCommand? add;

  /// The definition's base point.
  final Vector2 basePoint;

  /// The definition's first leaf's box when that leaf is a closed
  /// polyline or a circle (a unit's served top), else the definition's
  /// box. `unitLabelAttrib`'s `top`.
  final Aabb2 top;
}

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

  /// The symbol [key], a full versioned key (`kit.kind.variant@N`), as a
  /// definition of the current document: the one it holds, or one to add.
  /// Null when no loaded library has [key], or while the libraries load or
  /// after they failed ([symbolsState] tells which).
  ///
  /// A ref with an `add` took its handles from the document's seed, one
  /// per definition and per leaf: call this once per placement, never per
  /// preview. A second call for [key] before that `add` executes returns
  /// the same ref, `add` included (spec 2b S2): execute it once.
  SymbolDefinitionRef? symbolDefinition(String key);

  /// The symbol libraries' state: the plan's own listenable, so a tool can
  /// wait for `ready`.
  ValueListenable<SymbolsState> get symbolsState;
}
