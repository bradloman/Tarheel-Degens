(function(root){
 function route(matches,scores,hole){
  if(!Number.isInteger(hole)||hole<1||hole>18)throw Error('Invalid hole');
  if(!Array.isArray(matches)||matches.length!==3)throw Error('Expected three matches');
  const keys=Object.keys(scores);
  if(keys.length!==3||keys.some(k=>!Number.isInteger(scores[k])||scores[k]<1))throw Error('Enter three valid gross scores');
  const ids=new Set(),pairs=new Set(),counts=new Map();
  const writes=[];
  for(const match of matches){
   if(!match.id||ids.has(match.id)||match.players?.length!==2)throw Error('Invalid match');
   ids.add(match.id);
   const pair=match.players.map(p=>p.key).sort();
   if(pair[0]===pair[1]||pair.some(k=>!keys.includes(k)))throw Error('Invalid pair');
   const signature=JSON.stringify(pair);
   if(pairs.has(signature))throw Error('Duplicate pair');
   pairs.add(signature);
   for(const p of match.players){
    if(!p.id||!['registered','guest'].includes(p.kind))throw Error('Invalid roster identity');
    counts.set(p.key,(counts.get(p.key)||0)+1);
    writes.push({matchId:match.id,playerId:p.id,kind:p.kind,hole,gross:scores[p.key]});
   }
  }
  if(keys.some(k=>counts.get(k)!==2))throw Error('Incomplete round robin');
  return writes;
 }
 const api={route};
 if(typeof module!=='undefined'&&module.exports)module.exports=api;
 else root.StandardNassauRoundRobinScores=api;
})(typeof globalThis!=='undefined'?globalThis:this);
