// Pure Nines scoring and settlement logic. No UI or database side effects.
export function ninesHolePoints(netScores) {
  if (!Array.isArray(netScores) || netScores.length !== 3 || netScores.some(n => !Number.isInteger(n) || n < 1)) throw new Error('Exactly three valid net scores required');
  return netScores.map(n => {
    const better = netScores.filter(x => x < n).length;
    const equal = netScores.filter(x => x === n).length;
    if (equal === 3) return 3;
    if (better === 0) return equal === 2 ? 4 : 5;
    if (better === 1) return equal === 2 ? 2 : 3;
    return 1;
  });
}
// Integer cents prevent rounding discrepancies; remainder penny goes to first tied winner.
export function ninesSettlement(totals, stake, mode) {
  if (!Array.isArray(totals) || totals.length !== 3 || totals.some(n => !Number.isInteger(n) || n < 0)) throw new Error('Exactly three point totals required');
  if (!Number.isFinite(stake) || stake < 0 || !['fixed','per_point'].includes(mode)) throw new Error('Invalid stake or mode');
  const cents = Math.round(stake * 100);
  const high = Math.max(...totals);
  const winners = totals.map((n,i) => n === high ? i : -1).filter(i => i >= 0);
  const result = [0,0,0];
  if (winners.length === 3) return result;
  for (let i = 0; i < 3; i++) {
    if (winners.includes(i)) continue;
    const owed = mode === 'fixed' ? cents : cents * (high - totals[i]);
    result[i] -= owed;
    winners.forEach((w,j) => result[w] += Math.floor(owed / winners.length) + (j < owed % winners.length ? 1 : 0));
  }
  return result.map(n => n / 100);
}
