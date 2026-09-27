import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/admin_providers.dart';
import '../shell/top_bar.dart';
import 'request_widgets.dart';

/// `/requests` — teachers' "Request New Class" submissions.
class RequestsPage extends ConsumerStatefulWidget {
  const RequestsPage({super.key});

  @override
  ConsumerState<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends ConsumerState<RequestsPage> {
  RequestStatus? _status = RequestStatus.pending; // null = all

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(requestsProvider);
    final all = requests.valueOrNull ?? const <ClassRequest>[];
    int count(RequestStatus s) => all.where((r) => r.status == s).length;
    final shown = _status == null ? all : all.where((r) => r.status == _status).toList();

    return PageScaffold(
      header: const AdminPageHeader(
        icon: Icons.move_to_inbox_outlined,
        title: 'Class Requests',
        subtitle: 'Approve to create the class and its official code, or decline with a reason.',
      ),
      children: [
        ResponsiveGrid(
          maxColumns: 3,
          children: [
            StatCard(
              icon: Icons.hourglass_top_rounded,
              tone: Tone.amber,
              label: 'Pending',
              value: requests.whenData((_) => '${count(RequestStatus.pending)}'),
              caption: 'Waiting for a decision',
              selected: _status == RequestStatus.pending,
              onTap: () => setState(() => _status = RequestStatus.pending),
            ),
            StatCard(
              icon: Icons.check_rounded,
              tone: Tone.green,
              label: 'Approved',
              value: requests.whenData((_) => '${count(RequestStatus.approved)}'),
              caption: 'Classes created',
              selected: _status == RequestStatus.approved,
              onTap: () => setState(() => _status = RequestStatus.approved),
            ),
            StatCard(
              icon: Icons.close_rounded,
              tone: Tone.red,
              label: 'Declined',
              value: requests.whenData((_) => '${count(RequestStatus.declined)}'),
              caption: 'Teacher notified',
              selected: _status == RequestStatus.declined,
              onTap: () => setState(() => _status = RequestStatus.declined),
            ),
          ],
        ),
        SectionCard(
          icon: Icons.move_to_inbox_outlined,
          title: _status == null ? 'All requests' : '${_status!.label} requests',
          trailing: FilterDropdown<RequestStatus?>(
            value: _status,
            options: const [null, RequestStatus.pending, RequestStatus.approved, RequestStatus.declined],
            labelOf: (s) => s?.label ?? 'All',
            onChanged: (s) => setState(() => _status = s),
          ),
          child: AsyncValueView<List<ClassRequest>>(
            value: requests,
            data: (_) => shown.isEmpty
                ? EmptyNote(
                    _status == RequestStatus.pending ? 'No pending requests. You’re all caught up.' : 'Nothing here.',
                    icon: Icons.inbox_outlined,
                  )
                : Column(
                    children: [
                      for (var i = 0; i < shown.length; i++) ...[
                        if (i > 0) const Divider(),
                        RequestCard(request: shown[i]),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
