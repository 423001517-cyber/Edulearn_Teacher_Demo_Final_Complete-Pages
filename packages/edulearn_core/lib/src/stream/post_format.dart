/// Light formatting for stream posts, written by the composer's toolbar:
///   **bold**   *italic*   __underline__   "• " bullet lines
///   [link text](https://…)   and bare https:// links.
/// Pure Dart so the teacher website and student app render it the same way.
library;

enum SegmentStyle { plain, bold, italic, underline, link }

class FormatSegment {
  const FormatSegment(this.text, this.style, [this.url]);

  final String text;
  final SegmentStyle style;
  final String? url;

  @override
  String toString() => '${style.name}:$text${url == null ? '' : '→$url'}';
}

class FormatLine {
  const FormatLine(this.segments, {this.bullet = false});

  final List<FormatSegment> segments;
  final bool bullet;
}

final _inline = RegExp(
  r'\*\*(.+?)\*\*'             // 1 bold
  r'|__(.+?)__'                // 2 underline
  r'|\*(.+?)\*'                // 3 italic
  r'|\[([^\]]+)\]\((https?://[^)\s]+)\)' // 4 text, 5 url
  r'|(https?://[^\s)]+)',      // 6 bare url
);

List<FormatSegment> parseInline(String text) {
  final out = <FormatSegment>[];
  var at = 0;
  for (final m in _inline.allMatches(text)) {
    if (m.start > at) out.add(FormatSegment(text.substring(at, m.start), SegmentStyle.plain));
    if (m.group(1) != null) {
      out.add(FormatSegment(m.group(1)!, SegmentStyle.bold));
    } else if (m.group(2) != null) {
      out.add(FormatSegment(m.group(2)!, SegmentStyle.underline));
    } else if (m.group(3) != null) {
      out.add(FormatSegment(m.group(3)!, SegmentStyle.italic));
    } else if (m.group(4) != null) {
      out.add(FormatSegment(m.group(4)!, SegmentStyle.link, m.group(5)));
    } else {
      out.add(FormatSegment(m.group(6)!, SegmentStyle.link, m.group(6)));
    }
    at = m.end;
  }
  if (at < text.length) out.add(FormatSegment(text.substring(at), SegmentStyle.plain));
  return out;
}

List<FormatLine> parsePost(String text) => [
      for (final raw in text.split('\n'))
        if (raw.startsWith('• ') || raw.startsWith('- '))
          FormatLine(parseInline(raw.substring(2)), bullet: true)
        else
          FormatLine(parseInline(raw)),
    ];

/// The text without formatting marks.
String plainText(String text) => parsePost(text)
    .map((l) => (l.bullet ? '• ' : '') + l.segments.map((s) => s.text).join())
    .join('\n');

/// The composer's single text box: a short first line followed by more
/// text becomes the bold headline; otherwise everything is the body.
({String title, String body}) splitHeadline(String text) {
  final t = text.trim();
  final nl = t.indexOf('\n');
  if (nl > 0) {
    final first = t.substring(0, nl).trim();
    final rest = t.substring(nl + 1).trim();
    if (first.length <= 120 && rest.isNotEmpty && !first.startsWith('• ')) {
      return (title: plainText(first), body: rest);
    }
  }
  return (title: '', body: t);
}
