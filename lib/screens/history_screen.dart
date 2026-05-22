import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/title_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'title_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final history = await StorageService.getHistory();
    if (mounted) setState(() { _history = history; _loading = false; });
  }

  /// Строит URL обложки из сохранённого поля coverImage, используя ту же
  /// логику что и MangaTitle.coverUrl (4 формата).
  String _resolveCoverUrl(String? coverImage, String titleId) {
    const site   = 'https://tomilo-lib.ru';
    const oldS3  = 'https://tomilolib.s3.regru.cloud';
    const newS3  = 'https://s3.regru.cloud/tomilolib';

    if (coverImage == null || coverImage.isEmpty) {
      return '$site/uploads/titles/$titleId/cover.jpg';
    }
    if (coverImage.startsWith(oldS3))      return coverImage.replaceFirst(oldS3, newS3);
    if (coverImage.startsWith('https://') ||
        coverImage.startsWith('http://'))   return coverImage;
    if (coverImage.startsWith('/'))         return '$site$coverImage';
    return '$site/$coverImage';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
            color: Color(0xFF7C6FF7), strokeWidth: 2),
      );
    }
    if (_history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text('История пуста',
                style: TextStyle(color: Colors.white38, fontSize: 16)),
            SizedBox(height: 8),
            Text('Здесь будет история чтения',
                style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF7C6FF7),
      backgroundColor: const Color(0xFF161625),
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: _history.length,
        itemBuilder: (_, i) {
          final item      = _history[i];
          final titleId   = item['titleId']   as String? ?? '';
          final coverUrl  = _resolveCoverUrl(
              item['coverImage'] as String?, titleId);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF13131F),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: InkWell(
              onTap: () async {
                final slug = item['titleSlug'] as String?;
                if (slug == null || slug.isEmpty) return;
                try {
                  final json = await ApiService.getTitleBySlug(slug);
                  if (json != null && mounted) {
                    final title = MangaTitle.fromJson(json);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => TitleScreen(title: title)),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Ошибка: $e'),
                      backgroundColor: const Color(0xFF1E1E32),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: coverUrl,
                        width: 60,
                        height: 85,
                        fit: BoxFit.cover,
                        httpHeaders: const {
                          'Referer': 'https://tomilo-lib.ru/',
                          'Origin': 'https://tomilo-lib.ru',
                        },
                        placeholder: (_, __) => Container(
                            width: 60,
                            height: 85,
                            color: const Color(0xFF1E1E32)),
                        errorWidget: (_, __, ___) => Container(
                          width: 60,
                          height: 85,
                          color: const Color(0xFF1E1E32),
                          child: const Icon(Icons.broken_image_outlined,
                              color: Colors.white12, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['titleName'] as String? ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C6FF7).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['chapterName'] as String? ?? '',
                              style: const TextStyle(
                                  color: Color(0xFF7C6FF7), fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatDate(item['timestamp'] as String?),
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.white.withOpacity(0.2)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Только что';
    if (diff.inHours   < 1)  return '${diff.inMinutes} мин. назад';
    if (diff.inDays    < 1)  return '${diff.inHours} ч. назад';
    if (diff.inDays   == 1)  return 'Вчера';
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}';
  }
}
