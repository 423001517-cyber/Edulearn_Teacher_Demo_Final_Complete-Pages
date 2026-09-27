// Run with: npm test   (builds, then runs node's built-in test runner)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { computeRollup, noun } = require('../lib/rollup.js');
const time = require('../lib/time.js');

const near = (actual, expected) =>
  assert.ok(Math.abs(actual - expected) < 1e-9, `${actual} ≉ ${expected}`);

// Manila midnight as a UTC instant.
const manila = (y, m, d, h = 0) => new Date(Date.UTC(y, m - 1, d, h) - 8 * 3600 * 1000);

test('Manila day, month and quarter boundaries', () => {
  const late = new Date('2026-09-26T20:00:00Z'); // 04:00 on Sep 27 in Manila
  assert.equal(time.dayKey(late), '2026-09-27');
  assert.equal(time.startOfDay(late).toISOString(), '2026-09-26T16:00:00.000Z');
  assert.equal(time.monthKey(late), '2026-09');
  assert.equal(time.startOfQuarter(late).toISOString(), '2026-06-30T16:00:00.000Z');
});

test('rollup: missing work, progress, scores, attendance, activity', () => {
  const now = manila(2026, 9, 26, 21); // Saturday 9 PM
  const students = [{ id: 'a', name: 'Maria Santos' }, { id: 'b', name: 'Carlo Reyes' }];
  const w = (id, type, day, status = 'published', assigned = []) =>
    ({ id, title: id, type, status, dueDate: manila(2026, 9, day), assignedStudentIds: assigned });
  const work = [
    w('w1', 'quest', 21),
    w('w2', 'boss', 25), // due yesterday
    w('w3', 'quest', 28), // future
    w('w4', 'boss', 27, 'scheduled'), // tomorrow
    w('lesson', 'lesson', 21),
    w('draft', 'quiz', 22, 'draft'),
    w('remedial', 'quest', 23, 'published', ['b']),
  ];
  const sub = (studentId, classworkId, score, maxScore, returned = true) => ({
    studentId, classworkId, status: returned ? 'returned' : 'pending',
    score: returned ? score : null, maxScore,
    submittedAt: manila(2026, 9, 20), returnedAt: returned ? manila(2026, 9, 24) : null,
  });
  const submissions = [
    sub('a', 'w1', 18, 20),
    sub('a', 'w2', 40, 50),
    sub('b', 'w1', null, 20, false),
    sub('b', 'remedial', 10, 20),
  ];
  const attendance = [
    { date: manila(2026, 9, 24), marks: { a: 'present', b: 'late' } },
    { date: manila(2026, 9, 25), marks: { a: 'absent', b: 'present' } },
  ];

  const r = computeRollup(now, students, work, submissions, attendance);
  const a = r.students.get('a');
  const b = r.students.get('b');

  assert.equal(a.missingCount, 0);
  assert.equal(a.questProgress, 1);
  near(a.averageScore, 0.85);
  assert.equal(a.attendanceRate, 0.5);
  assert.equal(a.absences, 1);

  // b: owes w2 only (w1 was turned in, pending grading still counts)
  assert.equal(b.missingCount, 1);
  near(b.questProgress, 2 / 3);
  near(b.averageScore, 0.5);
  assert.equal(b.lateCount, 1);
  assert.equal(b.attendanceRate, 1);

  assert.deepEqual(r.missing.map((m) => `${m.studentId}:${m.work.id}`), ['b:w2']);
  assert.equal(r.studentsWithMissing, 1);
  // w1 100%, w2 50%, remedial 100% (only b assigned)
  near(r.completionRate, (1 + 0.5 + 1) / 3);
  assert.equal(r.yesterday.length, 1);
  assert.equal(r.yesterday[0].completed, 1);
  assert.deepEqual(r.yesterday[0].missedBy.map((s) => s.id), ['b']);
  assert.deepEqual(r.bossTomorrow.map((x) => x.id), ['w4']);
});

test('noun() wording for the activity feed', () => {
  assert.equal(noun('boss'), 'boss assessment');
  assert.equal(noun('quiz'), 'quiz');
  assert.equal(noun('weird'), 'task');
});

test('official class codes', () => {
  const { codeBase, candidateCodes, colorIndexFor } = require('../lib/admin/codes.js');
  assert.equal(codeBase('Rizal'), 'RIZAL');
  assert.equal(codeBase('Bonifacio'), 'BONI');
  assert.equal(codeBase('Mabini'), 'MABI');
  assert.equal(codeBase('Sto. Niño'), 'STON'); // STONINO → first 4
  assert.equal(codeBase('Luna'), 'LUNA');
  assert.equal(codeBase('123'), 'CLASS');
  const codes = candidateCodes('Rizal', 4);
  assert.equal(codes[0], 'RIZAL-4A');
  assert.equal(codes[1], 'RIZAL-4B');
  assert.equal(codes.length, 26);
  assert.ok(colorIndexFor('RIZAL-4A') >= 0 && colorIndexFor('RIZAL-4A') < 6);
});
