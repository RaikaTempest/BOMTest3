// ==============================
// Project scaffolding (copy these into files)
// ==============================
//
// lib/core/models.dart
// lib/core/logic.dart
// lib/core/engine.dart
// test/engine_test.dart
// lib/main.dart (temporary placeholder UI)
//
// Run:
//   flutter create bom_builder
//   cd bom_builder
//   # add the files below into the paths listed
//   flutter test
//
// After tests pass, we'll add persistence (path_provider) and real Flutter pages.

// ==============================
// lib/core/models.dart
// ==============================


enum ParamType { enumType, number, boolean, text }

ParamType paramTypeFromString(String s) {
  switch (s) {
    case 'enum':
      return ParamType.enumType;
    case 'number':
      return ParamType.number;
    case 'bool':
    case 'boolean':
      return ParamType.boolean;
    case 'text':
    default:
      return ParamType.text;
  }
}

String paramTypeToString(ParamType t) {
  switch (t) {
    case ParamType.enumType:
      return 'enum';
    case ParamType.number:
      return 'number';
    case ParamType.boolean:
      return 'bool';
    case ParamType.text:
      return 'text';
  }
}

class ParameterDef {
  final String key;
  final ParamType type;
  final String? unit;
  final List<String> allowedValues;
  final bool required;

  ParameterDef({
    required this.key,
    required this.type,
    this.unit,
    this.allowedValues = const [],
    this.required = true,
  });

  factory ParameterDef.fromJson(Map<String, dynamic> j) => ParameterDef(
        key: j['key'] as String,
        type: paramTypeFromString(j['type'] as String? ?? 'text'),
        unit: j['unit'] as String?,
        allowedValues: (j['allowed_values'] as List?)?.map((e) => '$e').toList() ?? const [],
        required: (j['required'] as bool?) ?? true,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'type': paramTypeToString(type),
        'unit': unit,
        'allowed_values': allowedValues,
        'required': required,
      };
}

class StaticComponent {
  final String? mm;
  final String? dynamicMmComponent;
  final int qty;

  const StaticComponent({this.mm, this.dynamicMmComponent, required this.qty});

