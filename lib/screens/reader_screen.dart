import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/title_model.dart';
import '../models/chapter_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

enum ReaderMode { webtoon, manga }

// ── Настройки читалки (persist через SharedPreferences) ──────────────────────
class _ReaderSettings {
  double brightness;
  double contrast;
  double containerWidth;
  ReaderMode mode;
  bool tapZones;
  bool doubleTapZoom;
  bool keepScreenOn;
  bool seamless; // бесшовный переход между главами

  _ReaderSettings({
    this.brightness     = 1.0,
    this.contrast       = 1.0,
    this.containerWidth = 768,
    this.mode           = ReaderMode.webtoon,
    this.tapZones       = false,
    this.doubleTapZoom  = true,
    this.keepScreenOn   = true,
    this.seamless       = true,
  });

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    brightness      = p.getDouble('r_brightness')      ?? 1.0;
    contrast        = p.getDouble('r_contrast')         ?? 1.0;
    containerWidth  = p.getDouble('r_containerWidth')   ?? 768;
    final modeStr   = p.getString('r_mode')             ?? 'webtoon';
    mode            = modeStr == 'manga' ? ReaderMode.manga : ReaderMode.webtoon;
    tapZones        = p.getBool  ('r_tapZones')         ?? false;
    doubleTapZoom   = p.getBool  ('r_doubleTapZoom')    ?? true;
    keepScreenOn    = p.getBool  ('r_keepScreenOn')     ?? true;
    seamless        = p.getBool  ('r_seamless')         ?? true;
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('r_brightness',     brightness);
    await p.setDouble('r_contrast',       contrast);
    await p.setDouble('r_containerWidth', containerWidth);
    await p.setString('r_mode',           mode == ReaderMode.manga ? 'manga' : 'webtoon');
    await p.setBool  ('r_tapZones',       tapZones);
    await p.setBool  ('r_doubleTapZoom',  doubleTapZoom);
    await p.setBool  ('r_keepScreenOn',   keepScreenOn);
    await p.setBool  ('r_seamless',       seamless);
  }

  void reset() {
    brightness     = 1.0;
    contrast       = 1.0;
    containerWidth = 768;
    mode           = ReaderMode.webtoon;
    tapZones       = false;
    doubleTapZoom  = true;
    keepScreenOn   = true;
    seamless       = true;
  }

}

