export function netMatchResult(player,match,participants,assignments,indexes){
 if(!['nassau','high_low'].includes(match.game_type))return null;
 const n=Number(match.hole_count),grouped=assignments.length>0;
 if(![9,18].includes(n)||participants.length<2)return null;
 const side=x=>grouped?assignments.find(a=>a.key===x.key)?.team:x.key;
 const sides=[...new Set(participants.map(side))];
 if(sides.length!==2||sides.some(x=>x==null))return null;
 const mine=participants.find(x=>x.key===player);
 if(!mine||!participants.every(x=>Number.isFinite(x.ch)))return null;
 const minimum=Math.min(...participants.map(x=>x.ch));
 let margin=0;
 for(let hole=1;hole<=n;hole++){
  const si=Number(indexes.find(x=>x.hole_number===hole)?.stroke_index);
  if(!Number.isInteger(si)||si<1||si>n)return null;
  const values=participants.map(x=>{
   const gross=x.scores.find(s=>s.hole_number===hole)?.gross_strokes;
   if(gross==null||!Number.isFinite(Number(gross)))return null;
   const diff=Math.max(0,Math.round(x.ch-minimum));
   const strokes=Math.floor(diff/n)+(si<=diff%n?1:0);
   return {side:side(x),net:Number(gross)-strokes};
  });
  if(values.some(v=>v==null))return null;
  const scores=sides.map(t=>values.filter(v=>v.side===t).map(v=>v.net).sort((a,b)=>a-b));
  if(match.game_type==='high_low'){
   if(scores.some(x=>x.length!==2))return null;
   margin+=Math.sign(scores[1][0]-scores[0][0])+Math.sign(scores[1][1]-scores[0][1]);
  }else margin+=Math.sign(scores[1][0]-scores[0][0]);
 }
 const result=side(mine)===sides[0]?margin:-margin;
 return result>0?'W':result<0?'L':'T';
}
