import 'package:flutter/material.dart';
import '../core/models.dart';

class WorkLocation {
  String barcode;
  Set<String> standards;
  WorkLocation({this.barcode = '', Set<String>? standards})
    : standards = standards ?? <String>{};
}

class ProjectScreen extends StatefulWidget {
  final List<StandardDef> standards;
  final int initialCount;
  const ProjectScreen({
    super.key,
    required this.standards,
    required this.initialCount,
  });

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  late List<WorkLocation> locations;

  @override
  void initState() {
    super.initState();
    locations = List.generate(widget.initialCount, (_) => WorkLocation());
  }

  Future<void> _addLocation() async {
    setState(() => locations.add(WorkLocation()));
  }

  Future<void> _removeLocation(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete work location?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirm == true) {
      setState(() => locations.removeAt(index));
    }
  }

  Future<void> _openStandards(int index) async {
    final updated = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder:
            (_) => LocationStandardsScreen(
              available: widget.standards,
              selected: locations[index].standards,
            ),
      ),
    );
    if (updated != null) {
      setState(() => locations[index].standards = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project')),
      body: ListView.builder(
        itemCount: locations.length,
        itemBuilder: (context, index) {
          final loc = locations[index];
          return ListTile(
            title: TextFormField(
              initialValue: loc.barcode,
              decoration: const InputDecoration(labelText: 'Barcode'),
              onChanged: (v) => loc.barcode = v,
            ),
            subtitle: Text(
              loc.standards.isEmpty
                  ? 'No standards'
                  : '${loc.standards.length} standard${loc.standards.length == 1 ? '' : 's'}',
            ),
            onTap: () => _openStandards(index),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _removeLocation(index),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addLocation,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class LocationStandardsScreen extends StatefulWidget {
  final List<StandardDef> available;
  final Set<String> selected;
  const LocationStandardsScreen({
    super.key,
    required this.available,
    required this.selected,
  });

  @override
  State<LocationStandardsScreen> createState() =>
      _LocationStandardsScreenState();
}

class _LocationStandardsScreenState extends State<LocationStandardsScreen> {
  late Set<String> selected;

  @override
  void initState() {
    super.initState();
    selected = Set.of(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply Standards'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(selected),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        children:
            widget.available.map((s) {
              return CheckboxListTile(
                title: Text('${s.code} — ${s.name}'),
                value: selected.contains(s.code),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      selected.add(s.code);
                    } else {
                      selected.remove(s.code);
                    }
                  });
                },
              );
            }).toList(),
      ),
    );
  }
}
