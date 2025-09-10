// lib/core/engine.dart
import 'dart:convert';  // <-- REQUIRED for jsonEncode

import 'models.dart';
import 'logic.dart';

class RuleEngine {
  final _logic = const JsonLogic();

  List<BomLine> evaluate(StandardDef std, Map<String, dynamic> inputs) {
    final bom = <BomLine>[];

    // static
    for (final sc in std.staticComponents) {
      bom.add(BomLine(mm: sc.mm, qty: sc.qty, source: 'static'));
    }

    // dynamic
    for (final dc in std.dynamicComponents) {
      final matches = <RuleDef>[];
      for (final r in dc.rules) {
        final ok = _logic.apply(r.expr, inputs);
        if (ok == true) matches.add(r);
      }
      if (matches.isEmpty) continue;

      matches.sort((a, b) {
        final p = (b.priority) - (a.priority);
        if (p != 0) return p;
        final la = jsonEncode(a.expr).length;
        final lb = jsonEncode(b.expr).length;
        return lb - la; // more specific first
      });

      final chosen = matches.first;
      for (final out in chosen.outputs) {
        final qty = out.qty ?? QtyFormula.evalInt(out.qtyFormula ?? '1', _onlyNums(inputs));
        bom.add(BomLine(mm: out.mm, qty: qty, source: 'rule:${dc.name}'));
      }
    }
    return bom;
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