// ── ReaderScreen ──────────────────────────────────────────────────────────────
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
  // ── State ──────────────────────────────────────────────
  late Chapter _currentChapter;
  final _settings = _ReaderSettings();
  bool _settingsLoaded = false;

  // Страницы: список объектов _PageEntry чтобы отличать страницы разных глав
  // и вставлять разделители
  List<_PageEntry> _entries = [];
  bool _loading  = true;
  bool _uiVisible = true;
  int  _currentPage = 1; // 1-based, только для главы без seamless
  Timer? _uiHideTimer;

  // Для manga-mode
  final PageController _pageController = PageController();
  // Для webtoon-mode
  final ScrollController _scrollController = ScrollController();

  // Предзагрузка следующей главы
  List<String>? _nextChapterPagesCache;
  Chapter? _nextChapterCache;
  bool _loadingNextPreview = false; // отображаем "загрузка следующей" в разделителе

  String? _currentTitleId;

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapter;
    _settings.load().then((_) {
      if (mounted) setState(() => _settingsLoaded = true);
      _applyScreenOn();
    });
    _loadPages();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scheduleHideUI();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    _uiHideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  void _applyScreenOn() {
    if (_settings.keepScreenOn) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  // ── Загрузка страниц ───────────────────────────────────
  Future<void> _loadPages() async {
    if (mounted) setState(() { _loading = true; _entries = []; });

    final tid = _currentChapter.titleId.isNotEmpty
        ? _currentChapter.titleId
        : widget.title.id;

    try {
      List<String> pages;
      // Сначала берём из предзагрузки если она уже готова
      if (_nextChapterCache?.id == _currentChapter.id &&
          _nextChapterPagesCache != null) {
        pages = _nextChapterPagesCache!;
        _nextChapterCache = null;
        _nextChapterPagesCache = null;
      } else {
        pages = await ApiService.getPages(
          _currentChapter.id,
          cachedPages: _currentChapter.pages.isNotEmpty
              ? _currentChapter.pages
              : null,
          titleId: tid,
        );
      }

      if (pages.isEmpty) throw Exception('Нет страниц');

      final savedPage = await StorageService.getProgress(_currentChapter.id);

      if (mounted) {
        setState(() {
          _currentTitleId = tid;
          _entries = pages.asMap().entries.map((e) => _PageEntry(
            url: e.value,
            index: e.key,
            chapterId: _currentChapter.id,
            titleId: tid,
            chapterNumber: _currentChapter.chapterNumber,
          )).toList();
          _currentPage = savedPage.clamp(1, pages.length);
          _loading = false;
        });
        if (_settings.mode == ReaderMode.manga && _pageController.hasClients) {
          _pageController.jumpToPage(_currentPage - 1);
        }

        // Предзагружаем первые 5 страниц с высоким приоритетом
        for (int i = 0; i < pages.length && i < 5; i++) {
          precacheImage(
            CachedNetworkImageProvider(
              pages[i],
              headers: const {'Referer': 'https://tomilo-lib.ru/', 'Origin': 'https://tomilo-lib.ru'},
            ),
            context,
          );
        }
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

      _preloadNext();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка: $e',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF1E1E32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  // ── Предзагрузка следующей главы ──────────────────────
  Future<void> _preloadNext() async {
    if (!hasNext || _loadingNextPreview) return;
    final idx = _chapterIdx;
    if (idx < 0 || idx >= widget.chapters.length - 1) return;
    final next = widget.chapters[idx + 1];
    if (_nextChapterCache?.id == next.id) return; // уже загружено

    setState(() => _loadingNextPreview = true);
    try {
      final tid = next.titleId.isNotEmpty ? next.titleId : widget.title.id;
      final pages = await ApiService.getPages(
        next.id,
        cachedPages: next.pages.isNotEmpty ? next.pages : null,
        titleId: tid,
      );
      if (mounted) {
        setState(() {
          _nextChapterCache = next;
          _nextChapterPagesCache = pages;
          _loadingNextPreview = false;
        });
        // В seamless-режиме добавляем страницы следующей главы прямо в список
        if (_settings.seamless && _settings.mode == ReaderMode.webtoon) {
          _appendNextChapterEntries(next, pages, tid);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingNextPreview = false);
    }
  }

  void _appendNextChapterEntries(Chapter next, List<String> pages, String tid) {
    if (!mounted) return;
    // Добавляем разделитель + страницы следующей главы
    final newEntries = [
      _PageEntry.divider(
        prevChapterNumber: _currentChapter.chapterNumber,
        nextChapterNumber: next.chapterNumber,
        nextChapterId: next.id,
      ),
      ...pages.asMap().entries.map((e) => _PageEntry(
        url: e.value,
        index: e.key,
        chapterId: next.id,
        titleId: tid,
        chapterNumber: next.chapterNumber,
      )),
    ];
    setState(() => _entries = [..._entries, ...newEntries]);
  }

  // ── Скролл: определяем текущую страницу и переход главы ─
  void _onScroll() {
    if (_entries.isEmpty) return;
    // Обновляем номер страницы по позиции скролла (примерно)
    // Переход на следующую главу при достижении её страниц
  }

  // ── UI helpers ─────────────────────────────────────────
  void _scheduleHideUI() {
    _uiHideTimer?.cancel();
    _uiHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _uiVisible && !_loading) {
        setState(() => _uiVisible = false);
      }
    });
  }

  void _toggleUI() {
    setState(() => _uiVisible = !_uiVisible);
    if (_uiVisible) _scheduleHideUI();
  }

  int get _chapterIdx =>
      widget.chapters.indexWhere((c) => c.id == _currentChapter.id);

  bool get hasPrev => _chapterIdx > 0;
  bool get hasNext => _chapterIdx < widget.chapters.length - 1;

  List<String> get _currentPages => _entries
      .where((e) => !e.isDivider && e.chapterId == _currentChapter.id)
      .map((e) => e.url!)
      .toList();

  void _goToChapter(Chapter chapter) {
    _uiHideTimer?.cancel();
    _nextChapterCache = null;
    _nextChapterPagesCache = null;
    setState(() {
      _currentChapter = chapter;
      _currentPage = 1;
      _entries = [];
    });
    _loadPages();
  }

  void _prevChapter() {
    final idx = _chapterIdx;
    if (idx > 0) _goToChapter(widget.chapters[idx - 1]);
  }

  void _nextChapter() {
    final idx = _chapterIdx;
    if (idx < widget.chapters.length - 1) {
      _goToChapter(widget.chapters[idx + 1]);
    }
  }

  // ── Tap zone navigation ────────────────────────────────
  void _handleTap(TapUpDetails details) {
    final w = MediaQuery.of(context).size.width;
    final x = details.globalPosition.dx;
    if (_settings.tapZones && _settings.mode == ReaderMode.manga) {
      if (x < w * 0.25) {
        if (_currentPage > 1) {
          _pageController.previousPage(
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        } else {
          _prevChapter();
        }
      } else if (x > w * 0.75) {
        if (_currentPage < _currentPages.length) {
          _pageController.nextPage(
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        } else {
          _nextChapter();
        }
      } else {
        _toggleUI();
      }
    } else {
      _toggleUI();
    }
  }

  // ── Build ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_settingsLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0C18),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF7C6FF7))),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C18),
      body: Stack(
        children: [
          // ── Контент читалки ──
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Color(0xFF7C6FF7), strokeWidth: 2))
          else if (_settings.mode == ReaderMode.webtoon)
            _buildWebtoon()
          else
            _buildManga(),

          // ── Top bar ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _uiVisible ? 0 : -80,
            left: 0, right: 0,
            child: _buildTopBar(),
          ),

          // ── Bottom bar ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            bottom: _uiVisible ? 0 : -120,
            left: 0, right: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  // ── Webtoon (вертикальный скролл) ─────────────────────
  Widget _buildWebtoon() {
    final pages = _currentPages;
    return GestureDetector(
      onTapUp: _handleTap,
      child: ColorFiltered(
        colorFilter: _colorFilter,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _entries.length,
          itemBuilder: (_, i) {
            final e = _entries[i];
            if (e.isDivider) return _buildDivider(e);
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: _settings.containerWidth,
                ),
                child: _WebtoonPageImage(
                  url: e.url!,
                  index: e.index,
                  titleId: e.titleId,
                  chapterId: e.chapterId,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Manga (горизонтальный свайп) ──────────────────────
  Widget _buildManga() {
    final pages = _currentPages;
    return GestureDetector(
      onTapUp: _handleTap,
      child: ColorFiltered(
        colorFilter: _colorFilter,
        child: PageView.builder(
          controller: _pageController,
          itemCount: pages.length,
          onPageChanged: (i) {
            setState(() => _currentPage = i + 1);
            StorageService.saveProgress(_currentChapter.id, i + 1);
            if (i == pages.length - 1) _preloadNext();
          },
          itemBuilder: (_, i) => InteractiveViewer(
            minScale: 0.9,
            maxScale: 5.0,
            onInteractionEnd: _settings.doubleTapZoom
                ? null
                : (_) {},
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _settings.containerWidth),
                child: _PageImage(
                  url: pages[i],
                  index: i,
                  fit: BoxFit.contain,
                  titleId: _currentTitleId,
                  chapterId: _currentChapter.id,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Разделитель между главами ─────────────────────────
  Widget _buildDivider(_PageEntry e) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      color: const Color(0xFF08080F),
      child: Column(
        children: [
          // Линия
          Row(children: [
            Expanded(child: Divider(color: Colors.white.withOpacity(0.08), thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.auto_stories_rounded,
                  color: Colors.white.withOpacity(0.15), size: 20),
            ),
            Expanded(child: Divider(color: Colors.white.withOpacity(0.08), thickness: 1)),
          ]),
          const SizedBox(height: 16),
          Text(
            'Глава ${e.prevChapterNumber} завершена',
            style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'Глава ${e.nextChapterNumber}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          if (_loadingNextPreview && _nextChapterPagesCache == null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  color: const Color(0xFF7C6FF7).withOpacity(0.5), strokeWidth: 2),
            ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Divider(color: Colors.white.withOpacity(0.08), thickness: 1)),
          ]),
        ],
      ),
    );
  }

  // ── ColorFilter из brightness+contrast ───────────────
  ColorFilter get _colorFilter {
    // Матрица яркости*контраста
    final b = _settings.brightness;
    final c = _settings.contrast;
    final t = (1.0 - c) / 2.0 * 255;
    return ColorFilter.matrix([
      c*b, 0,   0,   0, t,
      0,   c*b, 0,   0, t,
      0,   0,   c*b, 0, t,
      0,   0,   0,   1, 0,
    ]);
  }

  // ── Top Bar ───────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.85), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: Row(children: [
            _iconBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.title.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(_currentChapter.name,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ],
              ),
            ),
            _iconBtn(Icons.format_list_numbered_rounded, _showChapterSelector),
            _iconBtn(Icons.settings_rounded, _showSettings),
          ]),
        ),
      ),
    );
  }

  // ── Bottom Bar ────────────────────────────────────────
  Widget _buildBottomBar() {
    final pages = _currentPages;
    if (pages.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.85), Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Слайдер страниц
            if (_settings.mode == ReaderMode.manga) ...[
              Row(children: [
                Text('$_currentPage',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: const Color(0xFF7C6FF7),
                      inactiveTrackColor: Colors.white.withOpacity(0.15),
                      thumbColor: const Color(0xFF7C6FF7),
                      overlayColor: const Color(0xFF7C6FF7).withOpacity(0.2),
                    ),
                    child: Slider(
                      value: _currentPage.toDouble().clamp(1.0, pages.length.toDouble()),
                      min: 1,
                      max: pages.length.toDouble(),
                      divisions: pages.length > 1 ? pages.length - 1 : 1,
                      onChanged: (v) {
                        final page = v.round();
                        setState(() => _currentPage = page);
                        _pageController.jumpToPage(page - 1);
                        StorageService.saveProgress(_currentChapter.id, page);
                      },
                    ),
                  ),
                ),
                Text('${pages.length}',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
              ]),
            ] else ...[
              // В webtoon-режиме показываем номер главы и кол-во страниц
              Text(
                '${pages.length} стр.',
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
              ),
              const SizedBox(height: 6),
            ],
            // Кнопки глав
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
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
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
          ]),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white70, size: 18),
    ),
  );

  // ── Chapter selector ──────────────────────────────────
  void _showChapterSelector() {
    _uiHideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Выбор главы',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.chapters.length,
            itemBuilder: (_, i) {
              final ch = widget.chapters[i];
              final isCurrent = ch.id == _currentChapter.id;
              return ListTile(
                dense: true,
                leading: Text('${ch.chapterNumber}',
                    style: TextStyle(
                        color: isCurrent ? const Color(0xFF7C6FF7) : Colors.white.withOpacity(0.25),
                        fontWeight: FontWeight.w700, fontSize: 13)),
                title: Text(ch.name,
                    style: TextStyle(
                        color: isCurrent ? const Color(0xFF7C6FF7) : ch.isLocked ? Colors.white24 : Colors.white,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14)),
                trailing: isCurrent
                    ? const Icon(Icons.play_arrow_rounded, color: Color(0xFF7C6FF7), size: 18)
                    : ch.isLocked
                    ? Icon(Icons.lock_rounded, color: Colors.white.withOpacity(0.2), size: 16)
                    : null,
                onTap: ch.isLocked ? null : () { Navigator.pop(ctx); _goToChapter(ch); },
              );
            },
          ),
        ),
      ]),
    ).then((_) => _scheduleHideUI());
  }

  // ── Settings sheet ────────────────────────────────────
  void _showSettings() {
    _uiHideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F1E),
      isScrollControlled: true,
      // Ровно половина экрана — видно контент за шторкой
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
        minWidth: double.infinity,
      ),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          // update: сначала меняем данные, потом перерисовываем ОБА виджета
          void update(VoidCallback fn) {
            fn(); // меняем поля _settings
            setState(() {}); // перерисовываем reader (применяет яркость/контраст/ширину)
            setSheet(() {}); // перерисовываем шторку (обновляет значения слайдеров)
            _settings.save();
            _applyScreenOn();
          }

          return SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 20, right: 20, top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),

                // Заголовок + сброс
                Row(children: [
                  const Icon(Icons.menu_book_rounded, color: Color(0xFF7C6FF7), size: 20),
                  const SizedBox(width: 8),
                  const Text('Читалка',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      update(() => _settings.reset());
                      // Перезагрузить страницы если режим изменился
                    },
                    child: Row(children: [
                      Icon(Icons.refresh_rounded, color: Colors.white.withOpacity(0.4), size: 14),
                      const SizedBox(width: 4),
                      Text('Сбросить', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 20),

                // ── Режим ──────────────────────────────────────────
                _sheetLabel('РЕЖИМ'),
                const SizedBox(height: 8),
                _segRow(
                  label: 'Направление чтения',
                  sub: 'Лента — скролл вниз, Манга — свайп',
                  options: const [('webtoon', 'Лента ↓'), ('manga', 'Манга ←')],
                  value: _settings.mode == ReaderMode.webtoon ? 'webtoon' : 'manga',
                  onChanged: (v) => update(() =>
                  _settings.mode = v == 'manga' ? ReaderMode.manga : ReaderMode.webtoon),
                ),

                Divider(color: Colors.white.withOpacity(0.07), height: 28),

                // ── Изображение ────────────────────────────────────
                _sheetLabel('ИЗОБРАЖЕНИЕ'),
                const SizedBox(height: 12),
                _sliderRow(
                  label: 'Ширина контейнера',
                  value: _settings.containerWidth,
                  min: 300,
                  max: 1200,
                  display: '${_settings.containerWidth.round()} px',
                  onChanged: (v) => update(() => _settings.containerWidth = v),
                ),
                const SizedBox(height: 14),
                _sliderRow(
                  label: 'Яркость',
                  value: _settings.brightness,
                  min: 0.2, max: 2.0,
                  display: '${(_settings.brightness * 100).round()}%',
                  onChanged: (v) => update(() => _settings.brightness = v),
                ),
                const SizedBox(height: 14),
                _sliderRow(
                  label: 'Контраст',
                  value: _settings.contrast,
                  min: 0.2, max: 2.0,
                  display: '${(_settings.contrast * 100).round()}%',
                  onChanged: (v) => update(() => _settings.contrast = v),
                ),

                Divider(color: Colors.white.withOpacity(0.07), height: 28),

                // ── Переходы ───────────────────────────────────────
                _sheetLabel('ПЕРЕХОДЫ'),
                const SizedBox(height: 10),
                _switchRowSheet(
                  icon: Icons.auto_stories_rounded,
                  label: 'Бесшовный переход',
                  sub: 'Следующая глава подгружается прямо в ленту',
                  value: _settings.seamless,
                  onChanged: (v) => update(() => _settings.seamless = v),
                ),

                Divider(color: Colors.white.withOpacity(0.07), height: 28),

                // ── Управление ─────────────────────────────────────
                _sheetLabel('УПРАВЛЕНИЕ'),
                const SizedBox(height: 10),
                _switchRowSheet(
                  icon: Icons.touch_app_rounded,
                  label: 'Тап-зоны',
                  sub: 'Тап по краям → перелистывание (только манга)',
                  value: _settings.tapZones,
                  onChanged: (v) => update(() => _settings.tapZones = v),
                ),
                const SizedBox(height: 10),
                _switchRowSheet(
                  icon: Icons.zoom_in_rounded,
                  label: 'Двойной тап — зум',
                  sub: 'Быстрое увеличение изображения',
                  value: _settings.doubleTapZoom,
                  onChanged: (v) => update(() => _settings.doubleTapZoom = v),
                ),
                const SizedBox(height: 10),
                _switchRowSheet(
                  icon: Icons.screen_lock_landscape_rounded,
                  label: 'Не гасить экран',
                  sub: 'Экран остаётся включённым',
                  value: _settings.keepScreenOn,
                  onChanged: (v) => update(() => _settings.keepScreenOn = v),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) => _scheduleHideUI());
  }

  // ── Sheet helpers ─────────────────────────────────────
  Widget _sheetLabel(String t) => Text(t,
      style: TextStyle(
          color: Colors.white.withOpacity(0.35), fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 1.1));

  Widget _segRow({
    required String label,
    String? sub,
    required List<(String, String)> options,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      if (sub != null) ...[
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
      ],
      const SizedBox(height: 10),
      Row(children: [
        for (int i = 0; i < options.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(options[i].$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 34,
                decoration: BoxDecoration(
                  color: value == options[i].$1 ? const Color(0xFF7C6FF7) : const Color(0xFF1E1E32),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(options[i].$2,
                      style: TextStyle(
                          color: value == options[i].$1 ? Colors.white : Colors.white54,
                          fontSize: 12,
                          fontWeight: value == options[i].$1 ? FontWeight.w600 : FontWeight.normal)),
                ),
              ),
            ),
          ),
          if (i < options.length - 1) const SizedBox(width: 6),
        ],
      ]),
    ]);
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        Text(display, style: const TextStyle(color: Color(0xFF7C6FF7), fontSize: 13)),
      ]),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          activeTrackColor: const Color(0xFF7C6FF7),
          inactiveTrackColor: Colors.white.withOpacity(0.1),
          thumbColor: const Color(0xFF7C6FF7),
          overlayColor: const Color(0xFF7C6FF7).withOpacity(0.15),
        ),
        child: Slider(value: value, min: min, max: max, onChanged: onChanged),
      ),
    ]);
  }

  Widget _switchRowSheet({
    required IconData icon,
    required String label,
    required String sub,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: const Color(0xFF7C6FF7).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: const Color(0xFF7C6FF7), size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
      ])),
      Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF7C6FF7),
        activeTrackColor: const Color(0xFF7C6FF7).withOpacity(0.3),
        inactiveThumbColor: Colors.white38,
        inactiveTrackColor: Colors.white.withOpacity(0.1),
      ),
    ]);
  }
}

