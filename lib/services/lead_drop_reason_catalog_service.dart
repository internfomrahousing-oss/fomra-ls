import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lead_drop_reason.dart';

class LeadDropReasonCatalogService extends ChangeNotifier {
  LeadDropReasonCatalogService._();

  static final instance = LeadDropReasonCatalogService._();

  static const _prefsKey = 'lead_drop_reason_catalog_v1';

  List<LeadDropReason> _items = List.of(defaultLeadDropReasons);
  bool _loaded = false;

  List<LeadDropReason> get current => List.unmodifiable(_items);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      _items = List.of(defaultLeadDropReasons);
      _loaded = true;
      notifyListeners();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final parsed = decoded
            .whereType<Map>()
            .map((entry) => LeadDropReason.fromJson(
                  Map<String, dynamic>.from(entry),
                ))
            .where((reason) =>
                reason.id.trim().isNotEmpty && reason.label.trim().isNotEmpty)
            .toList();
        _items = parsed.isEmpty ? List.of(defaultLeadDropReasons) : parsed;
      } else {
        _items = List.of(defaultLeadDropReasons);
      }
    } catch (_) {
      _items = List.of(defaultLeadDropReasons);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_items.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> setItems(List<LeadDropReason> items) async {
    _items = List<LeadDropReason>.from(items);
    _loaded = true;
    notifyListeners();
    await _persist();
  }

  Future<void> addReason(String label) async {
    final clean = label.trim();
    if (clean.isEmpty) return;
    final id = _uniqueIdFromLabel(clean);
    await setItems([
      ..._items,
      LeadDropReason(id: id, label: clean),
    ]);
  }

  Future<void> updateReason(String id, String label) async {
    final clean = label.trim();
    if (clean.isEmpty) return;
    final next = _items
        .map((item) => item.id == id ? item.copyWith(label: clean) : item)
        .toList();
    await setItems(next);
  }

  Future<void> deleteReason(String id) async {
    await setItems(_items.where((item) => item.id != id).toList());
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final next = List<LeadDropReason>.from(_items);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    await setItems(next);
  }

  LeadDropReason? findByRaw(String? raw) =>
      leadDropReasonFromRaw(raw, catalog: _items);

  String displayLabelForRaw(String? raw) =>
      findByRaw(raw)?.label ?? (raw?.trim().isEmpty ?? true ? '—' : raw!.trim());

  String _uniqueIdFromLabel(String label) {
    final slug = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final base = slug.isEmpty ? 'reason' : slug;
    var candidate = base;
    var suffix = 2;
    while (_items.any((item) => item.id == candidate)) {
      candidate = '${base}_$suffix';
      suffix++;
    }
    return candidate;
  }
}