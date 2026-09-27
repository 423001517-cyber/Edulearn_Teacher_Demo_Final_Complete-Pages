import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';

/// Shared layout for the report detail drawers: title, big number with the
/// change from last period, scrolling body, and two footer buttons.
class ReportPanelFrame extends StatelessWidget {
  const ReportPanelFrame({
    super.key,
    required this.title,
    required this.icon,
    required this.tone,
    required this.value,
    required this.deltaText,
    required this.deltaColor,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onDownload,
    this.headerTrailing,
  });

  final String title;
  final IconData icon;
  final Tone tone;
  final String value;
  final String deltaText;
  final Color deltaColor;
  final List<Widget> children;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onDownload;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: AppText.dialogTitle.copyWith(fontSize: 21))),
                  if (headerTrailing != null) headerTrailing!,
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ToneIcon(icon, tone: tone, size: 64, circle: true),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value, style: AppText.statValue.copyWith(fontSize: 34)),
                        Text(deltaText,
                            style: TextStyle(
                                color: deltaColor, fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ...children,
            ],
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.description_outlined, size: 19),
                  label: const Text('Download Report'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onPrimary,
                  child: ArrowLabel(primaryLabel),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PanelSectionTitle extends StatelessWidget {
  const PanelSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Row(
          children: [
            Expanded(child: Text(text, style: AppText.sectionTitle.copyWith(fontSize: 15.5))),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

/// Bordered box that groups rows in a panel.
class PanelBox extends StatelessWidget {
  const PanelBox({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

/// "Monday Quest  ████████░░  90%"
class RateRow extends StatelessWidget {
  const RateRow({super.key, required this.label, required this.rate, this.color = AppColors.primary});

  final String label;
  final double rate;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: ProgressBar(value: rate, color: color)),
                const SizedBox(width: 14),
                SizedBox(
                  width: 44,
                  child: Text(percent(rate),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                ),
              ],
            ),
          ],
        ),
      );
}

/// Tinted count box ("9 Completed").
class CountBox extends StatelessWidget {
  const CountBox({super.key, required this.icon, required this.tone, required this.count, required this.label});

  final IconData icon;
  final Tone tone;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: tone.bg.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tone.bg),
          ),
          child: Row(
            children: [
              Icon(icon, color: tone.fg, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$count', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta.copyWith(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
