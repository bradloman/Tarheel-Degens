const assert=require('node:assert/strict');
const adapter=require('../round-robin-adapter.js');
const rr=require('../round-robin-nassau.js');
const roster=[
 {id:'A',name:'A',course_handicap:8,index:3},
 {id:'B',name:'B',course_handicap:12,index:7},
 {id:'C',name:'C',course_handicap:20,index:15}
];
const tee=Array.from({length:18},(_,i)=>({hole_number:i+1,stroke_index:i+1}));
const scores=Array.from({length:3},(_,i)=>({player_id:'ABC'[i],hole_number:1,gross_strokes:4}));
const data=adapter.snapshot(roster,tee,scores,[],()=>{throw Error('Do not recompute saved course handicaps');});
assert.deepEqual(data.players.map(p=>p.courseHandicap),[8,12,20]);
assert.deepEqual(rr.calculate(data.players,data.holes).map(m=>m.strokes),[[0,4],[0,12],[0,8]]);
assert.equal(data.holes[0].scores.A,4);
assert.deepEqual(data.holes[1].scores,{});
console.log('Round Robin saved handicap adapter tests passed');
