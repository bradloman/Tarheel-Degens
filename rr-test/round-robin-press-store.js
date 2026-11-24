// Round Robin Nassau press persistence, isolated by match and canonical player pair.
(function(root){
'use strict';
function pair(a,b){
 if(!a||!b||a===b)throw Error('Two distinct players required');
 return [a,b].sort();
}
function scope(matchId,a,b){
 if(!matchId)throw Error('Match id required');
 const [player_a,player_b]=pair(a,b);
 return {match_id:matchId,player_a,player_b};
}
function normalize(row){
 return {id:row.id,segment:row.segment,startHole:row.start_hole,
   playerA:row.player_a,playerB:row.player_b,parentId:row.parent_press_id??null,createdAt:row.created_at};
}
function create(client,matchId,a,b){
 const key=scope(matchId,a,b);
 const table=()=>client.from('match_round_robin_presses');
 return {
  async list(){
   const {data,error}=await table().select('*').match(key).is('undone_at',null).order('created_at',{ascending:true});
   if(error)throw error;
   return (data||[]).map(normalize);
  },
  async add(segment,startHole,userId,parentId=null){
   if(!['front','back','overall'].includes(segment))throw Error('Invalid segment');
   const [min,max]=segment==='front'?[2,9]:segment==='back'?[11,18]:[2,18];
   if(!Number.isInteger(startHole)||startHole<min||startHole>max)throw Error('Invalid press start');
   if(!userId)throw Error('Authenticated user required');
   const {data,error}=await client.rpc('activate_round_robin_press',{p_match:matchId,p_player_a:key.player_a,p_player_b:key.player_b,p_segment:segment,p_start:startHole,p_parent:parentId});
   if(error)throw error;
   return {id:data,segment,startHole,parentId,playerA:key.player_a,playerB:key.player_b};
  },
  async undo(pressId,userId){
   if(!pressId||!userId)throw Error('Press and user required');
   // Server authorization and hole-based undo cutoff must be enforced by the database.
   const {error}=await client.rpc('undo_round_robin_press',{p_id:pressId});
   if(error)throw error;
   return {id:pressId,undone:true};
  }
 };
}
const api={pair,scope,create};
if(typeof module!=='undefined'&&module.exports)module.exports=api;
else root.RoundRobinPressStore=api;
})(typeof globalThis!=='undefined'?globalThis:this);
