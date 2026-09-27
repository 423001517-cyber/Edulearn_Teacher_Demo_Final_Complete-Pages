import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../providers/classes_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/reports_providers.dart';
import '../shell/top_bar.dart';
import 'report_actions.dart';
import 'widgets/report_overview.dart';

/// `/reports?classId=&period=&panel=` — "View Reports" from Classes lands
/// here filtered to that class. `panel` opens a detail drawer on arrival
/// (used by the Dashboard's Missing Work card and the class stat cards).
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key, this.classId, required this.period, this.panel});

  final String? classId;
  final ReportPeriod period;
  final String? panel;

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  ReportPanel? _open;
  String? _autoOpened;

  Future<void> _openPanel(ReportPanel p, ClassRoom c) async {
    setState(() => _open = p);
    await openReportPanel(context, p, c, widget.period);
    if (mounted) setState(() => _open = null);
  }

  void _maybeAutoOpen(ClassRoom c) {
    final p = ReportPanel.parse(widget.panel);
    final key = '${c.id}/${widget.panel}';
    if (p == null || _autoOpened == key) return;
    _autoOpened = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openPanel(p, c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(classesProvider);
    return classes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: ErrorNote(error: e)),
      data: (all) {
        final active = all.where((c) => !c.isArchived).toList();
        ClassRoom? c;
        for (final x in all) {
          if (x.id == widget.classId) c = x;
        }
        c ??= active.isEmpty ? null : active.first;
        if (c == null) {
          return const PageScaffold(
            header: PageHeader(icon: Icons.assessment_outlined, title: 'Class Reports'),
            children: [EmptyNote('No classes yet — reports appear once a class is assigned.')],
          );
        }
        final cls = c;
        _maybeAutoOpen(cls);
        // Keep these streams warm so panels and exports open instantly.
        ref.watch(classClassworkProvider(cls.id));
        ref.watch(classStudentsProvider(cls.id));
        ref.watch(missingWorkProvider(cls.id));
        ref.watch(attendanceProvider(cls.id));

        final options = [...active, if (cls.isArchived) cls];
        return PageScaffold(
          header: PageHeader(
            icon: Icons.menu_book_outlined,
            title: 'Class Reports',
            subtitle: cls.name,
          ),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                FilterDropdown<ReportPeriod>(
                  value: widget.period,
                  options: ReportPeriod.values,
                  labelOf: (p) => p.label,
                  minWidth: 180,
                  onChanged: (p) =>
                      context.go(Routes.reports(classId: cls.id, period: p.name)),
                ),
                FilterDropdown<ClassRoom>(
                  value: cls,
                  options: options,
                  labelOf: (x) => x.name,
                  minWidth: 220,
                  onChanged: (x) =>
                      context.go(Routes.reports(classId: x.id, period: widget.period.name)),
                ),
              ],
            ),
            ReportStatsGrid(
              classId: cls.id,
              period: widget.period,
              selected: _open,
              onOpen: (p) => _openPanel(p, cls),
            ),
            TwoColumn(
              leftFlex: 3,
              rightFlex: 2,
              left: [ReportTrendCard(classId: cls.id, period: widget.period)],
              right: [
                ReportOptionsCard(
                  onStudentProgress: () => context.go(Routes.students(classId: cls.id)),
                  onPanel: (p) => _openPanel(p, cls),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white, minimumSize: const Size(0, 52)),
                        onPressed: () => exportFullPdf(ref, cls, widget.period),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Generate PDF'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryDeep, minimumSize: const Size(0, 52)),
                        onPressed: () => exportStudentCsv(ref, cls, widget.period),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Export CSV'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
