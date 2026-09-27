import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../providers/data_providers.dart';
import 'top_bar.dart';

/// Sections that aren't built yet. Links from other pages already point
/// here (with ?classId=…), so wiring a real page later is a one-line change
/// in router.dart.
class PlaceholderPage extends ConsumerWidget {
  const PlaceholderPage({super.key, required this.section, this.classId});

  final NavSection section;
  final String? classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cls = classId == null ? null : ref.watch(classByIdProvider)[classId];
    return PageScaffold(
      header: PageHeader(icon: section.icon, title: section.label, subtitle: cls?.name),
      children: [
        Container(
          decoration: AppDecorations.card,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            children: [
              Icon(section.icon, size: 44, color: AppColors.muted.withValues(alpha: 0.5)),
              const SizedBox(height: 14),
              Text('The ${section.label} page is next on the build list.',
                  textAlign: TextAlign.center, style: AppText.sectionTitle),
              const SizedBox(height: 6),
              const Text(
                'Everything you need today is on the Dashboard and in Classes.',
                textAlign: TextAlign.center,
                style: AppText.meta,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                      onPressed: () => context.go(Routes.dashboard),
                      child: const Text('Go to Dashboard')),
                  OutlinedButton(
                    onPressed: () => context.go(
                        classId == null ? Routes.classes : Routes.classDetail(classId!)),
                    child: Text(classId == null ? 'Go to Classes' : 'Back to class'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
