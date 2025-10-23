// lib/core/engine.dart
import 'dart:convert';  // <-- REQUIRED for jsonEncode

import 'models.dart';
import 'logic.dart';

class RuleEngine {
  final _logic = const JsonLogic();

  List<BomLine> evaluate(StandardDef std, Map<String, dynamic> inputs) {
    final bom = <BomLine>[];

    final dynamicByName = <String, DynamicComponentDef>{};
    for (final dc in std.dynamicComponents) {
      final name = dc.name.trim();
      if (name.isEmpty) continue;
      dynamicByName[name] = dc;
    }

    final selectedRules = <DynamicComponentDef, RuleDef?>{};
    final matrixSelections = <DynamicComponentDef, _MatrixSelection>{};

    RuleDef? selectRule(DynamicComponentDef dc) {
      if (selectedRules.containsKey(dc)) {
        return selectedRules[dc];
      }
      final rule = _selectRule(dc, inputs);
      selectedRules[dc] = rule;
      return rule;
    }

    _MatrixSelection matrixSelection(DynamicComponentDef dc) {
      return matrixSelections.putIfAbsent(dc, () => _selectMatrix(dc, inputs));
    }

    // static
    for (final sc in std.staticComponents) {
      final providerName = sc.dynamicMmComponent?.trim();
      if (providerName != null && providerName.isNotEmpty) {
        final provider = dynamicByName[providerName];
        String? mm;
        if (provider != null) {
          final matrixResult = matrixSelection(provider);
          if (matrixResult.status == 'ok' && matrixResult.primaryMm != null) {
            mm = matrixResult.primaryMm;
          }
        }
        mm ??= provider != null ? _firstNonEmptyMm(selectRule(provider)) : null;
        if (mm != null) {
          bom.add(
            BomLine(
              mm: mm,
              qty: sc.qty,
              source: 'static:$providerName',
              label: sc.label,
            ),
          );
          continue;
        }
      }
      final literalMm = sc.mm;
      if (literalMm != null) {
        bom.add(
          BomLine(
            mm: literalMm,
            qty: sc.qty,
            source: 'static',
            label: sc.label,
          ),
        );
      }
    }

    final numericInputs = _onlyNums(inputs);

    // dynamic
    for (final dc in std.dynamicComponents) {
      final matrixResult = matrixSelection(dc);
      if (matrixResult.shouldEmitLine) {
        final emittedMms = matrixResult.mms.isEmpty
            ? const ['INVALID']
            : matrixResult.mms;
        for (final mm in emittedMms) {
          bom.add(
            BomLine(
              mm: mm,
              qty: matrixResult.qty,
              source: 'matrix:${dc.name}',
              status: matrixResult.status,
              requiresAccessory: matrixResult.requiresAccessory,
              notes: matrixResult.notes,
            ),
          );
        }
      }
      if (matrixResult.blockRules) {
        continue;
      }
      final chosen = selectRule(dc);
      if (chosen == null) continue;
      for (final out in chosen.outputs) {
        final qty = out.qty ?? QtyFormula.evalInt(out.qtyFormula ?? '1', numericInputs);
        bom.add(BomLine(mm: out.mm, qty: qty, source: 'rule:${dc.name}'));
      }
    }
    return bom;
  }

  RuleDef? _selectRule(DynamicComponentDef dc, Map<String, dynamic> inputs) {
    final matches = <RuleDef>[];
    for (final r in dc.rules) {
      final ok = _logic.apply(r.expr, inputs);
      if (ok == true) matches.add(r);
    }
    if (matches.isEmpty) return null;

    matches.sort((a, b) {
      final p = (b.priority) - (a.priority);
      if (p != 0) return p;
      final la = jsonEncode(a.expr).length;
      final lb = jsonEncode(b.expr).length;
      return lb - la; // more specific first
    });

    return matches.first;
  }

  String? _firstNonEmptyMm(RuleDef? rule) {
    if (rule == null) return null;
    for (final out in rule.outputs) {
      final mm = out.mm.trim();
      if (mm.isNotEmpty) return mm;
    }
    return null;
  }

  Map<String, num> _onlyNums(Map<String, dynamic> src) {
    final m = <String, num>{};
    for (final e in src.entries) {
      final v = e.value;
      if (v is num) m[e.key] = v;
      if (v is String) {
        final n = num.tryParse(v);
        if (n != null) m[e.key] = n;
      }
    }
    return m;
  }

