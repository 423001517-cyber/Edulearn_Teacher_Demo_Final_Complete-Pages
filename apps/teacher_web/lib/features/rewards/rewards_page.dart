import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/rewards_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/stream_providers.dart';
import '../shell/top_bar.dart';
import '../stream/stream_page.dart' show PageClassSelector;
import '../students/student_support_panel.dart';
import 'rewards_dialogs.dart';

/// `/rewards?classId=` — points, badges, levels and the reward shop.
class RewardsPage extends ConsumerWidget {
  const RewardsPage({super.key, this.classId});

  final String? classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<ClassRoom?>(
      value: ref.watch(streamClassProvider(classId)),
      data: (c) {
        if (c == null) {
          return const PageScaffold(
            header: PageHeader(icon: Icons.wb_sunny_rounded, title: 'Rewards'),
            children: [EmptyNote('No classes yet — rewards open once a class is assigned to you.')],
          );
        }
        return PageScaffold(
          header: PageHeader(
            icon: Icons.wb_sunny_rounded,
            title: 'Rewards',
            subtitle: 'Motivate learners with points, badges, and class rewards.',
            actions: PageClassSelector(current: c, onChanged: (x) => goTo(Routes.rewards(classId: x.id))),
          ),
          children: [_Board(key: ValueKey(c.id), classRoom: c)],
        );
      },
    );
  }
}

class _Board extends ConsumerStatefulWidget {
  const _Board({super.key, required this.classRoom});

  final ClassRoom classRoom;

  @override
  ConsumerState<_Board> createState() => _BoardState();
}

class _BoardState extends ConsumerState<_Board> {
  LeaderboardPeriod _period = LeaderboardPeriod.week;
  bool _showAll = false;

  ClassRoom get _class => widget.classRoom;

