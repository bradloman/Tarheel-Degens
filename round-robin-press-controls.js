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
 async function activate(match,segment,parentId=null){
  if(busy)throw Error('Press action in progress');
  busy=true;
  try{
   const rows=await list(match);
   const options=root.RoundRobinPresses.opportunities(match,segment,rows);
   if(!options.some(o=>o.parentId===parentId))throw Error('Selected bet is not eligible');
   const selected=options.find(o=>o.parentId===parentId);
   if(!selected)throw Error('Selected bet is not eligible');
   const start=selected.startHole;
   const [a,b]=match.players;
   const result=await root.RoundRobinPressStore.create(client,matchId,a,b).add(segment,start,userId,parentId);
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
   if(match.holes.some(h=>h.hole>=row.startHole&&h.played))throw Error('Press locked after next hole saved');
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
