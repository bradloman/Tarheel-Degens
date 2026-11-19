// Pure press evaluation for one independently scored Round Robin Nassau matchup.
(function(root){
 'use strict';
 function evaluate(match,presses){
  if(!match||!Array.isArray(match.holes))throw Error('Match holes required');
  const ids=match.players;
  if(!Array.isArray(ids)||ids.length!==2)throw Error('Two matchup players required');
  const segments={front:[1,9],back:[10,18],overall:[1,18]};
  return presses.map(p=>{
   const range=segments[p.segment];
   if(!range)throw Error('Invalid segment');
   if(!Number.isInteger(p.startHole)||p.startHole<range[0]||p.startHole>range[1])throw Error('Invalid press start');
   let lead=0,last=p.startHole-1,closed=false;
   for(let h=p.startHole;h<=range[1];h++){
    const row=match.holes[h-1];
    if(!row||!row.played)break;
    lead+=row.winner===ids[0]?1:row.winner===ids[1]?-1:0;
    last=h;
    if(Math.abs(lead)>range[1]-h){closed=true;break;}
   }
   return {...p,lead,last,remaining:range[1]-last,closed:closed||last===range[1]};
  });
 }
 function eligible(match,segment,existing=[]){
  const range={front:[1,9],back:[10,18],overall:[1,18]}[segment];
  if(!range)throw Error('Invalid segment');
  // The base Nassau can close early while a separately started press stays live.
  // Derive progress from saved holes rather than the base bet's closed status.
  let last=range[0]-1;
  for(let h=range[0];h<=range[1];h++){
   if(!match.holes[h-1]?.played)break;
   last=h;
  }
  if(last<range[0]||last>=range[1])return false;
  const thread=existing.filter(p=>p.segment===segment).sort((a,b)=>a.startHole-b.startHole);
  const latest=thread.length?evaluate(match,[thread[thread.length-1]])[0]:match[segment];
  return !latest.closed&&Math.abs(latest.lead)>=2;
 }
 const api={evaluate,eligible};
 if(typeof module!=='undefined'&&module.exports)module.exports=api;
 else root.RoundRobinPresses=api;
})(typeof globalThis!=='undefined'?globalThis:this);
