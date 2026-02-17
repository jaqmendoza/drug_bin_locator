import 'package:flutter/services.dart' show rootBundle;

class DrugBinRepository {
  // Key = normalized item description, Value = bin location
  final Map<String, String> _descToBin = {};

  bool get isLoaded => _descToBin.isNotEmpty;

  Future<void> loadFromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);

    final lines = raw.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return;

    // TAB-separated header
    final header = lines.first.split('\t').map((e) => e.trim()).toList();

    int idxDesc = header.indexWhere((h) => h.toLowerCase() == 'item description');
    int idxBin = header.indexWhere((h) => h.toLowerCase() == 'bin location');

    if (idxDesc == -1 || idxBin == -1) {
      throw Exception(
        'TSV header must contain "Item Description" and "Bin Location". Found: $header',
      );
    }

    _descToBin.clear();

    for (int i = 1; i < lines.length; i++) {
      final cols = lines[i].split('\t');

      if (cols.length <= idxDesc || cols.length <= idxBin) continue;

      final desc = cols[idxDesc].trim();
      final bin = cols[idxBin].trim();

      if (desc.isEmpty || bin.isEmpty) continue;

      _descToBin[_norm(desc)] = bin;
    }
  }

  /// Exact match by description (after normalization)
  String? findBinByDescription(String description) {
    return _descToBin[_norm(description)];
  }

  /// Fallback: if OCR output contains extra words
  String? findBinByContains(String ocrText) {
    final text = _norm(ocrText);
    if (text.isEmpty) return null;

    final exact = _descToBin[text];
    if (exact != null) return exact;

    for (final entry in _descToBin.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return null;
  }

  String _norm(String s) {
    return s
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
