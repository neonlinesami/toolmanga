import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/title_model.dart';
import '../models/chapter_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

enum ReaderMode { webtoon, manga }

class ReaderScreen extends StatefulWidget {
  final Chapter chapter;
  final MangaTitle title;
  final List<Chapter> chapters;

  const ReaderScreen({
    super.key,
    required this.chapter,
    required this.title,
    required this.chapters,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late Chapter _currentChapter;
  List<String> _pages = [];
  List<String> _preloadedNextPages = [];
  bool _loading = true;
  bool _uiVisible = true;
  ReaderMode _readerMode = ReaderMode.webtoon;
  int _currentPage = 1;
  Timer? _uiHideTimer;

  // ── Settings state ──────────────────────────────────────
  double _brightness    = 1.0;
  double _contrast      = 1.0;
  double _containerWidth = 768;
  String _menuShow      = 'scroll';
  bool   _tapZone       = false;
  bool   _doubleTapZoom = true;
  bool   _keepScreenOn  = true;

  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapter;
    _loadPages();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scheduleHideUI();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    _uiHideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _scheduleHideUI() {
    _uiHideTimer?.cancel();
    _uiHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _uiVisible && !_loading) {
        setState(() => _uiVisible = false);
      }
    });
  }

  Future<void> _loadPages() async {
    setState(() {
      _loading = true;
      _pages = [];
      _preloadedNextPages = [];
    });
    try {
      final pages = await ApiService.getPages(_currentChapter.id);
      if (pages.isEmpty) throw Exception('Нет страниц в этой главе');

      final savedPage = await StorageService.getProgress(_currentChapter.id);

      if (mounted) {
        setState(() {
          _pages = pages;
          _loading = false;
          _currentPage = savedPage.clamp(1, pages.length);
        });
      }

      await StorageService.addToHistory(
        titleId: widget.title.id,
        titleSlug: widget.title.slug,
        titleName: widget.title.name,
        coverImage: widget.title.coverImage,
        chapterId: _currentChapter.id,
        chapterNumber: _currentChapter.chapterNumber,
        chapterName: _currentChapter.name,
      );

      if (_readerMode == ReaderMode.manga && _pageController.hasClients) {
        _pageController.jumpToPage(_currentPage - 1);
      }

      _preloadNextChapter();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: const Color(0xFF1E1E32),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _preloadNextChapter() async {
    if (!hasNext) return;
    final idx = widget.chapters.indexWhere((c) => c.id == _currentChapter.id);
    if (idx < 0 || idx >= widget.chapters.length - 1) return;
    final nextChapter = widget.chapters[idx + 1];
    try {
      final pages = await ApiService.getPages(nextChapter.id);
      if (pages.isNotEmpty && mounted) {
        setState(() => _preloadedNextPages = pages);
      }
    } catch (_) {}
  }

  void _toggleUI() {
    setState(() => _uiVisible = !_uiVisible);
    if (_uiVisible) _scheduleHideUI();
  }

  void _onPageChanged(int index) {
    final page = index + 1;
    setState(() => _currentPage = page);
    StorageService.saveProgress(_currentChapter.id, page);
  }

  void _goToChapter(Chapter chapter) {
    _uiHideTimer?.cancel();
    setState(() {
      _currentChapter = chapter;
      _currentPage = 1;
    });
    _loadPages();
  }

  void _prevChapter() {
    final idx = widget.chapters.indexWhere((c) => c.id == _currentChapter.id);
    if (idx > 0) _goToChapter(widget.chapters[idx - 1]);
  }

  void _nextChapter() {
    final idx = widget.chapters.indexWhere((c) => c.id == _currentChapter.id);
    if (idx < widget.chapters.length - 1) {
      final next = widget.chapters[idx + 1];
      if (_preloadedNextPages.isNotEmpty) {
        setState(() {
          _currentChapter = next;
          _pages = _preloadedNextPages;
          _preloadedNextPages = [];
          _currentPage = 1;
          _loading = false;
        });
        StorageService.addToHistory(
          titleId: widget.title.id,
          titleSlug: widget.title.slug,
          titleName: widget.title.name,
          coverImage: widget.title.coverImage,
          chapterId: next.id,
          chapterNumber: next.chapterNumber,
          chapterName: next.name,
        );
        _preloadNextChapter();
      } else {
        _goToChapter(next);
      }
    }
  }

  bool get hasPrev {
    final idx = widget.chapters.indexWhere((c) => c.id == _currentChapter.id);
    return idx > 0;
  }

  bool get hasNext {
    final idx = widget.chapters.indexWhere((c) => c.id == _currentChapter.id);
    return idx < widget.chapters.length - 1;
  }

  // ── Settings sheet ──────────────────────────────────────
  /// Настройки ЧИТАЛКИ — управляют только процессом чтения текущей главы.
  /// Не пересекаются с глобальными настройками приложения (тема, кэш, аккаунт).
  void _showSettings() {
    _uiHideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 20,
              right: 20,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),

                // Заголовок + сброс
                Row(
                  children: [
                    const Icon(Icons.menu_book_rounded,
                        color: Color(0xFF7C6FF7), size: 20),
                    const SizedBox(width: 8),
                    const Text('Читалка',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _brightness     = 1.0;
                          _contrast       = 1.0;
                          _readerMode     = ReaderMode.webtoon;
                          _tapZone        = false;
                          _doubleTapZoom  = true;
                          _keepScreenOn   = true;
                        });
                        setSheet(() {});
                      },
                      child: Row(children: [
                        Icon(Icons.refresh_rounded,
                            color: Colors.white.withOpacity(0.4), size: 14),
                        const SizedBox(width: 4),
                        Text('Сбросить',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 13)),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Режим отображения ─────────────────────────────
                _sheetLabel('РЕЖИМ'),
                const SizedBox(height: 8),
                _segRow(
                  ctx: ctx,
                  label: 'Направление чтения',
                  sub: 'Лента — скролл вниз, Манга — свайп влево',
                  options: const [
                    ('webtoon', 'Лента ↓'),
                    ('manga',   'Манга ←'),
                  ],
                  value: _readerMode == ReaderMode.webtoon ? 'webtoon' : 'manga',
                  onChanged: (v) {
                    setState(() {
                      _readerMode = v == 'webtoon'
                          ? ReaderMode.webtoon
                          : ReaderMode.manga;
                    });
                    setSheet(() {});
                  },
                ),

                Divider(color: Colors.white.withOpacity(0.07), height: 28),

                // ── Изображение ───────────────────────────────────
                _sheetLabel('ИЗОБРАЖЕНИЕ'),
                const SizedBox(height: 12),
                _sliderRow(
                  ctx: ctx,
                  label: 'Яркость',
                  value: _brightness,
                  min: 0.2,
                  max: 2.0,
                  display: '${(_brightness * 100).round()}%',
                  onChanged: (v) {
                    setState(() => _brightness = v);
                    setSheet(() {});
                  },
                ),
                const SizedBox(height: 14),
                _sliderRow(
                  ctx: ctx,
                  label: 'Контраст',
                  value: _contrast,
                  min: 0.2,
                  max: 2.0,
                  display: '${(_contrast * 100).round()}%',
                  onChanged: (v) {
                    setState(() => _contrast = v);
                    setSheet(() {});
                  },
                ),

                Divider(color: Colors.white.withOpacity(0.07), height: 28),

                // ── Управление ────────────────────────────────────
                _sheetLabel('УПРАВЛЕНИЕ'),
                const SizedBox(height: 10),
                _switchRowSheet(
                  ctx: ctx,
                  icon: Icons.touch_app_rounded,
                  label: 'Тап-зоны смены страниц',
                  sub: 'Тап по краям экрана → перелистывание',
                  value: _tapZone,
                  onChanged: (v) {
                    setState(() => _tapZone = v);
                    setSheet(() {});
                  },
                ),
                const SizedBox(height: 10),
                _switchRowSheet(
                  ctx: ctx,
                  icon: Icons.zoom_in_rounded,
                  label: 'Двойной тап — зум',
                  sub: 'Быстрое увеличение изображения',
                  value: _doubleTapZoom,
                  onChanged: (v) {
                    setState(() => _doubleTapZoom = v);
                    setSheet(() {});
                  },
                ),
                const SizedBox(height: 10),
                _switchRowSheet(
                  ctx: ctx,
                  icon: Icons.screen_lock_landscape_rounded,
                  label: 'Не гасить экран',
                  sub: 'Экран остаётся включённым во время чтения',
                  value: _keepScreenOn,
                  onChanged: (v) {
                    setState(() => _keepScreenOn = v);
                    setSheet(() {});
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    ).then((_) => _scheduleHideUI());
  }

  Widget _switchRowSheet({
    required BuildContext ctx,
    required IconData icon,
    required String label,
    required String sub,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF7C6FF7).withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: const Color(0xFF7C6FF7), size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              Text(sub,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.35), fontSize: 11)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF7C6FF7),
          activeTrackColor: const Color(0xFF7C6FF7).withOpacity(0.3),
          inactiveThumbColor: Colors.white38,
          inactiveTrackColor: Colors.white.withOpacity(0.1),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  Widget _sheetLabel(String t) => Text(
        t,
        style: TextStyle(
          color: Colors.white.withOpacity(0.35),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      );

  Widget _segRow({
    required BuildContext ctx,
    required String label,
    String? sub,
    required List<(String, String)> options,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(sub,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.35), fontSize: 11)),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 0; i < options.length; i++) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(options[i].$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 34,
                    decoration: BoxDecoration(
                      color: value == options[i].$1
                          ? const Color(0xFF7C6FF7)
                          : const Color(0xFF1E1E32),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(options[i].$2,
                          style: TextStyle(
                              color: value == options[i].$1
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: 12,
                              fontWeight: value == options[i].$1
                                  ? FontWeight.w600
                                  : FontWeight.normal)),
                    ),
                  ),
                ),
              ),
              if (i < options.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }

  Widget _sliderRow({
    required BuildContext ctx,
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(display,
                style: const TextStyle(
                    color: Color(0xFF7C6FF7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 2),
        SliderTheme(
          data: SliderTheme.of(ctx).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
            activeTrackColor: const Color(0xFF7C6FF7),
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            thumbColor: const Color(0xFF7C6FF7),
            overlayColor: const Color(0xFF7C6FF7).withOpacity(0.2),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_loading)
            const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF7C6FF7), strokeWidth: 2),
            )
          else if (_pages.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image_outlined,
                      color: Colors.white24, size: 56),
                  const SizedBox(height: 16),
                  const Text('Страницы не найдены',
                      style: TextStyle(color: Colors.white38)),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: _loadPages,
                    child: const Text('Повторить',
                        style: TextStyle(color: Color(0xFF7C6FF7))),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: _toggleUI,
              child: _buildImageFilter(
                child: _readerMode == ReaderMode.webtoon
                    ? _buildWebtoonReader()
                    : _buildMangaReader(),
              ),
            ),

          // UI overlay
          AnimatedOpacity(
            opacity: _uiVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_uiVisible,
              child: Stack(
                children: [
                  _buildTopBar(),
                  if (!_loading && _pages.isNotEmpty) _buildBottomBar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Apply brightness / contrast filter over reader content
  Widget _buildImageFilter({required Widget child}) {
    if (_brightness == 1.0 && _contrast == 1.0) return child;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_buildMatrix(_brightness, _contrast)),
      child: child,
    );
  }

  List<double> _buildMatrix(double brightness, double contrast) {
    // contrast: scale around 0.5 mid-point
    final c = contrast;
    final b = (brightness - 1.0) * 255;
    final t = (1.0 - c) / 2.0;
    return [
      c, 0, 0, 0, b + t * 255,
      0, c, 0, 0, b + t * 255,
      0, 0, c, 0, b + t * 255,
      0, 0, 0, 1, 0,
    ];
  }

  Widget _buildWebtoonReader() {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification && _pages.isNotEmpty) {
          final offset = _scrollController.offset;
          final pageHeight = MediaQuery.of(context).size.width * 1.5;
          final approxPage = (offset / pageHeight).floor() + 1;
          if (approxPage != _currentPage &&
              approxPage >= 1 &&
              approxPage <= _pages.length) {
            setState(() => _currentPage = approxPage);
            StorageService.saveProgress(_currentChapter.id, approxPage);
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _pages.length + (hasNext ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == _pages.length) return _buildNextChapterCard();
          return _WebtoonPageImage(url: _pages[i], index: i);
        },
      ),
    );
  }

  Widget _buildMangaReader() {
    return PageView.builder(
      controller: _pageController,
      reverse: true,
      onPageChanged: _onPageChanged,
      itemCount: _pages.length + (hasNext ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == _pages.length) {
          return Center(child: _buildNextChapterCard());
        }
        return GestureDetector(
          onTap: _toggleUI,
          child: InteractiveViewer(
            minScale: 0.9,
            maxScale: 5.0,
            child: Center(
              child: _PageImage(url: _pages[i], index: i, fit: BoxFit.contain),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNextChapterCard() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF7C6FF7).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: Color(0xFF7C6FF7), size: 28),
          ),
          const SizedBox(height: 14),
          const Text('Глава завершена',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          if (_preloadedNextPages.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Следующая глава загружена',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.35), fontSize: 12)),
          ],
          if (hasNext) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C6FF7),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 18),
                label: const Text('Следующая глава',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                onPressed: _nextChapter,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.85), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _currentChapter.name,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Режим читалки
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _readerMode = _readerMode == ReaderMode.webtoon
                          ? ReaderMode.manga
                          : ReaderMode.webtoon;
                    });
                    _scheduleHideUI();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _readerMode == ReaderMode.webtoon
                              ? Icons.view_day_rounded
                              : Icons.auto_stories_rounded,
                          color: Colors.white70,
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _readerMode == ReaderMode.webtoon ? 'Вебтун' : 'Манга',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
                // Список глав
                IconButton(
                  icon: const Icon(Icons.format_list_bulleted_rounded,
                      color: Colors.white70, size: 20),
                  onPressed: _showChapterSelector,
                ),
                // ⚙️ Настройки читалки
                IconButton(
                  icon: const Icon(Icons.settings_rounded,
                      color: Colors.white70, size: 20),
                  onPressed: _showSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.9), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '$_currentPage',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14),
                          activeTrackColor: const Color(0xFF7C6FF7),
                          inactiveTrackColor:
                              Colors.white.withOpacity(0.15),
                          thumbColor: const Color(0xFF7C6FF7),
                          overlayColor:
                              const Color(0xFF7C6FF7).withOpacity(0.2),
                        ),
                        child: Slider(
                          value: _currentPage
                              .toDouble()
                              .clamp(1.0, _pages.length.toDouble()),
                          min: 1,
                          max: _pages.length.toDouble(),
                          divisions:
                              _pages.length > 1 ? _pages.length - 1 : 1,
                          onChanged: (v) {
                            final page = v.round();
                            setState(() => _currentPage = page);
                            if (_readerMode == ReaderMode.manga) {
                              _pageController.jumpToPage(page - 1);
                            }
                            StorageService.saveProgress(
                                _currentChapter.id, page);
                          },
                        ),
                      ),
                    ),
                    Text(
                      '${_pages.length}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavButton(
                      icon: Icons.chevron_left_rounded,
                      label: 'Пред.',
                      enabled: hasPrev,
                      onTap: _prevChapter,
                    ),
                    Text(
                      'Глава ${_currentChapter.chapterNumber}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 12),
                    ),
                    _NavButton(
                      icon: Icons.chevron_right_rounded,
                      label: 'След.',
                      enabled: hasNext,
                      onTap: _nextChapter,
                      iconRight: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChapterSelector() {
    _uiHideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Выбор главы',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.chapters.length,
              itemBuilder: (_, i) {
                final ch = widget.chapters[i];
                final isCurrent = ch.id == _currentChapter.id;
                return ListTile(
                  dense: true,
                  leading: Text(
                    '${ch.chapterNumber}',
                    style: TextStyle(
                      color: isCurrent
                          ? const Color(0xFF7C6FF7)
                          : Colors.white.withOpacity(0.25),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  title: Text(
                    ch.name,
                    style: TextStyle(
                      color: isCurrent
                          ? const Color(0xFF7C6FF7)
                          : ch.isLocked
                              ? Colors.white24
                              : Colors.white,
                      fontWeight:
                          isCurrent ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  trailing: isCurrent
                      ? const Icon(Icons.play_arrow_rounded,
                          color: Color(0xFF7C6FF7), size: 18)
                      : ch.isLocked
                          ? Icon(Icons.lock_rounded,
                              color: Colors.white.withOpacity(0.2), size: 16)
                          : null,
                  onTap: ch.isLocked
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          _goToChapter(ch);
                        },
                );
              },
            ),
          ),
        ],
      ),
    ).then((_) => _scheduleHideUI());
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool iconRight;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.iconRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.white70 : Colors.white24;
    final children = [
      if (!iconRight) Icon(icon, color: color, size: 20),
      if (!iconRight) const SizedBox(width: 2),
      Text(label, style: TextStyle(color: color, fontSize: 13)),
      if (iconRight) const SizedBox(width: 2),
      if (iconRight) Icon(icon, color: color, size: 20),
    ];
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _PageImage extends StatelessWidget {
  final String url;
  final int index;
  final BoxFit fit;

  const _PageImage(
      {required this.url, required this.index, this.fit = BoxFit.fitWidth});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      httpHeaders: const {
        'Referer': 'https://tomilo-lib.ru/',
        'Origin': 'https://tomilo-lib.ru',
      },
      placeholder: (_, __) => AspectRatio(
        aspectRatio: 2 / 3,
        child: Container(
          color: const Color(0xFF0C0C18),
          child: Center(
            child: CircularProgressIndicator(
              color: const Color(0xFF7C6FF7).withOpacity(0.5),
              strokeWidth: 2,
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => AspectRatio(
        aspectRatio: 2 / 3,
        child: Container(
          color: const Color(0xFF0C0C18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_outlined,
                  color: Colors.white.withOpacity(0.1), size: 40),
              const SizedBox(height: 8),
              Text('Стр. ${index + 1}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.15), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebtoonPageImage extends StatelessWidget {
  final String url;
  final int index;

  const _WebtoonPageImage({required this.url, required this.index});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.fitWidth,
      width: double.infinity,
      httpHeaders: const {
        'Referer': 'https://tomilo-lib.ru/',
        'Origin': 'https://tomilo-lib.ru',
      },
      placeholder: (_, __) => AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          color: const Color(0xFF0C0C18),
          child: Center(
            child: CircularProgressIndicator(
              color: const Color(0xFF7C6FF7).withOpacity(0.5),
              strokeWidth: 2,
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          color: const Color(0xFF0C0C18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_outlined,
                  color: Colors.white.withOpacity(0.1), size: 36),
              const SizedBox(height: 8),
              Text('Стр. ${index + 1}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.15), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
