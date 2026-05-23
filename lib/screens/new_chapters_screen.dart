import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import 'title_screen.dart';
import 'reader_screen.dart';

class NewChaptersScreen extends StatefulWidget {
  const NewChaptersScreen({super.key});

  @override
  State<NewChaptersScreen> createState() => _NewChaptersScreenState();
}

class _NewChaptersScreenState extends State<NewChaptersScreen> {
  List<UpdateItem> _items = [];
  bool _loading = true;
  bool _hasMore = true;
  int _page = 1;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        if (!_loading && _hasMore) _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    if (reset) {
      setState(() {
        _items = [];
        _page = 1;
        _hasMore = true;
      });
    }
    setState(() => _loading = true);
    try {
      final result = await ApiService.getLatestUpdates(
        page: _page,
        limit: 30,
      );
      final newItems = result['items'] as List<UpdateItem>;
      final totalPages = result['pages'] as int;

      if (mounted) {
        setState(() {
          _items.addAll(newItems);
          _hasMore = _page < totalPages;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    _page++;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF7C6FF7),
                backgroundColor: const Color(0xFF161625),
                onRefresh: () => _load(reset: true),
                child: _items.isEmpty && _loading
                    ? _buildShimmer()
                    : _items.isEmpty
                    ? const Center(
                  child: Text('Ничего нет',
                      style: TextStyle(color: Colors.white38)),
                )
                    : ListView.builder(
                  controller: _scroll,
                  padding:
                  const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _items.length + (_hasMore ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == _items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF7C6FF7),
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }
                    final item = _items[i];
                    return _ChapterCard(
                      item: item,
                      onTapTitle: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TitleScreen(title: item.title),
                        ),
                      ),
                      onTapChapter: () async {
                        if (item.chapter.isLocked) return;
                        try {
                          final chapters =
                          await ApiService.getChapters(
                              item.title.id);
                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReaderScreen(
                                  chapter: item.chapter,
                                  title: item.title,
                                  chapters: chapters,
                                ),
                              ),
                            );
                          }
                        } catch (_) {}
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A14),
        border: Border(
          bottom:
          BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white70, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Новые главы',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF7C6FF7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('NEW',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 12,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 88,
        decoration: BoxDecoration(
          color: const Color(0xFF161625),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final UpdateItem item;
  final VoidCallback onTapTitle;
  final VoidCallback onTapChapter;

  const _ChapterCard({
    required this.item,
    required this.onTapTitle,
    required this.onTapChapter,
  });

  @override
  Widget build(BuildContext context) {
    final ch = item.chapter;
    final t = item.title;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          // Обложка
          GestureDetector(
            onTap: onTapTitle,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13),
                bottomLeft: Radius.circular(13),
              ),
              child: SizedBox(
                width: 60,
                height: 88,
                child: CachedNetworkImage(
                  imageUrl: t.coverUrl,
                  fit: BoxFit.cover,
                  httpHeaders: const {
                    'Referer': 'https://tomilo-lib.ru/',
                    'Origin': 'https://tomilo-lib.ru',
                  },
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFF1E1E32),
                    child: const Icon(Icons.broken_image_outlined,
                        color: Colors.white12, size: 22),
                  ),
                ),
              ),
            ),
          ),
          // Инфо
          Expanded(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onTapTitle,
                    child: Text(
                      t.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: ch.isLocked ? null : onTapChapter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: ch.isLocked
                            ? Colors.white.withOpacity(0.05)
                            : const Color(0xFF7C6FF7).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (ch.isLocked)
                            Icon(Icons.lock_rounded,
                                color: Colors.white.withOpacity(0.25),
                                size: 12)
                          else
                            const Icon(Icons.play_arrow_rounded,
                                color: Color(0xFF7C6FF7), size: 12),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Глава ${ch.chapterNumber}',
                              style: TextStyle(
                                color: ch.isLocked
                                    ? Colors.white24
                                    : const Color(0xFF7C6FF7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Дата
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              ch.releaseDate != null ? _fmtDate(ch.releaseDate!) : '',
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин.';
    if (diff.inHours < 24) return '${diff.inHours} ч.';
    if (diff.inDays < 7) return '${diff.inDays} дн.';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
  }
}