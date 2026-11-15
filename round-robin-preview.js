// Development-only UI: one set of gross inputs, selectable matchup status.
(function(){
'use strict';
const $=id=>document.getElementById(id);
const players=[{id:'A',name:'Player A',courseHandicap:8},{id:'B',name:'Player B',courseHandicap:12},{id:'C',name:'Player C',courseHandicap:20}];
const holes=Array.from({length:18},(_,i)=>({number:i+1,strokeIndex:i+1,scores:{}}));
let matchup=0,nine=1;
const pairNames=[['A','B'],['A','C'],['B','C']];
function render(){
 const matches=RoundRobinNassau.calculate(players,holes);
 $('players').innerHTML=players.map(p=>'<label>'+p.name+' · CH <input aria-label="'+p.name+' course handicap" data-hcp="'+p.id+'" type="number" min="-10" max="54" value="'+p.courseHandicap+'"></label> ').join('');
 $('matchups').innerHTML=pairNames.map((p,i)=>'<button type="button" data-matchup="'+i+'" aria-pressed="'+(i===matchup)+'">'+p.join(' vs ')+'</button>').join('');
 const selected=matches[matchup];
 $('status').innerHTML=['front','back','overall'].map(key=>{const r=selected[key];const leader=r.lead>0?selected.players[0]:r.lead<0?selected.players[1]:'';const value=r.played===0?'Not started':r.lead===0?'AS':r.closed&&r.remaining>0?Math.abs(r.lead)+'&'+r.remaining:Math.abs(r.lead)+' UP';return '<div><strong>'+key.toUpperCase()+'</strong><span>'+value+(leader?' · '+leader:'')+'</span></div>'}).join('');
 $('front').setAttribute('aria-pressed',String(nine===1));$('back').setAttribute('aria-pressed',String(nine===2));
 $('head').innerHTML='<tr><th>Hole</th>'+players.map(p=>'<th>'+p.id+'</th>').join('')+'<th>Match</th></tr>';
 const from=nine===1?1:10,to=from+8;
 $('rows').innerHTML=holes.slice(from-1,to).map(h=>{const r=selected.holes[h.number-1];return '<tr><th>'+h.number+'<div class="stroke">SI '+h.strokeIndex+'</div></th>'+players.map(p=>'<td><input aria-label="Hole '+h.number+' '+p.name+' gross strokes" type="number" min="1" max="30" inputmode="numeric" data-hole="'+h.number+'" data-player="'+p.id+'" value="'+(h.scores[p.id]??'')+'"></td>').join('')+'<td>'+(!r.played?'—':r.winner||'AS')+'</td></tr>'}).join('');
 $('totals').innerHTML='<tr><th>'+ (nine===1?'Front':'Back')+' total</th>'+players.map(p=>'<th>'+holes.slice(from-1,to).reduce((n,h)=>n+(h.scores[p.id]||0),0)+'</th>').join('')+'<th></th></tr>';
}
$('matchups').addEventListener('click',e=>{const b=e.target.closest('[data-matchup]');if(b){matchup=Number(b.dataset.matchup);render();}});
$('players').addEventListener('change',e=>{const id=e.target.dataset.hcp;if(!id)return;const n=Number(e.target.value);if(!Number.isInteger(n)||n< -10||n>54)return;players.find(p=>p.id===id).courseHandicap=n;render();});
$('rows').addEventListener('change',e=>{const {hole,player}=e.target.dataset;if(!hole||!player)return;const n=Number(e.target.value);if(e.target.value.trim()==='')delete holes[Number(hole)-1].scores[player];else if(Number.isInteger(n)&&n>=1&&n<=30)holes[Number(hole)-1].scores[player]=n;render();});
$('front').onclick=()=>{nine=1;render()};$('back').onclick=()=>{nine=2;render()};
render();
})();
