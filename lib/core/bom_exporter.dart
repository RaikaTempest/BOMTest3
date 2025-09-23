import 'dart:io';

import 'engine.dart';
import 'models.dart';

class BomExporter {
  final RuleEngine engine;
  BomExporter({RuleEngine? engine}) : engine = engine ?? RuleEngine();

  /// Generates BOM for each location and returns CSV string.
  String buildCsv(
    List<WorkLocation> locations,
    List<StandardDef> standards, {
    List<FlaggedMaterial> flaggedMaterials = const [],
  }) {
    final sb = StringBuffer();
    sb.writeln('location,standard,mm,qty,source');
    final flaggedLookup = <String, FlaggedMaterial>{};
    for (final flagged in flaggedMaterials) {
      final key = flagged.mm.trim().toLowerCase();
      if (key.isEmpty) continue;
      flaggedLookup[key] = flagged;
    }
    final matchedFlagged = <String, FlaggedMaterial>{};
    final standardsByCode = <String, StandardDef>{};
    for (final std in standards) {
      standardsByCode[std.code] = std;
    }
    final dynamicLookup = _buildDynamicComponentLookup(standards);
    final standardsWithDependencies = <String, StandardDef>{};
    final injectedDynamicNames = <String, Set<String>>{};
    for (final entry in standardsByCode.entries) {
      final resolved =
          _withDynamicDependencies(entry.value, dynamicLookup);
      standardsWithDependencies[entry.key] = resolved.standard;
      injectedDynamicNames[entry.key] = resolved.injectedNames;
    }
    for (final loc in locations) {
      for (final code in loc.standards) {
        final base = standardsByCode[code];
        if (base == null) {
          continue;
        }
        if (base.name.isEmpty &&
            base.staticComponents.isEmpty &&
            base.dynamicComponents.isEmpty) {
          continue;
        }
        final stdWithDeps = standardsWithDependencies[code] ?? base;
        final injected = injectedDynamicNames[code] ?? const <String>{};
        final lines = engine.evaluate(stdWithDeps, loc.variables);
        final staticConsumersByDynamic = <String, List<StaticComponent>>{};
        if (base.staticComponents.isNotEmpty && injected.isNotEmpty) {
          for (final component in base.staticComponents) {
            final providerName = component.dynamicMmComponent?.trim();
            if (providerName == null || providerName.isEmpty) {
              continue;
            }
            staticConsumersByDynamic
                .putIfAbsent(providerName, () => <StaticComponent>[])
                .add(component);
          }
        }
        final emittedStaticProviders = <String>{};
        final suppressedDynamicOutputs = <String, BomLine>{};
        for (final line in lines) {
          final source = line.source;
          if (source.startsWith('static:')) {
            final providerName = source.substring(7).trim();
            if (providerName.isNotEmpty) {
              emittedStaticProviders.add(providerName);
            }
          }
          if (source.startsWith('rule:')) {
            final dynamicName = source.substring(5).trim();
            // If a static provider for this dynamicName was emitted, skip the dynamic line
            if (emittedStaticProviders.contains(dynamicName)) {
              continue;
            }
            if (injected.contains(dynamicName)) {
              suppressedDynamicOutputs.putIfAbsent(dynamicName, () => line);
              continue;
            }
          }
          sb.writeln('${_esc(loc.barcode)},${_esc(base.code)},${_esc(line.mm)},${line.qty},${_esc(line.source)}');
          final mmKey = line.mm.trim().toLowerCase();
          if (mmKey.isEmpty) continue;
          final match = flaggedLookup[mmKey];
          if (match != null) {
            matchedFlagged.putIfAbsent(mmKey, () => match);
          }
        }
        if (suppressedDynamicOutputs.isNotEmpty &&
            staticConsumersByDynamic.isNotEmpty) {
          for (final entry in suppressedDynamicOutputs.entries) {
            final dynamicName = entry.key;
            if (emittedStaticProviders.contains(dynamicName)) {
              continue;
            }
            final consumers = staticConsumersByDynamic[dynamicName];
            if (consumers == null || consumers.isEmpty) {
              continue;
            }
            final fallbackMm = entry.value.mm;
            final fallbackSource = 'static:$dynamicName';
            for (final consumer in consumers) {
              sb.writeln(
                  '${_esc(loc.barcode)},${_esc(base.code)},${_esc(fallbackMm)},${consumer.qty},${_esc(fallbackSource)}');
              final mmKey = fallbackMm.trim().toLowerCase();
              if (mmKey.isEmpty) {
                continue;
              }
              final match = flaggedLookup[mmKey];
              if (match != null) {
                matchedFlagged.putIfAbsent(mmKey, () => match);
              }
            }
          }
        }
      }
    }
    if (matchedFlagged.isNotEmpty) {
      sb.writeln();
      sb.writeln(
          'flagged_mm,name,alternative_available,alternative_mm,alternative_name,note,flagged_at,flagged_by');
      final flaggedList = matchedFlagged.values.toList()
        ..sort((a, b) => a.mm.toLowerCase().compareTo(b.mm.toLowerCase()));
      for (final flagged in flaggedList) {
        final alternativeAvailable = flagged.alternativeAvailable ? 'true' : 'false';
        final alternativeMm = flagged.alternativeMm ?? '';
        final alternativeName = flagged.alternativeName ?? '';
        final note = flagged.note ?? '';
        final flaggedAt = flagged.flaggedAt?.toIso8601String() ?? '';
        final flaggedBy = flagged.flaggedBy ?? '';
        sb.writeln(
            '${_esc(flagged.mm)},${_esc(flagged.name)},${_esc(alternativeAvailable)},${_esc(alternativeMm)},${_esc(alternativeName)},${_esc(note)},${_esc(flaggedAt)},${_esc(flaggedBy)}');
      }
    }
    return sb.toString();
  }