// ── _PageEntry: страница или разделитель ─────────────────────────────────────
class _PageEntry {
  final bool isDivider;
  final String? url;
  final int index;
  final String chapterId;
  final String? titleId;
  final int chapterNumber;

  // Для разделителя
  final int? prevChapterNumber;
  final int? nextChapterNumber;
  final String? nextChapterId;

  const _PageEntry({
    required this.url,
    required this.index,
    required this.chapterId,
    required this.titleId,
    required this.chapterNumber,
    this.isDivider = false,
    this.prevChapterNumber,
    this.nextChapterNumber,
    this.nextChapterId,
  });

  factory _PageEntry.divider({
    required int prevChapterNumber,
    required int nextChapterNumber,
    required String nextChapterId,
  }) => _PageEntry(
    url: null, index: 0,
    chapterId: nextChapterId, titleId: null,
    chapterNumber: nextChapterNumber,
    isDivider: true,
    prevChapterNumber: prevChapterNumber,
    nextChapterNumber: nextChapterNumber,
    nextChapterId: nextChapterId,
  );
}

// ── NavButton ────────────────────────────────────────────────────────────────
class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool iconRight;

  const _NavButton({
    required this.icon, required this.label,
    required this.enabled, required this.onTap,
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

// ── _PageImage (manga mode) ──────────────────────────────────────────────────
class _PageImage extends StatefulWidget {
  final String url;
  final int index;
  final BoxFit fit;
  final String? titleId;
  final String chapterId;

  const _PageImage({
    required this.url, required this.index,
    this.fit = BoxFit.fitWidth,
    required this.titleId, required this.chapterId,
  });

  @override
  State<_PageImage> createState() => _PageImageState();
}

class _PageImageState extends State<_PageImage> {
  bool _useFallback = false;
  String get _activeUrl => _useFallback
      ? (ApiService.buildFallbackUrl(widget.url, widget.titleId, widget.chapterId) ?? widget.url)
      : widget.url;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: _activeUrl,
      fit: widget.fit,
      width: double.infinity,
      httpHeaders: const {'Referer': 'https://tomilo-lib.ru/', 'Origin': 'https://tomilo-lib.ru'},
      placeholder: (_, __) => AspectRatio(aspectRatio: 2/3,
          child: Container(color: const Color(0xFF0C0C18),
              child: Center(child: CircularProgressIndicator(
                  color: const Color(0xFF7C6FF7).withOpacity(0.5), strokeWidth: 2)))),
      errorWidget: (_, __, err) {
        if (!_useFallback &&
            ApiService.buildFallbackUrl(widget.url, widget.titleId, widget.chapterId) != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _useFallback = true);
          });
          return AspectRatio(aspectRatio: 2/3,
              child: Container(color: const Color(0xFF0C0C18),
                  child: Center(child: CircularProgressIndicator(
                      color: const Color(0xFF7C6FF7).withOpacity(0.3), strokeWidth: 2))));
        }
        return AspectRatio(aspectRatio: 2/3,
            child: Container(color: const Color(0xFF0C0C18),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.broken_image_outlined, color: Colors.white.withOpacity(0.1), size: 40),
                  const SizedBox(height: 8),
                  Text('Стр. ${widget.index + 1}',
                      style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 12)),
                ])));
      },
    );
  }
}

