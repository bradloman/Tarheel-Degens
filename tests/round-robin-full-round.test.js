const assert=require('node:assert/strict');
const rr=require('../round-robin-nassau.js');
const press=require('../round-robin-presses.js');
const {settle}=require('../round-robin-settlement.js');
const {create}=require('../round-robin-score-entry.js');
const players=[{id:'A',courseHandicap:8},{id:'B',courseHandicap:12},{id:'C',courseHandicap:20}];
const holes=Array.from({length:18},(_,i)=>({number:i+1,strokeIndex:i+1,scores:{}}));
const loader=async()=>({players,holes,matches:rr.calculate(players,holes)});
const entry=create(loader,async(h,s)=>{holes[h-1].scores={...s}});
(async()=>{
 await entry.refresh();
 for(let h=1;h<=18;h++){
  await entry.save(h,{A:h<=9?3:5,B:4,C:5});
  if(h===4){
   const state=entry.getState();
   assert.equal(state.matches.length,3);
   assert.equal(state.holes[3].scores.A,3);
  }
 }
 const before=entry.getState();
 assert.equal(before.matches.every(m=>m.holes.every(h=>h.played)),true);
 const bets={'A|B':[{id:'p1',segment:'front',startHole:3},{id:'p2',segment:'overall',startHole:7}],
  'A|C':[{id:'p3',segment:'back',startHole:12}]};
 const first=settle(before.matches,bets,5);
 assert.equal(first.bets.length,12);
 assert.equal(Object.values(first.totals).reduce((a,b)=>a+b,0),0);
 // Correct a previously saved hole; all three matchups must update.
 const corrected=await entry.save(4,{A:7,B:4,C:5});
 assert.equal(corrected.holes[3].scores.A,7);
 assert.equal(corrected.matches[0].holes[3].winner,'B');
 assert.equal(corrected.matches[1].holes[3].winner,'C');
 const final=settle(corrected.matches,bets,5);
 assert.equal(final.bets.length,12);
 assert.equal(Object.values(final.totals).reduce((a,b)=>a+b,0),0);
 assert.notDeepEqual(final.bets.map(b=>b.lead),first.bets.map(b=>b.lead),'Correction updates affected bet scores');
 assert.equal(press.evaluate(corrected.matches[0],bets['A|B']).length,2);
 console.log('18-hole Round Robin shared-score correction and settlement passed');
})().catch(e=>{console.error(e);process.exitCode=1});
