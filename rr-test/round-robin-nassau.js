// Round Robin Nassau pure scoring core. No database writes.
// Three players share gross scores; every pairing independently receives strokes.
(function(root){
  'use strict';
  function assert(condition,message){if(!condition)throw Error(message);}
  function pairings(players){
    assert(Array.isArray(players)&&players.length===3,'Round Robin Nassau requires exactly three players');
    assert(new Set(players.map(p=>p.id)).size===3,'Players must be distinct');
    return [[players[0],players[1]],[players[0],players[2]],[players[1],players[2]]];
  }
  function strokesOnHole(strokes,strokeIndex){
    assert(Number.isInteger(strokes)&&strokes>=0,'Invalid strokes');
    assert(Number.isInteger(strokeIndex)&&strokeIndex>=1&&strokeIndex<=18,'Invalid stroke index');
    return Math.floor(strokes/18)+(strokeIndex<=strokes%18?1:0);
  }
  function matchup(a,b,holes){
    assert(Number.isInteger(a.courseHandicap)&&Number.isInteger(b.courseHandicap),'Course handicaps required');
    const low=Math.min(a.courseHandicap,b.courseHandicap);
    const rows=holes.map((hole,i)=>{
      const h=i+1,si=hole.strokeIndex;
      assert(hole.number===h,'Holes must be ordered 1–18');
      const ga=hole.scores[a.id],gb=hole.scores[b.id];
      if(ga==null||gb==null)return {hole:h,played:false};
      assert(Number.isInteger(ga)&&ga>0&&Number.isInteger(gb)&&gb>0,'Invalid gross score');
      const na=ga-strokesOnHole(a.courseHandicap-low,si);
      const nb=gb-strokesOnHole(b.courseHandicap-low,si);
      return {hole:h,played:true,gross:[ga,gb],net:[na,nb],winner:na<nb?a.id:nb<na?b.id:null};
    });
    return {players:[a.id,b.id],strokes:[a.courseHandicap-low,b.courseHandicap-low],holes:rows,
      front:segment(rows,1,9,a.id,b.id),back:segment(rows,10,18,a.id,b.id),
      overall:segment(rows,1,18,a.id,b.id)};
  }
  function segment(rows,start,end,a,b){
    let lead=0,last=start-1,closed=false;
    for(let h=start;h<=end;h++){
      const row=rows[h-1];if(!row||!row.played)break;
      lead+=row.winner===a?1:row.winner===b?-1:0;
      last=h;
      if(Math.abs(lead)>end-h){closed=true;break;}
    }
    return {lead,last,played:last-start+1,remaining:end-last,closed:closed||last===end};
  }
  function calculate(players,holes){
    assert(holes.length===18,'Exactly 18 holes required');
    return pairings(players).map(([a,b])=>matchup(a,b,holes));
  }
  const api={pairings,strokesOnHole,matchup,segment,calculate};
  if(typeof module!=='undefined'&&module.exports)module.exports=api;
  else root.RoundRobinNassau=api;
})(typeof globalThis!=='undefined'?globalThis:this);
