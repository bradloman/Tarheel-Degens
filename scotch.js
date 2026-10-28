// Tarheel Degens — six-point Scotch scoring engine.
// Independent of the scorecard UI. All scores are gross integers; strokes are
// each player's allocated handicap strokes on this hole.
// Players are ordered [team A player 1, A player 2, B player 1, B player 2].
// ctpWinner is the player index (0..3), or null when no player qualifies.
// Only choose a CTP winner who reached the green in regulation.
// Birdie mode is 'gross' (default) or 'net'.
export function scoreScotchHole({players, par, ctpWinner = null, birdieMode = 'gross'}) {
  if (!Array.isArray(players) || players.length !== 4) throw Error('Scotch requires four players');
  if (!Number.isInteger(par) || par < 3 || par > 6) throw Error('Invalid hole par');
  if (!['gross','net'].includes(birdieMode)) throw Error('Invalid birdie mode');
  if (ctpWinner !== null && (!Number.isInteger(ctpWinner) || ctpWinner < 0 || ctpWinner > 3)) throw Error('Invalid CTP winner');
  const valid = players.every(p => Number.isInteger(p.gross) && p.gross > 0 && Number.isInteger(p.strokes) && p.strokes >= 0);
  if (!valid) return {complete:false, points:[0,0], categories:null, multiplier:1};
  const net = players.map(p => p.gross - p.strokes);
  const teams = [[0,1],[2,3]];
  const low = teams.map(t => Math.min(...t.map(i => net[i])));
  const total = teams.map(t => t.reduce((s,i) => s + net[i],0));
  const award = (a,b,points) => a === b ? [0,0] : a < b ? [points,0] : [0,points];
  const lowBall = award(low[0],low[1],2);
  const lowTotal = award(total[0],total[1],2);
  const ctp = ctpWinner === null ? [0,0] : ctpWinner < 2 ? [1,0] : [0,1];
  const qualifying = birdieMode === 'gross' ? players.map(p=>p.gross) : net;
  // Best qualifying score relative to par wins: eagle beats birdie;
  // equal birdies (or equal eagles) tie, and no birdies award zero.
  const best = teams.map(t => Math.min(...t.map(i => qualifying[i])));
  const birdie = best[0] >= par && best[1] >= par ? [0,0] :
    best[0] === best[1] ? [0,0] : best[0] < best[1] ? [1,0] : [0,1];
  const categories = {lowBall,lowTotal,ctp,birdie};
  const base = [0,1].map(i => Object.values(categories).reduce((s,v)=>s+v[i],0));
  let multiplier = 1;
  const sweepTeam = base[0] === 6 && base[1] === 0 ? 0 : base[1] === 6 && base[0] === 0 ? 1 : null;
  if (sweepTeam !== null) {
    const t = teams[sweepTeam];
    const bothBirdie = t.every(i => qualifying[i] <= par-1);
    const eagle = t.some(i => qualifying[i] <= par-2);
    multiplier = bothBirdie ? 4 : eagle ? 3 : 2;
  }
  return {complete:true, net, categories, base, multiplier, sweepTeam, points:base.map(p=>p*multiplier)};
}

export function settleScotch({teamPoints, wagerMode, stake}) {
  if (!Array.isArray(teamPoints) || teamPoints.length !== 2 || teamPoints.some(n=>!Number.isFinite(n)||n<0)) throw Error('Invalid points');
  if (!Number.isFinite(stake) || stake < 0) throw Error('Invalid stake');
  if (!['fixed','per_point'].includes(wagerMode)) throw Error('Invalid wager mode');
  const diff = teamPoints[0]-teamPoints[1];
  const amount = (wagerMode === 'fixed' ? Math.sign(diff)*stake : diff*stake);
  // Per-person net results, ordered A1,A2,B1,B2; zero-sum.
  return [amount,amount,-amount,-amount];
}
