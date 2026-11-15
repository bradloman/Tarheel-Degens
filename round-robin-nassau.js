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


// A press starts on the hole AFTER it is accepted. It belongs only to the
// selected pairing and segment; other pairings remain completely independent.
export function roundRobinPressStatus(pair, netByHole, press, segment) {
  if (!pair || !segment || !press || !Number.isInteger(press.startHole) ||
      press.startHole <= segment.start || press.startHole > segment.end ||
      !pair.playerIds.includes(press.calledBy)) {
    throw new Error('Invalid Round Robin press.');
  }
  return roundRobinSegmentStatus(pair, netByHole, press.startHole, segment.end);
}

export function roundRobinCanPress(pair, netByHole, segment, playerId, presses = []) {
  if (!pair.playerIds.includes(playerId)) return false;
  const status = roundRobinSegmentStatus(pair, netByHole, segment.start, segment.end);
  if (status.played === 0 || status.closed || status.lead === 0) return false;
  const downPlayer = status.lead > 0 ? pair.playerIds[1] : pair.playerIds[0];
  if (downPlayer !== playerId || Math.abs(status.lead) < 2) return false;
  const nextHole = status.lastHole + 1;
  if (nextHole > segment.end) return false;
  // Do not allow the same player to call multiple active presses in the
  // same segment on the same hole.
  return !presses.some(p => !p.undone && p.calledBy === playerId &&
    p.segment === segment.key && p.startHole === nextHole);
}

export function roundRobinAllStandings(players, netByHole, presses = []) {
  const pairs = roundRobinPairs(players);
  return pairs.map(pair => ({
    ...pair,
    segments: ROUND_ROBIN_SEGMENTS.map(segment => ({
      ...segment,
      status: roundRobinSegmentStatus(pair, netByHole, segment.start, segment.end),
      presses: presses.filter(p => !p.undone && p.pairKey === pair.key &&
        p.segment === segment.key).map(p => ({
        ...p,
        status: roundRobinPressStatus(pair, netByHole, p, segment)
      }))
    }))
  }));
}
