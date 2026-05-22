import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/title_model.dart';
import '../models/chapter_model.dart';

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
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success'] == true) {
        final titlesJson = data['data']['titles'] as List;
        final pagination = data['data']['pagination'] ?? {};
        return {
          'titles': titlesJson.map((j) => MangaTitle.fromJson(j)).toList(),
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
    int limit = 10000,
  }) async {
    final uri = Uri.parse('$_apiBase/chapters/title/$titleId').replace(
      queryParameters: {
        'page':      '1',
        'limit':     limit.toString(),
        'sortOrder': sortOrder,
      },
    );

    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 404) return [];
      if (response.statusCode != 200) return [];

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success'] != true) return [];

      final chaptersJson = data['data']?['chapters'] as List?;
      if (chaptersJson == null) return [];

      return chaptersJson
          .map((j) => Chapter.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Pages ────────────────────────────────────────────────────────────────────
  // API возвращает страницы как относительные пути вида:
  //   /titles/{titleId}/chapters/{chapterId}/001.jpg
  // Базовый URL — сайт (https://tomilo-lib.ru), НЕ S3!

  static Future<List<String>> getPages(String chapterId) async {
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

    final pages = data['data']?['pages'] as List?;
    if (pages == null || pages.isEmpty) {
      throw Exception('Нет страниц в этой главе');
    }

    return pages.map((p) {
      final path = p.toString();

      // Уже полный URL
      if (path.startsWith('https://') || path.startsWith('http://')) {
        // Нормализуем старый S3 домен если попался
        if (path.startsWith(_oldS3)) {
          return path.replaceFirst(_oldS3, _s3Base);
        }
        return path;
      }

      // Относительный путь → добавляем базу сайта
      // Пример: /titles/{id}/chapters/{id}/001.jpg
      if (path.startsWith('/')) {
        return '$_site$path';
      }

      // Путь без слеша (маловероятно, но на всякий случай)
      return '$_site/$path';
    }).toList();
  }

  // ── Title by id / slug ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getTitleById(String id) async {
    final response = await http
        .get(Uri.parse('$_apiBase/titles/$id'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return json['data'] as Map<String, dynamic>?;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getTitleBySlug(String slug) async {
    final response = await http
        .get(Uri.parse('$_apiBase/titles/slug/$slug'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return json['data'] as Map<String, dynamic>?;
    }
    return null;
  }
}
