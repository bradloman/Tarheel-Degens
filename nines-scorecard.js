import {ninesHolePoints,ninesSettlement} from './nines.js';
export function strokesOnNinesHole(allowance,strokeIndex) {
 if (!Number.isInteger(allowance) || allowance < 0 || !Number.isInteger(strokeIndex) || strokeIndex < 1 || strokeIndex > 18) throw new Error('Invalid handicap allowance or stroke index');
 return Math.floor(allowance / 18) + (strokeIndex <= allowance % 18 ? 1 : 0);
}
export function ninesScorecard(players, holes, stake, mode) {
 if (!Array.isArray(players) || players.length !== 3 || players.some(p => !Number.isInteger(p.courseHandicap))) throw new Error('Exactly three players with course handicaps required');
 if (!Array.isArray(holes) || ![9,18].includes(holes.length)) throw new Error('Nine or eighteen holes required');
 const lowest = Math.min(...players.map(p => p.courseHandicap));
 const allowances = players.map(p => p.courseHandicap - lowest);
 const totals = [0,0,0], grossTotals = [0,0,0];
 const rows = holes.map((hole,i) => {
  if (hole.number !== i+1 || !Number.isInteger(hole.strokeIndex) || hole.strokeIndex < 1 || hole.strokeIndex > 18) throw new Error('Invalid hole number or stroke index');
  const gross = hole.gross;
  if (!Array.isArray(gross) || gross.length !== 3) throw new Error('Exactly three gross scores required');
  if (gross.some(n => n === null || n === undefined || n === '')) return {hole:hole.number,complete:false};
  if (gross.some(n => !Number.isInteger(n) || n < 1 || n > 30)) throw new Error('Invalid gross score');
  const strokes = allowances.map(n => strokesOnNinesHole(n,hole.strokeIndex));
  const net = gross.map((n,j) => n-strokes[j]);
  const points = ninesHolePoints(net);
  for (let j=0;j<3;j++) { totals[j]+=points[j];grossTotals[j]+=gross[j]; }
  return {hole:hole.number,complete:true,gross:[...gross],strokes,net,points};
 });
 const complete = rows.every(r => r.complete);
 return {rows,allowances,totals,grossTotals,complete,settlement:complete?ninesSettlement(totals,stake,mode):null};
}
