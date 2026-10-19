import { FieldValue } from 'firebase-admin/firestore';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { db, isSeed, wantsNotice } from './shared';
import { rewardNotice } from './text';

/** A student redeemed a reward in the student app: tell the teacher. */
export const onRewardRequest = onDocumentCreated('rewardRequests/{id}', async (event) => {
  const r = event.data?.data();
  if (!r || isSeed(r) || r.status !== 'pending' || typeof r.teacherId !== 'string') return;
  if (!(await wantsNotice(r.teacherId, 'rewards'))) return;
  await db.collection('teachers').doc(r.teacherId).collection('notifications').add({
    kind: 'reward',
    title: rewardNotice(r.studentName, r.itemName, r.cost),
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });
});
