import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'clinexa_ui.dart';

/// Compatibility wrapper for older Clinexa feature pages.
/// V7 keeps the existing feature logic but gives those screens the same adaptive,
/// overflow-safe presentation as the redesigned modules.
class SectionPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;

  const SectionPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 640 ? 16.0 : 24.0;
    return ColoredBox(
      color: Colors.transparent,
      child: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 8),
          child: CxPageHeader(
            eyebrow: 'Clinexa workspace',
            title: title,
            subtitle: subtitle,
            icon: _iconForTitle(title),
            actions: actions,
          ),
        ),
        Expanded(child: child),
      ]),
    );
  }

  IconData _iconForTitle(String value) {
    final key = value.toLowerCase();
    if (key.contains('ai')) return Icons.auto_awesome_rounded;
    if (key.contains('message')) return Icons.chat_bubble_rounded;
    if (key.contains('record')) return Icons.folder_copy_rounded;
    if (key.contains('emergency')) return Icons.health_and_safety_rounded;
    if (key.contains('operation')) return Icons.domain_rounded;
    if (key.contains('search')) return Icons.manage_search_rounded;
    if (key.contains('setting') || key.contains('security')) return Icons.tune_rounded;
    if (key.contains('document') || key.contains('ocr')) return Icons.document_scanner_rounded;
    return Icons.dashboard_customize_rounded;
  }

}

class ErrorCard extends StatelessWidget {
  final String message;
  const ErrorCard(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ClinexaTheme.rose,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ClinexaTheme.emergency.withValues(alpha: .16)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.error_outline_rounded, color: ClinexaTheme.emergency, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 11.5, height: 1.4))),
        ]),
      );
}

class ClinexaEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const ClinexaEmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 54, height: 54, decoration: BoxDecoration(gradient: const LinearGradient(colors: [ClinexaTheme.mint, ClinexaTheme.accentSoft]), borderRadius: BorderRadius.circular(18)), child: Icon(icon, color: ClinexaTheme.primary)),
          const SizedBox(height: 13),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 11.5, height: 1.45)),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ]),
      );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
