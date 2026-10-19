import { FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';

import { db, soft } from '../shared';

/** Everything a teacher sees is stamped with teacherId; these follow the class. */
const CLASS_SCOPED = [
  'students', 'classwork', 'submissions', 'announcements', 'activity', 'missingWork', 'attendance',
  'conversations', 'pointAwards', 'rewardRequests',
];

/**
 * When an admin reassigns a class to another teacher, move every document
 * of that class to the new teacher so it appears on their dashboard (and
 * disappears from the previous teacher's).
 */
export const onClassReassigned = onDocumentUpdated('classes/{classId}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.teacherId === after.teacherId) return;

  const classId = event.params.classId;
  const writer = db.bulkWriter();
  let moved = 0;
  for (const name of CLASS_SCOPED) {
    const snap = await db.collection(name).where('classId', '==', classId).get();
    for (const doc of snap.docs) {
      writer.update(doc.ref, { teacherId: after.teacherId }).catch(soft(`${name}/${doc.id}`));
      moved++;
    }
  }
  writer.set(db.collection('teachers').doc(after.teacherId).collection('notifications').doc(), {
    kind: 'general',
    title: `You've been assigned Grade ${after.gradeLevel} – ${after.section}`,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  }).catch(soft('notification'));
  await writer.close();
  logger.info('Class reassigned', { classId, from: before.teacherId, to: after.teacherId, moved });
});
