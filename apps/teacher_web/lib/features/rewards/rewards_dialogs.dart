import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../providers/core_providers.dart';

Future<void> showGivePointsDialog(
  BuildContext context, {
  required ClassRoom classRoom,
  required List<Student> roster,
  required RewardSettings settings,
  Student? preselected,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _GivePointsDialog(classRoom: classRoom, roster: roster, settings: settings, preselected: preselected),
    );

class _GivePointsDialog extends ConsumerStatefulWidget {
  const _GivePointsDialog({required this.classRoom, required this.roster, required this.settings, this.preselected});

  final ClassRoom classRoom;
  final List<Student> roster;
  final RewardSettings settings;
  final Student? preselected;

  @override
  ConsumerState<_GivePointsDialog> createState() => _GivePointsDialogState();
}

class _GivePointsDialogState extends ConsumerState<_GivePointsDialog> {
  static const _presets = [5, 10, 20, 50];

  late final Set<String> _picked = {if (widget.preselected != null) widget.preselected!.id};
  late bool _wholeClass = widget.preselected == null;
  final _custom = TextEditingController();
  final _reason = TextEditingController();
  int _points = 10;
  bool _takeAway = false;
  String? _badgeId;
  String _query = '';
  bool _saving = false;

  @override
  void dispose() {
    _custom.dispose();
    _reason.dispose();
    super.dispose();
  }

  List<Student> get _targets =>
      _wholeClass ? widget.roster : widget.roster.where((s) => _picked.contains(s.id)).toList();

  Future<void> _save() async {
    final targets = _targets;
    final pts = (_takeAway ? -1 : 1) * _points;
    if (targets.isEmpty || (_points == 0 && _badgeId == null)) return;
    setState(() => _saving = true);
    try {
      await ref.read(rewardsRepositoryProvider).giveAward(
            classId: widget.classRoom.id,
            students: targets,
            points: pts,
            reason: _reason.text,
            badgeId: _badgeId,
          );
      if (!mounted) return;
      Navigator.pop(context);
      final who = targets.length == 1 ? targets.first.firstName : '${targets.length} students';
      showToast(pts == 0
          ? 'Badge given to $who'
          : '${pts > 0 ? 'Gave' : 'Took'} ${pts.abs()} points ${pts > 0 ? 'to' : 'from'} $who');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast('Couldn’t give points: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final manual = widget.settings.badges.where((b) => b.kind == BadgeKind.manual && b.enabled).toList();
    final q = _query.trim().toLowerCase();
    final list = widget.roster.where((s) => q.isEmpty || s.name.toLowerCase().contains(q)).toList();
    final targets = _targets;

    return AppDialog(
      maxWidth: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(title: 'Give points', subtitle: widget.classRoom.name),
          const SizedBox(height: 16),
          const FieldLabel('Who'),
          SegmentedPills<bool>(
            value: _wholeClass,
            options: const [true, false],
            labelOf: (v) => v ? 'Whole class (${widget.roster.length})' : 'Choose students',
            expand: true,
            onChanged: (v) => setState(() => _wholeClass = v),
          ),
          if (!_wholeClass) ...[
            const SizedBox(height: 10),
            SearchField(hint: 'Search students', onChanged: (v) => setState(() => _query = v)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final s in list)
                    CheckboxListTile(
                      dense: true,
                      value: _picked.contains(s.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _picked.add(s.id);
                        } else {
                          _picked.remove(s.id);
                        }
                      }),
                      title: Text(s.name, style: const TextStyle(fontSize: 13.5)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            Text('${_picked.length} selected', style: AppText.meta),
          ],
          const SizedBox(height: 16),
          const FieldLabel('Points'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final p in _presets)
                ChoiceChip(
                  label: Text('${_takeAway ? '−' : '+'}$p'),
                  selected: _points == p && _custom.text.isEmpty,
                  onSelected: (_) => setState(() {
                    _points = p;
                    _custom.clear();
                  }),
                ),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _custom,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                  decoration: const InputDecoration(hintText: 'Other'),
                  onChanged: (v) => setState(() => _points = int.tryParse(v) ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            dense: true,
            value: _takeAway,
            onChanged: (v) => setState(() => _takeAway = v ?? false),
            title: const Text('Take points away instead', style: TextStyle(fontSize: 13.5)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          const FieldLabel('Reason (students see this)'),
          TextField(
            controller: _reason,
            maxLength: 120,
            decoration: const InputDecoration(hintText: 'e.g. Helped a classmate with the map activity'),
          ),
          if (manual.isNotEmpty) ...[
            const SizedBox(height: 4),
            const FieldLabel('Also give a badge (optional)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('No badge'),
                  selected: _badgeId == null,
                  onSelected: (_) => setState(() => _badgeId = null),
                ),
                for (final b in manual)
                  ChoiceChip(
                    avatar: Icon(RewardIcons.icon(b.icon), size: 16, color: RewardIcons.tone(b.tone).fg),
                    label: Text(b.name),
                    selected: _badgeId == b.id,
                    onSelected: (_) => setState(() => _badgeId = b.id),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving || targets.isEmpty || (_points == 0 && _badgeId == null) ? null : _save,
                  child: Text(_saving
                      ? 'Saving…'
                      : targets.length == 1
                          ? 'Give to ${targets.first.firstName}'
                          : 'Give to ${targets.length} students'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Create a badge you give by hand, or edit any badge (name, rule, on/off).
Future<void> showBadgeDialog(
  BuildContext context, {
  required String classId,
  required RewardSettings settings,
  BadgeDef? existing,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _BadgeDialog(classId: classId, settings: settings, existing: existing),
    );

class _BadgeDialog extends ConsumerStatefulWidget {
  const _BadgeDialog({required this.classId, required this.settings, this.existing});

  final String classId;
  final RewardSettings settings;
  final BadgeDef? existing;

  @override
  ConsumerState<_BadgeDialog> createState() => _BadgeDialogState();
}

class _BadgeDialogState extends ConsumerState<_BadgeDialog> {
  late final BadgeDef? _e = widget.existing;
  late final _name = TextEditingController(text: _e?.name ?? '');
  late final _description = TextEditingController(text: _e?.description ?? '');
  late int _threshold = _e?.threshold ?? 1;
  late String _icon = _e?.icon ?? 'star';
  late String _tone = _e?.tone ?? 'green';
  late bool _enabled = _e?.enabled ?? true;
  bool _saving = false;

  bool get _manual {
    final e = _e;
    return e == null || e.kind == BadgeKind.manual;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _write(List<BadgeDef> badges, String done) async {
    setState(() => _saving = true);
    try {
      await ref.read(rewardsRepositoryProvider).saveSettings(widget.classId, widget.settings.copyWith(badges: badges));
      if (!mounted) return;
      Navigator.pop(context);
      showToast(done);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast('Couldn’t save: $e');
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final e = _e;
    if (e == null) {
      final badge = BadgeDef(
        id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        kind: BadgeKind.manual,
        icon: _icon,
        tone: _tone,
        description: _description.text,
      );
      await _write([...widget.settings.badges, badge], 'Badge created: $name');
      return;
    }
    final updated = e.copyWith(
      name: name,
      threshold: _threshold,
      icon: _icon,
      tone: _tone,
      enabled: _enabled,
      description: _description.text,
    );
    await _write([for (final b in widget.settings.badges) b.id == e.id ? updated : b], 'Badge saved');
  }

  Future<void> _delete() async {
    final e = _e;
    if (e == null) return;
    final ok = await confirmAction(
      context,
      title: 'Delete badge?',
      message: 'Students who earned “${e.name}” will no longer see it.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await _write(widget.settings.badges.where((b) => b.id != e.id).toList(), 'Badge deleted');
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    final kind = e?.kind ?? BadgeKind.manual;
    return AppDialog(
      maxWidth: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(
            title: e == null ? 'Create badge' : 'Edit badge',
            subtitle: e == null || e.kind == BadgeKind.manual ? 'A badge you give by hand' : 'Earned automatically',
          ),
          const SizedBox(height: 16),
          const FieldLabel('Name'),
          TextField(controller: _name, maxLength: 40, decoration: const InputDecoration(hintText: 'e.g. Helping Hand')),
          if (_manual) ...[
            const FieldLabel('What it’s for'),
            TextField(
              controller: _description,
              maxLength: 100,
              decoration: const InputDecoration(hintText: 'e.g. Given for helping a classmate'),
            ),
          ] else ...[
            FieldLabel('Rule: ${kind.rule}'),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Fewer',
                  onPressed: _threshold > 1 ? () => setState(() => _threshold--) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                const SizedBox(width: 12),
                Text('$_threshold ${kind.unit}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(width: 12),
                IconButton.outlined(
                  tooltip: 'More',
                  onPressed: _threshold < 50 ? () => setState(() => _threshold++) : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          const FieldLabel('Icon'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in RewardIcons.badgeKeys)
                _PickCircle(
                  selected: _icon == k,
                  tone: RewardIcons.tone(_tone),
                  onTap: () => setState(() => _icon = k),
                  child: Icon(RewardIcons.icon(k), size: 20, color: RewardIcons.tone(_tone).fg),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const FieldLabel('Color'),
          Wrap(
            spacing: 8,
            children: [
              for (final k in RewardIcons.toneKeys)
                _PickCircle(
                  selected: _tone == k,
                  tone: RewardIcons.tone(k),
                  onTap: () => setState(() => _tone = k),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(color: RewardIcons.tone(k).fg, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
          if (e != null) ...[
            const SizedBox(height: 10),
            SwitchRow(
              label: 'Badge is on',
              hint: 'Turned-off badges are hidden from students.',
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              if (e != null && e.kind == BadgeKind.manual)
                TextButton(
                  onPressed: _saving ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: AppColors.red),
                  child: const Text('Delete'),
                ),
              const Spacer(),
              OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 10),
              FilledButton(onPressed: _saving ? null : _save, child: Text(e == null ? 'Create badge' : 'Save')),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickCircle extends StatelessWidget {
  const _PickCircle({required this.selected, required this.tone, required this.onTap, required this.child});

  final bool selected;
  final Tone tone;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? tone.bg : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? tone.fg : AppColors.buttonBorder, width: selected ? 2 : 1),
        ),
        child: child,
      ),
    );
  }
}

/// Add or edit a reward students can spend points on.
Future<void> showShopItemDialog(
  BuildContext context, {
  required String classId,
  required RewardSettings settings,
  ShopItem? existing,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ShopItemDialog(classId: classId, settings: settings, existing: existing),
    );

class _ShopItemDialog extends ConsumerStatefulWidget {
  const _ShopItemDialog({required this.classId, required this.settings, this.existing});

  final String classId;
  final RewardSettings settings;
  final ShopItem? existing;

  @override
  ConsumerState<_ShopItemDialog> createState() => _ShopItemDialogState();
}

class _ShopItemDialogState extends ConsumerState<_ShopItemDialog> {
  late final ShopItem? _e = widget.existing;
  late final _name = TextEditingController(text: _e?.name ?? '');
  late final _cost = TextEditingController(text: '${_e?.cost ?? 100}');
  late String _icon = _e?.icon ?? 'gift';
  late bool _active = _e?.active ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _write(List<ShopItem> shop, String done) async {
    setState(() => _saving = true);
    try {
      await ref.read(rewardsRepositoryProvider).saveSettings(widget.classId, widget.settings.copyWith(shop: shop));
      if (!mounted) return;
      Navigator.pop(context);
      showToast(done);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast('Couldn’t save: $e');
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final cost = int.tryParse(_cost.text.trim()) ?? 0;
    if (name.isEmpty || cost <= 0) return;
    final e = _e;
    if (e == null) {
      final item = ShopItem(
        id: 'item-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        cost: cost,
        icon: _icon,
        active: _active,
      );
      await _write([...widget.settings.shop, item], 'Reward added: $name');
      return;
    }
    final updated = e.copyWith(name: name, cost: cost, icon: _icon, active: _active);
    await _write([for (final s in widget.settings.shop) s.id == e.id ? updated : s], 'Reward saved');
  }

  Future<void> _delete() async {
    final e = _e;
    if (e == null) return;
    final ok = await confirmAction(
      context,
      title: 'Delete reward?',
      message: 'Students won’t be able to redeem “${e.name}” anymore.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await _write(widget.settings.shop.where((s) => s.id != e.id).toList(), 'Reward deleted');
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return AppDialog(
      maxWidth: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(title: e == null ? 'Add reward' : 'Edit reward', subtitle: 'Something students can spend points on'),
          const SizedBox(height: 16),
          const FieldLabel('Reward'),
          TextField(controller: _name, maxLength: 60, decoration: const InputDecoration(hintText: 'e.g. Line leader for a day')),
          const FieldLabel('Cost in points'),
          SizedBox(
            width: 160,
            child: TextField(
              controller: _cost,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              decoration: const InputDecoration(suffixText: 'pts'),
            ),
          ),
          const SizedBox(height: 14),
          const FieldLabel('Icon'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in RewardIcons.shopKeys)
                _PickCircle(
                  selected: _icon == k,
                  tone: Tone.green,
                  onTap: () => setState(() => _icon = k),
                  child: Icon(RewardIcons.icon(k), size: 20, color: AppColors.primary),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SwitchRow(
            label: 'Students can redeem this',
            hint: 'Turn off to hide it without deleting it.',
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (e != null)
                TextButton(
                  onPressed: _saving ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: AppColors.red),
                  child: const Text('Delete'),
                ),
              const Spacer(),
              OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 10),
              FilledButton(onPressed: _saving ? null : _save, child: Text(e == null ? 'Add reward' : 'Save')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Points per rule and points per level.
Future<void> showPointRulesDialog(
  BuildContext context, {
  required String classId,
  required RewardSettings settings,
}) =>
    showDialog<void>(context: context, builder: (_) => _RulesDialog(classId: classId, settings: settings));

class _RulesDialog extends ConsumerStatefulWidget {
  const _RulesDialog({required this.classId, required this.settings});

  final String classId;
  final RewardSettings settings;

  @override
  ConsumerState<_RulesDialog> createState() => _RulesDialogState();
}

class _RulesDialogState extends ConsumerState<_RulesDialog> {
  late final Map<PointRule, TextEditingController> _fields = {
    for (final r in PointRule.values) r: TextEditingController(text: '${widget.settings.pointsFor(r)}'),
  };
  late final _level = TextEditingController(text: '${widget.settings.levelSize}');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    _level.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final points = {for (final e in _fields.entries) e.key: (int.tryParse(e.value.text.trim()) ?? 0).clamp(0, 500).toInt()};
    final level = (int.tryParse(_level.text.trim()) ?? 200).clamp(50, 5000).toInt();
    setState(() => _saving = true);
    try {
      await ref
          .read(rewardsRepositoryProvider)
          .saveSettings(widget.classId, widget.settings.copyWith(points: points, levelSize: level));
      if (!mounted) return;
      Navigator.pop(context);
      showToast('Point rules saved');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast('Couldn’t save: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget numberField(TextEditingController c, String suffix) => SizedBox(
          width: 110,
          child: TextField(
            controller: c,
            textAlign: TextAlign.right,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            decoration: InputDecoration(suffixText: suffix),
          ),
        );
    return AppDialog(
      maxWidth: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader(title: 'How students earn points', subtitle: 'Points are added automatically'),
          const SizedBox(height: 14),
          for (final r in PointRule.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w600))),
                  numberField(_fields[r]!, 'pts'),
                ],
              ),
            ),
          const Divider(height: 24),
          Row(
            children: [
              const Expanded(child: Text('Points per level', style: TextStyle(fontWeight: FontWeight.w600))),
              numberField(_level, 'pts'),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: _saving ? null : _save, child: const Text('Save rules'))),
            ],
          ),
        ],
      ),
    );
  }
}
