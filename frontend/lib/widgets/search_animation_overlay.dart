import 'package:flutter/material.dart';
import 'dart:math' as math;

class SearchAnimationOverlay extends StatefulWidget {
  final bool isSearching;
  final VoidCallback? onComplete;

  const SearchAnimationOverlay({
    super.key,
    required this.isSearching,
    this.onComplete,
  });

  @override
  State<SearchAnimationOverlay> createState() => _SearchAnimationOverlayState();
}

class _SearchAnimationOverlayState extends State<SearchAnimationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late AnimationController _hexagonController;
  late AnimationController _particleController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _hexagonAnimation;
  late Animation<double> _particleAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scanController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    _hexagonController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.linear),
    );

    _hexagonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hexagonController, curve: Curves.linear),
    );

    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    _hexagonController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SearchAnimationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isSearching && oldWidget.isSearching) {
      // Trigger completion animation
      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onComplete?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSearching) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Scanning radar effect
            AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: ScanningRadarPainter(
                    progress: _scanAnimation.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),

            // Animated hexagons
            AnimatedBuilder(
              animation: _hexagonAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: AnimatedHexagonsPainter(
                    progress: _hexagonAnimation.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),

            // Data particles
            AnimatedBuilder(
              animation: _particleAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: DataParticlesPainter(
                    progress: _particleAnimation.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),

            // Center pulse effect
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.search,
                            color: Colors.blue,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Status text overlay
            Positioned(
              bottom: 150,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _scanAnimation,
                builder: (context, child) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.blue,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Analyzing Parking Data',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getStatusText(_scanAnimation.value),
                            style: TextStyle(
                              color: Colors.blue[200],
                              fontSize: 12,
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

  String _getStatusText(double progress) {
    if (progress < 0.25) {
      return 'Scanning nearby locations...';
    } else if (progress < 0.5) {
      return 'Processing availability data...';
    } else if (progress < 0.75) {
      return 'Calculating optimal routes...';
    } else {
      return 'Matching preferences...';
    }
  }
}

class ScanningRadarPainter extends CustomPainter {
  final double progress;

  ScanningRadarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.6;

    // Draw scanning circles
    for (int i = 0; i < 4; i++) {
      final radius = maxRadius * ((progress + i * 0.25) % 1.0);
      final opacity = 1.0 - ((progress + i * 0.25) % 1.0);

      final paint = Paint()
        ..color = Colors.blue.withOpacity(opacity * 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius, paint);
    }

    // Draw scanning beam
    final angle = progress * 2 * math.pi;
    final beamPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.blue.withOpacity(0.3),
          Colors.blue.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: maxRadius),
        angle - 0.3,
        0.6,
        false,
      )
      ..close();

    canvas.drawPath(path, beamPaint);
  }

  @override
  bool shouldRepaint(ScanningRadarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class AnimatedHexagonsPainter extends CustomPainter {
  final double progress;

  AnimatedHexagonsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final hexagonSize = 40.0;

    // Create a grid of hexagons
    for (int row = -3; row <= 3; row++) {
      for (int col = -3; col <= 3; col++) {
        final x = center.dx + col * hexagonSize * 1.5;
        final y = center.dy + row * hexagonSize * math.sqrt(3) + 
                  (col.isOdd ? hexagonSize * math.sqrt(3) / 2 : 0);

        final distance = math.sqrt(
          math.pow(x - center.dx, 2) + math.pow(y - center.dy, 2),
        );
        
        final maxDistance = size.width * 0.5;
        final normalizedDistance = (distance / maxDistance).clamp(0.0, 1.0);

        // Animate based on progress and distance
        final animationPhase = (progress - normalizedDistance).abs();
        final opacity = (1.0 - animationPhase * 2).clamp(0.0, 1.0);

        if (opacity > 0) {
          _drawHexagon(
            canvas,
            Offset(x, y),
            hexagonSize * 0.4,
            Colors.blue.withOpacity(opacity * 0.3),
            animationPhase < 0.1,
          );
        }
      }
    }
  }

  void _drawHexagon(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
    bool highlight,
  ) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i;
      final x = center.dx + size * math.cos(angle);
      final y = center.dy + size * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final paint = Paint()
      ..color = highlight ? Colors.greenAccent.withOpacity(0.5) : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = highlight ? 2.5 : 1.5;

    canvas.drawPath(path, paint);

    if (highlight) {
      final fillPaint = Paint()
        ..color = Colors.greenAccent.withOpacity(0.1)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    }
  }

  @override
  bool shouldRepaint(AnimatedHexagonsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class DataParticlesPainter extends CustomPainter {
  final double progress;

  DataParticlesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final random = math.Random(42); // Fixed seed for consistent animation

    for (int i = 0; i < 30; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final startRadius = random.nextDouble() * 150 + 50;
      final endRadius = startRadius + 100;

      final currentRadius = startRadius + (endRadius - startRadius) * progress;
      final x = center.dx + currentRadius * math.cos(angle);
      final y = center.dy + currentRadius * math.sin(angle);

      final opacity = (1.0 - progress) * 0.6;
      final paint = Paint()
        ..color = Colors.blue.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 3, paint);

      // Draw connecting lines
      if (i > 0 && i % 3 == 0) {
        final prevAngle = random.nextDouble() * 2 * math.pi;
        final prevRadius = startRadius + (endRadius - startRadius) * progress;
        final prevX = center.dx + prevRadius * math.cos(prevAngle);
        final prevY = center.dy + prevRadius * math.sin(prevAngle);

        final linePaint = Paint()
          ..color = Colors.blue.withOpacity(opacity * 0.3)
          ..strokeWidth = 1;

        canvas.drawLine(Offset(x, y), Offset(prevX, prevY), linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(DataParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
