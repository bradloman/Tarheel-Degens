// Pair-scoped press controls for a saved Round Robin Nassau match.
// Uses server-authorized RPCs; does not write press rows directly.
(function(root){
'use strict';
function create(client,matchId,userId,reload){
 if(!client||!matchId||!userId||typeof reload!=='function')throw Error('Authenticated match context required');
 let busy=false;
 const key=match=>match.players.slice().sort().join('|');
 async function list(match){
  const [a,b]=match.players;
  return root.RoundRobinPressStore.create(client,matchId,a,b).list();
 }
 async function available(match,segment){
  const rows=await list(match);
  return root.RoundRobinPresses.eligible(match,segment,rows);
 }
 async function activate(match,segment){
  if(busy)throw Error('Press action in progress');
  busy=true;
  try{
   const rows=await list(match);
   if(!root.RoundRobinPresses.eligible(match,segment,rows))throw Error('Press is not eligible');
   const last=match.overall.last;
   if(last<0||last>=18)throw Error('No next hole');
   const start=last+1;
   const [a,b]=match.players;
   const result=await root.RoundRobinPressStore.create(client,matchId,a,b).add(segment,start,userId);
   await reload();
   return result;
  }finally{busy=false}
 }
 async function undo(match,pressId){
  if(busy)throw Error('Press action in progress');
  busy=true;
  try{
   const rows=await list(match);
   const row=rows.find(p=>p.id===pressId);
   if(!row)throw Error('Press not found in selected matchup');
   if(match.overall.last>=row.startHole)throw Error('Press locked after next hole saved');
   const [a,b]=match.players;
   const result=await root.RoundRobinPressStore.create(client,matchId,a,b).undo(pressId,userId);
   await reload();
   return result;
  }finally{busy=false}
 }
 return {list,available,activate,undo,key};
}
const api={create};
if(typeof module!=='undefined'&&module.exports)module.exports=api;
else root.RoundRobinPressControls=api;
})(typeof globalThis!=='undefined'?globalThis:this);
