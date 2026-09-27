import { DocumentData, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';

import { noun } from './rollup';
import { addActivity, db, isNotFound, isSeed } from './shared';
import { addDays, startOfDay } from './time';

const COUNTER_FIELDS = ['submittedCount', 'scoreSum', 'scoredCount', 'updatedAt', 'publishedAt'];

const ratio = (s: DocumentData | undefined) =>
  s && s.status === 'returned' && typeof s.score === 'number' && s.maxScore > 0 ? s.score / s.maxScore : null;

/**
 * Submissions (created by the student app, graded by the teacher):
 * keeps classwork counters in sync, clears the matching missing-work row,
 * posts to the activity feed and bumps the teacher's "new submissions"
 * notification.
 */
export const onSubmissionWritten = onDocumentWritten('submissions/{id}', async (event) => {
  const before = event.data?.before.exists ? event.data.before.data() : undefined;
  const after = event.data?.after.exists ? event.data.after.data() : undefined;
  const d = after ?? before;
  if (!d || (!before && isSeed(after))) return;

  const created = !before && !!after;
  const deleted = !!before && !after;
  const r0 = ratio(before);
  const r1 = ratio(after);

  const update: Record<string, FieldValue> = {};
  if (created) update.submittedCount = FieldValue.increment(1);
  if (deleted) update.submittedCount = FieldValue.increment(-1);
  if (r0 !== r1) {
    update.scoreSum = FieldValue.increment((r1 ?? 0) - (r0 ?? 0));
    if (r0 === null) update.scoredCount = FieldValue.increment(1);
    else if (r1 === null) update.scoredCount = FieldValue.increment(-1);
  }
  if (Object.keys(update).length > 0) {
    try {
      await db.collection('classwork').doc(d.classworkId).update(update);
    } catch (e) {
      if (!isNotFound(e)) throw e; // item deleted — nothing to count
    }
  }

  if (!created) return;
  const missingRef = db.collection('missingWork').doc(`${d.studentId}_${d.classworkId}`);
  const missing = await missingRef.get();
  if (missing.exists) {
    const batch = db.batch();
    batch.delete(missingRef);
    batch.update(db.collection('students').doc(d.studentId), {
      missingCount: FieldValue.increment(-1),
    });
    await batch.commit();
  }

  await Promise.all([
    addActivity(d.teacherId, d.classId, 'submitted', `${d.studentName} submitted a ${noun(d.classworkType)}`,
      d.classworkTitle ?? ''),
    bumpSubmissionNotification(d),
  ]);
});

/** One rolling notification per classwork item: "5 new submissions for …". */
async function bumpSubmissionNotification(s: DocumentData) {
  const ref = db
    .collection('teachers').doc(s.teacherId)
    .collection('notifications').doc(`submissions_${s.classworkId}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const prev = snap.exists && snap.get('read') === false ? (snap.get('count') as number) ?? 0 : 0;
    const count = prev + 1;
    tx.set(ref, {
      kind: 'submissions',
      classworkId: s.classworkId,
      count,
      title: `${count} new submission${count === 1 ? '' : 's'} for ${s.classworkTitle ?? 'classwork'}`,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
}

/** Active quests = published graded work due in the last 14 days or later. */
export async function recountQuests(classId: string) {
  const since = addDays(startOfDay(new Date()), -14);
  const snap = await db.collection('classwork')
    .where('classId', '==', classId)
    .where('dueDate', '>=', Timestamp.fromDate(since))
    .get();
  const count = snap.docs.filter((doc) => {
    const w = doc.data();
    return w.status === 'published' && w.type !== 'lesson';
  }).length;
  try {
    await db.collection('classes').doc(classId).update({ questCount: count });
  } catch (e) {
    if (!isNotFound(e)) throw e;
  }
}

function onlyCountersChanged(a: DocumentData, b: DocumentData) {
  const strip = (x: DocumentData) =>
    JSON.stringify(Object.keys(x).filter((k) => !COUNTER_FIELDS.includes(k)).sort().map((k) => [k, x[k]]));
  return strip(a) === strip(b);
}

export const onClassworkWritten = onDocumentWritten('classwork/{id}', async (event) => {
  const before = event.data?.before.exists ? event.data.before.data() : undefined;
  const after = event.data?.after.exists ? event.data.after.data() : undefined;
  if (!before && isSeed(after)) return;
  if (before && after && onlyCountersChanged(before, after)) return;

  const classIds = new Set<string>([before?.classId, after?.classId].filter((x): x is string => !!x));
  await Promise.all([...classIds].map(recountQuests));

  if (after && after.status === 'published' && before?.status !== 'published' && !after.assignedStudentIds?.length) {
    await addActivity(after.teacherId, after.classId, 'published',
      `New ${noun(after.type)} published: ${after.title}`);
  }
});

/** Keeps classes/{id}.studentCount right and announces new students. */
export const onStudentWritten = onDocumentWritten('students/{id}', async (event) => {
  const before = event.data?.before.exists ? event.data.before.data() : undefined;
  const after = event.data?.after.exists ? event.data.after.data() : undefined;
  if (!before && isSeed(after)) return;
  if (before && after && before.classId === after.classId) return; // progress update only

  const classIds = new Set<string>([before?.classId, after?.classId].filter((x): x is string => !!x));
  for (const classId of classIds) {
    const count = (await db.collection('students').where('classId', '==', classId).count().get()).data().count;
    try {
      await db.collection('classes').doc(classId).update({ studentCount: count });
    } catch (e) {
      if (!isNotFound(e)) throw e;
    }
  }
  if (after && after.classId !== before?.classId) {
    await addActivity(after.teacherId, after.classId, 'joined', `${after.name} joined the class`);
  }
});

export const onAnnouncementCreated = onDocumentCreated('announcements/{id}', async (event) => {
  const a = event.data?.data();
  if (!a || isSeed(a)) return;
  const subtitle = `“${a.title}”`;
  if (a.classId) {
    await addActivity(a.teacherId, a.classId, 'announcement', 'You posted an announcement', subtitle);
    return;
  }
  // Posted to all classes: show it in every active class feed.
  const classes = await db.collection('classes')
    .where('teacherId', '==', a.teacherId)
    .where('status', '==', 'active')
    .get();
  await Promise.all(classes.docs.map((c) =>
    addActivity(a.teacherId, c.id, 'announcement', 'You posted an announcement', subtitle)));
  logger.info('Announcement fanned out', { classes: classes.size });
});
