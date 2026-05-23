import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'catalog_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  // Советы — случайный тайтл из известных с сайта
  final List<Map<String, String>> _tips = [
    {
      'title': 'Как демон-император стал дворецким',
      'hint': 'Экшн, фэнтези · Продолжается',
    },
    {
      'title': 'Магия и мечи',
      'hint': 'Приключения · Завершён',
    },
    {
      'title': 'Реинкарнация в другом мире',
      'hint': 'Исэкай, боевик · Продолжается',
    },
    {
      'title': 'Тёмный охотник',
      'hint': 'Боевик, фэнтези · Продолжается',
    },
    {
      'title': 'Система Апокалипсиса',
      'hint': 'Постапокалипсис · Завершён',
    },
  ];

  late Map<String, String> _tip;

  @override
  void initState() {
    super.initState();
    _tip = _tips[Random().nextInt(_tips.length)];

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.82, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (_, __, ___) => const CatalogScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              // Logo
              ScaleTransition(
                scale: _scaleAnim,
                child: _AppLogo(size: 110),
              ),
              const SizedBox(height: 20),
              // App name
              const Text(
                'dutyIs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Читай мангу везде',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(flex: 2),
              // Tip card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.08), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C6FF7).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.auto_stories_rounded,
                          color: Color(0xFF7C6FF7),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Совет: попробуй почитать',
                              style: TextStyle(
                                color: Color(0xFF7C6FF7),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _tip['title']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _tip['hint']!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 1),
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Text(
                  '© 2025–2026 dutyIs',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.18),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  final double size;
  const _AppLogo({this.size = 80});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24), // Чтобы квадратная иконка была со скругленными углами
        child: Image.asset(
          'assets/icon/app_icon.png', // <-- Путь заменен на вашу иконку
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Red circle background
    final bgPaint = Paint()..color = const Color(0xFFCC1A1A);
    // Outer glow ring
    final glowPaint = Paint()
      ..color = const Color(0xFFFF3333).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawCircle(Offset(cx, cy), r, bgPaint);
    canvas.drawCircle(Offset(cx, cy), r - 2, glowPaint);

    // Dark inner shadow
    final shadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.35),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, shadowPaint);

    final figurePaint = Paint()
      ..color = Colors.black.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    final scale = size.width / 100.0;

    // Body silhouette (standing warrior)
    final bodyPath = Path();
    // Head
    bodyPath.addOval(Rect.fromCenter(
        center: Offset(cx, cy - 28 * scale), width: 12 * scale, height: 14 * scale));
    // Torso
    bodyPath.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, cy - 10 * scale),
          width: 16 * scale,
          height: 22 * scale),
      Radius.circular(4 * scale),
    ));
    // Left leg
    bodyPath.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 9 * scale, cy + 1 * scale, 7 * scale, 22 * scale),
      Radius.circular(3 * scale),
    ));
    // Right leg
    bodyPath.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(cx + 2 * scale, cy + 1 * scale, 7 * scale, 22 * scale),
      Radius.circular(3 * scale),
    ));

    canvas.drawPath(bodyPath, figurePaint);

    // Sword — diagonal from top-right to bottom-left
    final swordPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * scale
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(cx + 18 * scale, cy - 38 * scale),
      Offset(cx - 5 * scale, cy + 5 * scale),
      swordPaint,
    );

    // Sword guard
    final guardPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx + 8 * scale, cy - 22 * scale),
      Offset(cx + 18 * scale, cy - 14 * scale),
      guardPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}