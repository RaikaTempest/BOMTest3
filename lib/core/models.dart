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
  final String mm;
  final int qty;
  StaticComponent({required this.mm, required this.qty});
  factory StaticComponent.fromJson(Map<String, dynamic> j) => StaticComponent(
        mm: j['mm'] as String,
        qty: (j['qty'] as num).toInt(),
      );
  Map<String, dynamic> toJson() => {'mm': mm, 'qty': qty};
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
  DynamicComponentDef({required this.name, this.selectionStrategy = 'most_specific', this.rules = const []});
  factory DynamicComponentDef.fromJson(Map<String, dynamic> j) => DynamicComponentDef(
        name: j['name'] as String,
        selectionStrategy: j['selection_strategy'] as String? ?? 'most_specific',
        rules: (j['rules'] as List?)?.map((e) => RuleDef.fromJson((e as Map).cast<String, dynamic>())).toList() ?? const [],
      );
  Map<String, dynamic> toJson() => {
        'name': name,
        'selection_strategy': selectionStrategy,
        'rules': rules.map((e) => e.toJson()).toList(),
      };
}

class StandardDef {
  final String code;
  final String name;
  final String version;
  final String status; // draft/published/deprecated
  final List<ParameterDef> parameters;
  final List<StaticComponent> staticComponents;
  final List<DynamicComponentDef> dynamicComponents;

  StandardDef({
    required this.code,
    required this.name,
    this.version = '1.0.0',
    this.status = 'draft',
    this.parameters = const [],
    this.staticComponents = const [],
    this.dynamicComponents = const [],
  });

  factory StandardDef.fromJson(Map<String, dynamic> j) => StandardDef(
        code: j['code'] as String,
        name: j['name'] as String? ?? '',
        version: j['version'] as String? ?? '1.0.0',
        status: j['status'] as String? ?? 'draft',
        parameters: (j['parameters'] as List?)?.map((e) => ParameterDef.fromJson((e as Map).cast<String, dynamic>())).toList() ?? const [],
        staticComponents: (j['static_components'] as List?)?.map((e) => StaticComponent.fromJson((e as Map).cast<String, dynamic>())).toList() ?? const [],
        dynamicComponents: (j['dynamic_components'] as List?)?.map((e) => DynamicComponentDef.fromJson((e as Map).cast<String, dynamic>())).toList() ?? const [],
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'version': version,
        'status': status,
        'parameters': parameters.map((e) => e.toJson()).toList(),
        'static_components': staticComponents.map((e) => e.toJson()).toList(),
        'dynamic_components': dynamicComponents.map((e) => e.toJson()).toList(),
      };
}

class BomLine {
  final String mm;
  final int qty;
  final String source; // 'static' or 'rule:<dc>'
  BomLine({required this.mm, required this.qty, required this.source});
}

class CacheEntry {
  final String standardId;
  final Map<String, dynamic> inputs;
  final List<BomLine> bom;
  final String status; // pending/approved
  final DateTime createdAt;
  CacheEntry({required this.standardId, required this.inputs, required this.bom, required this.status, required this.createdAt});
}
