import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/core_providers.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/settings_providers.dart';
import '../shell/top_bar.dart';
import 'settings_dialogs.dart';

enum SettingsSection {
  profile('Profile', Icons.person_outline_rounded),
  notifications('Notifications', Icons.notifications_none_rounded),
  classwork('Classwork defaults', Icons.description_outlined),
  grading('Grading', Icons.table_chart_outlined),
  region('Calendar and region', Icons.public_rounded),
  security('Account and security', Icons.lock_outline_rounded);

  const SettingsSection(this.label, this.icon);
  final String label;
  final IconData icon;

  static SettingsSection? parse(String? v) {
    for (final s in values) {
      if (s.name == v) return s;
    }
    return null;
  }
}

/// `/settings?section=` — profile, notifications and the defaults other
/// pages use.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.section});

  final SettingsSection? section;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _keys = {for (final s in SettingsSection.values) s: GlobalKey()};
  SettingsSection _current = SettingsSection.profile;

  // Profile form
  final _name = TextEditingController();
  final _title = TextEditingController();
  final _subject = TextEditingController();
  final _bio = TextEditingController();
  Set<int> _grades = {};
  bool _profileLoaded = false;
  bool _profileDirty = false;

  // Preferences: null = no unsaved changes.
  TeacherPreferences? _draft;
  final _activity = TextEditingController();
  final _boss = TextEditingController();
  final _passing = TextEditingController();
  bool _prefsLoaded = false;

  bool _saving = false;
  bool _justSaved = false;
  bool _initDone = false;

  /// setState once built; during initState just run it.
  void _apply(VoidCallback f) {
    if (_initDone && mounted) {
      setState(f);
    } else {
      f();
    }
  }

  @override
  void initState() {
    super.initState();
    // Fill the forms once the profile and preferences arrive (not during
    // build: changing a controller there would rebuild mid-build).
    ref.listenManual<AsyncValue<Teacher?>>(teacherProvider, (_, next) {
      final t = next.valueOrNull;
      if (t != null && !_profileLoaded) _apply(() => _loadProfile(t));
    }, fireImmediately: true);
    ref.listenManual<AsyncValue<TeacherPreferences>>(teacherPreferencesProvider, (_, next) {
      final p = next.valueOrNull;
      if (p != null && !_prefsLoaded) _apply(() => _loadPrefs(p));
    }, fireImmediately: true);
    _initDone = true;
    final s = widget.section;
    if (s != null) {
      _current = s;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(s));
    }
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final s = widget.section;
    if (s != null && s != oldWidget.section) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(s));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _title, _subject, _bio, _activity, _boss, _passing]) {
      c.dispose();
    }
    super.dispose();
  }

  void _scrollTo(SettingsSection s) {
    setState(() => _current = s);
    final ctx = _keys[s]!.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.02);
    }
  }

  bool get _dirty => _profileDirty || _draft != null;

  void _loadProfile(Teacher t, {bool force = false}) {
    if (_profileLoaded && !force) return;
    _profileLoaded = true;
    _name.text = t.displayName;
    _title.text = t.titleName.isEmpty ? t.title : t.titleName;
    _subject.text = t.subject.isEmpty ? 'Araling Panlipunan' : t.subject;
    _bio.text = t.bio;
    _grades = {...t.gradeLevels};
    _profileDirty = false;
  }

  void _loadPrefs(TeacherPreferences p, {bool force = false}) {
    if (_prefsLoaded && !force) return;
    _prefsLoaded = true;
    _activity.text = '${p.activityPoints}';
    _boss.text = '${p.bossPoints}';
    _passing.text = '${p.passingGrade}';
    _draft = null;
  }

  void _touchProfile() => setState(() {
        _profileDirty = true;
        _justSaved = false;
      });

  void _change(TeacherPreferences base, TeacherPreferences Function(TeacherPreferences) edit) => setState(() {
        final next = edit(_draft ?? base);
        _draft = next == base ? null : next;
        _justSaved = false;
      });

  void _discard(Teacher? t, TeacherPreferences p) {
    setState(() {
      if (t != null) _loadProfile(t, force: true);
      _loadPrefs(p, force: true);
      _justSaved = false;
    });
  }

  Future<void> _save() async {
    final repo = ref.read(settingsRepositoryProvider);
    final name = _name.text.trim();
    if (_profileDirty && name.isEmpty) {
      showToast('Please enter your full name.');
      _scrollTo(SettingsSection.profile);
      return;
    }
    setState(() => _saving = true);
    try {
      if (_profileDirty) {
        await repo.saveProfile(
          displayName: name,
          titleName: _title.text,
          subject: _subject.text,
          gradeLevels: _grades.toList(),
          bio: _bio.text,
        );
      }
      final draft = _draft;
      if (draft != null) await repo.savePreferences(draft);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _profileDirty = false;
        _draft = null;
        _justSaved = true;
      });
      showToast('Settings saved');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast('Couldn’t save settings: $e');
    }
  }

  Future<void> _uploadPhoto() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png'], withData: true);
    final file = result?.files.single;
    if (file?.bytes == null) return;
    if (file!.size > 2 * 1024 * 1024) {
      showToast('Choose a photo under 2 MB.');
      return;
    }
    showToast('Uploading photo…');
    try {
      await ref.read(settingsRepositoryProvider).uploadPhoto(bytes: file.bytes!, fileName: file.name);
      showToast('Profile photo updated');
    } catch (e) {
      showToast('Couldn’t upload the photo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacher = ref.watch(teacherProvider).valueOrNull;
    final prefsValue = ref.watch(teacherPreferencesProvider);
    final school = ref.watch(schoolSettingsProvider).valueOrNull;
    final saved = prefsValue.valueOrNull;
    final base = saved ?? const TeacherPreferences();
    final p = _draft ?? base;

    final status = _saving
        ? 'Saving…'
        : _dirty
            ? 'You have unsaved changes'
            : _justSaved
                ? 'All changes saved'
                : null;

    return PageScaffold(
      header: PageHeader(
        icon: Icons.wb_sunny_rounded,
        title: 'Settings',
        subtitle: 'Manage your profile, notifications, and classroom preferences.',
        actions: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (status != null)
              Text(status,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _dirty ? const Color(0xFF8A5700) : AppColors.primary)),
            OutlinedButton(onPressed: _dirty && !_saving ? () => _discard(teacher, base) : null, child: const Text('Discard')),
            FilledButton(onPressed: _dirty && !_saving ? _save : null, child: const Text('Save changes')),
          ],
        ),
      ),
      children: [
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 920;
          final sections = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section(SettingsSection.profile, _profile(teacher, school)),
              _section(SettingsSection.notifications, _notifications(base, p)),
              _section(SettingsSection.classwork, _classwork(context, base, p)),
              _section(SettingsSection.grading, _grading(base, p)),
              _section(SettingsSection.region, _region(base, p, school)),
              _section(SettingsSection.security, const SecuritySection(), last: true),
            ],
          );
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in SettingsSection.values)
                      ChoiceChip(
                        avatar: Icon(s.icon, size: 16),
                        label: Text(s.label),
                        selected: s == _current,
                        onSelected: (_) => _scrollTo(s),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                sections,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 240, child: _nav()),
              const SizedBox(width: 20),
              Expanded(child: sections),
            ],
          );
        }),
      ],
    );
  }

  Widget _nav() => Container(
        decoration: AppDecorations.card,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final s in SettingsSection.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Material(
                  color: s == _current ? AppColors.primarySoft.withValues(alpha: 0.7) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => _scrollTo(s),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          Icon(s.icon, size: 19, color: s == _current ? AppColors.primary : AppColors.inkSoft),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.label,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: s == _current ? FontWeight.w700 : FontWeight.w600,
                                color: s == _current ? AppColors.primaryDeep : AppColors.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _section(SettingsSection s, Widget child, {bool last = false}) => Padding(
        key: _keys[s],
        padding: EdgeInsets.only(bottom: last ? 0 : 20),
        child: child,
      );

  Widget _card({required String title, String? subtitle, Widget? trailing, required List<Widget> children}) => Container(
        decoration: AppDecorations.card,
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.sectionTitle.copyWith(fontSize: 17)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(subtitle, style: AppText.meta),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );

  Widget _field(String label, Widget input, {String? hint}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel(label),
          input,
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint, style: AppText.meta.copyWith(fontSize: 12)),
          ],
        ],
      );

  Widget _grid(List<Widget> children, {double min = 260}) => LayoutBuilder(builder: (context, c) {
        final cols = (c.maxWidth / min).floor().clamp(1, 2);
        final w = (c.maxWidth - 16 * (cols - 1)) / cols;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [for (final child in children) SizedBox(width: w, child: child)],
        );
      });

  // ------------------------------------------------------------ Profile

  Widget _profile(Teacher? t, SchoolSettings? school) {
    return _card(
      title: 'Profile',
      subtitle: 'Students see your name, photo and welcome message in the EduLearn app.',
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TeacherAvatar(teacher: t, size: 76),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _uploadPhoto,
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: Text(t?.photoUrl == null ? 'Upload photo' : 'Change photo'),
                    ),
                    if (t?.photoUrl != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          try {
                            await ref.read(settingsRepositoryProvider).removePhoto();
                            showToast('Photo removed');
                          } catch (e) {
                            showToast('Couldn’t remove the photo: $e');
                          }
                        },
                        style: TextButton.styleFrom(foregroundColor: AppColors.red),
                        child: const Text('Remove'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text('JPG or PNG, up to 2 MB', style: AppText.meta.copyWith(fontSize: 12)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        _grid([
          _field(
            'Full name',
            TextField(controller: _name, onChanged: (_) => _touchProfile(), maxLength: 80, decoration: const InputDecoration(counterText: '')),
            hint: 'Used on reports and exports',
          ),
          _field(
            'What students call you',
            TextField(
              controller: _title,
              onChanged: (_) => _touchProfile(),
              maxLength: 40,
              decoration: const InputDecoration(hintText: 'Teacher Jean', counterText: ''),
            ),
            hint: 'Shown on the Stream and in Messages',
          ),
          _field(
            'School',
            TextFormField(
              key: ValueKey('school_${school?.schoolName}'),
              initialValue: school?.schoolName ?? '',
              enabled: false,
              decoration: const InputDecoration(suffixIcon: Icon(Icons.lock_outline_rounded, size: 18)),
            ),
            hint: 'Set by your school admin',
          ),
          _field(
            'Subject',
            TextField(controller: _subject, onChanged: (_) => _touchProfile(), maxLength: 60, decoration: const InputDecoration(counterText: '')),
          ),
        ]),
        const SizedBox(height: 16),
        const FieldLabel('Grade levels you teach'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var g = 1; g <= 6; g++)
              FilterChip(
                label: Text('Grade $g'),
                selected: _grades.contains(g),
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _grades.add(g);
                    } else {
                      _grades.remove(g);
                    }
                  });
                  _touchProfile();
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        _field(
          'Welcome message for students',
          TextField(
            controller: _bio,
            minLines: 3,
            maxLines: 5,
            maxLength: 200,
            onChanged: (_) => _touchProfile(),
            decoration: const InputDecoration(hintText: 'Magandang araw! Ako si Teacher Jean…'),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------- Notifications

  Widget _notifications(TeacherPreferences base, TeacherPreferences p) {
    Widget head(String text) => SizedBox(
          width: 76,
          child: Text(text, textAlign: TextAlign.center, style: AppText.label.copyWith(fontSize: 12.5)),
        );
    return _card(
      title: 'Notifications',
      subtitle: 'Choose what shows under the bell, and what is sent to your email.',
      children: [
        Row(children: [
          Expanded(child: Text('Notify me about', style: AppText.label.copyWith(fontSize: 12.5))),
          head('Website'),
          head('Email'),
        ]),
        const SizedBox(height: 6),
        const Divider(),
        for (final t in NotifyTopic.values) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      Text(t.hint, style: AppText.meta.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 76,
                  child: Switch(
                    value: p.choiceFor(t).web,
                    onChanged: (v) => _change(base, (x) => x.withChoice(t, x.choiceFor(t).copyWith(web: v))),
                  ),
                ),
                SizedBox(
                  width: 76,
                  child: Switch(
                    value: p.choiceFor(t).email,
                    onChanged: (v) => _change(base, (x) => x.withChoice(t, x.choiceFor(t).copyWith(email: v))),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Emails start once your school admin connects an email service. Your choices are saved now.',
                style: AppText.meta.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------ Classwork

  Widget _classwork(BuildContext context, TeacherPreferences base, TeacherPreferences p) {
    Widget number(TextEditingController c, void Function(int) set) => TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          decoration: const InputDecoration(suffixText: 'pts'),
          onChanged: (v) => set(int.tryParse(v) ?? 0),
        );
    final due = TimeOfDay(hour: p.dueHour, minute: p.dueMinute);
    return _card(
      title: 'Classwork defaults',
      subtitle: 'Filled in for you when you create classwork. You can still change them each time.',
      children: [
        _grid([
          _field('Activity points', number(_activity, (v) => _change(base, (x) => x.copyWith(activityPoints: v)))),
          _field('Friday Boss points', number(_boss, (v) => _change(base, (x) => x.copyWith(bossPoints: v)))),
          _field(
            'Due time',
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showTimePicker(context: context, initialTime: due);
                if (picked != null && mounted) {
                  _change(base, (x) => x.copyWith(dueHour: picked.hour, dueMinute: picked.minute));
                }
              },
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), alignment: Alignment.centerLeft),
              icon: const Icon(Icons.schedule_rounded, size: 18),
              label: Text(due.format(context)),
            ),
          ),
        ], min: 200),
        const SizedBox(height: 8),
        Text('New quests and quizzes start at each class’s Total points (Stream › Class settings).',
            style: AppText.meta.copyWith(fontSize: 12)),
        const SizedBox(height: 10),
        const Divider(),
        SwitchRow(
          label: 'Accept late submissions',
          hint: 'Students can still turn in work after the due time. It is marked Late.',
          value: p.allowLate,
          onChanged: (v) => _change(base, (x) => x.copyWith(allowLate: v)),
        ),
        const Divider(),
        SwitchRow(
          label: 'Tell students when a grade is returned',
          hint: '“Notify student” starts switched on when you return work.',
          value: p.notifyOnGrade,
          onChanged: (v) => _change(base, (x) => x.copyWith(notifyOnGrade: v)),
        ),
        const Divider(),
        SwitchRow(
          label: 'Post new classwork to the Stream',
          hint: 'Adds a short post so students see it right away.',
          value: p.postToStream,
          onChanged: (v) => _change(base, (x) => x.copyWith(postToStream: v)),
        ),
        const Divider(),
        SwitchRow(
          label: 'Show the class leaderboard to students',
          hint: 'Students always see their own points and badges.',
          value: p.showLeaderboard,
          onChanged: (v) => _change(base, (x) => x.copyWith(showLeaderboard: v)),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- Grading

  Widget _grading(TeacherPreferences base, TeacherPreferences p) {
    final scale = GradeLevel.defaults;
    return _card(
      title: 'Grading',
      subtitle: 'Defaults for a class until you save its own Gradebook settings.',
      trailing: LinkButton(label: 'Gradebook settings', onTap: () => goTo(Routes.gradebook())),
      children: [
        const FieldLabel('Overall grade'),
        Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedPills<GradeCalculation>(
              value: p.calculation,
              options: GradeCalculation.values,
              labelOf: (c) => c.label,
              onChanged: (c) => _change(base, (x) => x.copyWith(calculation: c)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(p.calculation.hint, style: AppText.meta.copyWith(fontSize: 12)),
        const SizedBox(height: 16),
        _field(
          'Passing grade',
          SizedBox(
            width: 140,
            child: TextField(
              controller: _passing,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              decoration: const InputDecoration(suffixText: '%'),
              onChanged: (v) => _change(base, (x) => x.copyWith(passingGrade: (int.tryParse(v) ?? 0).clamp(0, 100).toInt())),
            ),
          ),
          hint: 'Analytics and the Gradebook mark students below this.',
        ),
        const SizedBox(height: 16),
        const FieldLabel('Grading scale'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in scale)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(g.color).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${g.letter}  ', style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(
                    text: g.min == 0 ? 'Below ${g.max + 1}' : '${g.min}–${g.max}',
                    style: const TextStyle(color: AppColors.inkSoft),
                  ),
                ]), style: const TextStyle(fontSize: 13)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Change the scale for a class in Gradebook › Grade settings › Edit scale.',
            style: AppText.meta.copyWith(fontSize: 12)),
      ],
    );
  }

  // --------------------------------------------------------------- Region

  Widget _region(TeacherPreferences base, TeacherPreferences p, SchoolSettings? school) {
    final year = school?.schoolYear ?? '';
    return _card(
      title: 'Calendar and region',
      subtitle: 'How dates and weeks appear on the Calendar and Attendance pages.',
      children: [
        _grid([
          _field(
            'Calendar week starts on',
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedPills<bool>(
                value: p.weekStartsMonday,
                options: const [false, true],
                labelOf: (m) => m ? 'Monday' : 'Sunday',
                onChanged: (m) => _change(base, (x) => x.copyWith(weekStartsMonday: m)),
              ),
            ),
          ),
          _field(
            'Time zone',
            TextFormField(
              initialValue: 'Asia/Manila (UTC+08:00)',
              enabled: false,
              decoration: const InputDecoration(suffixIcon: Icon(Icons.lock_outline_rounded, size: 18)),
            ),
            hint: 'All due dates use Philippine time.',
          ),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.event_note_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${year.isEmpty ? 'The school year' : 'School year $year'} starts in June. '
                  'Quarter 1 is June to August, Quarter 2 September to November, Quarter 3 December to February, '
                  'Quarter 4 March to May. Set by your school admin.',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Email, password and signing out.
class SecuritySection extends ConsumerWidget {
  const SecuritySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    Widget row({required String title, required String subtitle, required Widget trailing}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppText.meta.copyWith(fontSize: 12.5)),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        );
    return Container(
      decoration: AppDecorations.card,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Account and security', style: AppText.sectionTitle.copyWith(fontSize: 17)),
          const SizedBox(height: 8),
          row(
            title: 'Email',
            subtitle: '${user?.email ?? '—'} · managed by your school admin',
            trailing: Pill(
              user?.emailVerified == true ? 'Verified' : 'Signed in',
              tone: user?.emailVerified == true ? Tone.green : Tone.blue,
            ),
          ),
          const Divider(),
          row(
            title: 'Password',
            subtitle: 'Use at least 8 characters. You’ll stay signed in on this device.',
            trailing: OutlinedButton(onPressed: () => showChangePasswordDialog(context), child: const Text('Change password')),
          ),
          const Divider(),
          row(
            title: 'Sign out',
            subtitle: 'Sign out of EduLearn on this browser.',
            trailing: OutlinedButton(
              onPressed: () async {
                ref.read(selectedClassIdProvider.notifier).state = null;
                await ref.read(authRepositoryProvider).signOut();
              },
              child: const Text('Sign out'),
            ),
          ),
          const Divider(),
          row(
            title: 'Sign out of all devices',
            subtitle: 'Lost a phone or used a shared computer? This ends every session, including this one.',
            trailing: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                side: const BorderSide(color: AppColors.red),
              ),
              onPressed: () async {
                final ok = await confirmAction(
                  context,
                  title: 'Sign out everywhere?',
                  message: 'You’ll need to sign in again on every device, including this one.',
                  confirmLabel: 'Sign out everywhere',
                  destructive: true,
                );
                if (!ok) return;
                try {
                  await ref.read(settingsRepositoryProvider).signOutEverywhere();
                } catch (e) {
                  showToast('Couldn’t sign out everywhere: $e');
                }
              },
              child: const Text('Sign out of all devices'),
            ),
          ),
        ],
      ),
    );
  }
}
