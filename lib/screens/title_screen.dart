import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/title_model.dart';
import '../models/chapter_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'reader_screen.dart';

class TitleScreen extends StatefulWidget {
  final MangaTitle title;

  const TitleScreen({super.key, required this.title});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  List<Chapter> _chapters = [];
  bool _loadingChapters = true;
  bool _isBookmarked = false;
  bool _descExpanded = false;
  String _chapterSort = 'asc';
  Map<String, dynamic>? _lastRead;

  @override
  void initState() {
    super.initState();
    _loadChapters();
    _checkBookmark();
    _loadLastRead();
  }

  Future<void> _loadChapters() async {
    try {
      print('CHAPTERS_LOAD: titleId=${widget.title.id}');
      final chapters =
      await ApiService.getChapters(widget.title.id, sortOrder: _chapterSort);
      print('CHAPTERS_RESULT: count=${chapters.length}');
      if (mounted)
        setState(() {
          _chapters = chapters;
          _loadingChapters = false;
        });
    } catch (e) {
      print('CHAPTERS_ERROR: $e');
      if (mounted) setState(() => _loadingChapters = false);
    }
  }

  Future<void> _checkBookmark() async {
    final b = await StorageService.isBookmarked(widget.title.id);
    if (mounted) setState(() => _isBookmarked = b);
  }

  Future<void> _loadLastRead() async {
    final last = await StorageService.getLastChapter(widget.title.id);
    if (mounted) setState(() => _lastRead = last);
  }

  void _toggleBookmark() async {
    await StorageService.toggleBookmark(widget.title.id);
    await _checkBookmark();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBookmarked ? 'Добавлено в закладки' : 'Удалено из закладок'),
          duration: const Duration(seconds: 1),
          backgroundColor: const Color(0xFF1E1E32),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _openChapter(Chapter chapter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          chapter: chapter,
          title: widget.title,
          chapters: _chapters,
        ),
      ),
    ).then((_) => _loadLastRead());
  }

  void _openFirstOrContinue() {
    if (_chapters.isEmpty) return;
    if (_lastRead != null) {
      final lastChapterId = _lastRead!['chapterId'] as String;
      final chapterIdx = _chapters.indexWhere((c) => c.id == lastChapterId);
      if (chapterIdx >= 0) {
        _openChapter(_chapters[chapterIdx]);
        return;
      }
    }
    _openChapter(_chapters.first);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildInfo()),
          SliverToBoxAdapter(child: _buildActions()),
          SliverToBoxAdapter(child: _buildDescription()),
          SliverToBoxAdapter(child: _buildMeta()),
          SliverToBoxAdapter(child: _buildGenres()),
          SliverToBoxAdapter(child: _buildChaptersHeader()),
          if (_loadingChapters)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child:
                      CircularProgressIndicator(color: Color(0xFF7C6FF7), strokeWidth: 2),
                ),
              ),
            )
          else if (_chapters.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text('Главы не найдены',
                      style: TextStyle(color: Colors.white38)),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ChapterTile(
                  chapter: _chapters[i],
                  isLastRead: _lastRead?['chapterId'] == _chapters[i].id,
                  onTap: () => _openChapter(_chapters[i]),
                ),
                childCount: _chapters.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: const Color(0xFF0A0A14),
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 16),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: _toggleBookmark,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: _isBookmarked
                    ? const Color(0xFF7C6FF7)
                    : Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: widget.title.coverUrl,
              fit: BoxFit.cover,
              httpHeaders: const {
                'Referer': 'https://tomilo-lib.ru/',
              },
              errorWidget: (_, __, ___) =>
                  Container(color: const Color(0xFF161625)),
            ),
            // Блюр-градиент
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.5),
                    const Color(0xFF0A0A14),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          if (widget.title.altNames.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.title.altNames.first,
              style:
                  TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(label: widget.title.typeLabel, color: const Color(0xFF7C6FF7)),
              _Chip(
                label: widget.title.statusLabel,
                color: widget.title.status == 'ongoing'
                    ? const Color(0xFF00C896)
                    : widget.title.status == 'completed'
                        ? const Color(0xFF636E90)
                        : const Color(0xFFE17055),
              ),
              if (widget.title.releaseYear != null)
                _Chip(
                    label: widget.title.releaseYear.toString(),
                    color: Colors.white24),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeta() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _StatBlock(
            icon: Icons.star_rounded,
            value: widget.title.averageRating?.toStringAsFixed(1) ?? '—',
            label: 'Рейтинг',
            color: const Color(0xFFFFD700),
          ),
          const SizedBox(width: 28),
          _StatBlock(
            icon: Icons.remove_red_eye_outlined,
            value: _fmt(widget.title.views ?? 0),
            label: 'Просмотры',
            color: Colors.white38,
          ),
          const SizedBox(width: 28),
          _StatBlock(
            icon: Icons.menu_book_rounded,
            value: widget.title.totalChapters?.toString() ?? '—',
            label: 'Глав',
            color: Colors.white38,
          ),
          if (widget.title.author != null) ...[
            const SizedBox(width: 28),
            Expanded(
              child: _StatBlock(
                icon: Icons.person_outline_rounded,
                value: widget.title.author!,
                label: 'Автор',
                color: Colors.white38,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C6FF7),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: Icon(
                  _lastRead != null
                      ? Icons.play_arrow_rounded
                      : Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                label: Text(
                  _lastRead != null ? 'Продолжить' : 'Читать',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15),
                ),
                onPressed: _chapters.isEmpty ? null : _openFirstOrContinue,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            width: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF161625),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                padding: EdgeInsets.zero,
              ),
              onPressed: _toggleBookmark,
              child: Icon(
                _isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: _isBookmarked
                    ? const Color(0xFF7C6FF7)
                    : Colors.white38,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    if (widget.title.description == null || widget.title.description!.isEmpty)
      return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Описание',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          AnimatedCrossFade(
            firstChild: Text(
              widget.title.description!,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 14,
                  height: 1.6),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            secondChild: Text(
              widget.title.description!,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 14,
                  height: 1.6),
            ),
            crossFadeState: _descExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
          GestureDetector(
            onTap: () => setState(() => _descExpanded = !_descExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _descExpanded ? 'Свернуть ↑' : 'Читать далее ↓',
                style: const TextStyle(
                    color: Color(0xFF7C6FF7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenres() {
    if (widget.title.genres.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: widget.title.genres
            .map((g) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161625),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.08), width: 1),
                  ),
                  child: Text(g,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.55), fontSize: 12)),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildChaptersHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Text(
            'Главы',
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF161625),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_chapters.length}',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 12),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() {
                _chapterSort = _chapterSort == 'asc' ? 'desc' : 'asc';
                _chapters = List.from(_chapters.reversed);
              });
            },
            child: Row(
              children: [
                Icon(
                  _chapterSort == 'asc'
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 15,
                  color: const Color(0xFF7C6FF7),
                ),
                const SizedBox(width: 4),
                Text(
                  _chapterSort == 'asc' ? 'По возрастанию' : 'По убыванию',
                  style: const TextStyle(
                      color: Color(0xFF7C6FF7), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatBlock(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.35), fontSize: 11)),
      ],
    );
  }
}

