/**
 * Date helpers pinned to Asia/Manila (UTC+8, no daylight saving), so
 * "today", "this month" and "this quarter" match what teachers see.
 */
export const MANILA_TZ = 'Asia/Manila';
const OFFSET_MS = 8 * 60 * 60 * 1000;
export const DAY_MS = 24 * 60 * 60 * 1000;

function parts(d: Date) {
  const m = new Date(d.getTime() + OFFSET_MS);
  return { y: m.getUTCFullYear(), mo: m.getUTCMonth(), d: m.getUTCDate() };
}

const utcFromManila = (y: number, mo: number, d: number) => new Date(Date.UTC(y, mo, d) - OFFSET_MS);

export const startOfDay = (d: Date) => {
  const p = parts(d);
  return utcFromManila(p.y, p.mo, p.d);
};

export const addDays = (d: Date, n: number) => new Date(d.getTime() + n * DAY_MS);

export const startOfMonth = (d: Date) => {
  const p = parts(d);
  return utcFromManila(p.y, p.mo, 1);
};

export const startOfQuarter = (d: Date) => {
  const p = parts(d);
  return utcFromManila(p.y, p.mo - (p.mo % 3), 1);
};

const pad = (n: number) => String(n).padStart(2, '0');

/** "2026-09-26" in Manila time. */
export const dayKey = (d: Date) => {
  const p = parts(d);
  return `${p.y}-${pad(p.mo + 1)}-${pad(p.d)}`;
};

/** "2026-09" in Manila time. */
export const monthKey = (d: Date) => {
  const p = parts(d);
  return `${p.y}-${pad(p.mo + 1)}`;
};
