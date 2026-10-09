import 'package:flutter/material.dart';

enum LogoVariant {
  iconOnly,
  horizontal,
  stacked,
  badge,
}

/// Custom-crafted Clinexa healthcare brand emblem.
/// Features a gradient medical cross nestled within a protective shield,
/// with ambient glow and precision geometry.
class ClinexaLogo extends StatefulWidget {
  final double size;
  final LogoVariant variant;
  final bool animate;
  final String? subtitle;
  final Color? textColor;

  const ClinexaLogo({
    super.key,
    this.size = 48,
    this.variant = LogoVariant.iconOnly,
    this.animate = false,
    this.subtitle,
    this.textColor,
  });

  @override
  State<ClinexaLogo> createState() => _ClinexaLogoState();
}

class _ClinexaLogoState extends State<ClinexaLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ClinexaLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildEmblem(BuildContext context) {
    final double s = widget.size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget emblem = Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(s * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF13978B),
            Color(0xFF0E6F68),
            Color(0xFF534BC7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF159A8F).withValues(alpha: isDark ? 0.38 : 0.24),
            blurRadius: s * 0.35,
            offset: Offset(0, s * 0.12),
          ),
          BoxShadow(
            color: const Color(0xFF635BDF).withValues(alpha: isDark ? 0.28 : 0.16),
            blurRadius: s * 0.5,
            offset: Offset(0, s * 0.2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glass highlight reflection
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: s * 0.45,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(s * 0.28)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Precision Custom Icon: Shield + Medical Cross + Pulse
          CustomPaint(
            size: Size(s * 0.62, s * 0.62),
            painter: _EmblemPainter(),
          ),
        ],
      ),
    );

    if (widget.animate) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 + (_controller.value * 0.04);
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: emblem,
      );
    }

    return emblem;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final emblem = _buildEmblem(context);

    if (widget.variant == LogoVariant.iconOnly) {
      return emblem;
    }

    final brandColor = widget.textColor ?? scheme.onSurface;

    if (widget.variant == LogoVariant.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          emblem,
          SizedBox(width: widget.size * 0.26),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Clinexa',
                    style: TextStyle(
                      color: brandColor,
                      fontSize: widget.size * 0.48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      height: 1.1,
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(left: widget.size * 0.08, bottom: widget.size * 0.22),
                    width: widget.size * 0.14,
                    height: widget.size * 0.14,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2BB8AA),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  widget.subtitle!,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: widget.size * 0.24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    }

    if (widget.variant == LogoVariant.stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          emblem,
          SizedBox(height: widget.size * 0.25),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CLINEXA',
                style: TextStyle(
                  color: brandColor,
                  fontSize: widget.size * 0.36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 4),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF2BB8AA),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle!,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: widget.size * 0.18,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ],
      );
    }

    // Badge variant
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.size * 0.28,
        vertical: widget.size * 0.14,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size * 0.6,
            height: widget.size * 0.6,
            child: emblem,
          ),
          SizedBox(width: widget.size * 0.18),
          Text(
            widget.subtitle ?? 'CLINEXA HEALTH',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: widget.size * 0.26,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paintWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw Cross with rounded corners
    final crossThick = w * 0.28;
    final armLen = w * 0.88;

    final hRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, h / 2), width: armLen, height: crossThick),
      Radius.circular(crossThick * 0.35),
    );
    final vRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, h / 2), width: crossThick, height: armLen),
      Radius.circular(crossThick * 0.35),
    );

    canvas.drawRRect(hRect, paintWhite);
    canvas.drawRRect(vRect, paintWhite);

    // Inner subtle center diamond
    final paintAccent = Paint()
      ..color = const Color(0xFF13978B)
      ..style = PaintingStyle.fill;

    final centerDot = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, h / 2), width: crossThick * 0.55, height: crossThick * 0.55),
      Radius.circular(crossThick * 0.18),
    );
    canvas.drawRRect(centerDot, paintAccent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
