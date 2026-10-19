import { initializeApp } from 'firebase-admin/app';
import { DocumentData, FieldValue, getFirestore } from 'firebase-admin/firestore';
import { logger, setGlobalOptions } from 'firebase-functions/v2';

// Runs before any function is defined (every module imports this file).
// Keep the region next to your Firestore database location.
setGlobalOptions({ region: 'asia-southeast1', maxInstances: 10 });

initializeApp();
export const db = getFirestore();

export type ActivityKind = 'submitted' | 'joined' | 'announcement' | 'completed' | 'missed' | 'published';

/** Adds a row to the "Recent Class Activity" feed. */
export function addActivity(
  teacherId: string,
  classId: string,
  kind: ActivityKind,
  title: string,
  subtitle = '',
) {
  return db.collection('activity').add({
    teacherId,
    classId,
    kind,
    title,
    subtitle,
    createdAt: FieldValue.serverTimestamp(),
  });
}

/** Seeded documents carry `seed: true`; their counters are already set. */
export const isSeed = (data: DocumentData | undefined) => data?.seed === true;

/** Firestore NOT_FOUND (e.g. the classwork item was deleted meanwhile). */
export const isNotFound = (e: unknown) => (e as { code?: number })?.code === 5;

/** Logs (instead of crashing on) a failed background write. */
export const soft = (what: string) => (e: unknown) => {
  logger.warn(`Write skipped: ${what}`, { error: String(e) });
  return undefined;
};

/** Settings › Notifications topics (teachers/{uid}/settings/preferences). */
export type NotifyTopic = 'submissions' | 'missingWork' | 'messages' | 'comments' | 'rewards';

/**
 * False only when the teacher switched off the website notice for [topic].
 * (Email choices are stored too, for when the school connects an email service.)
 */
export async function wantsNotice(teacherId: string, topic: NotifyTopic): Promise<boolean> {
  try {
    const snap = await db.collection('teachers').doc(teacherId).collection('settings').doc('preferences').get();
    return snap.get(`notify.${topic}.web`) !== false;
  } catch {
    return true;
  }
}
