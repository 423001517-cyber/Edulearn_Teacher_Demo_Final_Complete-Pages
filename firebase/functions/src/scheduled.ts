import { DocumentData, FieldValue, QueryDocumentSnapshot, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import {
  AttendanceIn,
  ClassworkType,
  MISSING_WINDOW_DAYS,
  StudentIn,
  SubmissionIn,
  WorkIn,
  computeRollup,
  noun,
} from './rollup';
import { addActivity, db, soft } from './shared';
import { addDays, dayKey, MANILA_TZ, monthKey, startOfDay, startOfMonth, startOfQuarter } from './time';
import { recountQuests } from './triggers';

const toDate = (v: unknown): Date | null => (v instanceof Timestamp ? v.toDate() : null);

/** Friday Boss Assessments (and anything else scheduled) go live on their date. */
export const publishScheduledClasswork = onSchedule(
  { schedule: 'every 60 minutes', timeZone: MANILA_TZ },
  async () => {
    const due = await db.collection('classwork')
      .where('status', '==', 'scheduled')
      .where('dueDate', '<=', Timestamp.now())
      .limit(400)
      .get();
    if (due.empty) return;
    const batch = db.batch();
    for (const doc of due.docs) {
      batch.update(doc.ref, { status: 'published', publishedAt: FieldValue.serverTimestamp() });
    }
    await batch.commit();
    logger.info('Published scheduled classwork', { count: due.size });
  },
);

/**
 * 9:00 PM Manila, every day. For each active class it recomputes:
 * student progress (missing work, quest progress, scores, attendance),
 * class completion/average, the missingWork rows, today's point on the
 * performance chart, this month's report stats, and posts the
 * "missed" / "completed" activity and teacher notifications.
 */
export const nightlyRollup = onSchedule(
  { schedule: '0 21 * * *', timeZone: MANILA_TZ, timeoutSeconds: 540, memory: '512MiB' },
  async () => {
    const classes = await db.collection('classes').where('status', '==', 'active').get();
    for (const c of classes.docs) {
      try {
        await rollupClass(c);
      } catch (e) {
        logger.error('Rollup failed', { classId: c.id, error: String(e) });
      }
    }
    logger.info('Nightly rollup finished', { classes: classes.size });
  },
);

export async function rollupClass(classDoc: QueryDocumentSnapshot, now = new Date()) {
  const classId = classDoc.id;
  const cls = classDoc.data();
  const teacherId: string = cls.teacherId;
  const className = `Grade ${cls.gradeLevel} – ${cls.section}`;
  const today = startOfDay(now);
  const quarterStart = startOfQuarter(now);
  const windowStart = addDays(today, -MISSING_WINDOW_DAYS);
  const from = quarterStart < windowStart ? quarterStart : windowStart;

  const [studentsSnap, workSnap, subsSnap, attSnap, missingSnap] = await Promise.all([
    db.collection('students').where('classId', '==', classId).get(),
    db.collection('classwork').where('classId', '==', classId)
      .where('dueDate', '>=', Timestamp.fromDate(addDays(from, -1))).get(),
    db.collection('submissions').where('classId', '==', classId)
      .where('submittedAt', '>=', Timestamp.fromDate(addDays(from, -45))).get(),
    db.collection('attendance').where('classId', '==', classId)
      .where('date', '>=', Timestamp.fromDate(quarterStart)).get(),
    db.collection('missingWork').where('classId', '==', classId).get(),
  ]);

  const students: StudentIn[] = studentsSnap.docs.map((d) => ({ id: d.id, name: d.get('name') ?? 'Student' }));
  const work: WorkIn[] = workSnap.docs.map((d) => {
    const w = d.data();
    return {
      id: d.id,
      title: w.title ?? 'Classwork',
      type: w.type as ClassworkType,
      status: w.status,
      dueDate: toDate(w.dueDate) ?? now,
      assignedStudentIds: w.assignedStudentIds ?? [],
    };
  });
  const submissions: SubmissionIn[] = subsSnap.docs.map((d) => {
    const s = d.data();
    return {
      studentId: s.studentId,
      classworkId: s.classworkId,
      status: s.status,
      score: typeof s.score === 'number' ? s.score : null,
      maxScore: s.maxScore ?? 0,
      submittedAt: toDate(s.submittedAt) ?? now,
      returnedAt: toDate(s.returnedAt),
    };
  });
  const attendance: AttendanceIn[] = attSnap.docs.map((d) => ({
    date: toDate(d.get('date')) ?? now,
    marks: (d.get('marks') ?? {}) as AttendanceIn['marks'],
  }));

  const r = computeRollup(now, students, work, submissions, attendance);
  const writer = db.bulkWriter();

  // Students
  for (const [id, s] of r.students) {
    writer.update(db.collection('students').doc(id), { ...s, rolledUpAt: FieldValue.serverTimestamp() })
      .catch(soft(`student ${id}`));
  }

  // missingWork rows: upsert current, delete resolved
  const keep = new Set<string>();
  for (const m of r.missing) {
    const id = `${m.studentId}_${m.work.id}`;
    keep.add(id);
    writer.set(db.collection('missingWork').doc(id), {
      teacherId,
      classId,
      studentId: m.studentId,
      studentName: m.studentName,
      classworkId: m.work.id,
      classworkTitle: m.work.title,
      classworkType: m.work.type,
      dueDate: Timestamp.fromDate(m.work.dueDate),
    }).catch(soft(`missingWork ${id}`));
  }
  for (const doc of missingSnap.docs) {
    if (!keep.has(doc.id)) writer.delete(doc.ref).catch(soft(`missingWork ${doc.id}`));
  }

  // Class card numbers
  const classUpdate: DocumentData = {};
  if (r.completionRate !== null) classUpdate.completionRate = r.completionRate;
  if (r.averageScore !== null) classUpdate.averageScore = r.averageScore;
  if (Object.keys(classUpdate).length > 0) {
    writer.update(classDoc.ref, classUpdate).catch(soft(`class ${classId}`));
  }

  // Performance chart point for today
  if (r.dailyScore !== null) {
    writer.set(classDoc.ref.collection('dailyPerformance').doc(dayKey(now)), {
      date: Timestamp.fromDate(today),
      score: r.dailyScore,
    }).catch(soft('dailyPerformance'));
  }

  // Monthly report row (overwritten nightly until the month ends)
  writer.set(classDoc.ref.collection('monthlyStats').doc(monthKey(now)), {
    month: Timestamp.fromDate(startOfMonth(now)),
    completion: r.monthCompletion ?? r.completionRate ?? 0,
    averageScore: r.monthAverage ?? r.averageScore ?? 0,
    attendance: r.monthAttendance ?? 0,
    missingWork: r.studentsWithMissing,
  }).catch(soft('monthlyStats'));

  // Teacher notifications
  const notifications = db.collection('teachers').doc(teacherId).collection('notifications');
  if (r.studentsWithMissing > 0) {
    writer.set(notifications.doc(`missing_${classId}`), {
      kind: 'missingWork',
      title: `${r.studentsWithMissing} student${r.studentsWithMissing === 1 ? ' has' : 's have'} missing work in ${className}`,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    }).catch(soft('missing notification'));
  }
  for (const w of r.bossTomorrow) {
    writer.create(notifications.doc(`boss_${w.id}`), {
      kind: 'schedule',
      title: `Friday Boss Assessment is tomorrow (${className})`,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    }).catch(() => undefined); // already notified
  }

  await writer.close();

  // Activity feed for work that closed yesterday
  for (const y of r.yesterday) {
    await addActivity(teacherId, classId, 'completed',
      `${y.completed} student${y.completed === 1 ? '' : 's'} completed the ${noun(y.work.type)}`, y.work.title);
    for (const s of y.missedBy.slice(0, 5)) {
      await addActivity(teacherId, classId, 'missed', `${s.name} missed a ${noun(y.work.type)}`, y.work.title);
    }
  }

  await recountQuests(classId);
}
