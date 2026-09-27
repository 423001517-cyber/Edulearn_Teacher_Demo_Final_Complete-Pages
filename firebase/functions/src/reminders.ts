import { FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions/v2';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { db } from './shared';

const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/**
 * "Send Reminder" in the dashboard writes reminders/{id}; this pushes it to
 * the student's devices (tokens saved by the student app in
 * students/{id}.fcmTokens) and records the outcome on the reminder.
 */
export const deliverReminder = onDocumentCreated('reminders/{id}', async (event) => {
  const snap = event.data;
  const r = snap?.data();
  if (!snap || !r) return;

  const student = await db.collection('students').doc(r.studentId).get();
  if (!student.exists || student.get('teacherId') !== r.teacherId) {
    await snap.ref.update({ status: 'rejected', processedAt: FieldValue.serverTimestamp() });
    return;
  }
  const tokens: string[] = student.get('fcmTokens') ?? [];
  if (tokens.length === 0) {
    // The student app can still show it: it reads reminders where studentId == me.
    await snap.ref.update({ status: 'no-device', processedAt: FieldValue.serverTimestamp() });
    return;
  }

  const teacher = await db.collection('teachers').doc(r.teacherId).get();
  const first = String(teacher.get('displayName') ?? 'your teacher').split(' ')[0];
  const res = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title: `Reminder from Teacher ${first}`, body: r.message },
    data: { type: 'reminder', classId: r.classId ?? '', classworkId: r.classworkId ?? '' },
  });

  const dead = tokens.filter((_, i) => {
    const code = res.responses[i]?.error?.code;
    return !res.responses[i]?.success && code !== undefined && DEAD_TOKEN_CODES.has(code);
  });
  if (dead.length > 0) {
    await student.ref.update({ fcmTokens: FieldValue.arrayRemove(...dead) });
  }
  await snap.ref.update({
    status: res.successCount > 0 ? 'sent' : 'failed',
    successCount: res.successCount,
    processedAt: FieldValue.serverTimestamp(),
  });
  logger.info('Reminder delivered', { reminder: snap.id, ok: res.successCount, dead: dead.length });
});
