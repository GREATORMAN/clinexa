import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Flexible surface used throughout Clinexa. It intentionally avoids fixed
/// heights so cards can grow with accessibility text and small phone widths.
class CxSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final bool elevated;
  final VoidCallback? onTap;
  final Border? border;

  const CxSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.gradient,
    this.radius = 18,
    this.elevated = false,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: gradient == null ? (color ?? Colors.white) : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? Border.all(color: ClinexaTheme.line),
      boxShadow: elevated
          ? const [
              BoxShadow(color: Color(0x0F10182B), blurRadius: 32, offset: Offset(0, 14)),
              BoxShadow(color: Color(0x070B776E), blurRadius: 12, offset: Offset(0, 3)),
            ]
          : null,
    );

    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: decoration,
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: body,
      ),
    );
  }
}

/// Responsive wrap grid with content-driven height. This replaces fixed-ratio
/// GridViews which were responsible for the yellow/black RenderFlex overflow
/// stripes on compact Android devices.
class CxAdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final int maxColumns;

  const CxAdaptiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 220,
    this.spacing = 12,
    this.maxColumns = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      final raw = ((constraints.maxWidth + spacing) / (minItemWidth + spacing)).floor();
      final columns = raw.clamp(1, maxColumns);
      final itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: children.map((child) => SizedBox(width: itemWidth, child: child)).toList(),
      );
    });
  }
}

class CxPageHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget? trailing;
  final IconData? icon;

  const CxPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    this.trailing,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 720;
      final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(eyebrow.toUpperCase(), style: const TextStyle(fontSize: 11, color: ClinexaTheme.primary, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
        const SizedBox(height: 10),
        Text(title, style: TextStyle(fontSize: compact ? 27 : 35, fontWeight: FontWeight.w700, color: ClinexaTheme.ink, letterSpacing: -1.2, height: 1.15)),
        const SizedBox(height: 9),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: Text(subtitle, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 13, height: 1.5))),
      ]);
      final buttons = Wrap(spacing: 8, runSpacing: 8, children: [...actions, if (trailing != null) trailing!]);
      if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [copy, if (actions.isNotEmpty || trailing != null) ...[const SizedBox(height: 18), buttons]]);
      return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(flex: 3, child: copy), if (actions.isNotEmpty || trailing != null) ...[const SizedBox(width: 20), Flexible(flex: 2, child: buttons)]]);
    });
  }
}

class CxSpotlightHero extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> stats;
  final List<Widget> actions;
  final IconData icon;

  const CxSpotlightHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.stats = const [],
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          Positioned.fill(child: DecoratedBox(decoration: const BoxDecoration(gradient: ClinexaTheme.heroGradient))),
          Positioned(right: -56, top: -76, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .055)))),
          Positioned(right: 90, bottom: -92, child: Container(width: 190, height: 190, decoration: BoxDecoration(shape: BoxShape.circle, color: ClinexaTheme.primaryBright.withValues(alpha: .16)))),
          Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .11), borderRadius: BorderRadius.circular(11), border: Border.all(color: Colors.white.withValues(alpha: .10))), child: Icon(icon, color: Colors.white, size: 18)),
                  const SizedBox(width: 10),
                  Flexible(child: Text(eyebrow.toUpperCase(), style: const TextStyle(color: Color(0xFF9DE7E0), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.25))),
                ]),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontSize: compact ? 28 : 34, letterSpacing: -1.0)),
                const SizedBox(height: 8),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 700), child: Text(subtitle, style: const TextStyle(color: Color(0xFFD4E1E7), fontSize: 12.5, height: 1.52))),
                if (actions.isNotEmpty) ...[const SizedBox(height: 18), Wrap(spacing: 8, runSpacing: 8, children: actions)],
              ]);
              if (compact || stats.isEmpty) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [copy, if (stats.isNotEmpty) ...[const SizedBox(height: 20), Wrap(spacing: 8, runSpacing: 8, children: stats)]]);
              }
              return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(flex: 7, child: copy), const SizedBox(width: 20), Flexible(flex: 4, child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: stats))]);
            }),
          ),
        ],
      ),
    );
  }
}

class CxHeroStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const CxHeroStat({super.key, required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        width: 106,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .095),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: .11)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 10),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.45)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFC7D9DF), fontSize: 9.2, fontWeight: FontWeight.w600)),
        ]),
      );
}

class CxMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color tone;
  final String? trend;

  const CxMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    this.tone = ClinexaTheme.primary,
    this.trend,
  });

  @override
  Widget build(BuildContext context) => CxSurface(
        elevated: true,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: tone.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: tone, size: 20)),
            const Spacer(),
            if (trend != null) CxStatusChip(label: trend!, color: ClinexaTheme.success, icon: Icons.trending_up_rounded),
          ]),
          const SizedBox(height: 15),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 25, letterSpacing: -.8)),
          const SizedBox(height: 3),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 4),
          Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.7, height: 1.4)),
        ]),
      );
}

class CxStatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const CxStatusChip({super.key, required this.label, this.color = ClinexaTheme.primary, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: .16))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12.5, color: color), const SizedBox(width: 5)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10.2))),
        ]),
      );
}

class CxSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const CxSectionHeader({super.key, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16.5, letterSpacing: -.35)),
          if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 12, height: 1.4))],
        ]);
        if (action == null) return copy;
        if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [copy, const SizedBox(height: 10), Align(alignment: Alignment.centerLeft, child: action!)]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: copy), const SizedBox(width: 10), Flexible(child: action!)]);
      });
}

class CxQuickAction extends StatelessWidget {
  final String label;
  final String caption;
  final IconData icon;
  final VoidCallback? onTap;
  final Color tone;
  const CxQuickAction({super.key, required this.label, required this.caption, required this.icon, this.onTap, this.tone = ClinexaTheme.primary});

  @override
  Widget build(BuildContext context) => CxSurface(
        onTap: onTap,
        elevated: true,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [tone, Color.lerp(tone, Colors.white, .22)!]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: tone.withValues(alpha: .18), blurRadius: 16, offset: const Offset(0, 7))]),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 2),
            Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 12, height: 1.35)),
          ])),
          const SizedBox(width: 5),
          const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF98A3B3)),
        ]),
      );
}

class CxEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const CxEmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 54, height: 54, decoration: BoxDecoration(gradient: const LinearGradient(colors: [ClinexaTheme.mint, ClinexaTheme.accentSoft]), borderRadius: BorderRadius.circular(18)), child: Icon(icon, color: ClinexaTheme.primary, size: 24)),
          const SizedBox(height: 13),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 5),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 12, height: 1.45))),
          if (action != null) ...[const SizedBox(height: 13), action!],
        ]),
      );
}
class CxMedicineVisual extends StatelessWidget {
  final String imageKey;
  final Color? tone;
  final double size;
  const CxMedicineVisual({super.key, required this.imageKey, this.tone, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final c = tone ?? ClinexaTheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, c.withAlpha(15)],
        ),
        borderRadius: BorderRadius.circular(size * .28),
        border: Border.all(color: c.withAlpha(30)),
        boxShadow: const [BoxShadow(color: Color(0x0B0B1424), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .28),
        child: CustomPaint(
          painter: _MedicinePainter(kind: imageKey, tone: c),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _MedicinePainter extends CustomPainter {
  final String kind;
  final Color tone;
  const _MedicinePainter({required this.kind, required this.tone});

  Paint _paint(Color color) => Paint()..color = color..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawCircle(Offset(w * .82, h * .18), w * .24, _paint(tone.withAlpha(16)));
    canvas.drawCircle(Offset(w * .12, h * .88), w * .18, _paint(tone.withAlpha(10)));

    switch (kind) {
      case 'inhaler':
        _inhaler(canvas, size);
        break;
      case 'cream':
      case 'gel':
        _tube(canvas, size);
        break;
      case 'sachet':
        _sachet(canvas, size);
        break;
      case 'liquid':
      case 'syrup':
        _bottle(canvas, size);
        break;
      case 'drops':
      case 'eye_drop':
        _drops(canvas, size);
        break;
      case 'capsule':
        _capsule(canvas, size);
        break;
      default:
        _blister(canvas, size);
    }
  }

  void _blister(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(w * .18, h * .20, w * .64, h * .58), Radius.circular(w * .10));
    canvas.drawRRect(rect, _paint(const Color(0xFFE9EEF3)));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .20, h * .22, w * .60, h * .54), Radius.circular(w * .08)), _paint(Colors.white));
    final positions = <Offset>[
      Offset(w * .34, h * .37), Offset(w * .58, h * .37),
      Offset(w * .34, h * .59), Offset(w * .58, h * .59),
    ];
    for (final p in positions) {
      canvas.drawCircle(p, w * .085, _paint(tone.withAlpha(38)));
      canvas.drawCircle(p.translate(-w * .015, -h * .012), w * .054, _paint(tone));
    }
  }

  void _capsule(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    canvas.save();
    canvas.translate(w * .5, h * .5);
    canvas.rotate(-.55);
    final capsule = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w * .58, height: h * .23), Radius.circular(h * .13));
    canvas.drawRRect(capsule, _paint(const Color(0xFFF6F8FA)));
    final left = RRect.fromRectAndCorners(Rect.fromLTWH(-w * .29, -h * .115, w * .29, h * .23), topLeft: Radius.circular(h * .13), bottomLeft: Radius.circular(h * .13));
    canvas.drawRRect(left, _paint(tone));
    canvas.drawLine(Offset.zero.translate(0, -h * .105), Offset.zero.translate(0, h * .105), Paint()..color = tone.withAlpha(80)..strokeWidth = 1);
    canvas.restore();
    canvas.drawCircle(Offset(w * .28, h * .72), w * .07, _paint(tone.withAlpha(25)));
  }

  void _inhaler(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .35, h * .20, w * .28, h * .35), Radius.circular(w * .07)), _paint(tone));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .31, h * .50, w * .38, h * .24), Radius.circular(w * .08)), _paint(tone.withAlpha(205)));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .58, h * .61, w * .20, h * .10), Radius.circular(w * .04)), _paint(const Color(0xFFDCE7E6)));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .40, h * .15, w * .18, h * .08), Radius.circular(w * .03)), _paint(const Color(0xFFD8E1E7)));
  }

  void _tube(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final path = Path()
      ..moveTo(w * .29, h * .24)
      ..lineTo(w * .66, h * .30)
      ..lineTo(w * .58, h * .72)
      ..lineTo(w * .23, h * .66)
      ..close();
    canvas.drawPath(path, _paint(Colors.white));
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = tone.withAlpha(55));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .28, h * .43, w * .31, h * .08), Radius.circular(w * .025)), _paint(tone));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .24, h * .66, w * .34, h * .08), Radius.circular(w * .025)), _paint(const Color(0xFFD6DEE7)));
  }

  void _sachet(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(w * .22, h * .16, w * .56, h * .68), Radius.circular(w * .06));
    canvas.drawRRect(r, _paint(Colors.white));
    canvas.drawRRect(r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.3..color = tone.withAlpha(70));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .30, h * .34, w * .40, h * .20), Radius.circular(w * .05)), _paint(tone.withAlpha(24)));
    canvas.drawCircle(Offset(w * .50, h * .44), w * .07, _paint(tone));
    canvas.drawLine(Offset(w * .28, h * .22), Offset(w * .72, h * .22), Paint()..color = const Color(0xFFDDE5EC)..strokeWidth = 1);
  }

  void _bottle(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .35, h * .16, w * .30, h * .12), Radius.circular(w * .035)), _paint(const Color(0xFFBFC9D3)));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .29, h * .25, w * .42, h * .52), Radius.circular(w * .09)), _paint(tone.withAlpha(205)));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .34, h * .42, w * .32, h * .20), Radius.circular(w * .04)), _paint(Colors.white.withAlpha(235)));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .39, h * .48, w * .22, h * .05), Radius.circular(w * .02)), _paint(tone));
  }

  void _drops(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final cap = Path()..moveTo(w * .42, h * .18)..lineTo(w * .58, h * .18)..lineTo(w * .64, h * .33)..lineTo(w * .36, h * .33)..close();
    canvas.drawPath(cap, _paint(const Color(0xFFD7E0E8)));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .30, h * .31, w * .40, h * .43), Radius.circular(w * .10)), _paint(Colors.white));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .34, h * .46, w * .32, h * .15), Radius.circular(w * .04)), _paint(tone.withAlpha(28)));
    canvas.drawCircle(Offset(w * .50, h * .535), w * .055, _paint(tone));
  }

  @override
  bool shouldRepaint(covariant _MedicinePainter oldDelegate) => oldDelegate.kind != kind || oldDelegate.tone != tone;
}

class CxSkeleton extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const CxSkeleton({super.key, required this.height, this.width, this.radius = 12});
  @override
  State<CxSkeleton> createState() => _CxSkeletonState();
}

class _CxSkeletonState extends State<CxSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (_, __) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(const Color(0xFFEEF2F6), const Color(0xFFF9FBFC), controller.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}

class CxErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const CxErrorBanner({super.key, required this.message, this.onRetry});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: ClinexaTheme.rose, borderRadius: BorderRadius.circular(16), border: Border.all(color: ClinexaTheme.emergency.withAlpha(34))),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: ClinexaTheme.emergency),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      );
}
