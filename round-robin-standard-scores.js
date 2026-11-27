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
 async function save(matches,scores,hole,db,userId){
  const writes=route(matches,scores,hole);
  if(!userId||writes.some(w=>w.gross>30))throw Error('Invalid score or saving user');
  const confirmed=[],failed=[];
  for(const w of writes){
   const guest=w.kind==='guest';
   const record={match_id:w.matchId,[guest?'guest_id':'player_id']:w.playerId,hole_number:w.hole,gross_strokes:w.gross,saved_by:userId};
   try{
    const result=await db.from(guest?'guest_hole_scores':'hole_scores').upsert(record,{onConflict:guest?'guest_id,hole_number':'match_id,player_id,hole_number'}).select('gross_strokes').single();
    if(result.error)throw result.error;
    if(Number(result.data?.gross_strokes)!==w.gross)throw Error('Score write not confirmed');
    confirmed.push(w);
   }catch(e){failed.push({...w,message:e?.message||String(e)});}
  }
  return {ok:failed.length===0,confirmed,failed};
 }
 const api={route,save};
 if(typeof module!=='undefined'&&module.exports)module.exports=api;
 else root.StandardNassauRoundRobinScores=api;
})(typeof globalThis!=='undefined'?globalThis:this);
