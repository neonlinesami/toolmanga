import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/title_model.dart';
import '../models/chapter_model.dart';

/// Безопасно приводит Map<dynamic,dynamic> к Map<String,dynamic>.
/// jsonDecode возвращает Map<dynamic,dynamic> — прямой каст падает в рантайме.
Map<String, dynamic> _cast(dynamic m) =>
    (m as Map).map((k, v) => MapEntry(k as String, v));

Map<String, dynamic>? _castNullable(dynamic m) =>
    m == null ? null : _cast(m);

class ApiService {
  static const String _site    = 'https://tomilo-lib.ru';
  static const String _apiBase = '$_site/api';
  static const String _s3Base  = 'https://s3.regru.cloud/tomilolib';
  static const String _oldS3   = 'https://tomilolib.s3.regru.cloud';

  static const Map<String, String> _headers = {
    'User-Agent':
    'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Accept':   'application/json',
    'Referer':  '$_site/',
    'Origin':   _site,
  };

  // ── Titles ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getTitles({
    int page = 1,
    int limit = 24,
    String sortBy = 'weekViews',
    String sortOrder = 'desc',
    String? search,
    String? type,
    String? status,
    bool includeAdult = true,
    int? yearFrom,
    int? yearTo,
  }) async {
    final params = {
      'page':         page.toString(),
      'limit':        limit.toString(),
      'sortBy':       sortBy,
      'sortOrder':    sortOrder,
      'includeAdult': includeAdult.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (type   != null) 'type':     type,
      if (status != null) 'status':   status,
      if (yearFrom != null) 'yearFrom': yearFrom.toString(),
      if (yearTo   != null) 'yearTo':   yearTo.toString(),
    };

    final uri = Uri.parse('$_apiBase/titles').replace(queryParameters: params);
    print('!!!TITLES_START: $uri');
    late http.Response response;
    try {
      response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      print('!!!TITLES_EXCEPTION: $e');
      rethrow;
    }
    print('!!!TITLES_STATUS: ${response.statusCode}');
    print('!!!TITLES_BODY_START: ${response.body.substring(0, response.body.length.clamp(0, 300))}');

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success'] == true) {
        final titlesJson = data['data']['titles'] as List;
        // DEBUG: log first 5 coverImage values
        for (int i = 0; i < titlesJson.length && i < 5; i++) {
          final t = titlesJson[i];
          print('COVER_RAW[$i]: ${t['coverImage']}');
        }
        final pagination = data['data']['pagination'] ?? {};
        final titles = titlesJson.map((j) => MangaTitle.fromJson(j)).toList();
        for (int i = 0; i < titles.length && i < 5; i++) {
          print('COVER_URL[$i]: ${titles[i].coverUrl}');
        }
        return {
          'titles': titles,
          'total':  pagination['total'] ?? 0,
          'pages':  pagination['pages'] ?? 1,
          'page':   pagination['page']  ?? 1,
        };
      }
    }
    throw Exception('Ошибка загрузки каталога: ${response.statusCode}');
  }

  // ── Chapters ────────────────────────────────────────────────────────────────

  static Future<List<Chapter>> getChapters(
      String titleId, {
        String sortOrder = 'asc',
        void Function(int loaded, int total)? onProgress,
      }) async {
    final allChapters = <Chapter>[];
    int page = 1;
    const pageSize = 200; // максимум что отдаёт сервер за раз

    while (true) {
      final uri = Uri.parse('$_apiBase/chapters/title/$titleId').replace(
        queryParameters: {
          'page':      page.toString(),
          'limit':     pageSize.toString(),
          'sortOrder': sortOrder,
        },
      );
      if (page == 1) print('CHAPTERS_URL: $uri');

      try {
        final response = await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 15));

        if (page == 1) {
          print('CHAPTERS_STATUS: ${response.statusCode}');
          print('CHAPTERS_BODY: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
        }

        if (response.statusCode == 404) break;
        if (response.statusCode != 200) break;

        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] != true) break;

        final chaptersJson = data['data']?['chapters'] as List?;
        if (chaptersJson == null || chaptersJson.isEmpty) break;

        allChapters.addAll(
          chaptersJson.map((j) => Chapter.fromJson(_cast(j))),
        );

        // Логируем прогресс и total
        final pagination = data['data']?['pagination'];
        final totalCount = (pagination?['total'] as num?)?.toInt() ?? allChapters.length;

        if (page == 1) {
          final totalPages = pagination?['pages'] ?? '?';
          print('CHAPTERS_TOTAL: $totalCount глав, $totalPages страниц');
        }

        onProgress?.call(allChapters.length, totalCount);

        print('CHAPTERS_PAGE $page: получено ${chaptersJson.length}, всего накоплено ${allChapters.length}');

        // Если пришло меньше чем запрашивали — это последняя страница
        if (chaptersJson.length < pageSize) break;
        page++;

      } catch (e) {
        print('CHAPTERS_EXCEPTION page=$page: $e');
        break;
      }
    }

    print('CHAPTERS_RESULT: count=${allChapters.length}');
    return allChapters;
  }

  // ── Pages ────────────────────────────────────────────────────────────────────
  // API возвращает страницы как относительные пути вида:
  //   /titles/{titleId}/chapters/{chapterId}/001.jpg
  // Базовый URL — сайт (https://tomilo-lib.ru), НЕ S3!

  static Future<List<String>> getPages(String chapterId, {List<String>? cachedPages, String? titleId}) async {
    // Если страницы уже пришли вместе со списком глав — используем их
    if (cachedPages != null && cachedPages.isNotEmpty) {
      print('PAGES_FROM_CACHE: $chapterId (${cachedPages.length} стр.)');
      return _resolvePageUrls(cachedPages, titleId, chapterId);
    }

    final uri = Uri.parse('$_apiBase/chapters/$chapterId');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки главы: ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data['success'] != true) {
      throw Exception('API вернул ошибку для главы $chapterId');
    }

    final titleIdRaw = data['data']?['titleId'];
    final String? resolvedTitleId = titleIdRaw is Map
        ? titleIdRaw['_id'] as String?
        : titleIdRaw as String?;

    final pages = data['data']?['pages'] as List?;
    if (pages == null || pages.isEmpty) {
      throw Exception('Нет страниц в этой главе');
    }

    return _resolvePageUrls(
      pages.map((p) => p.toString()).toList(),
      titleId ?? resolvedTitleId,
      chapterId,
    );
  }

  static List<String> _resolvePageUrls(
      List<String> rawPages, String? titleId, String chapterId) {
    return rawPages.map((path) {
      print('PAGE_RAW: $path');
      String url;

      if (path.startsWith('https://') || path.startsWith('http://')) {
        if (path.startsWith(_oldS3)) {
          url = path.replaceFirst(_oldS3, _s3Base);
        } else {
          url = path;
        }
      } else if (path.startsWith('/titles/') || path.startsWith('titles/')) {
        // Новый формат: /titles/{titleId}/chapters/{chapterId}/001.jpg → S3
        final normalized = path.startsWith('/') ? path : '/$path';
        url = '$_s3Base$normalized';
      } else if (path.startsWith('/chapters/')) {
        // Старый формат: /chapters/{chapterId}/001.jpeg → S3 без titleId
        url = '$_s3Base$path';
      } else if (path.startsWith('/')) {
        url = '$_s3Base$path';
      } else {
        url = '$_s3Base/$path';
      }

      print('PAGE_URL: $url');
      return url;
    }).toList();
  }

  /// Строит fallback URL когда основной (S3 с titleId) не загрузился.
  /// S3: s3.regru.cloud/tomilolib/titles/{tid}/chapters/{cid}/001.jpg → пробуем tomilo-lib.ru/titles/...
  /// Сайт: tomilo-lib.ru/titles/... → пробуем S3
  static String? buildFallbackUrl(String primaryUrl, String? titleId, String chapterId) {
    final uri = Uri.tryParse(primaryUrl);
    if (uri == null) return null;
    final filename = uri.pathSegments.lastOrNull;
    if (filename == null || !filename.contains('.')) return null;

    if (!primaryUrl.startsWith(_s3Base)) return null;

    final path = uri.path.replaceFirst('/tomilolib', '');

    if (path.contains('/titles/')) {
      // Новый формат → fallback старый (без titleId)
      return '$_s3Base/chapters/$chapterId/$filename';
    } else if (path.startsWith('/chapters/')) {
      // Старый формат → fallback новый (с titleId)
      if (titleId == null || titleId.isEmpty) return null;
      return '$_s3Base/titles/$titleId/chapters/$chapterId/$filename';
    }

    return null;
  }

  // ── Latest updates (лента обновлений — реальный эндпоинт сайта) ────────────
  // GET /api/titles/latest-updates?page=1&limit=48&includeAdult=true
  // Возвращает главы с вложенным тайтлом, аналогично странице /updates на сайте.
  static Future<Map<String, dynamic>> getLatestUpdates({
    int page = 1,
    int limit = 30,
    bool includeAdult = true,
  }) async {
    final uri = Uri.parse('$_apiBase/titles/latest-updates').replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
        'includeAdult': includeAdult.toString(),
      },
    );

    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('latest-updates: HTTP ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data['success'] != true) {
      throw Exception('latest-updates: API error');
    }

    // Ответ может быть двух форматов:
    // 1. data.chapters[] — список глав с вложенным titleId-объектом
    // 2. data.titles[]   — список тайтлов с вложенной lastChapter
    final inner = _cast(data['data']);
    final pagination = inner['pagination'] ?? {};

    // Формат 1: chapters
    if (inner.containsKey('chapters')) {
      final chapters = inner['chapters'] as List;
      final items = <UpdateItem>[];
      for (final ch in chapters) {
        try {
          final titleJson = _castNullable(ch['titleId']);
          if (titleJson == null) continue;
          final title = MangaTitle.fromJson(titleJson);
          final chapter = Chapter.fromJson(_cast(ch));
          items.add(UpdateItem(title: title, chapter: chapter));
        } catch (_) {}
      }
      return {
        'items': items,
        'pages': (pagination['pages'] as num?)?.toInt() ?? 1,
        'page': (pagination['page'] as num?)?.toInt() ?? page,
      };
    }

    // Формат 2: titles с lastChapter
    if (inner.containsKey('titles')) {
      final titles = inner['titles'] as List;
      final items = <UpdateItem>[];
      for (final t in titles) {
        try {
          final title = MangaTitle.fromJson(_cast(t));
          final lastChJson = _castNullable(t['lastChapter']);
          if (lastChJson == null) continue;
          final chapter = Chapter.fromJson(lastChJson);
          items.add(UpdateItem(title: title, chapter: chapter));
        } catch (_) {}
      }
      return {
        'items': items,
        'pages': (pagination['pages'] as num?)?.toInt() ?? 1,
        'page': (pagination['page'] as num?)?.toInt() ?? page,
      };
    }

    throw Exception('latest-updates: неизвестный формат ответа');
  }

  // ── Latest chapter (только одна последняя глава тайтла) ────────────────────
  // Используется в NewChaptersScreen: один лёгкий запрос вместо загрузки всех глав.
  static Future<Chapter?> getLatestChapter(String titleId) async {
    final uri = Uri.parse('$_apiBase/chapters/title/$titleId').replace(
      queryParameters: {
        'page': '1',
        'limit': '1',
        'sortOrder': 'desc',
      },
    );
    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success'] != true) return null;
      final chaptersJson = data['data']?['chapters'] as List?;
      if (chaptersJson == null || chaptersJson.isEmpty) return null;
      return Chapter.fromJson(_cast(chaptersJson.first));
    } catch (_) {
      return null;
    }
  }

  // ── Title by id / slug ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getTitleById(String id) async {
    final response = await http
        .get(Uri.parse('$_apiBase/titles/$id'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return _castNullable(json['data']);
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getTitleBySlug(String slug) async {
    final response = await http
        .get(Uri.parse('$_apiBase/titles/slug/$slug'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return _castNullable(json['data']);
    }
    return null;
  }
}

/// Пара «тайтл + последняя глава» — результат ApiService.getLatestUpdates().
class UpdateItem {
  final MangaTitle title;
  final Chapter chapter;
  UpdateItem({required this.title, required this.chapter});
}