  @override
  Widget build(BuildContext context) {
    final settingsValue = ref.watch(rewardSettingsProvider(_class.id));
    final weekValue = ref.watch(classRewardsProvider((_class.id, LeaderboardPeriod.week)));
    final boardValue = ref.watch(classRewardsProvider((_class.id, _period)));
    final requests = ref.watch(rewardRequestsProvider(_class.id)).valueOrNull ?? const <RewardRequest>[];
    final roster = ref.watch(classStudentsProvider(_class.id)).valueOrNull ?? const <Student>[];
    final prefs = ref.watch(preferencesProvider);

    return AsyncValueView<RewardSettings>(
      value: settingsValue,
      loadingHeight: 320,
      data: (settings) {
        final week = weekValue.valueOrNull ?? const <StudentRewards>[];
        final approved = requests.where((r) => r.status == RewardStatus.approved).length;
        final pending = requests.where((r) => r.status == RewardStatus.pending).toList();
        final counts = badgeCounts(week);
        final badgeTotal = counts.values.fold<int>(0, (a, b) => a + b);
        final withBadge = week.where((r) => r.badges.isNotEmpty).length;
        StudentRewards? leader;
        for (final r in week) {
          if (leader == null || r.streak > leader.streak) leader = r;
        }
        final best = leader;
        final weekPoints = week.fold<int>(0, (a, r) => a + r.earnedInPeriod);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: roster.isEmpty
                          ? null
                          : () => showGivePointsDialog(context, classRoom: _class, roster: roster, settings: settings),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Give points'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => showBadgeDialog(context, classId: _class.id, settings: settings),
                      icon: const Icon(Icons.star_outline_rounded, size: 18, color: AppColors.amber),
                      label: const Text('Create badge'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => showShopItemDialog(context, classId: _class.id, settings: settings),
                      icon: const Icon(Icons.redeem_rounded, size: 18),
                      label: const Text('Add reward'),
                    ),
                  ],
                ),
                Text(
                  prefs.showLeaderboard
                      ? 'Students see their points, badges and the class leaderboard in the EduLearn app.'
                      : 'Students see their own points and badges. The leaderboard is hidden (Settings).',
                  style: AppText.meta,
                ),
              ],
            ),
            const SizedBox(height: 20),
            ResponsiveGrid(
              maxColumns: 4,
              children: [
                StatCard(
                  icon: Icons.star_rounded,
                  tone: Tone.green,
                  label: 'Points earned this week',
                  value: weekValue.whenData((_) => _fmt(weekPoints)),
                  caption: 'Across ${week.length} students',
                ),
                StatCard(
                  icon: Icons.military_tech_rounded,
                  tone: Tone.purple,
                  label: 'Badges earned',
                  value: weekValue.whenData((_) => '$badgeTotal'),
                  caption: '$withBadge ${withBadge == 1 ? 'student has' : 'students have'} at least one',
                ),
                StatCard(
                  icon: Icons.redeem_rounded,
                  tone: Tone.amber,
                  label: 'Rewards redeemed',
                  value: AsyncData('$approved'),
                  caption: pending.isEmpty ? 'Nothing waiting for approval' : '${pending.length} waiting for your approval',
                  captionColor: pending.isEmpty ? null : const Color(0xFF8A5700),
                ),
                StatCard(
                  icon: Icons.local_fire_department_rounded,
                  tone: Tone.red,
                  label: 'Best on-time streak',
                  value: weekValue.whenData((_) => best == null || best.streak == 0 ? '—' : '${best.streak} in a row'),
                  caption: best == null || best.streak == 0 ? 'No streaks yet' : best.student.name,
                ),
              ],
            ),
            const SizedBox(height: 20),
            TwoColumn(
              leftFlex: 3,
              rightFlex: 2,
              left: [_leaderboard(boardValue, settings, roster)],
              right: [
                _ApprovalsCard(requests: pending, rewards: week),
                _ShopCard(classId: _class.id, settings: settings, requests: requests),
              ],
            ),
            const SizedBox(height: 20),
            TwoColumn(
              leftFlex: 3,
              rightFlex: 2,
              left: [_BadgesCard(classId: _class.id, settings: settings, counts: counts)],
              right: [_RulesCard(classId: _class.id, settings: settings)],
            ),
          ],
        );
      },
    );
  }

  Widget _leaderboard(AsyncValue<List<StudentRewards>> value, RewardSettings settings, List<Student> roster) {
    return SectionCard(
      title: 'Class leaderboard',
      icon: Icons.emoji_events_outlined,
      trailing: SegmentedPills<LeaderboardPeriod>(
        value: _period,
        options: LeaderboardPeriod.values,
        labelOf: (p) => p.label,
        height: 32,
        onChanged: (p) => setState(() => _period = p),
      ),
      child: AsyncValueView<List<StudentRewards>>(
        value: value,
        loadingHeight: 280,
        data: (rows) {
          if (rows.isEmpty) return const EmptyNote('No students in this class yet.', icon: Icons.groups_outlined);
          final ranked = leaderboard(rows, byPeriod: _period != LeaderboardPeriod.all);
          final shown = _showAll ? ranked : ranked.take(8).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              Text('${_class.name} · ${rows.length} students · ranked by points ${_period == LeaderboardPeriod.all ? 'earned so far' : 'earned ${_period.label.toLowerCase()}'}',
                  style: AppText.meta),
              const SizedBox(height: 6),
              for (var i = 0; i < shown.length; i++)
                _LeaderRow(
                  rank: i + 1,
                  row: shown[i],
                  points: _period == LeaderboardPeriod.all ? shown[i].earned : shown[i].earnedInPeriod,
                  onGive: () => showGivePointsDialog(
                    context,
                    classRoom: _class,
                    roster: roster,
                    settings: settings,
                    preselected: shown[i].student,
                  ),
                ),
              if (ranked.length > 8) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('Showing ${shown.length} of ${ranked.length}', style: AppText.meta)),
                    LinkButton(
                      label: _showAll ? 'Show top 8' : 'View full leaderboard',
                      showArrow: !_showAll,
                      onTap: () => setState(() => _showAll = !_showAll),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

String _fmt(int n) {
  final s = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.rank, required this.row, required this.points, required this.onGive});

  final int rank;
  final StudentRewards row;
  final int points;
  final VoidCallback onGive;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (rank) {
      1 => (const Color(0xFFFFCE42), const Color(0xFF5C3D00)),
      2 => (const Color(0xFFDCE1EA), const Color(0xFF2E3640)),
      3 => (const Color(0xFFF0C29A), const Color(0xFF5A3112)),
      _ => (AppColors.chip, AppColors.inkSoft),
    };
    final s = row.student;
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 520;
        final level = Row(
          children: [
            Text('Level ${row.level}', style: AppText.meta.copyWith(fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(child: ProgressBar(value: row.levelProgress, height: 7)),
            const SizedBox(width: 8),
            Text('${row.toNextLevel} to go', style: AppText.meta.copyWith(fontSize: 11.5)),
          ],
        );
        return Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Text('$rank', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: fg)),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () => showStudentPanel(context, s),
              customBorder: const CircleBorder(),
              child: InitialsAvatar(initials: s.initials, tone: toneForName(s.name), size: 38, imageUrl: s.photoUrl),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  SizedBox(width: wide ? 260 : double.infinity, child: level),
                ],
              ),
            ),
            if (wide) ...[
              const SizedBox(width: 10),
              Tooltip(
                message: row.badges.isEmpty ? 'No badges yet' : row.badges.map((b) => b.name).join(', '),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.military_tech_rounded, size: 18, color: AppColors.purple),
                    const SizedBox(width: 4),
                    Text('${row.badges.length}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ],
            const SizedBox(width: 14),
            SizedBox(
              width: 72,
              child: Text('${_fmt(points)} pts',
                  textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Give points to ${s.firstName}',
              onPressed: onGive,
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
            ),
          ],
        );
      }),
    );
  }
}

