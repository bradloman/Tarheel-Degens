/* Tarheel Degens — Tilt scoring foundation.
 * No Laying Up rules: https://nolayingup.com/blog/tilt
 * Pure functions; no database or DOM dependencies.
 */
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.TarheelTilt = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  function integer(value, label) {
    if (!Number.isInteger(value)) throw Error(label + ' must be an integer');
    return value;
  }
  function basePoints(netRelativeToPar) {
    integer(netRelativeToPar, 'Net relative to par');
    if (netRelativeToPar >= 2) return -4;
    if (netRelativeToPar === 1) return 0;
    if (netRelativeToPar === 0) return 2;
    if (netRelativeToPar === -1) return 4;
    if (netRelativeToPar === -2) return 8;
    return 16;
  }
  function nextMultiplier(netRelativeToPar, multiplier) {
    integer(netRelativeToPar, 'Net relative to par');
    integer(multiplier, 'Multiplier');
    if (multiplier < 1) throw Error('Multiplier must be positive');
    if (netRelativeToPar <= -3) return multiplier + 3;
    if (netRelativeToPar === -2) return multiplier + 2;
    if (netRelativeToPar === -1) return multiplier + 1;
    // Non-birdie results break a Tilt streak.
    return 1;
  }
  function scoreRound(holes) {
    if (!Array.isArray(holes) || holes.length > 18) throw Error('Provide at most 18 holes');
    let multiplier = 1, total = 0, completeThrough = 0, blocked = false;
    const rows = holes.map((hole, i) => {
      if (!hole || hole.gross == null || hole.gross === '') {
        blocked = true;
        return {hole: i + 1, entered: false, multiplier: null, points: null, runningTotal: null, nextMultiplier: null};
      }
      const gross = integer(Number(hole.gross), 'Gross strokes');
      const par = integer(Number(hole.par), 'Par');
      const strokes = integer(Number(hole.strokesReceived || 0), 'Strokes received');
      if (gross < 1 || par < 3 || par > 6 || strokes < -4 || strokes > 6) throw Error('Invalid hole score, par or strokes');
      if (blocked) return {hole: i + 1, entered: true, pending: true, multiplier: null, points: null, runningTotal: null, nextMultiplier: null};
      const net = gross - strokes, relative = net - par;
      const points = basePoints(relative) * multiplier;
      const usedMultiplier = multiplier;
      total += points;
      multiplier = nextMultiplier(relative, multiplier);
      completeThrough = i + 1;
      return {hole: i + 1, entered: true, gross, net, relative, multiplier: usedMultiplier, basePoints: basePoints(relative), points, runningTotal: total, nextMultiplier: multiplier};
    });
    return {holes: rows, points: total, completeThrough, nextMultiplier: multiplier, complete: holes.length > 0 && completeThrough === holes.length};
  }
  function validateGroups(players, groups, teams, teamSize) {
    if (!Array.isArray(players) || players.length < 2 || players.length > 12) throw Error('Tilt requires 2–12 players');
    const ids = players.map(p => p.id);
    if (ids.some(id => id == null) || new Set(ids).size !== ids.length) throw Error('Player IDs must be unique');
    if (!Array.isArray(groups) || groups.length < 1 || groups.length > 3) throw Error('Use 1–3 playing groups');
    const assigned = groups.flat();
    if (groups.some(g => !Array.isArray(g) || g.length < 1 || g.length > 4) || assigned.length !== ids.length || new Set(assigned).size !== ids.length || assigned.some(id => !ids.includes(id))) throw Error('Every golfer must be assigned to exactly one playing group of at most four');
    if (teams != null) {
      if (![2,3,4].includes(teamSize) || ids.length % teamSize) throw Error('Invalid equal team size');
      const teamIds = teams.flat();
      if (!Array.isArray(teams) || teams.length < 2 || teams.some(t => !Array.isArray(t) || t.length !== teamSize) || teamIds.length !== ids.length || new Set(teamIds).size !== ids.length || teamIds.some(id => !ids.includes(id))) throw Error('Every golfer must be on exactly one equally sized team');
    }
    return true;
  }
  function leaderboard(players, scores, teams) {
    const individual = players.map(p => {
      const result = scoreRound(scores[p.id] || []);
      return {id: p.id, name: p.name, ...result};
    }).sort((a,b) => b.points-a.points || String(a.name).localeCompare(String(b.name)));
    if (!teams) return {individual, teams: []};
    const teamBoard = teams.map((team, index) => {
      const members = team.map(id => individual.find(p => p.id === id));
      if (members.some(p => !p)) throw Error('Unknown team member');
      return {team: index+1, memberIds: team, points: members.reduce((s,p) => s+p.points,0), completeThrough: Math.min(...members.map(p=>p.completeThrough)), complete: members.every(p=>p.complete)};
    }).sort((a,b) => b.points-a.points || a.team-b.team);
    return {individual, teams: teamBoard};
  }
  return {basePoints, nextMultiplier, scoreRound, validateGroups, leaderboard};
});
