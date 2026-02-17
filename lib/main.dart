import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Drug Bin Locator
/// - Loads TSV from: assets/data/drug_master.tsv
/// - Lets user type Item Description (or any text) to find matching items
/// - Shows results list; tap a result to view Bin Location
///
/// TSV expected columns (tab-separated):
/// Item code    Item Description    UOM    Bin Location
///
/// IMPORTANT:
/// 1) Ensure pubspec.yaml includes:
/// flutter:
///   assets:
///     - assets/data/drug_master.tsv
/// 2) Restart app after editing pubspec.yaml (stop + run again)

void main() {
  runApp(const DrugBinLocatorApp());
}

class DrugBinLocatorApp extends StatelessWidget {
  const DrugBinLocatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drug Bin Locator',
      theme: ThemeData(useMaterial3: true),
      home: const DrugBinHomePage(),
    );
  }
}

class DrugRecord {
  final String itemCode;
  final String itemDescription;
  final String uom;
  final String binLocation;

  const DrugRecord({
    required this.itemCode,
    required this.itemDescription,
    required this.uom,
    required this.binLocation,
  });
}

class DrugBinHomePage extends StatefulWidget {
  const DrugBinHomePage({super.key});

  @override
  State<DrugBinHomePage> createState() => _DrugBinHomePageState();
}

class _DrugBinHomePageState extends State<DrugBinHomePage> {
  final TextEditingController _queryCtrl = TextEditingController();

  bool _loading = true;
  String? _loadError;

  List<DrugRecord> _all = <DrugRecord>[];
  List<DrugRecord> _results = <DrugRecord>[];

  DrugRecord? _selected;

  @override
  void initState() {
    super.initState();
    _loadTsv();
    _queryCtrl.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _queryCtrl.removeListener(_onQueryChanged);
    _queryCtrl.dispose();
    super.dispose();
  }

  String _norm(String s) {
    // Normalize for matching: lowercase + collapse whitespace
    final lower = s.toLowerCase().trim();
    return lower.replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _loadTsv() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _selected = null;
      _results = [];
      _all = [];
    });

    try {
      final raw = await rootBundle.loadString('assets/data/drug_master.tsv');

      final lines = raw.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) {
        throw Exception('TSV is empty');
      }

      // Expect header on first line
      final header = lines.first.split('\t');
      if (header.length < 4) {
        throw Exception('TSV header must have at least 4 columns (got ${header.length})');
      }

      final List<DrugRecord> parsed = [];
      for (int i = 1; i < lines.length; i++) {
        final cols = lines[i].split('\t');
        if (cols.length < 4) continue;

        final itemCode = cols[0].trim();
        final itemDesc = cols[1].trim();
        final uom = cols[2].trim();
        final bin = cols[3].trim();

        if (itemDesc.isEmpty && itemCode.isEmpty) continue;

        parsed.add(DrugRecord(
          itemCode: itemCode,
          itemDescription: itemDesc,
          uom: uom,
          binLocation: bin,
        ));
      }

      if (parsed.isEmpty) {
        throw Exception('No data rows parsed. Check TSV tabs and columns.');
      }

      setState(() {
        _all = parsed;
        _loading = false;
        _loadError = null;
      });

      // Run initial filter if user already typed something
      _filter(_queryCtrl.text);
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError =
            'Failed to load TSV. Unable to load asset or parse data.\n\nDetails: $e';
      });
    }
  }

  void _onQueryChanged() {
    _filter(_queryCtrl.text);
  }

  void _filter(String input) {
    final q = _norm(input);
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _selected = null;
      });
      return;
    }

    // Search strategy:
    // 1) "contains" on itemDescription
    // 2) also allow contains on itemCode
    // 3) if too many results, show top 50
    final List<DrugRecord> hits = [];
    for (final r in _all) {
      final desc = _norm(r.itemDescription);
      final code = _norm(r.itemCode);

      if (desc.contains(q) || code.contains(q)) {
        hits.add(r);
      }
    }

    // Optional: prioritize startsWith matches
    hits.sort((a, b) {
      final ad = _norm(a.itemDescription);
      final bd = _norm(b.itemDescription);
      final aStarts = ad.startsWith(q) ? 0 : 1;
      final bStarts = bd.startsWith(q) ? 0 : 1;
      if (aStarts != bStarts) return aStarts.compareTo(bStarts);
      return ad.compareTo(bd);
    });

    setState(() {
      _results = hits.take(50).toList();
      // Auto-select if single result
      _selected = (_results.length == 1) ? _results.first : null;
    });
  }

  void _pick(DrugRecord r) {
    setState(() {
      _selected = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drug Bin Locator'),
        actions: [
          IconButton(
            tooltip: 'Reload TSV',
            onPressed: _loadTsv,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _ErrorView(
                  message: _loadError!,
                  onRetry: _loadTsv,
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Loaded. Enter Item Description (or Item Code) to find bin.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 10),

                      TextField(
                        controller: _queryCtrl,
                        decoration: InputDecoration(
                          labelText: 'Search',
                          hintText: 'e.g. Duloxetine, Paracetamol, 0004-28-...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _queryCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear',
                                  onPressed: () {
                                    _queryCtrl.clear();
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                          border: const OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (selected != null) ...[
                        _SelectedCard(record: selected),
                        const SizedBox(height: 12),
                      ] else ...[
                        const Text(
                          'Tap a result below to see Bin Location.',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                      ],

                      Expanded(
                        child: _results.isEmpty
                            ? const Center(
                                child: Text(
                                  'No results yet.\nType something to search.',
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.separated(
                                itemCount: _results.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final r = _results[i];
                                  return ListTile(
                                    title: Text(
                                      r.itemDescription.isEmpty
                                          ? '(No description)'
                                          : r.itemDescription,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      'Code: ${r.itemCode.isEmpty ? '-' : r.itemCode}   •   UOM: ${r.uom.isEmpty ? '-' : r.uom}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Text(
                                      r.binLocation.isEmpty ? '-' : r.binLocation,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    onTap: () => _pick(r),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  final DrugRecord record;
  const _SelectedCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bin Location',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              record.binLocation.isEmpty ? '(No bin location found)' : record.binLocation,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              record.itemDescription.isEmpty ? '(No description)' : record.itemDescription,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Item Code: ${record.itemCode.isEmpty ? '-' : record.itemCode}    •    UOM: ${record.uom.isEmpty ? '-' : record.uom}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
