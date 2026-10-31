export function historicalBetCents(m,p,ctx){
 if(!['nassau','high_low'].includes(m.game_type))return null;
 const {members,guests,teams,scores,guestScores,indexes,presses,tee}=ctx;
 if(!tee||!Number.isFinite(Number(m.stake)))return null;
 const ch=x=>{const index=x.registered?(m.match_date>='2026-10-17'&&m.match_date<='2026-10-18'?12.6:null):x.handicap_index;return index==null?null:Math.round(Number(index)*Number(tee.slope_rating)/113+Number(tee.course_rating)-Number(tee.par));};
 const roster=[...members.map(x=>({key:'p:'+x.player_id,registered:true,hcp:ch({registered:true}),ss:scores.filter(y=>y.player_id===x.player_id)})),...guests.map(x=>({key:'g:'+x.id,registered:false,hcp:ch(x),ss:guestScores.filter(y=>y.guest_id===x.id)}))];
 if(roster.some(x=>x.hcp===null||!Number.isFinite(x.hcp))||indexes.length!==Number(m.hole_count))return null;
 const me=roster.find(x=>x.key===p);if(!me)return null;
 const group=x=>teams.find(t=>(t.player_id?'p:'+t.player_id:'g:'+t.guest_id)===x.key)?.team_number;
 const myGroup=group(me),two=roster.length===2;
 if(!two&&(![1,2].includes(myGroup)||roster.length!==4))return null;
 const sides=two?[[me],[roster.find(x=>x!==me)]]:[roster.filter(x=>group(x)===myGroup),roster.filter(x=>group(x)!==myGroup)];
 if(sides.some(x=>x.length!==roster.length/2))return null;
 const min=Math.min(...roster.map(x=>x.hcp)),n=Number(m.hole_count);
 const si=new Map(indexes.map(x=>[Number(x.hole_number),Number(x.stroke_index)]));
 const rank=n===9?[...indexes].sort((a,b)=>a.stroke_index-b.stroke_index):null;
 const net=(x,h)=>{const raw=x.ss.find(y=>Number(y.hole_number)===h)?.gross_strokes,idx=n===9?rank.findIndex(y=>y.hole_number===h)+1:si.get(h),diff=Math.round((x.hcp-min)*n/18);if(raw==null||!Number.isInteger(Number(raw))||idx<1||idx>n)return null;return Number(raw)-Math.floor(diff/n)-(idx<=diff%n?1:0)};
 const holes=new Map();
 for(let h=1;h<=n;h++){const v=sides.map(g=>g.map(x=>net(x,h)).sort((a,b)=>a-b));if(v.some(g=>g.some(x=>x===null)))return null;holes.set(h,v)}
 const sign=(a,b)=>Math.sign(b-a);
 let total=0;
 if(m.game_type==='nassau'){
  const segments=n===18?[['F',1,9],['B',10,18],['O',1,18]]:[['9',1,n]];
  for(const [segment,start,end] of segments){
   const starts=[start,...presses.filter(x=>!x.undone_at&&x.segment===segment&&x.start_hole>=start&&x.start_hole<=end).map(x=>Number(x.start_hole))];
   for(const first of starts){let lead=0;for(let h=first;h<=end;h++){const v=holes.get(h);lead+=sign(v[0][0],v[1][0])}total+=Math.sign(lead)*Number(m.stake)}
  }
 }else{
  if(two||n!==18)return null;
  const starts=[1,...presses.filter(x=>!x.undone_at).map(x=>Number(x.start_hole))];
  for(const first of starts){let lead=0;for(let h=first;h<=18;h++){const v=holes.get(h);lead+=sign(v[0][0],v[1][0])+sign(v[0][1],v[1][1])}total+=Math.sign(lead)*Number(m.stake)}
 }
 return Math.round(total*100);
}
