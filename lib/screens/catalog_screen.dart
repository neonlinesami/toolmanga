import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/title_model.dart';
import '../services/api_service.dart';
import 'title_screen.dart';
import 'bookmarks_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'new_chapters_screen.dart';
import 'search_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final ScrollController _scrollController = ScrollController();

  List<MangaTitle> _titles = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  int _totalPages = 1;
  String _sortBy = 'weekViews';
  String? _selectedType;
  String? _selectedStatus;
  int _selectedNav = 0; // 0=catalog,1=bookmarks,2=profile,3=history

  @override
  void initState() {
    super.initState();
    _loadTitles();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      if (!_loading && _hasMore) _loadMore();
    }
  }

  Future<void> _loadTitles({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      setState(() {
        _titles = [];
        _page = 1;
        _hasMore = true;
      });
    }
    setState(() => _loading = true);
    try {
      final result = await ApiService.getTitles(
        page: _page,
        sortBy: _sortBy,
        type: _selectedType,
        status: _selectedStatus,
      );
      if (mounted) {
        setState(() {
          _titles.addAll(result['titles'] as List<MangaTitle>);
          _totalPages = result['pages'] as int;
          _hasMore = _page < _totalPages;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: $e'),
            backgroundColor: const Color(0xFF1E1E30),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    _page++;
    await _loadTitles();
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13131F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _FilterSheet(
        sortBy: _sortBy,
        selectedType: _selectedType,
        selectedStatus: _selectedStatus,
        onApply: (sort, type, status) {
          setState(() {
            _sortBy = sort;
            _selectedType = type;
            _selectedStatus = status;
          });
          _loadTitles(reset: true);
        },
      ),
    );
  }

  bool get _hasActiveFilters =>
      _selectedType != null ||
      _selectedStatus != null ||
      _sortBy != 'weekViews';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _selectedNav == 0
                  ? _buildCatalog()
                  : _selectedNav == 1
                      ? const BookmarksScreen()
                      : _selectedNav == 3
                          ? const ProfileScreen()
                          : const HistoryScreen(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    String title;
    switch (_selectedNav) {
      case 1:
        title = 'Закладки';
        break;
      case 3:
        title = 'Профиль';
        break;
      default:
        title = 'Tomilo Lib';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A14),
        border: Border(
          bottom:
              BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Лого
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C6FF7), Color(0xFFD63891)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('T',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          // Кнопка поиска (только для каталога)
          if (_selectedNav == 0) ...[
            IconButton(
              icon: const Icon(Icons.search_rounded, color: Colors.white70),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            // Фильтры с индикатором
            Stack(
              children: [
                IconButton(
                  icon:
                      const Icon(Icons.tune_rounded, color: Colors.white70),
                  onPressed: _showFilters,
                  style: IconButton.styleFrom(
                    backgroundColor: _hasActiveFilters
                        ? const Color(0xFF7C6FF7).withOpacity(0.15)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (_hasActiveFilters)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF7C6FF7),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCatalog() {
    return RefreshIndicator(
      color: const Color(0xFF7C6FF7),
      backgroundColor: const Color(0xFF161625),
      onRefresh: () => _loadTitles(reset: true),
      child: _titles.isEmpty && _loading
          ? _buildShimmer()
          : _titles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.grid_off_rounded,
                          color: Colors.white12, size: 64),
                      const SizedBox(height: 16),
                      const Text('Ничего не найдено',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 16)),
                    ],
                  ),
                )
              : GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.55,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _titles.length + (_hasMore ? 3 : 0),
                  itemBuilder: (ctx, i) {
                    if (i >= _titles.length) return _buildShimmerCard();
                    return _TitleCard(
                      title: _titles[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TitleScreen(title: _titles[i]),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (_, __) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF161625),
      highlightColor: const Color(0xFF21213A),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161625),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return _DutyIsBottomNav(
      selectedIndex: _selectedNav,
      onTap: (i) {
        if (i == 2) {
          // Центральная кнопка → поиск
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SearchScreen()),
          );
        } else if (i == 4) {
          _showMoreSheet();
        } else {
          setState(() => _selectedNav = i);
        }
      },
    );
  }

  void _showMoreSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MoreSheet(
        onSettings: () {
          Navigator.pop(ctx);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()));
        },
        onNewChapters: () {
          Navigator.pop(ctx);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NewChaptersScreen()));
        },
      ),
    );
  }
}

