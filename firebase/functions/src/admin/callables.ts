import { randomBytes } from 'node:crypto';

import { getAuth } from 'firebase-admin/auth';
import { FieldValue, Transaction } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { CallableRequest, HttpsError, onCall } from 'firebase-functions/v2/https';

import { db } from '../shared';
import { candidateCodes, colorIndexFor } from './codes';

// ------------------------------------------------------------------ guards
function requireAdmin(req: CallableRequest<unknown>): string {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
  if (req.auth.token.role !== 'admin') {
    throw new HttpsError('permission-denied', 'Only administrators can do this.');
  }
  return req.auth.uid;
}

type Input = Record<string, unknown>;
const input = (req: CallableRequest<unknown>): Input =>
  req.data && typeof req.data === 'object' ? (req.data as Input) : {};

function text(v: unknown, field: string, max = 80): string {
  if (typeof v !== 'string' || v.trim().length === 0) {
    throw new HttpsError('invalid-argument', `${field} is required.`);
  }
  const t = v.trim();
  if (t.length > max) throw new HttpsError('invalid-argument', `${field} is too long.`);
  return t;
}

function grade(v: unknown): number {
  if (typeof v !== 'number' || !Number.isInteger(v) || v < 1 || v > 12) {
    throw new HttpsError('invalid-argument', 'Grade must be 1 to 12.');
  }
  return v;
}

const className = (g: number, section: string) => `Grade ${g} – ${section}`;

