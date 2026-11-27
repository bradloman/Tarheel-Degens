(function(root){
 function metadata(row){try{return JSON.parse(row.notes||'{}').roundRobin||null;}catch{return null;}}
 async function load(db,anchor){
  const meta=metadata(anchor);
  if(!meta?.groupId||anchor.game_type!=='nassau')return null;
  const result=await db.from('matches').select('*').eq('created_by',anchor.created_by).eq('match_date',anchor.match_date).eq('game_type','nassau');
  if(result.error)throw result.error;
  const rows=(result.data||[]).filter(r=>metadata(r)?.groupId===meta.groupId).sort((a,b)=>metadata(a).pairIndex-metadata(b).pairIndex);
  if(rows.length!==3||rows.some((r,i)=>metadata(r).pairIndex!==i||Number(r.player_count)!==2||Number(r.hole_count)!==18||r.tee_id!==anchor.tee_id||r.course_id!==anchor.course_id))throw Error('Incomplete or inconsistent Round Robin group');
  const ids=rows.map(r=>r.id);
  const queries=await Promise.all([
   db.from('match_players').select('match_id,player_id,players(display_name)').in('match_id',ids),
   db.from('guest_players').select('match_id,id,directory_entry_id,display_name').in('match_id',ids),
   db.from('hole_scores').select('match_id,player_id,hole_number,gross_strokes').in('match_id',ids),
   db.from('guest_hole_scores').select('match_id,guest_id,hole_number,gross_strokes').in('match_id',ids)
  ]);
  for(const q of queries)if(q.error)throw q.error;
  const [registered,guests,scores,guestScores]=queries.map(q=>q.data||[]);
  const matches=rows.map(r=>({...r,players:[
   ...registered.filter(p=>p.match_id===r.id).map(p=>({key:'registered:'+p.player_id,id:p.player_id,kind:'registered',name:p.players?.display_name||'Player'})),
   ...guests.filter(p=>p.match_id===r.id).map(p=>{if(!p.directory_entry_id)throw Error('Missing directory identity');return {key:'directory:'+p.directory_entry_id,id:p.id,kind:'guest',name:p.display_name};})
  ]}));
  const players=[...new Map(matches.flatMap(m=>m.players).map(p=>[p.key,p])).values()];
  root.StandardNassauRoundRobinScores.route(matches,Object.fromEntries(players.map(p=>[p.key,1])),1);
  const holes={};
  for(let h=1;h<=18;h++){
   holes[h]={};
   for(const p of players){
    const values=matches.flatMap(m=>m.players.filter(x=>x.key===p.key).map(x=>(x.kind==='guest'?guestScores:scores).find(s=>s.match_id===m.id&&s.hole_number===h&&(x.kind==='guest'?s.guest_id:s.player_id)===x.id)?.gross_strokes));
    holes[h][p.key]={value:values[0]??values[1]??'',consistent:values[0]===values[1]};
   }
  }
  return {matches,players,holes};
 }
 root.StandardNassauRoundRobinGroup={metadata,load};
})(globalThis);
