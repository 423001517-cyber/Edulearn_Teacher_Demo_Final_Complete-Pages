/**
 * Gives an EXISTING EduLearn account the admin role — use it once for the
 * school's first administrator. After that, admins add each other in
 * Settings → Administrators on the admin website.
 *
 *   cd tools/admin && npm install
 *   gcloud auth application-default login          # or GOOGLE_APPLICATION_CREDENTIALS
 *   node make_admin.mjs --project <project-id> --email principal@school.edu.ph
 *
 * The person must already have signed up (for example on the teacher
 * website) or been created in Firebase Authentication. They must sign out
 * and back in for the new role to take effect.
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const args = process.argv.slice(2);
const opt = (name) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : undefined;
};

const here = dirname(fileURLToPath(import.meta.url));
let defaultProject;
try {
  defaultProject = JSON.parse(readFileSync(join(here, '../../.firebaserc'), 'utf8')).projects.default;
} catch {
  defaultProject = undefined;
}

const project = opt('project') ?? process.env.GCLOUD_PROJECT ?? defaultProject;
const email = opt('email')?.trim().toLowerCase();
if (!project || !email) {
  console.error('Usage: node make_admin.mjs --project <project-id> --email person@school.edu.ph');
  process.exit(1);
}

initializeApp({ projectId: project });
const auth = getAuth();

let user;
try {
  user = await auth.getUserByEmail(email);
} catch {
  console.error(`No account uses ${email} in project "${project}". Create or sign up that account first.`);
  process.exit(1);
}

await auth.setCustomUserClaims(user.uid, { ...(user.customClaims ?? {}), role: 'admin' });
await getFirestore().doc(`admins/${user.uid}`).set({
  displayName: user.displayName ?? email,
  email,
  addedBy: 'make_admin.mjs',
  addedAt: FieldValue.serverTimestamp(),
});
console.log(`${email} is now an administrator of "${project}". Ask them to sign out and back in.`);
