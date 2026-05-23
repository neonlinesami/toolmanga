import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/title_model.dart';
import '../services/api_service.dart';
import 'title_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Три секции главной страницы
  List<MangaTitle> _recommended = []; // weekViews desc — популярное за неделю
  List<MangaTitle> _underrated = [];  // averageRating desc + низкие просмотры
  List<MangaTitle> _newest = [];      // createdAt desc — новые тайтлы

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        // Рекомендовано: топ недели по просмотрам
        ApiService.getTitles(
          page: 1, limit: 10,
          sortBy: 'weekViews', sortOrder: 'desc',
        ),
        // Недооценённые: высокий рейтинг, отсортированные по рейтингу
        // (у сайта нет фильтра "мало просмотров", берём топ по рейтингу
        //  со смещением, чтобы не пересекаться с рекомендациями)
        ApiService.getTitles(
          page: 3, limit: 10,
          sortBy: 'averageRating', sortOrder: 'desc',
        ),
        // Новые: свежие тайтлы по дате добавления
        ApiService.getTitles(
          page: 1, limit: 10,
          sortBy: 'createdAt', sortOrder: 'desc',
        ),
      ]);

      if (mounted) {
        setState(() {
          _recommended = results[0]['titles'] as List<MangaTitle>;
          _underrated  = results[1]['titles'] as List<MangaTitle>;
          _newest      = results[2]['titles'] as List<MangaTitle>;
          _loading     = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildShimmer();
    if (_error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white12, size: 64),
          const SizedBox(height: 16),
          const Text('Не удалось загрузить',
              style: TextStyle(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _load,
            child: const Text('Повторить', style: TextStyle(color: Color(0xFF7C6FF7))),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF7C6FF7),
      backgroundColor: const Color(0xFF161625),
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _BannerSection(titles: _recommended),
          const SizedBox(height: 8),
          _Section(
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFFF6B35),
            title: 'Рекомендовано',
            subtitle: 'Популярные на этой неделе',
            titles: _recommended,
          ),
          _Section(
            icon: Icons.diamond_rounded,
            iconColor: const Color(0xFF7C6FF7),
            title: 'Недооценённые',
            subtitle: 'Высокий рейтинг — мало известны',
            titles: _underrated,
          ),
          _Section(
            icon: Icons.new_releases_rounded,
            iconColor: const Color(0xFF4CAF96),
            title: 'Новые',
            subtitle: 'Свежие тайтлы на платформе',
            titles: _newest,
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Banner shimmer
        Container(
          height: 200,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          decoration: BoxDecoration(
            color: const Color(0xFF161625),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        const SizedBox(height: 24),
        for (int s = 0; s < 3; s++) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              height: 20, width: 140,
              decoration: BoxDecoration(
                color: const Color(0xFF161625),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          SizedBox(
            height: 168,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              itemBuilder: (_, __) => Container(
                width: 106,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF161625),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ─── Banner (первый тайтл из recommended как Hero) ──────────────────────────

class _BannerSection extends StatefulWidget {
  final List<MangaTitle> titles;
  const _BannerSection({required this.titles});

  @override
  State<_BannerSection> createState() => _BannerSectionState();
}

class _BannerSectionState extends State<_BannerSection> {
  int _current = 0;
  late final PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
    // Авто-прокрутка
    Future.delayed(const Duration(seconds: 3), _autoScroll);
  }

  void _autoScroll() {
    if (!mounted || widget.titles.isEmpty) return;
    final next = (_current + 1) % widget.titles.length.clamp(1, 5);
    _ctrl.animateToPage(next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut);
    Future.delayed(const Duration(seconds: 4), _autoScroll);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.titles.take(5).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(children: [
      SizedBox(
        height: 210,
        child: PageView.builder(
          controller: _ctrl,
          onPageChanged: (i) => setState(() => _current = i),
          itemCount: items.length,
          itemBuilder: (_, i) => _BannerCard(title: items[i]),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(items.length, (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: _current == i ? 18 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: _current == i
                ? const Color(0xFF7C6FF7)
                : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(3),
          ),
        )),
      ),
    ]);
  }
}

class _BannerCard extends StatelessWidget {
  final MangaTitle title;
  const _BannerCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => TitleScreen(title: title))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFF161625),
        ),
        clipBehavior: Clip.antiAlias,
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
              errorWidget: (_, __, ___) =>
                  Container(color: const Color(0xFF1E1E32)),
            ),
            // Градиент снизу
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.85),
                    ],
                    stops: const [0.35, 0.6, 1.0],
                  ),
                ),
              ),
            ),
            // Текст
            Positioned(
              left: 14, right: 14, bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title.averageRating != null) ...[
                    Row(children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFFD700), size: 13),
                      const SizedBox(width: 3),
                      Text(title.averageRating!.toStringAsFixed(1),
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(title.typeLabel,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 10)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                  ],
                  Text(title.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section (горизонтальная карусель) ──────────────────────────────────────

class _Section extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<MangaTitle> titles;

  const _Section({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.titles,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              Text(subtitle,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 11)),
            ]),
          ]),
        ),
        SizedBox(
          height: 168,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: titles.length,
            itemBuilder: (ctx, i) => _MiniCard(
              title: titles[i],
              onTap: () => Navigator.push(ctx,
                  MaterialPageRoute(
                      builder: (_) => TitleScreen(title: titles[i]))),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  final MangaTitle title;
  final VoidCallback onTap;
  const _MiniCard({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 106,
        margin: const EdgeInsets.only(right: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: title.coverUrl,
                fit: BoxFit.cover,
                width: 106,
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
          const SizedBox(height: 5),
          Text(
            title.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.3),
          ),
          if (title.averageRating != null) ...[
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.star_rounded,
                  color: Color(0xFFFFD700), size: 10),
              const SizedBox(width: 2),
              Text(title.averageRating!.toStringAsFixed(1),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 10)),
            ]),
          ],
        ]),
      ),
    );
  }
}