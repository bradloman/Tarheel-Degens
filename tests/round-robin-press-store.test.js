const assert=require('node:assert/strict');
const store=require('../round-robin-press-store.js');
assert.deepEqual(store.pair('B','A'),['A','B']);
assert.deepEqual(store.scope('round-1','B','A'),{match_id:'round-1',player_a:'A',player_b:'B'});
assert.notDeepEqual(store.scope('round-1','A','B'),store.scope('round-1','A','C'));
assert.throws(()=>store.scope('round-1','A','A'));
const rows=[];
const mock={from(table){
 assert.equal(table,'match_round_robin_presses');
 let filters={},pending=null;
 const chain={
 select(){return chain},match(obj){filters={...filters,...obj};return chain},
 is(field,value){filters[field]=value;return chain},order(){return Promise.resolve({data:rows.filter(r=>Object.entries(filters).every(([k,v])=>r[k]===v)),error:null})},
 insert(obj){pending={id:'p'+(rows.length+1),created_at:'now',undone_at:null,...obj};rows.push(pending);return chain},
 update(obj){pending={...obj};return chain},
 single(){
  if(pending?.id)return Promise.resolve({data:pending,error:null});
  const row=rows.find(r=>Object.entries(filters).every(([k,v])=>r[k]===v));
  if(!row)return Promise.resolve({data:null,error:{message:'not found'}});
  Object.assign(row,pending);return Promise.resolve({data:row,error:null});
 }
 };return chain;
}};
(async()=>{
 const ab=store.create(mock,'round-1','B','A'),ac=store.create(mock,'round-1','A','C');
 const p=await ab.add('front',3,'user-1');
 assert.equal((await ab.list()).length,1);
 assert.equal((await ac.list()).length,0);
 await assert.rejects(()=>ac.undo(p.id,'user-1'));
 await ab.undo(p.id,'user-1');
 assert.equal((await ab.list()).length,0);
 console.log('Round Robin press storage isolation tests passed');
})().catch(e=>{console.error(e);process.exitCode=1});
