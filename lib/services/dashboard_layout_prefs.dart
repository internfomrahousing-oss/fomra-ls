import 'package:shared_preferences/shared_preferences.dart';

/// Persisted widget order for the management BI dashboard.
class DashboardLayoutPrefs {
  static const _key = 'mgmt_bi_widget_order_v2';

  static const defaultOrder = [
    'pipeline',
    'recommendations',
    'funnel',
    'ageing',
    'bottlenecks',
    'sla',
    'executives',
    'district',
    'activities',
  ];

  static Future<List<String>> loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ??
        prefs.getStringList('mgmt_bi_widget_order_v1');
    if (raw == null || raw.isEmpty) return List.of(defaultOrder);
    final known = defaultOrder.toSet();
    final cleaned = raw.where(known.contains).toList();
    for (final id in defaultOrder) {
      if (!cleaned.contains(id)) cleaned.add(id);
    }
    return cleaned;
  }

  static Future<void> saveOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, order);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove('mgmt_bi_widget_order_v1');
  }
}
