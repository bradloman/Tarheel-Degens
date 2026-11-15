// Read-only adapter from Tarheel Degens shared score storage to Round Robin scoring.
(function(root){
'use strict';
function snapshot(roster,teeHoles,scores,guestScores,courseHandicap){
 if(roster.length!==3)throw Error('Round Robin requires exactly three players');
 const players=roster.map(p=>{
  const ch=p.index!=null&&p.index!==''?courseHandicap(p.index):Number(p.handicap);
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
 return {players,holes};
}
function calculate(roster,teeHoles,scores,guestScores,courseHandicap){
 const data=snapshot(roster,teeHoles,scores,guestScores,courseHandicap);
 return root.RoundRobinNassau.calculate(data.players,data.holes);
}
const api={snapshot,calculate};
if(typeof module!=='undefined'&&module.exports)module.exports=api;
else root.RoundRobinAdapter=api;
})(typeof globalThis!=='undefined'?globalThis:this);
