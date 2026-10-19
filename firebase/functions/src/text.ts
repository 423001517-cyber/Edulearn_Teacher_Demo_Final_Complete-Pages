/** Small pure text helpers (unit-tested in test/text.test.mjs). */

/** "Juan Dela Cruz" -> "Juan". */
export const firstName = (name: unknown) =>
  typeof name === 'string' && name.trim() ? name.trim().split(/\s+/)[0] : 'Student';

/** The conversation-list preview for a chat message (max 140 characters). */
export function chatPreview(body: unknown, attachmentName?: unknown): string {
  const text = typeof body === 'string' ? body.trim() : '';
  const out = text || (typeof attachmentName === 'string' && attachmentName ? `Sent a file: ${attachmentName}` : '');
  return out.length > 140 ? `${out.slice(0, 140)}…` : out;
}

/** Bell text for a new reward request. */
export const rewardNotice = (studentName: unknown, itemName: unknown, cost: unknown) =>
  `${typeof studentName === 'string' ? studentName : 'A student'} wants “${
    typeof itemName === 'string' ? itemName : 'a reward'}”${typeof cost === 'number' ? ` (${cost} pts)` : ''}`;
