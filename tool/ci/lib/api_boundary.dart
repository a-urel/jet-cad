// The plan library's API boundary: the chrome is built with shadcn_ui, but
// no `Shad*` or `LucideIcons` type is part of what the library exports, so a
// host that does not use shadcn_ui is never asked to know it. The check
// resolves the library's barrel and walks every exported element.
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// The packages whose types the plan library's API must not mention.
const Set<String> defaultForbiddenPackages = {
  'shadcn_ui',
  'lucide_icons_flutter',
};

/// The library at [barrelUri] (`package:...`), resolved by the analysis
/// context that covers [packageDir] (its package config is the
/// workspace's, or the fixture's own).
Future<LibraryElement> resolveBarrel(
  String packageDir,
  String barrelUri,
) async {
  final collection = AnalysisContextCollection(includedPaths: [packageDir]);
  try {
    final session = collection.contextFor(packageDir).currentSession;
    final result = await session.getLibraryByUri(barrelUri);
    if (result is! LibraryElementResult) {
      throw StateError('$barrelUri did not resolve in $packageDir: $result');
    }
    return result.element;
  } finally {
    await collection.dispose();
  }
}

/// One problem for each place the API exported by [barrel] mentions a type
/// declared in one of [forbiddenPackages]: an exported element that is
/// itself such a type, or an exported element's public member type,
/// parameter, return type, type argument, bound or supertype (any of the
/// element's supertypes, whether or not the library exports them). Types
/// the library does not export are not walked: a host cannot name them.
/// Each problem names the element, the member and the type.
List<String> apiBoundaryProblems(
  LibraryElement barrel, {
  Set<String> forbiddenPackages = defaultForbiddenPackages,
}) {
  final problems = <String>[];
  final seen = <Element>{};
  final names = barrel.exportNamespace.definedNames2.keys.toList()..sort();
  for (final name in names) {
    final element = barrel.exportNamespace.definedNames2[name]!;
    if (!seen.add(element)) continue;
    _Walk(forbiddenPackages, problems).element(element, name);
  }
  return problems;
}

final class _Walk {
  _Walk(this.forbidden, this.problems);

  final Set<String> forbidden;
  final List<String> problems;

  String? _package(Element? e) {
    final uri = e?.library?.uri;
    if (uri == null || uri.scheme != 'package' || uri.pathSegments.isEmpty) {
      return null;
    }
    return uri.pathSegments.first;
  }

  bool _isForbidden(Element? e) => forbidden.contains(_package(e));

  void _report(String owner, String member, String what, Element type) {
    final where = member.isEmpty ? owner : '$owner.$member';
    problems.add(
      '$where: $what ${type.displayName} (package ${_package(type)})',
    );
  }

  /// Every forbidden type [type] is made of.
  void _type(DartType? type, String owner, String member, String what) {
    if (type == null) return;
    final alias = type.alias;
    if (alias != null) {
      if (_isForbidden(alias.element)) {
        _report(owner, member, what, alias.element);
      }
      for (final argument in alias.typeArguments) {
        _type(argument, owner, member, what);
      }
    }
    switch (type) {
      case InterfaceType():
        if (_isForbidden(type.element))
          _report(owner, member, what, type.element);
        for (final argument in type.typeArguments) {
          _type(argument, owner, member, what);
        }
      case FunctionType():
        _type(type.returnType, owner, member, what);
        for (final p in type.formalParameters) {
          _type(p.type, owner, member, what);
        }
        for (final p in type.typeParameters) {
          _type(p.bound, owner, member, what);
        }
      case RecordType():
        for (final f in type.positionalFields) {
          _type(f.type, owner, member, what);
        }
        for (final f in type.namedFields) {
          _type(f.type, owner, member, what);
        }
      default:
    }
  }

  void _typeParameters(
    List<TypeParameterElement> parameters,
    String owner,
    String member,
  ) {
    for (final p in parameters) {
      _type(p.bound, owner, member, 'type parameter bound');
    }
  }

  void _executable(ExecutableElement e, String owner) {
    final member = e.displayName;
    _type(e.returnType, owner, member, 'return type');
    for (final p in e.formalParameters) {
      _type(p.type, owner, member, 'parameter ${p.displayName}:');
    }
    _typeParameters(e.typeParameters, owner, member);
  }

  void element(Element e, String exportedAs) {
    if (_isForbidden(e)) {
      problems.add(
        '$exportedAs: exports ${e.displayName} '
        '(package ${_package(e)})',
      );
      return;
    }
    final owner = e.displayName.isEmpty ? exportedAs : e.displayName;
    switch (e) {
      case InterfaceElement():
        for (final t in e.allSupertypes) {
          if (_isForbidden(t.element)) {
            _report(owner, '', 'supertype', t.element);
          }
        }
        _typeParameters(e.typeParameters, owner, '');
        if (e is MixinElement) {
          for (final t in e.superclassConstraints) {
            _type(t, owner, '', 'superclass constraint');
          }
        }
        _members(e, owner);
        for (final c in e.constructors.where((c) => c.isPublic)) {
          _executable(c, owner);
        }
      case ExtensionElement():
        _type(e.extendedType, owner, '', 'extended type');
        _members(e, owner);
      case TypeAliasElement():
        _type(e.aliasedType, owner, '', 'aliased type');
        _typeParameters(e.typeParameters, owner, '');
      case TopLevelFunctionElement():
        _executable(e, owner);
      case GetterElement():
        _type(e.returnType, owner, '', 'type');
      case SetterElement():
        _executable(e, owner);
      default:
    }
  }

  void _members(InstanceElement e, String owner) {
    for (final f in e.fields) {
      if (f.isPublic && f.isOriginDeclaration) {
        _type(f.type, owner, f.displayName, 'type');
      }
    }
    for (final g in e.getters) {
      if (g.isPublic && !g.isOriginVariable) _executable(g, owner);
    }
    for (final s in e.setters) {
      if (s.isPublic && !s.isOriginVariable) _executable(s, owner);
    }
    for (final m in e.methods) {
      if (m.isPublic) _executable(m, owner);
    }
  }
}
