// Read-only UI controller for the saved Round Robin Nassau scorecard.
// The caller supplies an authenticated Supabase client and a mounted container.
(function(root){
'use strict';
function create(client,matchId,container){
 if(!container)throw Error('Scorecard container required');
 let state,selected=0;
 const doc=container.ownerDocument;
 function element(tag,value){
  const node=doc.createElement(tag);
  if(value!=null)node.textContent=String(value);
  return node;
 }
 function show(){
  container.replaceChildren();
  if(!state)return;
  const nav=element('nav');
  for(let i=0;i<state.matches.length;i++){
   const match=state.matches[i],button=element('button',match.players.join(' vs '));
   button.type='button';button.setAttribute('aria-pressed',String(i===selected));
   button.addEventListener('click',()=>{selected=i;show()});
   nav.appendChild(button);
  }
  container.appendChild(nav);
  const match=state.matches[selected],status=element('div');
  for(const segment of ['front','back','overall']){
   const s=match[segment];
   const label=s.played===0?'Not started':s.lead===0?'AS':Math.abs(s.lead)+(s.closed&&s.remaining>0?'&'+s.remaining:' UP')+' '+(s.lead>0?match.players[0]:match.players[1]);
   status.appendChild(element('p',segment.toUpperCase()+': '+label));
  }
  container.appendChild(status);
  const key=match.players.slice().sort().join('|');
  const presses=state.pressesByMatch[key]||[];
  container.appendChild(element('p','Active presses: '+presses.map(p=>p.segment+' (hole '+p.startHole+')').join(', ')));
  const pairPlayers=match.players.map(id=>state.players.find(p=>p.id===id));
  const table=element('table'),head=element('tr');
  for(const title of ['Hole',...pairPlayers.map(p=>p.name||p.id),'Winner'])head.appendChild(element('th',title));
  table.appendChild(head);
  for(let h=0;h<18;h++){
   const row=element('tr'),hole=state.holes[h],result=match.holes[h];
   row.appendChild(element('th',h+1));
   for(const player of pairPlayers)row.appendChild(element('td',hole.scores[player.id]??'—'));
   row.appendChild(element('td',result.played?result.winner||'AS':'—'));
   table.appendChild(row);
  }
  container.appendChild(table);
 }
 async function refresh(){
  state=await root.RoundRobinLoader.load(client,matchId);
  show();
  return state;
 }
 return {refresh,select(index){if(!Number.isInteger(index)||index<0||index>2)throw Error('Invalid matchup');selected=index;show()},getState(){return state}};
}
const api={create};
if(typeof module!=='undefined'&&module.exports)module.exports=api;
else root.RoundRobinScorecardView=api;
})(typeof globalThis!=='undefined'?globalThis:this);
