import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/navigation.dart';
import '../../providers/stream_providers.dart';

/// Stream icon + colour per kind of classwork post (design: blue
/// assignment, purple quiz, orange material).
extension StreamWorkKindVisuals on StreamWorkKind {
  IconData get icon => switch (this) {
        StreamWorkKind.assignment => Icons.assignment_outlined,
        StreamWorkKind.quiz => Icons.quiz_rounded,
        StreamWorkKind.material => Icons.auto_stories_rounded,
      };

  Tone get tone => switch (this) {
        StreamWorkKind.assignment => Tone.blue,
        StreamWorkKind.quiz => Tone.purple,
        StreamWorkKind.material => Tone.amber,
      };
}

/// "Sep 25, 2026, 8:30 AM"
String postTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '${fullDate(d)}, $h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "8:00 AM"
String clockTime(TimeOfDay t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

Future<void> openUrl(String? url) async {
  if (url == null) {
    showToast('This demo file was never uploaded, so it can’t be opened.');
    return;
  }
  final ok = await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
  if (!ok) showToast('Couldn’t open the link.');
}

/// Post text with the composer's formatting (bold, italic, underline,
/// bullet lines, links).
class FormattedText extends StatelessWidget {
  const FormattedText(this.text, {super.key, this.style, this.maxLines});

  final String text;
  final TextStyle? style;

  /// Collapses to a plain preview with an ellipsis.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    if (maxLines != null) {
      return Text(plainText(text), style: base, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }
    final lines = parsePost(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines)
          if (line.bullet)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: base),
                  Expanded(child: Text.rich(_spans(line.segments, base), style: base)),
                ],
              ),
            )
          else
            Text.rich(_spans(line.segments, base), style: base),
      ],
    );
  }

  static TextSpan _spans(List<FormatSegment> segments, TextStyle base) => TextSpan(children: [
        for (final s in segments)
          switch (s.style) {
            SegmentStyle.plain => TextSpan(text: s.text),
            SegmentStyle.bold => TextSpan(text: s.text, style: const TextStyle(fontWeight: FontWeight.w700)),
            SegmentStyle.italic => TextSpan(text: s.text, style: const TextStyle(fontStyle: FontStyle.italic)),
            SegmentStyle.underline =>
              TextSpan(text: s.text, style: const TextStyle(decoration: TextDecoration.underline)),
            SegmentStyle.link => WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => openUrl(s.url),
                    child: Text(s.text,
                        style: base.copyWith(
                            color: AppColors.link, decoration: TextDecoration.underline)),
                  ),
                ),
              ),
          },
      ]);
}

/// The grey file chip: "[PDF] Q1_Class_Orientation.pdf   2.4 MB".
class AttachmentChip extends StatelessWidget {
  const AttachmentChip({super.key, required this.attachment, this.onRemove});

  final PostAttachment attachment;

  /// Shows an ✕ (composer).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final a = attachment;
    final (IconData icon, Color color) = switch (a.kind) {
      AttachmentKind.link => (Icons.link_rounded, AppColors.blue),
      AttachmentKind.video => (Icons.smart_display_rounded, AppColors.red),
      AttachmentKind.file => switch (a.extension) {
          'PDF' => (Icons.picture_as_pdf_rounded, AppColors.red),
          'DOC' || 'DOCX' => (Icons.description_rounded, AppColors.blue),
          'PPT' || 'PPTX' => (Icons.slideshow_rounded, AppColors.amber),
          'XLS' || 'XLSX' => (Icons.grid_on_rounded, AppColors.primary),
          'PNG' || 'JPG' || 'JPEG' || 'GIF' => (Icons.image_rounded, AppColors.purple),
          _ => (Icons.insert_drive_file_rounded, AppColors.muted),
        },
    };
    return Material(
      color: AppColors.chip,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => openUrl(a.url),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 8, onRemove == null ? 14 : 4, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              if (a.sizeLabel.isNotEmpty) ...[
                const SizedBox(width: 14),
                Text(a.sizeLabel, style: AppText.meta.copyWith(fontSize: 12.5)),
              ],
              if (onRemove != null)
                IconButton(
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round avatar with initials (photos come later with the student app).
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.name, this.photoUrl, this.size = 44});

  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _initials()),
      );
    }
    return _initials();
  }

  Widget _initials() => InitialsAvatar(initials: initialsOf(name), tone: toneForName(name), size: size);
}

/// Tinted chip used on classwork posts: "Due Sep 28, 2026", "20 points".
class MetaChip extends StatelessWidget {
  const MetaChip({super.key, required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color == null ? AppColors.chip : color!.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}
