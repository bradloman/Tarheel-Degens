const assert=require('node:assert/strict');
const store=require('../round-robin-press-store.js');
assert.deepEqual(store.pair('B','A'),['A','B']);
assert.deepEqual(store.scope('round-1','B','A'),{match_id:'round-1',player_a:'A',player_b:'B'});
assert.notDeepEqual(store.scope('round-1','A','B'),store.scope('round-1','A','C'));
assert.throws(()=>store.scope('round-1','A','A'));
const rows=[];
const mock={
 from(table){assert.equal(table,'match_round_robin_presses');let filters={};return {
  select(){return this},match(obj){Object.assign(filters,obj);return this},
  is(k,v){filters[k]=v;return this},
  order(){return Promise.resolve({data:rows.filter(r=>Object.entries(filters).every(([k,v])=>r[k]===v)),error:null})}
 }},
 async rpc(name,args){
  if(name==='activate_round_robin_press'){
   const id='p'+(rows.length+1);
   rows.push({id,match_id:args.p_match,player_a:args.p_player_a,player_b:args.p_player_b,segment:args.p_segment,start_hole:args.p_start,undone_at:null});
   return {data:id,error:null};
  }
  if(name==='undo_round_robin_press'){
   const row=rows.find(r=>r.id===args.p_id);
   if(!row)return {error:{message:'Not found'}};
   row.undone_at='now';return {error:null};
  }
  throw Error('Unexpected RPC');
 }
};
(async()=>{
 const ab=store.create(mock,'round-1','B','A'),ac=store.create(mock,'round-1','A','C');
 const p=await ab.add('front',3,'user-1');
 assert.equal((await ab.list()).length,1);
 assert.equal((await ac.list()).length,0);
 await ab.undo(p.id,'user-1');
 assert.equal((await ab.list()).length,0);
 console.log('Round Robin press storage RPC tests passed');
})().catch(e=>{console.error(e);process.exitCode=1});
