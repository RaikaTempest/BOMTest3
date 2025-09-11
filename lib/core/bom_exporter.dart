import 'dart:io';

import 'engine.dart';
import 'models.dart';

class BomExporter {
  final RuleEngine engine;
  BomExporter({RuleEngine? engine}) : engine = engine ?? RuleEngine();

  /// Generates BOM for each location and returns CSV string.
  String buildCsv(List<WorkLocation> locations, List<StandardDef> standards) {
    final sb = StringBuffer();
    sb.writeln('location,standard,mm,qty,source');
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
        }
      }
    }
    return sb.toString();
  }

  /// Writes the CSV to the given file path.
  Future<void> writeCsv(String path, List<WorkLocation> locations, List<StandardDef> standards) async {
    final csv = buildCsv(locations, standards);
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
