const assert=require('node:assert/strict');
const fs=require('node:fs');
const sql=fs.readFileSync('supabase/round-robin-presses.sql','utf8');
for(const pattern of [
 /parent_press_id uuid references public\.match_round_robin_presses\(id\)/,
 /p_parent uuid default null/,
 /v_parent\.match_id<>p_match/,
 /v_parent\.segment<>p_segment/,
 /v_start:=v_parent\.start_hole/,
 /if abs\(v_lead\)<2 then raise exception/,
 /if abs\(v_lead\)>v_end-v_last then raise exception/,
 /later\.parent_press_id=p\.id/,
 /hole_number>=p\.start_hole/,
 /revoke all on function public\.activate_round_robin_press\(uuid,uuid,uuid,text,integer,uuid\) from public,anon,authenticated/,
 /create policy rr_presses_read/
])assert.match(sql,pattern);
assert.doesNotMatch(sql,/grant execute on function public\.activate_round_robin_press/, 'Activation must remain disabled pending database validation');
console.log('Staged Round Robin SQL security contract checks passed');
