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

    RuleDef? selectRule(DynamicComponentDef dc) {
      if (selectedRules.containsKey(dc)) {
        return selectedRules[dc];
      }
      final rule = _selectRule(dc, inputs);
      selectedRules[dc] = rule;
      return rule;
    }

    // static
    for (final sc in std.staticComponents) {
      final providerName = sc.dynamicMmComponent?.trim();
      if (providerName != null && providerName.isNotEmpty) {
        final provider = dynamicByName[providerName];
        final mm = provider != null ? _firstNonEmptyMm(selectRule(provider)) : null;
        if (mm != null) {
          bom.add(BomLine(mm: mm, qty: sc.qty, source: 'static:$providerName'));
          continue;
        }
      }
      final literalMm = sc.mm;
      if (literalMm != null) {
        bom.add(BomLine(mm: literalMm, qty: sc.qty, source: 'static'));
      }
    }

    final numericInputs = _onlyNums(inputs);

    // dynamic
    for (final dc in std.dynamicComponents) {
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
}
