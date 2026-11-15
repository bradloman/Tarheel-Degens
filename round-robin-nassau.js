// Shared-round, three-player Round Robin Nassau helpers.
// This module is deliberately independent of persistence and UI.
export function roundRobinPairs(players) {
  if (!Array.isArray(players) || players.length !== 3 || new Set(players.map(p => p.id)).size !== 3 || players.some(p => !p?.id)) {
    throw new Error('Round Robin Nassau requires exactly three distinct players.');
  }
  return [[0, 1], [0, 2], [1, 2]].map(([a, b]) => ({
    key: [players[a].id, players[b].id].sort().join(':'),
    playerIds: [players[a].id, players[b].id]
  }));
}

export function roundRobinNetScores(players, grossByPlayer, strokeIndex) {
  if (!Number.isInteger(strokeIndex) || strokeIndex < 1 || strokeIndex > 18) throw new Error('Invalid stroke index.');
  if (!Array.isArray(players) || players.length !== 3 || players.some(p => !Number.isInteger(p.courseHandicap))) throw new Error('Three course handicaps required.');
  const low = Math.min(...players.map(p => p.courseHandicap));
  return Object.fromEntries(players.map(p => {
    const gross = grossByPlayer[p.id];
    if (!Number.isInteger(gross) || gross < 1 || gross > 30) return [p.id, null];
    const allowance = p.courseHandicap - low;
    const strokes = Math.floor(allowance / 18) + (strokeIndex <= allowance % 18 ? 1 : 0);
    return [p.id, gross - strokes];
  }));
}

export function roundRobinSegmentStatus(pair, netByHole, start, end) {
  let lead = 0, lastHole = start - 1;
  for (let hole = start; hole <= end; hole++) {
    const values = netByHole[hole];
    const a = values?.[pair.playerIds[0]], b = values?.[pair.playerIds[1]];
    if (!Number.isInteger(a) || !Number.isInteger(b)) break;
    lead += a < b ? 1 : a > b ? -1 : 0;
    lastHole = hole;
    if (Math.abs(lead) > end - hole) break;
  }
  const played = lastHole - start + 1;
  return {lead, played, lastHole, remaining: end - lastHole, closed: played > 0 && (lastHole === end || Math.abs(lead) > end - lastHole)};
}

export const ROUND_ROBIN_SEGMENTS = Object.freeze([
  {key: 'F', start: 1, end: 9},
  {key: 'B', start: 10, end: 18},
  {key: 'O', start: 1, end: 18}
]);
