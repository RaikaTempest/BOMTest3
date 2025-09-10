import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/engine.dart';
import '../core/logic.dart'; // for JsonLogic to trace rule matches


class NewJobScreen extends StatefulWidget {
  final List<StandardDef> standards;
  const NewJobScreen({super.key, required this.standards});

  @override
  State<NewJobScreen> createState() => _NewJobScreenState();
}

class _NewJobScreenState extends State<NewJobScreen> {
  StandardDef? selected;
  final Map<String, dynamic> inputs = {};
  List<BomLine> bom = [];
  final eng = RuleEngine();
  bool showDebug = false;
  final _logic = const JsonLogic();
  List<String> trace = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Job')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<StandardDef>(
              value: selected,
              decoration: const InputDecoration(labelText: 'Standard'),
              items: widget.standards
                  .map((s) => DropdownMenuItem(value: s, child: Text('${s.code} — ${s.name}')))
                  .toList(),
              onChanged: (s) {
                setState(() {
                  selected = s;
                  inputs.clear();
                  bom = [];
                });
              },
            ),
            const SizedBox(height: 12),
            if (selected != null) Expanded(child: _ParamsForm(std: selected!, inputs: inputs, onChanged: () {
              setState(() {});
            })),
            Row(
              children: [
                ElevatedButton(
                  onPressed: selected == null ? null : () {
                    final t = <String>[];
                    if (selected != null) {
                      for (final dc in selected!.dynamicComponents) {
                        int idx = 0;
                        for (final r in dc.rules) {
                          final ok = _logic.apply(r.expr, inputs) == true;
                          t.add('[${dc.name}] rule#${idx++} ${ok ? "✓" : "✗"}  expr=${r.expr}');
                        }
                      }
                    }
                    final lines = eng.evaluate(selected!, inputs);
                    setState(() {
                      trace = t;   // <-- save the built trace
                      bom = lines;
                    });

                  },
                  child: const Text('Generate BOM'),
                ),
                const SizedBox(width: 12),
                if (bom.isNotEmpty) Text('${bom.length} lines'),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(()=> showDebug = !showDebug),
                  child: Text(showDebug ? 'Hide debug' : 'Show debug'),
                ),
              ],
            ),
            
            if (showDebug) ...[
              const SizedBox(height: 8),
              Text('Inputs: $inputs', style: const TextStyle(fontFamily: 'monospace')),
              const SizedBox(height: 4),
              const Text('Rule trace:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...trace.map((s)=> Text(s, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
              const Divider(height: 24),
            ],
            const Divider(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: bom.length,
                itemBuilder: (_, i) => ListTile(
                  dense: true,
                  title: Text('${bom[i].mm}  × ${bom[i].qty}'),
                  subtitle: Text(bom[i].source),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParamsForm extends StatelessWidget {
  final StandardDef std;
  final Map<String, dynamic> inputs;
  final VoidCallback onChanged;
  const _ParamsForm({required this.std, required this.inputs, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: std.parameters.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = std.parameters[i];
        final label = p.unit == null || p.unit!.isEmpty ? p.key : '${p.key} (${p.unit})';

        switch (p.type) {
          case ParamType.enumType:
            final items = <String>['', ...p.allowedValues];

            return DropdownButtonFormField<String>(
              value: (inputs[p.key] as String?)?.isEmpty == true
                  ? null
                  : inputs[p.key] as String?,
              decoration: InputDecoration(labelText: label),
              items: items
                  .map((v) => DropdownMenuItem<String>(
                        value: v.isEmpty ? '' : v,
                        child: Text(v.isEmpty ? '-- choose --' : v),
                      ))
                  .toList(),
              onChanged: (v) {
                inputs[p.key] = v ?? '';
                onChanged();
              },
            );
          case ParamType.number:
            return TextFormField(
              decoration: InputDecoration(labelText: label),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final n = num.tryParse(v);
                inputs[p.key] = n ?? 0;
                onChanged();
              },
            );
          case ParamType.boolean:
            final current = (inputs[p.key] == true);
            return CheckboxListTile(
              title: Text(label),
              value: current,
              onChanged: (v) { inputs[p.key] = (v ?? false); onChanged(); },
            );
          case ParamType.text:
          default:
            return TextFormField(
              decoration: InputDecoration(labelText: label),
              onChanged: (v) { inputs[p.key] = v; onChanged(); },
            );
        }
      },
    );
  }
}
