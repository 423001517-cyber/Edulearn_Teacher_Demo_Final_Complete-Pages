/**
 * Official class codes, e.g. "RIZAL-4A": up to 5 letters of the section
 * (sections longer than 5 letters use their first 4 — "BONI", "MABI"),
 * the grade, then the first free letter A–Z.
 */
export function codeBase(section: string): string {
  const letters = section
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '') // Niño -> Nino
    .toUpperCase()
    .replace(/[^A-Z]/g, '');
  if (letters.length === 0) return 'CLASS';
  return letters.length <= 5 ? letters : letters.slice(0, 4);
}

export function candidateCodes(section: string, gradeLevel: number): string[] {
  const base = codeBase(section);
  return 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map((l) => `${base}-${gradeLevel}${l}`);
}

/** Stable 0–5 color slot for a new class card. */
export function colorIndexFor(code: string): number {
  let h = 0;
  for (const c of code) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  return h % 6;
}
