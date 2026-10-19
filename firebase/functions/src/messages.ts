import { FieldValue } from 'firebase-admin/firestore';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { db, isSeed, wantsNotice } from './shared';
import { chatPreview, firstName } from './text';

/**
 * A student's chat message (from the student app): updates the
 * conversation preview and unread count, and tells the teacher.
 * The teacher's own messages update the conversation in the same batch.
 */
export const onConversationMessage = onDocumentCreated('conversations/{cid}/messages/{mid}', async (event) => {
  const m = event.data?.data();
  if (!m || isSeed(m) || m.authorRole !== 'student') return;
  const ref = db.collection('conversations').doc(event.params.cid);
  const convo = await ref.get();
  if (!convo.exists) return;

  await ref.update({
    lastMessage: chatPreview(m.body, m.attachment?.name),
    lastMessageAt: FieldValue.serverTimestamp(),
    lastRole: 'student',
    lastAuthor: firstName(m.authorName),
    unread: FieldValue.increment(1),
  });

  const teacherId = convo.get('teacherId');
  if (!teacherId || !(await wantsNotice(teacherId, 'messages'))) return;
  const group = convo.get('kind') === 'group';
  // One rolling notice per conversation.
  await db.collection('teachers').doc(teacherId).collection('notifications').doc(`message_${event.params.cid}`).set({
    kind: 'message',
    title: group ? `${m.authorName} wrote in ${convo.get('title')}` : `${m.authorName} sent you a message`,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });
});
