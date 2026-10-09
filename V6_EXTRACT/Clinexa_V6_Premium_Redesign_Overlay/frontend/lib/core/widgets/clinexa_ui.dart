import 'package:flutter/material.dart';
import '../theme/theme.dart';

class CxSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final bool elevated;
  final VoidCallback? onTap;

  const CxSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.radius = 22,
    this.elevated = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: ClinexaTheme.line),
        boxShadow: elevated
            ? const [BoxShadow(color: Color(0x100B1424), blurRadius: 26, offset: Offset(0, 10))]
            : null,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class CxPageHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget? trailing;

  const CxPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 720;
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow.toUpperCase(), style: const TextStyle(color: ClinexaTheme.primary, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.25)),
          const SizedBox(height: 7),
          Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: compact ? 27 : 34)),
          const SizedBox(height: 6),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: Text(subtitle, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 13.5, height: 1.45))),
        ],
      );
      if (compact) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          heading,
          if (trailing != null || actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [...actions, if (trailing != null) trailing!]),
          ],
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: heading),
        if (actions.isNotEmpty) Wrap(spacing: 8, children: actions),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ]);
    });
  }
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
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: tone.withAlpha(20), borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: tone, size: 21),
            ),
            const Spacer(),
            if (trend != null) CxStatusChip(label: trend!, color: ClinexaTheme.success, icon: Icons.trending_up_rounded),
          ]),
          const SizedBox(height: 20),
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 27)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          const SizedBox(height: 4),
          Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 11.5)),
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
        decoration: BoxDecoration(color: color.withAlpha(18), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withAlpha(38))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 5)],
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10.5)),
        ]),
      );
}

class CxSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const CxSectionHeader({super.key, required this.title, this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17)),
          if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 11.5))],
        ])),
        if (action != null) action!,
      ]);
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
        padding: const EdgeInsets.all(15),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: tone.withAlpha(18), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: tone, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            const SizedBox(height: 2),
            Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF9AA7B8)),
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
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(17)), child: Icon(icon, color: ClinexaTheme.muted)),
          const SizedBox(height: 13),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 11.5, height: 1.45))),
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
