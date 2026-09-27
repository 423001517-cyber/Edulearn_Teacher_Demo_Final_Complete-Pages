import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme.dart';

/// White rounded card with an icon + title header and an optional link.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.showDivider = true,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 12),
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;
  final bool showDivider;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 22, color: AppColors.ink),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(title,
                      style: AppText.sectionTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (trailing != null)
                  trailing!
                else if (actionLabel != null)
                  LinkButton(label: actionLabel!, onTap: onAction),
              ],
            ),
          ),
          if (showDivider) const Padding(padding: EdgeInsets.only(top: 8), child: Divider()),
          child,
        ],
      ),
    );
  }
}

/// Blue "View all →" style link.
class LinkButton extends StatelessWidget {
  const LinkButton({super.key, required this.label, this.onTap, this.showArrow = true});

  final String label;
  final VoidCallback? onTap;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.link, fontWeight: FontWeight.w600, fontSize: 13)),
            if (showArrow) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.link),
            ],
          ],
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.tone, this.icon, this.large = false, this.dot = false});

  final String label;
  final Tone tone;
  final IconData? icon;
  final bool large;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 16 : 11, vertical: large ? 8 : 5),
      decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
                width: 7, height: 7, decoration: BoxDecoration(color: tone.fg, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: large ? 16 : 14, color: tone.fg),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: tone.fg, fontWeight: FontWeight.w600, fontSize: large ? 13.5 : 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon on a soft tinted square (or circle).
class ToneIcon extends StatelessWidget {
  const ToneIcon(this.icon, {super.key, required this.tone, this.size = 40, this.circle = false});

  final IconData icon;
  final Tone tone;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone.bg,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.26),
      ),
      child: Icon(icon, color: tone.fg, size: size * 0.5),
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.initials,
    this.tone = Tone.blue,
    this.size = 40,
    this.imageUrl,
  });

  final String initials;
  final Tone tone;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: tone.bg,
        backgroundImage: NetworkImage(imageUrl!),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(color: tone.fg, fontWeight: FontWeight.w800, fontSize: size * 0.34),
      ),
    );
  }
}

/// Stable avatar color for a name.
Tone toneForName(String name) {
  const tones = [Tone.blue, Tone.green, Tone.red, Tone.amber];
  var h = 0;
  for (final c in name.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return tones[h % tones.length];
}

/// Rounded progress bar (drawn by hand so it looks the same on every
/// Flutter version).
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.color = AppColors.primary, this.height = 9});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.track),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0).toDouble(),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

String percent(double? v) => v == null ? '—' : '${(v * 100).round()}%';

/// "+12% from last quarter" / "−6 from last quarter".
String deltaLabel(double? delta, String comparison, {bool asPercent = true}) {
  if (delta == null) return 'No earlier data';
  final n = asPercent ? (delta * 100).round() : delta.round();
  final sign = n > 0 ? '+' : (n < 0 ? '−' : '±');
  return '$sign${n.abs()}${asPercent ? '%' : ''} $comparison';
}

/// Green when the change is good, red when it's bad.
Color deltaColor(double? delta, {bool lowerIsBetter = false}) {
  if (delta == null || delta == 0) return AppColors.muted;
  final good = lowerIsBetter ? delta < 0 : delta > 0;
  return good ? AppColors.primary : AppColors.red;
}

