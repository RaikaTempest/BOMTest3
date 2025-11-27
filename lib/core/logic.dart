// lib/core/logic.dart
// JSONLogic-lite + qty formula evaluator

class JsonLogic {
  const JsonLogic();

  dynamic _var(dynamic val, Map<String, dynamic> ctx) {
    if (val is List && val.isNotEmpty) {
      final name = val[0]?.toString();
      final def = val.length > 1 ? val[1] : null;
      return _getVar(name, ctx) ?? def;
    }
    return _getVar(val?.toString(), ctx);
  }

  dynamic _getVar(String? path, Map<String, dynamic> ctx) {
    if (path == null || path.isEmpty) return null;
    dynamic cur = ctx;
    for (final part in path.split('.')) {
      if (cur is Map && cur.containsKey(part)) {
        cur = cur[part];
      } else {
        return null;
      }
    }
    return cur;
  }

  bool _asBool(dynamic v) =>
      v == true || (v is num && v != 0) || (v is String && v.isNotEmpty);

  num _asNum(dynamic v) {
    if (v is num) return v;
    if (v is String) {
      final n = num.tryParse(v);
      if (n != null) return n;
    }
    return 0;
  }

  num? _tryNum(dynamic v) {
    if (v is num) return v;
    if (v is String) {
      return num.tryParse(v);
    }
    return null;
  }

  // Evaluate an arbitrary operand: if it's a map, treat as expression; else pass through
  dynamic _eval(dynamic v, Map<String, dynamic> ctx) {
    if (v is Map) return apply(Map<String, dynamic>.from(v), ctx);
    return v;
  }

  dynamic apply(Map<String, dynamic> expr, Map<String, dynamic> ctx) {
    if (expr.isEmpty || expr.length != 1) return false;
    final op = expr.keys.first;
    final val = expr.values.first;

    switch (op) {
      case 'var':
        return _var(val, ctx);

      case 'and': {
        final list = (val is List) ? val : const [];
        for (final e in list) {
          final r = (e is Map) ? apply(Map<String, dynamic>.from(e), ctx) : e;
          if (!_asBool(r)) return false;
        }
        return true;
      }

      case 'or': {
        final list = (val is List) ? val : const [];
        for (final e in list) {
          final r = (e is Map) ? apply(Map<String, dynamic>.from(e), ctx) : e;
          if (_asBool(r)) return true;
        }
        return false;
      }

      case 'xor': {
        final list = (val is List) ? val : const [];
        var truthyCount = 0;
        for (final e in list) {
          final r = (e is Map) ? apply(Map<String, dynamic>.from(e), ctx) : e;
          if (_asBool(r)) {
            truthyCount++;
            if (truthyCount > 1) return false;
          }
        }
        return truthyCount == 1;
      }

      case 'nor': {
        final list = (val is List) ? val : const [];
        for (final e in list) {
          final r = (e is Map) ? apply(Map<String, dynamic>.from(e), ctx) : e;
          if (_asBool(r)) return false;
        }
        return true;
      }

      case 'nand': {
        final list = (val is List) ? val : const [];
        if (list.isEmpty) return false;
        for (final e in list) {
          final r = (e is Map) ? apply(Map<String, dynamic>.from(e), ctx) : e;
          if (!_asBool(r)) return true;
        }
        return false;
      }

      case '==': {
        final a = _eval(val[0], ctx);
        final b = _eval(val[1], ctx);
        // numeric-aware equality: 4 == 4.0 and '4' == 4 are true, but
        // non-numeric strings should still compare by value.
        final numA = _tryNum(a);
        final numB = _tryNum(b);
        if (numA != null && numB != null) {
          return numA == numB;
        }
        return a == b;
      }

      case '!=':
        return !(apply({'==': val}, ctx) as bool);

      case '>':
        return _asNum(_eval(val[0], ctx)) > _asNum(_eval(val[1], ctx));
      case '>=':
        return _asNum(_eval(val[0], ctx)) >= _asNum(_eval(val[1], ctx));
      case '<':
        return _asNum(_eval(val[0], ctx)) < _asNum(_eval(val[1], ctx));
      case '<=':
        return _asNum(_eval(val[0], ctx)) <= _asNum(_eval(val[1], ctx));

      case 'in': {
        final needle = _eval(val[0], ctx);
        final hay = _eval(val[1], ctx);
        if (hay is List) return hay.contains(needle);
        if (hay is String) {
          return hay.split(',').map((s) => s.trim()).contains('$needle');
        }
        return false;
      }

      default:
        return false;
    }
  }
}

