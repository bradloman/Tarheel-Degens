const assert=require('node:assert/strict');
const rr=require('../round-robin-nassau.js');
const {settle}=require('../round-robin-settlement.js');
const players=[{id:'A',courseHandicap:0},{id:'B',courseHandicap:0},{id:'C',courseHandicap:0}];
const holes=Array.from({length:18},(_,i)=>({number:i+1,strokeIndex:i+1,scores:{A:3,B:4,C:5}}));
const matches=rr.calculate(players,holes);
const result=settle(matches,{},5);
assert.deepEqual(result.totals,{A:30,B:0,C:-30});
assert.equal(result.bets.length,9);
assert.equal(Object.values(result.totals).reduce((a,b)=>a+b,0),0);
const withPress=settle(matches,{'A|B':[{segment:'front',startHole:3}]},5);
assert.deepEqual(withPress.totals,{A:35,B:-5,C:-30});
const ties=rr.calculate(players,holes.map(h=>({...h,scores:{A:4,B:4,C:4}})));
assert.deepEqual(settle(ties,{},5).totals,{A:0,B:0,C:0});
const incomplete=holes.map(h=>({...h,scores:{...h.scores}}));
delete incomplete[17].scores.C;
assert.throws(()=>settle(rr.calculate(players,incomplete),{},5),/unfinished/);
console.log('Round Robin Nassau settlement tests passed');

const {matchupRecords}=require('../round-robin-settlement.js');
const rows=withPress.bets.map(b=>{const [a,c]=b.match.split('|');return {match_id:'round1',player_a:a,player_b:c,segment:b.segment,press_id:b.type==='press'?'press1':null,lead:b.lead,amount_a_cents:Math.round(b.amountA*100)}});
for(const id of ['A','B','C']){
 const records=matchupRecords(rows,id);
 assert.equal(records.length,2);
 assert.equal(records.reduce((sum,r)=>sum+r.netCents,0),withPress.totals[id]*100);
 assert.deepEqual(records.map(r=>r.result).sort(),id==='A'?['win','win']:id==='B'?['loss','win']:['loss','loss']);
}
assert.throws(()=>matchupRecords([...rows,rows.find(r=>r.segment==='overall')],'A'),/Duplicate/);
assert.throws(()=>matchupRecords(rows.filter(r=>r.segment!=='overall'),'A'),/Missing/);
const tiedRows=rows.map(r=>({...r,lead:0,amount_a_cents:0}));
assert.deepEqual(matchupRecords(tiedRows,'B').map(r=>r.result),['tie','tie']);