  /// Writes the CSV to the given file path.
  Future<void> writeCsv(
    String path,
    List<WorkLocation> locations,
    List<StandardDef> standards, {
    List<FlaggedMaterial> flaggedMaterials = const [],
  }) async {
    final csv = buildCsv(
      locations,
      standards,
      flaggedMaterials: flaggedMaterials,
    );
    final file = File(path);
    await file.writeAsString(csv);
  }

  String _esc(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      final escaped = v.replaceAll('"', '""');
      return '"$escaped"';
    }
    return v;
  }

  Map<String, DynamicComponentDef> _buildDynamicComponentLookup(
      Iterable<StandardDef> standards) {
    final lookup = <String, DynamicComponentDef>{};
    for (final std in standards) {
      for (final component in std.dynamicComponents) {
        final name = component.name.trim();
        if (name.isEmpty) continue;
        lookup.putIfAbsent(name, () => component);
      }
    }
    return lookup;
  }

  ({StandardDef standard, Set<String> injectedNames})
      _withDynamicDependencies(
    StandardDef std,
    Map<String, DynamicComponentDef> dynamicLookup,
  ) {
    if (std.staticComponents.isEmpty) {
      return (standard: std, injectedNames: const <String>{});
    }
    final existing = std.dynamicComponents
        .map((dc) => dc.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    final injected = <String>{};
    final dependencies = <DynamicComponentDef>[];
    for (final staticComponent in std.staticComponents) {
      final providerName = staticComponent.dynamicMmComponent?.trim();
      if (providerName == null || providerName.isEmpty) {
        continue;
      }
      if (existing.contains(providerName)) {
        continue;
      }
      final dependency = dynamicLookup[providerName];
      if (dependency == null) {
        continue;
      }
      dependencies.add(dependency);
      injected.add(providerName);
      existing.add(providerName);
    }
    if (dependencies.isEmpty) {
      return (standard: std, injectedNames: const <String>{});
    }
    return (
      standard: StandardDef(
        code: std.code,
        name: std.name,
        version: std.version,
        status: std.status,
        parameters: std.parameters,
        staticComponents: std.staticComponents,
        dynamicComponents: [
          ...std.dynamicComponents,
          ...dependencies,
        ],
        applicationId: std.applicationId,
      ),
      injectedNames: Set.unmodifiable(injected),
    );
  }
}
