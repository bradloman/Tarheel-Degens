const {test}=require('node:test');
const assert=require('node:assert/strict');
const {plan,create}=require('./round-robin-standard-plan.js');
const players=['registered:a','directory:b','directory:c'];
const settings={created_by:'admin',match_date:'2026-11-26',stake:5,course_id:'course',tee_id:'tee'};
test('exactly three ordinary Nassau configurations with shared settings',()=>{
 const rows=plan(players,settings,'group');
 assert.deepEqual(rows.map(r=>r.players),[[players[0],players[1]],[players[0],players[2]],[players[1],players[2]]]);
 rows.forEach((r,i)=>{assert.deepEqual(r.match,{...settings,game_type:'nassau',player_count:2,hole_count:18,notes:JSON.stringify({roundRobin:{groupId:'group',pairIndex:i}})});});
});
test('reject invalid rosters before writes',async()=>{
 for(const p of [[],players.slice(0,2),[players[0],players[0],players[2]],[...players,'self']]){
  await assert.rejects(create(p,settings,'group',{createMatch(){assert.fail('unexpected write');}}));
 }
});
test('creates three matches and enrolls exactly two players per match',async()=>{
 const rows=[],enrolled=[];
 const ids=await create(players,settings,'group',{async createMatch(row){rows.push(row);return {id:'m'+rows.length};},async enroll(id,p){enrolled.push([id,p]);}});
 assert.deepEqual(ids,['m1','m2','m3']);
 assert.deepEqual(enrolled,[['m1',players[0]],['m1',players[1]],['m2',players[0]],['m2',players[2]],['m3',players[1]],['m3',players[2]]]);
});
test('reports partial creation and stops on enrollment failure',async()=>{
 let count=0;
 await assert.rejects(create(players,settings,'group',{async createMatch(){return {id:'m'+(++count)};},async enroll(id){if(id==='m2')throw Error('enrollment failed');}}),e=>{assert.deepEqual(e.createdMatchIds,['m1','m2']);return /enrollment failed/.test(e.message);});
 assert.equal(count,2);
});
