// Read-only Supabase loader for a three-player Round Robin Nassau.
// No score writes, press mutations, or settlement posting.
(function(root){
'use strict';
function check(result,label){
 if(result.error)throw Error(label+': '+result.error.message);
 return result.data||[];
}
async function load(client,matchId){
 if(!client||!matchId)throw Error('Client and match ID required');
 const matchResult=await client.from('matches').select('*').eq('id',matchId).single();
 if(matchResult.error)throw Error('Match: '+matchResult.error.message);
 const match=matchResult.data;
 if(!match||match.game_type!=='round_robin'||match.hole_count!==18||match.player_count!==3)
  throw Error('Not an 18-hole three-player Round Robin Nassau');
 const [rosterResult,guestRosterResult,teeResult,scoresResult,guestScoresResult,pressResult]=await Promise.all([
  client.from('match_players').select('*').eq('match_id',matchId),
  client.from('guest_players').select('*').eq('match_id',matchId),
  client.from('course_holes').select('*').eq('tee_id',match.tee_id),
  client.from('hole_scores').select('*').eq('match_id',matchId),
  client.from('guest_hole_scores').select('*').eq('match_id',matchId),
  client.from('match_round_robin_presses').select('*').eq('match_id',matchId).is('undone_at',null)
 ]);
 const roster=check(rosterResult,'Roster'),teeHoles=check(teeResult,'Course holes'),
  scores=check(scoresResult,'Scores'),presses=check(pressResult,'Presses');
 const players=root.RoundRobinAdapter.mixedRoster(roster,check(guestRosterResult,'Directory roster'));
 const data=root.RoundRobinAdapter.snapshot(players,teeHoles,scores,check(guestScoresResult,'Directory scores'),()=>{throw Error('Saved course handicap required');});
 const matches=root.RoundRobinNassau.calculate(data.players,data.holes);
 const pressesByMatch={};
 for(const row of presses){
  const pair=[row.player_a,row.player_b].sort();
  if(!pair.every(id=>players.some(p=>p.id===id))||pair[0]===pair[1])throw Error('Invalid saved press pairing');
  const key=pair.join('|');
  (pressesByMatch[key]||(pressesByMatch[key]=[])).push({
   id:row.id,segment:row.segment,startHole:row.start_hole,parentId:row.parent_press_id??null
  });
 }
 return {match,players:data.players,identities:data.identities,holes:data.holes,matches,pressesByMatch};
}
const api={load};
if(typeof module!=='undefined'&&module.exports)module.exports=api;
else root.RoundRobinLoader=api;
})(typeof globalThis!=='undefined'?globalThis:this);