/// The icon + number cards used on Dashboard, Classes, Class and Reports pages.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.tone,
    required this.label,
    required this.value,
    required this.caption,
    this.captionColor,
    this.watermark,
    this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final Tone tone;
  final String label;
  final AsyncValue<String> value;
  final String caption;
  final Color? captionColor;
  final IconData? watermark;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 230;
      final circle = compact ? 44.0 : 58.0;
      return Container(
        decoration: AppDecorations.card.copyWith(
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.all(compact ? 14 : 18),
              child: Row(
                children: [
                  Container(
                    width: circle,
                    height: circle,
                    decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
                    child: Icon(icon, color: tone.fg, size: circle * 0.45),
                  ),
                  SizedBox(width: compact ? 10 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        value.when(
                          data: (v) => Text(v, style: AppText.statValue),
                          loading: () => const _ValueSkeleton(),
                          error: (e, st) => const Text('—', style: AppText.statValue),
                        ),
                        Text(caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.meta.copyWith(
                                color: captionColor ?? AppColors.muted,
                                fontWeight: captionColor != null ? FontWeight.w600 : null)),
                      ],
                    ),
                  ),
                  if (watermark != null && !compact)
                    Icon(watermark, size: 30, color: AppColors.muted.withValues(alpha: 0.3)),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _ValueSkeleton extends StatelessWidget {
  const _ValueSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        width: 48,
        height: 22,
        decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(6)),
      );
}

/// Lays out cards in N equal columns that wrap on narrow screens.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 220,
    this.maxColumns = 4,
    this.spacing = 16,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      var cols = (c.maxWidth / minItemWidth).floor().clamp(1, maxColumns);
      if (cols > children.length && children.isNotEmpty) cols = children.length;
      final w = ((c.maxWidth - spacing * (cols - 1)) / cols).floorToDouble();
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final child in children) SizedBox(width: w, child: child)],
      );
    });
  }
}

/// Loading / error / data switch for an [AsyncValue].
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({super.key, required this.value, required this.data, this.loadingHeight = 120});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final double loadingHeight;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => SizedBox(
        height: loadingHeight,
        child: const Center(
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
        ),
      ),
      error: (e, st) => ErrorNote(error: e),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.message, {super.key, this.actionLabel, this.onAction, this.icon});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 30, color: AppColors.muted.withValues(alpha: 0.6)),
            const SizedBox(height: 8),
          ],
          Text(message, textAlign: TextAlign.center, style: AppText.meta),
          if (actionLabel != null) ...[
            const SizedBox(height: 8),
            LinkButton(label: actionLabel!, onTap: onAction),
          ],
        ],
      ),
    );
  }
}

/// Shows the raw Firestore error so a missing-index link can be copied.
class ErrorNote extends StatelessWidget {
  const ErrorNote({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Couldn't load this section.",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 4),
                SelectableText('$error', style: AppText.meta.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The small grey ⋮ button used on list rows.
class MoreMenu<T> extends StatelessWidget {
  const MoreMenu({super.key, required this.items, required this.onSelected, this.tooltip = 'More actions'});

  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (_) => items,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.inkSoft),
      ),
    );
  }
}

PopupMenuItem<T> menuItem<T>(T value, IconData icon, String label, {bool destructive = false}) {
  final color = destructive ? AppColors.red : AppColors.ink;
  return PopupMenuItem<T>(
    value: value,
    height: 42,
    child: Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

/// Outlined dropdown chip ("All Grades ⌄", "This Week ⌄") backed by a
/// popup menu with a check next to the current choice.
class FilterDropdown<T> extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.icon,
    this.prefix = '',
    this.minWidth = 0,
  });

  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final IconData? icon;
  final String prefix;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: '',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      onSelected: (i) => onChanged(options[i]),
      itemBuilder: (_) => [
        for (var i = 0; i < options.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 44,
            child: _OptionRow(label: labelOf(options[i]), selected: options[i] == value),
          ),
      ],
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.buttonBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text('$prefix${labelOf(value)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.blueSoft : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: selected ? AppColors.link : AppColors.ink,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
          ),
          if (selected) const Icon(Icons.check_rounded, size: 18, color: AppColors.link),
        ],
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, required this.onChanged, this.initialValue = ''});

  final String hint;
  final ValueChanged<String> onChanged;
  final String initialValue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextFormField(
        initialValue: initialValue,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.inkSoft),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

/// Two-column "Label   value" row used in popovers and panels.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: AppText.meta.copyWith(fontSize: 13.5))),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: child)),
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: AppText.label),
      );
}

/// "Open Class →" button label (text with a trailing arrow).
class ArrowLabel extends StatelessWidget {
  const ArrowLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_rounded, size: 18),
        ],
      );
}
