import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _bookmarksKey = 'bookmarks';
  static const String _historyKey = 'reading_history';
  static const String _progressKey = 'reading_progress';

  // --- Закладки ---

  static Future<List<String>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_bookmarksKey) ?? [];
  }

  static Future<bool> isBookmarked(String titleId) async {
    final bookmarks = await getBookmarks();
    return bookmarks.contains(titleId);
  }

  static Future<void> toggleBookmark(String titleId) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList(_bookmarksKey) ?? [];
    if (bookmarks.contains(titleId)) {
      bookmarks.remove(titleId);
    } else {
      bookmarks.insert(0, titleId);
    }
    await prefs.setStringList(_bookmarksKey, bookmarks);
  }

  // --- История чтения ---

  static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? [];
    return raw.map((s) {
      final decoded = jsonDecode(s);
      return Map<String, dynamic>.from(decoded as Map);
    }).toList();
  }

  static Future<void> addToHistory({
    required String titleId,
    required String titleSlug,
    required String titleName,
    required String? coverImage,
    required String chapterId,
    required int chapterNumber,
    required String chapterName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? [];
    final history = raw.map((s) {
      final decoded = jsonDecode(s);
      return Map<String, dynamic>.from(decoded as Map);
    }).toList();

    // Удалим старую запись для этого тайтла
    history.removeWhere((h) => h['titleId'] == titleId);

    // Добавим новую в начало
    history.insert(0, {
      'titleId': titleId,
      'titleSlug': titleSlug,
      'titleName': titleName,
      'coverImage': coverImage,
      'chapterId': chapterId,
      'chapterNumber': chapterNumber,
      'chapterName': chapterName,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Ограничим историю 100 записями
    if (history.length > 100) history.removeLast();

    await prefs.setStringList(
      _historyKey,
      history.map((h) => jsonEncode(h)).toList(),
    );
  }

  // --- Прогресс чтения (номер последней прочитанной страницы) ---

  static Future<void> saveProgress(String chapterId, int page) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey);

    final Map<String, dynamic> progress = raw != null
        ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
        : {};

    progress[chapterId] = page;

    // Автоочистка: держим прогресс только для глав из истории чтения.
    if (progress.length > 500) {
      await _pruneProgress(prefs, progress);
      return; // _pruneProgress сохраняет сам
    }

    await prefs.setString(_progressKey, jsonEncode(progress));
  }

  /// Удаляет из прогресса записи глав, которые не встречаются в истории.
  static Future<void> _pruneProgress(
      SharedPreferences prefs,
      Map<String, dynamic> progress,
      ) async {
    final raw = prefs.getStringList(_historyKey) ?? [];
    final history = raw.map((s) {
      final decoded = jsonDecode(s);
      return Map<String, dynamic>.from(decoded as Map);
    }).toList();

    final knownChapterIds = history.map((h) => h['chapterId'] as String).toSet();

    progress.removeWhere((key, _) => !knownChapterIds.contains(key));
    await prefs.setString(_progressKey, jsonEncode(progress));
  }

  /// Принудительная очистка прогресса: оставляет только главы из истории.
  static Future<int> pruneProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey);
    if (raw == null) return 0;

    final progress = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final before = progress.length;
    await _pruneProgress(prefs, progress);
    return before - progress.length;
  }

  /// Полная очистка всех данных приложения.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bookmarksKey);
    await prefs.remove(_historyKey);
    await prefs.remove(_progressKey);
  }

  /// Приблизительный размер хранилища (сумма длин всех строк в байтах).
  static Future<int> estimateStorageBytes() async {
    final prefs = await SharedPreferences.getInstance();
    int total = 0;
    final history = prefs.getStringList(_historyKey) ?? [];
    for (final s in history) total += s.length;
    final progress = prefs.getString(_progressKey) ?? '';
    total += progress.length;
    final bookmarks = prefs.getStringList(_bookmarksKey) ?? [];
    for (final s in bookmarks) total += s.length;
    return total;
  }

  static Future<int> getProgress(String chapterId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey);
    if (raw == null) return 1;

    final progress = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return progress[chapterId] ?? 1;
  }

  // --- Последняя прочитанная глава тайтла ---

  static Future<Map<String, dynamic>?> getLastChapter(String titleId) async {
    final history = await getHistory();
    try {
      return history.firstWhere((h) => h['titleId'] == titleId);
    } catch (_) {
      return null;
    }
  }
}