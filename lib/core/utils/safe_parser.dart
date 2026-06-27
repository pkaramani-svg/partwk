class SafeParser {
  static Map<String, String> asMapStringString(dynamic map) {
    if (map == null || map is! Map) return {};
    return map.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
  }

  static List<String> asListString(dynamic list) {
    if (list == null || list is! List) return [];
    return list.map((e) => e?.toString() ?? '').toList();
  }
}
