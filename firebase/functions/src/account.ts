import { getAuth } from 'firebase-admin/auth';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import './shared';

/** Settings › "Sign out of all devices": ends every session of the caller. */
export const signOutEverywhere = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Please sign in.');
  await getAuth().revokeRefreshTokens(uid);
  return { ok: true };
});
