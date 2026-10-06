/**
 * Pure helpers for the class stream (unit-tested in test/rollup.test.mjs).
 */

/** +1 when a comment appears, −1 when it's deleted, 0 for edits. */
export function commentDelta(beforeExists: boolean, afterExists: boolean): number {
  if (!beforeExists && afterExists) return 1;
  if (beforeExists && !afterExists) return -1;
  return 0;
}

/** "Maria Santos commented on Welcome to Quarter 1!" (titles trimmed to 60). */
export function commentNotice(authorName: string, postTitle: string): string {
  const t = postTitle.trim() || 'your post';
  const short = t.length > 60 ? `${t.slice(0, 57)}…` : t;
  return `${authorName || 'A student'} commented on ${short}`;
}

/** Headline of an announcement: its title, or the first line of the body. */
export function postHeadline(title: unknown, body: unknown): string {
  if (typeof title === 'string' && title.trim()) return title.trim();
  if (typeof body !== 'string') return '';
  const first = body.split('\n').find((l) => l.trim().length > 0) ?? '';
  return first.replace(/\*\*|__|\*/g, '').replace(/^[•-]\s+/, '').trim();
}
