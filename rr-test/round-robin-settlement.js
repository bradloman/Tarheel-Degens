// Pure, zero-sum settlement for three independent Nassau pairings.
// Amounts are per bet per pairing. No database writes.
(function(root){
'use strict';
const segments=['front','back','overall'];
function settle(matches,pressesByMatch={},stake=5){
 if(!Array.isArray(matches)||matches.length!==3)throw Error('Exactly three pairings required');
 if(!Number.isFinite(stake)||stake<0)throw Error('Invalid stake');
 const players=new Set(matches.flatMap(m=>m.players));
 if(players.size!==3)throw Error('Exactly three distinct players required');
 const totals=Object.fromEntries([...players].map(id=>[id,0]));
 const bets=[];
 const pressApi=typeof module!=='undefined'&&module.exports?require('./round-robin-presses.js'):root.RoundRobinPresses;
 for(const match of matches){
  if(match.holes.length!==18||match.holes.some(h=>!h.played))throw Error('Cannot settle unfinished round');
  const [a,b]=match.players;
  const key=[a,b].sort().join('|');
  for(const segment of segments){
   const result=match[segment];
   if(!result.closed)throw Error('Cannot settle unfinished '+key+' '+segment);
   const amount=Math.sign(result.lead)*stake;
   totals[a]+=amount;totals[b]-=amount;
   bets.push({match:key,segment,type:'base',lead:result.lead,amountA:amount});
  }
  const presses=pressApi.evaluate(match,pressesByMatch[key]||[]);
  for(const p of presses){
   if(!p.closed)throw Error('Cannot settle unfinished press '+key);
   const value=p.stake==null?stake:p.stake;
   if(!Number.isFinite(value)||value<0)throw Error('Invalid press stake');
   const amount=Math.sign(p.lead)*value;
   totals[a]+=amount;totals[b]-=amount;
   bets.push({match:key,segment:p.segment,type:'press',startHole:p.startHole,lead:p.lead,amountA:amount});
  }
 }
 const rounded=Object.fromEntries(Object.entries(totals).map(([id,v])=>[id,Math.round(v*100)/100]));
 if(Math.abs(Object.values(rounded).reduce((a,b)=>a+b,0))>0.001)throw Error('Settlement must balance');
 return {totals:rounded,bets};
}
// Convert persisted bet rows into one record per opponent, using integer cents.
// Identity resolution and posted-match access belong to the calling records adapter.
function matchupRecords(rows,participantId){
 const pairs=new Map();
 for(const row of rows){
  const a=row.player_a,b=row.player_b;
  if(a!==participantId&&b!==participantId)continue;
  const opponent=a===participantId?b:a, direction=a===participantId?1:-1;
  const key=JSON.stringify([row.match_id,opponent]);
  if(!pairs.has(key))pairs.set(key,{matchId:row.match_id,opponentId:opponent,netCents:0,result:null});
  const record=pairs.get(key), cents=Number(row.amount_a_cents);
  if(!Number.isSafeInteger(cents))throw Error('Invalid settled cents');
  record.netCents+=direction*cents;
  if(row.segment==='overall'&&row.press_id==null){
   if(record.result!==null)throw Error('Duplicate overall result');
   const lead=direction*Number(row.lead);
   if(!Number.isFinite(lead))throw Error('Invalid overall lead');
   record.result=lead>0?'win':lead<0?'loss':'tie';
  }
 }
 const records=[...pairs.values()];
 if(records.some(r=>r.result===null))throw Error('Missing overall result');
 return records;
}
const api={settle,matchupRecords};
if(typeof module!=='undefined'&&module.exports)module.exports=api;
else root.RoundRobinSettlement=api;
})(typeof globalThis!=='undefined'?globalThis:this);
