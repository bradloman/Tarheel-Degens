const {test}=require('node:test');
const assert=require('node:assert/strict');
const {route,save}=require('./round-robin-standard-scores.js');
const a={key:'a',id:'registered-a',kind:'registered'};
const guest=(key,id)=>({key,id,kind:'guest'});
const matches=[{id:'ab',players:[a,guest('b','b1')]},{id:'ac',players:[a,guest('c','c1')]},{id:'bc',players:[guest('b','b2'),guest('c','c2')]}];
const scores={a:4,b:5,c:6};
test('routes six gross scores to correct match-specific identities',()=>{
 assert.deepEqual(route(matches,scores,7).map(w=>[w.matchId,w.playerId,w.kind,w.hole,w.gross]),[
 ['ab','registered-a','registered',7,4],['ab','b1','guest',7,5],
 ['ac','registered-a','registered',7,4],['ac','c1','guest',7,6],
 ['bc','b2','guest',7,5],['bc','c2','guest',7,6]]);
});
test('rejects incomplete or invalid scores',()=>{
 for(const s of [{a:4,b:5},{a:4,b:0,c:6},{a:4,b:5.5,c:6}])assert.throws(()=>route(matches,s,7));
});
test('rejects duplicate pair and missing match',()=>{
 assert.throws(()=>route([matches[0],matches[1],{...matches[0],id:'other'}],scores,7));
 assert.throws(()=>route(matches.slice(0,2),scores,7));
});
test('accepts holes 1 and 18 and rejects invalid holes',()=>{
 for(const h of [1,18])assert.equal(route(matches,scores,h).length,6);
 for(const h of [0,19,1.5])assert.throws(()=>route(matches,scores,h));
});

function fakeDb(fail){
 const calls=[];
 return {calls,from(table){return {upsert(record,options){calls.push({table,record,options});return {select(){return {async single(){return fail?.(record)?{error:{message:'write failed'}}:{data:{gross_strokes:record.gross_strokes}};}};}};}};}};
}
test('save confirms all six standard score writes',async()=>{
 const db=fakeDb();const result=await save(matches,scores,7,db,'admin');
 assert.equal(result.ok,true);assert.equal(result.confirmed.length,6);
 assert.equal(db.calls.filter(c=>c.table==='guest_hole_scores').length,4);
 assert.equal(db.calls.filter(c=>c.table==='hole_scores').length,2);
 assert.ok(db.calls.every(c=>c.record.saved_by==='admin'));
});
test('partial failure is reported and retry uses identical upsert keys',async()=>{
 const db=fakeDb(r=>r.guest_id==='b2');const result=await save(matches,scores,7,db,'admin');
 assert.equal(result.ok,false);assert.equal(result.confirmed.length,5);assert.equal(result.failed[0].playerId,'b2');
 const retry=fakeDb();assert.equal((await save(matches,scores,7,retry,'admin')).ok,true);
 assert.deepEqual(retry.calls,db.calls);
});
test('invalid gross score is rejected before database writes',async()=>{
 const db=fakeDb();await assert.rejects(save(matches,{a:31,b:5,c:6},7,db,'admin'));assert.equal(db.calls.length,0);
});
