// Supabase data adapter for the Round Robin Nassau scorecard.
// Uses the existing authenticated Supabase client; no service-role keys.
// This is a development module, not yet enabled on the live scorecard.
const requireOk = (result, label) => {
  if (result.error) throw new Error(label + ': ' + result.error.message);
  return result.data;
};

export async function loadRoundRobinGroup(db, groupId) {
  if (!groupId) throw new Error('A Round Robin group ID is required.');
  const group = requireOk(await db.from('round_robin_nassau_groups')
    .select('id,created_by').eq('id',groupId).single(), 'Load round');
  const links = requireOk(await db.from('round_robin_nassau_matches')
    .select('match_id,pairing_number').eq('group_id',groupId)
    .order('pairing_number'), 'Load pairings');
  if (links.length !== 3 || links.some((link, i) => link.pairing_number !== i + 1)
      || new Set(links.map(link => link.match_id)).size !== 3) {
    throw new Error('Round Robin must have exactly three distinct linked matches.');
  }
  const matchIds = links.map(link => link.match_id);
  const matches = requireOk(await db.from('matches')
    .select('id,status,course_id,tee_id,match_date,stake,hole_count,game_type')
    .in('id',matchIds), 'Load Nassau matches');
  if (matches.length !== 3 || matches.some(m => m.game_type !== 'nassau' || m.hole_count !== 18)) {
    throw new Error('Round Robin contains invalid Nassau matches.');
  }
  const matchById = new Map(matches.map(m => [m.id,m]));
  if (new Set(matches.map(m => m.tee_id)).size !== 1 ||
      new Set(matches.map(m => m.course_id)).size !== 1) {
    throw new Error('Round Robin matches must use the same course and tees.');
  }
  const registered = requireOk(await db.from('match_players')
    .select('match_id,player_id,course_handicap').in('match_id',matchIds), 'Load registered players');
  const guests = requireOk(await db.from('guest_players')
    .select('id,match_id,directory_entry_id,display_name,handicap_index,course_handicap')
    .in('match_id',matchIds), 'Load directory players');
  const rosters = new Map(matchIds.map(id => [id, []]));
  for (const row of registered) rosters.get(row.match_id)?.push({
    key:'registered:'+row.player_id,courseHandicap:row.course_handicap
  });
  for (const row of guests) rosters.get(row.match_id)?.push({
    key:'directory:'+row.directory_entry_id,courseHandicap:row.course_handicap,
    name:row.display_name,handicapIndex:row.handicap_index,guestId:row.id
  });
  const unique = new Map();
  for (const rows of rosters.values()) {
    if (rows.length !== 2) throw new Error('Each Nassau pairing must have two players.');
    for (const row of rows) {
      if (row.key.endsWith('null')) throw new Error('A directory player has no linked identity.');
      const existing = unique.get(row.key);
      if (existing && existing.courseHandicap !== row.courseHandicap)
        throw new Error('Course handicap must be consistent across pairings.');
      unique.set(row.key,{...existing,...row});
    }
  }
  if (unique.size !== 3 || [...unique.keys()].some(key =>
    [...rosters.values()].filter(rows => rows.some(r => r.key === key)).length !== 2)) {
    throw new Error('Every player must participate in exactly two pairings.');
  }
  const scoresRegistered = requireOk(await db.from('hole_scores')
    .select('match_id,player_id,hole_number,gross_strokes').in('match_id',matchIds), 'Load registered scores');
  const scoresGuests = requireOk(await db.from('guest_hole_scores')
    .select('match_id,guest_id,hole_number,gross_strokes').in('match_id',matchIds), 'Load directory scores');
  const guestKeys = new Map(guests.map(g => [g.id,'directory:'+g.directory_entry_id]));
  const scores = {};
  const absorb = (key, hole, gross) => {
    if (!key || !Number.isInteger(hole) || hole < 1 || hole > 18) return;
    scores[hole] ??= {};
    if (scores[hole][key] !== undefined && scores[hole][key] !== gross)
      throw new Error('Linked match scores disagree for '+key+' on hole '+hole+'.');
    scores[hole][key] = gross;
  };
  for (const s of scoresRegistered) absorb('registered:'+s.player_id,s.hole_number,s.gross_strokes);
  for (const s of scoresGuests) absorb(guestKeys.get(s.guest_id),s.hole_number,s.gross_strokes);
  return {
    group,links,matches:links.map(link => matchById.get(link.match_id)),
    players:[...unique.values()].map(row=>({id:row.key,...row})),
    pairings:links.map(link=>({matchId:link.match_id,pairingNumber:link.pairing_number,
      playerIds:rosters.get(link.match_id).map(r=>r.key)})),
    scores
  };
}

export async function saveRoundRobinGross(db, groupId, playerKey, hole, gross) {
  if (!Number.isInteger(hole) || hole < 1 || hole > 18 ||
      !Number.isInteger(gross) || gross < 1 || gross > 30) {
    throw new Error('Enter a valid hole (1–18) and gross score (1–30).');
  }
  const count = requireOk(await db.rpc('save_round_robin_nassau_score',{
    p_group:groupId,p_player_key:playerKey,p_hole:hole,p_gross:gross
  }), 'Save shared score');
  if (count !== 2) throw new Error('Expected to update exactly two linked Nassau matches.');
  return count;
}
