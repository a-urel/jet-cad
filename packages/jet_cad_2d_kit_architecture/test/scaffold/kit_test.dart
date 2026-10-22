// Spec 3a C2: the kit's descriptor. Its id and version (the pubspec's), its
// words and its prepare, and the type and tool ids of A7.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_architecture/src/separator_linetype.dart';
import 'package:jet_cad_2d_kit_architecture/src/words/words.dart';

void main() {
  test(
      'SC-ids the kit is architecture at its pubspec\'s version, with its '
      'words and its prepare; its type and tool ids are the spec\'s (C2)', () {
    expect(architectureKit.id, 'architecture');
    // M-SC-ver: the kit's version moved without the pubspec's.
    expect(architectureKit.version, '0.1.1');
    expect(File('pubspec.yaml').readAsStringSync(),
        contains('\nversion: ${architectureKit.version}\n'));
    expect(identical(architectureKit.names, architectureNames), isTrue);
    // M-SC-1: the kit without its prepare.
    expect(architectureKit.prepare, ensureDashedLinetype);
    expect([
      ArchitectureTypes.box,
      ArchitectureTypes.wall,
      ArchitectureTypes.opening,
      ArchitectureTypes.separator,
      ArchitectureTypes.room,
      ArchitectureTypes.dimension,
    ], [
      'architecture.box',
      'architecture.wall',
      'architecture.opening',
      'architecture.separator',
      'architecture.room',
      'architecture.dimension',
    ]);
    // M-SC-ids: a tool id renamed.
    expect([
      ArchitectureTools.box,
      ArchitectureTools.wall,
      ArchitectureTools.door,
      ArchitectureTools.window,
      ArchitectureTools.gap,
      ArchitectureTools.room,
      ArchitectureTools.separator,
      ArchitectureTools.dimension,
    ], [
      'architecture.box',
      'architecture.wall',
      'architecture.door',
      'architecture.window',
      'architecture.gap',
      'architecture.room',
      'architecture.separator',
      'architecture.dimension',
    ]);
  });
}
