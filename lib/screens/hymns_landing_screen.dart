import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hymns_latest/services/christmas_mode_service.dart';
import 'package:hymns_latest/screens/hymns_screen.dart';
import 'package:hymns_latest/screens/keerthane_screen.dart';
import 'package:hymns_latest/screens/christmas_carols_screen.dart';
import 'package:hymns_latest/utils/haptic_feedback_manager.dart';
import 'dart:math' as math;

/// Landing screen that shows either the default Hymns view or
/// a category-based view during Christmas time.
class HymnsLandingScreen extends StatelessWidget {
  const HymnsLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChristmasModeService>(
      builder: (context, christmasService, child) {
        if (christmasService.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (christmasService.isChristmasTime) {
          return const ChristmasLandingView();
        }

        return const HymnsScreen();
      },
    );
  }
}

/// The Christmas-themed landing view with category cards and snowfall
class ChristmasLandingView extends StatefulWidget {
  const ChristmasLandingView({super.key});

  @override
  State<ChristmasLandingView> createState() => _ChristmasLandingViewState();
}

class _ChristmasLandingViewState extends State<ChristmasLandingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _snowController;

  @override
  void initState() {
    super.initState();
    _snowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _snowController.dispose();
    super.dispose();
  }

  void _showFestiveToast(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _FestiveToastOverlay(
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;

    // Dynamic horizontal padding based on screen width
    final horizontalPadding = size.width > 600 ? 32.0 : 16.0;

    return Scaffold(
      body: Stack(
        children: [
          // Dark gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0D1B2A),
                  Color(0xFF1B263B),
                  Color(0xFF1B263B),
                  Color(0xFF0D1B2A),
                ],
              ),
            ),
          ),

          // Snowfall animation
          AnimatedBuilder(
            animation: _snowController,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: SnowfallPainter(
                  progress: _snowController.value,
                  snowflakeColor: Colors.white.withOpacity(0.6),
                  snowflakeCount: 50,
                ),
              );
            },
          ),

          // Main content
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        horizontalPadding, 24, horizontalPadding, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB22222).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      const Color(0xFFB22222).withOpacity(0.3),
                                ),
                              ),
                              child: const Text('🎄',
                                  style: TextStyle(fontSize: 28)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Merry Christmas!',
                                    style: textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Glory to God in the highest',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: Colors.white70,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Text('⭐', style: TextStyle(fontSize: 24)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Category cards
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Hymns Card
                      _CategoryCard(
                        title: 'Hymns',
                        subtitle: 'Traditional hymns from the CSI hymn book',
                        emoji: '🎵',
                        gradientColors: const [
                          Color(0xFF2E7D32),
                          Color(0xFF1B5E20)
                        ],
                        onTap: () {
                          HapticFeedbackManager.lightClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HymnsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Keerthane Card
                      _CategoryCard(
                        title: 'Keerthane',
                        subtitle: 'Kannada devotional songs and lyrics',
                        emoji: '🎶',
                        gradientColors: const [
                          Color(0xFF1976D2),
                          Color(0xFF0D47A1)
                        ],
                        onTap: () {
                          HapticFeedbackManager.lightClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const KeerthaneScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Christmas Carols Card
                      _CategoryCard(
                        title: 'Christmas Carols',
                        subtitle: 'Celebrate the season with festive songs',
                        emoji: '🎄',
                        gradientColors: const [
                          Color(0xFFC62828),
                          Color(0xFF8E0000)
                        ],
                        isHighlighted: true,
                        onTap: () {
                          HapticFeedbackManager.lightClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ChristmasCarolsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                    ]),
                  ),
                ),

                // Decorative footer - Easter egg!
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding, vertical: 8),
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedbackManager.mediumClick();
                          _showFestiveToast(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('❄️', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              Text(
                                'Peace on Earth',
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('❄️', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable category card widget with better contrast
class _CategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emoji;
  final List<Color> gradientColors;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.gradientColors,
    this.isHighlighted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: isHighlighted ? 12 : 6,
      shadowColor: gradientColors.first.withOpacity(0.5),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
          ),
          child: Row(
            children: [
              // Emoji container with better contrast
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 14),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isHighlighted) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'NEW',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: gradientColors.first,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Arrow icon with better visibility
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for snowfall effect
class SnowfallPainter extends CustomPainter {
  final double progress;
  final Color snowflakeColor;
  final int snowflakeCount;

  SnowfallPainter({
    required this.progress,
    required this.snowflakeColor,
    this.snowflakeCount = 50,
  }) {
    if (_cachedSnowflakes.isEmpty ||
        _cachedSnowflakes.length != snowflakeCount) {
      _generateSnowflakes();
    }
  }

  static final List<Snowflake> _cachedSnowflakes = [];

  void _generateSnowflakes() {
    _cachedSnowflakes.clear();
    final random = math.Random(42);
    for (int i = 0; i < snowflakeCount; i++) {
      _cachedSnowflakes.add(Snowflake(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 3 + 1,
        speed: random.nextDouble() * 0.3 + 0.1,
        drift: random.nextDouble() * 0.08 - 0.04,
        opacity: random.nextDouble() * 0.5 + 0.3,
      ));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final flake in _cachedSnowflakes) {
      final paint = Paint()
        ..color = snowflakeColor.withOpacity(flake.opacity)
        ..style = PaintingStyle.fill;

      final y = ((flake.y + progress * flake.speed) % 1.0) * size.height;
      final x = (flake.x +
              math.sin(progress * math.pi * 2 + flake.y * 10) * flake.drift) *
          size.width;

      canvas.drawCircle(
        Offset(x, y),
        flake.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SnowfallPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class Snowflake {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double drift;
  final double opacity;

  Snowflake({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.drift,
    required this.opacity,
  });
}

/// Festive animated toast overlay for the Easter egg
class _FestiveToastOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const _FestiveToastOverlay({required this.onDismiss});

  @override
  State<_FestiveToastOverlay> createState() => _FestiveToastOverlayState();
}

class _FestiveToastOverlayState extends State<_FestiveToastOverlay>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _shimmerController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    _slideController.forward();

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _slideController.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onTap: () {
                _slideController.reverse().then((_) => widget.onDismiss());
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withOpacity(0.5),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Bouncy dove
                        Transform.translate(
                          offset: Offset(
                              0,
                              math.sin(_shimmerController.value * math.pi * 2) *
                                  2),
                          child: const Text(
                            '🕊️',
                            style: TextStyle(
                                fontSize: 16, decoration: TextDecoration.none),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Shimmer text
                        ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              colors: const [
                                Colors.white,
                                Color(0xFFFFD700),
                                Colors.white,
                              ],
                              stops: [
                                (_shimmerController.value - 0.3)
                                    .clamp(0.0, 1.0),
                                _shimmerController.value.clamp(0.0, 1.0),
                                (_shimmerController.value + 0.3)
                                    .clamp(0.0, 1.0),
                              ],
                            ).createShader(bounds);
                          },
                          child: const Text(
                            'Goodwill to all men',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                              color: Colors.white,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Bouncy star
                        Transform.scale(
                          scale: 0.9 +
                              math.sin(_shimmerController.value * math.pi * 2) *
                                  0.15,
                          child: const Text(
                            '✨',
                            style: TextStyle(
                                fontSize: 14, decoration: TextDecoration.none),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
