import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/title_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'title_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<MangaTitle> _titles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final ids = await StorageService.getBookmarks();
      final titles = <MangaTitle>[];
      for (final id in ids) {
        try {
          final json = await ApiService.getTitleById(id);
          if (json != null) titles.add(MangaTitle.fromJson(json));
        } catch (_) {}
      }
      if (mounted) setState(() { _titles = titles; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
            color: Color(0xFF7C6FF7), strokeWidth: 2),
      );
    }
    if (_titles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border_rounded,
                color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text('Нет закладок',
                style: TextStyle(color: Colors.white38, fontSize: 16)),
            SizedBox(height: 8),
            Text('Добавьте тайтлы в закладки',
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
        itemCount: _titles.length,
        itemBuilder: (_, i) => _BookmarkTile(
          title: _titles[i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => TitleScreen(title: _titles[i])),
          ).then((_) => _load()),
          onRemove: () async {
            await StorageService.toggleBookmark(_titles[i].id);
            _load();
          },
        ),
      ),
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  final MangaTitle title;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _BookmarkTile({
    required this.title,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: title.coverUrl,
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
                      title.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(title.typeLabel,
                        style: const TextStyle(
                            color: Color(0xFF7C6FF7), fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '${title.totalChapters ?? 0} глав',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.bookmark_remove_rounded,
                    color: Colors.white24),
                onPressed: onRemove,
                tooltip: 'Удалить из закладок',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