  _MatrixSelection _selectMatrix(
    DynamicComponentDef dc,
    Map<String, dynamic> inputs,
  ) {
    final matrix = dc.matrix;
    if (matrix == null) {
      return _MatrixSelection.none();
    }
    final axis1Value = matrix.valueForAxis(matrix.axis1Parameter, inputs);
    final axis2Value = matrix.valueForAxis(matrix.axis2Parameter, inputs);
    if (axis1Value == null || axis1Value.isEmpty || axis2Value == null || axis2Value.isEmpty) {
      return _MatrixSelection(
        status: 'pending',
        qty: 0,
        requiresAccessory: false,
        notes: null,
        blockRules: false,
        shouldEmitLine: false,
        mms: const [],
      );
    }
    final cell = matrix.lookup(inputs);
    if (cell == null) {
      final note = 'No combination for $axis1Value × $axis2Value';
      return _MatrixSelection(
        status: 'invalid',
        qty: 0,
        requiresAccessory: false,
        notes: note,
        blockRules: true,
        shouldEmitLine: true,
        mms: const ['INVALID'],
      );
    }
    if (!cell.enabled) {
      final note = cell.notes?.isNotEmpty == true
          ? cell.notes
          : 'Combination $axis1Value × $axis2Value disabled';
      return _MatrixSelection(
        status: 'invalid',
        qty: 0,
        requiresAccessory: cell.requiresAccessory,
        notes: note,
        blockRules: true,
        shouldEmitLine: true,
        mms: const ['INVALID'],
      );
    }
    final mms = _resolveMatrixMms(dc, matrix, inputs, cell);
    if (mms.isEmpty) {
      return _MatrixSelection(
        status: 'pending',
        qty: cell.qty,
        requiresAccessory: cell.requiresAccessory,
        notes: cell.notes,
        blockRules: false,
        shouldEmitLine: false,
        mms: const [],
      );
    }
    return _MatrixSelection(
      status: 'ok',
      qty: cell.qty,
      requiresAccessory: cell.requiresAccessory,
      notes: cell.notes,
      blockRules: false,
      shouldEmitLine: true,
      mms: mms,
    );
  }

  List<String> _resolveMatrixMms(
    DynamicComponentDef dc,
    ConnectorMatrix matrix,
    Map<String, dynamic> inputs,
    ConnectorMatrixCell cell,
  ) {
    if (cell.hasMm) {
      return cell.mms;
    }
    final pattern = dc.mmPattern;
    if (pattern == null || pattern.trim().isEmpty) {
      return const [];
    }
    final axis1Value = matrix.valueForAxis(matrix.axis1Parameter, inputs) ?? '';
    final axis2Value = matrix.valueForAxis(matrix.axis2Parameter, inputs) ?? '';
    final resolved = pattern.replaceAllMapped(
      RegExp(r'\{([^}]+)\}'),
      (match) {
        final token = (match.group(1) ?? '').trim();
        if (token.isEmpty) return '';
        if (token == 'axis1') return axis1Value;
        if (token == 'axis2') return axis2Value;
        if (token == matrix.axis1Parameter) return axis1Value;
        if (token == matrix.axis2Parameter) return axis2Value;
        if (token == 'mm') return cell.mm ?? '';
        final fromInputs = matrix.valueForAxis(token, inputs);
        if (fromInputs != null) return fromInputs;
        final raw = inputs[token];
        return raw == null ? '' : '$raw';
      },
    );
    final trimmed = resolved.trim();
    return trimmed.isEmpty ? const [] : [trimmed];
  }
}

class _MatrixSelection {
  final String status;
  final int qty;
  final bool requiresAccessory;
  final String? notes;
  final bool blockRules;
  final bool shouldEmitLine;
  final List<String> mms;

  _MatrixSelection({
    required this.status,
    required this.qty,
    required this.requiresAccessory,
    required this.notes,
    required this.blockRules,
    required this.shouldEmitLine,
    required List<String> mms,
  }) : mms = List.unmodifiable(mms);

  String? get primaryMm => mms.isEmpty ? null : mms.first;

  factory _MatrixSelection.none() => _MatrixSelection(
        status: 'none',
        qty: 0,
        requiresAccessory: false,
        notes: null,
        blockRules: false,
        shouldEmitLine: false,
        mms: const [],
      );
}
