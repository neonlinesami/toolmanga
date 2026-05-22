import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/title_model.dart';
import '../services/api_service.dart';
import 'title_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  List<MangaTitle> _results = [];
  bool _loading = false;
  bool _searched = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty || q == _lastQuery) return;
    _lastQuery = q;
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final result = await ApiService.getTitles(
        page: 1,
        limit: 40,
        search: q,
        sortBy: 'weekViews',
      );
      if (mounted && _lastQuery == q) {
        setState(() {
          _results = result['titles'] as List<MangaTitle>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header / search bar ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Название, автор...',
                        hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3), fontSize: 15),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFF7C6FF7), size: 20),
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.white38, size: 18),
                                onPressed: () {
                                  _controller.clear();
                                  setState(() {
                                    _results = [];
                                    _searched = false;
                                    _lastQuery = '';
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFF161625),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: const Color(0xFF7C6FF7).withOpacity(0.5),
                              width: 1),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (v) {
                        setState(() {});
                        if (v.isEmpty) {
                          setState(() {
                            _results = [];
                            _searched = false;
                            _lastQuery = '';
                          });
                        }
                      },
                      onSubmitted: _search,
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Отмена',
                      style: TextStyle(
                          color: Color(0xFF7C6FF7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            // ── Results ─────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF7C6FF7), strokeWidth: 2),
                    )
                  : !_searched
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_rounded,
                                  color: Colors.white.withOpacity(0.08),
                                  size: 72),
                              const SizedBox(height: 14),
                              Text(
                                'Введите название для поиска',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                    fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : _results.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off_rounded,
                                      color: Colors.white.withOpacity(0.08),
                                      size: 64),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Ничего не найдено',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.35),
                                        fontSize: 15),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 4, 12, 16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.55,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: _results.length,
                              itemBuilder: (ctx, i) {
                                final t = _results[i];
                                return GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => TitleScreen(title: t)),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF161625),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    clipBehavior: Clip.hardEdge,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 8,
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              CachedNetworkImage(
                                                imageUrl: t.coverUrl,
                                                fit: BoxFit.cover,
                                                httpHeaders: const {
                                                  'Referer':
                                                      'https://tomilo-lib.ru/',
                                                  'Origin':
                                                      'https://tomilo-lib.ru',
                                                },
                                                placeholder: (_, __) =>
                                                    Container(
                                                        color: const Color(
                                                            0xFF1E1E32)),
                                                errorWidget: (_, __, ___) =>
                                                    Container(
                                                  color:
                                                      const Color(0xFF1E1E32),
                                                  child: const Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                      color: Colors.white12,
                                                      size: 28),
                                                ),
                                              ),
                                              if (t.averageRating != null)
                                                Positioned(
                                                  top: 6,
                                                  right: 6,
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 5,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.75),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                            Icons.star_rounded,
                                                            color: Color(
                                                                0xFFFFD700),
                                                            size: 10),
                                                        const SizedBox(
                                                            width: 2),
                                                        Text(
                                                          t.averageRating!
                                                              .toStringAsFixed(
                                                                  1),
                                                          style: const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              Positioned(
                                                bottom: 5,
                                                left: 5,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 5,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                            0xFF7C6FF7)
                                                        .withOpacity(0.85),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            5),
                                                  ),
                                                  child: Text(
                                                    t.typeLabel,
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w700,
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
                                            padding: const EdgeInsets.fromLTRB(
                                                6, 5, 6, 5),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    t.name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      height: 1.3,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (t.totalChapters != null)
                                                  Text(
                                                    '${t.totalChapters} гл.',
                                                    style: TextStyle(
                                                        color: Colors.white
                                                            .withOpacity(0.3),
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
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
