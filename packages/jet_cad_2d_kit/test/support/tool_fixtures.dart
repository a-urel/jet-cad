// Fixtures for PlanTool and its settings (spec 2a P1, P3): two settings
// types, so a list of tools holds settings of two different `S`.
import 'package:flutter/widgets.dart' show IconData;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:meta/meta.dart';

import 'code_fixtures.dart';

@immutable
final class SlabSettings {
  const SlabSettings({this.width = 900.5, this.finish = Finish.oiled});

  final double width;
  final Finish finish;

  @override
  bool operator ==(Object other) =>
      other is SlabSettings && other.width == width && other.finish == finish;

  @override
  int get hashCode => Object.hash(width, finish);

  @override
  String toString() => 'SlabSettings($width, ${finish.name})';
}

@immutable
final class PostSettings {
  const PostSettings({this.round = false});

  final bool round;

  @override
  bool operator ==(Object other) =>
      other is PostSettings && other.round == round;

  @override
  int get hashCode => round.hashCode;
}

PlanTool slabTool({String id = 'test.slab'}) => PlanTool(
      id: id,
      icon: const IconData(0xe1b1),
      letter: 'S',
      needs: const {Capability.structure, Capability.geometry},
      settings: PlanToolSettings<SlabSettings>(
        initial: const SlabSettings(),
        specs: [
          LengthProperty<SlabSettings>(
            id: 'width',
            read: (s) => s.width,
            write: (s, v) => SlabSettings(width: v, finish: s.finish),
            min: 300,
          ),
          ChoiceProperty<SlabSettings, Finish>(
            id: 'finish',
            values: const [Finish.oiled, Finish.raw],
            read: (s) => s.finish,
            write: (s, v) => SlabSettings(width: s.width, finish: v),
          ),
        ],
      ),
      create: (services) => throw UnimplementedError('not armed in tests'),
    );

PlanTool postTool({String id = 'test.post'}) => PlanTool(
      id: id,
      icon: const IconData(0xe1b2),
      settings: PlanToolSettings<PostSettings>(
        initial: const PostSettings(),
        specs: [
          ToggleProperty<PostSettings>(
            id: 'round',
            read: (s) => s.round,
            write: (s, v) => PostSettings(round: v),
          ),
        ],
      ),
      create: (services) => throw UnimplementedError('not armed in tests'),
    );
