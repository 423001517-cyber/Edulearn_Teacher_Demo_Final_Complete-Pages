import { DocumentData, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { db, isNotFound, isSeed, wantsNotice } from '../shared';
import { MANILA_TZ } from '../time';
import { commentDelta, commentNotice, postHeadline } from './comments';

/**
 * Scheduled stream posts and scheduled classwork go live at their
 * publishAt time.
 */
export const publishScheduledPosts = onSchedule(
  { schedule: 'every 5 minutes', timeZone: MANILA_TZ },
  async () => {
    let total = 0;
    for (const name of ['announcements', 'classwork']) {
      const due = await db.collection(name)
        .where('status', '==', 'scheduled')
        .where('publishAt', '<=', Timestamp.now())
        .limit(400)
        .get();
      if (due.empty) continue;
      const batch = db.batch();
      for (const doc of due.docs) {
        // Posts: createdAt = publishAt so they sort where students expect.
        batch.update(doc.ref, name === 'announcements'
          ? { status: 'published', createdAt: doc.get('publishAt') }
          : { status: 'published', publishedAt: doc.get('publishAt') });
      }
      await batch.commit();
      total += due.size;
    }
    if (total) logger.info('Published scheduled items', { count: total });
  },
);

/**
 * Keeps `commentCount` on the post and tells the teacher when a student
 * comments. Shared by announcements and classwork.
 */
async function onComment(
  parentCollection: 'announcements' | 'classwork',
  postId: string,
  before: DocumentData | undefined,
  after: DocumentData | undefined,
) {
  if (isSeed(after ?? before)) return;
  const delta = commentDelta(!!before, !!after);
  if (delta === 0) return;
  const postRef = db.collection(parentCollection).doc(postId);
  try {
    await postRef.update({ commentCount: FieldValue.increment(delta) });
  } catch (e) {
    if (isNotFound(e)) return; // post deleted with its comments
    throw e;
  }

  if (delta > 0 && after?.authorRole === 'student') {
    const post = await postRef.get();
    const teacherId = post.get('teacherId');
    if (!teacherId || !(await wantsNotice(teacherId, 'comments'))) return;
    await db.collection('teachers').doc(teacherId).collection('notifications').add({
      kind: 'general',
      title: commentNotice(after.authorName, postHeadline(post.get('title'), post.get('body'))),
      classId: post.get('classId') ?? null,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
}

export const onAnnouncementComment = onDocumentWritten(
  'announcements/{postId}/comments/{commentId}',
  (event) => onComment('announcements', event.params.postId,
    event.data?.before.data(), event.data?.after.data()),
);

export const onClassworkComment = onDocumentWritten(
  'classwork/{postId}/comments/{commentId}',
  (event) => onComment('classwork', event.params.postId,
    event.data?.before.data(), event.data?.after.data()),
);
