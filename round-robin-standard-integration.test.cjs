const {test}=require('node:test');
const assert=require('node:assert/strict');
const {create}=require('./round-robin-standard-plan.js');
const scoring=require('./round-robin-standard-scores.js');
globalThis.StandardNassauRoundRobinScores=scoring;
require('./round-robin-standard-group.js');
test('create three Nassaus, save two holes, reopen from another matchup',async()=>{
 const tables={matches:[],match_players:[],guest_players:[],hole_scores:[],guest_hole_scores:[]};
 const ids=await create(['registered:a','directory:b','directory:c'],{created_by:'admin',match_date:'2026-11-26',tee_id:'tee',course_id:'course',stake:5},'group',{
 async createMatch(row){const m={...row,id:'m'+tables.matches.length,status:'active'};tables.matches.push(m);return m;},
 async enroll(id,p){if(p.startsWith('registered:'))tables.match_players.push({match_id:id,player_id:p.slice(11),players:{display_name:'A'}});else tables.guest_players.push({match_id:id,id:id+p,directory_entry_id:p.slice(10),display_name:p.slice(10)});}
 });
 const db={from(table){let rows=tables[table];const q={select(){return q;},eq(k,v){rows=rows.filter(r=>r[k]===v);return q;},in(k,v){rows=rows.filter(r=>v.includes(r[k]));return q;},then(resolve){return Promise.resolve({data:rows}).then(resolve);},upsert(record,{onConflict}){const keys=onConflict.split(',');const old=tables[table].find(r=>keys.every(k=>r[k]===record[k]));if(old)Object.assign(old,record);else tables[table].push(record);return {select(){return {async single(){return {data:{gross_strokes:record.gross_strokes}};}};}};}};return q;}};
 const group=await globalThis.StandardNassauRoundRobinGroup.load(db,tables.matches[0]);
 assert.equal(group.players.length,3);
 for(let h=1;h<=2;h++)assert.equal((await scoring.save(group.matches,{'registered:a':4,'directory:b':5,'directory:c':6},h,db,'admin')).ok,true);
 const reopened=await globalThis.StandardNassauRoundRobinGroup.load(db,tables.matches[2]);
 assert.deepEqual(reopened.matches.map(m=>m.id),ids);
 assert.deepEqual(reopened.holes[2]['directory:b'],{value:5,consistent:true});
 assert.equal(tables.hole_scores.length+tables.guest_hole_scores.length,12);
});
