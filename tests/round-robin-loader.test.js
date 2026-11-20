const assert=require('node:assert/strict');
global.RoundRobinAdapter=require('../round-robin-adapter.js');
global.RoundRobinNassau=require('../round-robin-nassau.js');
const {load}=require('../round-robin-loader.js');
const roster=['A','B','C'].map((player_id,i)=>({player_id,course_handicap:[8,12,20][i]}));
const holes=Array.from({length:18},(_,i)=>({hole_number:i+1,stroke_index:i+1}));
const scores=['A','B','C'].map(player_id=>({player_id,hole_number:1,gross_strokes:4}));
const press=[{id:'p1',player_a:'A',player_b:'B',segment:'front',start_hole:2,undone_at:null}];
const datasets={matches:[{id:'m1',game_type:'round_robin',hole_count:18,player_count:3,tee_id:'tee'}],match_players:roster,course_holes:holes,hole_scores:scores,match_round_robin_presses:press};
const client={from(table){return {select(){return this},eq(k,v){this.key=k;this.value=v;return this},is(){return this},async single(){return {data:datasets[table][0],error:null}},then(resolve){return Promise.resolve({data:datasets[table],error:null}).then(resolve)}}}};
(async()=>{
 const state=await load(client,'m1');
 assert.equal(state.matches.length,3);
 assert.deepEqual(state.matches.map(m=>m.strokes),[[0,4],[0,12],[0,8]]);
 assert.equal(state.pressesByMatch['A|B'].length,1);
 assert.equal(state.pressesByMatch['A|C'],undefined);
 assert.equal(state.holes[0].scores.A,4);
 console.log('Round Robin read-only loader tests passed');
})().catch(e=>{console.error(e);process.exitCode=1});
