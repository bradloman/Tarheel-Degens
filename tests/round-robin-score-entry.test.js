const assert=require('node:assert/strict');
const rr=require('../round-robin-nassau.js');
const {create}=require('../round-robin-score-entry.js');
const players=[{id:'A',courseHandicap:0},{id:'B',courseHandicap:0},{id:'C',courseHandicap:0}];
const holes=Array.from({length:18},(_,i)=>({number:i+1,strokeIndex:i+1,scores:{}}));
let saved=0,failed=false;
const loader=async()=>({players,holes,matches:rr.calculate(players,holes)});
const entry=create(loader,async(h,s)=>{
 saved++;
 if(failed)throw Error('Persistence failed');
 holes[h-1].scores={...s};
});
(async()=>{
 await entry.refresh();
 let state=await entry.save(1,{A:3,B:4,C:5});
 assert.equal(saved,1);
 assert.deepEqual(state.matches.map(m=>m.front.lead),[1,1,1]);
 state=await entry.save(1,{A:6,B:4,C:3});
 assert.deepEqual(state.matches.map(m=>m.front.lead),[-1,-1,-1]);
 assert.equal(state.holes[0].scores.A,6);
 await assert.rejects(()=>entry.save(2,{A:4,B:4}),/All three gross/);
 assert.equal(saved,2);
 failed=true;
 await assert.rejects(()=>entry.save(2,{A:4,B:4,C:4}),/Persistence failed/);
 assert.deepEqual(entry.getState().holes[1].scores,{});
 console.log('Round Robin shared score saving tests passed');
})().catch(e=>{console.error(e);process.exitCode=1});
