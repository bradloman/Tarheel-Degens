/* Round Robin is orchestration only; all betting belongs to ordinary Nassau matches. */
(function(root){
  function plan(players, settings, groupId) {
    if (!Array.isArray(players) || players.length !== 3 || new Set(players).size !== 3 || players.some(p=>typeof p !== 'string' || !p)) throw new Error('Select exactly three distinct players.');
    if (!groupId) throw new Error('A group identifier is required.');
    const pairs = [[0,1],[0,2],[1,2]];
    return pairs.map(([a,b], index)=>({
      players:[players[a],players[b]],
      match:{...settings,game_type:'nassau',player_count:2,hole_count:18,
        notes:JSON.stringify({roundRobin:{groupId,pairIndex:index}})}
    }));
  }
  async function create(players, settings, groupId, io) {
    const configurations=plan(players,settings,groupId);
    const created=[];
    try {
      for(const config of configurations) {
        const match=await io.createMatch(config.match);
        if(!match?.id) throw new Error('Match creation did not return an ID.');
        created.push(match.id);
        for(const player of config.players) await io.enroll(match.id,player);
      }
      return created;
    } catch(error) {
      const failure=new Error('Round Robin setup failed: '+(error?.message||String(error)));
      failure.createdMatchIds=created;
      throw failure;
    }
  }
  const api={plan,create};
  if(typeof module !== 'undefined' && module.exports) module.exports=api;
  else root.StandardNassauRoundRobin=api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