class _ChapterTile extends StatelessWidget {
  final Chapter chapter;
  final bool isLastRead;
  final VoidCallback onTap;

  const _ChapterTile(
      {required this.chapter,
      required this.isLastRead,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: chapter.isLocked ? null : onTap,
      splashColor: const Color(0xFF7C6FF7).withOpacity(0.08),
      highlightColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isLastRead
              ? const Color(0xFF7C6FF7).withOpacity(0.07)
              : Colors.transparent,
          border: Border(
              bottom:
                  BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
        ),
        child: Row(
          children: [
            // Номер главы
            SizedBox(
              width: 36,
              child: Text(
                '${chapter.chapterNumber}',
                style: TextStyle(
                  color: isLastRead
                      ? const Color(0xFF7C6FF7)
                      : Colors.white.withOpacity(0.25),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isLastRead)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF7C6FF7),
                            shape: BoxShape.circle,
                          ),
                        ),
                      Flexible(
                        child: Text(
                          chapter.name,
                          style: TextStyle(
                            color: chapter.isLocked
                                ? Colors.white24
                                : Colors.white,
                            fontSize: 14,
                            fontWeight: isLastRead
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (chapter.releaseDate != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(chapter.releaseDate!),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            if (chapter.isLocked)
              Icon(Icons.lock_rounded,
                  color: Colors.white.withOpacity(0.2), size: 16)
            else if (chapter.views > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_fmtNum(chapter.views),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.2),
                          fontSize: 11)),
                  const SizedBox(width: 3),
                  Icon(Icons.remove_red_eye_outlined,
                      color: Colors.white.withOpacity(0.2), size: 12),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Сегодня';
    if (diff.inDays == 1) return 'Вчера';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _fmtNum(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}