import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecentService {
  static const _key = 'recent_files';

  Future<List<Map<String, dynamic>>> getRecent() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key) ?? const [];
    return raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  Future<void> add(String path, String name, String type) async {
    final p = await SharedPreferences.getInstance();
    final items = await getRecent();
    items.removeWhere((e) => e['path'] == path);
    items.insert(0, {
      'path': path,
      'name': name,
      'type': type,
      'openedAt': DateTime.now().toIso8601String(),
    });
    final trimmed = items.take(20).map(jsonEncode).toList();
    await p.setStringList(_key, trimmed);
  }
}