  factory StaticComponent.fromJson(Map<String, dynamic> j) => StaticComponent(
        mm: j['mm'] as String?,
        dynamicMmComponent: j['dynamic_mm_component'] as String?,
        qty: (j['qty'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        if (mm != null) 'mm': mm,
        if (dynamicMmComponent != null)
          'dynamic_mm_component': dynamicMmComponent,
        'qty': qty,
      };
}

class FlaggedMaterial {
  final String mm;
  final String name;
  final bool alternativeAvailable;
  final String? alternativeMm;
  final String? alternativeName;
  final String? note;
  final DateTime? flaggedAt;
  final String? flaggedBy;

  const FlaggedMaterial({
    required this.mm,
    required this.name,
    this.alternativeAvailable = false,
    this.alternativeMm,
    this.alternativeName,
    this.note,
    this.flaggedAt,
    this.flaggedBy,
  });

  static String? _normalizedString(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  factory FlaggedMaterial.fromJson(Map<String, dynamic> j) => FlaggedMaterial(
        mm: _normalizedString(j['mm'] as String?) ?? '',
        name: _normalizedString(j['name'] as String?) ??
            _normalizedString(j['reason'] as String?) ??
            '',
        alternativeAvailable: j['alternative_available'] as bool? ?? false,
        alternativeMm: _normalizedString(j['alternative_mm'] as String?),
        alternativeName: _normalizedString(j['alternative_name'] as String?),
        note: _normalizedString(j['note'] as String?) ??
            _normalizedString(j['reason'] as String?),
        flaggedAt: j['flagged_at'] != null
            ? DateTime.tryParse(j['flagged_at'] as String)
            : null,
        flaggedBy: _normalizedString(j['flagged_by'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'mm': mm,
        'name': name,
        if (alternativeAvailable) 'alternative_available': true,
        if (alternativeMm != null) 'alternative_mm': alternativeMm,
        if (alternativeName != null) 'alternative_name': alternativeName,
        if (note != null) ...{'note': note, 'reason': note},
        if (flaggedAt != null) 'flagged_at': flaggedAt!.toIso8601String(),
        if (flaggedBy != null) 'flagged_by': flaggedBy,
      };
}

class OutputSpec {
  final String mm;
  final int? qty;
  final String? qtyFormula; // e.g., "span_ft/10*3"
  OutputSpec({required this.mm, this.qty, this.qtyFormula});
  factory OutputSpec.fromJson(Map<String, dynamic> j) => OutputSpec(
        mm: j['mm'] as String,
        qty: (j['qty'] as num?)?.toInt(),
        qtyFormula: j['qty_formula'] as String?,
      );
  Map<String, dynamic> toJson() => {
        'mm': mm,
        if (qty != null) 'qty': qty,
        if (qtyFormula != null) 'qty_formula': qtyFormula,
      };
}

class RuleDef {
  final Map<String, dynamic> expr; // JSONLogic-lite
  final List<OutputSpec> outputs;
  final int priority;
  RuleDef({required this.expr, required this.outputs, this.priority = 0});
  factory RuleDef.fromJson(Map<String, dynamic> j) => RuleDef(
        expr: (j['expr'] as Map).cast<String, dynamic>(),
        outputs: (j['outputs'] as List).map((e) => OutputSpec.fromJson((e as Map).cast<String, dynamic>())).toList(),
        priority: (j['priority'] as num?)?.toInt() ?? 0,
      );
  Map<String, dynamic> toJson() => {
        'expr': expr,
        'outputs': outputs.map((e) => e.toJson()).toList(),
        'priority': priority,
      };
}

class DynamicComponentDef {
  final String name;
  final String selectionStrategy; // 'most_specific'
  final List<RuleDef> rules;
  final ConnectorMatrix? matrix;
  final String? mmPattern;

  DynamicComponentDef({
    required this.name,
    this.selectionStrategy = 'most_specific',
    this.rules = const [],
    this.matrix,
    this.mmPattern,
  });

  factory DynamicComponentDef.fromJson(Map<String, dynamic> j) => DynamicComponentDef(
        name: j['name'] as String,
        selectionStrategy: j['selection_strategy'] as String? ?? 'most_specific',
        rules: (j['rules'] as List?)?.map((e) => RuleDef.fromJson((e as Map).cast<String, dynamic>())).toList() ?? const [],
        matrix: j['matrix'] is Map
            ? ConnectorMatrix.fromJson((j['matrix'] as Map).cast<String, dynamic>())
            : null,
        mmPattern: j['mm_pattern'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'selection_strategy': selectionStrategy,
        'rules': rules.map((e) => e.toJson()).toList(),
        if (matrix != null) 'matrix': matrix!.toJson(),
        if (mmPattern != null && mmPattern!.trim().isNotEmpty) 'mm_pattern': mmPattern,
      };

  DynamicComponentDef copyWith({
    String? name,
    String? selectionStrategy,
    List<RuleDef>? rules,
    ConnectorMatrix? matrix,
    String? mmPattern,
  }) {
    return DynamicComponentDef(
      name: name ?? this.name,
      selectionStrategy: selectionStrategy ?? this.selectionStrategy,
      rules: rules ?? this.rules,
      matrix: matrix ?? this.matrix,
      mmPattern: mmPattern ?? this.mmPattern,
    );
  }
}

class ConnectorMatrix {
  final String axis1Parameter; // e.g., wire 1 gauge
  final String axis2Parameter; // e.g., wire 2 gauge
  final List<ConnectorMatrixRow> rows;
  final List<String> metadataColumns;

  const ConnectorMatrix({
    required this.axis1Parameter,
    required this.axis2Parameter,
    this.rows = const [],
    this.metadataColumns = const [],
  });

  factory ConnectorMatrix.fromJson(Map<String, dynamic> j) => ConnectorMatrix(
        axis1Parameter: j['axis1_parameter'] as String? ?? '',
        axis2Parameter: j['axis2_parameter'] as String? ?? '',
        rows: (j['rows'] as List?)
                ?.whereType<Map>()
                .map((e) => ConnectorMatrixRow.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        metadataColumns: (j['metadata_columns'] as List?)
                ?.whereType<String>()
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'axis1_parameter': axis1Parameter,
        'axis2_parameter': axis2Parameter,
        'rows': rows.map((e) => e.toJson()).toList(),
        if (metadataColumns.isNotEmpty) 'metadata_columns': metadataColumns,
      };

  List<String> get columnValues {
    final values = <String>{};
    for (final row in rows) {
      for (final cell in row.cells) {
        values.add(cell.axis2Value);
      }
    }
    final sorted = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  ConnectorMatrixCell? lookup(Map<String, dynamic> inputs) {
    final axis1Value = valueForAxis(axis1Parameter, inputs);
    final axis2Value = valueForAxis(axis2Parameter, inputs);
    if (axis1Value == null || axis2Value == null) {
      return null;
    }
    final normalizedAxis1 = _normalizeForComparison(axis1Value);
    final normalizedAxis2 = _normalizeForComparison(axis2Value);
    for (final row in rows) {
      if (_normalizeForComparison(row.axis1Value) != normalizedAxis1) {
        continue;
      }
      for (final cell in row.cells) {
        if (_normalizeForComparison(cell.axis2Value) == normalizedAxis2) {
          return cell;
        }
      }
    }
    return null;
  }

  ConnectorMatrix copyWith({
    String? axis1Parameter,
    String? axis2Parameter,
    List<ConnectorMatrixRow>? rows,
    List<String>? metadataColumns,
  }) {
    return ConnectorMatrix(
      axis1Parameter: axis1Parameter ?? this.axis1Parameter,
      axis2Parameter: axis2Parameter ?? this.axis2Parameter,
      rows: rows ?? this.rows,
      metadataColumns: metadataColumns ?? this.metadataColumns,
    );
  }

  String? valueForAxis(String axis, Map<String, dynamic> inputs) {
    if (axis.isEmpty) return null;
    return _stringify(inputs[axis]);
  }

  static String? _stringify(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.trim();
    if (v is int) return v.toString();
    if (v is num) {
      final intValue = v.toInt();
      if (v == intValue) {
        return intValue.toString();
      }
      var s = v.toString();
      if (s.contains('.')) {
        s = s.replaceAll(RegExp(r'0+$'), '');
        if (s.endsWith('.')) {
          s = s.substring(0, s.length - 1);
        }
      }
      return s;
    }
    if (v is bool) return v ? 'true' : 'false';
    return v.toString();
  }

  static String _normalizeForComparison(String? value) {
    if (value == null) return '';
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final numeric = num.tryParse(trimmed);
    if (numeric != null) {
      if (numeric is int) {
        return numeric.toString();
      }
      if (numeric is double) {
        if (!numeric.isFinite) {
          return trimmed.toLowerCase();
        }
        if (numeric == numeric.roundToDouble()) {
          return numeric.toInt().toString();
        }
        return numeric.toString();
      }
    }
    return trimmed.toLowerCase();
  }
}

class ConnectorMatrixRow {
  final String axis1Value;
  final List<ConnectorMatrixCell> cells;

  const ConnectorMatrixRow({required this.axis1Value, this.cells = const []});

  factory ConnectorMatrixRow.fromJson(Map<String, dynamic> j) => ConnectorMatrixRow(
        axis1Value: j['axis1_value'] as String? ?? '',
        cells: (j['cells'] as List?)
                ?.whereType<Map>()
                .map((e) => ConnectorMatrixCell.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'axis1_value': axis1Value,
        'cells': cells.map((e) => e.toJson()).toList(),
      };

  ConnectorMatrixRow copyWith({
    String? axis1Value,
    List<ConnectorMatrixCell>? cells,
  }) {
    return ConnectorMatrixRow(
      axis1Value: axis1Value ?? this.axis1Value,
      cells: cells ?? this.cells,
    );
  }
}

class ConnectorMatrixCell {
  final String axis2Value;
  final String? mm;
  final int qty;
  final bool enabled;
  final bool requiresAccessory;
  final String? notes;

  const ConnectorMatrixCell({
    required this.axis2Value,
    this.mm,
    this.qty = 1,
    this.enabled = true,
    this.requiresAccessory = false,
    this.notes,
  });

  factory ConnectorMatrixCell.fromJson(Map<String, dynamic> j) => ConnectorMatrixCell(
        axis2Value: j['axis2_value'] as String? ?? '',
        mm: j['mm'] as String?,
        qty: (j['qty'] as num?)?.toInt() ?? 1,
        enabled: j['enabled'] as bool? ?? true,
        requiresAccessory: j['requires_accessory'] as bool? ?? false,
        notes: j['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'axis2_value': axis2Value,
        if (mm != null) 'mm': mm,
        if (qty != 1) 'qty': qty,
        if (!enabled) 'enabled': enabled,
        if (requiresAccessory) 'requires_accessory': requiresAccessory,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes,
      };

  ConnectorMatrixCell copyWith({
    String? axis2Value,
    String? mm,
    int? qty,
    bool? enabled,
    bool? requiresAccessory,
    String? notes,
  }) {
    return ConnectorMatrixCell(
      axis2Value: axis2Value ?? this.axis2Value,
      mm: mm ?? this.mm,
      qty: qty ?? this.qty,
      enabled: enabled ?? this.enabled,
      requiresAccessory: requiresAccessory ?? this.requiresAccessory,
      notes: notes ?? this.notes,
    );
  }

  bool get hasMm => (mm ?? '').trim().isNotEmpty;
}

class StandardDef {
  final String code;
  final String name;
  final String version;
  final String status; // draft/published/deprecated
  final List<ParameterDef> parameters;
  final List<StaticComponent> staticComponents;
  final List<DynamicComponentDef> dynamicComponents;
  final String? applicationId; // originating StandardApplication

  StandardDef({
    required this.code,
    required this.name,
    this.version = '1.0.0',
    this.status = 'draft',
    this.parameters = const [],
    this.staticComponents = const [],
    this.dynamicComponents = const [],
    this.applicationId,
  });

  factory StandardDef.fromJson(Map<String, dynamic> j) => StandardDef(
        code: j['code'] as String,
        name: j['name'] as String? ?? '',
        version: j['version'] as String? ?? '1.0.0',
        status: j['status'] as String? ?? 'draft',
        parameters: (j['parameters'] as List?)?.map((e) => ParameterDef.fromJson((e as Map).cast<String, dynamic>())).toList() ?? const [],
        staticComponents: (j['static_components'] as List?)?.map((e) => StaticComponent.fromJson((e as Map).cast<String, dynamic>())).toList() ?? const [],
        dynamicComponents: (j['dynamic_components'] as List?)?.map((e) => DynamicComponentDef.fromJson((e as Map).cast<String, dynamic>())).toList() ?? const [],
        applicationId: j['application_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'version': version,
        'status': status,
        'parameters': parameters.map((e) => e.toJson()).toList(),
        'static_components': staticComponents.map((e) => e.toJson()).toList(),
        'dynamic_components': dynamicComponents.map((e) => e.toJson()).toList(),
        if (applicationId != null) 'application_id': applicationId,
      };
}

class StandardApplication {
  final String id;
  final String createdBy;
  final String content;
  final String status; // pending/approved/rejected
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? standardCode;

  StandardApplication({
    required this.id,
    required this.createdBy,
    required this.content,
    this.status = 'pending',
    required this.createdAt,
    this.approvedAt,
    this.standardCode,
  });

  factory StandardApplication.fromJson(Map<String, dynamic> j) => StandardApplication(
        id: j['id'] as String,
        createdBy: j['created_by'] as String,
        content: j['content'] as String,
        status: j['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(j['created_at'] as String),
        approvedAt: j['approved_at'] != null ? DateTime.parse(j['approved_at'] as String) : null,
        standardCode: j['standard_code'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_by': createdBy,
        'content': content,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        if (approvedAt != null) 'approved_at': approvedAt!.toIso8601String(),
        'standard_code': standardCode,
      };
}

class BomLine {
  final String mm;
  final int qty;
  final String source; // 'static', 'static:<dc>', 'rule:<dc>', or 'matrix:<dc>'
  final String status; // ok / invalid
  final bool requiresAccessory;
  final String? notes;
  BomLine({
    required this.mm,
    required this.qty,
    required this.source,
    this.status = 'ok',
    this.requiresAccessory = false,
    this.notes,
  });
}

class CacheEntry {
  final String standardId;
  final Map<String, dynamic> inputs;
  final List<BomLine> bom;
  final String status; // pending/approved
  final DateTime createdAt;
  CacheEntry({required this.standardId, required this.inputs, required this.bom, required this.status, required this.createdAt});
}

class WorkLocation {
  String barcode;
  Set<String> standards;
  Map<String, dynamic> variables;
  WorkLocation({
    this.barcode = '',
    Set<String>? standards,
    Map<String, dynamic>? variables,
  })  : standards = standards ?? <String>{},
        variables = variables ?? <String, dynamic>{};

  factory WorkLocation.fromJson(Map<String, dynamic> j) => WorkLocation(
        barcode: j['barcode'] as String? ?? '',
        standards:
            (j['standards'] as List?)?.map((e) => e.toString()).toSet() ?? <String>{},
        variables: (j['variables'] as Map?)?.cast<String, dynamic>() ?? {},
      );

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'standards': standards.toList(),
        'variables': variables,
      };
}

class Project {
  final String name;
  final List<WorkLocation> locations;
  Project({required this.name, required this.locations});

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        name: j['name'] as String? ?? '',
        locations: (j['locations'] as List?)
                ?.map((e) => WorkLocation.fromJson(
                    (e as Map).cast<String, dynamic>()))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'locations': locations.map((e) => e.toJson()).toList(),
      };
}
