/* Tarheel Degens — Scotch scoring engine (no UI or database side effects).
   Teams: arrays of two player IDs; scores: gross strokes by player ID;
   strokes: handicap strokes received by player ID; par: hole par.
   ctpPlayerId: player ID or null (only set for a player on green in regulation).
   birdieMode: "gross" (default) or "net".
*/
(function (root) {
  "use strict";
  function scoreHole({ teams, scores, strokes = {}, par, ctpPlayerId = null, birdieMode = "gross" }) {
    if (!Array.isArray(teams) || teams.length !== 2 || teams.some(t => !Array.isArray(t) || t.length !== 2))
      throw new Error("Scotch requires two teams of two");
    const ids = teams.flat();
    if (new Set(ids).size !== 4) throw new Error("Scotch requires four distinct players");
    if (!Number.isInteger(par) || par < 3 || par > 6) throw new Error("Invalid par");
    if (!["gross", "net"].includes(birdieMode)) throw new Error("Invalid birdie mode");
    const net = {};
    for (const id of ids) {
      if (!Number.isInteger(scores[id]) || scores[id] < 1) throw new Error("Missing or invalid gross score");
      const h = strokes[id] ?? 0;
      if (!Number.isInteger(h) || h < 0) throw new Error("Invalid handicap strokes");
      net[id] = scores[id] - h;
    }
    if (ctpPlayerId !== null && !ids.includes(ctpPlayerId)) throw new Error("Invalid closest-to-pin player");
    const points = [0, 0], breakdown = [[], []];
    function award(category, valueA, valueB, pts, lowerWins = true) {
      if (valueA === valueB) return;
      const winner = lowerWins ? (valueA < valueB ? 0 : 1) : (valueA > valueB ? 0 : 1);
      points[winner] += pts;
      breakdown[winner].push(category);
    }
    const lows = teams.map(t => Math.min(...t.map(id => net[id])));
    const totals = teams.map(t => t.reduce((sum, id) => sum + net[id], 0));
    award("lowBall", lows[0], lows[1], 2);
    award("lowTotal", totals[0], totals[1], 2);
    if (ctpPlayerId !== null) {
      const winner = teams.findIndex(t => t.includes(ctpPlayerId));
      points[winner] += 1;
      breakdown[winner].push("closestToPin");
    }
    // Birdie point is contested by each team's best qualifying score.
    // Eagle (-2) defeats birdie (-1); matching best scores tie for zero.
    const bestRelative = teams.map(t => Math.min(...t.map(id => (birdieMode === "net" ? net[id] : scores[id]) - par)));
    if (bestRelative[0] <= -1 || bestRelative[1] <= -1) {
      const a = bestRelative[0] <= -1 ? bestRelative[0] : 0;
      const b = bestRelative[1] <= -1 ? bestRelative[1] : 0;
      award("birdieOrBetter", a, b, 1);
    }
    let multiplier = 1, sweepTeam = null;
    const winner = points[0] === 6 ? 0 : points[1] === 6 ? 1 : null;
    if (winner !== null) {
      sweepTeam = winner;
      const relative = teams[winner].map(id => (birdieMode === "net" ? net[id] : scores[id]) - par);
      multiplier = relative.every(n => n <= -1) ? 4 : relative.some(n => n <= -2) ? 3 : 2;
      points[winner] *= multiplier;
    }
    return { points, breakdown, net, multiplier, sweepTeam, margin: points[0] - points[1] };
  }
  function settle({ teamPoints, bettingMode, stake }) {
    if (!Array.isArray(teamPoints) || teamPoints.length !== 2 || teamPoints.some(n => !Number.isFinite(n) || n < 0))
      throw new Error("Invalid team points");
    if (!Number.isFinite(stake) || stake < 0) throw new Error("Invalid stake");
    if (!["perPoint", "fixed"].includes(bettingMode)) throw new Error("Invalid betting mode");
    const margin = teamPoints[0] - teamPoints[1];
    const perPlayer = margin === 0 ? 0 : Math.sign(margin) * (bettingMode === "perPoint" ? Math.abs(margin) * stake : stake);
    return { teamAEach: perPlayer, teamBEach: -perPlayer, margin };
  }
  root.TarheelScotch = Object.freeze({ scoreHole, settle });
})(typeof window !== "undefined" ? window : globalThis);
