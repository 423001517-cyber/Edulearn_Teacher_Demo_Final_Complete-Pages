#!/usr/bin/env node
/**
 * Seeds Firestore (+ an Auth user) with demo data that matches the mockups:
 * Teacher Jean, Grade 4 – Rizal (RIZAL-4A), Grade 5 – Bonifacio (BONI-5B),
 * Grade 6 – Mabini (MABI-6C), one archived class, 68 active students,
 * 7 students with missing work, 14 submissions to review, 9 active quests
 * this week, and a quarter-over-quarter report trend (+12% completion …).
 * Also attendance (with excused days and notes), chats for the Messages page,
 * and reward requests / bonus points for the Rewards page.
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
/** School quarter 1–4 (school year starts in June), like schoolQuarter() in edulearn_core. */
const schoolQuarter = (d) => Math.floor(((parts(d).mo + 1 - 6 + 12) % 12) / 3) + 1;
const TYPE_ORDER = { lesson: 1, quest: 2, quiz: 3, activity: 4, boss: 5, material: 6 };
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
const mc = (id, text, choices, correctIndex, explanation = '') =>
  ({ id, text, type: 'multipleChoice', choices, correctIndex, answer: '', points: 1, explanation });
const QUIZ_QUESTIONS = [
  mc('q1', 'Alin sa mga sumusunod ang isang anyong lupa?', ['Bundok', 'Look ng Dagat', 'Golpo', 'Kipot'], 0),
  mc('q2', 'Ano ang tawag sa malawak na anyong tubig na nasa pagitan ng mga kontinente?', ['Ilog', 'Karagatan', 'Lawa', 'Talon'], 1),
  mc('q3', 'Alin ang pinakamataas na bundok sa Pilipinas?', ['Bundok Pulag', 'Bundok Apo', 'Bulkang Mayon', 'Bundok Banahaw'], 1),
  { id: 'q4', text: 'Ang Bulkang Mayon ay matatagpuan sa Albay.', type: 'trueFalse', choices: ['Tama', 'Mali'],
    correctIndex: 0, answer: '', points: 1, explanation: '' },
  { id: 'q5', text: 'Ano ang tawag sa lupang napaliligiran ng tubig?', type: 'shortAnswer', choices: [],
    correctIndex: 0, answer: 'pulo', points: 1, explanation: 'Pulo o isla ang lupang napaliligiran ng tubig.' },
];
const BOSS_QUESTIONS = [
  mc('b1', 'Ano ang rehiyon ng Pilipinas na kilala sa mga bulkan?', ['Rehiyon V – Bicol', 'NCR', 'Rehiyon III', 'CAR'], 0,
    'Nasa Bicol ang Bulkang Mayon at iba pang bulkan.'),
  mc('b2', 'Aling rehiyon ang may pinakamahabang baybayin?', ['Rehiyon IV-B – MIMAROPA', 'CAR', 'NCR', 'Rehiyon II'], 0),
  mc('b3', 'Alin sa mga sumusunod ang produkto ng Rehiyon IV-A?', ['Kape', 'Abaka', 'Tabako', 'Perlas'], 0),
  mc('b4', 'Ilan ang rehiyon ng Pilipinas?', ['12', '15', '17', '20'], 2),
  mc('b5', 'Saang rehiyon matatagpuan ang Banaue Rice Terraces?', ['CAR', 'Rehiyon I', 'Rehiyon VII', 'BARMM'], 0),
];

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
    createdAt: addDays(now, -200),
    // Settings › Profile
    titleName: 'Teacher Jean', subject: 'Araling Panlipunan', gradeLevels: [4, 5, 6],
    bio: 'Magandang araw! Ako si Teacher Jean. Sabay-sabay nating tuklasin ang kasaysayan at kultura ng Pilipinas.' } });
  for (const t of EXTRA_TEACHERS) {
    docs.push({ path: `teachers/${t.uid}`, data: {
      displayName: t.displayName, email: t.email, photoUrl: null, role: 'teacher', status: t.status,
      createdAt: addDays(now, -90) } });
  }
  docs.push({ path: 'settings/school', data: {
    schoolName: 'Philippine Cultural College', schoolYear: '2026–2027', contactEmail: 'office@edulearn.test' } });

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
    // Excused days (absent with a parent's note), notes, and arrival times on
    // the latest day. A separate random stream keeps every other number the same.
    const ex = mulberry32(7919 * cls.gradeLevel + cls.size);
    const notes = days.map(() => ({}));
    const times = days.map(() => ({}));
    for (const s of students) {
      if (ex() < 0.15 && days.length > 2) {
        const i = Math.floor(ex() * (days.length - 1));
        if (marks[i][s.id] === 'present') {
          marks[i][s.id] = 'excused';
          notes[i][s.id] = 'Medical check-up, note received';
        }
      }
    }
    const last = days.length - 1;
    if (last >= 0) {
      const calm = students.filter((s) => !s.absences && !s.lates && marks[last][s.id] === 'present');
      const excusedToday = calm[calm.length - 1];
      if (excusedToday) {
        marks[last][excusedToday.id] = 'excused';
        notes[last][excusedToday.id] = 'Medical check-up, note received';
      }
      const lateNamed = students.find((s) => s.lates);
      if (lateNamed) notes[last][lateNamed.id] = 'Came with a parent';
      for (const s of students) {
        const m = marks[last][s.id];
        if (m === 'present') times[last][s.id] = addHours(days[last], 6.8 + ex() * 0.65); // 6:48–7:27 AM
        if (m === 'late') times[last][s.id] = addHours(days[last], 7.55 + ex() * 0.4); // 7:33–7:57 AM
      }
    }
    days.forEach((d, i) => put(`attendance/${cls.id}_${dayKey(d)}`, {
      teacherId, classId: cls.id, date: d, marks: marks[i], notes: notes[i], times: times[i], savedAt: addHours(d, 8) }));

    // ---- student docs (scores filled in after pending submissions are chosen)
    for (const s of students) {
      let absences = 0, lates = 0, excused = 0;
      marks.forEach((m) => {
        if (m[s.id] === 'absent') absences++;
        if (m[s.id] === 'late') lates++;
        if (m[s.id] === 'excused') excused++;
      });
      const counted = days.length - excused;
      s.attendance = { attendanceRate: counted ? round2((counted - absences) / counted) : null,
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
      // Edit class details / Class settings
      room: `Grade ${cls.gradeLevel} Room`,
      description: cls.id === 'rizal-4a'
        ? 'Magandang araw, Grade 4 – Rizal! Sama-sama tayong matuto at tuklasin ang ating bansa.' : '',
      streamPermission: 'postAndComment', classworkNotifications: 'condensed',
      totalPoints: 20, showOverallGrade: true,
    });

    // Classwork topics: one per week ("Week 13: Mga Rehiyon ng Pilipinas").
    const weekTopics = TOPICS[cls.gradeLevel];
    for (let idx = 0; idx < 14; idx++) {
      put(`classes/${cls.id}/topics/${cls.id}-t${idx}`, {
        name: `Week ${idx + 1}: ${weekTopics[idx % weekTopics.length]}`, position: idx + 1 });
    }

    for (const w of cls._work) {
      const c = cls._counters.get(w.id);
      const idx = Number(w.id.match(/-w(\d+)-/)[1]);
      put(`classwork/${w.id}`, {
        teacherId, classId: cls.id, className: cls._className, type: w.type, title: w.title,
        description: w.description, dueDate: w.dueDate, status: w.status, points: POINTS[w.type],
        attachmentUrl: null, attachmentName: null, assignedStudentIds: [],
        submittedCount: c.submittedCount, scoreSum: round2(c.scoreSum), scoredCount: c.scoredCount,
        createdAt: addDays(w.dueDate, -5),
        topicId: `${cls.id}-t${idx}`, quarter: schoolQuarter(w.dueDate), position: TYPE_ORDER[w.type],
        publishAt: w.status === 'scheduled' ? addDays(w.dueDate, -3) : null,
        attachments: [], postToStream: true, notifyStudents: true, allowLate: w.type !== 'boss',
        ...(w.type === 'quest' ? { xpReward: 100, coinReward: 25, attempts: 3, difficulty: 'medium' } : {}),
        ...(w.type === 'quiz' ? { timeLimitMinutes: 20, attempts: 1, shuffleQuestions: true, shuffleChoices: true,
          showScoreImmediately: true, autoGrade: true } : {}),
        ...(w.type === 'boss' ? { timeLimitMinutes: 30, attempts: 1, difficulty: 'hard', passingScore: 70,
          bossId: 'kapuluan', bossHp: 100, xpReward: 75, rewardBadge: 'Rehiyon Master',
          shuffleQuestions: true, showExplanations: true,
          questionCount: w.id === 'rizal-4a-w12-boss' ? BOSS_QUESTIONS.length : 0 } : {}),
        ...(w.type === 'activity' ? { submissionType: 'file', groupWork: false, rubric: [] } : {}),
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
    status: 'published', attachments: [], commentCount: 0,
    title: "Reminder: Please read Chapter 1 before Monday's quest.",
    body: 'Chapter 1 covers Rizal’s early life in Calamba. Bring your notes to class.' });
  put('announcements/seed-a2', { teacherId, classId: 'rizal-4a', pinned: false, createdAt: ago(50),
    status: 'published', attachments: [], commentCount: 0,
    title: "Good job on the quiz! Let's keep it up!", body: 'Class average went up this week. Salamat!' });
  put('announcements/seed-a3', { teacherId, classId: null, pinned: true, createdAt: ago(28),
    status: 'published', attachments: [], commentCount: 0,
    title: 'Field trip forms are now available', body: 'Please return the signed forms by Friday.' });
  put('announcements/seed-a4', { teacherId, classId: 'boni-5b', pinned: false, createdAt: ago(75),
    status: 'published', attachments: [], commentCount: 0,
    title: 'Friday Boss Assessment this week', body: 'Review Aralin 1–3. Good luck, Bonifacio!' });

  // ---- class stream (Stream page) for Grade 4 – Rizal, matching the design.
  // Due dates fall after this week, so dashboard counts don't change.
  const at = (day, h, m = 0) => { const d = new Date(day); d.setHours(h, m, 0, 0); return d; };
  const nextMon = addDays(thisMonday, 7);
  const rizalName = 'Grade 4 – Rizal';
  const streamWork = [
    { id: 'rizal-4a-stream-assign', type: 'quest', title: 'Mga Rehiyon ng Pilipinas',
      description: 'Gumawa ng isang maikling ulat o presentasyon tungkol sa rehiyon na iyong napili.',
      dueDate: at(nextMon, 23, 59), createdAt: at(addDays(today, -2), 14, 15) },
    { id: 'rizal-4a-stream-quiz', type: 'quiz', title: 'Quiz: Anyong Lupa at Tubig',
      description: 'Sagutan ang 20-item multiple choice quiz tungkol sa anyong lupa at anyong tubig ng Pilipinas.',
      dueDate: at(addDays(nextMon, 2), 23, 59), createdAt: at(addDays(today, -3), 10, 0) },
    { id: 'rizal-4a-stream-reflection', type: 'activity', title: 'Reading Reflection',
      description: 'Isulat ang iyong repleksyon tungkol sa binasang materyal (5–8 pangungusap).',
      dueDate: at(addDays(nextMon, 4), 23, 59), createdAt: at(addDays(today, -1), 9, 0) },
    { id: 'rizal-4a-stream-material', type: 'material', title: 'Reading Material: Kasaysayan ng Pilipinas',
      description: 'Basahin ang mga pahina 1–10 at sagutin ang gabay na tanong sa dulo ng materyal na talakayan.',
      dueDate: at(addDays(today, -4), 13, 45), createdAt: at(addDays(today, -4), 13, 45),
      attachmentName: 'Kasaysayan_ng_Pilipinas.pdf', attachmentSize: 5452595, commentCount: 3 },
  ];
  for (const w of streamWork) {
    put(`classwork/${w.id}`, {
      teacherId, classId: 'rizal-4a', className: rizalName, type: w.type, title: w.title,
      description: w.description, dueDate: w.dueDate, status: 'published', points: POINTS[w.type],
      attachmentUrl: null, attachmentName: w.attachmentName ?? null, attachmentSize: w.attachmentSize ?? null,
      assignedStudentIds: [], submittedCount: 0, scoreSum: 0, scoredCount: 0,
      commentCount: w.commentCount ?? 0, createdAt: w.createdAt,
      topicId: w.type === 'material' ? 'rizal-4a-t12' : 'rizal-4a-t13', quarter: schoolQuarter(w.dueDate),
      position: 10 + (TYPE_ORDER[w.type] ?? 0), attachments: [], postToStream: true, notifyStudents: true,
      allowLate: true,
      ...(w.type === 'quest' ? { xpReward: 100, coinReward: 25, attempts: 3, difficulty: 'medium' } : {}),
      ...(w.type === 'quiz' ? { timeLimitMinutes: 20, attempts: 1, shuffleQuestions: true, shuffleChoices: true,
        showScoreImmediately: true, autoGrade: true, questionCount: QUIZ_QUESTIONS.length } : {}),
      ...(w.type === 'activity' ? { submissionType: 'text', groupWork: false,
        rubric: [{ title: 'Nilalaman', description: 'Wasto at buo ang repleksyon', points: 6 },
                 { title: 'Kalinawan', description: 'Malinaw ang pagkakasulat', points: 4 }] } : {}),
    });
  }
  // Answer keys live in classwork/{id}/private/questions (teacher-only).
  put('classwork/rizal-4a-stream-quiz/private/questions', { questions: QUIZ_QUESTIONS });
  put(`classwork/rizal-4a-w12-boss/private/questions`, { questions: BOSS_QUESTIONS });

  const welcomeAt = ago(52);
  put('announcements/seed-welcome', { teacherId, classId: 'rizal-4a', pinned: false, status: 'published',
    createdAt: welcomeAt, publishAt: null, commentCount: 5, title: 'Welcome to Quarter 1!',
    body: 'Magandang araw, Grade 4 – Rizal! Sana ay maging makabuluhan at masaya ang ating paglalakbay '
      + 'sa Araling Panlipunan ngayong unang markahan. Sama-sama nating tuklasin ang ating bansa!',
    attachments: [{ name: 'Q1_Class_Orientation.pdf', url: null, kind: 'file', sizeBytes: 2516582, storagePath: null }] });
  const comment = (post, id, author, mins, body) => put(`${post}/comments/${id}`, {
    authorId: author.id, authorName: author.name, authorRole: author.role, body, attachment: null,
    createdAt: addHours(post.includes('seed-welcome') ? welcomeAt : streamWork[3].createdAt, mins / 60) });
  const rz = (n, name) => ({ id: `rizal-4a-s${pad(n)}`, name, role: 'student' });
  const jean = { id: teacherId, name: 'Jean Magallanes', role: 'teacher' };
  const welcome = 'announcements/seed-welcome';
  comment(welcome, 'c1', rz(1, 'Maria Santos'), 32,
    'Excited po ako sa bagong quarter, Teacher! Maraming salamat po sa malinaw na paliwanag. '
    + 'Sana po masaya at makabuluhan ang ating klase ngayong taon. 😊');
  comment(welcome, 'c2', rz(2, 'Juan Dela Cruz'), 45, 'Salamat po, Teacher Jean! Looking forward po sa mga bagong aralin. 💚');
  comment(welcome, 'c3', rz(4, 'Ana Lopez'), 58,
    'Ang ganda po ng tema ngayong quarter. Interesado po talaga ako sa kasaysayan ng Pilipinas. Maraming salamat po!');
  comment(welcome, 'c4', rz(3, 'Carlo Reyes'), 71,
    'Sana po marami tayong talakayan at gawain na pangkatang activity. Excited po ako makipagtulungan sa aking mga kaklase! 😊');
  comment(welcome, 'c5', jean, 95,
    'Maraming salamat sa inyong lahat! Excited din po ako na makasama kayo ngayong quarter. '
    + 'Sama-sama tayong matuto at tuklasin ang ganda ng ating bansa. 🇵🇭 💚');
  const material = 'classwork/rizal-4a-stream-material';
  comment(material, 'c1', rz(1, 'Maria Santos'), 40, 'Teacher, kasama po ba ang pahina 10 sa babasahin?');
  comment(material, 'c2', jean, 55, 'Oo, Maria — hanggang pahina 10, kasama ang gabay na tanong. 👍');
  comment(material, 'c3', rz(4, 'Ana Lopez'), 90, 'Salamat po! Nabasa ko na po ang unang limang pahina.');

  // Calendar → school and class events
  const evt = (id, title, day, kind, extra = {}) => put(`calendarEvents/${id}`, {
    teacherId, title, start: day, end: null, allDay: true, classId: null, kind, location: '', notes: '', ...extra });
  evt('seed-ev1', 'Faculty Meeting', at(addDays(nextMon, 2), 15, 0), 'school',
    { allDay: false, end: at(addDays(nextMon, 2), 16, 30), location: 'Faculty Room' });
  evt('seed-ev2', 'Buwan ng Wika Program', at(addDays(nextMon, 11), 8, 0), 'school', { location: 'Covered Court' });
  evt('seed-ev3', 'Field trip: Pambansang Museo', at(addDays(nextMon, 4), 7, 0), 'classEvent',
    { classId: 'rizal-4a', notes: 'Dalhin ang pirmadong permission slip.' });

  // A scheduled post and a draft (Stream → "All posts" filter → Scheduled / Drafts)
  const tomorrow8 = at(addDays(today, 1), 8, 0);
  put('announcements/seed-scheduled', { teacherId, classId: 'rizal-4a', pinned: false, status: 'scheduled',
    createdAt: ago(1), publishAt: tomorrow8, commentCount: 0, attachments: [],
    title: 'Paalala: Quiz sa Miyerkules',
    body: 'Huwag kalimutan ang **Quiz: Anyong Lupa at Tubig** sa susunod na Miyerkules. Balikan ang inyong mga tala!' });
  put('announcements/seed-draft', { teacherId, classId: 'rizal-4a', pinned: false, status: 'draft',
    createdAt: ago(3), publishAt: null, commentCount: 0, attachments: [],
    title: 'Gabay sa field trip',
    body: '• Dalhin ang pirmadong form\n• Magdala ng baon at tubig\n• Isuot ang PE uniform' });

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

  // ---- Messages: chats with students and class groups (Messages page)
  const rizal = CLASSES.find((c) => c.id === 'rizal-4a');
  const boni = CLASSES.find((c) => c.id === 'boni-5b');
  const rs = rizal._students;
  const firstOf = (name) => name.split(' ')[0];
  let unreadMessages = 0;
  const convo = (id, data, msgs) => {
    const lastMsg = msgs[msgs.length - 1];
    const fromStudent = lastMsg.role === 'student';
    unreadMessages += data.unread ?? 0;
    put(`conversations/${id}`, {
      teacherId, studentsCanReply: true, quietHours: true, unread: 0, studentId: null,
      createdAt: addHours(now, -(msgs[0].h + 1)), ...data,
      lastMessage: lastMsg.body || (lastMsg.file ? `Sent a file: ${lastMsg.file}` : ''),
      lastMessageAt: addHours(now, -lastMsg.h),
      lastRole: fromStudent ? 'student' : 'teacher',
      lastAuthor: fromStudent ? firstOf(lastMsg.name) : 'Teacher',
    });
    msgs.forEach((m, i) => put(`conversations/${id}/messages/m${String(i + 1).padStart(2, '0')}`, {
      authorId: m.role === 'teacher' ? teacherId : m.id,
      authorName: m.role === 'teacher' ? 'Teacher Jean' : m.name,
      authorRole: m.role,
      body: m.body,
      createdAt: addHours(now, -m.h),
      attachment: m.file ? { name: m.file, url: null, kind: 'file', sizeBytes: 482113, storagePath: null } : null,
      classworkId: null, classworkTitle: null,
    }));
  };
  const T = (h, body) => ({ role: 'teacher', h, body });
  const S = (st, h, body, file) => ({ role: 'student', id: st.id, name: st.name, h, body, file });
  const [maria, juan, carlo, ana] = rs;
  convo(`dm_${teacherId}_${juan.id}`, { classId: 'rizal-4a', kind: 'student', studentId: juan.id, title: juan.name, unread: 1 }, [
    S(juan, 1.3, 'Good morning po, Teacher Jean!'),
    S(juan, 1.28, 'Nakalimutan ko pong i-submit ang activity natin kahapon. Pwede pa po ba?'),
    T(1.1, 'Good morning, Juan! Yes, you can still turn it in until 5:00 PM today.'),
    S(juan, 0.9, 'Salamat po! Ito po ang mapa ko. Tama na po ba ang kulay ng Rehiyon V?', 'rehiyon-map-juan.png'),
  ]);
  convo('class_rizal-4a', { classId: 'rizal-4a', kind: 'group', title: 'Grade 4 – Rizal' }, [
    T(26, 'Hello, Grade 4 – Rizal! Paalala: ang Friday Boss natin ay sa Biyernes, 8:00 AM.'),
    S(ana, 25.9, 'Yes po, Teacher! Nag-review na po kami.'),
    S(maria, 25.8, 'Teacher, kasama po ba ang Klima at Panahon?'),
    T(25.6, 'Hindi pa, Maria. Ang aralin lang natin ngayong linggo. Nasa Classwork ang review quest.'),
  ]);
  convo(`dm_${teacherId}_${carlo.id}`, { classId: 'rizal-4a', kind: 'student', studentId: carlo.id, title: carlo.name, unread: 1 }, [
    S(carlo, 64, 'Teacher, paano po gagawin ang quest? Hindi ko po maintindihan ang mapa.'),
  ]);
  convo(`dm_${teacherId}_${ana.id}`, { classId: 'rizal-4a', kind: 'student', studentId: ana.id, title: ana.name }, [
    S(ana, 170, 'Teacher, tapos ko na po lahat ng quests this week.'),
    T(169.8, 'Great job, Ana! Ang galing mo. Keep it up!'),
    S(ana, 169.7, 'Salamat po, Teacher!'),
  ]);
  const paolo = boni._students[2];
  convo('class_boni-5b', { classId: 'boni-5b', kind: 'group', title: 'Grade 5 – Bonifacio' }, [
    S(paolo, 240, 'Teacher, saan po makikita ang quiz natin?'),
    T(239.5, `Nasa Classwork, ${firstOf(paolo.name)}, sa ilalim ng topic ngayong linggo.`),
  ]);

  // ---- Rewards: requests from the student app and points given by hand
  const shop = { 'line-leader': ['Line leader for a day', 150], 'class-game': ['Pick the class review game', 200],
    seat: ['Choose your seat for a day', 120] };
  let pendingRequests = 0;
  const request = (n, st, item, status, h) => {
    if (status === 'pending') pendingRequests++;
    put(`rewardRequests/seed-rr${n}`, {
      teacherId, classId: 'rizal-4a', studentId: st.id, studentName: st.name, itemId: item,
      itemName: shop[item][0], cost: shop[item][1], status, createdAt: addHours(now, -h),
      decidedAt: status === 'pending' ? null : addHours(now, -h + 3),
    });
  };
  request(1, rs[5], 'line-leader', 'pending', 2);
  request(2, rs[6], 'class-game', 'pending', 5);
  request(3, maria, 'seat', 'pending', 20);
  request(4, ana, 'line-leader', 'approved', 100);
  request(5, rs[7], 'seat', 'approved', 140);
  request(6, rs[8], 'line-leader', 'approved', 190);
  request(7, juan, 'seat', 'approved', 260);
  request(8, rs[9], 'class-game', 'approved', 300);
  request(9, rs[5], 'line-leader', 'approved', 330);
  request(10, rs[10], 'class-game', 'declined', 200);
  const award = (n, st, points, reason, h, badgeId = null) => put(`pointAwards/seed-pa${n}`, {
    teacherId, classId: 'rizal-4a', studentId: st.id, studentName: st.name, points, reason, badgeId,
    createdAt: addHours(now, -h) });
  award(1, maria, 20, 'Tinulungan ang kaklase sa map activity', 30, 'helping-hand');
  award(2, juan, 10, 'Great participation in class', 50);
  award(3, carlo, 15, 'Improved on the last quiz', 80);
  award(4, rs[6], 20, 'Helped set up the class display', 120, 'helping-hand');

  for (const cls of CLASSES) {
    const m = cls._latestMarks ?? {};
    const count = (v) => Object.values(m).filter((x) => x === v).length;
    summary.classes.push({
      id: cls.id, code: cls.classCode, students: cls._students.length, archived: !!cls.archived,
      missingStudents: new Set([...cls._missingSet].map((k) => k.split('_')[0])).size,
      classwork: cls._work.length,
      latestAttendance: `${count('present')} present / ${count('late')} late / ${count('absent')} absent / ${count('excused')} excused`,
    });
  }
  summary.unreadMessages = unreadMessages;
  summary.pendingRewardRequests = pendingRequests;
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
      'attendance', 'reminders', 'classRequests', 'pointAwards', 'rewardRequests', 'calendarEvents'];
    for (const name of owned) {
      const snap = await db.collection(name).where('teacherId', '==', user.uid).get();
      const w = db.bulkWriter();
      snap.docs.forEach((d) => w.delete(d.ref));
      await w.close();
    }
    const chats = await db.collection('conversations').where('teacherId', '==', user.uid).get();
    for (const c of chats.docs) await db.recursiveDelete(c.ref);
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
