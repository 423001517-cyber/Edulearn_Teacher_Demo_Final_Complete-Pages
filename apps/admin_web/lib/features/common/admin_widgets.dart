import 'dart:math' as math;

import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/navigation.dart';
import '../../data/admin_functions.dart';

/// Runs an admin action; shows [success] or a readable error as a toast.
Future<T?> runAdminAction<T>(Future<T> Function() action, {String? success}) async {
  try {
    final result = await action();
    if (success != null) showToast(success);
    return result;
  } on AdminActionException catch (e) {
    showToast(e.message);
  } catch (e) {
    showToast('Something went wrong: $e');
  }
  return null;
}

/// Like [runAdminAction] for actions without a result; true on success.
Future<bool> attempt(Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null) showToast(success);
    return true;
  } on AdminActionException catch (e) {
    showToast(e.message);
  } catch (e) {
    showToast('Something went wrong: $e');
  }
  return false;
}

Future<void> copyText(String text, String toast) async {
  await Clipboard.setData(ClipboardData(text: text));
  showToast(toast);
}

/// Monospace class code with a copy button.
class CodeChip extends StatelessWidget {
  const CodeChip(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.chip,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: code.isEmpty ? null : () => copyText(code, 'Class code copied — $code is ready to paste.'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(code.isEmpty ? '—' : code,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.4)),
              const SizedBox(width: 6),
              const Icon(Icons.content_copy_outlined, size: 15, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Share this link" result dialog (new teacher accounts, password links).
Future<void> showLinkDialog({required String title, required String message, required String link}) {
  return showRootDialog<void>(
    (ctx) => AppDialog(
      maxWidth: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(
            title: title,
            leading: const ToneIcon(Icons.check_rounded, tone: Tone.green, size: 46, circle: true),
          ),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(height: 1.5)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(10)),
            child: SelectableText(link, style: AppText.meta.copyWith(fontSize: 12)),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => copyText(link, 'Link copied'),
                  icon: const Icon(Icons.content_copy_outlined, size: 18),
                  label: const Text('Copy link'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Dropdown of teachers (disabled accounts are listed but not selectable).
class TeacherPicker extends StatelessWidget {
  const TeacherPicker({
    super.key,
    required this.teachers,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final List<Teacher> teachers;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<String>(
      key: ValueKey('teacher-$value-${teachers.length}'),
      initialSelection: value,
      enabled: enabled,
      expandedInsets: EdgeInsets.zero,
      requestFocusOnTap: false,
      hintText: 'Choose a teacher',
      dropdownMenuEntries: [
        for (final t in teachers)
          DropdownMenuEntry(
            value: t.uid,
            label: t.isDisabled ? '${t.displayName} (disabled)' : t.displayName,
            enabled: !t.isDisabled,
          ),
      ],
      onSelected: onChanged,
    );
  }
}

/// Dropdown of classes.
class ClassPicker extends StatelessWidget {
  const ClassPicker({super.key, required this.classes, required this.value, required this.onChanged});

  final List<ClassRoom> classes;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<String>(
      key: ValueKey('class-$value-${classes.length}'),
      initialSelection: value,
      expandedInsets: EdgeInsets.zero,
      requestFocusOnTap: false,
      hintText: 'Choose a class',
      dropdownMenuEntries: [
        for (final c in classes) DropdownMenuEntry(value: c.id, label: '${c.name} · ${c.classCode}'),
      ],
      onSelected: onChanged,
    );
  }
}

class GradePicker extends StatelessWidget {
  const GradePicker({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<int>(
      initialSelection: value,
      expandedInsets: EdgeInsets.zero,
      requestFocusOnTap: false,
      dropdownMenuEntries: [
        for (var g = 1; g <= 12; g++) DropdownMenuEntry(value: g, label: 'Grade $g'),
      ],
      onSelected: (g) => onChanged(g ?? value),
    );
  }
}

class TableCol {
  const TableCol(this.label, {this.flex = 10});
  final String label;
  final int flex;
}

/// A card with a header row, one row per item (cells follow [columns]),
/// pagination, and a stacked card layout on narrow screens.
class AdminTable<T> extends StatefulWidget {
  const AdminTable({
    super.key,
    required this.columns,
    required this.items,
    required this.cells,
    required this.compact,
    this.pageSize = 15,
    this.noun = 'items',
    this.emptyMessage = 'Nothing here yet.',
  });

  final List<TableCol> columns;
  final List<T> items;
  final List<Widget> Function(T item) cells;
  final Widget Function(T item) compact;
  final int pageSize;
  final String noun;
  final String emptyMessage;

  @override
  State<AdminTable<T>> createState() => _AdminTableState<T>();
}

class _AdminTableState<T> extends State<AdminTable<T>> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) {
      return Container(decoration: AppDecorations.card, child: EmptyNote(widget.emptyMessage));
    }
    final pages = (items.length / widget.pageSize).ceil();
    final page = math.min(_page, pages - 1);
    final start = page * widget.pageSize;
    final shown = items.sublist(start, math.min(start + widget.pageSize, items.length));

    return Container(
      decoration: AppDecorations.card,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 860;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Container(
                color: AppColors.chip.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    for (final c in widget.columns)
                      Expanded(flex: c.flex, child: Text(c.label, style: AppText.label)),
                  ],
                ),
              ),
            for (final item in shown)
              Container(
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
                padding: EdgeInsets.symmetric(horizontal: wide ? 20 : 14, vertical: 12),
                child: wide
                    ? Row(
                        children: [
                          for (final (i, cell) in widget.cells(item).indexed)
                            Expanded(
                              flex: widget.columns[i].flex,
                              child: Align(alignment: Alignment.centerLeft, child: cell),
                            ),
                        ],
                      )
                    : widget.compact(item),
              ),
            Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Showing ${start + 1}–${start + shown.length} of ${items.length} ${widget.noun}',
                        style: AppText.meta),
                  ),
                  if (pages > 1) ...[
                    IconButton(
                      tooltip: 'Previous page',
                      onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text('${page + 1} / $pages', style: const TextStyle(fontWeight: FontWeight.w700)),
                    IconButton(
                      tooltip: 'Next page',
                      onPressed: page < pages - 1 ? () => setState(() => _page = page + 1) : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// "Rosa Dizon" with an avatar and a second line.
class PersonCell extends StatelessWidget {
  const PersonCell({super.key, required this.name, this.subtitle = '', this.size = 40});

  final String name;
  final String subtitle;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InitialsAvatar(initials: initialsOf(name), tone: toneForName(name), size: size),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.itemTitle),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.meta.copyWith(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Completion-style bar with its percentage.
class RateCell extends StatelessWidget {
  const RateCell(this.value, {super.key});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(percent(value), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 4),
          ProgressBar(value: value, height: 7),
        ],
      ),
    );
  }
}
