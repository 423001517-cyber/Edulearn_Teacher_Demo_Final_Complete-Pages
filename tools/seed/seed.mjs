#!/usr/bin/env node
/**
 * Seeds Firestore (+ an Auth user) with demo data that matches the mockups:
 * Teacher Jean, Grade 4 – Rizal (RIZAL-4A), Grade 5 – Bonifacio (BONI-5B),
 * Grade 6 – Mabini (MABI-6C), one archived class, 68 active students,
 * 7 students with missing work, 14 submissions to review, 9 active quests
 * this week, and a quarter-over-quarter report trend (+12% completion …).
 *
 * Usage (from tools/seed, after `npm install`):
 *   node seed.mjs --dry-run                 # print what would be written
 *   # Emulators (start them first: firebase emulators:start):
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
 *     node seed.mjs --reset
 *   # A real project (uses Application Default Credentials):
 *   node seed.mjs --project your-project-id --reset
 *
 * Also creates the admin website sign-in (admin@edulearn.test / edulearn123),
 * two more teachers, school settings and class requests.
 *
 * Options: --email, --password, --project, --reset, --dry-run
 * Every written document has `seed: true`, so the Cloud Functions skip
 * counter updates for them (counters are already filled in here).
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

// ------------------------------------------------------------------- args
const args = process.argv.slice(2);
const flag = (name) => args.includes(`--${name}`);
const opt = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] && !args[i + 1].startsWith('--') ? args[i + 1] : fallback;
};
const here = dirname(fileURLToPath(import.meta.url));
const defaultProject = (() => {
  try {
    return JSON.parse(readFileSync(join(here, '../../.firebaserc'), 'utf8')).projects.default;
  } catch {
    return 'demo-edulearn';
  }
})();
const EMAIL = opt('email', 'jean@edulearn.test');
const ADMIN_EMAIL = opt('admin-email', 'admin@edulearn.test');
const EXTRA_TEACHERS = [
  { uid: 'teacher-rosa', displayName: 'Rosa Dizon', email: 'rosa@edulearn.test', status: 'active' },
  { uid: 'teacher-mark', displayName: 'Mark Villareal', email: 'mark@edulearn.test', status: 'disabled' },
];
const PASSWORD = opt('password', 'edulearn123');
const PROJECT = opt('project', process.env.GCLOUD_PROJECT ?? defaultProject);

// ------------------------------------------------------- Manila date math
const OFFSET = 8 * 3600 * 1000;
const DAY = 24 * 3600 * 1000;
const parts = (d) => {
  const m = new Date(d.getTime() + OFFSET);
  return { y: m.getUTCFullYear(), mo: m.getUTCMonth(), d: m.getUTCDate(), wd: m.getUTCDay() };
};
const manila = (y, mo, d, h = 0, mi = 0) => new Date(Date.UTC(y, mo, d, h, mi) - OFFSET);
const startOfDay = (d) => { const p = parts(d); return manila(p.y, p.mo, p.d); };
const addDays = (d, n) => new Date(d.getTime() + n * DAY);
const addHours = (d, n) => new Date(d.getTime() + n * 3600 * 1000);
const startOfMonth = (d) => { const p = parts(d); return manila(p.y, p.mo, 1); };
const startOfQuarter = (d) => { const p = parts(d); return manila(p.y, p.mo - (p.mo % 3), 1); };
const monday = (d) => { const p = parts(d); return addDays(startOfDay(d), -((p.wd + 6) % 7)); };
const pad = (n) => String(n).padStart(2, '0');
const dayKey = (d) => { const p = parts(d); return `${p.y}-${pad(p.mo + 1)}-${pad(p.d)}`; };
const monthKey = (d) => { const p = parts(d); return `${p.y}-${pad(p.mo + 1)}`; };
const isWeekday = (d) => { const wd = parts(d).wd; return wd >= 1 && wd <= 5; };
const clamp = (x, lo, hi) => Math.min(hi, Math.max(lo, x));
const round2 = (x) => Math.round(x * 1000) / 1000;

// Deterministic randomness so every run produces the same school.
function mulberry32(seed) {
  return () => {
    seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ------------------------------------------------------------ school data
const CLASSES = [
  { id: 'rizal-4a', gradeLevel: 4, section: 'Rizal', classCode: 'RIZAL-4A', colorIndex: 0, size: 20,
    target: { c: 0.75, a: 0.82, t: 0.94, m: 2 }, delta: { c: 0.12, a: 0.08, t: 0.04, m: 6 } },
  { id: 'boni-5b', gradeLevel: 5, section: 'Bonifacio', classCode: 'BONI-5B', colorIndex: 1, size: 25,
    target: { c: 0.6, a: 0.76, t: 0.92, m: 3 }, delta: { c: 0.07, a: 0.05, t: 0.02, m: 3 } },
  { id: 'mabi-6c', gradeLevel: 6, section: 'Mabini', classCode: 'MABI-6C', colorIndex: 2, size: 23,
    target: { c: 0.55, a: 0.71, t: 0.9, m: 2 }, delta: { c: 0.05, a: 0.03, t: 0.01, m: 2 } },
  { id: 'luna-4b', gradeLevel: 4, section: 'Luna', classCode: 'LUNA-4B', colorIndex: 3, size: 18, archived: true,
    target: { c: 0.81, a: 0.79, t: 0.93, m: 0 }, delta: { c: 0.03, a: 0.02, t: 0.01, m: 1 } },
];

// Students called out in the mockups (missing = pieces of missing work).
const NAMED = {
  'rizal-4a': [
    { name: 'Maria Santos', avg: 0.85, qp: 0.88 },
    { name: 'Juan Dela Cruz', avg: 0.78, qp: 0.76, missing: 1 },
    { name: 'Carlo Reyes', avg: 0.58, qp: 0.6, missing: 3, absences: 2 },
    { name: 'Ana Lopez', avg: 0.94, qp: 0.92, lates: 3 },
  ],
  'boni-5b': [
    { name: 'Junia Rey', avg: 0.7, qp: 0.72, missing: 2, absences: 2 },
    { name: 'Jasmine Siguan', avg: 0.62, qp: 0.8, recentLow: true },
    { name: 'Paolo Garcia', avg: 0.74, qp: 0.81, missing: 1 },
    { name: 'Bea Mendoza', avg: 0.69, qp: 0.78, missing: 1 },
  ],
  'mabi-6c': [
    { name: 'Marky Compas', avg: 0.73, qp: 0.84, inactiveDays: 3 },
    { name: 'Jean Magallanes', avg: 0.88, qp: 0.93 },
    { name: 'Rico Villanueva', avg: 0.64, qp: 0.7, missing: 2 },
    { name: 'Liza Ramos', avg: 0.68, qp: 0.74, missing: 1 },
  ],
  'luna-4b': [],
};

const FIRST = ['Andrea', 'Miguel', 'Sofia', 'Gabriel', 'Isabel', 'Rafael', 'Camille', 'Joshua', 'Angela',
  'Nathan', 'Patricia', 'Daniel', 'Kristine', 'Luis', 'Bianca', 'Enzo', 'Trisha', 'Carlos', 'Mika', 'Adrian',
  'Nicole', 'Paulo', 'Janella', 'Marco', 'Erika', 'Vince', 'Alyssa', 'Kyle', 'Denise', 'Ramon'];
const LAST = ['Aquino', 'Bautista', 'Castillo', 'Dizon', 'Estrada', 'Fernandez', 'Gonzales', 'Hernandez',
  'Ignacio', 'Javier', 'Lim', 'Manalo', 'Navarro', 'Ocampo', 'Pascual', 'Quizon', 'Santiago', 'Tolentino',
  'Umali', 'Valdez', 'Yap', 'Zamora', 'Cruz', 'Del Rosario', 'Mercado', 'Salazar', 'Torres', 'Soriano'];

const TOPICS = {
  4: ['Ang Mapa ng Pilipinas', 'Mga Rehiyon ng Pilipinas', 'Klima at Panahon', 'Mga Anyong Lupa at Tubig',
    'Mga Likas na Yaman', 'Panahon ng Himagsikan', 'Lokal na Pamahalaan', 'Kultura at Tradisyon',
    'Mga Bayani ng Pilipinas', 'Ang Propaganda Movement', 'Rebolusyong Pilipino', 'Kasaysayan ng Pilipinas'],
  5: ['Pinagmulan ng Pilipinas', 'Sinaunang Kabihasnan', 'Pananakop ng Espanya', 'Kristiyanisasyon',
    'Panahon ng Himagsikan', 'Lokal na Pamahalaan', 'Ang Katipunan', 'Andres Bonifacio', 'Kilusang Propaganda',
    'Kalakalang Galyon', 'Sistemang Encomienda', 'Pag-aalsa ng mga Pilipino'],
  6: ['Unang Republika', 'Pananakop ng Amerika', 'Komonwelt', 'Ikalawang Digmaang Pandaigdig',
    'Panahon ng Himagsikan', 'Lokal na Pamahalaan', 'Batas Militar', 'EDSA People Power', 'Ang Saligang Batas',
    'Karapatang Pantao', 'Apolinario Mabini', 'Ikatlong Republika'],
};
// This week's Rizal work, straight from the class page mockup.
const RIZAL_THIS_WEEK = {
  quest: ['The Life and Legacy of Rizal', 'Chapter 1: Early Life'],
  activity: ["Rizal's Writings Analysis", 'Short Answer Questions'],
  boss: ['Rizal and Philippine Nationalism', 'Comprehensive Test'],
};
const HARD = { 'Panahon ng Himagsikan': -0.14, 'Lokal na Pamahalaan': -0.11 };
const POINTS = { quest: 20, quiz: 20, activity: 10, boss: 50, lesson: 0 };

// --------------------------------------------------------------- builder
export function buildSeed(teacherId, now = new Date()) {
  const rand = mulberry32(20260926);
  const pick = (xs) => xs[Math.floor(rand() * xs.length)];
  const noise = (s) => (rand() * 2 - 1) * s;

  const today = startOfDay(now);
  const thisMonday = monday(now);
  const quarterStart = startOfQuarter(now);
  const windowStart = addDays(today, -30);

  const docs = []; // { path, data }
  const put = (path, data) => docs.push({ path, data: { ...data, seed: true } });

  docs.push({ path: `teachers/${teacherId}`, data: {
    displayName: 'Jean Magallanes', email: EMAIL, photoUrl: null, role: 'teacher', status: 'active',
    createdAt: addDays(now, -200) } });
  for (const t of EXTRA_TEACHERS) {
    docs.push({ path: `teachers/${t.uid}`, data: {
      displayName: t.displayName, email: t.email, photoUrl: null, role: 'teacher', status: t.status,
      createdAt: addDays(now, -90) } });
  }
  docs.push({ path: 'settings/school', data: {
    schoolName: 'EduLearn Elementary School', schoolYear: '2026–2027', contactEmail: 'office@edulearn.test' } });

  const allSubs = [];
  const summary = { classes: [], students: 0, activeStudents: 0, missingStudents: 0, pending: 0, activeQuestsThisWeek: 0 };
  const usedNames = new Set(Object.values(NAMED).flat().map((s) => s.name));

  for (const cls of CLASSES) {
    const className = `Grade ${cls.gradeLevel} – ${cls.section}`;
    const active = !cls.archived;

    // ---- students
    const roster = [...NAMED[cls.id]];
    while (roster.length < cls.size) {
      let name;
      do { name = `${pick(FIRST)} ${pick(LAST)}`; } while (usedNames.has(name));
      usedNames.add(name);
      roster.push({ name, avg: clamp(cls.target.a + noise(0.1), 0.6, 0.97), qp: clamp(cls.target.c + 0.15 + noise(0.1), 0.6, 0.99) });
    }
    const students = roster.map((s, i) => ({ ...s, id: `${cls.id}-s${pad(i + 1)}`, number: String(i + 1).padStart(4, '0') }));

    // ---- classwork: 12 past weeks, this week, next week
    const topics = TOPICS[cls.gradeLevel];
    const work = [];
    for (let w = -12; w <= 1; w++) {
      const mon = addDays(thisMonday, w * 7);
      const topic = topics[(w + 12) % topics.length];
      const future = (d) => d >= today;
      const add = (type, dayOffset, title, description, status) => {
        const due = addDays(mon, dayOffset);
        const s = status ?? (w === 1 ? (type === 'activity' || type === 'lesson' ? 'draft' : 'scheduled')
          : type === 'boss' && future(due) ? 'scheduled' : 'published');
        work.push({ id: `${cls.id}-w${w + 12}-${type}`, type, title, description, dueDate: due, status: s,
          difficulty: HARD[topic] ?? noise(0.03), assignedStudentIds: [] });
      };
      const rizalNow = cls.id === 'rizal-4a' && w === 0;
      add('lesson', 0, `Aralin ${w + 13}: ${rizalNow ? 'Ang Buhay ni Rizal' : topic}`, 'Basahin bago ang quest.');
      add('quest', 0, rizalNow ? RIZAL_THIS_WEEK.quest[0] : topic, rizalNow ? RIZAL_THIS_WEEK.quest[1] : 'Weekly quest');
      if (w < 0 && w % 2 !== 0) add('quiz', 2, `Quiz: ${topic}`, 'Automatically graded');
      add('activity', 3, rizalNow ? RIZAL_THIS_WEEK.activity[0] : `${topic} – Gawain`,
        rizalNow ? RIZAL_THIS_WEEK.activity[1] : 'Group activity');
      add('boss', 4, rizalNow ? RIZAL_THIS_WEEK.boss[0] : topic, rizalNow ? RIZAL_THIS_WEEK.boss[1] : 'Friday Boss Assessment');
    }
    const graded = work.filter((w) => w.type !== 'lesson' && w.status !== 'draft');
    const weekEnd = addDays(thisMonday, 7);
    const activeThisWeek = graded.filter((w) => w.dueDate >= thisMonday && w.dueDate < weekEnd).length;
    if (active) summary.activeQuestsThisWeek += activeThisWeek;

    // ---- who is missing what (most recent past-due work in the 30-day window)
    const windowItems = graded
      .filter((w) => w.status === 'published' && w.dueDate < today && w.dueDate >= windowStart)
      .sort((a, b) => b.dueDate - a.dueDate);
    const missingSet = new Set();
    for (const s of students) {
      for (const w of windowItems.slice(0, s.missing ?? 0)) missingSet.add(`${s.id}_${w.id}`);
    }

    // ---- submissions
    const counters = new Map(work.map((w) => [w.id, { submittedCount: 0, scoreSum: 0, scoredCount: 0 }]));
    for (const w of graded) {
      if (w.status !== 'published' || w.dueDate > now) continue;
      for (const s of students) {
        const key = `${s.id}_${w.id}`;
        if (missingSet.has(key)) continue;
        const dueToday = w.dueDate >= today;
        const old = w.dueDate < windowStart;
        if (dueToday && rand() > 0.6) continue;
        if (old && rand() > s.qp + 0.1) continue;
        let submittedAt = addHours(w.dueDate, -Math.floor(rand() * 40) - 2);
        if (submittedAt > now) submittedAt = addHours(now, -1);
        const maxScore = POINTS[w.type];
        const target = s.recentLow && w.dueDate >= addDays(today, -21) ? 0.5 : s.avg;
        const ratio = clamp(target + w.difficulty + noise(0.08), 0.3, 1);
        allSubs.push({ cls, className, s, w, key, submittedAt, maxScore, score: Math.round(ratio * maxScore) });
      }
    }

    // ---- attendance (school days this quarter, up to 60 days back)
    const days = [];
    for (let d = addDays(today, -60); d <= today; d = addDays(d, 1)) {
      if (d >= quarterStart && isWeekday(d)) days.push(d);
    }
    const latest = days[days.length - 1];
    const marks = days.map(() => ({}));
    for (const s of students) {
      days.forEach((_, i) => { marks[i][s.id] = 'present'; });
      const earlier = days.length - 1; // indexes before the latest day
      const spots = (n) => {
        const out = new Set();
        while (out.size < Math.min(n, earlier)) out.add(Math.floor(rand() * earlier));
        return [...out];
      };
      if (s.absences) {
        marks[days.length - 1][s.id] = 'absent';
        for (const i of spots(s.absences - 1)) marks[i][s.id] = 'absent';
      } else if (rand() < 0.3) {
        for (const i of spots(1)) marks[i][s.id] = 'absent';
      }
      if (s.lates) {
        marks[days.length - 1][s.id] = 'late';
        for (const i of spots(s.lates - 1)) if (marks[i][s.id] === 'present') marks[i][s.id] = 'late';
      } else if (rand() < 0.3) {
        for (const i of spots(1 + Math.floor(rand() * 2))) if (marks[i][s.id] === 'present') marks[i][s.id] = 'late';
      }
    }
    days.forEach((d, i) => put(`attendance/${cls.id}_${dayKey(d)}`, {
      teacherId, classId: cls.id, date: d, marks: marks[i] }));

    // ---- student docs (scores filled in after pending submissions are chosen)
    for (const s of students) {
      let absences = 0, lates = 0;
      marks.forEach((m) => { if (m[s.id] === 'absent') absences++; if (m[s.id] === 'late') lates++; });
      s.attendance = { attendanceRate: days.length ? round2((days.length - absences) / days.length) : null,
        absences, lateCount: lates };
      s.classId = cls.id;
      s.gradeLevel = cls.gradeLevel;
    }

    cls._students = students;
    cls._work = work;
    cls._counters = counters;
    cls._missingSet = missingSet;
    cls._windowItems = windowItems;
    cls._className = className;
    cls._latest = latest;
    cls._latestMarks = marks[marks.length - 1];
  }

  // ---- the 14 most recent submissions (active classes) are waiting for review
  const activeIds = new Set(CLASSES.filter((c) => !c.archived).map((c) => c.id));
  const pending = new Set(allSubs.filter((x) => activeIds.has(x.cls.id))
    .sort((a, b) => b.submittedAt - a.submittedAt).slice(0, 14).map((x) => x.key));
  summary.pending = pending.size;

  const perStudent = new Map();
  allSubs.forEach((x, i) => {
    const isPending = pending.has(x.key);
    const returnedAt = isPending ? null
      : (addHours(x.submittedAt, 20) > now ? addHours(now, -1) : addHours(x.submittedAt, 20));
    put(`submissions/sub-${String(i).padStart(5, '0')}`, {
      teacherId, classId: x.cls.id, studentId: x.s.id, studentName: x.s.name, gradeLevel: x.cls.gradeLevel,
      classworkId: x.w.id, classworkTitle: x.w.title, classworkType: x.w.type,
      submittedAt: x.submittedAt, status: isPending ? 'pending' : 'returned',
      score: isPending ? null : x.score, maxScore: x.maxScore, privateFeedback: '',
      returnedAt, attachmentUrl: null,
    });
    const c = x.cls._counters.get(x.w.id);
    c.submittedCount++;
    if (!isPending) {
      c.scoreSum += x.score / x.maxScore;
      c.scoredCount++;
      if ((returnedAt ?? x.submittedAt) >= quarterStart) {
        const list = perStudent.get(x.s.id) ?? [];
        list.push({ ratio: x.score / x.maxScore, at: returnedAt });
        perStudent.set(x.s.id, list);
      }
    }
  });

  // ---- write classes, classwork, students, missing work, charts, reports
  for (const cls of CLASSES) {
    const active = !cls.archived;
    const students = cls._students;
    const questCount = cls._work.filter((w) => w.type !== 'lesson' && w.status === 'published'
      && w.dueDate >= addDays(today, -14)).length;

    put(`classCodes/${cls.classCode}`, { classId: cls.id, createdAt: addDays(today, -200) });
    put(`classes/${cls.id}`, {
      teacherId, gradeLevel: cls.gradeLevel, section: cls.section, subject: 'Araling Panlipunan',
      classCode: cls.classCode, status: active ? 'active' : 'archived', studentCount: students.length,
      questCount, completionRate: cls.target.c, averageScore: cls.target.a, coverImageUrl: null,
      colorIndex: cls.colorIndex, archivedAt: active ? null : addDays(today, -45),
    });

    for (const w of cls._work) {
      const c = cls._counters.get(w.id);
      put(`classwork/${w.id}`, {
        teacherId, classId: cls.id, className: cls._className, type: w.type, title: w.title,
        description: w.description, dueDate: w.dueDate, status: w.status, points: POINTS[w.type],
        attachmentUrl: null, attachmentName: null, assignedStudentIds: [],
        submittedCount: c.submittedCount, scoreSum: round2(c.scoreSum), scoredCount: c.scoredCount,
        createdAt: addDays(w.dueDate, -5),
      });
    }

    let withMissing = 0;
    for (const s of students) {
      const missingCount = [...cls._missingSet].filter((k) => k.startsWith(`${s.id}_`)).length;
      if (missingCount > 0) withMissing++;
      const results = (perStudent.get(s.id) ?? []).sort((a, b) => b.at - a.at);
      const avg = (xs) => (xs.length ? round2(xs.reduce((t, r) => t + r.ratio, 0) / xs.length) : null);
      put(`students/${s.id}`, {
        teacherId, classId: cls.id, name: s.name, studentNumber: s.number, gradeLevel: cls.gradeLevel,
        questProgress: round2(s.qp), ...s.attendance, averageScore: avg(results),
        recentScore: avg(results.slice(0, 3)), missingCount,
        lastActiveAt: addHours(now, -(s.inactiveDays ? s.inactiveDays * 24 + 2 : 2 + Math.floor(rand() * 20))),
        photoUrl: null, fcmTokens: [],
      });
    }
    if (active) {
      summary.activeStudents += students.length;
      summary.missingStudents += withMissing;
    }
    summary.students += students.length;

    const byId = new Map(students.map((s) => [s.id, s]));
    for (const key of cls._missingSet) {
      const [studentId, workId] = [key.slice(0, key.indexOf('_')), key.slice(key.indexOf('_') + 1)];
      const w = cls._work.find((x) => x.id === workId);
      put(`missingWork/${key}`, {
        teacherId, classId: cls.id, studentId, studentName: byId.get(studentId).name,
        classworkId: w.id, classworkTitle: w.title, classworkType: w.type, dueDate: w.dueDate,
      });
    }

    // Class Performance chart: weekday scores for the last ~4 months
    for (let d = addDays(today, -120); d <= today; d = addDays(d, 1)) {
      if (!isWeekday(d)) continue;
      const progress = 1 - (today - d) / (120 * DAY);
      put(`classes/${cls.id}/dailyPerformance/${dayKey(d)}`, {
        date: d, score: round2(clamp(cls.target.a - 0.07 + 0.09 * progress + noise(0.035), 0.4, 0.99)) });
    }

    // Monthly report rows: quarter means hit target (and target − delta last quarter)
    const qNow = startOfQuarter(now);
    for (let k = 0; k < 6; k++) {
      const qp = parts(qNow);
      const qStart = manila(qp.y, qp.mo - 3 * k, 1);
      const shrink = k === 0 ? 0 : 1 + (k - 1) * 0.35; // older quarters improve less
      const mean = {
        c: clamp(cls.target.c - cls.delta.c * shrink, 0.25, 0.99),
        a: clamp(cls.target.a - cls.delta.a * shrink, 0.35, 0.99),
        t: clamp(cls.target.t - cls.delta.t * shrink, 0.6, 0.99),
        m: cls.target.m + (k === 0 ? 0 : cls.delta.m + (k - 1)),
      };
      const months = [0, 1, 2].map((i) => manila(parts(qStart).y, parts(qStart).mo + i, 1)).filter((m) => m <= now);
      const offsets = { 1: [0], 2: [-0.005, 0.005], 3: [-0.01, 0, 0.01] }[months.length] ?? [];
      months.forEach((m, i) => put(`classes/${cls.id}/monthlyStats/${monthKey(m)}`, {
        month: m,
        completion: round2(mean.c + offsets[i]),
        averageScore: round2(mean.a + offsets[i]),
        attendance: round2(mean.t + offsets[i] / 2),
        missingWork: mean.m + (months.length - 1 - i),
      }));
    }
  }

  // ---- class requests (admin website → Class Requests)
  put('classRequests/seed-req1', { teacherId, gradeLevel: 5, section: 'Silang', subject: 'Araling Panlipunan',
    note: 'New section for incoming transferees.', status: 'pending', createdAt: addHours(now, -20) });
  put('classRequests/seed-req2', { teacherId: 'teacher-rosa', gradeLevel: 6, section: 'Aguinaldo',
    subject: 'Araling Panlipunan', note: 'I can take the afternoon block.', status: 'pending',
    createdAt: addHours(now, -52) });
  put('classRequests/seed-req3', { teacherId, gradeLevel: 4, section: 'Luna', subject: 'Araling Panlipunan',
    note: '', status: 'declined', decisionNote: 'Grade 4 – Luna was merged into Rizal this year.',
    createdAt: addDays(now, -40), decidedAt: addDays(now, -39) });

  // ---- announcements, activity, notifications
  const ago = (h) => addHours(now, -h);
  put('announcements/seed-a1', { teacherId, classId: 'rizal-4a', pinned: false, createdAt: ago(5),
    title: "Reminder: Please read Chapter 1 before Monday's quest.",
    body: 'Chapter 1 covers Rizal’s early life in Calamba. Bring your notes to class.' });
  put('announcements/seed-a2', { teacherId, classId: 'rizal-4a', pinned: false, createdAt: ago(50),
    title: "Good job on the quiz! Let's keep it up!", body: 'Class average went up this week. Salamat!' });
  put('announcements/seed-a3', { teacherId, classId: null, pinned: true, createdAt: ago(28),
    title: 'Field trip forms are now available', body: 'Please return the signed forms by Friday.' });
  put('announcements/seed-a4', { teacherId, classId: 'boni-5b', pinned: false, createdAt: ago(75),
    title: 'Friday Boss Assessment this week', body: 'Review Aralin 1–3. Good luck, Bonifacio!' });

  const act = (id, classId, kind, title, subtitle, h) =>
    put(`activity/${id}`, { teacherId, classId, kind, title, subtitle, createdAt: ago(h) });
  act('seed-r1', 'rizal-4a', 'submitted', 'Maria Santos submitted a quiz', 'The Life and Legacy of Rizal', 2);
  act('seed-r2', 'rizal-4a', 'joined', 'Juan Dela Cruz joined the class', '', 3);
  act('seed-r3', 'rizal-4a', 'announcement', 'You posted an announcement',
    '“Reminder: Please read Chapter 1 before Monday\'s quest.”', 5);
  act('seed-r4', 'rizal-4a', 'published', 'New quiz published: Ang Propaganda Movement', '', 6);
  act('seed-r5', 'rizal-4a', 'completed', '15 students completed the activity', "Rizal's Writings Analysis", 24);
  act('seed-r6', 'rizal-4a', 'missed', 'Carlo Reyes missed a quiz', 'The Life and Legacy of Rizal', 26);
  act('seed-b1', 'boni-5b', 'submitted', 'Paolo Garcia submitted a quest', 'Pananakop ng Espanya', 1);
  act('seed-b2', 'boni-5b', 'announcement', 'You posted an announcement', '“Friday Boss Assessment this week”', 75);
  act('seed-b3', 'boni-5b', 'missed', 'Junia Rey missed a quest', 'Kristiyanisasyon', 30);
  act('seed-m1', 'mabi-6c', 'submitted', 'Jean Magallanes submitted an activity', 'Komonwelt – Gawain', 4);
  act('seed-m2', 'mabi-6c', 'completed', '19 students completed the quest', 'Unang Republika', 28);

  const note = (id, kind, title, h, read) =>
    put(`teachers/${teacherId}/notifications/${id}`, { kind, title, createdAt: ago(h), read });
  note('seed-n1', 'submissions', '5 new submissions for Monday Quest', 0.2, false);
  note('missing_boni-5b', 'missingWork', '3 students have missing work in Grade 5 – Bonifacio', 1, false);
  note('seed-n3', 'schedule', 'Friday Boss Assessment is tomorrow', 3, true);
  note('seed-n4', 'general', 'Welcome to EduLearn! Your classes are ready.', 48, true);

  for (const cls of CLASSES) {
    const m = cls._latestMarks ?? {};
    const count = (v) => Object.values(m).filter((x) => x === v).length;
    summary.classes.push({
      id: cls.id, code: cls.classCode, students: cls._students.length, archived: !!cls.archived,
      missingStudents: new Set([...cls._missingSet].map((k) => k.split('_')[0])).size,
      classwork: cls._work.length, latestAttendance: `${count('present')} present / ${count('late')} late / ${count('absent')} absent`,
    });
  }
  summary.teachers = 1 + EXTRA_TEACHERS.length;
  summary.pendingRequests = 2;
  summary.submissions = allSubs.length;
  summary.documents = docs.length;
  return { docs, summary };
}

// ----------------------------------------------------------------- writer
async function main() {
  if (flag('dry-run')) {
    const { summary } = buildSeed('DRY-RUN-TEACHER');
    console.log(JSON.stringify(summary, null, 2));
    return;
  }

  // The demo project only exists in the emulators — point there automatically.
  if (PROJECT.startsWith('demo-')) {
    process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
    process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
  }
  const { initializeApp } = await import('firebase-admin/app');
  const { getAuth } = await import('firebase-admin/auth');
  const { getFirestore } = await import('firebase-admin/firestore');
  initializeApp({ projectId: PROJECT });
  const emulated = !!process.env.FIRESTORE_EMULATOR_HOST;
  console.log(`Seeding project "${PROJECT}"${emulated ? ' (emulators)' : ''}…`);

  const auth = getAuth();
  let user;
  try {
    user = await auth.getUserByEmail(EMAIL);
  } catch {
    user = await auth.createUser({ email: EMAIL, password: PASSWORD, displayName: 'Jean Magallanes' });
    console.log(`Created sign-in: ${EMAIL} / ${PASSWORD}`);
  }
  await auth.setCustomUserClaims(user.uid, { role: 'teacher' });

  // More teachers (so the admin Teachers page has something to show)
  for (const t of EXTRA_TEACHERS) {
    try {
      await auth.getUser(t.uid);
    } catch {
      await auth.createUser({ uid: t.uid, email: t.email, password: PASSWORD, displayName: t.displayName });
    }
    await auth.updateUser(t.uid, { disabled: t.status === 'disabled' });
    await auth.setCustomUserClaims(t.uid, { role: 'teacher' });
  }

  // Admin website sign-in
  let admin;
  try {
    admin = await auth.getUserByEmail(ADMIN_EMAIL);
  } catch {
    admin = await auth.createUser({ email: ADMIN_EMAIL, password: PASSWORD, displayName: 'Carmela Santos' });
    console.log(`Created admin sign-in: ${ADMIN_EMAIL} / ${PASSWORD}`);
  }
  await auth.setCustomUserClaims(admin.uid, { role: 'admin' });

  const db = getFirestore();

  if (flag('reset')) {
    console.log('Removing earlier data for this teacher…');
    const owned = ['students', 'classwork', 'submissions', 'announcements', 'activity', 'missingWork',
      'attendance', 'reminders', 'classRequests'];
    for (const name of owned) {
      const snap = await db.collection(name).where('teacherId', '==', user.uid).get();
      const w = db.bulkWriter();
      snap.docs.forEach((d) => w.delete(d.ref));
      await w.close();
    }
    const classes = await db.collection('classes').where('teacherId', '==', user.uid).get();
    for (const c of classes.docs) await db.recursiveDelete(c.ref);
    for (const name of ['classCodes', 'classRequests']) {
      const snap = await db.collection(name).get();
      const w = db.bulkWriter();
      snap.docs.filter((d) => d.get('seed') === true).forEach((d) => w.delete(d.ref));
      await w.close();
    }
    await db.recursiveDelete(db.collection('teachers').doc(user.uid));
  }

  const { docs, summary } = buildSeed(user.uid);
  const writer = db.bulkWriter();
  for (const { path, data } of docs) writer.set(db.doc(path), data);
  writer.set(db.doc(`admins/${admin.uid}`), {
    displayName: admin.displayName ?? 'Administrator', email: ADMIN_EMAIL, seed: true, addedAt: new Date() });
  await writer.close();

  console.log(`Wrote ${docs.length} documents.`);
  console.log(JSON.stringify(summary, null, 2));
  console.log(`\nTeacher website: ${EMAIL} / ${PASSWORD}`);
  console.log(`Admin website:   ${ADMIN_EMAIL} / ${PASSWORD}`);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