// ─── Dynamic Island–style bottom nav ──────────────────────────────────────────
class _DutyIsBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _DutyIsBottomNav({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      color: const Color(0xFF0A0A14),
      padding: EdgeInsets.only(bottom: bottom > 0 ? bottom : 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF141420),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withOpacity(0.09),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 0 — Каталог
              _IslandNavItem(
                icon: Icons.grid_view_rounded,
                label: 'Каталог',
                active: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
              // 1 — Закладки
              _IslandNavItem(
                icon: Icons.bookmark_rounded,
                label: 'Закладки',
                active: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
              // 2 — Центральная кнопка (поиск)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(2),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFCC1A1A), Color(0xFF991010)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFCC1A1A).withOpacity(
                                selectedIndex == 2 ? 0.55 : 0.25),
                            blurRadius: selectedIndex == 2 ? 16 : 8,
                            spreadRadius: selectedIndex == 2 ? 2 : 0,
                          ),
                        ],
                      ),
                      child: CustomPaint(painter: _MiniLogoPainter()),
                    ),
                  ),
                ),
              ),
              // 3 — Профиль
              _IslandNavItem(
                icon: Icons.person_rounded,
                label: 'Профиль',
                active: selectedIndex == 3,
                onTap: () => onTap(3),
              ),
              // 4 — Ещё
              _IslandNavItem(
                icon: Icons.more_horiz_rounded,
                label: 'Ещё',
                active: false,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IslandNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _IslandNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        active ? const Color(0xFF7C6FF7) : Colors.white.withOpacity(0.38);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF7C6FF7).withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.width / 46.0;

    final figurePaint = Paint()
      ..color = Colors.black.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final body = Path();
    body.addOval(Rect.fromCenter(
        center: Offset(cx, cy - 9 * scale),
        width: 6 * scale,
        height: 7 * scale));
    body.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, cy - 1 * scale),
          width: 8 * scale,
          height: 12 * scale),
      Radius.circular(2 * scale),
    ));
    body.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 5 * scale, cy + 5 * scale, 4 * scale, 10 * scale),
      Radius.circular(1.5 * scale),
    ));
    body.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(cx + 1 * scale, cy + 5 * scale, 4 * scale, 10 * scale),
      Radius.circular(1.5 * scale),
    ));
    canvas.drawPath(body, figurePaint);

    final sword = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx + 9 * scale, cy - 16 * scale),
      Offset(cx - 2 * scale, cy + 2 * scale),
      sword,
    );
    final guard = Paint()
      ..color = Colors.white.withOpacity(0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx + 4 * scale, cy - 8 * scale),
      Offset(cx + 9 * scale, cy - 5 * scale),
      guard,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── More sheet ───────────────────────────────────────────────────────────────
class _MoreSheet extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback onNewChapters;

  const _MoreSheet({required this.onSettings, required this.onNewChapters});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F).withOpacity(0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 3.5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),
          _MoreTile(
            icon: Icons.new_releases_rounded,
            label: 'Новые главы',
            badge: 'NEW',
            onTap: onNewChapters,
          ),
          Divider(
              color: Colors.white.withOpacity(0.06),
              height: 1,
              indent: 16,
              endIndent: 16),
          _MoreTile(
            icon: Icons.settings_rounded,
            label: 'Настройки',
            onTap: onSettings,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _MoreTile({
    required this.icon,
    required this.label,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF7C6FF7).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF7C6FF7), size: 20),
      ),
      title: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF7C6FF7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(badge!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
      trailing: Icon(Icons.chevron_right_rounded,
          color: Colors.white.withOpacity(0.2), size: 20),
    );
  }
}

// ─── Title card ───────────────────────────────────────────────────────────────
class _TitleCard extends StatelessWidget {
  final MangaTitle title;
  final VoidCallback onTap;

  const _TitleCard({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161625),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: title.coverUrl,
                    fit: BoxFit.cover,
                    httpHeaders: const {
                      'Referer': 'https://tomilo-lib.ru/',
                      'Origin': 'https://tomilo-lib.ru',
                    },
                    placeholder: (_, __) =>
                        Container(color: const Color(0xFF1E1E32)),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF1E1E32),
                      child: const Icon(Icons.broken_image_outlined,
                          color: Colors.white12, size: 28),
                    ),
                  ),
                  if (title.averageRating != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Color(0xFFFFD700), size: 10),
                            const SizedBox(width: 2),
                            Text(
                              title.averageRating!.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 40,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6)
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 5,
                    left: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C6FF7).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        title.typeLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (title.totalChapters != null)
                      Text(
                        '${title.totalChapters} гл.',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 10),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter sheet ─────────────────────────────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  final String sortBy;
  final String? selectedType;
  final String? selectedStatus;
  final Function(String sort, String? type, String? status) onApply;

  const _FilterSheet({
    required this.sortBy,
    required this.selectedType,
    required this.selectedStatus,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _sort;
  String? _type;
  String? _status;

  static const _sortOptions = [
    ('weekViews', 'Популярные за неделю'),
    ('views', 'Всего просмотров'),
    ('averageRating', 'По рейтингу'),
    ('createdAt', 'Новинки'),
    ('updatedAt', 'Обновления'),
  ];

  static const _typeOptions = [
    (null, 'Все типы'),
    ('manga', 'Манга'),
    ('manhwa', 'Манхва'),
    ('manhua', 'Маньхуа'),
    ('comic', 'Комикс'),
  ];

  static const _statusOptions = [
    (null, 'Любой'),
    ('ongoing', 'Выходит'),
    ('completed', 'Завершён'),
    ('hiatus', 'Заморожен'),
  ];

  @override
  void initState() {
    super.initState();
    _sort = widget.sortBy;
    _type = widget.selectedType;
    _status = widget.selectedStatus;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Фильтры',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(
                    () => {_sort = 'weekViews', _type = null, _status = null}),
                child: const Text('Сбросить',
                    style: TextStyle(
                        color: Color(0xFF7C6FF7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSection(
              'Сортировка',
              _sortOptions.map((o) => (o.$1, o.$2)).toList(),
              _sort,
              (v) => setState(() => _sort = v!)),
          const SizedBox(height: 16),
          _buildSection(
              'Тип',
              _typeOptions.map((o) => (o.$1, o.$2)).toList(),
              _type,
              (v) => setState(() => _type = v),
              nullable: true),
          const SizedBox(height: 16),
          _buildSection(
              'Статус',
              _statusOptions.map((o) => (o.$1, o.$2)).toList(),
              _status,
              (v) => setState(() => _status = v),
              nullable: true),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C6FF7),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.onApply(_sort, _type, _status);
              },
              child: const Text('Применить',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<(String?, String)> options,
      String? selected, ValueChanged<String?> onChanged,
      {bool nullable = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = opt.$1 == selected;
            return GestureDetector(
              onTap: () => onChanged(opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF7C6FF7)
                      : const Color(0xFF1E1E32),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  opt.$2,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white54,
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
