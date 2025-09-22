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
    for (final loc in locations) {
      for (final code in loc.standards) {
        final std = standards.firstWhere(
            (s) => s.code == code,
            orElse: () => StandardDef(code: code, name: ''));
        if (std.code != code || std.name.isEmpty && std.staticComponents.isEmpty && std.dynamicComponents.isEmpty) {
          continue;
        }
        final lines = engine.evaluate(std, loc.variables);
        for (final line in lines) {
          sb.writeln('${_esc(loc.barcode)},${_esc(std.code)},${_esc(line.mm)},${line.qty},${_esc(line.source)}');
          final mmKey = line.mm.trim().toLowerCase();
          if (mmKey.isEmpty) continue;
          final match = flaggedLookup[mmKey];
          if (match != null) {
            matchedFlagged.putIfAbsent(mmKey, () => match);
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
}