class QtyFormula {
  // very small arithmetic parser: identifiers are replaced by numeric vars
  static int evalInt(String expr, Map<String, dynamic> vars) {
    final tokens = _tokenize(expr, vars);
    final rpn = _toRpn(tokens);
    final v = _evalRpn(rpn);
    return v.round();
  }

  static List<_Tok> _tokenize(String s, Map<String, dynamic> vars) {
    final out = <_Tok>[];
    int i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c.trim().isEmpty) { i++; continue; }
      if ('+-*/()'.contains(c)) { out.add(_Tok(c, _Kind.op)); i++; continue; }
      if (_isDigit(c)) {
        int j = i+1; while (j < s.length && (_isDigit(s[j]) || s[j] == '.')) j++;
        out.add(_Tok(s.substring(i,j), _Kind.num)); i = j; continue;
      }
      // identifier
      int j = i+1; while (j < s.length && _isIdentChar(s[j])) j++;
      final ident = s.substring(i,j);
      final v = vars[ident];
      final numVal = (v is num) ? v.toString() : '0';
      out.add(_Tok(numVal, _Kind.num));
      i = j;
    }
    return out;
  }

  static bool _isDigit(String c) => (c.codeUnitAt(0) ^ 0x30) <= 9 || c == '.';
  static bool _isIdentChar(String c) {
    final cc = c.codeUnitAt(0);
    return (cc >= 65 && cc <= 90) || (cc >= 97 && cc <= 122) ||
           (cc >= 48 && cc <= 57) || c == '_' || c == '.';
  }

  static int _prec(String op) {
    switch (op) {
      case '+': case '-': return 1;
      case '*': case '/': return 2;
      default: return 0;
    }
  }

  static List<_Tok> _toRpn(List<_Tok> tokens) {
    final out = <_Tok>[];
    final ops = <_Tok>[];
    for (final t in tokens) {
      if (t.kind == _Kind.num) {
        out.add(t);
      } else {
        final v = t.val;
        if (v == '(') {
          ops.add(t);
        } else if (v == ')') {
          while (ops.isNotEmpty && ops.last.val != '(') out.add(ops.removeLast());
          if (ops.isNotEmpty && ops.last.val == '(') ops.removeLast();
        } else {
          while (ops.isNotEmpty && _prec(ops.last.val) >= _prec(v)) {
            out.add(ops.removeLast());
          }
          ops.add(t);
        }
      }
    }
    while (ops.isNotEmpty) out.add(ops.removeLast());
    return out;
  }

  static num _evalRpn(List<_Tok> rpn) {
    final st = <num>[];
    for (final t in rpn) {
      if (t.kind == _Kind.num) {
        st.add(num.parse(t.val));
      } else {
        final b = st.removeLast();
        final a = st.removeLast();
        switch (t.val) {
          case '+': st.add(a + b); break;
          case '-': st.add(a - b); break;
          case '*': st.add(a * b); break;
          case '/': st.add(b == 0 ? 0 : a / b); break;
        }
      }
    }
    return st.isEmpty ? 0 : st.last;
  }
}

class _Tok { final String val; final _Kind kind; _Tok(this.val, this.kind); }
enum _Kind { num, op }