function notifyTeacher(tx: Transaction, teacherId: string, title: string) {
  tx.set(db.collection('teachers').doc(teacherId).collection('notifications').doc(), {
    kind: 'general',
    title,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

// ----------------------------------------------------------------- classes
interface NewClass {
  gradeLevel: number;
  section: string;
  subject: string;
  teacherId: string;
}

/**
 * Reserves a unique class code (classCodes/{code}) and creates the class,
 * inside the caller's transaction. All reads happen before any write.
 */
async function createClassInTx(tx: Transaction, c: NewClass, adminUid: string) {
  const teacher = await tx.get(db.collection('teachers').doc(c.teacherId));
  if (!teacher.exists) throw new HttpsError('not-found', 'That teacher does not exist.');
  if (teacher.get('status') === 'disabled') {
    throw new HttpsError('failed-precondition', 'That teacher account is disabled.');
  }

  let code: string | null = null;
  for (const candidate of candidateCodes(c.section, c.gradeLevel)) {
    const snap = await tx.get(db.collection('classCodes').doc(candidate));
    if (!snap.exists) {
      code = candidate;
      break;
    }
  }
  if (!code) throw new HttpsError('resource-exhausted', 'No class codes left for this section.');

  const classRef = db.collection('classes').doc();
  tx.set(db.collection('classCodes').doc(code), {
    classId: classRef.id,
    createdAt: FieldValue.serverTimestamp(),
  });
  tx.set(classRef, {
    teacherId: c.teacherId,
    gradeLevel: c.gradeLevel,
    section: c.section,
    subject: c.subject,
    classCode: code,
    status: 'active',
    studentCount: 0,
    questCount: 0,
    completionRate: 0,
    averageScore: 0,
    coverImageUrl: null,
    colorIndex: colorIndexFor(code),
    archivedAt: null,
    createdAt: FieldValue.serverTimestamp(),
    createdBy: adminUid,
  });
  notifyTeacher(tx, c.teacherId, `New class assigned: ${className(c.gradeLevel, c.section)} (code ${code})`);
  return { classId: classRef.id, classCode: code };
}

/** Admin → Classes → "Create Class". */
export const createClass = onCall(async (req) => {
  const adminUid = requireAdmin(req);
  const d = input(req);
  const c: NewClass = {
    gradeLevel: grade(d.gradeLevel),
    section: text(d.section, 'Section', 60),
    subject: text(d.subject, 'Subject'),
    teacherId: text(d.teacherId, 'Teacher', 128),
  };
  const result = await db.runTransaction((tx) => createClassInTx(tx, c, adminUid));
  logger.info('Class created', { ...result, by: adminUid });
  return result;
});

/** Approves a teacher's "Request New Class" (optionally adjusted). */
export const approveClassRequest = onCall(async (req) => {
  const adminUid = requireAdmin(req);
  const d = input(req);
  const requestRef = db.collection('classRequests').doc(text(d.requestId, 'Request', 128));

  const result = await db.runTransaction(async (tx) => {
    const request = await tx.get(requestRef);
    if (!request.exists) throw new HttpsError('not-found', 'Request not found.');
    if (request.get('status') !== 'pending') {
      throw new HttpsError('failed-precondition', 'This request was already handled.');
    }
    const r = request.data()!;
    const c: NewClass = {
      gradeLevel: grade(d.gradeLevel ?? r.gradeLevel),
      section: text(d.section ?? r.section, 'Section', 60),
      subject: text(d.subject ?? r.subject, 'Subject'),
      teacherId: text(d.teacherId ?? r.teacherId, 'Teacher', 128),
    };
    const created = await createClassInTx(tx, c, adminUid);
    tx.update(requestRef, {
      status: 'approved',
      classId: created.classId,
      decidedAt: FieldValue.serverTimestamp(),
      decidedBy: adminUid,
    });
    return created;
  });
  logger.info('Class request approved', { request: requestRef.id, ...result });
  return result;
});

export const declineClassRequest = onCall(async (req) => {
  const adminUid = requireAdmin(req);
  const d = input(req);
  const requestRef = db.collection('classRequests').doc(text(d.requestId, 'Request', 128));
  const note = typeof d.note === 'string' ? d.note.trim().slice(0, 500) : '';

  await db.runTransaction(async (tx) => {
    const request = await tx.get(requestRef);
    if (!request.exists) throw new HttpsError('not-found', 'Request not found.');
    if (request.get('status') !== 'pending') {
      throw new HttpsError('failed-precondition', 'This request was already handled.');
    }
    tx.update(requestRef, {
      status: 'declined',
      decisionNote: note,
      decidedAt: FieldValue.serverTimestamp(),
      decidedBy: adminUid,
    });
    notifyTeacher(tx, request.get('teacherId'),
      `Your request for ${className(request.get('gradeLevel'), request.get('section'))} was declined` +
      (note ? `: ${note}` : '.'));
  });
  return { ok: true };
});

/** Issues a new code (e.g. the old one was shared publicly). */
export const regenerateClassCode = onCall(async (req) => {
  requireAdmin(req);
  const classRef = db.collection('classes').doc(text(input(req).classId, 'Class', 128));

  return db.runTransaction(async (tx) => {
    const cls = await tx.get(classRef);
    if (!cls.exists) throw new HttpsError('not-found', 'Class not found.');
    const old: string = cls.get('classCode') ?? '';
    let code: string | null = null;
    for (const candidate of candidateCodes(cls.get('section'), cls.get('gradeLevel'))) {
      if (candidate === old) continue;
      const snap = await tx.get(db.collection('classCodes').doc(candidate));
      if (!snap.exists) {
        code = candidate;
        break;
      }
    }
    if (!code) throw new HttpsError('resource-exhausted', 'No class codes left for this section.');
    if (old) tx.delete(db.collection('classCodes').doc(old));
    tx.set(db.collection('classCodes').doc(code), {
      classId: classRef.id,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(classRef, { classCode: code });
    notifyTeacher(tx, cls.get('teacherId'),
      `New class code for ${className(cls.get('gradeLevel'), cls.get('section'))}: ${code}`);
    return { classCode: code };
  });
});

// ---------------------------------------------------------------- accounts
/**
 * Admin → Teachers → "Add Teacher". Creates the sign-in account and returns
 * a one-time link the teacher uses to set their own password.
 */
export const createTeacherAccount = onCall(async (req) => {
  const adminUid = requireAdmin(req);
  const d = input(req);
  const displayName = text(d.displayName, 'Name');
  const email = text(d.email, 'Email', 254).toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    throw new HttpsError('invalid-argument', 'That email address looks wrong.');
  }

  const auth = getAuth();
  let uid: string;
  try {
    const user = await auth.createUser({
      email,
      displayName,
      password: randomBytes(18).toString('base64url'),
    });
    uid = user.uid;
  } catch (e) {
    if ((e as { code?: string }).code === 'auth/email-already-exists') {
      throw new HttpsError('already-exists', 'An account with that email already exists.');
    }
    throw e;
  }
  await auth.setCustomUserClaims(uid, { role: 'teacher' });
  await db.collection('teachers').doc(uid).set({
    displayName,
    email,
    photoUrl: null,
    role: 'teacher',
    status: 'active',
    createdAt: FieldValue.serverTimestamp(),
    createdBy: adminUid,
  });
  const resetLink = await auth.generatePasswordResetLink(email);
  logger.info('Teacher account created', { uid, by: adminUid });
  return { uid, resetLink };
});

/** New "set your password" link for a teacher. */
export const teacherPasswordLink = onCall(async (req) => {
  requireAdmin(req);
  const user = await getAuth().getUser(text(input(req).uid, 'Teacher', 128));
  if (!user.email) throw new HttpsError('failed-precondition', 'This account has no email.');
  return { resetLink: await getAuth().generatePasswordResetLink(user.email) };
});

/** Disable (can't sign in, signed out everywhere) or re-enable a teacher. */
export const setTeacherStatus = onCall(async (req) => {
  requireAdmin(req);
  const d = input(req);
  const uid = text(d.uid, 'Teacher', 128);
  const disabled = d.disabled === true;
  const auth = getAuth();
  await auth.updateUser(uid, { disabled });
  if (disabled) await auth.revokeRefreshTokens(uid);
  await db.collection('teachers').doc(uid).set({ status: disabled ? 'disabled' : 'active' }, { merge: true });
  return { ok: true };
});

/** Admin → Settings → Administrators: grant or remove the admin role. */
export const setAdminRole = onCall(async (req) => {
  const adminUid = requireAdmin(req);
  const d = input(req);
  const makeAdmin = d.admin === true;
  const auth = getAuth();

  let user;
  try {
    user = await auth.getUserByEmail(text(d.email, 'Email', 254).toLowerCase());
  } catch {
    throw new HttpsError('not-found', 'No account uses that email. They must sign up or be added first.');
  }
  if (!makeAdmin && user.uid === adminUid) {
    throw new HttpsError('failed-precondition', "You can't remove your own admin role.");
  }

  const isTeacher = (await db.collection('teachers').doc(user.uid).get()).exists;
  await auth.setCustomUserClaims(user.uid, makeAdmin ? { role: 'admin' } : isTeacher ? { role: 'teacher' } : {});
  const adminDoc = db.collection('admins').doc(user.uid);
  if (makeAdmin) {
    await adminDoc.set({
      displayName: user.displayName ?? user.email ?? 'Administrator',
      email: user.email ?? '',
      addedBy: adminUid,
      addedAt: FieldValue.serverTimestamp(),
    });
  } else {
    await adminDoc.delete();
  }
  return { uid: user.uid };
});
