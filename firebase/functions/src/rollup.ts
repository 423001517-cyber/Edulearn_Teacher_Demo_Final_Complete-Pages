/**
 * Pure calculations for the nightly rollup. No Firestore here, so it can be
 * unit-tested (see functions/test/rollup.test.mjs).
 */
import { addDays, startOfDay, startOfMonth, startOfQuarter } from './time';

export type ClassworkType = 'lesson' | 'quest' | 'quiz' | 'boss' | 'activity' | 'material';

export interface WorkIn {
  id: string;
  title: string;
  type: ClassworkType;
  status: string;
  dueDate: Date;
  assignedStudentIds: string[];
}

export interface StudentIn {
  id: string;
  name: string;
}

export interface SubmissionIn {
  studentId: string;
  classworkId: string;
  status: string;
  score: number | null;
  maxScore: number;
  submittedAt: Date;
  returnedAt: Date | null;
}

export interface AttendanceIn {
  date: Date;
  marks: Record<string, 'present' | 'late' | 'absent'>;
}

export interface StudentOut {
  missingCount: number;
  questProgress: number;
  averageScore: number | null;
  recentScore: number | null;
  attendanceRate: number | null;
  absences: number;
  lateCount: number;
}

export interface MissingOut {
  studentId: string;
  studentName: string;
  work: WorkIn;
}

export interface RollupOut {
  students: Map<string, StudentOut>;
  missing: MissingOut[];
  completionRate: number | null;
  averageScore: number | null;
  studentsWithMissing: number;
  monthAttendance: number | null;
  monthCompletion: number | null;
  monthAverage: number | null;
  dailyScore: number | null;
  /** Items whose due date was yesterday: who turned them in, who didn't. */
  yesterday: { work: WorkIn; completed: number; missedBy: StudentIn[] }[];
  /** Friday Boss Assessments due tomorrow. */
  bossTomorrow: WorkIn[];
}

/** Late work is still accepted (and counted as missing) for this long. */
export const MISSING_WINDOW_DAYS = 30;

const GRADED: ClassworkType[] = ['quest', 'quiz', 'boss', 'activity'];

export const isGraded = (w: WorkIn) =>
  GRADED.includes(w.type) && (w.status === 'published' || w.status === 'closed');

export const isAssigned = (w: WorkIn, studentId: string) =>
  w.assignedStudentIds.length === 0 || w.assignedStudentIds.includes(studentId);

export const ratioOf = (s: SubmissionIn) =>
  s.status === 'returned' && typeof s.score === 'number' && s.maxScore > 0 ? s.score / s.maxScore : null;

const avg = (xs: number[]) => (xs.length === 0 ? null : xs.reduce((a, b) => a + b, 0) / xs.length);

export function computeRollup(
  now: Date,
  students: StudentIn[],
  work: WorkIn[],
  submissions: SubmissionIn[],
  attendance: AttendanceIn[],
): RollupOut {
  const today = startOfDay(now);
  const tomorrow = addDays(today, 1);
  const yesterday = addDays(today, -1);
  const windowStart = addDays(today, -MISSING_WINDOW_DAYS);
  const quarterStart = startOfQuarter(now);
  const monthStart = startOfMonth(now);

  const submitted = new Set(submissions.map((s) => `${s.studentId}_${s.classworkId}`));
  const graded = work.filter(isGraded);
  const pastDue = graded.filter((w) => w.dueDate < today);
  const inWindow = pastDue.filter((w) => w.dueDate >= windowStart);

  const out = new Map<string, StudentOut>();
  const missing: MissingOut[] = [];

  for (const st of students) {
    const mine = inWindow.filter((w) => isAssigned(w, st.id));
    const notIn = mine.filter((w) => !submitted.has(`${st.id}_${w.id}`));
    for (const w of notIn) missing.push({ studentId: st.id, studentName: st.name, work: w });

    const returned = submissions
      .filter((s) => s.studentId === st.id && ratioOf(s) !== null)
      .filter((s) => (s.returnedAt ?? s.submittedAt) >= quarterStart)
      .sort((a, b) => (b.returnedAt ?? b.submittedAt).getTime() - (a.returnedAt ?? a.submittedAt).getTime());
    const ratios = returned.map((s) => ratioOf(s)!);

    let present = 0, late = 0, absent = 0;
    for (const day of attendance) {
      const mark = day.marks[st.id];
      if (mark === 'present') present++;
      else if (mark === 'late') late++;
      else if (mark === 'absent') absent++;
    }
    const marked = present + late + absent;

    out.set(st.id, {
      missingCount: notIn.length,
      questProgress: mine.length === 0 ? 1 : (mine.length - notIn.length) / mine.length,
      averageScore: avg(ratios),
      recentScore: avg(ratios.slice(0, 3)),
      attendanceRate: marked === 0 ? null : (present + late) / marked,
      absences: absent,
      lateCount: late,
    });
  }

  const classSize = students.length;
  const completionOf = (w: WorkIn) => {
    const assigned = students.filter((s) => isAssigned(w, s.id));
    const size = assigned.length || classSize;
    if (size === 0) return null;
    return assigned.filter((s) => submitted.has(`${s.id}_${w.id}`)).length / size;
  };
  const rates = (items: WorkIn[]) =>
    items.map(completionOf).filter((x): x is number => x !== null);

  const quarterItems = pastDue.filter((w) => w.dueDate >= quarterStart);
  const monthItems = pastDue.filter((w) => w.dueDate >= monthStart);

  const monthDays = attendance.filter((d) => d.date >= monthStart);
  let attended = 0, total = 0;
  for (const d of monthDays) {
    for (const mark of Object.values(d.marks)) {
      total++;
      if (mark !== 'absent') attended++;
    }
  }

  const returnedSince = (from: Date) =>
    submissions
      .filter((s) => ratioOf(s) !== null && (s.returnedAt ?? s.submittedAt) >= from)
      .map((s) => ratioOf(s)!);

  const studentAverages = [...out.values()]
    .map((s) => s.averageScore)
    .filter((x): x is number => x !== null);

  return {
    students: out,
    missing,
    completionRate: avg(rates(quarterItems)),
    averageScore: avg(studentAverages),
    studentsWithMissing: [...out.values()].filter((s) => s.missingCount > 0).length,
    monthAttendance: total === 0 ? null : attended / total,
    monthCompletion: avg(rates(monthItems)),
    monthAverage: avg(returnedSince(monthStart)),
    dailyScore: avg(returnedSince(today)),
    yesterday: pastDue
      .filter((w) => w.dueDate >= yesterday && w.dueDate < today)
      .map((w) => {
        const assigned = students.filter((s) => isAssigned(w, s.id));
        return {
          work: w,
          completed: assigned.filter((s) => submitted.has(`${s.id}_${w.id}`)).length,
          missedBy: assigned.filter((s) => !submitted.has(`${s.id}_${w.id}`)),
        };
      }),
    // Usually still "scheduled" the night before, so don't require published.
    bossTomorrow: work.filter(
      (w) => w.type === 'boss' && w.status !== 'draft' && w.dueDate >= tomorrow && w.dueDate < addDays(tomorrow, 1),
    ),
  };
}

/** "quest", "quiz", "boss assessment" … for activity sentences. */
export const noun = (type: string) =>
  type === 'boss' ? 'boss assessment' : ['lesson', 'quest', 'quiz', 'activity', 'material'].includes(type) ? type : 'task';