class _ApprovalsCard extends ConsumerWidget {
  const _ApprovalsCard({required this.requests, required this.rewards});

  final List<RewardRequest> requests;
  final List<StudentRewards> rewards;

  Future<void> _decide(BuildContext context, WidgetRef ref, RewardRequest r, bool approve) async {
    final repo = ref.read(rewardsRepositoryProvider);
    if (approve) {
      int? balance;
      for (final x in rewards) {
        if (x.student.id == r.studentId) balance = x.balance;
      }
      if (balance != null && balance < r.cost) {
        final ok = await confirmAction(
          context,
          title: 'Not enough points',
          message: '${r.studentName} has $balance points but ${r.itemName} costs ${r.cost}. Approve anyway?',
          confirmLabel: 'Approve anyway',
        );
        if (!ok) return;
      }
    }
    try {
      await repo.decide(r, approve: approve);
      showToast(approve
          ? 'Approved: ${r.itemName} for ${r.studentName}. ${r.cost} points were used.'
          : 'Declined: ${r.itemName}. ${r.studentName} keeps their points.');
    } catch (e) {
      showToast('Couldn’t update the request: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Waiting for approval',
      icon: Icons.hourglass_top_rounded,
      trailing: requests.isEmpty ? null : Pill('${requests.length} new', tone: Tone.amber),
      child: requests.isEmpty
          ? const EmptyNote('All caught up. New reward requests show here.', icon: Icons.check_circle_outline_rounded)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < requests.length; i++) ...[
                  if (i > 0) const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InitialsAvatar(
                              initials: initialsOf(requests[i].studentName),
                              tone: toneForName(requests[i].studentName),
                              size: 36,
                            ),
                            const SizedBox(width: 10),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(requests[i].studentName,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  Text('${requests[i].itemName} · ${requests[i].cost} pts',
                                      style: AppText.meta.copyWith(fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: () => _decide(context, ref, requests[i], false),
                              child: const Text('Decline'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => _decide(context, ref, requests[i], true),
                              child: const Text('Approve'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ShopCard extends ConsumerWidget {
  const _ShopCard({required this.classId, required this.settings, required this.requests});

  final String classId;
  final RewardSettings settings;
  final List<RewardRequest> requests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final redeemed = <String, int>{};
    for (final r in requests) {
      if (r.status == RewardStatus.approved) redeemed[r.itemId] = (redeemed[r.itemId] ?? 0) + 1;
    }
    return SectionCard(
      title: 'Reward shop',
      icon: Icons.storefront_outlined,
      actionLabel: 'Add',
      onAction: () => showShopItemDialog(context, classId: classId, settings: settings),
      child: settings.shop.isEmpty
          ? const EmptyNote('No rewards yet. Add privileges students can spend points on.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < settings.shop.length; i++) ...[
                  if (i > 0) const Divider(),
                  _ShopRow(
                    item: settings.shop[i],
                    redeemed: redeemed[settings.shop[i].id] ?? 0,
                    onEdit: () => showShopItemDialog(context, classId: classId, settings: settings, existing: settings.shop[i]),
                    onToggle: (v) async {
                      final shop = [
                        for (final s in settings.shop) s.id == settings.shop[i].id ? s.copyWith(active: v) : s,
                      ];
                      try {
                        await ref.read(rewardsRepositoryProvider).saveSettings(classId, settings.copyWith(shop: shop));
                      } catch (e) {
                        showToast('Couldn’t save: $e');
                      }
                    },
                  ),
                ],
              ],
            ),
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({required this.item, required this.redeemed, required this.onEdit, required this.onToggle});

  final ShopItem item;
  final int redeemed;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ToneIcon(RewardIcons.icon(item.icon), tone: item.active ? Tone.green : Tone.neutral, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  Text(
                    '${item.cost} pts · ${item.active ? (redeemed == 0 ? 'not redeemed yet' : 'redeemed $redeemed ${redeemed == 1 ? 'time' : 'times'}') : 'hidden from students'}',
                    style: AppText.meta.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: item.active ? 'Students can redeem this' : 'Hidden from students',
              child: Switch(value: item.active, onChanged: onToggle),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgesCard extends StatelessWidget {
  const _BadgesCard({required this.classId, required this.settings, required this.counts});

  final String classId;
  final RewardSettings settings;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Badges',
      icon: Icons.military_tech_outlined,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Awarded on their own when a student meets the rule. Tap a badge to edit it.', style: AppText.meta),
            const SizedBox(height: 12),
            ResponsiveGrid(
              minItemWidth: 165,
              maxColumns: 4,
              spacing: 12,
              children: [
                for (final b in settings.badges)
                  _BadgeTile(
                    badge: b,
                    count: counts[b.id] ?? 0,
                    onTap: () => showBadgeDialog(context, classId: classId, settings: settings, existing: b),
                  ),
                _NewBadgeTile(onTap: () => showBadgeDialog(context, classId: classId, settings: settings)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.count, required this.onTap});

  final BadgeDef badge;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = badge.enabled ? RewardIcons.tone(badge.tone) : Tone.neutral;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: SizedBox(
            height: 132,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: tone.bg,
                    shape: BoxShape.circle,
                    border: Border.all(color: tone.fg, width: 2),
                  ),
                  child: Icon(RewardIcons.icon(badge.icon), color: tone.fg, size: 22),
                ),
                const SizedBox(height: 8),
                Text(badge.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 2),
                Expanded(
                  child: Text(badge.ruleText,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.meta.copyWith(fontSize: 12, height: 1.35)),
                ),
                Text(
                  badge.enabled ? '$count ${count == 1 ? 'student' : 'students'}' : 'Turned off',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewBadgeTile extends StatelessWidget {
  const _NewBadgeTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFCFBF7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFB9C2BE), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: const SizedBox(
          height: 160,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: AppColors.primary),
              SizedBox(height: 6),
              Text('New badge', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.classId, required this.settings});

  final String classId;
  final RewardSettings settings;

  static IconData _icon(PointRule r) => switch (r) {
        PointRule.quest => Icons.emoji_events_rounded,
        PointRule.activity => Icons.auto_stories_rounded,
        PointRule.perfectQuiz => Icons.quiz_rounded,
        PointRule.bossPass => Icons.workspace_premium_rounded,
        PointRule.onTime => Icons.local_fire_department_rounded,
      };

  static Tone _tone(PointRule r) => switch (r) {
        PointRule.quest => Tone.green,
        PointRule.activity || PointRule.bossPass => Tone.amber,
        PointRule.perfectQuiz => Tone.purple,
        PointRule.onTime => Tone.red,
      };

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'How students earn points',
      icon: Icons.rule_rounded,
      actionLabel: 'Edit rules',
      onAction: () => showPointRulesDialog(context, classId: classId, settings: settings),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in PointRule.values) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  ToneIcon(_icon(r), tone: _tone(r), size: 34),
                  const SizedBox(width: 12),
                  Expanded(child: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
                  Text('+${settings.pointsFor(r)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                ],
              ),
            ),
            const Divider(),
          ],
          const SizedBox(height: 6),
          Text(
            'Every ${settings.levelSize} points is one level. Bonus points you give by hand count too, '
            'and points spent in the shop don’t lower a student’s level.',
            style: AppText.meta.copyWith(fontSize: 12.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}
