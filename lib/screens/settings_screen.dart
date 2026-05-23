import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _theme          = 'dark';
  bool   _autoMarkRead   = true;
  bool   _showAdult      = false;
  String _defaultSort    = 'weekViews';
  bool   _loaded         = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _theme        = p.getString('app_theme')       ?? 'dark';
      _autoMarkRead = p.getBool  ('app_autoMarkRead') ?? true;
      _showAdult    = p.getBool  ('app_showAdult')    ?? false;
      _defaultSort  = p.getString('app_defaultSort')  ?? 'weekViews';
      _loaded       = true;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('app_theme',       _theme);
    await p.setBool  ('app_autoMarkRead', _autoMarkRead);
    await p.setBool  ('app_showAdult',    _showAdult);
    await p.setString('app_defaultSort',  _defaultSort);
  }

  Future<void> _clearImageCache() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(_snack('Кэш изображений очищен'));
    }
  }

  Future<void> _clearHistory() async {
    final ok = await _confirm('Очистить историю?', 'Все записи об истории чтения будут удалены.');
    if (!ok || !mounted) return;
    final p = await SharedPreferences.getInstance();
    await p.remove('reading_history');
    await p.remove('reading_progress');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('История и прогресс очищены'));
  }

  Future<void> _clearBookmarks() async {
    final ok = await _confirm('Очистить закладки?', 'Все закладки будут удалены.');
    if (!ok || !mounted) return;
    final p = await SharedPreferences.getInstance();
    await p.remove('bookmarks');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('Закладки очищены'));
  }

  Future<void> _resetReaderSettings() async {
    final ok = await _confirm('Сбросить настройки читалки?', 'Яркость, контраст, ширина и другие параметры вернутся к значениям по умолчанию.');
    if (!ok || !mounted) return;
    final p = await SharedPreferences.getInstance();
    for (final key in ['r_brightness','r_contrast','r_containerWidth','r_mode',
      'r_tapZones','r_doubleTapZoom','r_keepScreenOn','r_seamless']) {
      await p.remove(key);
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(_snack('Настройки читалки сброшены'));
  }

  SnackBar _snack(String msg) => SnackBar(
    content: Text(msg, style: const TextStyle(color: Colors.white)),
    backgroundColor: const Color(0xFF1E1E32),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 2),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: SafeArea(
        child: Column(children: [
          _Header(onBack: () => Navigator.pop(context)),
          if (!_loaded)
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: Color(0xFF7C6FF7), strokeWidth: 2)),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [

                  // ── Внешний вид ──────────────────────────────────
                  _sectionLabel('ВНЕШНИЙ ВИД'),
                  _buildCard([
                    _segmentRow(
                      label: 'Тема приложения',
                      subtitle: 'Пока доступна только тёмная тема',
                      value: _theme,
                      options: const [
                        ('dark',   'Тёмная'),
                        ('light',  'Светлая'),
                        ('system', 'Системная'),
                      ],
                      onChanged: (v) {
                        setState(() => _theme = v);
                        _save();
                        // TODO: применить тему через ThemeProvider
                        ScaffoldMessenger.of(context).showSnackBar(
                            _snack('Смена темы будет доступна в следующей версии'));
                      },
                    ),
                  ]),

                  // ── Каталог ──────────────────────────────────────
                  _sectionLabel('КАТАЛОГ'),
                  _buildCard([
                    _segmentRow(
                      label: 'Сортировка по умолчанию',
                      value: _defaultSort,
                      options: const [
                        ('weekViews',     'Популярные'),
                        ('updatedAt',     'Обновления'),
                        ('averageRating', 'Рейтинг'),
                      ],
                      onChanged: (v) {
                        setState(() => _defaultSort = v);
                        _save();
                      },
                    ),
                    _divider(),
                    _switchRow(
                      icon: Icons.no_adult_content_rounded,
                      label: 'Показывать 18+ контент',
                      subtitle: 'Тайтлы с пометкой для взрослых',
                      value: _showAdult,
                      onChanged: (v) {
                        setState(() => _showAdult = v);
                        _save();
                      },
                    ),
                  ]),

                  // ── Чтение ───────────────────────────────────────
                  _sectionLabel('ЧТЕНИЕ'),
                  _buildCard([
                    _switchRow(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Автоотметка прочитанного',
                      subtitle: 'Помечать главу при открытии',
                      value: _autoMarkRead,
                      onChanged: (v) {
                        setState(() => _autoMarkRead = v);
                        _save();
                      },
                    ),
                    _divider(),
                    _actionRow(
                      icon: Icons.tune_rounded,
                      label: 'Сбросить настройки читалки',
                      subtitle: 'Яркость, режим, контраст и т.д.',
                      color: const Color(0xFF7C6FF7),
                      onTap: _resetReaderSettings,
                    ),
                  ]),

                  // ── Хранилище ────────────────────────────────────
                  _sectionLabel('ХРАНИЛИЩЕ'),
                  _buildCard([
                    _actionRow(
                      icon: Icons.cleaning_services_rounded,
                      label: 'Очистить кэш изображений',
                      subtitle: 'Освобождает место на устройстве',
                      color: const Color(0xFF7C6FF7),
                      onTap: _clearImageCache,
                    ),
                    _divider(),
                    _actionRow(
                      icon: Icons.history_rounded,
                      label: 'Очистить историю чтения',
                      subtitle: 'Удалить историю и прогресс по страницам',
                      color: const Color(0xFFE08C3A),
                      onTap: _clearHistory,
                    ),
                    _divider(),
                    _actionRow(
                      icon: Icons.bookmark_remove_rounded,
                      label: 'Очистить закладки',
                      subtitle: 'Удалить все добавленные в закладки',
                      color: const Color(0xFFE05C5C),
                      onTap: _clearBookmarks,
                    ),
                  ]),

                  // ── О приложении ─────────────────────────────────
                  _sectionLabel('О ПРИЛОЖЕНИИ'),
                  _buildCard([
                    _infoRow(icon: Icons.info_outline_rounded, label: 'Версия', value: '1.0.0'),
                    _divider(),
                    _infoRow(icon: Icons.language_rounded, label: 'Источник данных', value: 'tomilo-lib.ru'),
                  ]),
                ],
              ),
            ),
        ]),
      ),
    );
  }

  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E32),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(body, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена', style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Подтвердить', style: TextStyle(color: Color(0xFFE05C5C)))),
        ],
      ),
    ) ?? false;
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 0, 8),
    child: Text(text, style: TextStyle(
        color: Colors.white.withOpacity(0.35), fontSize: 11,
        fontWeight: FontWeight.w700, letterSpacing: 1.1)),
  );

  Widget _buildCard(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: BoxDecoration(
      color: const Color(0xFF13131F),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _divider() => Divider(color: Colors.white.withOpacity(0.06), height: 22, thickness: 1);

  Widget _segmentRow({
    required String label,
    String? subtitle,
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String> onChanged,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      if (subtitle != null) ...[
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
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

  Widget _switchRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(children: [
      Container(width: 36, height: 36,
          decoration: BoxDecoration(
              color: const Color(0xFF7C6FF7).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFF7C6FF7), size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
      ])),
      Switch(
        value: value, onChanged: onChanged,
        activeColor: const Color(0xFF7C6FF7),
        activeTrackColor: const Color(0xFF7C6FF7).withOpacity(0.3),
        inactiveThumbColor: Colors.white38,
        inactiveTrackColor: Colors.white.withOpacity(0.1),
      ),
    ]);
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500)),
          Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
        ])),
        Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.2), size: 18),
      ]),
    );
  }

  Widget _infoRow({required IconData icon, required String label, required String value}) {
    return Row(children: [
      Container(width: 36, height: 36,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white38, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14))),
      Text(value, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13)),
    ]);
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A14),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        const Text('Настройки', style: TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}