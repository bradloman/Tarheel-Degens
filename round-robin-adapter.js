// Read-only adapter from Tarheel Degens shared score storage to Round Robin scoring.
(function(root){
'use strict';
function participantIdentity(p){
 if(!p||!p.id)throw Error('Missing Round Robin participant ID');
 const id=String(p.id);
 if(p.guest){
  const directoryId=p.directory_entry_id??p.directoryEntryId??p.directory;
  return {key:'guest:'+id,kind:'guest',scoreId:id,directoryEntryId:directoryId||null};
 }
 return {key:'registered:'+id,kind:'registered',scoreId:id,directoryEntryId:null};
}
function participantIdentities(roster){
 if(!Array.isArray(roster)||roster.length!==3)throw Error('Round Robin requires exactly three players');
 const identities=roster.map(participantIdentity);
 if(new Set(identities.map(x=>x.key)).size!==3)throw Error('Round Robin requires three distinct participants');
 return identities;
}
function mixedRoster(registered,guests){
 const roster=[...registered.map(p=>({id:p.player_id,name:p.name??p.player_id,course_handicap:p.course_handicap,guest:false})),...guests.map(p=>({id:p.id,name:p.display_name,course_handicap:p.course_handicap,guest:true,directory_entry_id:p.directory_entry_id}))];
 participantIdentities(roster);
 if(new Set(roster.map(p=>p.id)).size!==3)throw Error('Ambiguous Round Robin participant IDs');
 const directoryIds=roster.filter(p=>p.directory_entry_id).map(p=>p.directory_entry_id);
 if(new Set(directoryIds).size!==directoryIds.length)throw Error('Duplicate directory participant');
 return roster;
}
function snapshot(roster,teeHoles,scores,guestScores,courseHandicap){
 const identities=participantIdentities(roster);
 const players=roster.map(p=>{
  const saved=p.course_handicap??p.courseHandicap;
  const ch=saved!=null&&saved!==''?Number(saved):p.index!=null&&p.index!==''?courseHandicap(p.index):Number(p.handicap);
  if(!Number.isInteger(ch))throw Error('Missing course handicap for '+p.id);
  return {id:p.id,courseHandicap:ch,name:p.name};
 });
 const holes=Array.from({length:18},(_,i)=>{
  const number=i+1,tee=teeHoles.find(h=>Number(h.hole_number)===number);
  if(!tee)throw Error('Missing tee hole '+number);
  const scoreMap={};
  for(const p of roster){
   const record=(p.guest?guestScores:scores).find(s=>Number(s.hole_number)===number&&(p.guest?s.guest_id:s.player_id)===p.id);
   if(record&&record.gross_strokes!=null)scoreMap[p.id]=Number(record.gross_strokes);
  }
  return {number,strokeIndex:Number(tee.stroke_index),scores:scoreMap};
 });
 return {players,holes,identities};
}
function calculate(roster,teeHoles,scores,guestScores,courseHandicap){
 const data=snapshot(roster,teeHoles,scores,guestScores,courseHandicap);
 return root.RoundRobinNassau.calculate(data.players,data.holes);
}
const api={snapshot,calculate,participantIdentity,participantIdentities,mixedRoster};
if(typeof module!=='undefined'&&module.exports)module.exports=api;
else root.RoundRobinAdapter=api;
})(typeof globalThis!=='undefined'?globalThis:this);