// ── _WebtoonPageImage ────────────────────────────────────────────────────────
class _WebtoonPageImage extends StatefulWidget {
  final String url;
  final int index;
  final String? titleId;
  final String chapterId;

  const _WebtoonPageImage({
    required this.url, required this.index,
    required this.titleId, required this.chapterId,
  });

  @override
  State<_WebtoonPageImage> createState() => _WebtoonPageImageState();
}

class _WebtoonPageImageState extends State<_WebtoonPageImage> {
  bool _useFallback = false;
  String get _activeUrl => _useFallback
      ? (ApiService.buildFallbackUrl(widget.url, widget.titleId, widget.chapterId) ?? widget.url)
      : widget.url;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: _activeUrl,
      fit: BoxFit.fitWidth,
      width: double.infinity,
      // Первые 3 страницы грузятся с высоким приоритетом
      httpHeaders: const {'Referer': 'https://tomilo-lib.ru/', 'Origin': 'https://tomilo-lib.ru'},
      placeholder: (_, __) => AspectRatio(aspectRatio: 3/4,
          child: Container(color: const Color(0xFF0C0C18),
              child: Center(child: CircularProgressIndicator(
                  color: const Color(0xFF7C6FF7).withOpacity(0.5), strokeWidth: 2)))),
      errorWidget: (_, url, error) {
        if (!_useFallback &&
            ApiService.buildFallbackUrl(widget.url, widget.titleId, widget.chapterId) != null) {
          print('PAGE_FALLBACK: стр.${widget.index + 1}');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _useFallback = true);
          });
          return AspectRatio(aspectRatio: 3/4,
              child: Container(color: const Color(0xFF0C0C18),
                  child: Center(child: CircularProgressIndicator(
                      color: const Color(0xFF7C6FF7).withOpacity(0.3), strokeWidth: 2))));
        }
        return AspectRatio(aspectRatio: 3/4,
            child: Container(color: const Color(0xFF0C0C18),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.broken_image_outlined, color: Colors.white.withOpacity(0.1), size: 36),
                  const SizedBox(height: 8),
                  Text('Стр. ${widget.index + 1}',
                      style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 12)),
                ])));
      },
    );
  }
}